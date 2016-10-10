using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Set, "NTFSInheritance", DefaultParameterSetName = "Path")]
    public class SetInheritance : BaseCmdletWithPrivControl
    {
        private bool? accessInheritanceEnabled;
        private bool? auditInheritanceEnabled;
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

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public bool? AccessInheritanceEnabled
        {
            get { return accessInheritanceEnabled; }
            set { accessInheritanceEnabled = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public bool? AuditInheritanceEnabled
        {
            get { return auditInheritanceEnabled; }
            set { auditInheritanceEnabled = value; }
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
            EnableFileSystemPrivileges(true);
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
                        var currentState = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item);

                        if (currentState.AccessInheritanceEnabled != accessInheritanceEnabled)
                        {
                            WriteVerbose("AccessInheritanceEnabled not equal");
                            if (accessInheritanceEnabled.Value)
                            {
                                WriteVerbose("Calling EnableAccessInheritance");
                                FileSystemInheritanceInfo.EnableAccessInheritance(item, false);
                            }
                            else
                            {
                                WriteVerbose("Calling DisableAccessInheritance");
                                FileSystemInheritanceInfo.DisableAccessInheritance(item, true);
                            }
                        }
                        else
                            WriteVerbose("AccessInheritanceEnabled is equal - no change was done");

                        if (currentState.AuditInheritanceEnabled != auditInheritanceEnabled)
                        {
                            WriteVerbose("AuditInheritanceEnabled not equal");
                            if (auditInheritanceEnabled.Value)
                            {
                                WriteVerbose("Calling EnableAuditInheritance");
                                FileSystemInheritanceInfo.EnableAuditInheritance(item, true);
                            }
                            else
                            {
                                WriteVerbose("Calling DisableAuditInheritance");
                                FileSystemInheritanceInfo.DisableAuditInheritance(item, false);
                            }
                        }
                        else
                            WriteVerbose("AuditInheritanceEnabled is equal - no change was done");
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                            var currentState = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item);

                            if (currentState.AccessInheritanceEnabled != accessInheritanceEnabled)
                            {
                                WriteVerbose("AccessInheritanceEnabled not equal");
                                if (accessInheritanceEnabled.Value)
                                {
                                    WriteVerbose("Calling EnableAccessInheritance");
                                    FileSystemInheritanceInfo.EnableAccessInheritance(item, false);
                                }
                                else
                                {
                                    WriteVerbose("Calling DisableAccessInheritance");
                                    FileSystemInheritanceInfo.DisableAccessInheritance(item, true);
                                }
                            }
                            else
                                WriteVerbose("AccessInheritanceEnabled is equal - no change was done");

                            if (currentState.AuditInheritanceEnabled != auditInheritanceEnabled)
                            {
                                WriteVerbose("AuditInheritanceEnabled not equal");
                                if (auditInheritanceEnabled.Value)
                                {
                                    WriteVerbose("Calling EnableAuditInheritance");
                                    FileSystemInheritanceInfo.EnableAuditInheritance(item, true);
                                }
                                else
                                {
                                    WriteVerbose("Calling DisableAuditInheritance");
                                    FileSystemInheritanceInfo.DisableAuditInheritance(item, false);
                                }
                            }
                            else
                                WriteVerbose("AuditInheritanceEnabled is equal - no change was done");

                            FileSystemOwner.SetOwner(item, previousOwner);
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
                    finally
                    {
                        if (passThru)
                        {
                            WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item));
                        }
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    var currentState = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd);

                    if (currentState.AccessInheritanceEnabled != accessInheritanceEnabled)
                    {
                        WriteVerbose("AccessInheritanceEnabled not equal");
                        if (accessInheritanceEnabled.Value)
                        {
                            WriteVerbose("Calling EnableAccessInheritance");
                            FileSystemInheritanceInfo.EnableAccessInheritance(sd, false);
                        }
                        else
                        {
                            WriteVerbose("Calling DisableAccessInheritance");
                            FileSystemInheritanceInfo.DisableAccessInheritance(sd, true);
                        }
                    }
                    else
                        WriteVerbose("AccessInheritanceEnabled is equal - no change was done");

                    if (currentState.AuditInheritanceEnabled != auditInheritanceEnabled)
                    {
                        WriteVerbose("AuditInheritanceEnabled not equal");
                        if (auditInheritanceEnabled.Value)
                        {
                            WriteVerbose("Calling EnableAuditInheritance");
                            FileSystemInheritanceInfo.EnableAuditInheritance(sd, true);
                        }
                        else
                        {
                            WriteVerbose("Calling DisableAuditInheritance");
                            FileSystemInheritanceInfo.DisableAuditInheritance(sd, false);
                        }
                    }
                    else
                        WriteVerbose("AuditInheritanceEnabled is equal - no change was done");

                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd));
                    }
                }
            }
        }
    }
}