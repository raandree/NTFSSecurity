# WRITING DOCUMENTATION

One of the easiest ways to contribute to the NTFSAccess PowerShell module is by helping to write and edit documentation.
All the documentation hosted on GitHub is written using *Markdown*. Markdown is a lightweight markup
language with plain text formatting syntax. Markdown forms the basis of our documentation's
conceptual authoring language. Creating new articles is as easy as writing a simple text file by
using your favorite text editor.

## Markdown editors

Here are some Markdown editors you can try out:

- [Visual Studio Code](https://code.visualstudio.com)
- [Atom](https://atom.io/)
- [Sublime Text](http://www.sublimetext.com/)

## Get started using Markdown

To get started using Markdown, see [How to use Markdown for writing Docs](https://docs.microsoft.com/contribute/how-to-write-use-markdown).

NTFSSecurity uses the [Mkdocs][mkdocs] builder on ReadTheDocs for documentation.

Don't use hard tabs in Markdown. For more detailed information about the Markdown specification, see the
[Markdown Specifics](04-Markdown-Specifics.md) article.

## Creating new topics

To contribute new documentation, check for issues tagged as ["Help Wanted"][labels] to make sure
you're not duplicating efforts. If no one seems to be working on what you have planned:

- Open a new issue and label it as "in progress". If you don't have rights to assign labels, add "in
  progress" as a comment to tell others what you're working on.
- Follow the same workflow as described above for making major edits to existing topics.
- Add your new article to the `TOC.yml` file (located in the top-level folder of each
  documentation set).

## Updating topics that exist in multiple versions

Most reference topics are duplicated across all versions of PowerShell. When reporting an issue
about a cmdlet reference or an About_ article, you must specify which versions are affected by the
issue. The default issue template in GitHub includes a [GFM task list][gfm-task]. Use the checkboxes
in the task list to specify which versions of the content are affected. When you submit a change to
a article for an issue that affects multiple versions of the content, you must apply the appropriate
change to each version of the file.

## Next Steps

Read the [Style Guide](03-Style-Guide.md).

<!-- External URLs -->
[markdig]: https://github.com/lunet-io/markdig
[CommonMark]: https://spec.commonmark.org/
[gfm-help]: https://help.github.com/categories/writing-on-github/
[labels]: https://github.com/raandree/NTFSSecurity/labels/Help%20Wanted
[mkdocs]: https://www.mkdocs.org/user-guide/writing-your-docs/