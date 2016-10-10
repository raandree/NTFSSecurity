using System.Management.Automation;
using Security2;
using System.IO;
using System.Linq;
using System;
using System.Security.AccessControl;

namespace NTFSSecurity
{
    #region Enable-Privileges
    [Cmdlet(VerbsLifecycle.Enable, "Privileges")]
    [OutputType(typeof(ProcessPrivileges.PrivilegeAndAttributes))]
    public class EnablePrivileges : BaseCmdletWithPrivControl
    {
        private bool enablePrivileges = false;
        private SwitchParameter passThru;
        public string[] Path { get; set; }

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
            var privateData = (System.Collections.Hashtable)this.MyInvocation.MyCommand.Module.PrivateData;
            var psCallStack = (CallStackFrame)this.InvokeCommand.InvokeScript("Get-PSCallStack")[1].BaseObject;

            try
            {
                enablePrivileges = (bool)privateData["EnablePrivileges"];
            }
            catch (Exception ex)
            {
                throw new ParseException("Could not parse the module's PrivateData field in the module's psd1 file. Please refer to the documentation for further details", ex);
            }

            //if the command is called from NTFSSecurity.Init.ps1 and EnablePrivileges is set to true in the NTFSSecurity.psd1 or if the cmdlet is called from somewhere else
            if ((psCallStack.InvocationInfo.MyCommand.Name == "NTFSSecurity.Init.ps1" && enablePrivileges == true))
            {
                this.EnableFileSystemPrivileges(false);
            }
            else if (psCallStack.InvocationInfo.MyCommand.Name != "NTFSSecurity.Init.ps1")
            {
                this.EnableFileSystemPrivileges(false);
            }

            if (passThru)
            {
                this.WriteObject(this.privControl.GetPrivileges());
            }
        }

        protected override void EndProcessing()
        {
            //nothing as we want to keep the privileges enabled  
        }
    }
    #endregion Enable-Privileges

    #region Disable-Privileges
    [Cmdlet(VerbsLifecycle.Disable, "Privileges")]
    [OutputType(typeof(ProcessPrivileges.PrivilegeAndAttributes))]
    public class DisablePrivileges : BaseCmdletWithPrivControl
    {
        private SwitchParameter passThru;
        public string[] Path { get; set; }

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
            if (this.privControl.GetPrivileges()
                .Where(p => p.PrivilegeState == ProcessPrivileges.PrivilegeState.Enabled)
                .Where(p => (
                    p.Privilege == ProcessPrivileges.Privilege.TakeOwnership) |
                    (p.Privilege == ProcessPrivileges.Privilege.Restore) |
                    (p.Privilege == ProcessPrivileges.Privilege.Backup))
                .Count() == 0)
            {
                this.WriteError(new ErrorRecord(new AdjustPriviledgeException("Privileges are not enabled"), "Disable Privilege Error", ErrorCategory.SecurityError, null));
                return;
            }

            this.DisableFileSystemPrivileges();
            this.WriteVerbose("The privileges 'TakeOwnership', 'Restore' and 'Backup' are now enabled.");

            if (passThru)
            {
                this.WriteObject(this.privControl.GetPrivileges());
            }
        }

        protected override void EndProcessing()
        {
            //nothing as priviliges should already been cleaned up
        }
    }
    #endregion Enable-Privileges

    #region Get-Privileges
    [Cmdlet(VerbsCommon.Get, "Privileges")]
    [OutputType(typeof(ProcessPrivileges.PrivilegeAndAttributes))]
    public class GetPrivileges : BaseCmdlet
    {
        public string[] Path { get; set; }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            var privControl = new PrivilegeControl();

            this.WriteObject(privControl.GetPrivileges(), true);
        }
    }
    #endregion Get-Privileges
}