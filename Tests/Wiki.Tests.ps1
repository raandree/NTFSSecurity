<#
    Tests .github\scripts\Export-WikiContent.ps1, which converts the documentation in Docs into the pages of the
    GitHub wiki: with a small sample of Docs for the conversion rules, and with the real Docs for complete pages and
    working links.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    $exportScript = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\Export-WikiContent.ps1'

    function Get-GitHubAnchor {
        # Returns the anchors that GitHub generates for the headings of a Markdown text.
        param (
            [Parameter(Mandatory)]
            [string]
            $Markdown
        )

        $text = [regex]::Replace($Markdown, '(?ms)^```.*?^```', '')
        $seen = @{}
        foreach ($match in [regex]::Matches($text, '(?m)^#{1,6}\s+(.+?)\s*#*\s*$')) {
            $heading = $match.Groups[1].Value -replace '\[([^\]]*)\]\([^)]*\)', '$1' -replace '[`*]', ''
            $anchor = [regex]::Replace($heading.Trim().ToLowerInvariant(), '[^\p{L}\p{Nd}\s_-]', '') -replace ' ', '-'
            if ($seen.ContainsKey($anchor)) {
                $seen[$anchor]++
                '{0}-{1}' -f $anchor, $seen[$anchor]
            } else {
                $seen[$anchor] = 0
                $anchor
            }
        }
    }
}

Describe 'Export-WikiContent.ps1' {
    Context 'When it converts a sample of Docs' {
        BeforeAll {
            $repositoryPath = Join-Path -Path $TestDrive -ChildPath 'repository'
            $docsPath = Join-Path -Path $repositoryPath -ChildPath 'Docs'
            $wikiPath = Join-Path -Path $TestDrive -ChildPath 'wiki'
            foreach ($folder in "$docsPath\Cmdlets", "$docsPath\Contributing", "$wikiPath\.git") {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
            }

            # A clone of the wiki with pages that Docs doesn't have
            Set-Content -LiteralPath "$wikiPath\.git\config" -Value '[core]'
            Set-Content -LiteralPath "$wikiPath\Version-History.textile" -Value '* 4.2.4'
            Set-Content -LiteralPath "$wikiPath\Old-Page.md" -Value '# Old page'

            Set-Content -LiteralPath "$repositoryPath\CHANGELOG.md" -Value '# Changelog'
            Set-Content -LiteralPath "$docsPath\Contributing.md" -Value '# Contributing'
            Set-Content -LiteralPath "$docsPath\Contributing\01-Getting-Started.md" -Value '# Get started'
            Set-Content -LiteralPath "$docsPath\Concepts.md" -Value "# Concepts`n`n## Rights`n`nSee [Home](README.md)."
            Set-Content -LiteralPath "$docsPath\README.md" -Value @'
# Thing

[Concepts](Concepts.md#rights), [Get-Thing](Cmdlets/Get-Thing.md), and [`Set-Thing`](Cmdlets/Set-Thing.md).
[Changelog](../CHANGELOG.md), [guide](Contributing.md), and [first steps](Contributing/01-Getting-Started.md).
[Example site](https://example.com/page.md) and [cmdlets](#cmdlets).
Code keeps its links: `[Concepts](Concepts.md)`.

```powershell
# [Concepts](Concepts.md)
```

## Installation

Install the module.

## Cmdlets

### Getting

| Cmdlet | Description |
| --- | --- |
| [Get-Thing](Cmdlets/Get-Thing.md) | Gets a thing. |

### Setting

| Cmdlet | Description |
| --- | --- |
| [Set-Thing](Cmdlets/Set-Thing.md) | Sets a thing. |
'@
            $metadata = "---`nexternal help file: Thing.dll-Help.xml`nonline version: https://example.com`nschema: 2.0.0`n---`n`n"
            Set-Content -LiteralPath "$docsPath\Cmdlets\Get-Thing.md" -Value ($metadata +
                "# Get-Thing`n`nSee [rights](../Concepts.md#rights), [Set-Thing](Set-Thing.md), and [home](../README.md).")
            Set-Content -LiteralPath "$docsPath\Cmdlets\Set-Thing.md" -Value ($metadata +
                "# Set-Thing`n`nSee [Get-Thing](Get-Thing.md).")

            & $exportScript -Path $docsPath -DestinationPath $wikiPath -RepositoryUrl 'https://github.com/contoso/Thing' -Branch 'main'

            $homePage = Get-Content -LiteralPath "$wikiPath\Home.md" -Raw
            $sidebar = Get-Content -LiteralPath "$wikiPath\_Sidebar.md" -Raw
        }

        It 'Should write Home, Concepts, the cmdlet pages, How-to-install, the sidebar, and the footer' {
            $expected = 'Home.md', 'Concepts.md', 'Get-Thing.md', 'Set-Thing.md', 'How-to-install.md', '_Sidebar.md', '_Footer.md'

            ((Get-ChildItem -LiteralPath $wikiPath -File).Name | Sort-Object) -join ', ' |
                Should -BeExactly (($expected | Sort-Object) -join ', ')
        }

        It 'Should keep the .git folder and remove the pages that Docs does not have' {
            "$wikiPath\.git\config" | Should -Exist
            "$wikiPath\Version-History.textile" | Should -Not -Exist
            "$wikiPath\Old-Page.md" | Should -Not -Exist
        }

        It 'Should not publish the contributor guide' {
            Get-ChildItem -LiteralPath $wikiPath -Recurse -File -Filter '*Get*Started*' | Should -BeNullOrEmpty
            "$wikiPath\Contributing.md" | Should -Not -Exist
        }

        It 'Should convert <Link> on <Page> into <Expected>' -ForEach @(
            @{ Page = 'Home'; Link = '[Concepts](Concepts.md#rights)'; Expected = '[Concepts](Concepts#rights)' }
            @{ Page = 'Home'; Link = '[Get-Thing](Cmdlets/Get-Thing.md)'; Expected = '[Get-Thing](Get-Thing)' }
            @{ Page = 'Home'; Link = '[`Set-Thing`](Cmdlets/Set-Thing.md)'; Expected = '[`Set-Thing`](Set-Thing)' }
            @{ Page = 'Home'; Link = '[Changelog](../CHANGELOG.md)'; Expected = '[Changelog](https://github.com/contoso/Thing/blob/main/CHANGELOG.md)' }
            @{ Page = 'Home'; Link = '[guide](Contributing.md)'; Expected = '[guide](https://github.com/contoso/Thing/blob/main/Docs/Contributing.md)' }
            @{ Page = 'Home'; Link = '[first steps](Contributing/01-Getting-Started.md)'; Expected = '[first steps](https://github.com/contoso/Thing/blob/main/Docs/Contributing/01-Getting-Started.md)' }
            @{ Page = 'Home'; Link = '[Example site](https://example.com/page.md)'; Expected = '[Example site](https://example.com/page.md)' }
            @{ Page = 'Home'; Link = '[cmdlets](#cmdlets)'; Expected = '[cmdlets](#cmdlets)' }
            @{ Page = 'Concepts'; Link = '[Home](README.md)'; Expected = '[Home](Home)' }
            @{ Page = 'Get-Thing'; Link = '[rights](../Concepts.md#rights)'; Expected = '[rights](Concepts#rights)' }
            @{ Page = 'Get-Thing'; Link = '[Set-Thing](Set-Thing.md)'; Expected = '[Set-Thing](Set-Thing)' }
            @{ Page = 'Get-Thing'; Link = '[home](../README.md)'; Expected = '[home](Home)' }
        ) {
            $content = Get-Content -LiteralPath "$wikiPath\$Page.md" -Raw

            $content | Should -Match ([regex]::Escape($Expected))
            if ($Link -ne $Expected) {
                $content | Should -Not -Match ([regex]::Escape($Link))
            }
        }

        It 'Should keep links in code unchanged' {
            $homePage | Should -Match ([regex]::Escape('`[Concepts](Concepts.md)`'))
            $homePage | Should -Match ([regex]::Escape('# [Concepts](Concepts.md)'))
        }

        It 'Should remove the platyPS metadata from the cmdlet pages' {
            Get-Content -LiteralPath "$wikiPath\Get-Thing.md" -TotalCount 1 | Should -BeExactly '# Get-Thing'
        }

        It 'Should link Home and the other pages in the sidebar' {
            $sidebar | Should -Match ([regex]::Escape('[Home](Home)'))
            $sidebar | Should -Match ([regex]::Escape('[Concepts](Concepts)'))
        }

        It 'Should list the cmdlets in the sidebar under the groups of Docs/README.md' {
            $sidebar | Should -Match '(?s)Getting.*\[Get-Thing\]\(Get-Thing\).*Setting.*\[Set-Thing\]\(Set-Thing\)'
        }

        It 'Should say in the footer that the wiki is generated from Docs' {
            Get-Content -LiteralPath "$wikiPath\_Footer.md" -Raw |
                Should -Match ([regex]::Escape('(https://github.com/contoso/Thing/tree/main/Docs)'))
        }

        It 'Should keep the address of the former page How-to-install' {
            Get-Content -LiteralPath "$wikiPath\How-to-install.md" -Raw | Should -Match ([regex]::Escape('(Home#installation)'))
        }
    }

    Context 'When it converts the documentation of the repository' {
        BeforeAll {
            $repositoryPath = Join-Path -Path $PSScriptRoot -ChildPath '..'
            $docsPath = Join-Path -Path $repositoryPath -ChildPath 'Docs'
            $wikiPath = Join-Path -Path $TestDrive -ChildPath 'wiki-of-the-repository'

            & $exportScript -Path $docsPath -DestinationPath $wikiPath

            $pages = Get-ChildItem -LiteralPath $wikiPath -Filter '*.md'
            $cmdletNames = (Get-ChildItem -LiteralPath (Join-Path -Path $docsPath -ChildPath 'Cmdlets') -Filter '*.md').BaseName
        }

        It 'Should write a page for every page in Docs except the contributor guide, and one for every cmdlet' {
            $topPages = (Get-ChildItem -LiteralPath $docsPath -Filter '*.md' |
                    Where-Object -Property Name -NotIn -Value 'README.md', 'Contributing.md').BaseName
            $expected = @('Home', 'How-to-install', '_Sidebar', '_Footer') + $topPages + $cmdletNames

            ($pages.BaseName | Sort-Object) -join ', ' | Should -BeExactly (($expected | Sort-Object) -join ', ')
        }

        It 'Should keep the page name Version-History, which the release notes of 4.2.4 and 4.2.6 link to' {
            Join-Path -Path $wikiPath -ChildPath 'Version-History.md' | Should -Exist
        }

        It 'Should list every cmdlet in the sidebar' {
            $sidebar = Get-Content -LiteralPath (Join-Path -Path $wikiPath -ChildPath '_Sidebar.md') -Raw

            $cmdletNames | Where-Object -FilterScript { $sidebar -notmatch ('\]\({0}\)' -f [regex]::Escape($_)) } |
                Should -BeNullOrEmpty
        }

        It 'Should link only to existing wiki pages, their anchors, and existing files of the repository' {
            $anchors = @{}
            foreach ($page in $pages) {
                $anchors[$page.BaseName] = @(Get-GitHubAnchor -Markdown (Get-Content -LiteralPath $page.FullName -Raw))
            }

            $brokenLinks = foreach ($page in $pages) {
                $text = [regex]::Replace((Get-Content -LiteralPath $page.FullName -Raw), '(?ms)^```.*?^```', '')
                $text = [regex]::Replace($text, '`[^`\n]+`', '')
                foreach ($match in [regex]::Matches($text, '\]\((?<url>[^)\s]+)\)')) {
                    $url = $match.Groups['url'].Value
                    if ($url -match '^https://github\.com/raandree/NTFSSecurity/(?:blob|tree)/master/(?<path>[^#]+)') {
                        if (-not (Test-Path -LiteralPath (Join-Path -Path $repositoryPath -ChildPath $Matches['path']))) {
                            '{0}: {1}' -f $page.BaseName, $url
                        }
                    } elseif ($url -notmatch '^[a-z]+:') {
                        $target, $anchor = $url -split '#', 2
                        if (-not $target) {
                            $target = $page.BaseName
                        }
                        if (-not $anchors.ContainsKey($target) -or ($anchor -and $anchors[$target] -notcontains $anchor)) {
                            '{0}: {1}' -f $page.BaseName, $url
                        }
                    }
                }
            }

            $brokenLinks | Should -BeNullOrEmpty
        }
    }
}
