using Alphaleonis.Win32.Filesystem;
using System;
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
            var root = System.IO.Path.GetPathRoot(path);

            try
            {
                FileSystemInfo temp = null;

                if (TryGetFileSystemInfo2(path, out temp))
                    throw new ArgumentException(string.Format("The file '{0}' does already exist, cannot create the link", path));

                if (!TryGetFileSystemInfo2(target, out temp))
                    throw new ArgumentException("The target path exist, cannot create the link");
                else
                    if (temp is DirectoryInfo)
                    throw new ArgumentException("The target is not a file, cannot create the link");

                File.CreateHardlink(path, target);

                if (passThru)
                {
                    var links = File.EnumerateHardlinks(path);

                    foreach (var link in links)
                    {
                        var target = new PSObject(GetFileSystemInfo2(System.IO.Path.Combine(root, link.Substring(1))));
                        target.Properties.Add(new PSCodeProperty("Mode", modeMethodInfo));
                        WriteObject(target);
                    }
                }
            }
            catch (System.IO.FileNotFoundException ex)
            {
                WriteError(new ErrorRecord(ex, "CreateHardLinkError", ErrorCategory.WriteError, path));
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
