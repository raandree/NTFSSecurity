using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{

    [Cmdlet(VerbsLifecycle.Disable, "NTFSAuditInheritance", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemInheritanceInfo))]
    public class DisableAuditInheritance : BaseCmdletWithPrivControl
    {
        private bool removeInheritedAuditRules;
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

        /// <summary>
        /// Removes the inherited audit entries instead of copying them to the item. Before 5.0.0, the switch was
        /// named RemoveInheritedAccessRules, which remains an alias.
        /// </summary>
        [Parameter]
        [Alias("RemoveInheritedAccessRules")]
        public SwitchParameter RemoveInheritedAuditRules
        {
            get { return removeInheritedAuditRules; }
            set { removeInheritedAuditRules = value; }
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
                        FileSystemInheritanceInfo.DisableAuditInheritance(item, removeInheritedAuditRules);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            InvokeAsOwner(item, path, () =>
                            {
                                FileSystemInheritanceInfo.DisableAuditInheritance(item, removeInheritedAuditRules);
                            });
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

                    // Only after a successful change, so that a failure doesn't report the unchanged state
                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item));
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    FileSystemInheritanceInfo.DisableAuditInheritance(sd, removeInheritedAuditRules);

                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd));
                    }
                }
            }
        }
    }
}