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
                FileSystemInfo item = null;

                foreach (var path in paths)
                {
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
                        WriteObject(FileSystemOwner.GetOwner(item));
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                            WriteObject(FileSystemOwner.GetOwner(item));

                            FileSystemOwner.SetOwner(item, previousOwner);
                        }
                        catch (Exception ex2)
                        {
                            WriteError(new ErrorRecord(ex2, "ReadSecurityError", ErrorCategory.WriteError, path));
                            continue;
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.OpenError, path));
                        continue;
                    }
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
