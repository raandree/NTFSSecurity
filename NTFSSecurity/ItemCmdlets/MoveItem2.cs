using Alphaleonis.Win32.Filesystem;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Move, "Item2", SupportsShouldProcess = true)]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class MoveItem2 : BaseCmdlet
    {
        private string destination;
        private SwitchParameter force;
        private bool passThru;

        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
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

        [Parameter(Position = 2, Mandatory = true, ValueFromPipelineByPropertyName = true)]
        [FileSystemPathTransformation]
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
                    continue;
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

                // A folder at the destination counts as well; before 5.0.0-rc6, only a file did.
                var destinationExists = !force && (File.Exists(actualDestination) || Directory.Exists(actualDestination));

                // Report a conflict only for an operation that runs; -WhatIf names it in a verbose message (#108).
                if (!ShouldProcess(resolvedPath, item is FileInfo ? "Move File" : "Move Directory"))
                {
                    if (destinationExists)
                    {
                        WriteVerbose(string.Format("The destination '{0}' already exists; without -Force, the move would fail", actualDestination));
                    }
                    else
                    {
                        var missingFolder = GetMissingDestinationFolder(actualDestination);
                        if (missingFolder != null)
                        {
                            WriteVerbose(string.Format("The destination folder '{0}' does not exist; the move would fail", missingFolder));
                        }
                    }

                    continue;
                }

                if (destinationExists)
                {
                    WriteError(new ErrorRecord(new AlreadyExistsException(), "DestinationFileAlreadyExists", ErrorCategory.ResourceExists, actualDestination));
                    continue;
                }

                if (WriteMissingDestinationFolderError(actualDestination, "MoveError"))
                {
                    continue;
                }

                try
                {
                    if (item is FileInfo)
                    {
                        ((FileInfo)item).MoveTo(actualDestination, force ? MoveOptions.ReplaceExisting : MoveOptions.CopyAllowed, PathFormat.RelativePath);
                        WriteVerbose(string.Format("File '{0}' moved to '{1}'", resolvedPath, actualDestination));
                    }
                    else
                    {
                        // Without CopyAllowed, so that Windows refuses a move to another volume, which it can't do for a
                        // folder. Before 5.0.0-rc7, AlphaFS emulated such a move by copying and deleting: an empty folder
                        // was deleted without being created at the destination, and a folder with files failed with an
                        // error that named one of its files.
                        ((DirectoryInfo)item).MoveTo(actualDestination, force ? MoveOptions.ReplaceExisting : MoveOptions.None, PathFormat.RelativePath);
                        WriteVerbose(string.Format("Directory '{0}' moved to '{1}'", resolvedPath, actualDestination));
                    }

                    if (passThru)
                        WriteObject(item);
                }
                catch (NotSameDeviceException ex)
                {
                    // A file gets here only with -Force, which moves without CopyAllowed; it keeps the error of Windows.
                    if (item is DirectoryInfo)
                    {
                        var message = string.Format("The folder '{0}' can't move to another volume, '{1}'. Copy it with Copy-Item2, then remove it with Remove-Item2.", resolvedPath, actualDestination);
                        WriteError(new ErrorRecord(new System.IO.IOException(message, ex), "MoveError", ErrorCategory.InvalidOperation, resolvedPath));
                    }
                    else
                    {
                        WriteError(new ErrorRecord(ex, "MoveError", ErrorCategory.InvalidData, resolvedPath));
                    }
                }
                catch (System.IO.IOException ex)
                {
                    WriteError(new ErrorRecord(ex, "MoveError", ErrorCategory.InvalidData, resolvedPath));
                }
                catch (Exception ex)
                {
                    if (PipelineControl.IsEnd(ex))
                    {
                        throw;
                    }

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
