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

            // The source of an inherited entry is found from the path of the item that the descriptor was read from;
            // a descriptor that a caller built directly, such as the conversion from FileSecurity, has none. Such an
            // entry gets no source, the same as one whose source Windows could not name: a cmdlet caller has no
            // parameter to turn getInheritedFrom off (the module setting GetInheritedFrom is true by default), so an
            // exception here would stop a cmdlet that a descriptor without an item was never meant to reach.
            var findInheritedFrom = getInheritedFrom && sd.Item != null;

            if (findInheritedFrom)
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
                var source = findInheritedFrom && aceCounter < inheritedFrom.Count ? inheritedFrom[aceCounter] : null;
                aceCounter++;
                if (ace.IsInherited ? !includeInherited : !includeExplicit)
                {
                    continue;
                }

                // sd.FullName, not sd.Item.FullName: null without an item instead of a NullReferenceException.
                var ace2 = new FileSystemAccessRule2(ace) { FullName = sd.FullName, InheritanceEnabled = !sd.SecurityDescriptor.AreAccessRulesProtected };
                if (findInheritedFrom && inheritedFrom.Count > 0)
                {
                    // Windows names a folder with a trailing backslash; the text for an unknown parent has none.
                    ace2.inheritedFrom = string.IsNullOrEmpty(source) ? "" : source.TrimEnd('\\');
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