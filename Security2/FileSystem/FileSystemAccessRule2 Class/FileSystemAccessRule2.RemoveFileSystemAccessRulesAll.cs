using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        /// <summary>
        /// Removes the explicit access entries of the descriptor; with a non-null <paramref name="accounts"/>, only
        /// the entries whose account is in the list (compared like IdentityReference2.Equals), leaving the rest of
        /// the descriptor untouched. Before 5.0.0, the list was never applied: the filtered result was discarded, and
        /// every explicit entry was removed regardless of the list, including with an empty list.
        /// </summary>
        public static void RemoveFileSystemAccessRuleAll(FileSystemSecurity2 sd, List<IdentityReference2> accounts = null)
        {
            var acl = sd.SecurityDescriptor.GetAccessRules(true, false, typeof(SecurityIdentifier));

            var entriesToRemove = accounts == null ? acl.OfType<FileSystemAccessRule>() :
                acl.OfType<FileSystemAccessRule>().Where(ace => accounts.Any(account => account == (IdentityReference2)ace.IdentityReference));

            foreach (FileSystemAccessRule ace in entriesToRemove.ToList())
            {
                sd.SecurityDescriptor.RemoveAccessRuleSpecific(ace);
            }
        }

        public static void RemoveFileSystemAccessRuleAll(FileSystemInfo item, List<IdentityReference2> accounts = null)
        {
            // Only the DACL, so that the owner isn't written back (#34) and the inherited entries keep their flag
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);

            RemoveFileSystemAccessRuleAll(sd, accounts);

            sd.Write();
        }
    }
}