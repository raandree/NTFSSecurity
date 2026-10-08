using Alphaleonis.Win32.Filesystem;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.New, "NTFSHardLink")]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class NewHardLink : BaseCmdlet
    {
        string target;
        private bool passThru;
        System.Reflection.MethodInfo modeMethodInfo = null;

        // Required since 5.0.0-rc7. Before, an omitted -Path failed with an index error, and an omitted -Target meant the
        // current location, which is a folder.
        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [Alias("FullName")]
        [FileSystemPathTransformation]
        public string Path
        {
            // PowerShell reads a parameter that takes pipeline input before it binds the input. Before 5.0.0-rc7, the
            // empty list failed that read, so every piped object failed with GetDefaultValueFailed.
            get { return paths.Count > 0 ? paths[0] : null; }
            set
            {
                paths.Clear();
                paths.Add(value);
            }
        }

        [Parameter(Mandatory = true, Position = 2, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [FileSystemPathTransformation]
        public string Target
        {
            get { return target; }
            set { target = value; }
        }

        [Parameter]
        public SwitchParameter PassThru
        {
            get { return passThru; }
            set { passThru = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            modeMethodInfo = typeof(FileSystemCodeMembers).GetMethod("Mode");
        }

        protected override void ProcessRecord()
        {
            string path;
            string targetPath;
            try
            {
                path = GetRelativePath(paths[0]);
                targetPath = GetRelativePath(target);
            }
            // Windows PowerShell rejects a character that Windows doesn't allow in a path, such as |, already here.
            catch (ArgumentException ex)
            {
                WriteError(new ErrorRecord(ex, "CreateHardLinkError", ErrorCategory.InvalidArgument, paths[0]));
                return;
            }
            var root = System.IO.Path.GetPathRoot(path);

            // Non-terminating errors, so that the links that follow in the pipeline are created as well. Before
            // 5.0.0-rc7, an existing path, a missing target, or a folder as target stopped the pipeline.
            FileSystemInfo temp = null;
            if (TryGetFileSystemInfo2(path, out temp))
            {
                var exists = new ArgumentException(string.Format("The file '{0}' does already exist, cannot create the link", path));
                WriteError(new ErrorRecord(exists, "CreateHardLinkError", ErrorCategory.ResourceExists, path));
                return;
            }

            if (!TryGetFileSystemInfo2(targetPath, out temp))
            {
                var missing = new System.IO.FileNotFoundException(string.Format("The target '{0}' does not exist, cannot create the link", targetPath), targetPath);
                WriteError(new ErrorRecord(missing, "CreateHardLinkError", ErrorCategory.ObjectNotFound, path));
                return;
            }

            if (temp is DirectoryInfo)
            {
                var folder = new ArgumentException(string.Format("The target '{0}' is not a file, cannot create the link", targetPath));
                WriteError(new ErrorRecord(folder, "CreateHardLinkError", ErrorCategory.InvalidArgument, path));
                return;
            }

            try
            {
                File.CreateHardlink(path, targetPath);
            }
            catch (Exception ex)
            {
                WriteError(new ErrorRecord(ex, "CreateHardLinkError", GetErrorCategory(ex), path));
                return;
            }

            if (passThru)
            {
                IEnumerable<string> links;
                try
                {
                    links = File.EnumerateHardlinks(path).ToList();
                }
                // Windows can't list the names of a file on a network share: (50) The request is not supported.
                // The link exists; before 5.0.0-rc6, this stopped the cmdlet with a terminating error.
                catch (System.IO.IOException ex)
                {
                    WriteError(new ErrorRecord(ex, "GetHardLinkError", ErrorCategory.ReadError, path));
                    return;
                }

                foreach (var link in links)
                {
                    var name = new PSObject(GetFileSystemInfo2(System.IO.Path.Combine(root, link.Substring(1))));
                    name.Properties.Add(new PSCodeProperty("Mode", modeMethodInfo));
                    WriteObject(name);
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }

        // In PowerShell 7, AlphaFS rejects a character that Windows doesn't allow in a path only when it creates the link.
        internal static ErrorCategory GetErrorCategory(Exception ex)
        {
            if (ex is UnauthorizedAccessException)
                return ErrorCategory.PermissionDenied;

            if (ex is ArgumentException)
                return ErrorCategory.InvalidArgument;

            return ErrorCategory.WriteError;
        }
    }
}
