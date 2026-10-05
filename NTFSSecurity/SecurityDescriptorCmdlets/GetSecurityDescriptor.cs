using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSSecurityDescriptor")]
    [OutputType(typeof(FileSystemSecurity2))]
    public class GetSecurityDescriptor : BaseCmdletWithPrivControl
    {
        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
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

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            if (paths.Count == 0)
            {
                paths.Add(GetVariableValue("PWD").ToString());
            }
        }

        protected override void ProcessRecord()
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
                    WriteObject(new FileSystemSecurity2(item));
                }
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        InvokeAsOwner(item, path, () =>
                        {
                            WriteObject(new FileSystemSecurity2(item));
                        });
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
                }
            }
        }
    }
}
