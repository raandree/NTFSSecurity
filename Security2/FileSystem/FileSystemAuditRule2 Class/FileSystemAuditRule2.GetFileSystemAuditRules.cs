using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        public static IEnumerable<FileSystemAuditRule2> GetFileSystemAuditRules(FileSystemInfo item, bool includeExplicit, bool includeInherited, bool getInheritedFrom = false)
        {
            var sd = new FileSystemSecurity2(item);

            return GetFileSystemAuditRules(sd, includeExplicit, includeInherited, getInheritedFrom);
        }

        public static IEnumerable<FileSystemAuditRule2> GetFileSystemAuditRules(FileSystemSecurity2 sd, bool includeExplicit, bool includeInherited, bool getInheritedFrom = false)
        {
            List<FileSystemAuditRule2> aceList = new List<FileSystemAuditRule2>();
            List<string> inheritedFrom = null;

            if (getInheritedFrom)
            {
                inheritedFrom = Win32.GetInheritedFrom(sd.Item, sd.SecurityDescriptor);
            }

            var aceCounter = 0;
            var acl = !sd.IsFile ?
                ((DirectorySecurity)sd.SecurityDescriptor).GetAuditRules(includeExplicit, includeInherited, typeof(SecurityIdentifier)) :
                ((FileSecurity)sd.SecurityDescriptor).GetAuditRules(includeExplicit, includeInherited, typeof(SecurityIdentifier));

            foreach (FileSystemAuditRule ace in acl)
            {
                var ace2 = new FileSystemAuditRule2(ace) { FullName = sd.Item.FullName, InheritanceEnabled = !sd.SecurityDescriptor.AreAccessRulesProtected };
                if (getInheritedFrom)
                {
                    ace2.inheritedFrom = string.IsNullOrEmpty(inheritedFrom[aceCounter]) ? "" : inheritedFrom[aceCounter].Substring(0, inheritedFrom[aceCounter].Length - 1);
                    aceCounter++;
                }

                aceList.Add(ace2);
            }

            return aceList;
        }

        public static IEnumerable<FileSystemAuditRule2> GetFileSystemAuditRules(string path, bool includeExplicit, bool includeInherited)
        {
            if (File.Exists(path))
            {
                var item = new FileInfo(path);
                return GetFileSystemAuditRules(item, includeExplicit, includeInherited);
            }
            else
            {
                var item = new DirectoryInfo(path);
                return GetFileSystemAuditRules(item, includeExplicit, includeInherited);
            }
        }
    }
}
