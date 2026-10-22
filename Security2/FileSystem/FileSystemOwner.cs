using Alphaleonis.Win32.Filesystem;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public class FileSystemOwner
    {
        private FileSystemInfo item;
        private IdentityReference2 owner;
        private FileSystemSecurity sd;

        public FileSystemInfo Item
        {
            get { return item; }
        }

        public IdentityReference2 Owner
        {
            get { return owner; }
        }

        public IdentityReference2 Account
        {
            get { return owner; }
        }

        public string FullName
        {
            // Null without an item, such as for a descriptor that a conversion from FileSecurity built directly,
            // instead of a NullReferenceException.
            get { return item != null ? item.FullName : null; }
        }

        private FileSystemOwner(FileSystemInfo item, IdentityReference2 owner)
        {
            this.item = item;
            this.owner = owner;
        }

        public static FileSystemOwner GetOwner(FileSystemSecurity2 sd)
        {
            return new FileSystemOwner(sd.Item, sd.SecurityDescriptor.GetOwner(typeof(SecurityIdentifier)));
        }

        public static void SetOwner(FileSystemSecurity2 sd, IdentityReference2 account)
        {
            sd.SecurityDescriptor.SetOwner(account);
        }

        public static FileSystemOwner GetOwner(FileSystemInfo item)
        {
            return GetOwner(new FileSystemSecurity2(item, AccessControlSections.Owner));
        }

        public static void SetOwner(FileSystemInfo item, IdentityReference2 account)
        {
            var sd = new FileSystemSecurity2(item, AccessControlSections.Owner);

            SetOwner(sd, account);

            sd.Write();
        }

        public override string ToString()
        {
            // Empty, not null, without an item: ToString must never return null, and there is no other
            // representation of this object to fall back to.
            return item != null ? item.FullName : string.Empty;
        }
    }
}
