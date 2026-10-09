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
                inheritedFrom = Win32.GetInheritedFrom(sd.Item, sd.SecurityDescriptor, true);
            }

            // All entries, so that each entry gets the source at its index in the SACL; before 5.0.0-rc6, the entries of
            // -ExcludeExplicit got the sources of other entries. The filter follows.
            var aceCounter = 0;
            var acl = !sd.IsFile ?
                ((DirectorySecurity)sd.SecurityDescriptor).GetAuditRules(true, true, typeof(SecurityIdentifier)) :
                ((FileSecurity)sd.SecurityDescriptor).GetAuditRules(true, true, typeof(SecurityIdentifier));

            foreach (FileSystemAuditRule ace in acl)
            {
                var source = getInheritedFrom && aceCounter < inheritedFrom.Count ? inheritedFrom[aceCounter] : null;
                aceCounter++;
                if (ace.IsInherited ? !includeInherited : !includeExplicit)
                {
                    continue;
                }

                var ace2 = new FileSystemAuditRule2(ace) { FullName = sd.Item.FullName, InheritanceEnabled = !sd.SecurityDescriptor.AreAuditRulesProtected };
                if (getInheritedFrom && inheritedFrom.Count > 0)
                {
                    // Windows names a folder with a trailing backslash; the text for an unknown parent has none.
                    ace2.inheritedFrom = string.IsNullOrEmpty(source) ? "" : source.TrimEnd('\\');
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
