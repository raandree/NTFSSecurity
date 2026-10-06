using Alphaleonis.Win32.Filesystem;
using System;
using System.Collections.Generic;
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

        // The SDDL form of each section as it was read or last written, so that WriteChanges writes only the
        // sections that changed since.
        private Dictionary<AccessControlSections, string> sectionsAsRead;

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
            this.item = item;
            isFile = item is FileInfo;

            sd = GetSecurity(item, sections);

            RememberSections();
        }

        public FileSystemSecurity2(FileSystemInfo item)
        {
            this.item = item;
            isFile = item is FileInfo;

            try
            {
                sd = GetSecurity(item, AccessControlSections.All);
                sections = AccessControlSections.All;
            }
            catch
            {
                try
                {
                    sd = GetSecurity(item, AccessControlSections.Access | AccessControlSections.Owner | AccessControlSections.Group);
                    sections = AccessControlSections.Access | AccessControlSections.Owner | AccessControlSections.Group;
                }
                catch
                {
                    sd = GetSecurity(item, AccessControlSections.Access);
                    sections = AccessControlSections.Access;
                }
            }

            // Read together with the SACL, the inherited entries of a DACL without the auto-inherit flag lose their
            // inherited flag when the parent folder has no SACL, and writing such a DACL back stores them as explicit
            // entries. Read alone, the DACL keeps the flags.
            if (HasAuditSection)
            {
                var accessSecurity = GetSecurity(item, AccessControlSections.Access);
                sd.SetSecurityDescriptorBinaryForm(accessSecurity.GetSecurityDescriptorBinaryForm(), AccessControlSections.Access);
            }

            RememberSections();
        }

        // For the root of a drive, the methods of DirectoryInfo read and write the security descriptor of the volume,
        // a device object, instead of that of its root folder (#41). The methods that take the path keep the trailing
        // backslash and reach the root folder.
        internal static FileSystemSecurity GetSecurity(FileSystemInfo item, AccessControlSections sections)
        {
            var file = item as FileInfo;
            if (file != null)
            {
                return file.GetAccessControl(sections);
            }

            string root;
            if (TryGetDriveRoot(item, out root))
            {
                return Directory.GetAccessControl(root, sections);
            }

            return ((DirectoryInfo)item).GetAccessControl(sections);
        }

        internal static void SetSecurity(FileSystemInfo item, FileSystemSecurity security, AccessControlSections sections)
        {
            var file = item as FileInfo;
            if (file != null)
            {
                file.SetAccessControl((FileSecurity)security, sections);
                return;
            }

            string root;
            if (TryGetDriveRoot(item, out root))
            {
                Directory.SetAccessControl(root, (DirectorySecurity)security, sections);
                return;
            }

            ((DirectoryInfo)item).SetAccessControl((DirectorySecurity)security, sections);
        }

        private static bool TryGetDriveRoot(FileSystemInfo item, out string root)
        {
            var fullName = item.FullName.TrimEnd('\\');
            if (fullName.Length == 2 && fullName[1] == ':' && char.IsLetter(fullName[0]))
            {
                root = fullName + "\\";
                return true;
            }

            root = null;
            return false;
        }

        // Without the Security privilege, the security descriptor is read without its SACL.
        internal bool HasAuditSection
        {
            get { return (sections & AccessControlSections.Audit) == AccessControlSections.Audit; }
        }

        // An item without audit entries can have no SACL at all, also when the SACL was read.
        internal bool HasSystemAcl
        {
            get { return new RawSecurityDescriptor(sd.GetSecurityDescriptorBinaryForm(), 0).SystemAcl != null; }
        }

        // The sections that differ from the ones that were read or last written.
        internal AccessControlSections ChangedSections
        {
            get
            {
                var changed = AccessControlSections.None;
                foreach (var section in sectionsAsRead)
                {
                    if (sd.GetSecurityDescriptorSddlForm(section.Key) != section.Value)
                    {
                        changed |= section.Key;
                    }
                }

                return changed;
            }
        }

        private void RememberSections()
        {
            sectionsAsRead = new Dictionary<AccessControlSections, string>();
            foreach (var section in new[] { AccessControlSections.Access, AccessControlSections.Audit, AccessControlSections.Owner, AccessControlSections.Group })
            {
                sectionsAsRead[section] = sd.GetSecurityDescriptorSddlForm(section);
            }
        }

        public FileSystemSecurity SecurityDescriptor
        {
            get
            {
                return sd;
            }
        }

        // Writes the sections that the descriptor was read with. Windows can return the owner and the group with a DACL
        // that is read alone, and writing them back fails for an owner that the user cannot assign (#34).
        public void Write()
        {
            SetSecurity(item, sd, sections);

            RememberSections();
        }

        // Writes only the sections that changed since they were read or last written, so that, for example, an
        // unchanged owner that the user cannot assign isn't written back (#34). Without a change, it writes nothing.
        internal void WriteChanges()
        {
            var changedSections = ChangedSections;
            if (changedSections == AccessControlSections.None)
            {
                return;
            }

            SetSecurity(item, sd, changedSections);

            RememberSections();
        }

        // Writes the sections that the descriptor was read with to another item, like Write().
        public void Write(FileSystemInfo item)
        {
            SetSecurity(item, sd, sections);
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
