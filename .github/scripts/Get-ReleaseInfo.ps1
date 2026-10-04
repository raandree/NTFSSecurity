<#
.SYNOPSIS
    Returns the version of the module and its release notes from CHANGELOG.md.

.DESCRIPTION
    Reads ModuleVersion and the prerelease label (PrivateData.PSData.Prerelease) from the module manifest and returns
    the version to release, such as 5.0.0 or 5.0.0-rc1, with its release notes:

    - A release without a prerelease label takes the notes of the section "## [<version>] - <yyyy-MM-dd>". The
      section must exist and have a release date.
    - A prerelease takes the notes of the section "## [Unreleased]", which must not be empty. CHANGELOG.md must not
      have a section for the version yet; it gets one with the final release.

    The notes are the text below the heading up to the next section or up to the link definitions at the end of the
    file, with line feeds as line breaks.

.PARAMETER ManifestPath
    Specifies the module manifest.

.PARAMETER ChangelogPath
    Specifies CHANGELOG.md.

.EXAMPLE
    .\.github\scripts\Get-ReleaseInfo.ps1 -ManifestPath .\NTFSSecurity\NTFSSecurity.psd1 -ChangelogPath .\CHANGELOG.md

    Returns the version, whether it is a prerelease, the release date, and the release notes.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]
    $ManifestPath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]
    $ChangelogPath
)

$ErrorActionPreference = 'Stop'

function Get-ChangelogSection {
    <#
        Returns the date and the notes of the section with the given name, such as 5.0.0 or Unreleased, or nothing if
        CHANGELOG.md has no such section.
    #>
    param (
        [Parameter(Mandatory)]
        [string]
        $Changelog,

        [Parameter(Mandatory)]
        [string]
        $Name
    )

    $pattern = '(?ms)^## \[{0}\](?:[ \t]+-[ \t]+(?<Date>\S+))?[ \t]*$(?<Notes>.*?)(?=^## |^\[[^\]]+\]:[ \t]|\z)' -f
        [regex]::Escape($Name)
    $match = [regex]::Match($Changelog, $pattern)
    if ($match.Success) {
        [pscustomobject]@{
            Date  = $match.Groups['Date'].Value
            Notes = $match.Groups['Notes'].Value.Trim()
        }
    }
}

$manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$moduleVersion = "$($manifest.ModuleVersion)"
if ($moduleVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "The module version '$moduleVersion' must have three parts, such as 5.0.0."
}

$prerelease = "$($manifest.PrivateData.PSData.Prerelease)"
if ($prerelease -and $prerelease -notmatch '^[A-Za-z][0-9A-Za-z-]*$') {
    throw ("The prerelease label '$prerelease' isn't valid in the PowerShell Gallery. Use letters, digits, and " +
        'hyphens only, starting with a letter, such as rc1.')
}

$changelog = (Get-Content -LiteralPath $ChangelogPath -Raw -Encoding UTF8) -replace '\r\n', "`n"
$versionSection = Get-ChangelogSection -Changelog $changelog -Name $moduleVersion

if ($prerelease) {
    if ($versionSection) {
        throw ("CHANGELOG.md already has a section for $moduleVersion, so $moduleVersion is released. A prerelease " +
            'needs a higher module version.')
    }

    $section = Get-ChangelogSection -Changelog $changelog -Name 'Unreleased'
    if (-not $section -or -not $section.Notes) {
        throw "The [Unreleased] section of CHANGELOG.md is empty. It holds the notes of $moduleVersion-$prerelease."
    }
    $date = $null
} else {
    if (-not $versionSection) {
        throw ("CHANGELOG.md has no section for $moduleVersion. Rename the [Unreleased] section to " +
            "[$moduleVersion] and add the release date.")
    }
    if ($versionSection.Date -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw "The section of $moduleVersion in CHANGELOG.md has no release date in the format yyyy-MM-dd."
    }
    if (-not $versionSection.Notes) {
        throw "The section of $moduleVersion in CHANGELOG.md is empty."
    }

    $section = $versionSection
    $date = [datetime]::ParseExact($versionSection.Date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
}

[pscustomobject]@{
    Version       = if ($prerelease) { "$moduleVersion-$prerelease" } else { $moduleVersion }
    ModuleVersion = $moduleVersion
    Prerelease    = $prerelease
    IsPrerelease  = [bool] $prerelease
    Date          = $date
    Notes         = $section.Notes
}
