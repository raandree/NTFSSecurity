using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        public static void RemoveFileSystemAuditRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            // Only the SACL, so that no other section that Windows returns with it is written back (#34)
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);

            // An item without audit entries can have no SACL at all. Then there is nothing to remove, and Windows denies
            // a write without any section: (5) Access is denied.
            if (!sd.HasSystemAcl)
            {
                return;
            }

            RemoveFileSystemAuditRule(sd, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            sd.Write();
        }

        public static void RemoveFileSystemAuditRule(FileSystemInfo item, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            foreach (var account in accounts)
            {
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
        }

        public static void RemoveFileSystemAuditRule(FileSystemInfo item, FileSystemAuditRule ace)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);
            if (!sd.HasSystemAcl)
            {
                return;
            }

            sd.SecurityDescriptor.RemoveAuditRuleSpecific(ace);
            sd.Write();
        }

        public static void RemoveFileSystemAuditRule(string path, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
            else
            {
                var item = new DirectoryInfo(path);
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
        }

        public static FileSystemAuditRule2 RemoveFileSystemAuditRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            var ace = (FileSystemAuditRule)sd.SecurityDescriptor.AuditRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
            if (sd.IsFile)
            {
                if (removeSpecific)
                    ((FileSecurity)sd.SecurityDescriptor).RemoveAuditRuleSpecific(ace);
                else
                    ((FileSecurity)sd.SecurityDescriptor).RemoveAuditRule(ace);
            }
            else
            {
                if (removeSpecific)
                    ((DirectorySecurity)sd.SecurityDescriptor).RemoveAuditRuleSpecific(ace);
                else
                    ((DirectorySecurity)sd.SecurityDescriptor).RemoveAuditRule(ace);
            }

            return ace;
        }

        public static IEnumerable<FileSystemAuditRule2> RemoveFileSystemAuditRule(FileSystemSecurity2 sd, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            var aces = new List<FileSystemAuditRule2>();

            foreach (var account in accounts)
            {
                aces.Add(RemoveFileSystemAuditRule(sd, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific));
            }

            return aces;
        }
    }
}
