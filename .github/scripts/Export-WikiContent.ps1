<#
.SYNOPSIS
    Converts the documentation in the Docs folder into the pages of the GitHub wiki.

.DESCRIPTION
    Writes a wiki page for every page in Docs except the contributor guide (Contributing.md and the Contributing
    folder). Docs/README.md becomes the page Home, and every other page keeps its file name, so a page in
    Docs/Cmdlets becomes a page named after its cmdlet. The platyPS metadata at the top of the cmdlet pages is
    removed. Relative links point to the wiki pages; links to other files of the repository point to the files on
    GitHub. Links in code stay unchanged.

    The script also writes the sidebar, which lists the cmdlets in the groups of the cmdlet list in Docs/README.md;
    the footer; and the page How-to-install, which keeps the address of the former wiki page working.

    The script removes everything in DestinationPath except the .git folder, so that pages that no longer exist in
    Docs disappear from the wiki.

.PARAMETER Path
    Specifies the Docs folder of the repository.

.PARAMETER DestinationPath
    Specifies the folder to write the wiki pages to, usually a clone of the wiki repository. The script creates the
    folder if it doesn't exist.

.PARAMETER RepositoryUrl
    Specifies the address of the repository on GitHub, for links to files that aren't wiki pages.

.PARAMETER Branch
    Specifies the branch for links to files that aren't wiki pages.

.EXAMPLE
    git clone https://github.com/raandree/NTFSSecurity.wiki.git $env:TEMP\wiki
    .\.github\scripts\Export-WikiContent.ps1 -Path .\Docs -DestinationPath $env:TEMP\wiki
    git -C $env:TEMP\wiki status

    Writes the wiki pages into a clone of the wiki and shows which pages change.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]
    $Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $DestinationPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $RepositoryUrl = 'https://github.com/raandree/NTFSSecurity',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Branch = 'master'
)

$ErrorActionPreference = 'Stop'

function Resolve-RepositoryPath {
    <#
        Returns the path of a link target relative to the repository root, with / as separator, or nothing if the
        link leaves the repository.
    #>
    param (
        [Parameter(Mandatory)]
        [string]
        $Directory,

        [Parameter(Mandatory)]
        [string]
        $Link
    )

    $segments = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($segment in (('{0}/{1}' -f $Directory, $Link) -split '/')) {
        if ($segment -eq '..') {
            if ($segments.Count -eq 0) {
                return
            }
            $segments.RemoveAt($segments.Count - 1)
        } elseif ($segment -and $segment -ne '.') {
            $segments.Add($segment)
        }
    }

    $segments -join '/'
}

function ConvertTo-WikiLink {
    <#
        Returns the wiki address of a link on a page in Directory: the name of a wiki page, the address of a file of
        the repository on GitHub, or the link itself if it is absolute or points to the same page.
    #>
    param (
        [Parameter(Mandatory)]
        [string]
        $Url,

        [Parameter(Mandatory)]
        [string]
        $Directory
    )

    if ($Url -match '^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|//|#)') {
        return $Url
    }

    $linkPath, $anchor = $Url -split '#', 2
    $target = Resolve-RepositoryPath -Directory $Directory -Link ([uri]::UnescapeDataString($linkPath))
    if (-not $target) {
        return $Url
    }

    $fragment = if ($anchor) { '#' + $anchor } else { '' }
    if ($pageNames.ContainsKey($target)) {
        return $pageNames[$target] + $fragment
    }

    $view = if (Test-Path -LiteralPath (Join-Path -Path $repositoryRoot -ChildPath $target) -PathType Container) {
        'tree'
    } else {
        'blob'
    }
    '{0}/{1}/{2}/{3}{4}' -f $RepositoryUrl.TrimEnd('/'), $view, $Branch, $target, $fragment
}

function Convert-MarkdownLink {
    <#
        Returns the Markdown text with the links of a page in Directory converted to wiki addresses. Links in code
        spans and fenced code blocks stay unchanged.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', 'Directory', Justification = 'The match evaluator script block uses it.'
    )]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]
        $Markdown,

        [Parameter(Mandatory)]
        [string]
        $Directory
    )

    $inlinePattern = '(?<code>(?<ticks>`+).+?\k<ticks>)|(?<prefix>!?\[(?:[^\[\]`]|`[^`]*`)*\]\()(?<url>[^)\s]+)(?<suffix>(?:\s+"[^"]*")?\))'
    $definitionPattern = '^(?<prefix>\s{0,3}\[[^\]]+\]:\s*)(?<url>\S+)(?<suffix>.*)$'
    $convertLink = {
        param ($match)

        if ($match.Groups['code'].Success) {
            return $match.Value
        }
        $match.Groups['prefix'].Value + (ConvertTo-WikiLink -Url $match.Groups['url'].Value -Directory $Directory) +
            $match.Groups['suffix'].Value
    }

    $fence = $null
    $lines = foreach ($line in ($Markdown -split '\r?\n')) {
        if ($line -match '^\s{0,3}(?<fence>`{3,}|~{3,})') {
            if (-not $fence) {
                $fence = $Matches['fence']
            } elseif ($Matches['fence'].StartsWith($fence)) {
                $fence = $null
            }
            $line
            continue
        }
        if ($fence) {
            $line
            continue
        }

        $line = [regex]::Replace($line, $inlinePattern, $convertLink)
        [regex]::Replace($line, $definitionPattern, $convertLink)
    }

    $lines -join "`n"
}

$docsRoot = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
$repositoryRoot = Split-Path -Path $docsRoot -Parent
$docsName = Split-Path -Path $docsRoot -Leaf
$destinationRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath).TrimEnd('\', '/')

# Refuse a destination that contains the documentation, such as the repository itself.
$separator = [IO.Path]::DirectorySeparatorChar
if (($docsRoot + $separator).StartsWith($destinationRoot + $separator, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The destination '$destinationRoot' contains the documentation in '$docsRoot'. Specify a clone of the wiki."
}

# Collect the pages: Docs/README.md is the home page, and the contributor guide stays in the repository.
$pageNames = @{}
$pages = foreach ($file in Get-ChildItem -LiteralPath $docsRoot -Filter '*.md' -File -Recurse) {
    $repositoryPath = $file.FullName.Substring($repositoryRoot.Length + 1) -replace '\\', '/'
    if ($repositoryPath -match ('^{0}/Contributing(?:\.md$|/)' -f [regex]::Escape($docsName))) {
        continue
    }

    $name = if ($repositoryPath -eq "$docsName/README.md") { 'Home' } else { $file.BaseName }
    if ($pageNames.Values -contains $name) {
        throw "Two pages in '$docsRoot' would become the wiki page '$name'."
    }
    $pageNames[$repositoryPath] = $name

    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $title = if ($content -match '(?m)^#\s+(?<title>.+?)\s*$') { $Matches['title'] } else { $name -replace '-', ' ' }
    [pscustomobject]@{
        Name      = $name
        Title     = $title
        Directory = $repositoryPath.Substring(0, $repositoryPath.LastIndexOf('/'))
        Content   = $content
    }
}

# Remove the old pages, but keep the history of the wiki.
if (Test-Path -LiteralPath $destinationRoot) {
    foreach ($item in Get-ChildItem -LiteralPath $destinationRoot -Force | Where-Object -Property Name -NE -Value '.git') {
        if ($PSCmdlet.ShouldProcess($item.FullName, 'Remove')) {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
        }
    }
} elseif ($PSCmdlet.ShouldProcess($destinationRoot, 'Create folder')) {
    New-Item -ItemType Directory -Path $destinationRoot | Out-Null
}

$wikiPages = [ordered]@{}
foreach ($page in $pages) {
    $content = [regex]::Replace($page.Content, '\A---\r?\n.*?\r?\n---[ \t]*(?:\r?\n|\z)\s*', '', 'Singleline')
    $wikiPages[$page.Name] = Convert-MarkdownLink -Markdown $content -Directory $page.Directory
}

# The sidebar links the other pages and the cmdlets, grouped like the cmdlet list of the home page.
$homePage = $pages | Where-Object -Property Name -EQ -Value 'Home'
$sidebar = New-Object -TypeName 'System.Collections.Generic.List[string]'
$sidebar.Add('### [Home](Home)')
$sidebar.Add('')
foreach ($page in $pages | Where-Object { $_.Directory -eq $docsName -and $_.Name -ne 'Home' } | Sort-Object -Property Name) {
    $sidebar.Add(('- [{0}]({1})' -f $page.Title, $page.Name))
}
if ($homePage) {
    $section = $null
    foreach ($line in ($homePage.Content -split '\r?\n')) {
        if ($line -match '^##\s+(?<title>.+?)\s*$') {
            $section = $Matches['title']
            if ($section -eq 'Cmdlets') {
                $sidebar.Add('')
                $sidebar.Add('### Cmdlets')
            }
        } elseif ($section -eq 'Cmdlets' -and $line -match '^###\s+(?<title>.+?)\s*$') {
            $sidebar.Add('')
            $sidebar.Add(('**{0}**' -f $Matches['title']))
            $sidebar.Add('')
        } elseif ($section -eq 'Cmdlets' -and $line -match '^\|\s*\[(?<name>[^\]]+)\]\((?<url>[^)\s]+)\)') {
            $sidebar.Add(('- [{0}]({1})' -f $Matches['name'], (ConvertTo-WikiLink -Url $Matches['url'] -Directory $docsName)))
        }
    }
}
$wikiPages['_Sidebar'] = $sidebar -join "`n"

$wikiPages['_Footer'] = ('This wiki is generated from the [{0}]({1}/tree/{2}/{0}) folder of the repository. ' +
    'To change a page, edit its file there; changes made in the wiki are overwritten.') -f $docsName, $RepositoryUrl.TrimEnd('/'), $Branch

# The former wiki page How-to-install is linked from outside; it now points to the installation steps.
if ($homePage -and $homePage.Content -match '(?m)^##\s+Installation\s*$') {
    $wikiPages['How-to-install'] = "# How to install`n`nThe installation steps are in the [Installation](Home#installation) section of the [Home](Home) page."
}

$encoding = New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false
foreach ($name in $wikiPages.Keys) {
    $file = Join-Path -Path $destinationRoot -ChildPath "$name.md"
    if ($PSCmdlet.ShouldProcess($file, 'Write wiki page')) {
        [IO.File]::WriteAllText($file, $wikiPages[$name].TrimEnd() + "`n", $encoding)
    }
}
