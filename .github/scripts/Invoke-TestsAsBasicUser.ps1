<#
.SYNOPSIS
    Runs the Pester tests as a basic user, without the privileges and the Administrators group of the current account.

.DESCRIPTION
    Some tests need a session without the Security, Restore, or Create Symbolic Link privilege, and skip in an elevated
    session such as that of a GitHub runner. This script derives a token of the SAFER level Normal User from the token
    of the current process, as runas /trustlevel:0x20000 does: the Administrators group is deny-only, and only the
    privilege to bypass traverse checking stays. It starts Invoke-Tests.ps1 in the same PowerShell edition with that
    token, waits for it, prints its output, and fails if the tests failed. The job summary of GitHub Actions gets the
    results through a file of this account, which the restricted token can write.

.PARAMETER ResultPath
    Specifies the path of the result file in the NUnit format.

.PARAMETER Title
    Specifies the heading of the test results in the job summary.

.EXAMPLE
    .\.github\scripts\Invoke-TestsAsBasicUser.ps1 -ResultPath TestResults\WindowsPowerShell-BasicUser.xml -Title 'Windows PowerShell 5.1 as a basic user'

    Runs the tests in Windows PowerShell 5.1 as a basic user.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ResultPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Title
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class NTFSSecurityBasicUserProcess
{
    private const uint SaferScopeIdUser = 2;
    private const uint SaferLevelIdNormalUser = 0x20000;
    private const uint SaferLevelOpen = 1;
    private const uint CreateNoWindow = 0x08000000;
    private const uint Infinite = 0xFFFFFFFF;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo
    {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX;
        public int dwY;
        public int dwXSize;
        public int dwYSize;
        public int dwXCountChars;
        public int dwYCountChars;
        public int dwFillAttribute;
        public int dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SaferCreateLevel(uint scopeId, uint levelId, uint openFlags, out IntPtr levelHandle, IntPtr reserved);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SaferComputeTokenFromLevel(IntPtr levelHandle, IntPtr inAccessToken, out IntPtr outAccessToken, uint flags, IntPtr reserved);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SaferCloseLevel(IntPtr levelHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CreateProcessAsUser(IntPtr token, string applicationName, string commandLine, IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint creationFlags, IntPtr environment, string currentDirectory, ref StartupInfo startupInfo, out ProcessInformation processInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    // Starts the command line with a token of the SAFER level Normal User, waits for it, and returns its exit code.
    public static int Run(string applicationName, string commandLine, string currentDirectory)
    {
        IntPtr level;
        if (!SaferCreateLevel(SaferScopeIdUser, SaferLevelIdNormalUser, SaferLevelOpen, out level, IntPtr.Zero))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        IntPtr token = IntPtr.Zero;
        try
        {
            if (!SaferComputeTokenFromLevel(level, IntPtr.Zero, out token, 0, IntPtr.Zero))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            var startupInfo = new StartupInfo();
            startupInfo.cb = Marshal.SizeOf(typeof(StartupInfo));
            ProcessInformation processInformation;
            if (!CreateProcessAsUser(token, applicationName, commandLine, IntPtr.Zero, IntPtr.Zero, false, CreateNoWindow, IntPtr.Zero, currentDirectory, ref startupInfo, out processInformation))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            try
            {
                WaitForSingleObject(processInformation.hProcess, Infinite);
                uint exitCode;
                if (!GetExitCodeProcess(processInformation.hProcess, out exitCode))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                return (int)exitCode;
            }
            finally
            {
                CloseHandle(processInformation.hThread);
                CloseHandle(processInformation.hProcess);
            }
        }
        finally
        {
            if (token != IntPtr.Zero)
            {
                CloseHandle(token);
            }

            SaferCloseLevel(level);
        }
    }
}
'@

$repositoryPath = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..')).ProviderPath
$resultFullPath = [IO.Path]::GetFullPath((Join-Path -Path $repositoryPath -ChildPath $ResultPath))
$resultFolder = Split-Path -Path $resultFullPath -Parent
if (-not (Test-Path -LiteralPath $resultFolder)) {
    New-Item -ItemType Directory -Path $resultFolder | Out-Null
}

$runFolder = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('NTFSSecurity.BasicUser-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $runFolder | Out-Null
$logPath = Join-Path -Path $runFolder -ChildPath 'Output.log'
$summaryPath = Join-Path -Path $runFolder -ChildPath 'Summary.md'
# In the temp folder of the account, which the restricted token can write, unlike maybe the folder of the repository
$runResultPath = Join-Path -Path $runFolder -ChildPath 'Result.xml'

$executable = (Get-Process -Id $PID).Path
$testScript = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-Tests.ps1'
# cmd redirects the output of the tests, which have no console of their own.
$commandLine = 'cmd.exe /d /s /c ""{0}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -ResultPath "{2}" -Title "{3}" > "{4}" 2>&1"' -f
    $executable, $testScript, $runResultPath, $Title.Replace('"', "'"), $logPath

$stepSummary = $env:GITHUB_STEP_SUMMARY
$env:GITHUB_STEP_SUMMARY = $summaryPath
try {
    "Running the tests as a basic user: $commandLine"
    $exitCode = [NTFSSecurityBasicUserProcess]::Run((Join-Path -Path $env:SystemRoot -ChildPath 'System32\cmd.exe'), $commandLine, $repositoryPath)
}
finally {
    $env:GITHUB_STEP_SUMMARY = $stepSummary
}

if (Test-Path -LiteralPath $logPath) {
    Get-Content -LiteralPath $logPath
}

if ($stepSummary -and (Test-Path -LiteralPath $summaryPath)) {
    $encoding = New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false
    [IO.File]::AppendAllText($stepSummary, [IO.File]::ReadAllText($summaryPath), $encoding)
}

if (Test-Path -LiteralPath $runResultPath) {
    Copy-Item -LiteralPath $runResultPath -Destination $resultFullPath -Force
}

Remove-Item -LiteralPath $runFolder -Recurse -Force
if ($exitCode -ne 0) {
    throw "The tests as a basic user failed with exit code $exitCode."
}
