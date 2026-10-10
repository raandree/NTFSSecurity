[CmdletBinding()]
param (
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string[]] $DomainController = @('OSDC1'),
    [string[]] $Member = @('OSFile19', 'OSFile22', 'OSFile25', 'OSWin11'),
    [Parameter(Mandatory)] [string] $OutFile
)

# Readiness and identity of the machines of an AutomatedLab lab for the live tests of NTFSSecurity, in Windows PowerShell 5.1 on the
# Hyper-V host. It proves what the tests need, not that a VM runs: authenticated WinRM through AutomatedLab, the operating system
# build, the domain, the clock against the host, LDAP and a Kerberos ticket (a domain controller), or the secure channel, the domain
# controller locator and a service ticket for a peer (a member), the PowerShell 7 and Pester payloads, and the ports of SMB, RPC, and
# WinRM from the host. Nothing is changed in the lab. Passwords are never read or printed.
& {
    $ErrorActionPreference = 'Stop'
    # -File passes an array as one string, so a list may arrive as 'A,B'.
    $DomainController = @($DomainController | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    $Member = @($Member | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    '[{0:yyyy-MM-dd HH:mm:ss}Z] START matrix-readiness lab={1}' -f [DateTime]::UtcNow, $LabName
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $labCommand = @{ NoDisplay = $true; PassThru = $true; ErrorAction = 'Stop' }
    $everyMachine = @($DomainController) + @($Member)
    $peerByMember = @{}
    foreach ($name in $Member) { $peerByMember[$name] = @($Member | Where-Object -FilterScript { $_ -ne $name })[0] }
    foreach ($name in $everyMachine) {
        $address = (Get-LabVM -ComputerName $name).IpV4Address
        $wsman = try { $null = Test-WSMan -ComputerName $address -ErrorAction Stop; 'ok' } catch { "failed: $($_.Exception.Message)" }
        $ports = foreach ($port in 135, 445, 5985) {
            $client = New-Object -TypeName 'System.Net.Sockets.TcpClient'
            try { $open = $client.ConnectAsync($address, $port).Wait(3000) } catch { $open = $false } finally { $client.Dispose() }
            '{0}={1}' -f $port, $open
        }

        $hostUtc = [DateTime]::UtcNow
        $state = Invoke-LabCommand -ComputerName $name -ActivityName "Readiness of $name" -ScriptBlock {
            param ([bool] $IsDomainController, [string] $Peer)
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $computer = Get-CimInstance -ClassName Win32_ComputerSystem
            $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
            $dotNet = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
            $pwshPath = Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe'
            $result = [ordered]@{
                Os         = '{0} {1}.{2}' -f $os.Caption, $os.Version, $version.UBR
                ProductType = $os.ProductType
                Edition    = $version.EditionID
                Domain     = $computer.Domain
                Utc        = [DateTime]::UtcNow
                DotNet     = $dotNet
                WindowsPowerShell = $PSVersionTable.PSVersion.ToString()
                PowerShell7 = $(if (Test-Path -LiteralPath $pwshPath) { (Get-Item -LiteralPath $pwshPath).VersionInfo.ProductVersion } else { 'missing' })
                PesterDesktop = $(@(Get-Module -Name Pester -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1 | ForEach-Object -Process { $_.Version.ToString() }) -join '')
                PesterCore = $(if (Test-Path -LiteralPath (Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\Modules\Pester\5.7.1\Pester.psd1')) { '5.7.1' } else { 'missing' })
                Ldap       = ''
                Channel    = ''
                Kerberos   = ''
            }
            if ($IsDomainController) {
                $rootDse = [adsi]'LDAP://RootDSE'
                $result.Ldap = 'RootDSE {0}, synchronized {1}' -f $rootDse.dnsHostName.Value, $rootDse.isSynchronized.Value
                $result.Kerberos = (& klist.exe get "krbtgt/$($computer.Domain)" 2>&1 | Select-String -Pattern 'Error|Server: krbtgt' | Select-Object -First 1).Line
            }
            else {
                $result.Ldap = (& nltest.exe "/dsgetdc:$($computer.Domain)" 2>&1 | Select-String -Pattern '^\s*DC: |ERROR' | Select-Object -First 1).Line
                $result.Channel = 'secure channel {0}' -f (Test-ComputerSecureChannel)
                $result.Kerberos = (& klist.exe get "host/$Peer.$($computer.Domain)" 2>&1 | Select-String -Pattern 'Error|Server: host' | Select-Object -First 1).Line
            }

            [pscustomobject] $result
        } -ArgumentList ($name -in $DomainController), $peerByMember[$name] @labCommand
        $skew = [Math]::Round(($state.Utc - $hostUtc).TotalSeconds, 1)
        '{0,-9} wsman={1} ports({2}) os={3} type={4} edition={5} domain={6} skew={7}s' -f $name, $wsman, ($ports -join ' '), $state.Os, $state.ProductType, $state.Edition, $state.Domain, $skew
        '          .NET release={0}; Windows PowerShell {1}; PowerShell 7 {2}; Pester Desktop {3}, Core {4}' -f $state.DotNet, $state.WindowsPowerShell, $state.PowerShell7, $state.PesterDesktop, $state.PesterCore
        '          ldap: {0}' -f ("$($state.Ldap)".Trim())
        if ($state.Channel) { '          {0}' -f $state.Channel }
        '          kerberos: {0}' -f ("$($state.Kerberos)".Trim())
    }

    '[{0:yyyy-MM-dd HH:mm:ss}Z] matrix-readiness-DONE' -f [DateTime]::UtcNow
} *>&1 | Out-File -FilePath $OutFile -Encoding utf8 -Width 400
