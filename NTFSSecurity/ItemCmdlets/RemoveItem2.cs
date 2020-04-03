using Alphaleonis.Win32.Filesystem;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Remove, "Item2", SupportsShouldProcess = true)]
    public class RemoveItem2 : BaseCmdlet
    {
        private SwitchParameter force;
        private SwitchParameter recurse;
        private string filter;
        private bool passThru;

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
        
        [Parameter]
        public SwitchParameter Force
        {
            get { return force; }
            set { force = value; }
        }

        [Parameter]
        public SwitchParameter Recurse
        {
            get { return recurse; }
            set { recurse = value; }
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
                    return;
                }

                try
                {
                    if (item is FileInfo)
                    {
                        if (ShouldProcess(item.ToString(), "Remove File"))
                        {
                            ((FileInfo)item).Delete(force);
                            WriteVerbose(string.Format("File '{0}' was removed", item.ToString()));
                        }
                    }
                    else
                    {
                        if (ShouldProcess(item.ToString(), "Remove Directory"))
                        {
                            ((DirectoryInfo)item).Delete(recurse, force);
                            WriteVerbose(string.Format("Directory '{0}' was removed", item.ToString()));
                        }
                    }

                    if (passThru)
                        WriteObject(item);
                }
                catch (System.IO.IOException ex)
                {
                    WriteError(new ErrorRecord(ex, "DeleteError", ErrorCategory.InvalidData, path));
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "DeleteError", ErrorCategory.NotSpecified, path));
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
