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

        WildcardPattern wildcard = null;

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

            // Only * and ? are wildcards, like in the pattern that the enumeration matches; a bracket or a backtick stands
            // for itself. Before 5.0.0, [1] was read as a character class, so a file with brackets in its name was not
            // returned for its name. The enumeration returns every item for *.* as Windows does, so the comparison does
            // too; with the dot as an ordinary character, it would drop the items without a dot, most folders.
            // CultureInvariant: like the enumeration (see MoveNextInvariant), the comparison would otherwise treat I and i as
            // different letters with tr-TR and drop items that the enumeration returned.
            var pattern = filter == "*.*" ? "*" : filter;
            wildcard = new WildcardPattern(pattern.Replace("`", "``").Replace("[", "`[").Replace("]", "`]"), WildcardOptions.Compiled | WildcardOptions.IgnoreCase | WildcardOptions.CultureInvariant);

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
                            files = di.EnumerateDirectories(filter, global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
                        }

                        WriteFileSystemInfoCollection(files);
                    }
                    else if (file)
                    {
                        IEnumerator files;
                        using (new InvariantCultureScope())
                        {
                            files = di.EnumerateFiles(filter, global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
                        }

                        WriteFileSystemInfoCollection(files);
                    }
                    else
                    {
                        IEnumerator files;
                        using (new InvariantCultureScope())
                        {
                            files = di.EnumerateFileSystemInfos(filter, global::System.IO.SearchOption.TopDirectoryOnly).GetEnumerator();
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
                if (!wildcard.IsMatch(current.Name))
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
    }
}
