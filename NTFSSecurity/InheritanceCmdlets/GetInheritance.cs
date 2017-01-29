using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSInheritance", DefaultParameterSetName = "Path")]
    [OutputType(typeof(FileSystemInheritanceInfo))]
    public class GetInheritance : BaseCmdletWithPrivControl
    {
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

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
            EnableFileSystemPrivileges(true);

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetVariableValue("PWD").ToString() };
            }
        }

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "Path")
            {
                foreach (var path in paths)
                {
                    FileSystemInfo item = null;
                    FileSystemInheritanceInfo inheritanceInfo = null;

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
                        inheritanceInfo = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        try
                        {
                            var ownerInfo = FileSystemOwner.GetOwner(item);
                            var previousOwner = ownerInfo.Owner;

                            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                            inheritanceInfo = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(item);

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
                        if (inheritanceInfo != null)
                        {
                            WriteObject(inheritanceInfo);
                        }
                    }
                }
            }
            else
            {
                foreach (var sd in securityDescriptors)
                {
                    var inheritanceInfo = FileSystemInheritanceInfo.GetFileSystemInheritanceInfo(sd);

                    if (inheritanceInfo != null)
                    {
                        WriteObject(inheritanceInfo);
                    }
                }
            }
        }
    }
}