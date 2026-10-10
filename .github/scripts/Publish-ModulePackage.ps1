<#
.SYNOPSIS
    Publishes the already built NTFSSecurity package to the PowerShell Gallery.
.DESCRIPTION
    Uses the PSGALLERY_API_KEY environment secret. A published version is skipped only when its Gallery SHA512
    matches the exact local package. An uncertain upload is recovered only after that same verification; other
    errors remain failures. The release workflow checks the tag and version first.
.PARAMETER NupkgPath
    The package that the build job produced.
.PARAMETER Version
    The version that the release workflow verified.
.EXAMPLE
    .\.github\scripts\Publish-ModulePackage.ps1 -NupkgPath .\out\NTFSSecurity.5.0.0-rc7.nupkg -Version 5.0.0-rc7

    Publishes the package using the environment secret, without logging or passing the key on a process command line.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $NupkgPath,

    [Parameter(Mandatory)]
    [ValidatePattern('\A\d+\.\d+\.\d+(?:-[A-Za-z][0-9A-Za-z-]*)?\z')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'
if (-not $env:PSGALLERY_API_KEY) {
    throw 'The secret PSGALLERY_API_KEY of the environment powershell-gallery is not set.'
}
$packagePath = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath

function Find-PublishedPackage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param ()

    $lookupErrors = @()
    $found = @(Find-PSResource -Name NTFSSecurity -Version $Version -Prerelease -Repository PSGallery -ErrorAction SilentlyContinue -ErrorVariable lookupErrors)
    foreach ($lookupError in $lookupErrors) {
        if (($lookupError.FullyQualifiedErrorId -split ',')[0] -ne 'PackageNotFound') {
            throw $lookupError
        }
    }
    if ($found.Count -gt 1) {
        throw "The PowerShell Gallery returned more than one package for NTFSSecurity $Version."
    }
    if ($found.Count -eq 1) {
        return $found[0]
    }
    Write-Verbose "NTFSSecurity $Version is not listed in the PowerShell Gallery."
}

function Assert-PublishedPackage {
    [CmdletBinding()]
    param ()

    $uri = "https://www.powershellgallery.com/api/v2/Packages(Id='NTFSSecurity',Version='$Version')"
    $entry = Invoke-RestMethod -Uri $uri -ErrorAction Stop
    $expectedHash = [string] $entry.entry.properties.PackageHash
    if ($entry.entry.properties.PackageHashAlgorithm -ne 'SHA512' -or -not $expectedHash) {
        throw "The PowerShell Gallery has no usable SHA512 hash for NTFSSecurity $Version."
    }
    $stream = [IO.File]::OpenRead($packagePath)
    $sha512 = [Security.Cryptography.SHA512]::Create()
    try {
        $actualHash = [Convert]::ToBase64String($sha512.ComputeHash($stream))
    }
    finally {
        $sha512.Dispose()
        $stream.Dispose()
    }
    if ($actualHash -cne $expectedHash) {
        throw "NTFSSecurity $Version in the PowerShell Gallery contains a different package; publication cannot continue."
    }
}

if (Find-PublishedPackage) {
    Assert-PublishedPackage
    "NTFSSecurity $Version is already in the PowerShell Gallery and matches the exact local package."
    return
}

try {
    Publish-PSResource -NupkgPath $packagePath -Repository PSGallery -ApiKey $env:PSGALLERY_API_KEY -ErrorAction Stop
}
catch {
    $publishError = $_
    $verified = $false
    try {
        if (Find-PublishedPackage) {
            Assert-PublishedPackage
            $verified = $true
        }
    }
    catch {
        Write-Warning ("The upload outcome could not be verified for NTFSSecurity {0}: {1}" -f $Version, $_.Exception.Message)
    }
    if ($verified) {
        Write-Warning "Publish-PSResource reported an error, but the Gallery SHA512 verified the exact package for NTFSSecurity $Version."
        return
    }
    throw $publishError
}
