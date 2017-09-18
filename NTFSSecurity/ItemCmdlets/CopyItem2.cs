using Alphaleonis.Win32.Filesystem;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Copy, "Item2", SupportsShouldProcess = true)]
    public class CopyItem2 : BaseCmdlet
    {
        private string destination;
        private SwitchParameter force;
        private bool passThru;

        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
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

        [Parameter(Position = 2, Mandatory = true, ValueFromPipelineByPropertyName = true)]
        public string Destination
        {
            get { return destination; }
            set { destination = value; }
        }

        [Parameter]
        public SwitchParameter Force
        {
            get { return force; }
            set { force = value; }
        }

        [Parameter]
        public bool PassThru
        {
            get { return passThru; }
            set { passThru = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            destination = GetRelativePath(destination);
            WriteVerbose(string.Format("Destination path is '{0}'", destination));
        }

        protected override void ProcessRecord()
        {
            foreach (var path in paths)
            {
                WriteVerbose(string.Format("Copying item '{0}'", path));

                FileSystemInfo item = null;
                var actualDestination = string.Empty;

                var resolvedPath = GetRelativePath(path);

                try
                {
                    item = GetFileSystemInfo2(resolvedPath);
                }
                catch (System.IO.FileNotFoundException ex)
                {
                    WriteError(new ErrorRecord(ex, "FileNotFound", ErrorCategory.ObjectNotFound, resolvedPath));
                    return;
                }

                //destination is a directory
                if (Directory.Exists(destination))
                {
                    //hence adding the file name to the destination path
                    actualDestination = System.IO.Path.Combine(destination, System.IO.Path.GetFileName(resolvedPath));
                }
                else
                {
                    actualDestination = destination;
                }

                if (!force & File.Exists(actualDestination))
                {
                    WriteError(new ErrorRecord(new AlreadyExistsException(), "DestinationFileAlreadyExists", ErrorCategory.ResourceExists, actualDestination));
                    return;
                }

                try
                {
                    if (item is FileInfo)
                    {
                        if (ShouldProcess(resolvedPath, "Copy File"))
                        {
                            ((FileInfo)item).CopyTo(actualDestination, force ? CopyOptions.None : CopyOptions.FailIfExists, PathFormat.RelativePath);
                            WriteVerbose(string.Format("File '{0}' copied to '{0}'", resolvedPath, destination));
                        }
                    }
                    else
                    {
                        if (ShouldProcess(resolvedPath, "Copy Directory"))
                        {
                            ((DirectoryInfo)item).CopyTo(actualDestination, force ? CopyOptions.None : CopyOptions.FailIfExists, PathFormat.RelativePath);
                            WriteVerbose(string.Format("Directory '{0}' copied to '{0}'", resolvedPath, destination));
                        }
                    }

                    if (passThru)
                        WriteObject(item);
                }
                catch (System.IO.IOException ex)
                {
                    WriteError(new ErrorRecord(ex, "CopyError", ErrorCategory.InvalidData, resolvedPath));
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "CopyError", ErrorCategory.NotSpecified, resolvedPath));
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
