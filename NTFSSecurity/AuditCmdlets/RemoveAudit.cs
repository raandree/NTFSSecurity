using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Linq;
using System.Management.Automation;
using System.Security.AccessControl;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Remove, "NTFSAudit", DefaultParameterSetName = "PathComplex")]
    [OutputType(typeof(FileSystemAccessRule2))]
    public class RemoveAudit : BaseCmdletWithPrivControl
    {
        private IdentityReference2[] account;
        private FileSystemRights2 accessRights;
        private AuditFlags auditFlags = AuditFlags.Failure | AuditFlags.Success;
        private InheritanceFlags inheritanceFlags = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        private PropagationFlags propagationFlags = PropagationFlags.None;
        private ApplyTo appliesTo;
        private bool removeSpecific;
        private bool passThru;

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "PathSimple")]
        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
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

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "SDSimple")]
        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "SDComplex")]
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

        [Parameter(Mandatory = true, Position = 2, ValueFromPipelineByPropertyName = true)]
        [Alias("IdentityReference", "ID")]
        public IdentityReference2[] Account
        {
            get { return account; }
            set { account = value; }
        }

        [Parameter(Mandatory = true, Position = 3, ValueFromPipelineByPropertyName = true)]
        [Alias("FileSystemRights")]
        public FileSystemRights2 AccessRights
        {
            get { return accessRights; }
            set { accessRights = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public AuditFlags AuditFlags
        {
            get { return auditFlags; }
            set { auditFlags = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "SDComplex")]
        public InheritanceFlags InheritanceFlags
        {
            get { return inheritanceFlags; }
            set { inheritanceFlags = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "SDComplex")]
        public PropagationFlags PropagationFlags
        {
            get { return propagationFlags; }
            set { propagationFlags = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "PathSimple")]
        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "SDSimple")]
        public ApplyTo AppliesTo
        {
            get { return appliesTo; }
            set { appliesTo = value; }
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
            if (ParameterSetName.EndsWith("Simple"))
            {
                FileSystemSecurity2.ConvertToFileSystemFlags(appliesTo, out inheritanceFlags, out propagationFlags);
            }

            if (ParameterSetName.StartsWith("Path"))
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
                    }

                    if (ParameterSetName == "PathSimple")
                    {
                        FileSystemSecurity2.ConvertToFileSystemFlags(appliesTo, out inheritanceFlags, out propagationFlags);
                    }

                    try
                    {
                        FileSystemAuditRule2.RemoveFileSystemAuditRule(item, account.ToList(), accessRights, auditFlags, inheritanceFlags, propagationFlags);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                            FileSystemAuditRule2.RemoveFileSystemAuditRule(item, account.ToList(), accessRights, auditFlags, inheritanceFlags, propagationFlags);

                            FileSystemOwner.SetOwner(item, previousOwner);
                        }
                        catch (Exception ex2)
                        {
                            WriteError(new ErrorRecord(ex2, "RemoveAceError", ErrorCategory.WriteError, path));
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "RemoveAceError", ErrorCategory.WriteError, path));
                    }

                    if (passThru == true)
                    {
                        FileSystemAccessRule2.GetFileSystemAccessRules(item, true, true).ForEach(ace => WriteObject(ace));
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    FileSystemAuditRule2.RemoveFileSystemAuditRule(sd, account.ToList(), accessRights, auditFlags, inheritanceFlags, propagationFlags);

                    if (passThru == true)
                    {
                        FileSystemAuditRule2.GetFileSystemAuditRules(sd, true, true).ForEach(ace => WriteObject(ace));
                    }
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}