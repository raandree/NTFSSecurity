<#
.SYNOPSIS
    Runs NTFSSecurity.Live.Tests.ps1 for one role and writes the result file.

.DESCRIPTION
    Invoke-NTFSSecurityLabTest.ps1 starts this script in a new Windows PowerShell 5.1 or PowerShell 7 process on the
    client or the file server of the lab, as the account of the role. Each module version runs in its own process,
    because all versions of NTFSSecurity.dll have the same assembly version, and a second import in a process would
    use the first DLL. Exits with 0 when all tests passed and with 1 otherwise.

.PARAMETER ModulePath
    The folder that contains NTFSSecurity.psd1 of the version to test. The role Server needs no module.

.PARAMETER ConfigurationPath
    The configuration of the run that Invoke-NTFSSecurityLabTest.ps1 wrote.

.PARAMETER Role
    The role whose tests run: Delegate, ServerAdmin, Admin, or Server.

.PARAMETER ResultPath
    The path of the result file: a JSON array with the name, the result, and the error message of each test that
    ran, and of each test file that failed. Pester's result formats read the operating system through CIM, which an
    account that isn't an administrator can't use in a remote session.

.EXAMPLE
    .\Start-NTFSSecurityLiveTest.ps1 -ModulePath C:\NTFSSecurityLab\Modules\5.0.0-rc4\NTFSSecurity -ConfigurationPath C:\NTFSSecurityLab\Configuration\Run.json -Role Delegate -ResultPath $env:TEMP\Delegate.json

    Runs the tests of the delegated account against 5.0.0-rc4.
#>
[CmdletBinding()]
param (
    [string]
    $ModulePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ConfigurationPath,

    [Parameter(Mandatory)]
    [ValidateSet('Delegate', 'ServerAdmin', 'Admin', 'Server')]
    [string]
    $Role,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ResultPath
)

$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 5.7.1

$data = @{
    ModulePath        = $ModulePath
    ConfigurationPath = $ConfigurationPath
    Role              = $Role
}
$configuration = New-PesterConfiguration
$configuration.Run.Container = New-PesterContainer -Path (Join-Path -Path $PSScriptRoot -ChildPath 'NTFSSecurity.Live.Tests.ps1') -Data $data
$configuration.Run.PassThru = $true
$configuration.Filter.Tag = $Role
$configuration.Output.Verbosity = 'Detailed'
$configuration.Output.RenderMode = 'Plaintext'
$result = Invoke-Pester -Configuration $configuration

$tests = foreach ($test in $result.Tests | Where-Object -FilterScript { $_.Result -ne 'NotRun' }) {
    [pscustomobject]@{
        Name    = $test.ExpandedPath
        Result  = [string]$test.Result
        Message = (@($test.ErrorRecord) | Where-Object -FilterScript { $_ } | ForEach-Object -Process { $_.ToString() }) -join [Environment]::NewLine
    }
}

# A test file fails also when only its tests fail; it is listed only when it failed with an error of its own.
$failedFiles = foreach ($container in $result.Containers | Where-Object -FilterScript { $_.Result -eq 'Failed' -and @($_.ErrorRecord).Count -gt 0 }) {
    [pscustomobject]@{
        Name    = 'Test file {0}' -f $container.Item
        Result  = 'Failed'
        Message = (@($container.ErrorRecord) | Where-Object -FilterScript { $_ } | ForEach-Object -Process { $_.ToString() }) -join [Environment]::NewLine
    }
}

ConvertTo-Json -InputObject @(@($tests) + @($failedFiles)) -Depth 3 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
exit [int]($result.Result -ne 'Passed')
