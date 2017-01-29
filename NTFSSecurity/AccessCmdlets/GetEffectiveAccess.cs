using Alphaleonis.Win32.Filesystem;
using ProcessPrivileges;
using Security2;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSEffectiveAccess", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemAccessRule2))]
    public class GetEffectiveAccess : BaseCmdletWithPrivControl
    {
        private IdentityReference2 account = System.Security.Principal.WindowsIdentity.GetCurrent().User.Value;
        private SwitchParameter excludeNoneAccessEntries;
        private string serverName = "localhost";
        private IEnumerable<PrivilegeAndAttributes> securityPrivilege;

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

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = true)]
        [Alias("NTAccount", "IdentityReference")]
        [ValidateNotNullOrEmpty]
        public IdentityReference2 Account
        {
            get { return account; }
            set { account = value; }
        }

        [Parameter]
        public string ServerName
        {
            get { return serverName; }
            set { serverName = value; }
        }

        [Parameter()]
        public SwitchParameter ExcludeNoneAccessEntries
        {
            get { return excludeNoneAccessEntries; }
            set { excludeNoneAccessEntries = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            if (paths == null)
            {
                paths = new List<string>() { GetVariableValue("PWD").ToString() };
            }

            var securityPrivilege = privControl.GetPrivileges().Where(priv => priv.Privilege == ProcessPrivileges.Privilege.Security);
            if (securityPrivilege.Count() == 0)
            {
                this.WriteWarning("The user does not hold the Security Privliege and might not be able to read the effective permissions");
            }
            else
            {
                if (securityPrivilege.FirstOrDefault().PrivilegeState == PrivilegeState.Disabled)
                {
                    this.WriteWarning("The user does hold the Security Privilege but it is disabled. Hence getting effective permissions might not be possible. Use 'Enable-Privileges' to enable it");
                }
            }
        }

        protected override void ProcessRecord()
        {
            FileSystemInfo item = null;

            foreach (var path in paths)
            {
                EffectiveAccessInfo result = null;

                try
                {
                    item = this.GetFileSystemInfo2(path);
                }
                catch (Exception ex)
                {
                    this.WriteError(new ErrorRecord(ex, "ReadFileError", ErrorCategory.OpenError, path));
                    continue;
                }

                try
                {
                    result = EffectiveAccess.GetEffectiveAccess(item, account, serverName);

                    if (!result.FromRemote)
                    {
                        WriteWarning("The effective rights can only be computed based on group membership on this" +
                                      " computer. For more accurate results, calculate effective access rights on " +
                                      "the target computer");
                    }
                    if (result.OperationFailed && securityPrivilege == null)
                    {
                        var ex = new Exception(string.Format("Could not get effective permissions from machine '{0}' maybe because the 'Security' privilege is not enabled which might be required. Enable the priviliges using 'Enable-Privileges'. The error was '{1}'", serverName, result.AuthzException.Message), result.AuthzException);
                        WriteError(new ErrorRecord(ex, "GetEffectiveAccessError", ErrorCategory.ReadError, item));
                        continue;
                    }
                    else if (result.OperationFailed)
                    {
                        var ex = new Exception(string.Format("Could not get effective permissions from machine '{0}'. The error is '{1}'", serverName, result.AuthzException.Message), result.AuthzException);
                        WriteError(new ErrorRecord(ex, "GetEffectiveAccessError", ErrorCategory.ReadError, item));
                        continue;
                    }

                    if (excludeNoneAccessEntries && result.Ace.AccessRights == FileSystemRights2.None)
                        continue;
                }
                //not sure if the following catch block willb be invoked, testing needed.
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        var ownerInfo = FileSystemOwner.GetOwner(item);
                        var previousOwner = ownerInfo.Owner;

                        FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                        //--------------------

                        result = EffectiveAccess.GetEffectiveAccess(item, account, serverName);

                        if (!result.FromRemote)
                        {
                            WriteWarning("The effective rights can only be computed based on group membership on this" +
                                          " computer. For more accurate results, calculate effective access rights on " +
                                          "the target computer");
                        }
                        if (result.OperationFailed && securityPrivilege == null)
                        {
                            var ex = new Exception(string.Format("Could not get effective permissions from machine '{0}' maybe because the 'Security' privilege is not enabled which might be required. Enable the priviliges using 'Enable-Privileges'. The error was '{1}'", serverName, result.AuthzException.Message), result.AuthzException);
                            WriteError(new ErrorRecord(ex, "GetEffectiveAccessError", ErrorCategory.ReadError, item));
                            continue;
                        }
                        else if (result.OperationFailed)
                        {
                            var ex = new Exception(string.Format("Could not get effective permissions from machine '{0}'. The error is '{1}'", serverName, result.AuthzException.Message), result.AuthzException);
                            WriteError(new ErrorRecord(ex, "GetEffectiveAccessError", ErrorCategory.ReadError, item));
                            continue;
                        }

                        if (excludeNoneAccessEntries && result.Ace.AccessRights == FileSystemRights2.None)
                            continue;

                        //--------------------

                        FileSystemOwner.SetOwner(item, previousOwner);
                    }
                    catch (Exception ex2)
                    {
                        this.WriteError(new ErrorRecord(ex2, "ReadSecurityError", ErrorCategory.WriteError, path));
                    }
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "ReadEffectivePermissionError", ErrorCategory.ReadError, path));
                }
                finally
                {
                    if (result != null)
                    {
                        WriteObject(result.Ace);
                    }
                }
            }
        }
    }
}