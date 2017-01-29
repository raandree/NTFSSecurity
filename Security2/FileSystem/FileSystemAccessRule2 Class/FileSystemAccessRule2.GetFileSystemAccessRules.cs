using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        public static IEnumerable<FileSystemAccessRule2> GetFileSystemAccessRules(FileSystemInfo item, bool includeExplicit, bool includeInherited, bool getInheritedFrom = false)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Access);

            return GetFileSystemAccessRules(sd, includeExplicit, includeInherited, getInheritedFrom);
        }

        public static IEnumerable<FileSystemAccessRule2> GetFileSystemAccessRules(FileSystemSecurity2 sd, bool includeExplicit, bool includeInherited, bool getInheritedFrom = false)
        {
            List<FileSystemAccessRule2> aceList = new List<FileSystemAccessRule2>();
            List<string> inheritedFrom = null;

            if (getInheritedFrom)
            {
                inheritedFrom = Win32.GetInheritedFrom(sd.Item, sd.SecurityDescriptor);
            }

            var aceCounter = 0;
            var acl = !sd.IsFile ?
                ((DirectorySecurity)sd.SecurityDescriptor).GetAccessRules(includeExplicit, includeInherited, typeof(SecurityIdentifier)) :
                ((FileSecurity)sd.SecurityDescriptor).GetAccessRules(includeExplicit, includeInherited, typeof(SecurityIdentifier));

            foreach (FileSystemAccessRule ace in acl)
            {
                var ace2 = new FileSystemAccessRule2(ace) { FullName = sd.Item.FullName, InheritanceEnabled = !sd.SecurityDescriptor.AreAccessRulesProtected };
                if (getInheritedFrom && inheritedFrom.Count > 0)
                {
                    ace2.inheritedFrom = string.IsNullOrEmpty(inheritedFrom[aceCounter]) ? "" : inheritedFrom[aceCounter].Substring(0, inheritedFrom[aceCounter].Length - 1);
                    aceCounter++;
                }

                aceList.Add(ace2);
            }

            return aceList;
        }

        public static IEnumerable<FileSystemAccessRule2> GetFileSystemAccessRules(string path, bool includeExplicit, bool includeInherited, bool getInheritedFrom = false)
        {
            if (File.Exists(path))
            {
                return GetFileSystemAccessRules(new FileInfo(path), includeExplicit, includeInherited, getInheritedFrom);
            }
            else
            {
                return GetFileSystemAccessRules(new DirectoryInfo(path), includeExplicit, includeInherited, getInheritedFrom);
            }
        }
    }
}