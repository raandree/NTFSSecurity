using Alphaleonis.Win32.Filesystem;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAccessRule2
    {
        #region Properties
        private FileSystemAccessRule fileSystemAccessRule;
        private string fullName;
        private bool inheritanceEnabled;
        private string inheritedFrom;

        public string Name { get { return System.IO.Path.GetFileName(fullName); } }
        public string FullName { get { return fullName; } set { fullName = value; } }
        public bool InheritanceEnabled { get { return inheritanceEnabled; } set { inheritanceEnabled = value; } }
        public string InheritedFrom { get { return inheritedFrom; } set { inheritedFrom = value; } }
        public AccessControlType AccessControlType { get { return fileSystemAccessRule.AccessControlType; } }
        public FileSystemRights2 AccessRights { get { return (FileSystemRights2)fileSystemAccessRule.FileSystemRights; } }
        public IdentityReference2 Account { get { return fileSystemAccessRule.IdentityReference; } }
        public InheritanceFlags InheritanceFlags { get { return fileSystemAccessRule.InheritanceFlags; } }
        public bool IsInherited { get { return fileSystemAccessRule.IsInherited; } }
        public PropagationFlags PropagationFlags { get { return fileSystemAccessRule.PropagationFlags; } }
        #endregion

        public FileSystemAccessRule2(FileSystemAccessRule fileSystemAccessRule)
        {
            this.fileSystemAccessRule = fileSystemAccessRule;
        }

        public FileSystemAccessRule2(FileSystemAccessRule fileSystemAccessRule, FileSystemInfo item)
        {
            this.fileSystemAccessRule = fileSystemAccessRule;
            this.fullName = item.FullName;
        }

        public FileSystemAccessRule2(FileSystemAccessRule fileSystemAccessRule, string path)
        {
            this.fileSystemAccessRule = fileSystemAccessRule;
        }

        public static implicit operator FileSystemAccessRule(FileSystemAccessRule2 ace2)
        {
            return ace2.fileSystemAccessRule;
        }
        public static implicit operator FileSystemAccessRule2(FileSystemAccessRule ace)
        {
            return new FileSystemAccessRule2(ace);
        }

        //REQUIRED BECAUSE OF CONVERSION OPERATORS
        public override bool Equals(object obj)
        {
            return fileSystemAccessRule == (FileSystemAccessRule)obj;
        }
        public override int GetHashCode()
        {
            return fileSystemAccessRule.GetHashCode();
        }
        public override string ToString()
        {
            return string.Format("{0} '{1}' ({2})",
                AccessControlType.ToString()[0],
                Account.AccountName,
                AccessRights.ToString()
            );

        }
        public SimpleFileSystemAccessRule ToSimpleFileSystemAccessRule2()
        {
            return new SimpleFileSystemAccessRule(fullName, Account, AccessRights, AccessControlType);
        }
    }
}