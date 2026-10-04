using Alphaleonis.Win32.Filesystem;
using System;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Security2
{
    public class EffectiveAccess
    {
        public static EffectiveAccessInfo GetEffectiveAccess(FileSystemInfo item, IdentityReference2 id, string serverName)
        {
            return GetEffectiveAccess(new FileSystemSecurity2(item), id, serverName);
        }

        public static EffectiveAccessInfo GetEffectiveAccess(FileSystemSecurity2 sd, IdentityReference2 id, string serverName)
        {
            bool remoteServerAvailable = false;
            Exception authzAccessCheckException = null;

            var win32 = new Win32();

            var effectiveAccessMask = win32.GetEffectiveAccess(sd.SecurityDescriptor, id, serverName, out remoteServerAvailable, out authzAccessCheckException);

            var ace = new FileSystemAccessRule((SecurityIdentifier)id, (FileSystemRights)effectiveAccessMask, AccessControlType.Allow);

            return new EffectiveAccessInfo(
                new FileSystemAccessRule2(ace, sd.Item),
                remoteServerAvailable,
                authzAccessCheckException);
        }
    }

    public class EffectiveAccessInfo
    {
        private FileSystemAccessRule2 ace;
        private bool fromRemote;
        private Exception authzException;

        public FileSystemAccessRule2 Ace
        {
            get { return ace; }
        }

        public bool FromRemote
        {
            get { return fromRemote; }
        }

        public Exception AuthzException
        {
            get { return authzException; }
        }

        public bool OperationFailed
        {
            get
            {
                return authzException == null ? false : true;
            }
        }

        public EffectiveAccessInfo(FileSystemAccessRule2 ace, bool fromRemote, Exception authzException = null)
        {
            this.ace = ace;
            this.fromRemote = fromRemote;
            this.authzException = authzException;
        }
    }
}