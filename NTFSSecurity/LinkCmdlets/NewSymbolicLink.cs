using Alphaleonis.Win32.Filesystem;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.New, "NTFSSymbolicLink")]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class NewSymbolicLink : BaseCmdlet
    {
        string target;
        private bool passThru;
        System.Reflection.MethodInfo modeMethodInfo = null;

        // Required since 5.0.0-rc7. Before, an omitted -Path failed with an index error, and an omitted -Target meant the
        // current location, so the cmdlet created a link to the current folder.
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
            var path = GetRelativePath(paths[0]);
            var targetPath = GetRelativePath(target);

            // Non-terminating errors, so that the links that follow in the pipeline are created as well. Before
            // 5.0.0-rc7, an existing path and a failure to create the link stopped the pipeline.
            FileSystemInfo targetItem = null;
            try
            {
                targetItem = GetFileSystemInfo2(targetPath);
            }
            catch (System.IO.FileNotFoundException ex)
            {
                WriteError(new ErrorRecord(ex, "CreateSymbolicLinkError", ErrorCategory.ObjectNotFound, path));
                return;
            }

            FileSystemInfo temp;
            if (TryGetFileSystemInfo2(path, out temp))
            {
                var exists = new ArgumentException("The path does already exist, cannot create link");
                WriteError(new ErrorRecord(exists, "CreateSymbolicLinkError", ErrorCategory.ResourceExists, path));
                return;
            }

            try
            {
                File.CreateSymbolicLink(path, targetPath, targetItem is FileInfo ? SymbolicLinkTarget.File : SymbolicLinkTarget.Directory);
            }
            // Without the right to create symbolic links: (1314) A required privilege is not held by the client.
            catch (Exception ex)
            {
                WriteError(new ErrorRecord(ex, "CreateSymbolicLinkError", ex is UnauthorizedAccessException ? ErrorCategory.PermissionDenied : ErrorCategory.WriteError, path));
                return;
            }

            if (passThru)
            {
                if (targetItem is FileInfo)
                    WriteObject(new FileInfo(path));
                else
                    WriteObject(new DirectoryInfo(path));
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}