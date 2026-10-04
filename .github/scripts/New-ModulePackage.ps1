<#
.SYNOPSIS
    Builds the packages of a release from the build output of the module.

.DESCRIPTION
    Copies the files that the FileList of the module manifest names from BuildPath into the folder NTFSSecurity in
    DestinationPath, so that the packages contain no debug symbols or other build output, and checks the copy with
    Test-ModuleManifest. Then it creates the NuGet package for the PowerShell Gallery with Compress-PSResource, named
    after the version and the prerelease label, and adds the command tags that the PowerShell Gallery uses to list the
    cmdlets of the module. Last, it creates NTFSSecurity.zip, which contains the folder NTFSSecurity, for the GitHub
    release.

    The script needs Compress-PSResource from Microsoft.PowerShell.PSResourceGet, which comes with PowerShell 7.4 and
    later.

.PARAMETER BuildPath
    Specifies the build output folder, such as NTFSSecurity\bin\Release.

.PARAMETER DestinationPath
    Specifies the folder for the module folder and the packages. The script replaces the module folder and the
    packages that an earlier run created there.

.EXAMPLE
    .\.github\scripts\New-ModulePackage.ps1 -BuildPath .\NTFSSecurity\bin\Release -DestinationPath .\out

    Creates the folder .\out\NTFSSecurity and the files .\out\NTFSSecurity.<version>.nupkg and .\out\NTFSSecurity.zip.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]
    $BuildPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $DestinationPath
)

$ErrorActionPreference = 'Stop'
$moduleName = 'NTFSSecurity'

if (-not (Get-Command -Name Compress-PSResource -ErrorAction SilentlyContinue)) {
    throw 'Compress-PSResource was not found. Run the script in PowerShell 7.4 or later, which includes PSResourceGet.'
}

$buildRoot = (Resolve-Path -LiteralPath $BuildPath).ProviderPath
$manifestPath = Join-Path -Path $buildRoot -ChildPath "$moduleName.psd1"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "The build output in '$buildRoot' has no module manifest $moduleName.psd1."
}

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$version = "$($manifest.ModuleVersion)"
if ($manifest.PrivateData.PSData.Prerelease) {
    $version = '{0}-{1}' -f $version, $manifest.PrivateData.PSData.Prerelease
}

$missingFiles = @($manifest.FileList | Where-Object -FilterScript {
        -not (Test-Path -LiteralPath (Join-Path -Path $buildRoot -ChildPath $_) -PathType Leaf)
    })
if ($missingFiles) {
    throw "The build output in '$buildRoot' lacks these files of the FileList: $($missingFiles -join ', ')."
}

$destinationRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
$modulePath = Join-Path -Path $destinationRoot -ChildPath $moduleName
$packagePath = Join-Path -Path $destinationRoot -ChildPath "$moduleName.$version.nupkg"
$zipPath = Join-Path -Path $destinationRoot -ChildPath "$moduleName.zip"
foreach ($path in $modulePath, $packagePath, $zipPath) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

foreach ($file in $manifest.FileList) {
    $target = Join-Path -Path $modulePath -ChildPath $file
    $targetFolder = Split-Path -Path $target -Parent
    if (-not (Test-Path -LiteralPath $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path -Path $buildRoot -ChildPath $file) -Destination $target
}

$testParameters = @{
    Path            = Join-Path -Path $modulePath -ChildPath "$moduleName.psd1"
    ErrorAction     = 'Stop'
    WarningVariable = 'manifestWarnings'
    WarningAction   = 'SilentlyContinue'
}
$null = Test-ModuleManifest @testParameters
if ($manifestWarnings) {
    throw "Test-ModuleManifest reported warnings for the module in '$modulePath': $($manifestWarnings -join ' ')"
}

Compress-PSResource -Path $modulePath -DestinationPath $destinationRoot
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw "Compress-PSResource didn't create the package '$packagePath'."
}

<#
    PSResourceGet doesn't add the command tags that PowerShellGet 2 added when it published 4.2.6. The PowerShell
    Gallery lists the cmdlets of a module from these tags, and Find-Command searches them, so add the missing ones to
    the nuspec in the package.
#>
$commandTags = @('PSIncludes_Cmdlet') + @($manifest.CmdletsToExport | Sort-Object -Unique |
        ForEach-Object -Process { "PSCmdlet_$_"; "PSCommand_$_" })
$archive = [IO.Compression.ZipFile]::Open($packagePath, [IO.Compression.ZipArchiveMode]::Update)
try {
    $stream = $archive.GetEntry("$moduleName.nuspec").Open()
    try {
        $nuspec = New-Object -TypeName 'System.Xml.XmlDocument'
        $nuspec.Load($stream)
        $tagsNode = $nuspec.SelectSingleNode("/*[local-name()='package']/*[local-name()='metadata']/*[local-name()='tags']")
        if (-not $tagsNode) {
            throw "The nuspec in the package '$packagePath' has no tags element."
        }
        $tags = @($tagsNode.InnerText -split '\s+' | Where-Object -FilterScript { $_ })
        $tagsNode.InnerText = ($tags + @($commandTags | Where-Object -FilterScript { $_ -notin $tags })) -join ' '

        $stream.SetLength(0)
        $settings = New-Object -TypeName 'System.Xml.XmlWriterSettings'
        $settings.Encoding = New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false
        $settings.Indent = $true
        $writer = [Xml.XmlWriter]::Create($stream, $settings)
        try {
            $nuspec.Save($writer)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
} finally {
    $archive.Dispose()
}

[IO.Compression.ZipFile]::CreateFromDirectory($modulePath, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $true)

[pscustomobject]@{
    Version     = $version
    ModulePath  = $modulePath
    PackagePath = $packagePath
    ZipPath     = $zipPath
}
