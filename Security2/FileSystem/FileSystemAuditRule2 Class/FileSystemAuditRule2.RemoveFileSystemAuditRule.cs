using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        public static void RemoveFileSystemAuditRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            FileSystemAuditRule ace = null;

            if (item is FileInfo)
            {
                var file = (FileInfo)item;
                var sd = file.GetAccessControl(AccessControlSections.Audit);

                ace = (FileSystemAuditRule)sd.AuditRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);

                sd.RemoveAuditRule(ace);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Audit);

                ace = (FileSystemAuditRule)sd.AuditRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                sd.RemoveAuditRule(ace);

                directory.SetAccessControl(sd);
            }
        }

        public static void RemoveFileSystemAuditRule(FileSystemInfo item, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            foreach (var account in accounts)
            {
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }
        }

        public static void RemoveFileSystemAuditRule(FileSystemInfo item, FileSystemAuditRule ace)
        {
            if (item is FileInfo)
            {
                var file = (FileInfo)item;
                var sd = file.GetAccessControl(AccessControlSections.Audit);

                sd.RemoveAuditRuleSpecific(ace);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Audit);

                sd.RemoveAuditRuleSpecific(ace);

                directory.SetAccessControl(sd);
            }
        }

        public static void RemoveFileSystemAuditRule(string path, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }
            else
            {
                var item = new DirectoryInfo(path);
                RemoveFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags);
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
                aces.Add(RemoveFileSystemAuditRule(sd, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }
    }
}
