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
            if (ParameterSetName == "SD")
            {
                foreach (var sd in securityDescriptors)
                {
                    WriteOrphanedAces(FileSystemAccessRule2.GetFileSystemAccessRules(sd, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom), sd.FullName);
                }

                return;
            }

            foreach (var path in paths)
            {
                FileSystemInfo item = null;
                IEnumerable<FileSystemAccessRule2> acl = null;

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
                        InvokeAsOwner(item, path, () =>
                        {
                            acl = FileSystemAccessRule2.GetFileSystemAccessRules(item, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom);
                        });
                    }
                    catch (Exception ex2)
                    {
                        this.WriteError(new ErrorRecord(ex2, "AddAceError", ErrorCategory.WriteError, path));
                        continue;
                    }
                }
                catch (Exception ex)
                {
                    this.WriteWarning(string.Format("Could not read item {0}. The error was: {1}", path, ex.Message));
                    continue;
                }

                WriteOrphanedAces(acl, path);
            }
        }

        private void WriteOrphanedAces(IEnumerable<FileSystemAccessRule2> acl, string path)
        {
            var orphanedAces = acl.Where(ace => string.IsNullOrEmpty(ace.Account.AccountName));
            if (Account != null)
            {
                orphanedAces = orphanedAces.Where(ace => ace.Account == Account);
            }

            var orphanedAceList = orphanedAces.ToList();
            orphanedSidCount += orphanedAceList.Count;

            WriteVerbose(string.Format("Item {0} knows about {1} orphaned SIDs in its ACL", path, orphanedAceList.Count));

            orphanedAceList.ForEach(ace => WriteObject(ace));
        }

        protected override void EndProcessing()
        {
            WriteVerbose(string.Format("Total orphaned Access Control Enties: {0}", orphanedSidCount));
            base.EndProcessing();
        }
    }
}