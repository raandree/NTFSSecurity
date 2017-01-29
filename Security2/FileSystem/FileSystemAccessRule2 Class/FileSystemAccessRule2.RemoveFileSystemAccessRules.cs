using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        public static void RemoveFileSystemAccessRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            FileSystemAccessRule ace = null;

            if (item as FileInfo != null)
            {
                var file = (FileInfo)item;
                var sd = file.GetAccessControl(AccessControlSections.Access);

                ace = (FileSystemAccessRule)sd.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                if (removeSpecific)
                    sd.RemoveAccessRuleSpecific(ace);
                else
                    sd.RemoveAccessRule(ace);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Access);

                ace = (FileSystemAccessRule)sd.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                if (removeSpecific)
                    sd.RemoveAccessRuleSpecific(ace);
                else
                    sd.RemoveAccessRule(ace);

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

                if (removeSpecific)
                    sd.RemoveAccessRuleSpecific(ace);
                else
                    sd.RemoveAccessRule(ace);

                file.SetAccessControl(sd);
            }
            else
            {
                DirectoryInfo directory = (DirectoryInfo)item;

                var sd = directory.GetAccessControl(AccessControlSections.Access);

                if (removeSpecific)
                    sd.RemoveAccessRuleSpecific(ace);
                else
                    sd.RemoveAccessRule(ace);

                directory.SetAccessControl(sd);
            }
        }

        public static FileSystemAccessRule2 RemoveFileSystemAccessRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            var ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
            if (sd.IsFile)
            {
                if (removeSpecific)
                    ((FileSecurity)sd.SecurityDescriptor).RemoveAccessRuleSpecific(ace);
                else
                    ((FileSecurity)sd.SecurityDescriptor).RemoveAccessRule(ace);
            }
            else
            {
                if (removeSpecific)
                    ((DirectorySecurity)sd.SecurityDescriptor).RemoveAccessRuleSpecific(ace);
                else
                    ((DirectorySecurity)sd.SecurityDescriptor).RemoveAccessRule(ace);
            }

            return ace;
        }

        public static IEnumerable<FileSystemAccessRule2> RemoveFileSystemAccessRule(FileSystemSecurity2 sd, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            var aces = new List<FileSystemAccessRule2>();

            foreach (var account in accounts)
            {
                aces.Add(RemoveFileSystemAccessRule(sd, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }
    }
}