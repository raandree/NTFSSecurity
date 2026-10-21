using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Linq;
using System.Management.Automation;
using System.Security.AccessControl;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Add, "NTFSAudit")]
    [OutputType(typeof(FileSystemAuditRule2))]
    public class AddAudit : BaseCmdletWithPrivControl
    {
        private IdentityReference2[] account;
        private FileSystemRights2 accessRights;
        private object auditFlags;
        private object inheritanceFlags;
        private object propagationFlags;
        private object appliesTo;
        private bool passThru;

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "PathSimple")]
        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
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
        [ArgumentCompleter(typeof(AuditFlagsArgumentCompleter))]
        public object AuditFlags
        {
            get { return auditFlags; }
            set { auditFlags = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "SDComplex")]
        [ArgumentCompleter(typeof(InheritanceFlagsArgumentCompleter))]
        public object InheritanceFlags
        {
            get { return inheritanceFlags; }
            set { inheritanceFlags = value; }
        }

        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "PathComplex")]
        [Parameter(ValueFromPipelineByPropertyName = true, ParameterSetName = "SDComplex")]
        [ArgumentCompleter(typeof(PropagationFlagsArgumentCompleter))]
        public object PropagationFlags
        {
            get { return propagationFlags; }
            set { propagationFlags = value; }
        }

        // Mandatory, so that a command without it resolves to the Complex parameter set, also for -SecurityDescriptor.
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "PathSimple")]
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "SDSimple")]
        [ArgumentCompleter(typeof(ApplyToArgumentCompleter))]
        public object AppliesTo
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
            // Checked here, before privileges are enabled, because only a value that came from the command line is
            // already bound at this point; a bad value from the pipeline is handled per record in ProcessRecord.
            ValidateNamedValue<AuditFlags>(auditFlags, "AuditFlags");
            ValidateNamedValue<InheritanceFlags>(inheritanceFlags, "InheritanceFlags");
            ValidateNamedValue<PropagationFlags>(propagationFlags, "PropagationFlags");
            ValidateNamedValue<ApplyTo>(appliesTo, "AppliesTo");

            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            AuditFlags auditFlagsValue;
            if (!TryConvertValue(auditFlags, "AuditFlags", System.Security.AccessControl.AuditFlags.Failure | System.Security.AccessControl.AuditFlags.Success, out auditFlagsValue))
            {
                return;
            }

            // The flags of this record are locals: the fields behind -InheritanceFlags and -PropagationFlags keep the value of the
            // previous piped object when the next one binds neither, so the scope that -AppliesTo converts to must not stay in them.
            var inheritance = System.Security.AccessControl.InheritanceFlags.ContainerInherit | System.Security.AccessControl.InheritanceFlags.ObjectInherit;
            var propagation = System.Security.AccessControl.PropagationFlags.None;

            if (ParameterSetName.EndsWith("Simple"))
            {
                ApplyTo appliesToValue;
                if (!TryConvertValue(appliesTo, "AppliesTo", default(ApplyTo), out appliesToValue))
                {
                    return;
                }

                FileSystemSecurity2.ConvertToFileSystemFlags(appliesToValue, out inheritance, out propagation);
            }
            else
            {
                InheritanceFlags inheritanceValue;
                if (!TryConvertValue(inheritanceFlags, "InheritanceFlags", inheritance, out inheritanceValue))
                {
                    return;
                }
                inheritance = inheritanceValue;

                PropagationFlags propagationValue;
                if (!TryConvertValue(propagationFlags, "PropagationFlags", propagation, out propagationValue))
                {
                    return;
                }
                propagation = propagationValue;
            }

            if (ParameterSetName.StartsWith("Path"))
            {
                FileSystemInfo item = null;

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
                        FileSystemAuditRule2.AddFileSystemAuditRule(item, account.ToList(), accessRights, auditFlagsValue, inheritance, propagation);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            InvokeAsOwner(item, path, () =>
                            {
                                FileSystemAuditRule2.AddFileSystemAuditRule(item, account.ToList(), accessRights, auditFlagsValue, inheritance, propagation);
                            });
                        }
                        catch (Exception ex2)
                        {
                            WriteError(new ErrorRecord(ex2, "AddAceError", ErrorCategory.WriteError, path));
                            continue;
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "AddAceError", ErrorCategory.WriteError, path));
                        continue;
                    }

                    if (passThru == true)
                    {
                        FileSystemAuditRule2.GetFileSystemAuditRules(item, true, true).ForEach(ace => WriteObject(ace));
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    if (!TestAuditSection(sd))
                    {
                        continue;
                    }

                    FileSystemAuditRule2.AddFileSystemAuditRule(sd, account.ToList(), accessRights, auditFlagsValue, inheritance, propagation);

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

        // A bad value named on the command line is already bound when BeginProcessing runs, so it is reported there
        // as a terminating error, the way the binder itself would have reported it for a typed parameter.
        private void ValidateNamedValue<T>(object value, string parameterName)
        {
            if (value == null)
            {
                return;
            }

            try
            {
                ParameterConversion.Convert<T>(value, parameterName);
            }
            catch (ArgumentException ex)
            {
                ThrowTerminatingError(new ErrorRecord(ex, "InvalidParameterValue", ErrorCategory.InvalidArgument, value));
            }
        }

        // A bad value that a piped object bound converts here, once per record. A null rawValue means the property
        // was not bound for this record, so the parameter's own default applies. A bad value is reported as one
        // non-terminating error per path or per descriptor, and the caller leaves the record alone and returns.
        private bool TryConvertValue<T>(object rawValue, string parameterName, T defaultValue, out T result)
        {
            if (rawValue == null)
            {
                result = defaultValue;
                return true;
            }

            try
            {
                result = ParameterConversion.Convert<T>(rawValue, parameterName);
                return true;
            }
            catch (ArgumentException ex)
            {
                result = defaultValue;
                WriteInvalidParameterValueErrors(ex);
                return false;
            }
        }

        private void WriteInvalidParameterValueErrors(Exception ex)
        {
            if (ParameterSetName.StartsWith("Path"))
            {
                foreach (var path in paths)
                {
                    WriteError(new ErrorRecord(ex, "InvalidParameterValue", ErrorCategory.InvalidArgument, path));
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    WriteError(new ErrorRecord(ex, "InvalidParameterValue", ErrorCategory.InvalidArgument, sd));
                }
            }
        }
    }
}