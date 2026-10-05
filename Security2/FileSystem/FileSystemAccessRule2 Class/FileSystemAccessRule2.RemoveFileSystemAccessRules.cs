using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        // Generic rights, such as GENERIC_ALL, appear in inherit-only entries. FileSystemSecurity.RemoveAccessRule
        // rebuilds a rule that doesn't match exactly and rejects generic rights then, so such a rule is removed
        // through ModifyAccessRule, which works on the access mask (#17).
        private static bool HasGenericRights(FileSystemRights2 rights)
        {
            return ((long)rights & 0xF0000000L) != 0;
        }

        private static void RemoveRule(FileSystemSecurity sd, FileSystemAccessRule ace, bool removeSpecific)
        {
            if (HasGenericRights((FileSystemRights2)(int)ace.FileSystemRights))
            {
                bool modified;
                sd.ModifyAccessRule(removeSpecific ? AccessControlModification.RemoveSpecific : AccessControlModification.Remove, ace, out modified);
            }
            else if (removeSpecific)
            {
                sd.RemoveAccessRuleSpecific(ace);
            }
            else
            {
                sd.RemoveAccessRule(ace);
            }
        }

        public static void RemoveFileSystemAccessRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow && !HasGenericRights(rights))
                rights = rights | FileSystemRights2.Synchronize;

            FileSystemAccessRule ace = null;

            if (item as FileInfo != null)
            {
                var file = (FileInfo)item;
                var sd = file.GetAccessControl(AccessControlSections.Access);

                ace = (FileSystemAccessRule)sd.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                RemoveRule(sd, ace, removeSpecific);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Access);

                ace = (FileSystemAccessRule)sd.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                RemoveRule(sd, ace, removeSpecific);

                directory.SetAccessControl(sd);
            }
        }

        public static void RemoveFileSystemAccessRule(FileSystemInfo item, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            foreach (var account in accounts)
            {
                RemoveFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
        }

        public static void RemoveFileSystemAccessRule(string path, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                RemoveFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
            else
            {
                var item = new DirectoryInfo(path);
                RemoveFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
        }

        public static void RemoveFileSystemAccessRule(string path, List<IdentityReference2> account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                RemoveFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
            else
            {
                var item = new DirectoryInfo(path);
                RemoveFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific);
            }
        }

        public static void RemoveFileSystemAccessRule(FileSystemInfo item, FileSystemAccessRule ace, bool removeSpecific = false)
        {
            if (item as FileInfo != null)
            {
                var file = (FileInfo)item;
                var sd = file.GetAccessControl(AccessControlSections.Access);

                RemoveRule(sd, ace, removeSpecific);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Access);

                RemoveRule(sd, ace, removeSpecific);

                directory.SetAccessControl(sd);
            }
        }

        public static FileSystemAccessRule2 RemoveFileSystemAccessRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow && !HasGenericRights(rights))
                rights = rights | FileSystemRights2.Synchronize;

            var ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
            if (sd.IsFile)
            {
                RemoveRule(((FileSecurity)sd.SecurityDescriptor), ace, removeSpecific);
            }
            else
            {
                RemoveRule(((DirectorySecurity)sd.SecurityDescriptor), ace, removeSpecific);
            }

            return ace;
        }

        public static IEnumerable<FileSystemAccessRule2> RemoveFileSystemAccessRule(FileSystemSecurity2 sd, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            var aces = new List<FileSystemAccessRule2>();

            foreach (var account in accounts)
            {
                aces.Add(RemoveFileSystemAccessRule(sd, account, rights, type, inheritanceFlags, propagationFlags, removeSpecific));
            }

            return aces;
        }
    }
}