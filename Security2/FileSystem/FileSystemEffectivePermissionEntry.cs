using System.Collections.Generic;
using System.Security.AccessControl;

namespace Security2
{
    public class FileSystemEffectivePermissionEntry
    {
        private IdentityReference2 account;
        private uint accessMask;
        private string objectPath;

        public IdentityReference2 Account { get { return account; } }

        public uint AccessMask { get { return accessMask; } }

        public string FullName { get { return objectPath; } }

        public string Name
        {
            get
            {
                if (!string.IsNullOrEmpty(FullName))
                {
                    return System.IO.Path.GetFileName(FullName);
                }
                else
                {
                    return null;
                }
            }
        }

        public FileSystemRights AccessRights
        {
            get
            {
                return (FileSystemRights)accessMask;
            }
        }

        private List<string> accessAsString;
        public List<string> AccessAsString { get { return accessAsString; } }

        public FileSystemEffectivePermissionEntry(IdentityReference2 identity, uint AccessMask, string FullName)
        {
            this.account = identity;
            this.accessMask = AccessMask;
            this.objectPath = FullName;
            this.accessAsString = new List<string>();

            if (accessMask == 0)
            {
                accessAsString.Add("None");
            }
            else
            {
                string tempString = ((FileSystemRights)this.accessMask).ToString();
                foreach (var s in tempString.Split(','))
                {
                    this.accessAsString.Add(s);
                }
            }
        }
    }
}
