using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        public static FileSystemAccessRule2 AddFileSystemAccessRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            FileSystemAccessRule ace = null;

            if (sd.IsFile)
            {
                ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, InheritanceFlags.None, PropagationFlags.None, type);
                ((FileSecurity)sd.SecurityDescriptor).AddAccessRule(ace);
            }
            else
            {
                ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
                ((DirectorySecurity)sd.SecurityDescriptor).AddAccessRule(ace);
            }

            return ace;
        }

        public static FileSystemAccessRule2 AddFileSystemAccessRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            var sd = new FileSystemSecurity2(item);

            var ace = AddFileSystemAccessRule(sd, account, rights, type, inheritanceFlags, propagationFlags);

            sd.Write();

            return ace;
        }

        public static IEnumerable<FileSystemAccessRule2> AddFileSystemAccessRule(FileSystemInfo item, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            var aces = new List<FileSystemAccessRule2>();

            foreach (var account in accounts)
            {
                aces.Add(AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }

        public static IEnumerable<FileSystemAccessRule2> AddFileSystemAccessRule(FileSystemSecurity2 sd, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            var aces = new List<FileSystemAccessRule2>();

            foreach (var account in accounts)
            {
                aces.Add(AddFileSystemAccessRule(sd, account, rights, type, inheritanceFlags, propagationFlags));
            }

            return aces;
        }

        public static FileSystemAccessRule2 AddFileSystemAccessRule(string path, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            FileSystemAccessRule ace = null;

            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                ace = AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }
            else
            {
                var item = new DirectoryInfo(path);
                ace = AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags);
            }

            return ace;
        }

        public static IEnumerable<FileSystemAccessRule2> AddFileSystemAccessRule(string path, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                foreach (var account in accounts)
                {
                    yield return AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags);
                }
            }
            else
            {
                var item = new DirectoryInfo(path);
                foreach (var account in accounts)
                {
                    yield return AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags);
                }
            }
        }

        public static void AddFileSystemAccessRule(FileSystemAccessRule2 rule)
        {
            AddFileSystemAccessRule(rule.fullName,
                rule.Account,
                rule.AccessRights,
                rule.AccessControlType,
                rule.InheritanceFlags,
                rule.PropagationFlags);
        }
    }
}