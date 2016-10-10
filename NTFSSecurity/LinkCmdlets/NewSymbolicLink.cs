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

        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [Alias("FullName")]
        public string Path
        {
            get { return paths[0]; }
            set
            {
                paths.Clear();
                paths.Add(value);
            }
        }

        [Parameter(Position = 2, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
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
            var path = paths[0];

            path = GetRelativePath(path);
            target = GetRelativePath(target);
            FileSystemInfo targetItem = null;
            var root = System.IO.Path.GetPathRoot(path);

            try
            {
                targetItem = GetFileSystemInfo2(target);

                FileSystemInfo temp;
                if (TryGetFileSystemInfo2(path, out temp))
                {
                    throw new ArgumentException("The path does already exist, cannot create link");
                }

                File.CreateSymbolicLink(path, target, targetItem is FileInfo ? SymbolicLinkTarget.File : SymbolicLinkTarget.Directory);

                if (passThru)
                {
                    WriteObject(new FileInfo(path));
                }
            }
            catch (System.IO.FileNotFoundException ex)
            {
                WriteError(new ErrorRecord(ex, "CreateSymbolicLinkError", ErrorCategory.ObjectNotFound, path));
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}