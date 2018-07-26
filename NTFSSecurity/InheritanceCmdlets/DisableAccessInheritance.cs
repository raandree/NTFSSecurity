using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsLifecycle.Disable, "NTFSAccessInheritance", DefaultParameterSetName = "Path")]
    public class DisableAccessInheritance : BaseCmdletWithPrivControl
    {
        private bool removeInheritedAccessRules;
        private bool passThru;

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

        [Parameter]
        public SwitchParameter RemoveInheritedAccessRules
        {
            get { return removeInheritedAccessRules; }
            set { removeInheritedAccessRules = value; }
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
            EnableFileSystemPrivileges(true);
        }

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "Path")
            {
                foreach (var path in paths)
                {
                    FileSystemInfo item = null;

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
                        FileSystemInheritanceInfo.DisableAccessInheritance(item, removeInheritedAccessRules);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                            FileSystemInheritanceInfo.DisableAccessInheritance(item, removeInheritedAccessRules);

                            FileSystemOwner.SetOwner(item, previousOwner);
                        }
                        catch (Exception ex2)
                        {
                            WriteError(new ErrorRecord(ex2, "ModifySdError", ErrorCategory.WriteError, path));
                            continue;
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ModifySdError", ErrorCategory.WriteError, path));
                        continue;
                    }
                    finally
                    {
                        if (passThru)
                        {
                            WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item));
                        }
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    FileSystemInheritanceInfo.DisableAccessInheritance(sd, removeInheritedAccessRules);

                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd));
                    }
                }
            }
        }
    }
}