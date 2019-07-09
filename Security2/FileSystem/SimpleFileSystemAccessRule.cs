using System.Security.AccessControl;

namespace Security2
{
    public class SimpleFileSystemAccessRule
    {
        private string fullName;
        private IdentityReference2 identity;
        private FileSystemRights2 accessRights;
        private AccessControlType type;

        public AccessControlType AccessControlType
        {
            get { return type; }
            set { type = value; }
        }

        public string FullName
        {
            get { return fullName; }
        }

        public string Name
        {
            get
            {
                return System.IO.Path.GetFileName(fullName);
            }
        }

        public IdentityReference2 Identity
        {
            get { return identity; }
        }

        public SimpleFileSystemAccessRights AccessRights
        {
            get
            {
                SimpleFileSystemAccessRights result = SimpleFileSystemAccessRights.None;

                if ((accessRights & FileSystemRights2.Read) == FileSystemRights2.Read)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.CreateFiles) == FileSystemRights2.CreateFiles)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.AppendData) == FileSystemRights2.AppendData)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.ReadExtendedAttributes) == FileSystemRights2.ReadExtendedAttributes)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.WriteExtendedAttributes) == FileSystemRights2.WriteExtendedAttributes)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.ExecuteFile) == FileSystemRights2.ExecuteFile)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.DeleteSubdirectoriesAndFiles) == FileSystemRights2.DeleteSubdirectoriesAndFiles)
                { result |= SimpleFileSystemAccessRights.Delete; }

                if ((accessRights & FileSystemRights2.ReadAttributes) == FileSystemRights2.ReadAttributes)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.WriteAttributes) == FileSystemRights2.WriteAttributes)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.Delete) == FileSystemRights2.Delete)
                { result |= SimpleFileSystemAccessRights.Delete; }

                if ((accessRights & FileSystemRights2.ReadPermissions) == FileSystemRights2.ReadPermissions)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.ChangePermissions) == FileSystemRights2.ChangePermissions)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.TakeOwnership) == FileSystemRights2.TakeOwnership)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.Synchronize) == FileSystemRights2.Synchronize)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.FullControl) == FileSystemRights2.FullControl)
                { result = (SimpleFileSystemAccessRights.Write | SimpleFileSystemAccessRights.Read | SimpleFileSystemAccessRights.Delete); }

                if ((accessRights & FileSystemRights2.GenericRead) == FileSystemRights2.GenericRead)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.GenericWrite) == FileSystemRights2.GenericWrite)
                { result |= SimpleFileSystemAccessRights.Write; }

                if ((accessRights & FileSystemRights2.GenericExecute) == FileSystemRights2.GenericExecute)
                { result |= SimpleFileSystemAccessRights.Read; }

                if ((accessRights & FileSystemRights2.GenericAll) == FileSystemRights2.GenericAll)
                { result = (SimpleFileSystemAccessRights.Write | SimpleFileSystemAccessRights.Read | SimpleFileSystemAccessRights.Delete); }

                return result;
            }
        }

        public SimpleFileSystemAccessRule(string path, IdentityReference2 account, FileSystemRights2 access, AccessControlType accessControlType)
        {
            fullName = path;
            accessRights = access;
            identity = account;
            type = accessControlType;
        }

        public override bool Equals(object obj)
        {
            var compareObject = obj as SimpleFileSystemAccessRule;

            if (compareObject == null)
            {
                return false;
            }

            if (this.AccessRights == compareObject.AccessRights && this.Identity == compareObject.Identity && this.AccessControlType == compareObject.AccessControlType)
            {
                return true;
            }
            else
            {
                return false;
            }
        }

        public override int GetHashCode()
        {
            return this.Identity.GetHashCode() | this.AccessRights.GetHashCode() | this.AccessControlType.GetHashCode();
        }
    }
}
