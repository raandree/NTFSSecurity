# Write documentation

The NTFSSecurity documentation is written in Markdown and lives in the
`Docs` folder of the repository, where GitHub renders it. GitHub Actions also
publishes it to the [wiki](https://github.com/raandree/NTFSSecurity/wiki).
This page explains how the documentation is organized and how to change it.

## Documentation structure

| Path | Content |
| --- | --- |
| `Docs/README.md` | Home page with features, requirements, installation, and the cmdlet list; GitHub shows it when you open the `Docs` folder |
| `Docs/Concepts.md` | Background on security descriptors, rights, inheritance, and privileges |
| `Docs/Examples.md` | Task-oriented examples |
| `Docs/Version-History.md` | Changes in 4.2.6 and earlier |
| `Docs/Cmdlets/*.md` | One reference page per cmdlet, in platyPS format |
| `NTFSSecurity/en-US/NTFSSecurity.dll-Help.xml` | Help file that `Get-Help` shows, generated from `Docs/Cmdlets` |
| `Docs/Contributing.md`, `Docs/Contributing/*.md` | This contributor guide |
| `README.md` | Front page of the GitHub repository |
| `CHANGELOG.md` | Changes since 4.2.6 |
| `.github/workflows/ci.yml` | CI build: documentation checks, tests, packages, wiki publishing, and releases |
| `.github/scripts/Export-WikiContent.ps1` | Converts `Docs` into the pages of the wiki |

When you add a page, link to it from `Docs/README.md` or from a related page,
so that readers can find it.

## Markdown editors

Any text editor works. These editors have good Markdown support:

- [Visual Studio Code](https://code.visualstudio.com) with the
  [markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)
  extension
- [Sublime Text](https://www.sublimetext.com/)

To get started with Markdown, see
[How to use Markdown for writing Docs](https://learn.microsoft.com/contribute/content/markdown-reference).
Don't use hard tabs. For the rules that apply to this repository, see
[Markdown and platyPS specifics](04-Markdown-Specifics.md).

## Update the cmdlet reference

The pages in `Docs/Cmdlets` are [platyPS][platyps] Markdown files. platyPS
reads the parameter metadata from the module, so the syntax and the parameter
details always match the code. You write the synopsis, the description, the
parameter descriptions, the examples, and the notes.

When a cmdlet changes, build the module, import the build output, and update
the pages in Windows PowerShell 5.1. A Release build writes the module to
`NTFSSecurity\bin\Release`; the steps "Restore the NuGet packages" and "Build
the module" in `.github/workflows/ci.yml` show the commands that the CI build
uses:

```powershell
Install-Module -Name platyPS -RequiredVersion 0.14.2
Import-Module -Name .\NTFSSecurity\bin\Release\NTFSSecurity.psd1
Update-MarkdownHelp -Path .\Docs\Cmdlets
```

`Update-MarkdownHelp` updates the syntax and the parameter metadata and keeps
the text that you wrote. Fill in the description of every new parameter.

Use Windows PowerShell 5.1 for platyPS. In PowerShell 7.4 and later,
platyPS 0.14.2 adds the `-ProgressAction` common parameter to every page.

For a new cmdlet, create the page, replace every placeholder in it, and add
the cmdlet to the cmdlet list in `Docs/README.md`. Replace `Get-NTFSExample`
with the name of the new cmdlet:

```powershell
New-MarkdownHelp -Command Get-NTFSExample -OutputFolder .\Docs\Cmdlets
```

`Get-Help` shows the help file `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`,
which `New-ExternalHelp` generates from the pages and the build copies into
the module. Whenever you change a page in `Docs/Cmdlets`, generate the file
again and commit it together with the page:

```powershell
New-ExternalHelp -Path .\Docs\Cmdlets -OutputPath .\NTFSSecurity\en-US -Force
```

## Preview your change

GitHub renders the pages with GitHub Flavored Markdown. To preview a page
before you push it, open it in Visual Studio Code and press **Ctrl+Shift+V**.
In a pull request, the **Files changed** tab shows a changed page rendered
when you open its menu (**...**) and select **View file**.

## Publish to the wiki

After every push to `master`, the CI workflow converts the pages in `Docs`,
except this contributor guide, into the pages of the
[wiki](https://github.com/raandree/NTFSSecurity/wiki) and publishes them.
`Docs/README.md` becomes the home page, every cmdlet page becomes a page with
the name of the cmdlet, and the sidebar lists the cmdlets in the groups of the
cmdlet list in `Docs/README.md`. Don't edit the wiki itself; the next push
overwrites it.

For a pull request, the summary of the CI run lists the wiki pages that would
change. To look at the pages before you push, write them into a clone of the
wiki:

```powershell
git clone https://github.com/raandree/NTFSSecurity.wiki.git $env:TEMP\wiki
.\.github\scripts\Export-WikiContent.ps1 -Path .\Docs -DestinationPath $env:TEMP\wiki
```

## Check your change

Before you open a pull request, check the following:

- No page in `Docs/Cmdlets` contains a `{{ ... }}` placeholder.
- `Update-MarkdownHelp` doesn't change any page in `Docs/Cmdlets`. The CI
  workflow runs the same check.
- `New-ExternalHelp` doesn't change
  `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`. The CI workflow runs the
  same check.
- The Pester tests in `Tests` pass. They test the module in
  `NTFSSecurity\bin\Release`, for example that `Get-Help` shows every page,
  and the conversion to the wiki. The CI workflow runs them in Windows
  PowerShell 5.1 and in PowerShell 7 with Pester 5.7.1:

  ```powershell
  Install-Module -Name Pester -RequiredVersion 5.7.1 -SkipPublisherCheck
  Import-Module -Name Pester -RequiredVersion 5.7.1
  Invoke-Pester -Path .\Tests -Output Detailed
  ```

- All links work. The CI workflow checks them with `Get-MarkdownLink` from
  the MarkdownLinkCheck module:

  ```powershell
  Get-MarkdownLink -Path .\Docs -BrokenOnly
  ```

- Every example works. Test examples in a test folder, never on production
  data.

## Create new topics

Before you write a new topic, check the issues labeled
[Documentation][label-documentation] or [Help Wanted][label-help-wanted] to
make sure nobody else is working on it. If nobody is, open an issue that
describes the topic and say that you're working on it. Then follow the
workflow for larger changes in [Get started](01-Getting-Started.md).

## Next steps

Read the [Style guide](03-Style-Guide.md).

<!-- External URLs -->
[platyps]: https://github.com/PowerShell/platyPS
[label-documentation]: https://github.com/raandree/NTFSSecurity/labels/Documentation
[label-help-wanted]: https://github.com/raandree/NTFSSecurity/labels/Help%20Wanted
