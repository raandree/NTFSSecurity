using Security2;
using System;
using System.Management.Automation;
using System.Security.AccessControl;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Set, "NTFSSecurityDescriptor")]
    [OutputType(typeof(FileSystemSecurity2))]
    public class SetSecurityDescriptor : BaseCmdletWithPrivControl
    {
        private SwitchParameter passThru;

        [Parameter(Mandatory = true, Position = 2, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        public FileSystemSecurity2[] SecurityDescriptor
        {
            get { return securityDescriptors.ToArray(); }
            set
            {
                securityDescriptors.Clear();
                securityDescriptors.AddRange(value);
            }
        }

        [Parameter()]
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
            foreach (var sd in securityDescriptors)
            {
                try
                {
                    // Only the changed sections, so that an unchanged owner, for example, isn't written back (#34)
                    var changedSections = sd.ChangedSections;
                    if (changedSections == AccessControlSections.None)
                    {
                        WriteVerbose(string.Format("No section of the security descriptor of '{0}' changed since it was read or last written; nothing is written", sd.FullName));
                    }
                    else
                    {
                        WriteVerbose(string.Format("Writing the changed sections of the security descriptor of '{0}': {1}", sd.FullName, changedSections));
                    }

                    sd.WriteChanges();
                }
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        WriteChangesAsOwner(sd);
                    }
                    catch (Exception ex2)
                    {
                        WriteError(new ErrorRecord(ex2, "WriteSdError", ErrorCategory.WriteError, sd.Item));
                        continue;
                    }
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "WriteSdError", ErrorCategory.WriteError, sd.Item));
                    continue;
                }

                // After the write and outside its retry: before 5.0.0-rc6, a write that needed ownership wrote no
                // object, and a denied read started a retry of the write and ended in a WriteSdError.
                if (passThru)
                {
                    try
                    {
                        WriteObject(new FileSystemSecurity2(sd.Item));
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.ReadError, sd.Item));
                    }
                }
            }
        }

        // Like InvokeAsOwner, takes ownership for the write and sets the previous owner back on every exit path, but not
        // after a successful write of a descriptor that sets the owner itself, which would undo that owner.
        private void WriteChangesAsOwner(FileSystemSecurity2 sd)
        {
            var setsOwner = (sd.ChangedSections & AccessControlSections.Owner) == AccessControlSections.Owner;
            var previousOwner = FileSystemOwner.GetOwner(sd.Item).Owner;

            FileSystemOwner.SetOwner(sd.Item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

            var written = false;
            try
            {
                sd.WriteChanges();
                written = true;
            }
            finally
            {
                if (!(written && setsOwner))
                {
                    try
                    {
                        FileSystemOwner.SetOwner(sd.Item, previousOwner);
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "RestoreOwnerError", ErrorCategory.WriteError, sd.Item));
                    }
                }
            }
        }
    }
}
