using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        public static void RemoveFileSystemAuditRuleAll(FileSystemSecurity2 sd, List<IdentityReference2> accounts = null)
        {
            var acl = sd.SecurityDescriptor.GetAuditRules(true, false, typeof(SecurityIdentifier));

            if (accounts != null)
            {
                acl.OfType<FileSystemAuditRule>().Where(ace => (accounts.Where(account => account == (IdentityReference2)ace.IdentityReference).Count() > 1));
            }

            foreach (FileSystemAuditRule ace in acl)
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
