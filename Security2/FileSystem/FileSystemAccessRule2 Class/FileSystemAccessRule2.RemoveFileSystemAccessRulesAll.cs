using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        public static void RemoveFileSystemAccessRuleAll(FileSystemSecurity2 sd, List<IdentityReference2> accounts = null)
        {
            var acl = sd.SecurityDescriptor.GetAccessRules(true, false, typeof(SecurityIdentifier));

            if (accounts != null)
            {
                acl.OfType<FileSystemAccessRule>().Where(ace => (accounts.Where(account => account == (IdentityReference2)ace.IdentityReference).Count() > 1));
            }

            foreach (FileSystemAccessRule ace in acl)
            {
                sd.SecurityDescriptor.RemoveAccessRuleSpecific(ace);
            }
        }

        public static void RemoveFileSystemAccessRuleAll(FileSystemInfo item, List<IdentityReference2> accounts = null)
        {
            var sd = new FileSystemSecurity2(item);

            RemoveFileSystemAccessRuleAll(sd, accounts);

            sd.Write();
        }
    }
}