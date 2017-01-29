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
            IEnumerable<FileSystemAuditRule2> acl;
            FileSystemInfo item = null;

            foreach (var p in paths)
            {
                try
                {
                    item = this.GetFileSystemInfo2(p);
                }
                catch (Exception ex)
                {
                    this.WriteError(new ErrorRecord(ex, "ReadError", ErrorCategory.OpenError, p));
                    continue;
                }

                try
                {
                    acl = FileSystemAuditRule2.GetFileSystemAuditRules(item, !ExcludeExplicit, !ExcludeInherited, getInheritedFrom);

                    var orphanedAces = acl.Where(ace => string.IsNullOrEmpty(ace.Account.AccountName));
                    orphanedSidCount += orphanedAces.Count();

                    this.WriteVerbose(string.Format("Item {0} knows about {1} orphaned SIDs in its ACL", p, orphanedAces.Count()));
                    this.WriteObject(orphanedAces);
                }
                catch (Exception ex)
                {
                    this.WriteWarning(string.Format("Could not read item {0}. The error was: {1}", p, ex.Message));
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
