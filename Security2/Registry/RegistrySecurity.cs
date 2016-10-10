using System;
using System.Collections.Generic;
using System.Security.AccessControl;
using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace Security2
{
    //#region FileSecurity2
    //public class FileSecurity2 : ICast<FileSecurity>, IDisposable
    //{
    //    protected FileSecurity securityDescriptor;

    //    public string FullName { get; set; }

    //    public string Name { get { return System.IO.Path.GetFileName(FullName); } }

    //    public FileSecurity2() { }
    //    public FileSecurity2(FileSecurity SecurityDescriptor)
    //    {
    //        this.securityDescriptor = SecurityDescriptor;
    //    }

    //    #region conversion
    //    public static implicit operator FileSecurity(FileSecurity2 V)
    //    {
    //        return V.securityDescriptor;
    //    }
    //    public static implicit operator FileSecurity2(FileSecurity n)
    //    {
    //        return new FileSecurity2(n);
    //    }
    //    //REQUIRED BECAUSE OF CONVERSION OPERATORS
    //    public override bool Equals(object obj)
    //    {
    //        return this.securityDescriptor == (FileSecurity)obj;
    //    }
    //    public override int GetHashCode()
    //    {
    //        return this.securityDescriptor.GetHashCode();
    //    }
    //    #endregion

    //    #region ICast<FileSecurity> Members
    //    public FileSecurity Cast
    //    {
    //        get { return this.securityDescriptor; }
    //    }
    //    #endregion

    //    #region IDisposable Members
    //    public void Dispose()
    //    { }
    //    #endregion
    //}
    //#endregion

    //#region DirectorySecurity2
    //public class DirectorySecurity2 : ICast<DirectorySecurity>, IDisposable
    //{
    //    protected DirectorySecurity securityDescriptor;

    //    public string FullName { get; set; }

    //    public string Name { get { return System.IO.Path.GetFileName(FullName); } }

    //    public DirectorySecurity2() { }
    //    public DirectorySecurity2(DirectorySecurity SecurityDescriptor)
    //    {
    //        this.securityDescriptor = SecurityDescriptor;
    //    }

    //    #region conversion
    //    public static implicit operator DirectorySecurity(DirectorySecurity2 V)
    //    {
    //        return V.securityDescriptor;
    //    }
    //    public static implicit operator DirectorySecurity2(DirectorySecurity n)
    //    {
    //        return new DirectorySecurity2(n);
    //    }
    //    //REQUIRED BECAUSE OF CONVERSION OPERATORS
    //    public override bool Equals(object obj)
    //    {
    //        return this.securityDescriptor == (DirectorySecurity)obj;
    //    }
    //    public override int GetHashCode()
    //    {
    //        return this.securityDescriptor.GetHashCode();
    //    }
    //    #endregion

    //    #region ICast<DirectorySecurity> Members
    //    public DirectorySecurity Cast
    //    {
    //        get { return this.securityDescriptor; }
    //    }
    //    #endregion

    //    #region IDisposable Members
    //    public void Dispose()
    //    { }
    //    #endregion
    //}
    //#endregion

    #region RegistryAccessRule2
    public class RegistryAccessRule2 : IDisposable
    {
        protected RegistryAccessRule registryAccessRule;

        public string Name
        {
            get
            {
                if (!string.IsNullOrEmpty(FullName))
                {
                    if (FullName.Contains("\\"))
                    {
                        var elements = FullName.Split('\\');
                        return elements[elements.Length - 1];
                    }
                    else
                    {
                        return FullName;
                    }
                }
                else
                {
                    return null;
                }
            }
        }

        public string FullName { get; set; }

        public bool InheritanceEnabled { get; set; }

        public RegistryAccessRule2(RegistryAccessRule registryAccessRule)
        {
            this.registryAccessRule = registryAccessRule;
        }

        #region Properties
        public AccessControlType AccessControlType { get { return registryAccessRule.AccessControlType; } }
        public RegistryRights RegistryRights { get { return registryAccessRule.RegistryRights; } }
        public IdentityReference2 IdentityReference { get { return (IdentityReference2)registryAccessRule.IdentityReference; } }
        public InheritanceFlags InheritanceFlags { get { return registryAccessRule.InheritanceFlags; } }
        public bool IsInherited { get { return registryAccessRule.IsInherited; } }
        public PropagationFlags PropagationFlags { get { return registryAccessRule.PropagationFlags; } }
        #endregion

        #region conversion
        public static implicit operator RegistryAccessRule(RegistryAccessRule2 V)
        {
            return V.registryAccessRule;
        }
        public static implicit operator RegistryAccessRule2(RegistryAccessRule n)
        {
            return new RegistryAccessRule2(n);
        }
        //REQUIRED BECAUSE OF CONVERSION OPERATORS
        public override bool Equals(object obj)
        {
            return this.registryAccessRule == (RegistryAccessRule)obj;
        }
        public override int GetHashCode()
        {
            return this.registryAccessRule.GetHashCode();
        }
        public override string ToString()
        {
            return registryAccessRule.ToString();
        }
        #endregion

        #region IDisposable Members
        public void Dispose()
        { }
        #endregion
    }
    #endregion

    #region RegistryInheritanceInfo
    public class RegistryInheritanceInfo
    {
        public RegistryKey Item { get; set; }
        public bool InheritanceEnabled { get; set; }

        public string FullName { get { return Item.Name; } }
        public string Name
        {
            get
            {
                if (!string.IsNullOrEmpty(FullName))
                {
                    if (FullName.Contains("\\"))
                    {
                        var elements = FullName.Split('\\');
                        return elements[elements.Length - 1];
                    }
                    else
                    {
                        return FullName;
                    }
                }
                else
                {
                    return null;
                }
            }
        }
    }
    #endregion

    #region RegistryEffectivePermissionEntry
    public class RegistryEffectivePermissionEntry
    {
        private IdentityReference2 account;
        public IdentityReference2 Account { get { return account; } }

        private uint accessMask;
        public uint AccessMask { get { return accessMask; } }

        private string objectPath;
        public string FullName { get { return objectPath; } }
        public string Name { get
            {
                if (!string.IsNullOrEmpty(FullName))
                {
                    if (FullName.Contains("\\"))
                    {
                        var elements = FullName.Split('\\');
                        return elements[elements.Length - 1];
                    }
                    else
                    {
                        return FullName;
                    }
                }
                else
                {
                    return null;
                }
            }
        }

        private List<string> accessAsString;
        public List<string> AccessAsString { get { return accessAsString; } }

        public RegistryEffectivePermissionEntry(IdentityReference2 id, uint AccessMask, string FullName)
        {
            this.account = id;
            this.accessMask = AccessMask;
            this.objectPath = FullName;
            this.accessAsString = new List<string>();

            if (accessMask == 0)
            {
                accessAsString.Add("None");
            }
            else
            {
                string tempString = ((RegistryRights)this.accessMask).ToString();
                foreach (var s in tempString.Split(','))
                {
                    this.accessAsString.Add(s);
                }
            }
        }
    }
    #endregion

    #region RegistryOwner
    public class RegistryOwner
    {
        public RegistryKey Item { get; set; }
        public Security2.IdentityReference2 Account { get; set; }
    }
    #endregion

    #region Win32
    #region Win32Enums
    /// <summary>
    /// enum used by RegOpenKeyEx
    /// </summary>
    public enum SAM_DESIRED : long
    {
        KEY_QUERY_VALUE = 0x1,
        KEY_SET_VALUE = 0x2,
        KEY_ALL_ACCESS = 0xf003f,
        KEY_CREATE_SUB_KEY = 0x4,
        KEY_ENUMERATE_SUB_KEYS = 0x8,
        KEY_NOTIFY = 0x10,
        KEY_CREATE_LINK = 0x20,
        READ_CONTROL = 0x20000,
        WRITE_DAC = 0x40000,
        WRITE_OWNER = 0x80000,
        SYNCHRONIZE = 0x100000,

        STANDARD_RIGHTS_REQUIRED = 0xf0000,

        STANDARD_RIGHTS_READ = READ_CONTROL,
        STANDARD_RIGHTS_WRITE = READ_CONTROL,
        STANDARD_RIGHTS_EXECUTE = READ_CONTROL,

        KEY_READ = STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY,

        KEY_WRITE = STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY,

        KEY_EXECUTE = KEY_READ
    }

    /// <summary>
    /// constant enum for registry roots
    /// </summary>
    public enum REGISTRY_ROOT : long
    {
        HKEY_CLASSES_ROOT = 0x80000000,
        HKEY_CURRENT_USER = 0x80000001,
        HKEY_LOCAL_MACHINE = 0x80000002,
        HKEY_USERS = 0x80000003
    }
    #endregion

    public class RegistryKeyOpenException : System.Exception
    {
        private long win32ErrorCode;
        public long Win32ErrorCode { get { return win32ErrorCode; } }

        public RegistryKeyOpenException()
            : base("Cannot open Registry Key")
        { }

        public RegistryKeyOpenException(Exception innerException)
            : base("Cannot open Registry Key", innerException)
        { }

        public RegistryKeyOpenException(long Win32ErrorCode)
            : base("Cannot open Registry Key")
        {
            this.win32ErrorCode = Win32ErrorCode;
        }

        public RegistryKeyOpenException(Exception innerException, long Win32ErrorCode)
            : base("Cannot open Registry Key", innerException)
        {
            this.win32ErrorCode = Win32ErrorCode;
        }
    }

    public class RegistryKeySetSecurityException : System.Exception
    {
        private long win32ErrorCode;
        public long Win32ErrorCode { get { return win32ErrorCode; } }

        public RegistryKeySetSecurityException()
            : base("Cannot set security descriptor on registry key")
        { }

        public RegistryKeySetSecurityException(Exception innerException)
            : base("Cannot set security descriptor on registry key", innerException)
        { }

        public RegistryKeySetSecurityException(long Win32ErrorCode)
            : base("Cannot set security descriptor on registry key")
        {
            this.win32ErrorCode = Win32ErrorCode;
        }

        public RegistryKeySetSecurityException(Exception innerException, long Win32ErrorCode)
            : base("Cannot set security descriptor on registry key", innerException)
        {
            this.win32ErrorCode = Win32ErrorCode;
        }
    }

    public class Win32RegistrySecurity
    {

        #region DllImports
        [DllImport("kernel32.dll")]
        private static extern long CloseHandle(IntPtr hHandle);

        [DllImport("advapi32.dll")]
        private static extern long InitializeSecurityDescriptor(ref SECURITY_DESCRIPTOR pSecurityDescriptor, long dwRevision);

        [DllImport("advapi32.dll")]
        private static extern long SetSecurityDescriptorOwner(ref SECURITY_DESCRIPTOR pSecurityDescriptor, byte[] pOwner, long bOwnerDefaulted);

        [DllImport("advapi32.dll")]
        private static extern long RegSetKeySecurity(IntPtr ptrKey, SECURITY_INFORMATION SecurityInformation, SECURITY_DESCRIPTOR pSecurityDescriptor);

        [DllImport("advapi32.dll", EntryPoint = "RegOpenKeyExA")]
        private static extern long RegOpenKeyEx(REGISTRY_ROOT hKey, string lpSubKey, long ulOptions, SAM_DESIRED samDesired, ref IntPtr ptrKey);

        [DllImport("advapi32.dll")]
        private static extern long RegCloseKey(IntPtr ptrKey);

        private struct SECURITY_DESCRIPTOR
        {
            public byte Revision;
            public byte Sbz1;
            public long Control;
            public long Owner;
            public long Group;
            public ACL Sacl;
            public ACL Dacl;
        }

        private struct ACL
        {
            public byte AclRevision;
            public byte Sbz1;
            public int AclSize;
            public int AceCount;
            public int Sbz2;
        }
        #endregion

        private RegistryKey GetRegistryKey(REGISTRY_ROOT Root, string KeyPath, RegistryRights Desired)
        {
            try
            {
                switch (Root)
                {
                    case REGISTRY_ROOT.HKEY_CLASSES_ROOT:
                        return Registry.ClassesRoot.OpenSubKey(KeyPath, RegistryKeyPermissionCheck.ReadWriteSubTree, Desired);
                    case REGISTRY_ROOT.HKEY_LOCAL_MACHINE:
                        return Registry.LocalMachine.OpenSubKey(KeyPath, RegistryKeyPermissionCheck.ReadWriteSubTree, Desired);
                    case REGISTRY_ROOT.HKEY_USERS:
                        return Registry.Users.OpenSubKey(KeyPath, RegistryKeyPermissionCheck.ReadWriteSubTree, Desired);
                    case REGISTRY_ROOT.HKEY_CURRENT_USER:
                        return Registry.CurrentUser.OpenSubKey(KeyPath, RegistryKeyPermissionCheck.ReadWriteSubTree, Desired);
                    default:
                        return null;
                }
            }
            catch (Exception)
            {
                return null;
            }
        }

        public void SetRegistryOwner(REGISTRY_ROOT Root, string KeyPath, SecurityIdentifier sid)
        {
            long win32ErrorCode = 0;

            SECURITY_DESCRIPTOR sd = new SECURITY_DESCRIPTOR();
            byte[] byteSid = new byte[sid.BinaryLength];
            sid.GetBinaryForm(byteSid, 0);

            IntPtr pRegKey = IntPtr.Zero;

            try
            {
                win32ErrorCode = RegOpenKeyEx(Root, KeyPath, 0, SAM_DESIRED.WRITE_OWNER, ref pRegKey);
                if (win32ErrorCode != 0)
                {
                    throw new RegistryKeyOpenException(win32ErrorCode);
                }
            }
            catch (RegistryKeyOpenException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new RegistryKeyOpenException(ex);
            }

            InitializeSecurityDescriptor(ref sd, 1);            
            SetSecurityDescriptorOwner(ref sd, byteSid, 0);

            try
            {
                win32ErrorCode = RegSetKeySecurity(pRegKey, SECURITY_INFORMATION.OWNER_SECURITY_INFORMATION, sd);
                if (win32ErrorCode != 0)
                {
                    throw new RegistryKeySetSecurityException(win32ErrorCode);
                }
            }
            catch (RegistryKeySetSecurityException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new RegistryKeyOpenException(ex);
            }
            finally
            {
                RegCloseKey(pRegKey);
            }
        }
    }
#endregion
}