using Alphaleonis.Win32.Filesystem;
using System;
using System.Security.AccessControl;

namespace Security2
{
    public class FileSystemSecurity2
    {
        protected FileSecurity fileSecurityDescriptor;
        protected DirectorySecurity directorySecurityDescriptor;
        protected FileSystemInfo item;
        protected FileSystemSecurity sd;
        protected AccessControlSections sections;
        protected bool isFile = false;

        public FileSystemInfo Item
        {
            get { return item; }
            set { item = value; }
        }

        public string FullName { get { return item.FullName; } }

        public string Name { get { return item.Name; } }

        public bool IsFile { get { return isFile; } }

        public FileSystemSecurity2(FileSystemInfo item, AccessControlSections sections)
        {
            this.sections = sections;

            if (item is FileInfo)
            {
                this.item = (FileInfo)item;

                sd = ((FileInfo)this.item).GetAccessControl(sections);

                isFile = true;
            }
            else
            {
                this.item = (DirectoryInfo)item;

                sd = ((DirectoryInfo)this.item).GetAccessControl(sections);
            }
        }

        public FileSystemSecurity2(FileSystemInfo item)
        {
            if (item is FileInfo)
            {
                this.item = (FileInfo)item;
                try
                {
                    sd = ((FileInfo)this.item).GetAccessControl(AccessControlSections.All);
                }
                catch
                {
                    try
                    {
                        sd = ((FileInfo)this.item).GetAccessControl(AccessControlSections.Access | AccessControlSections.Owner | AccessControlSections.Group);
                    }
                    catch
                    {
                        sd = ((FileInfo)this.item).GetAccessControl(AccessControlSections.Access);
                    }
                }

                isFile = true;
            }
            else
            {
                this.item = (DirectoryInfo)item;
                try
                {
                    sd = ((DirectoryInfo)this.item).GetAccessControl(AccessControlSections.All);
                }
                catch
                {
                    try
                    {
                        sd = ((DirectoryInfo)this.item).GetAccessControl(AccessControlSections.Access | AccessControlSections.Owner | AccessControlSections.Group);
                    }
                    catch
                    {
                        sd = ((DirectoryInfo)this.item).GetAccessControl(AccessControlSections.Access);
                    }
                }
            }
        }

        public FileSystemSecurity SecurityDescriptor
        {
            get
            {
                return sd;
            }
        }

        public void Write()
        {
            if (isFile)
            {
                ((FileInfo)item).SetAccessControl((FileSecurity)sd);
            }
            else
            {
                ((DirectoryInfo)item).SetAccessControl((DirectorySecurity)sd);
            }
        }

        public void Write(FileSystemInfo item)
        {
            if (item is FileInfo)
            {
                ((FileInfo)item).SetAccessControl((FileSecurity)sd);
            }
            else
            {
                ((DirectoryInfo)item).SetAccessControl((DirectorySecurity)sd);
            }
        }

        public void Write(string path)
        {
            FileSystemInfo item = null;

            if (File.Exists(path))
            {
                item = new FileInfo(path);
            }
            else if (Directory.Exists(path))
            {
                item = new DirectoryInfo(path);
            }
            else
            {
                throw new System.IO.FileNotFoundException("File not found", path);
            }

            Write(item);
        }

        #region Conversion
        public static implicit operator FileSecurity(FileSystemSecurity2 fs2)
        {
            return fs2.fileSecurityDescriptor;
        }
        public static implicit operator FileSystemSecurity2(FileSecurity fs)
        {
            return new FileSystemSecurity2(new FileInfo(""));
        }

        public static implicit operator DirectorySecurity(FileSystemSecurity2 fs2)
        {
            return fs2.directorySecurityDescriptor;
        }
        public static implicit operator FileSystemSecurity2(DirectorySecurity fs)
        {
            return new FileSystemSecurity2(new DirectoryInfo(""));
        }

        //REQUIRED BECAUSE OF CONVERSION OPERATORS
        public override bool Equals(object obj)
        {
            return this.fileSecurityDescriptor == (FileSecurity)obj;
        }
        public override int GetHashCode()
        {
            return fileSecurityDescriptor.GetHashCode();
        }
        #endregion

        public static void ConvertToFileSystemFlags(ApplyTo ApplyTo, out InheritanceFlags inheritanceFlags, out PropagationFlags propagationFlags)
        {
            inheritanceFlags = InheritanceFlags.None;
            propagationFlags = PropagationFlags.None;

            switch (ApplyTo)
            {
                case ApplyTo.FilesOnly:
                    inheritanceFlags = InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.InheritOnly;
                    break;
                case ApplyTo.SubfoldersAndFilesOnly:
                    inheritanceFlags = InheritanceFlags.ObjectInherit | InheritanceFlags.ContainerInherit;
                    propagationFlags = PropagationFlags.InheritOnly;
                    break;
                case ApplyTo.SubfoldersOnly:
                    inheritanceFlags = InheritanceFlags.ContainerInherit;
                    propagationFlags = PropagationFlags.InheritOnly;
                    break;
                case ApplyTo.ThisFolderAndFiles:
                    inheritanceFlags = InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.None;
                    break;
                case ApplyTo.ThisFolderAndSubfolders:
                    inheritanceFlags = InheritanceFlags.ContainerInherit;
                    propagationFlags = PropagationFlags.None;
                    break;
                case ApplyTo.ThisFolderOnly:
                    inheritanceFlags = InheritanceFlags.None;
                    propagationFlags = PropagationFlags.None;
                    break;
                case ApplyTo.ThisFolderSubfoldersAndFiles:
                    inheritanceFlags = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.None;
                    break;
                case ApplyTo.FilesOnlyOneLevel:
                    inheritanceFlags = InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit;
                    break;
                case ApplyTo.SubfoldersAndFilesOnlyOneLevel:
                    inheritanceFlags = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit;
                    break;
                case ApplyTo.SubfoldersOnlyOneLevel:
                    inheritanceFlags = InheritanceFlags.ContainerInherit;
                    propagationFlags = PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit;
                    break;
                case ApplyTo.ThisFolderAndFilesOneLevel:
                    inheritanceFlags = InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.NoPropagateInherit;
                    break;
                case ApplyTo.ThisFolderAndSubfoldersOneLevel:
                    inheritanceFlags = InheritanceFlags.ContainerInherit;
                    propagationFlags = PropagationFlags.NoPropagateInherit;
                    break;
                case ApplyTo.ThisFolderSubfoldersAndFilesOneLevel:
                    inheritanceFlags = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
                    propagationFlags = PropagationFlags.NoPropagateInherit;
                    break;
            }
        }

        public static ApplyTo ConvertToApplyTo(InheritanceFlags InheritanceFlags, PropagationFlags PropagationFlags)
        {
            if (InheritanceFlags == InheritanceFlags.ObjectInherit & PropagationFlags == PropagationFlags.InheritOnly)
                return ApplyTo.FilesOnly;
            else if (InheritanceFlags == (InheritanceFlags.ObjectInherit | InheritanceFlags.ContainerInherit) & PropagationFlags == PropagationFlags.InheritOnly)
                return ApplyTo.SubfoldersAndFilesOnly;
            else if (InheritanceFlags == InheritanceFlags.ContainerInherit & PropagationFlags == PropagationFlags.InheritOnly)
                return ApplyTo.SubfoldersOnly;
            else if (InheritanceFlags == InheritanceFlags.ObjectInherit & PropagationFlags == PropagationFlags.None)
                return ApplyTo.ThisFolderAndFiles;
            else if (InheritanceFlags == InheritanceFlags.ContainerInherit & PropagationFlags == PropagationFlags.None)
                return ApplyTo.ThisFolderAndSubfolders;
            else if (InheritanceFlags == InheritanceFlags.None & PropagationFlags == PropagationFlags.None)
                return ApplyTo.ThisFolderOnly;
            else if (InheritanceFlags == (InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit) & PropagationFlags == PropagationFlags.None)
                return ApplyTo.ThisFolderSubfoldersAndFiles;
            else if (InheritanceFlags == (InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit) & PropagationFlags == PropagationFlags.NoPropagateInherit)
                return ApplyTo.ThisFolderSubfoldersAndFilesOneLevel;
            else if (InheritanceFlags == InheritanceFlags.ContainerInherit & PropagationFlags == PropagationFlags.NoPropagateInherit)
                return ApplyTo.ThisFolderAndSubfoldersOneLevel;
            else if (InheritanceFlags == InheritanceFlags.ObjectInherit & PropagationFlags == PropagationFlags.NoPropagateInherit)
                return ApplyTo.ThisFolderAndFilesOneLevel;
            else if (InheritanceFlags == (InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit) & PropagationFlags == (PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit))
                return ApplyTo.SubfoldersAndFilesOnlyOneLevel;
            else if (InheritanceFlags == InheritanceFlags.ContainerInherit & PropagationFlags == (PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit))
                return ApplyTo.SubfoldersOnlyOneLevel;
            else if (InheritanceFlags == InheritanceFlags.ObjectInherit & PropagationFlags == (PropagationFlags.InheritOnly | PropagationFlags.NoPropagateInherit))
                return ApplyTo.FilesOnlyOneLevel;

            throw new RightsConverionException("The combination of InheritanceFlags and PropagationFlags could not be translated");
        }

        public static FileSystemRights MapGenericRightsToFileSystemRights(uint originalRights)
        {
            try
            {
                var r = Enum.Parse(typeof(FileSystemRights), (originalRights).ToString());
                if (r.ToString() == originalRights.ToString())
                {
                    throw new ArgumentOutOfRangeException();
                }

                var fileSystemRights = (FileSystemRights)originalRights;
                return fileSystemRights;
            }
            catch (Exception)
            {
                FileSystemRights rights = 0;
                if (Convert.ToBoolean(originalRights & (uint)GenericRights.GENERIC_EXECUTE))
                {
                    rights |= (FileSystemRights)MappedGenericRights.FILE_GENERIC_EXECUTE;
                    originalRights ^= (uint)GenericRights.GENERIC_EXECUTE;
                }
                if (Convert.ToBoolean(originalRights & (uint)GenericRights.GENERIC_READ))
                {
                    rights |= (FileSystemRights)MappedGenericRights.FILE_GENERIC_READ;
                    originalRights ^= (uint)GenericRights.GENERIC_READ;
                }
                if (Convert.ToBoolean(originalRights & (uint)GenericRights.GENERIC_WRITE))
                {
                    rights |= (FileSystemRights)MappedGenericRights.FILE_GENERIC_WRITE;
                    originalRights ^= (uint)GenericRights.GENERIC_WRITE;
                }
                if (Convert.ToBoolean(originalRights & (uint)GenericRights.GENERIC_ALL))
                {
                    rights |= (FileSystemRights)MappedGenericRights.FILE_GENERIC_ALL;
                    originalRights ^= (uint)GenericRights.GENERIC_ALL;
                }
                //throw new RightsConverionException("Cannot convert GenericRights into FileSystemRights");

                var remainingRights = (FileSystemRights)Enum.Parse(typeof(FileSystemRights), (originalRights).ToString());

                rights |= remainingRights;

                return rights;
            }
        }
    }
}
