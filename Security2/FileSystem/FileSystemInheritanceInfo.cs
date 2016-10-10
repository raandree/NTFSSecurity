using Alphaleonis.Win32.Filesystem;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{

    public class FileSystemInheritanceInfo
    {
        private enum InheritanceScope
        {
            Access,
            Audit
        }

        private FileSystemInfo item;
        private bool? accessInheritanceEnabled;
        private bool? auditInheritanceEnabled;

        public FileSystemInfo Item
        {
            get { return item; }
            set { item = value; }
        }

        public bool? AccessInheritanceEnabled
        {
            get { return accessInheritanceEnabled; }
            set { accessInheritanceEnabled = value; }
        }

        public bool? AuditInheritanceEnabled
        {
            get { return auditInheritanceEnabled; }
            set { auditInheritanceEnabled = value; }
        }

        public string FullName { get { return Item.FullName; } }

        public string Name { get { return Path.GetFileName(item.FullName); } }

        private FileSystemInheritanceInfo(FileSystemInfo item, bool? accessInheritanceEnabled, bool? auditInheritanceEnabled)
        {
            this.item = item;
            this.accessInheritanceEnabled = accessInheritanceEnabled;
            this.auditInheritanceEnabled = auditInheritanceEnabled;
        }

        #region GetFileSystemInheritanceInfo
        public static FileSystemInheritanceInfo GetFileSystemInheritanceInfo(string path)
        {
            var item = new FileInfo(path);
            return GetFileSystemInheritanceInfo(item);
        }

        public static FileSystemInheritanceInfo GetFileSystemInheritanceInfo(FileSystemInfo item)
        {
            if (item is FileInfo)
            {

                bool? areAuditRulesProtected = null;

                var areAccessRulesProtected = ((FileInfo)item).GetAccessControl(AccessControlSections.Access).AreAccessRulesProtected;

                try
                {
                    areAuditRulesProtected = ((FileInfo)item).GetAccessControl(AccessControlSections.Audit).AreAuditRulesProtected;
                }
                catch (System.IO.IOException)
                {
                    //log that the security privilege is missing
                }

                return new FileSystemInheritanceInfo(item, !areAccessRulesProtected, !areAuditRulesProtected);
            }
            else
            {
                bool? areAuditRulesProtected = null;

                var areAccessRulesProtected = ((DirectoryInfo)item).GetAccessControl(AccessControlSections.Access).AreAccessRulesProtected;

                try
                {
                    areAuditRulesProtected = ((DirectoryInfo)item).GetAccessControl(AccessControlSections.Audit).AreAuditRulesProtected;
                }
                catch (System.IO.IOException)
                {
                    //log that the security privilege is missing
                }

                return new FileSystemInheritanceInfo(item, !areAccessRulesProtected, !areAuditRulesProtected);
            }
        }

        public static FileSystemInheritanceInfo GetFileSystemInheritanceInfo(FileSystemSecurity2 sd)
        {
            return new FileSystemInheritanceInfo(sd.Item, !sd.SecurityDescriptor.AreAccessRulesProtected, !sd.SecurityDescriptor.AreAuditRulesProtected);            
        }
        #endregion GetFileSystemInheritanceInfo

        #region Enable / DisableInheritance internal
        private static void EnableInheritance(FileSystemSecurity2 sd, bool removeExplicitAccessRules, InheritanceScope scope)
        {
            if (sd.IsFile)
            {
                if (scope == InheritanceScope.Access)
                {
                    sd.SecurityDescriptor.SetAccessRuleProtection(false, false);

                    //if RemoveExplicitAccessRules is set
                    if (removeExplicitAccessRules)
                    {
                        //remove all explicitly set ACEs from the item
                        foreach (FileSystemAccessRule ace in ((FileSecurity)sd.SecurityDescriptor).GetAccessRules(true, false, typeof(SecurityIdentifier)))
                        {
                            ((FileSecurity)sd.SecurityDescriptor).RemoveAccessRule(ace);
                        }
                    }
                }
                else
                {
                    sd.SecurityDescriptor.SetAuditRuleProtection(false, false);

                    //if RemoveExplicitAccessRules is set
                    if (removeExplicitAccessRules)
                    {
                        //remove all explicitly set ACEs from the item
                        foreach (FileSystemAuditRule ace in ((FileSecurity)sd.SecurityDescriptor).GetAuditRules(true, false, typeof(SecurityIdentifier)))
                        {
                            ((FileSecurity)sd.SecurityDescriptor).RemoveAuditRule(ace);
                        }
                    }
                }
            }
            else
            {
                if (scope == InheritanceScope.Access)
                {
                    ((DirectorySecurity)sd.SecurityDescriptor).SetAccessRuleProtection(false, false);

                    //if RemoveExplicitAccessRules is set
                    if (removeExplicitAccessRules)
                    {
                        //remove all explicitly set ACEs from the item
                        foreach (FileSystemAccessRule ace in ((DirectorySecurity)sd.SecurityDescriptor).GetAccessRules(true, false, typeof(SecurityIdentifier)))
                        {
                            ((DirectorySecurity)sd.SecurityDescriptor).RemoveAccessRule(ace);
                        }
                    }
                }
                else
                {
                    ((DirectorySecurity)sd.SecurityDescriptor).SetAuditRuleProtection(false, false);

                    //if RemoveExplicitAccessRules is set
                    if (removeExplicitAccessRules)
                    {
                        //remove all explicitly set ACEs from the item
                        foreach (FileSystemAuditRule ace in ((DirectorySecurity)sd.SecurityDescriptor).GetAuditRules(true, false, typeof(SecurityIdentifier)))
                        {
                            ((DirectorySecurity)sd.SecurityDescriptor).RemoveAuditRule(ace);
                        }
                    }
                }
            }
        }

        private static void DisableInheritance(FileSystemSecurity2 sd, bool removeInheritedAccessRules, InheritanceScope scope)
        {
            if (sd.IsFile)
            {
                if (scope == InheritanceScope.Access)
                    ((FileSecurity)sd.SecurityDescriptor).SetAccessRuleProtection(true, !removeInheritedAccessRules);
                else
                    ((FileSecurity)sd.SecurityDescriptor).SetAuditRuleProtection(true, !removeInheritedAccessRules);
            }
            else
            {
                if (scope == InheritanceScope.Access)
                    ((DirectorySecurity)sd.SecurityDescriptor).SetAccessRuleProtection(true, !removeInheritedAccessRules);
                else
                    ((DirectorySecurity)sd.SecurityDescriptor).SetAuditRuleProtection(true, !removeInheritedAccessRules);
            }
        }
        #endregion Enable / DisableInheritance internal

        #region Public Methods using SecurityDescriptor
        public static void EnableAccessInheritance(FileSystemSecurity2 sd, bool removeExplicitAccessRules)
        {
            EnableInheritance(sd, removeExplicitAccessRules, InheritanceScope.Access);
        }

        public static void EnableAuditInheritance(FileSystemSecurity2 sd, bool removeExplicitAccessRules)
        {
            EnableInheritance(sd, removeExplicitAccessRules, InheritanceScope.Audit);
        }

        public static void DisableAccessInheritance(FileSystemSecurity2 sd, bool removeExplicitAccessRules)
        {
            DisableInheritance(sd, removeExplicitAccessRules, InheritanceScope.Access);
        }

        public static void DisableAuditInheritance(FileSystemSecurity2 sd, bool removeExplicitAccessRules)
        {
            DisableInheritance(sd, removeExplicitAccessRules, InheritanceScope.Audit);
        }
        #endregion Public Methods using SecurityDescriptor

        #region Public Methods using FileSystemInfo
        public static void EnableAccessInheritance(FileSystemInfo item, bool removeExplicitAccessRules)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);
            EnableAccessInheritance(sd, removeExplicitAccessRules);
            sd.Write();
        }

        public static void DisableAccessInheritance(FileSystemInfo item, bool removeInheritedAccessRules)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);
            DisableAccessInheritance(sd, removeInheritedAccessRules);
            sd.Write();
        }

        public static void EnableAuditInheritance(FileSystemInfo item, bool removeExplicitAccessRules)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);
            EnableAuditInheritance(sd, removeExplicitAccessRules);
            sd.Write();
        }

        public static void DisableAuditInheritance(FileSystemInfo item, bool removeInheritedAccessRules)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Audit);
            DisableAuditInheritance(sd, removeInheritedAccessRules);
            sd.Write();
        }
        #endregion Public Methods using FileSystemInfo

        #region Public Methods using Path
        public static void EnableAccessInheritance(string path, bool removeExplicitAccessRules)
        {
            if (File.Exists(path))
            {
                EnableAccessInheritance(new FileInfo(path), removeExplicitAccessRules);
            }
            else if (Directory.Exists(path))
            {
                EnableAccessInheritance(new DirectoryInfo(path), removeExplicitAccessRules);
            }
        }

        public static void DisableAccessInheritance(string path, bool removeInheritedAccessRules)
        {
            if (File.Exists(path))
            {
                DisableAccessInheritance(new FileInfo(path), removeInheritedAccessRules);
            }
            else if (Directory.Exists(path))
            {
                DisableAccessInheritance(new DirectoryInfo(path), removeInheritedAccessRules);
            }
        }

        public static void EnableAuditInheritance(string path, bool removeExplicitAccessRules)
        {
            if (File.Exists(path))
            {
                EnableAuditInheritance(new FileInfo(path), removeExplicitAccessRules);
            }
            else if (Directory.Exists(path))
            {
                EnableAuditInheritance(new DirectoryInfo(path), removeExplicitAccessRules);
            }
        }

        public static void DisableAuditInheritance(string path, bool removeInheritedAccessRules)
        {
            if (File.Exists(path))
            {
                DisableAuditInheritance(new FileInfo(path), removeInheritedAccessRules);
            }
            else if (Directory.Exists(path))
            {
                DisableAuditInheritance(new DirectoryInfo(path), removeInheritedAccessRules);
            }
        }
        #endregion Public Methods using Path
    }
}