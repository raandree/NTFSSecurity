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
            get { return item.FullName; }
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
            return item.FullName;
        }
    }
}
