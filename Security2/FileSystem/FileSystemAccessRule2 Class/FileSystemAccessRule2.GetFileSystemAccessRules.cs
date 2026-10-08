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
                inheritedFrom = Win32.GetInheritedFrom(sd.Item, sd.SecurityDescriptor, false);
            }

            // All entries, so that each entry gets the source at its index in the DACL; before 5.0.0-rc6, the entries of
            // -ExcludeExplicit got the sources of other entries. The filter follows.
            var aceCounter = 0;
            var acl = !sd.IsFile ?
                ((DirectorySecurity)sd.SecurityDescriptor).GetAccessRules(true, true, typeof(SecurityIdentifier)) :
                ((FileSecurity)sd.SecurityDescriptor).GetAccessRules(true, true, typeof(SecurityIdentifier));

            foreach (FileSystemAccessRule ace in acl)
            {
                var source = getInheritedFrom && aceCounter < inheritedFrom.Count ? inheritedFrom[aceCounter] : null;
                aceCounter++;
                if (ace.IsInherited ? !includeInherited : !includeExplicit)
                {
                    continue;
                }

                var ace2 = new FileSystemAccessRule2(ace) { FullName = sd.Item.FullName, InheritanceEnabled = !sd.SecurityDescriptor.AreAccessRulesProtected };
                if (getInheritedFrom && inheritedFrom.Count > 0)
                {
                    ace2.inheritedFrom = string.IsNullOrEmpty(source) ? "" : source.Substring(0, source.Length - 1);
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