using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity.AuditCmdlets
{
    [Cmdlet(VerbsCommon.Get, "NTFSOrphanedAudit")]
    [OutputType(typeof(FileSystemAuditRule2))]
    public class GetOrphanedAudit : GetAudit
    {
        int orphanedSidCount = 0;

        protected override void ProcessRecord()
        {
            if (ParameterSetName == "SD")
            {
                foreach (var sd in securityDescriptors)
                {
                    if (!sd.HasAuditSection)
                    {
                        var ex = new InvalidOperationException(string.Format(
                            "The security descriptor of '{0}' doesn't contain the audit entries, because it was read without the Security privilege.", sd.FullName));
                        WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.InvalidData, sd));
                        continue;
                    }

                    WriteOrphanedAces(FileSystemAuditRule2.GetFileSystemAuditRules(sd, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom), sd.FullName);
                }

                return;
            }

            foreach (var p in paths)
            {
                FileSystemInfo item = null;

                try
                {
                    item = this.GetFileSystemInfo2(p);
                }
                catch (Exception ex)
                {
                    this.WriteError(new ErrorRecord(ex, "ReadError", ErrorCategory.OpenError, p));
                    continue;
                }

                IEnumerable<FileSystemAuditRule2> acl = null;

                try
                {
                    acl = FileSystemAuditRule2.GetFileSystemAuditRules(item, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom);
                }
                catch (Exception ex)
                {
                    this.WriteWarning(string.Format("Could not read item {0}. The error was: {1}", p, ex.Message));
                    continue;
                }

                // Outside the try block, so that a stopped pipeline isn't reported as a read error.
                WriteOrphanedAces(acl, p);
            }
        }

        private void WriteOrphanedAces(IEnumerable<FileSystemAuditRule2> acl, string path)
        {
            var orphanedAces = acl.Where(ace => string.IsNullOrEmpty(ace.Account.AccountName));
            if (Account != null)
            {
                orphanedAces = orphanedAces.Where(ace => ace.Account == Account);
            }

            var orphanedAceList = orphanedAces.ToList();
            orphanedSidCount += orphanedAceList.Count;

            this.WriteVerbose(string.Format("Item {0} knows about {1} orphaned SIDs in its ACL", path, orphanedAceList.Count));

            // One object per entry, not one collection per item
            orphanedAceList.ForEach(ace => WriteObject(ace));
        }

        protected override void EndProcessing()
        {
            WriteVerbose(string.Format("Total orphaned Access Control Enties: {0}", orphanedSidCount));
            base.EndProcessing();
        }
    }
}