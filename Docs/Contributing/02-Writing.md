# Write documentation

The NTFSSecurity documentation is written in Markdown and built into a
website with [MkDocs][mkdocs]. This page explains how the documentation is
organized and how to change it.

## Documentation structure

| Path | Content |
| --- | --- |
| `Docs/index.md` | Home page with features, requirements, and the cmdlet list |
| `Docs/Concepts.md` | Background on security descriptors, rights, inheritance, and privileges |
| `Docs/Examples.md` | Task-oriented examples |
| `Docs/Cmdlets/*.md` | One reference page per cmdlet, in platyPS format |
| `NTFSSecurity/en-US/NTFSSecurity.dll-Help.xml` | Help file that `Get-Help` shows, generated from `Docs/Cmdlets` |
| `Docs/Contributing.md`, `Docs/Contributing/*.md` | This contributor guide |
| `mkdocs.yml` | Site settings and navigation |
| `.readthedocs.yml` | Build settings for Read the Docs |
| `README.md` | Front page of the GitHub repository |

When you add a page, add it to the `nav` section of `mkdocs.yml`.

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
`NTFSSecurity\bin\Release`; the `before_build` and `build_script` steps in
`appveyor.yml` show the commands that the CI build uses:

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
the page to `mkdocs.yml`. Replace `Get-NTFSExample` with the name of the new
cmdlet:

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

## Preview the website

MkDocs needs Python. Install the MkDocs version that the site is built with
and start the preview server:

```powershell
pip install -r Docs/requirements.txt
mkdocs serve
```

Open `http://127.0.0.1:8000` in a browser. The preview reloads when you save
a file. Run `mkdocs build --strict` to find broken links and pages that are
missing from the navigation.

## Check your change

Before you open a pull request, check the following:

- No page in `Docs/Cmdlets` contains a `{{ ... }}` placeholder.
- `Update-MarkdownHelp` doesn't change any page in `Docs/Cmdlets`. The build
  defined in `appveyor.yml` runs the same check.
- `New-ExternalHelp` doesn't change
  `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`. The build runs the same
  check.
- The Pester tests in `Tests` pass. They test the module in
  `NTFSSecurity\bin\Release`, for example that `Get-Help` shows every page.
  The build runs them in Windows PowerShell 5.1 with Pester 5.7.1:

  ```powershell
  Install-Module -Name Pester -RequiredVersion 5.7.1 -SkipPublisherCheck
  Import-Module -Name Pester -RequiredVersion 5.7.1
  Invoke-Pester -Path .\Tests -Output Detailed
  ```

- All links work. The build checks them with `Get-MarkdownLink` from the
  MarkdownLinkCheck module:

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
[mkdocs]: https://www.mkdocs.org/user-guide/writing-your-docs/
[platyps]: https://github.com/PowerShell/platyPS
[label-documentation]: https://github.com/raandree/NTFSSecurity/labels/Documentation
[label-help-wanted]: https://github.com/raandree/NTFSSecurity/labels/Help%20Wanted
