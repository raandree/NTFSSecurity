# Style guide

Follow these rules so that the NTFSSecurity documentation reads as one
consistent set of pages.

## Language

- Write in American English, in the present tense, and in the active voice.
- Address the reader as "you".
- Keep sentences short, with one idea per sentence.
- Write product names as their owners do: PowerShell, Windows PowerShell,
  NTFS, Active Directory, GitHub.
- Format cmdlet names, parameter names, values, type names, paths, and code
  as code with backticks, for example `Add-NTFSAccess -AccessRights Modify`.
- Describe what the code does. Check every statement about behavior against
  the source code or a test run.

## Examples

- Use the sample accounts `CONTOSO\JohnDoe`, `CONTOSO\Domain Users`,
  `BUILTIN\Users`, and `BUILTIN\Administrators`.
- Use sample paths below `C:\Data`.
- Use full cmdlet names, full parameter names, and full value names, for
  example `FullControl` instead of `Full`. Don't use aliases or positional
  parameters unless the example is about them.
- Test every example in a test folder before you publish it.
- Don't publish output that shows real computer, domain, or user names.
  Describe the result in a sentence instead.
- Say when an example needs an elevated session.

## Cmdlet reference pages

| Section | Content |
| --- | --- |
| SYNOPSIS | One sentence that starts with a verb in the third person, for example "Gets ..." or "Adds ...". |
| DESCRIPTION | What the cmdlet does, what it works on, how the parameter sets differ, defaults, and the module settings that affect it. |
| EXAMPLES | Two to four realistic tasks. Each example has a title, the command, and a sentence that explains the result. |
| PARAMETERS | "Specifies ..." for parameters that take a value and "Indicates that ..." for switches. Name the default when the parameter is omitted. |
| INPUTS and OUTPUTS | One sentence per type. Say when the cmdlet writes nothing by default. |
| NOTES | Required privileges, limitations, and differences between versions. |
| RELATED LINKS | Links to closely related cmdlet pages. |

## Conceptual pages

- Use one level 1 heading per page and sentence case for all headings.
- Start each page with a short introduction that says what the page covers.
- Wrap lines at 80 characters, except in tables, links, and code blocks.
- Link to the cmdlet reference instead of repeating parameter details.

## Next steps

Read [Markdown and platyPS specifics](04-Markdown-Specifics.md).
