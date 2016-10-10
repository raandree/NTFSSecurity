using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSOrphanedAccess")]
    [OutputType(typeof(FileSystemAccessRule2))]
    public class GetOrphanedAccess : GetAccess
    {
        int orphanedSidCount = 0;

        protected override void ProcessRecord()
        {
            IEnumerable<FileSystemAccessRule2> acl = null;
            FileSystemInfo item = null;

            foreach (var path in paths)
            {
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
                    acl = FileSystemAccessRule2.GetFileSystemAccessRules(item, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom);
                }
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        var ownerInfo = FileSystemOwner.GetOwner(item);
                        var previousOwner = ownerInfo.Owner;

                        FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                        acl = FileSystemAccessRule2.GetFileSystemAccessRules(item, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom);

                        FileSystemOwner.SetOwner(item, previousOwner);
                    }
                    catch (Exception ex2)
                    {
                        this.WriteError(new ErrorRecord(ex2, "AddAceError", ErrorCategory.WriteError, path));
                    }
                }
                catch (Exception ex)
                {
                    this.WriteWarning(string.Format("Could not read item {0}. The error was: {1}", path, ex.Message));
                }
                finally
                {
                    if (acl != null)
                    {
                        var orphanedAces = acl.Where(ace => string.IsNullOrEmpty(ace.Account.AccountName));
                        orphanedSidCount += orphanedAces.Count();

                        WriteVerbose(string.Format("Item {0} knows about {1} orphaned SIDs in its ACL", path, orphanedAces.Count()));

                        orphanedAces.ForEach(ace => WriteObject(ace));
                    }
                }
            }
        }

        protected override void EndProcessing()
        {
            WriteVerbose(string.Format("Total orphaned Access Control Enties: {0}", orphanedSidCount));
            base.EndProcessing();
        }
    }
}
