using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        // Rights that FileSystemAccessRule.AccessMaskFromRights rejects, such as the generic rights, which Windows
        // keeps in the inherit-only entries of folders (#17).
        private static bool HasUnsupportedRights(int accessMask)
        {
            return accessMask < 0 || accessMask > (int)FileSystemRights.FullControl;
        }

        // FileSystemSecurity.RemoveAccessRule removes a rule that matches an entry exactly as it is, and otherwise
        // rebuilds it without the Synchronize right, which fails for unsupported rights. For those, do the same
        // without rebuilding the rule.
        private static void RemoveRule(FileSystemSecurity sd, FileSystemAccessRule ace, bool removeSpecific)
        {
            var accessMask = (int)ace.FileSystemRights;

            if (!HasUnsupportedRights(accessMask))
            {
                if (removeSpecific)
                    sd.RemoveAccessRuleSpecific(ace);
                else
                    sd.RemoveAccessRule(ace);

                return;
            }

            var sid = (SecurityIdentifier)ace.IdentityReference.Translate(typeof(SecurityIdentifier));
            var exactMatch = sd.GetAccessRules(true, true, typeof(SecurityIdentifier))
                .OfType<FileSystemAccessRule>()
                .Any(rule => (int)rule.FileSystemRights == accessMask &&
                    rule.IdentityReference == sid &&
                    rule.AccessControlType == ace.AccessControlType);

            var ruleToRemove = exactMatch ? ace : (FileSystemAccessRule)sd.AccessRuleFactory(sid,
                accessMask & ~(int)FileSystemRights.Synchronize, false, ace.InheritanceFlags, ace.PropagationFlags, ace.AccessControlType);

            // Like RemoveAccessRule, ignore whether an entry was changed: removing an entry that doesn't exist is not
            // an error.
            bool modified;
            sd.ModifyAccessRule(removeSpecific ? AccessControlModification.RemoveSpecific : AccessControlModification.Remove, ruleToRemove, out modified);
        }
        public static void RemoveFileSystemAccessRule(FileSystemInfo item, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            // Only the DACL: Windows can return the owner with it, and writing that back fails for an owner that the user
            // cannot assign (#34).
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);

            var ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
            RemoveRule(sd.SecurityDescriptor, ace, removeSpecific);

            sd.Write();
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
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);

            RemoveRule(sd.SecurityDescriptor, ace, removeSpecific);

            sd.Write();
        }

        public static FileSystemAccessRule2 RemoveFileSystemAccessRule(FileSystemSecurity2 sd, IdentityReference2 account, FileSystemRights2 rights, AccessControlType type, InheritanceFlags inheritanceFlags, PropagationFlags propagationFlags, bool removeSpecific = false)
        {
            if (type == AccessControlType.Allow)
                rights = rights | FileSystemRights2.Synchronize;

            var ace = (FileSystemAccessRule)sd.SecurityDescriptor.AccessRuleFactory(account, (int)rights, false, inheritanceFlags, propagationFlags, type);
            RemoveRule(sd.SecurityDescriptor, ace, removeSpecific);

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