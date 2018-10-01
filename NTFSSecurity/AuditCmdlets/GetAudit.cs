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
            IEnumerable<FileSystemAuditRule2> acl = null;
            FileSystemInfo item = null;

            if (ParameterSetName == "Path")
            {
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
                        acl = FileSystemAuditRule2.GetFileSystemAuditRules(item, !excludeExplicit, !excludeInherited, getInheritedFrom);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);
                            acl = FileSystemAuditRule2.GetFileSystemAuditRules(item, !excludeExplicit, !excludeInherited, getInheritedFrom);
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
                    finally
                    {
                        if (acl != null)
                        {
                            if (account != null)
                            {
                                acl = acl.Where(ace => ace.Account == account);
                            }

                            acl.ForEach(ace => WriteObject(ace));
                        }
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    acl = FileSystemAuditRule2.GetFileSystemAuditRules(sd, !excludeExplicit, !excludeInherited, getInheritedFrom);

                    if (account != null)
                    {
                        acl = acl.Where(ace => ace.Account == account);
                    }

                    acl.ForEach(ace => WriteObject(ace));
                }
            }
        }
    }
}