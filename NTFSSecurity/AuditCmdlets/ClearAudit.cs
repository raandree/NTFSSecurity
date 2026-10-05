using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Clear, "NTFSAudit", DefaultParameterSetName = "Path")]
    public class ClearAudit : BaseCmdletWithPrivControl
    {
        private SwitchParameter disableInheritance;

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "Path")]
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

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "SD")]
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
        public SwitchParameter DisableInheritance
        {
            get { return disableInheritance; }
            set { disableInheritance = value; }
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
                        FileSystemAuditRule2.RemoveFileSystemAuditRuleAll(item);
                        if (disableInheritance)
                            FileSystemInheritanceInfo.DisableAuditInheritance(item, true);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            InvokeAsOwner(item, path, () =>
                            {
                                FileSystemAuditRule2.RemoveFileSystemAuditRuleAll(item);
                                if (disableInheritance)
                                    FileSystemInheritanceInfo.DisableAuditInheritance(item, true);
                            });
                        }
                        catch (Exception ex2)
                        {
                            WriteError(new ErrorRecord(ex2, "ClearAclError", ErrorCategory.WriteError, path));
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ClearAclError", ErrorCategory.WriteError, path));
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    FileSystemAuditRule2.RemoveFileSystemAuditRuleAll(sd);
                    if (disableInheritance)
                        FileSystemInheritanceInfo.DisableAuditInheritance(sd, true);
                }
            }

        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
