using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSAudit")]
    [OutputType(typeof(FileSystemAuditRule2))]
    public class GetAudit : BaseCmdletWithPrivControl
    {
        private bool excludeInherited;
        private bool excludeExplicit;
        private IdentityReference2 account;

        protected bool getInheritedFrom = false;

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

        [Parameter(ValueFromRemainingArguments = true)]
        [Alias("IdentityReference", "ID")]
        [ValidateNotNullOrEmpty]
        public IdentityReference2 Account
        {
            get { return account; }
            set { account = value; }
        }

        [Parameter]
        public SwitchParameter ExcludeExplicit
        {
            get { return excludeExplicit; }
            set { excludeExplicit = value; }
        }

        [Parameter]
        public SwitchParameter ExcludeInherited
        {
            get { return excludeInherited; }
            set { excludeInherited = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            getInheritedFrom = (bool)((System.Collections.Hashtable)MyInvocation.MyCommand.Module.PrivateData)["GetInheritedFrom"];

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetVariableValue("PWD").ToString() };
            }
        }

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "Path")
            {
                foreach (var path in paths)
                {
                    FileSystemInfo item = null;
                    IEnumerable<FileSystemAuditRule2> acl = null;

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
                        acl = GetAuditRules(item);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);
                            acl = GetAuditRules(item);
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

                    WriteAuditRules(acl);
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    if (!sd.HasAuditSection)
                    {
                        var ex = new InvalidOperationException(string.Format(
                            "The security descriptor of '{0}' doesn't contain the audit entries, because it was read without the Security privilege.", sd.FullName));
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.InvalidData, sd));
                        continue;
                    }

                    WriteAuditRules(FileSystemAuditRule2.GetFileSystemAuditRules(sd, !excludeExplicit, !excludeInherited, getInheritedFrom));
                }
            }
        }

        private IEnumerable<FileSystemAuditRule2> GetAuditRules(FileSystemInfo item)
        {
            // Reading only the SACL fails without the Security privilege, instead of returning no entries.
            var sd = new FileSystemSecurity2(item, System.Security.AccessControl.AccessControlSections.Audit);
            return FileSystemAuditRule2.GetFileSystemAuditRules(sd, !excludeExplicit, !excludeInherited, getInheritedFrom);
        }

        private void WriteAuditRules(IEnumerable<FileSystemAuditRule2> acl)
        {
            if (account != null)
            {
                acl = acl.Where(ace => ace.Account == account);
            }

            acl.ForEach(ace => WriteObject(ace));
        }
    }
}