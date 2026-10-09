[CmdletBinding()]
param (
    [Parameter(Mandatory)] [ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z]+)?$')] [string] $Version,
    [Parameter(Mandatory)] [string] $OutputPath,
    [string] $Repository = 'raandree/NTFSSecurity'
)

# Read-only identity check of a published NTFSSecurity version (acceptance of a published candidate): the tag, its commit on master, the CI run of the
# tag, the GitHub release asset, and the PowerShell Gallery package. It downloads the nupkg and the zip into OutputPath, checks the
# SHA-512 that the Gallery publishes (ordinal, case-sensitive base64), extracts both with System.IO.Compression, and compares the
# module files byte for byte. It writes Identity.json and prints a table; it changes nothing on GitHub or in the Gallery, and
# it never imports the module. Exit code 1 for any mismatch.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$headers = @{ 'User-Agent' = 'ntfssecurity-published-identity-check'; Accept = 'application/vnd.github+json' }
$api = "https://api.github.com/repos/$Repository"
$problems = New-Object -TypeName 'System.Collections.Generic.List[string]'
$result = [ordered]@{ Version = $Version; CheckedUtc = [DateTime]::UtcNow.ToString('o') }

# 1. The tag and its commit
$ref = Invoke-RestMethod -Uri "$api/git/ref/tags/$Version" -Headers $headers
$sha = $ref.object.sha
if ($ref.object.type -eq 'tag') { $sha = (Invoke-RestMethod -Uri "$api/git/tags/$sha" -Headers $headers).object.sha }
$result.TagCommit = $sha
$compare = Invoke-RestMethod -Uri "$api/compare/master...$sha" -Headers $headers
$result.CommitOnMaster = ($compare.status -in 'identical', 'behind')
$result.CompareStatus = $compare.status
if (-not $result.CommitOnMaster) { $problems.Add("The commit $sha of the tag isn't on master (compare status: $($compare.status)).") }

# 2. The CI run of the tag: the tag push has the tag as its branch name
$runs = @((Invoke-RestMethod -Uri "$api/actions/runs?head_sha=$sha&per_page=30" -Headers $headers).workflow_runs | Where-Object -FilterScript { $_.event -eq 'push' -and $_.head_branch -eq $Version })
if ($runs.Count -eq 0) { $problems.Add("No CI run of the tag push for $Version.") }
$jobs = @()
foreach ($run in ($runs | Sort-Object -Property run_number)) {
    $jobs += @((Invoke-RestMethod -Uri "$api/actions/runs/$($run.id)/jobs?per_page=50" -Headers $headers).jobs | ForEach-Object -Process {
            [pscustomobject]@{ Run = $run.id; Attempt = $run.run_attempt; Job = $_.name; Status = $_.status; Conclusion = $_.conclusion }
        })
}
$result.CiJobs = $jobs
$latestRelease = @($jobs | Where-Object -FilterScript { $_.Job -match 'Release' } | Sort-Object -Property Attempt | Select-Object -Last 1)
if ($latestRelease.Count -eq 0 -or $latestRelease[0].Conclusion -ne 'success') { $problems.Add('The latest Release job of the tag did not succeed.') }

# 3. The GitHub release and its zip
$release = Invoke-RestMethod -Uri "$api/releases/tags/$Version" -Headers $headers
$asset = @($release.assets | Where-Object -FilterScript { $_.name -eq 'NTFSSecurity.zip' }) | Select-Object -First 1
if (-not $asset) { throw "The release $Version has no NTFSSecurity.zip." }
$zipPath = Join-Path -Path $OutputPath -ChildPath "NTFSSecurity-$Version.zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
$zipSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$result.Release = [ordered]@{ Prerelease = $release.prerelease; Published = $release.published_at; AssetSize = $asset.size; AssetDigest = $asset.digest; ZipSha256 = $zipSha256 }
if ($asset.digest -and $asset.digest -like 'sha256:*' -and ($asset.digest.Substring(7) -ne $zipSha256.ToLowerInvariant())) { $problems.Add('The SHA-256 of the downloaded zip differs from the digest of the release asset.') }

# 4. The PowerShell Gallery package; the published hash is base64 of SHA-512
$entry = Invoke-RestMethod -Uri ("https://www.powershellgallery.com/api/v2/Packages(Id='NTFSSecurity',Version='{0}')" -f $Version)
$published = $entry.entry.properties.PackageHash.'#text'
if (-not $published) { $published = [string] $entry.entry.properties.PackageHash }
$algorithm = $entry.entry.properties.PackageHashAlgorithm
if (-not $published -or $algorithm -ne 'SHA512') { throw "The Gallery has no SHA512 hash for NTFSSecurity $Version (algorithm '$algorithm')." }
$nupkgPath = Join-Path -Path $OutputPath -ChildPath "NTFSSecurity.$Version.nupkg"
Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/NTFSSecurity/$Version" -OutFile $nupkgPath -UseBasicParsing
$sha512 = [System.Security.Cryptography.SHA512]::Create()
$stream = [System.IO.File]::OpenRead($nupkgPath)
try { $actual = [Convert]::ToBase64String($sha512.ComputeHash($stream)) } finally { $stream.Dispose(); $sha512.Dispose() }
$hashMatches = [string]::Equals($actual, $published, [StringComparison]::Ordinal)
$result.Gallery = [ordered]@{ Published = $entry.entry.properties.Published.'#text'; IsPrerelease = $entry.entry.properties.IsPrerelease.'#text'; PackageHashAlgorithm = $algorithm; PackageHash = $published; DownloadedSha512 = $actual; HashMatches = $hashMatches; NupkgSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $nupkgPath).Hash }
if (-not $hashMatches) { $problems.Add('The downloaded nupkg does not have the SHA-512 that the Gallery publishes.') }

# 5. The module files of both packages
$nupkgFolder = Join-Path -Path $OutputPath -ChildPath "nupkg-$Version"
$zipFolder = Join-Path -Path $OutputPath -ChildPath "zip-$Version"
foreach ($folder in $nupkgFolder, $zipFolder) { if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force } }
[System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgPath, $nupkgFolder)
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $zipFolder)
function Get-ModuleRoot { param ([string] $Folder) (Get-ChildItem -LiteralPath $Folder -Filter 'NTFSSecurity.psd1' -Recurse -File | Select-Object -First 1).DirectoryName }
$nupkgRoot = Get-ModuleRoot -Folder $nupkgFolder
$zipRoot = Get-ModuleRoot -Folder $zipFolder
$files = foreach ($file in Get-ChildItem -LiteralPath $zipRoot -Recurse -File) {
    $relative = $file.FullName.Substring($zipRoot.Length).TrimStart('\')
    $other = Join-Path -Path $nupkgRoot -ChildPath $relative
    $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
    $nupkgHash = if (Test-Path -LiteralPath $other) { (Get-FileHash -Algorithm SHA256 -LiteralPath $other).Hash } else { '' }
    [pscustomobject]@{ File = $relative; ZipSha256 = $zipHash; NupkgSha256 = $nupkgHash; Equal = ($zipHash -eq $nupkgHash) }
}

$files | Export-Csv -LiteralPath (Join-Path -Path $OutputPath -ChildPath "ModuleFiles-$Version.csv") -NoTypeInformation -Encoding utf8
$result.ModuleFiles = @($files).Count
$result.ModuleFilesEqual = (@($files | Where-Object -FilterScript { -not $_.Equal }).Count -eq 0)
$result.ModuleDllSha256 = ($files | Where-Object -FilterScript { $_.File -eq 'NTFSSecurity.dll' }).ZipSha256
if (-not $result.ModuleFilesEqual) { $problems.Add('The module files of the nupkg and of the zip differ.') }

# 6. The identity that the manifest claims
$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $zipRoot -ChildPath 'NTFSSecurity.psd1')
$label = $manifest.PrivateData.PSData.Prerelease
$claimed = if ($label) { '{0}-{1}' -f $manifest.ModuleVersion, $label } else { [string] $manifest.ModuleVersion }
$result.ManifestVersion = $claimed
if ($claimed -ne $Version) { $problems.Add("The manifest says $claimed, not $Version.") }

$result.Problems = @($problems)
$result.Verified = ($problems.Count -eq 0)
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path -Path $OutputPath -ChildPath "Identity-$Version.json") -Encoding utf8
'Version {0}: tag commit {1}; on master: {2} ({3})' -f $Version, $sha, $result.CommitOnMaster, $compare.status
$jobs | Format-Table -AutoSize | Out-String -Width 200
'GitHub zip SHA-256 {0}' -f $zipSha256
'Gallery SHA-512 matches: {0}; nupkg SHA-256 {1}' -f $hashMatches, $result.Gallery.NupkgSha256
'Module files: {0}; equal in nupkg and zip: {1}; NTFSSecurity.dll SHA-256 {2}' -f $result.ModuleFiles, $result.ModuleFilesEqual, $result.ModuleDllSha256
'Manifest identity: {0}' -f $claimed
if ($problems.Count -gt 0) { $problems | ForEach-Object -Process { 'PROBLEM: ' + $_ }; 'PUBLISHED_IDENTITY_NOT_VERIFIED'; exit 1 }
'PUBLISHED_IDENTITY_VERIFIED'
