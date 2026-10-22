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

            // Only the DACL, so that the owner isn't written back (#34) and the inherited entries keep their flag
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);

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

        /// <summary>
        /// Adds one access entry per account to the item at the path, and returns them in the order of
        /// <paramref name="accounts"/>. Before 5.0.0, this overload was an iterator (a yield return in the loop
        /// below), so nothing happened until the caller enumerated the result; called as a statement, or assigned to
        /// a variable that is never read, it changed nothing. It now builds the list and writes the entries before
        /// returning, like its FileSystemInfo and FileSystemSecurity2 siblings; an exception that adding an entry
        /// raises is now thrown by this call, not by the later enumeration.
        /// </summary>
        public static IEnumerable<FileSystemAccessRule2> AddFileSystemAccessRule(string path, List<IdentityReference2> accounts, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            var aces = new List<FileSystemAccessRule2>();

            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                foreach (var account in accounts)
                {
                    aces.Add(AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags));
                }
            }
            else
            {
                var item = new DirectoryInfo(path);
                foreach (var account in accounts)
                {
                    aces.Add(AddFileSystemAccessRule(item, account, rights, type, inheritanceFlags, propagationFlags));
                }
            }

            return aces;
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