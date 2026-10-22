using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        /// <summary>
        /// Removes the explicit audit entries of the descriptor; with a non-null <paramref name="accounts"/>, only
        /// the entries whose account is in the list (compared like IdentityReference2.Equals), leaving the rest of
        /// the descriptor untouched. Before 5.0.0, the list was never applied: the filtered result was discarded, and
        /// every explicit entry was removed regardless of the list, including with an empty list.
        /// </summary>
        public static void RemoveFileSystemAuditRuleAll(FileSystemSecurity2 sd, List<IdentityReference2> accounts = null)
        {
            var acl = sd.SecurityDescriptor.GetAuditRules(true, false, typeof(SecurityIdentifier));

            var entriesToRemove = accounts == null ? acl.OfType<FileSystemAuditRule>() :
                acl.OfType<FileSystemAuditRule>().Where(ace => accounts.Any(account => account == (IdentityReference2)ace.IdentityReference));

            foreach (FileSystemAuditRule ace in entriesToRemove.ToList())
            {
                sd.SecurityDescriptor.RemoveAuditRuleSpecific(ace);
            }
        }

        public static void RemoveFileSystemAuditRuleAll(FileSystemInfo item, List<IdentityReference2> accounts = null)
        {
            // Only the SACL, so that neither the owner (#34) nor the DACL is written back
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);

            RemoveFileSystemAuditRuleAll(sd, accounts);

            // An item without audit entries can have no SACL at all. Then there is nothing to remove, and Windows denies
            // a write without any section: (5) Access is denied.
            if (sd.HasSystemAcl)
            {
                sd.Write();
            }
        }
    }
}
