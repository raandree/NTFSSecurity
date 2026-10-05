using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity.OwnerCmdlets
{
    [Cmdlet(VerbsCommon.Get, "NTFSOwner", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemOwner))]
    public class GetOwner : BaseCmdletWithPrivControl
    {
        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "Path")]
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

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "SecurityDescriptor")]
        [ValidateNotNullOrEmpty]
        public FileSystemSecurity2[] SecurityDescriptor
        {
            get { return securityDescriptors.ToArray(); }
            set
            {
                securityDescriptors.Clear();
                securityDescriptors.AddRange(value);
            }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "Path")
            {
                foreach (var path in paths)
                {
                    FileSystemInfo item = null;
                    FileSystemOwner owner = null;

                    try
                    {
                        item = GetFileSystemInfo2(path);
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ReadFileError", ErrorCategory.OpenError, path));
                        continue;
                    }

                    try
                    {
                        owner = FileSystemOwner.GetOwner(item);
                    }
                    catch (UnauthorizedAccessException ex)
                    {
                        // Taking ownership to read the owner would replace the owner that the cmdlet reports.
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.PermissionDenied, path));
                        continue;
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.OpenError, path));
                        continue;
                    }

                    // Outside the try block, so that a stopped pipeline isn't reported as a read error.
                    WriteObject(owner);
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    WriteObject(FileSystemOwner.GetOwner(sd));
                }
            }
        }
    }
}
