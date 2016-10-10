using Alphaleonis.Win32.Filesystem;
using System.Security.AccessControl;

namespace Security2
{
    public partial class FileSystemAuditRule2
    {
        #region Properties
        private FileSystemAuditRule fileSystemAuditRule;
        private string fullName;
        private bool inheritanceEnabled;
        private string inheritedFrom;

        public string Name { get { return System.IO.Path.GetFileName(fullName); } }
        public string FullName { get { return fullName; } set { fullName = value; } }
        public bool InheritanceEnabled { get { return inheritanceEnabled; } set { inheritanceEnabled = value; } }
        public string InheritedFrom { get { return inheritedFrom; } set { inheritedFrom = value; } }
        public AuditFlags AuditFlags { get { return fileSystemAuditRule.AuditFlags; } }
        public FileSystemRights2 AccessRights { get { return (FileSystemRights2)fileSystemAuditRule.FileSystemRights; } }
        public IdentityReference2 Account { get { return (IdentityReference2)fileSystemAuditRule.IdentityReference; } }
        public InheritanceFlags InheritanceFlags { get { return fileSystemAuditRule.InheritanceFlags; } }
        public bool IsInherited { get { return fileSystemAuditRule.IsInherited; } }
        public PropagationFlags PropagationFlags { get { return fileSystemAuditRule.PropagationFlags; } }
        #endregion

        public FileSystemAuditRule2(FileSystemAuditRule fileSystemAuditRule)
        {
            this.fileSystemAuditRule = fileSystemAuditRule;
        }

        public FileSystemAuditRule2(FileSystemAuditRule fileSystemAuditRule, FileSystemInfo item)
        {
            this.fileSystemAuditRule = fileSystemAuditRule;
            this.fullName = item.FullName;
        }

        public FileSystemAuditRule2(FileSystemAuditRule fileSystemAuditRule, string path)
        {
            this.fileSystemAuditRule = fileSystemAuditRule;
        }

        #region Conversion
        public static implicit operator FileSystemAuditRule(FileSystemAuditRule2 ace2)
        {
            return ace2.fileSystemAuditRule;
        }
        public static implicit operator FileSystemAuditRule2(FileSystemAuditRule ace)
        {
            return new FileSystemAuditRule2(ace);
        }
        //REQUIRED BECAUSE OF CONVERSION OPERATORS
        public override bool Equals(object obj)
        {
            return this.fileSystemAuditRule == (FileSystemAuditRule)obj;
        }
        public override int GetHashCode()
        {
            return this.fileSystemAuditRule.GetHashCode();
        }
        public override string ToString()
        {
            return fileSystemAuditRule.ToString();
        }
        public SimpleFileSystemAuditRule ToSimpleFileSystemAuditRule2()
        {
            return new SimpleFileSystemAuditRule(this.fullName, this.Account, this.AccessRights);
        }
        #endregion
    }
}
