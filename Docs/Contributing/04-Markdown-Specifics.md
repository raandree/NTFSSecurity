# Markdown and platyPS specifics

This page lists the Markdown rules for the NTFSSecurity documentation and
the additional rules for the cmdlet reference pages, which platyPS processes.

## Markdown

- Use ATX headings (`#`), one level 1 heading per page, and don't skip
  heading levels.
- Use `-` for bulleted lists and `1.` for numbered lists.
- Surround headings, lists, tables, and code blocks with blank lines.
- Give every fenced code block a language, for example `powershell`.
- Don't use hard tabs or trailing spaces.
- Link to other pages with relative links to the `.md` file, for example
  `[Concepts](Concepts.md)` or `[Get-NTFSAccess](Cmdlets/Get-NTFSAccess.md)`.
  MkDocs converts them to links to the generated pages.
- End every file with a single newline.

## Cmdlet reference pages

platyPS converts the pages in `Docs/Cmdlets` to the help file that `Get-Help`
shows and updates the pages from the module. Keep the structure that platyPS
expects:

- Keep the front matter. `external help file`, `Module Name`, and `schema`
  must stay as they are. `online version` is the address of the page on
  GitHub, which `Get-Help -Online` opens.
- Keep the level 2 headings in capital letters and in this order: SYNOPSIS,
  SYNTAX, DESCRIPTION, EXAMPLES, PARAMETERS, INPUTS, OUTPUTS, NOTES,
  RELATED LINKS. Don't add other level 2 headings.
- Don't edit the SYNTAX blocks or the YAML block of a parameter by hand.
  platyPS regenerates them from the module. The only exception is
  `Default value`, which platyPS keeps.
- Write each paragraph on a single line. platyPS carries line breaks into the
  text that `Get-Help` shows.
- Put a link at the end of a sentence. In the text that `Get-Help` shows,
  platyPS writes a link as `text (address)` and drops the space after it.
- Start each example with a level 3 heading such as
  `### Example 1: Get the permissions of a folder`, followed by a code block
  with the language `PowerShell` whose first line starts with `PS C:\>`.
- Under INPUTS and OUTPUTS, keep the level 3 headings with the type names and
  add a sentence below each one.
- In RELATED LINKS, write each link on its own line and separate the links
  with blank lines.

## MkDocs

- The site uses the built-in `readthedocs` theme.
- Every page must be listed in the `nav` section of `mkdocs.yml`.
- Files in `Docs` that aren't Markdown are copied to the website. Exclude
  files that don't belong there with `exclude_docs` in `mkdocs.yml`.
