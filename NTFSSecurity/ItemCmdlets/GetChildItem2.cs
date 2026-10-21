using Alphaleonis.Win32.Filesystem;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Linq;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "ChildItem2")]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class GetChildItem2 : BaseCmdlet
    {
        private string filter = "*";
        private SwitchParameter recurse;
        private SwitchParameter directory;
        private SwitchParameter file;
        private System.IO.FileAttributes attributes;
        private SwitchParameter hidden;
        private SwitchParameter system;
        private SwitchParameter readOnly;
        private SwitchParameter force;
        private SwitchParameter skipMountPoints;
        private SwitchParameter skipSymbolicLinks;
        private bool getFileSystemModeProperty = false;
        private bool identifyHardLinks = false;
        private int? depth;

        System.Reflection.MethodInfo modeMethodInfo = null;

        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [Alias("FullName")]
        [FileSystemPathTransformation]
        public string[] Path
        {
            get { return paths.ToArray(); }
            set
            {
                paths.Clear();
                paths.AddRange(value);
            }
        }

        [Parameter(Position = 2)]
        [ValidateNotNull]
        public string Filter
        {
            get { return filter; }
            set { filter = value; }
        }

        [Parameter]
        public SwitchParameter Recurse
        {
            get { return recurse; }
            set { recurse = value; }
        }

        [Parameter]
        public SwitchParameter Directory
        {
            get { return directory; }
            set { directory = value; }
        }

        [Parameter]
        public SwitchParameter File
        {
            get { return file; }
            set { file = value; }
        }

        [Parameter]
        public System.IO.FileAttributes Attributes
        {
            get { return attributes; }
            set { attributes = value; ; }
        }

        [Parameter()]
        public SwitchParameter Hidden
        {
            get { return hidden; }
            set { hidden = value; }
        }

        [Parameter]
        public SwitchParameter System
        {
            get { return system; }
            set { system = value; }
        }

        [Parameter]
        public SwitchParameter ReadOnly
        {
            get { return readOnly; }
            set { readOnly = value; }
        }

        [Parameter]
        public SwitchParameter Force
        {
            get { return force; }
            set { force = value; }
        }

        [Parameter]
        public SwitchParameter SkipMountPoints
        {
            get { return skipMountPoints; }
            set { skipMountPoints = value; }
        }

        [Parameter]
        public SwitchParameter SkipSymbolicLinks
        {
            get { return skipSymbolicLinks; }
            set { skipSymbolicLinks = value; }
        }

        [Parameter]
        public int? Depth
        {
            get { return depth; }
            set { depth = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            // An empty value would match every item, also the hidden ones; Get-ChildItem rejects it as well.
            if (MyInvocation.BoundParameters.ContainsKey("Attributes") && attributes == 0)
            {
                ThrowTerminatingError(new ErrorRecord(
                    new ArgumentException("Specify at least one file attribute for the Attributes parameter."),
                    "AttributesEmpty", ErrorCategory.InvalidArgument, attributes));
            }

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetCurrentLocation() };
            }

            // The names are matched by DosWildcard, not by the enumeration (see WriteFileSystem, which always asks
            // AlphaFS for "*"), so there is nothing to pre-compile here: DosWildcard reads the raw value of -Filter
            // at the time each name is compared.
            modeMethodInfo = typeof(FileSystemCodeMembers).GetMethod("Mode");

            getFileSystemModeProperty = (bool)((Hashtable)MyInvocation.MyCommand.Module.PrivateData)["GetFileSystemModeProperty"];
            identifyHardLinks = (bool)((Hashtable)MyInvocation.MyCommand.Module.PrivateData)["IdentifyHardLinks"];
        }

        protected override void ProcessRecord()
        {
            foreach (var path in paths)
            {
                FileSystemInfo item = null;

                try
                {
                    item = GetFileSystemInfo2(path);
                }
                catch (System.IO.FileNotFoundException ex)
                {
                    WriteError(new ErrorRecord(ex, "FileNotFound", ErrorCategory.ObjectNotFound, path));
                    continue;
                }

                var di = item as DirectoryInfo;
                if (di == null)
                {
                    // Like Get-ChildItem, a file path returns the file itself.
                    if (!directory)
                    {
                        WriteFileSystemInfoCollection(new FileSystemInfo[] { item }.GetEnumerator());
                    }
                    continue;
                }

                try
                {
                    WriteFileSystem(di, 0);
                }
                catch (PipelineStoppedException ex)
                {
                    throw ex;
                }
            }
        }

        private void WriteFileSystem(FileSystemInfo fsi, int currentDepth)
        {
            var di = fsi as DirectoryInfo;
            try
            {
                if (di != null)
                {
                    if (directory)
                    {
                        IEnumerator files;
                        using (new InvariantCultureScope())
                        {
                            // The enumeration applies no pattern of its own; DosWildcard decides in
                            // WriteFileSystemInfoCollection, on the real name, with the dot rules of Windows
                            // PowerShell 5.1.
                            files = di.EnumerateDirectories("*", global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
                        }

                        WriteFileSystemInfoCollection(files);
                    }
                    else if (file)
                    {
                        IEnumerator files;
                        using (new InvariantCultureScope())
                        {
                            files = di.EnumerateFiles("*", global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
                        }

                        WriteFileSystemInfoCollection(files);
                    }
                    else
                    {
                        IEnumerator files;
                        using (new InvariantCultureScope())
                        {
                            files = di.EnumerateFileSystemInfos("*", global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
                        }

                        WriteFileSystemInfoCollection(files);
                    }
                }

                if (recurse)
                {
                    try
                    {
                        var subDis = di.EnumerateDirectories("*", global::System.IO.SearchOption.TopDirectoryOnly);
                        var subDisEnumerator = subDis.GetEnumerator();

                        foreach (var subDi in subDis)
                        {
                            //if ((subDi.Attributes & global::System.IO.FileAttributes.Hidden) == global::System.IO.FileAttributes.Hidden & !hidden)
                            //    continue;

                            subDi.RefreshEntryInfo();
                            if (subDi.EntryInfo.IsMountPoint && skipMountPoints) { continue; }
                            if (subDi.EntryInfo.IsSymbolicLink && skipSymbolicLinks) { continue; }

                            if (depth.HasValue)
                            {
                                if (currentDepth < depth)
                                    WriteFileSystem(subDi, currentDepth + 1);
                            }
                            else
                                WriteFileSystem(subDi, 0);
                        }
                    }
                    catch (PipelineStoppedException ex)
                    {
                        throw ex;
                    }
                    catch (Exception ex)
                    {
                        // Not what a later command raises, which this catch would hide; the verbose message is for a
                        // folder that can't be listed.
                        if (IsFromLaterCommand(ex))
                        {
                            throw;
                        }

                        WriteVerbose(string.Format("Cannot access folder '{0}' for recursive operation", di));
                    }
                }
            }
            catch (UnauthorizedAccessException ex)
            {
                WriteError(new ErrorRecord(ex, "DirUnauthorizedAccessError", ErrorCategory.PermissionDenied, di.FullName));
            }
            catch (PipelineStoppedException ex)
            {
                throw ex;
            }
            catch (Exception ex)
            {
                if (IsFromLaterCommand(ex))
                {
                    throw;
                }

                WriteError(new ErrorRecord(ex, "DirUnspecifiedError", ErrorCategory.NotSpecified, di.FullName));
            }
        }

        protected void WriteFileSystemInfoCollection(IEnumerator fileSystemInfos)
        {
            while (MoveNextInvariant(fileSystemInfos))
            {
                FileSystemInfo current = (FileSystemInfo)fileSystemInfos.Current;
                if (!DosWildcard.IsMatch(current.Name, filter))
                {
                    continue;
                }

                var writeItem = force.ToBool() || hidden.ToBool();

                if (MyInvocation.BoundParameters.ContainsKey("Attributes"))
                {
                    // Like Get-ChildItem, an item matches when it has any of the listed attributes (#5).
                    if ((current.Attributes & attributes) == 0)
                        continue;

                    writeItem = true;
                }
                else
                {
                    if ((current.Attributes & global::System.IO.FileAttributes.Hidden) != global::System.IO.FileAttributes.Hidden)
                        writeItem = true;

                    if (hidden)
                        if ((current.Attributes & global::System.IO.FileAttributes.Hidden) != global::System.IO.FileAttributes.Hidden)
                            writeItem = false;

                    if (system)
                        if ((current.Attributes & global::System.IO.FileAttributes.System) != global::System.IO.FileAttributes.System)
                            writeItem = false;

                    if (readOnly)
                        if ((current.Attributes & global::System.IO.FileAttributes.ReadOnly) != global::System.IO.FileAttributes.ReadOnly)
                            writeItem = false;
                }

                if (writeItem)
                {
                    PSObject item;
                    if (current is FileInfo)
                    {
                        item = new PSObject((FileInfo)current);
                    }
                    else
                    {
                        item = new PSObject((DirectoryInfo)current);
                    }

                    //can be disabled for a better performance in the PSD1 file, PrivateData section, GetFileSystemModeProperty = $true / $false
                    if (getFileSystemModeProperty)
                        item.Properties.Add(new PSCodeProperty("Mode", modeMethodInfo));

                    if (identifyHardLinks == true && current is FileInfo)
                    {
                        try
                        {
                            item.Properties.Add(new PSNoteProperty("HardLinkCount", Alphaleonis.Win32.Filesystem.File.EnumerateHardlinks(current.FullName).Count()));
                        }
                        catch
                        {
                            WriteDebug(string.Format("Could not read hard links for '{0}'", current.FullName));
                        }
                    }

                    WriteObject(item);
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }

        // AlphaFS 2.2 matches the filter with a regular expression that takes the culture of the thread, and with tr-TR the
        // letters I and i differ: index* did not match Index.txt. The enumeration therefore runs with the invariant culture,
        // which is back before an item reaches the pipeline, so that no later command sees it.
        private static bool MoveNextInvariant(IEnumerator enumerator)
        {
            using (new InvariantCultureScope())
            {
                return enumerator.MoveNext();
            }
        }

        private sealed class InvariantCultureScope : IDisposable
        {
            private readonly global::System.Globalization.CultureInfo previous;

            public InvariantCultureScope()
            {
                previous = global::System.Threading.Thread.CurrentThread.CurrentCulture;
                global::System.Threading.Thread.CurrentThread.CurrentCulture = global::System.Globalization.CultureInfo.InvariantCulture;
            }

            public void Dispose()
            {
                global::System.Threading.Thread.CurrentThread.CurrentCulture = previous;
            }
        }

        // Matches a -Filter pattern against the real name of an item with the Win32 "DOS" wildcard rules that
        // Windows PowerShell 5.1 applies to Get-ChildItem -Filter, in both editions, so that the two editions and
        // the short-name based matching that a past fix removed do not disagree. The rules come from
        // FsRtlIsNameInExpression with the Win32 translation of a DOS pattern (DOS_STAR, DOS_QM, DOS_DOT): an
        // asterisk matches a run of characters (but not past the LAST dot in the name, which a following dot
        // token still has to account for); a question mark matches one character that is not a dot, or nothing
        // where the name has no more characters left or the next one is a dot; and a dot matches a literal dot in
        // the name, or nothing where the name has no more characters left, which is why "Report.*" also returns
        // "Report" and "Report." returns only the names without a dot. Comparisons are case-insensitive with the
        // invariant culture, never the thread culture, matching the enumeration (see InvariantCultureScope).
        // Every character other than an asterisk or a question mark is ordinary, including a bracket and a
        // backtick.
        private static class DosWildcard
        {
            private enum TokenKind
            {
                Literal,
                Star,
                QuestionMark,
                Dot
            }

            private struct Token
            {
                public TokenKind Kind;
                public char Char;
            }

            public static bool IsMatch(string name, string pattern)
            {
                // An empty value matches every item, like a plain asterisk; Get-ChildItem2 keeps its own default
                // of "*" for -Filter, but once a caller passes an explicit empty string this is the policy.
                if (pattern.Length == 0)
                {
                    return true;
                }

                // A single dot is not a meaningful base/extension split, so Get-ChildItem treats it the same as
                // no filter at all, in both editions.
                if (pattern == ".")
                {
                    return true;
                }

                var tokens = Tokenize(pattern);
                var matched = new Dictionary<long, bool>();
                return Match(name, 0, tokens, 0, matched);
            }

            private static List<Token> Tokenize(string pattern)
            {
                var tokens = new List<Token>();

                // A run of one or more dots that reaches the end of the pattern collapses into a single DOS_DOT:
                // "Report..." and "Report." both ask for "Report" with nothing left of the name to account for.
                // A dot elsewhere becomes a DOS_DOT only when the single next character is an asterisk or a
                // question mark; otherwise it is an ordinary character that requires a literal dot in the name.
                var trailingDotsFrom = pattern.Length;
                while (trailingDotsFrom > 0 && pattern[trailingDotsFrom - 1] == '.')
                {
                    trailingDotsFrom--;
                }
                var hasTrailingDotRun = trailingDotsFrom < pattern.Length;

                for (var i = 0; i < pattern.Length; i++)
                {
                    if (hasTrailingDotRun && i == trailingDotsFrom)
                    {
                        tokens.Add(new Token { Kind = TokenKind.Dot, Char = '.' });
                        break;
                    }

                    var c = pattern[i];
                    if (c == '*')
                    {
                        tokens.Add(new Token { Kind = TokenKind.Star });
                    }
                    else if (c == '?')
                    {
                        tokens.Add(new Token { Kind = TokenKind.QuestionMark });
                    }
                    else if (c == '.')
                    {
                        var next = (i + 1 < pattern.Length) ? pattern[i + 1] : '\0';
                        var qualifies = (i + 1 >= pattern.Length) || next == '*' || next == '?';
                        tokens.Add(new Token { Kind = qualifies ? TokenKind.Dot : TokenKind.Literal, Char = '.' });
                    }
                    else
                    {
                        tokens.Add(new Token { Kind = TokenKind.Literal, Char = c });
                    }
                }
                return tokens;
            }

            // Matches the name, starting at name position ni, against the tokens from token position ti. The
            // dictionary memoizes (ti, ni) pairs, because a star token tries every name position from ni onward
            // and the same (ti, ni) pair can otherwise be re-examined many times over for a pattern with several
            // stars.
            private static bool Match(string name, int ni, List<Token> tokens, int ti, Dictionary<long, bool> matched)
            {
                var key = ((long)ti << 32) | (uint)ni;
                bool cached;
                if (matched.TryGetValue(key, out cached))
                {
                    return cached;
                }

                var result = MatchCore(name, ni, tokens, ti, matched);
                matched[key] = result;
                return result;
            }

            private static bool MatchCore(string name, int ni, List<Token> tokens, int ti, Dictionary<long, bool> matched)
            {
                if (ti == tokens.Count)
                {
                    return ni == name.Length;
                }

                var tok = tokens[ti];

                if (tok.Kind == TokenKind.Star)
                {
                    // A star that is directly followed by a dot (a DOS_DOT or an ordinary dot) must leave that dot
                    // for the dot token to account for: it may cross every dot in the name but the LAST one (Win32
                    // DOS_STAR), which is why "Rep*." does not return "Report.txt" although a plain "*" could reach
                    // the end of the name by crossing the dot, and why "*.?" reaches the final segment of a name
                    // with two or more dots, such as "archive.tar.gz". A star with anything else after it,
                    // including another star, is free to cross every dot, which is why "**." returns every item
                    // and "R*t" returns "Report.txt".
                    var max = name.Length;
                    if (ti + 1 < tokens.Count && tokens[ti + 1].Kind == TokenKind.Dot)
                    {
                        var lastDot = name.LastIndexOf('.');
                        if (lastDot >= ni)
                        {
                            max = lastDot;
                        }
                    }

                    for (var k = ni; k <= max; k++)
                    {
                        if (Match(name, k, tokens, ti + 1, matched))
                        {
                            return true;
                        }
                    }
                    return false;
                }

                if (ni == name.Length)
                {
                    // A question mark or a dot can match nothing at the end of the name; anything else needs a
                    // character that is not there.
                    if (tok.Kind == TokenKind.QuestionMark || tok.Kind == TokenKind.Dot)
                    {
                        return Match(name, ni, tokens, ti + 1, matched);
                    }
                    return false;
                }

                if (tok.Kind == TokenKind.QuestionMark)
                {
                    // A question mark does not match a dot; it matches nothing there instead, leaving the dot for
                    // a later token.
                    if (name[ni] == '.')
                    {
                        return Match(name, ni, tokens, ti + 1, matched);
                    }
                    return Match(name, ni + 1, tokens, ti + 1, matched);
                }

                if (tok.Kind == TokenKind.Dot)
                {
                    if (name[ni] == '.')
                    {
                        return Match(name, ni + 1, tokens, ti + 1, matched);
                    }
                    return false;
                }

                if (char.ToUpperInvariant(tok.Char) == char.ToUpperInvariant(name[ni]))
                {
                    return Match(name, ni + 1, tokens, ti + 1, matched);
                }

                return false;
            }
        }
    }
}
