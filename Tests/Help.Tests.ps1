<#
    Tests that Get-Help shows the help that is generated from Docs/Cmdlets for
    every cmdlet of the module built in NTFSSecurity\bin\Release.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    $pagePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Docs\Cmdlets'
    $sectionPattern = '(?ms)^## (?<Heading>[A-Z ]+?)\s*$(?<Text>.*?)(?=^## |\z)'

    $helpPages = foreach ($page in Get-ChildItem -Path $pagePath -Filter '*.md') {
        $content = Get-Content -LiteralPath $page.FullName -Raw
        $sections = @{}
        foreach ($match in [regex]::Matches($content, $sectionPattern)) {
            $sections[$match.Groups['Heading'].Value] = $match.Groups['Text'].Value
        }

        $parameterNames = [regex]::Matches("$($sections['PARAMETERS'])", '(?m)^### -(?<Name>\w+)') |
            ForEach-Object -Process { $_.Groups['Name'].Value }

        @{
            CommandName    = $page.BaseName
            Synopsis       = "$($sections['SYNOPSIS'])".Trim()
            ExampleCount   = [regex]::Matches("$($sections['EXAMPLES'])", '(?m)^### ').Count
            ParameterNames = @($parameterNames)
            OnlineUri      = [regex]::Match($content, '(?m)^online version: (?<Uri>\S+)').Groups['Uri'].Value
        }
    }
}

Describe 'Help of the NTFSSecurity cmdlets' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
        $module = Import-Module -Name $modulePath -Force -PassThru -ErrorAction Stop
        $pagePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Docs\Cmdlets'

        <#
            With this test hook, Get-Help -Online returns the URI instead of opening a browser. In PowerShell 7,
            the hook also makes Get-Help ignore the help file, so this test runs only in Windows PowerShell.
        #>
        $testHooks = [psobject].Assembly.GetType('System.Management.Automation.Internal.InternalTestHooks')
        $bypassOnlineHelp = if ($testHooks -and $PSVersionTable.PSEdition -ne 'Core') {
            $testHooks.GetField('BypassOnlineHelpRetrieval', [Reflection.BindingFlags] 'NonPublic, Static')
        }
    }

    AfterAll {
        Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
    }

    It 'Should ship the help file in the en-US folder' {
        Join-Path -Path $module.ModuleBase -ChildPath 'en-US\NTFSSecurity.dll-Help.xml' | Should -Exist
    }

    It 'Should have a page in Docs/Cmdlets for every exported cmdlet' {
        $pageNames = (Get-ChildItem -Path $pagePath -Filter '*.md').BaseName | Sort-Object
        $cmdletNames = (Get-Command -Module NTFSSecurity -CommandType Cmdlet).Name | Sort-Object

        $cmdletNames -join ', ' | Should -BeExactly ($pageNames -join ', ')
    }

    Context '<CommandName>' -ForEach $helpPages {
        BeforeAll {
            $help = Get-Help -Name $CommandName -Full
        }

        It 'Should show the synopsis from Docs/Cmdlets' {
            "$($help.Synopsis)".Trim() | Should -BeExactly $Synopsis
        }

        It 'Should describe the parameters from Docs/Cmdlets' {
            $describedParameterNames = foreach ($parameter in $help.parameters.parameter) {
                if (($parameter.description.Text -join '').Trim()) {
                    $parameter.name
                }
            }

            ($describedParameterNames | Sort-Object) -join ', ' |
                Should -BeExactly (($ParameterNames | Sort-Object) -join ', ')
        }

        It 'Should show the <ExampleCount> examples from Docs/Cmdlets' {
            @($help.examples.example | Where-Object -FilterScript { $_ }) | Should -HaveCount $ExampleCount
        }

        It 'Should link to the online version from Docs/Cmdlets' {
            @($help.relatedLinks.navigationLink)[0].uri | Should -BeExactly $OnlineUri
        }

        It 'Should keep the space after each link in the help text' {
            # platyPS writes an inline link as "text (url)" and drops the space that follows it.
            $help | Out-String -Width 4096 | Should -Not -Match '\((?:\.\./|https?://)[^)\s]+\)\w'
        }

        It 'Should open the online version with Get-Help -Online' {
            if (-not $bypassOnlineHelp) {
                $reason = 'the test hook for Get-Help -Online reads the help file only in Windows PowerShell'
                Set-ItResult -Skipped -Because $reason
                return
            }

            $bypassOnlineHelp.SetValue($null, $true)
            try {
                $onlineHelp = Get-Help -Name $CommandName -Online
            } finally {
                $bypassOnlineHelp.SetValue($null, $false)
            }

            "$onlineHelp" | Should -Match ('{0}$' -f [regex]::Escape($OnlineUri))
        }
    }
}
