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

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetVariableValue("PWD").ToString() };
            }

            wildcard = new WildcardPattern(filter, WildcardOptions.Compiled | WildcardOptions.IgnoreCase);

            modeMethodInfo = typeof(FileSystemCodeMembers).GetMethod("Mode");

            getFileSystemModeProperty = (bool)((Hashtable)MyInvocation.MyCommand.Module.PrivateData)["GetFileSystemModeProperty"];
            identifyHardLinks = (bool)((Hashtable)MyInvocation.MyCommand.Module.PrivateData)["IdentifyHardLinks"];
        }

        protected override void ProcessRecord()
        {
            foreach (var path in paths)
            {
                DirectoryInfo di = null;

                try
                {
                    di = (DirectoryInfo)GetFileSystemInfo2(path);

                }
                catch (System.IO.FileNotFoundException ex)
                {
                    WriteError(new ErrorRecord(ex, "FileNotFound", ErrorCategory.ObjectNotFound, path));
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
                        var files = di.EnumerateDirectories(filter, global::System.IO.SearchOption.TopDirectoryOnly);
                        WriteFileSystemInfoCollection(files.GetEnumerator());
                    }
                    else if (file)
                    {
                        var files = di.EnumerateFiles(filter, global::System.IO.SearchOption.TopDirectoryOnly);
                        WriteFileSystemInfoCollection(files.GetEnumerator());
                    }
                    else
                    {
                        var files = di.EnumerateFileSystemInfos(filter, global::System.IO.SearchOption.TopDirectoryOnly);
                        WriteFileSystemInfoCollection(files.GetEnumerator());
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
                    catch (Exception)
                    {
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
                //System.Management.Automation.BreakException or System.Management.Automation.ContinueException cannot be caught due to its protection level in PowerShell v2
                if (ex.GetType().FullName == "System.Management.Automation.BreakException" | ex.GetType().FullName == "System.Management.Automation.ContinueException")
                {
                    throw ex;
                }
                WriteError(new ErrorRecord(ex, "DirUnspecifiedError", ErrorCategory.NotSpecified, di.FullName));
            }
        }

        protected void WriteFileSystemInfoCollection(IEnumerator fileSystemInfos)
        {
            while (fileSystemInfos.MoveNext())
            {
                FileSystemInfo current = (FileSystemInfo)fileSystemInfos.Current;
                if (!wildcard.IsMatch(current.Name))
                {
                    continue;
                }

                var writeItem = force.ToBool();

                if (MyInvocation.BoundParameters.ContainsKey("Attributes"))
                {
                    if ((current.Attributes & attributes) != attributes)
                        continue;

                    writeItem = true;
                }
                else
                {
                    if (hidden)
                        force = true;

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
    }
}
