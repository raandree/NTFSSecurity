using Security2;
using System;
using System.Management.Automation;

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
                    sd.Write();

                    if (passThru)
                    {
                        WriteObject(new FileSystemSecurity2(sd.Item));
                    }
                }
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        var ownerInfo = FileSystemOwner.GetOwner(sd.Item);
                        var previousOwner = ownerInfo.Owner;

                        FileSystemOwner.SetOwner(sd.Item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                        sd.Write();

                        FileSystemOwner.SetOwner(sd.Item, previousOwner);
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
                }
            }
        }
    }
}
