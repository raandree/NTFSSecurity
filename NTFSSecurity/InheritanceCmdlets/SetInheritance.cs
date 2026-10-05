using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Set, "NTFSInheritance", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemInheritanceInfo))]
    public class SetInheritance : BaseCmdletWithPrivControl
    {
        private bool? accessInheritanceEnabled;
        private bool? auditInheritanceEnabled;
        private bool passThru;

        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "Path")]
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
                        SetInheritanceState(item);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            InvokeAsOwner(item, path, () =>
                            {
                                SetInheritanceState(item);
                            });
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

                    // Only after a successful change, so that a failure doesn't report the unchanged state
                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item));
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    SetInheritanceState(sd);

                    if (passThru)
                    {
                        WriteObject(FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd));
                    }
                }
            }
        }

        private void SetInheritanceState(FileSystemInfo item)
        {
            var currentState = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item);

            if (IsChangeRequested("AccessInheritanceEnabled", accessInheritanceEnabled, currentState.AccessInheritanceEnabled))
            {
                if (accessInheritanceEnabled.Value)
                {
                    WriteVerbose("Calling EnableAccessInheritance");
                    FileSystemInheritanceInfo.EnableAccessInheritance(item, false);
                }
                else
                {
                    WriteVerbose("Calling DisableAccessInheritance");
                    FileSystemInheritanceInfo.DisableAccessInheritance(item, false);
                }
            }

            if (IsChangeRequested("AuditInheritanceEnabled", auditInheritanceEnabled, currentState.AuditInheritanceEnabled))
            {
                if (auditInheritanceEnabled.Value)
                {
                    WriteVerbose("Calling EnableAuditInheritance");
                    FileSystemInheritanceInfo.EnableAuditInheritance(item, false);
                }
                else
                {
                    WriteVerbose("Calling DisableAuditInheritance");
                    FileSystemInheritanceInfo.DisableAuditInheritance(item, false);
                }
            }
        }

        private void SetInheritanceState(FileSystemSecurity2 sd)
        {
            var currentState = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd);

            if (IsChangeRequested("AccessInheritanceEnabled", accessInheritanceEnabled, currentState.AccessInheritanceEnabled))
            {
                if (accessInheritanceEnabled.Value)
                {
                    WriteVerbose("Calling EnableAccessInheritance");
                    FileSystemInheritanceInfo.EnableAccessInheritance(sd, false);
                }
                else
                {
                    WriteVerbose("Calling DisableAccessInheritance");
                    FileSystemInheritanceInfo.DisableAccessInheritance(sd, false);
                }
            }

            if (IsChangeRequested("AuditInheritanceEnabled", auditInheritanceEnabled, currentState.AuditInheritanceEnabled))
            {
                if (auditInheritanceEnabled.Value)
                {
                    WriteVerbose("Calling EnableAuditInheritance");
                    FileSystemInheritanceInfo.EnableAuditInheritance(sd, false);
                }
                else
                {
                    WriteVerbose("Calling DisableAuditInheritance");
                    FileSystemInheritanceInfo.DisableAuditInheritance(sd, false);
                }
            }
        }

        // An omitted parameter leaves its section unchanged.
        private bool IsChangeRequested(string parameterName, bool? requestedState, bool? currentState)
        {
            if (!requestedState.HasValue)
            {
                WriteVerbose(string.Format("{0} not specified - no change was done", parameterName));
                return false;
            }

            if (currentState == requestedState)
            {
                WriteVerbose(string.Format("{0} is equal - no change was done", parameterName));
                return false;
            }

            WriteVerbose(string.Format("{0} not equal", parameterName));
            return true;
        }
    }
}