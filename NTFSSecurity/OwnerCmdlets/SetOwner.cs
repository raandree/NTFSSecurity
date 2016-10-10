using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Set, "NTFSOwner", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemOwner))]
    public class SetOwner : BaseCmdletWithPrivControl
    {
        private SwitchParameter passThru;
        private IdentityReference2 account;

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

        [Parameter(Mandatory = true, Position = 2, ValueFromPipelineByPropertyName = true)]
        public IdentityReference2 Account
        {
            get { return account; }
            set { account = value; }
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
                        FileSystemOwner.SetOwner(item, account);
                        WriteDebug("Owner set on item {0}", item.FullName);

                        if (passThru)
                        {
                            WriteObject(FileSystemOwner.GetOwner(item));
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "SetOwnerError", ErrorCategory.WriteError, path));
                        continue;
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    FileSystemOwner.SetOwner(sd, account);

                    if (passThru)
                    {
                        WriteObject(FileSystemOwner.GetOwner(sd));
                    }
                }
            }
        }
    }
}