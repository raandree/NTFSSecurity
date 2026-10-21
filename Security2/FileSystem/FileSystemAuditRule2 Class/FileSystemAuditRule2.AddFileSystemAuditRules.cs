using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        public static FileSystemAuditRule2 AddFileSystemAuditRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            FileSystemAuditRule2 ace = null;

            if (sd.IsFile)
            {
                ace = (FileSystemAuditRule)sd.SecurityDescriptor.AuditRuleFactory(account, (int)rights, false, InheritanceFlags.None, PropagationFlags.None, type);
                ((FileSecurity)sd.SecurityDescriptor).AddAuditRule(ace);
            }
            else
            {
                ace = (FileSystemAuditRule)sd.SecurityDescriptor.AuditRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                ((DirectorySecurity)sd.SecurityDescriptor).AddAuditRule(ace);
            }

            return ace;
        }

        public static FileSystemAuditRule2 AddFileSystemAuditRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            // Only the SACL, so that neither the owner (#34) nor the DACL is written back
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);

            var ace = AddFileSystemAuditRule(sd, account, rights, type, inheritanceFlags, propagationFlags);

            sd.Write();

            return ace;
        }

        public static FileSystemAuditRule2 AddFileSystemAuditRule(string path, IdentityReference2 account, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            FileSystemAuditRule ace = null;

            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                ace = AddFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }
            else
            {
                var item = new DirectoryInfo(path);
                ace = AddFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }

            return ace;
        }

        public static IEnumerable<FileSystemAuditRule2> AddFileSystemAuditRule(FileSystemSecurity2 sd, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            var aces = new List<FileSystemAuditRule2>();

            foreach (var account in accounts)
            {
                aces.Add(AddFileSystemAuditRule(sd, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }

        public static IEnumerable<FileSystemAuditRule2> AddFileSystemAuditRule(FileSystemInfo item, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            var aces = new List<FileSystemAuditRule2>();

            foreach (var account in accounts)
            {
                aces.Add(AddFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }

        /// <summary>
        /// Adds one audit entry per account to the item at the path, and returns them in the order of
        /// <paramref name="accounts"/>. Before 5.0.0, this overload was an iterator (a yield return in the loop
        /// below), so nothing happened until the caller enumerated the result; called as a statement, or assigned to
        /// a variable that is never read, it changed nothing. It now builds the list and writes the entries before
        /// returning, like its FileSystemInfo and FileSystemSecurity2 siblings; an exception that adding an entry
        /// raises is now thrown by this call, not by the later enumeration.
        /// </summary>
        public static IEnumerable<FileSystemAuditRule2> AddFileSystemAuditRule(string path, List<IdentityReference2> accounts, FileSystemRights2 rights, AuditFlags type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            var aces = new List<FileSystemAuditRule2>();

            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                foreach (var account in accounts)
                {
                    aces.Add(AddFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags));
                }
            }
            else
            {
                var item = new DirectoryInfo(path);
                foreach (var account in accounts)
                {
                    aces.Add(AddFileSystemAuditRule(item, account, rights, type, inheritanceFlags, propagationFlags));
                }
            }

            return aces;
        }

        public static void AddFileSystemAuditRule(FileSystemAuditRule2 rule)
        {
            AddFileSystemAuditRule(rule.fullName,
                rule.Account,
                rule.AccessRights,
                rule.AuditFlags,
                rule.InheritanceFlags,
                rule.PropagationFlags);
        }
    }
}
