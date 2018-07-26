using Alphaleonis.Win32.Filesystem;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Move, "Item2", SupportsShouldProcess = true)]
    public class MoveItem2 : BaseCmdlet
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
                WriteVerbose(string.Format("Moving item '{0}'", path));

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
                        if (ShouldProcess(resolvedPath, "Move File"))
                        {
                            ((FileInfo)item).MoveTo(actualDestination, force ? MoveOptions.ReplaceExisting : MoveOptions.CopyAllowed, PathFormat.RelativePath);
                            WriteVerbose(string.Format("File '{0}' moved to '{0}'", resolvedPath, destination));
                        }
                    }
                    else
                    {
                        if (ShouldProcess(resolvedPath, "Move Directory"))
                        {
                            ((DirectoryInfo)item).MoveTo(actualDestination, force ? MoveOptions.ReplaceExisting : MoveOptions.CopyAllowed, PathFormat.RelativePath);
                            WriteVerbose(string.Format("Directory '{0}' moved to '{0}'", resolvedPath, destination));
                        }
                    }

                    if (passThru)
                        WriteObject(item);
                }
                catch (System.IO.IOException ex)
                {
                    WriteError(new ErrorRecord(ex, "MoveError", ErrorCategory.InvalidData, resolvedPath));
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "MoveError", ErrorCategory.NotSpecified, resolvedPath));
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
