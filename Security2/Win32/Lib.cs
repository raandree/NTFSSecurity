using Alphaleonis.Win32.Filesystem;
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;

namespace Security2
{
    internal partial class Win32
    {
        internal const string AUTHZ_OBJECTUUID_WITHCAP = "9a81c2bd-a525-471d-a4ed-49907c0b23da";
        internal const string RCP_OVER_TCP_PROTOCOL = "ncacn_ip_tcp";

        IntPtr userClientCtxt = IntPtr.Zero;
        SafeAuthzRMHandle authzRM;
        IntPtr pGrantedAccess = IntPtr.Zero;
        IntPtr pErrorSecObj = IntPtr.Zero;

        #region GetInheritedFrom
        public static List<string> GetInheritedFrom(FileSystemInfo item, ObjectSecurity sd)
        {
            var inheritedFrom = new List<string>();

            var sdBytes = sd.GetSecurityDescriptorBinaryForm();
            byte[] aclBytes = null;
            var rawSd = new RawSecurityDescriptor(sdBytes, 0);

            var aceCount = 0;

            if (rawSd.SystemAcl != null)
            {
                aceCount = rawSd.SystemAcl.Count;
                aclBytes = new byte[rawSd.SystemAcl.BinaryLength];
                rawSd.SystemAcl.GetBinaryForm(aclBytes, 0);

                try
                {
                    inheritedFrom = GetInheritedFrom(item.FullName,
                    aclBytes,
                    aceCount,
                    item is DirectoryInfo ? true : false,
                    SECURITY_INFORMATION.SACL_SECURITY_INFORMATION);
                }
                catch
                {
                    inheritedFrom = new List<string>();
                    for (int i = 0; i < aceCount; i++)
                    {
                        inheritedFrom.Add("unknown parent");
                    }
                }
            }
            else if (rawSd.DiscretionaryAcl != null)
            {
                aceCount = rawSd.DiscretionaryAcl.Count;
                aclBytes = new byte[rawSd.DiscretionaryAcl.BinaryLength];
                rawSd.DiscretionaryAcl.GetBinaryForm(aclBytes, 0);

                try
                {
                    inheritedFrom = GetInheritedFrom(item.FullName,
                        aclBytes,
                        aceCount,
                        item is DirectoryInfo ? true : false,
                        SECURITY_INFORMATION.DACL_SECURITY_INFORMATION);
                }
                catch
                {
                    inheritedFrom = new List<string>();
                    for (int i = 0; i < aceCount; i++)
                    {
                        inheritedFrom.Add("unknown parent");
                    }
                }
            }

            return inheritedFrom;
        }
        public static List<string> GetInheritedFrom(string path, byte[] aclBytes, int aceCount, bool isContainer, SECURITY_INFORMATION aclType)
        {
            var inheritedFrom = new List<string>();
            path = Path.GetLongPath(path);

            uint returnValue = 0;
            GENERIC_MAPPING genericMap = new GENERIC_MAPPING();
            genericMap.GenericRead = (uint)MappedGenericRights.FILE_GENERIC_READ;
            genericMap.GenericWrite = (uint)MappedGenericRights.FILE_GENERIC_WRITE;
            genericMap.GenericExecute = (uint)MappedGenericRights.FILE_GENERIC_EXECUTE;
            genericMap.GenericAll = (uint)MappedGenericRights.FILE_GENERIC_ALL;

            var pInheritInfo = Marshal.AllocHGlobal(aceCount * Marshal.SizeOf(typeof(PINHERITED_FROM)));

            returnValue = GetInheritanceSource(
                path,
                ResourceType.FileObject,
                aclType,
                isContainer,
                IntPtr.Zero,
                0,
                aclBytes,
                IntPtr.Zero,
                ref genericMap,
                pInheritInfo
                );

            if (returnValue != 0)
            {
                throw new System.ComponentModel.Win32Exception((int)returnValue);
            }

            for (int i = 0; i < aceCount; i++)
            {
                var inheritInfo = pInheritInfo.ElementAt<PINHERITED_FROM>(i);

                inheritedFrom.Add(
                    !string.IsNullOrEmpty(inheritInfo.AncestorName) && inheritInfo.AncestorName.StartsWith(@"\\?\") ? inheritInfo.AncestorName.Substring(4) : inheritInfo.AncestorName
                );
            }

            FreeInheritedFromArray(pInheritInfo, (ushort)aceCount, IntPtr.Zero);
            Marshal.FreeHGlobal(pInheritInfo);

            return inheritedFrom;
        }
        #endregion GetInheritedFrom

        public int GetEffectiveAccess(ObjectSecurity sd, IdentityReference2 identity, string serverName, out bool remoteServerAvailable, out Exception authzException)
        {
            int effectiveAccess = 0;
            remoteServerAvailable = false;
            authzException = null;

            try
            {
                GetEffectivePermissions_AuthzInitializeResourceManager(serverName, out remoteServerAvailable);

                try
                {
                    GetEffectivePermissions_AuthzInitializeContextFromSid(identity);
                    effectiveAccess = GetEffectivePermissions_AuthzAccessCheck(sd);
                }
                catch (Exception ex)
                {
                    authzException = ex;
                }
            }
            catch
            { }
            finally
            {
                GetEffectivePermissions_FreeResouces();
            }

            return effectiveAccess;
        }

        #region Win32 Wrapper
        private void GetEffectivePermissions_AuthzInitializeResourceManager(string serverName, out bool remoteServerAvailable)
        {
            remoteServerAvailable = false;

            var rpcInitInfo = new AUTHZ_RPC_INIT_INFO_CLIENT();

            rpcInitInfo.version = AuthzRpcClientVersion.V1;
            rpcInitInfo.objectUuid = AUTHZ_OBJECTUUID_WITHCAP;
            rpcInitInfo.protocol = RCP_OVER_TCP_PROTOCOL;
            rpcInitInfo.server = serverName;

            SafeHGlobalHandle pRpcInitInfo = SafeHGlobalHandle.AllocHGlobalStruct(rpcInitInfo);
            if (!AuthzInitializeRemoteResourceManager(pRpcInitInfo.ToIntPtr(), out authzRM))
            {
                int error = Marshal.GetLastWin32Error();

                if (error != Win32Error.EPT_S_NOT_REGISTERED) //if not RPC server unavailable
                {
                    throw new Win32Exception(error);
                }

                if (serverName == "localhost")
                {
                    remoteServerAvailable = true;
                }

                //
                // As a fallback we do AuthzInitializeResourceManager. But the results can be inaccurate.
                //
                if (!AuthzInitializeResourceManager(
                                AuthzResourceManagerFlags.NO_AUDIT,
                                IntPtr.Zero,
                                IntPtr.Zero,
                                IntPtr.Zero,
                                "EffectiveAccessCheck",
                                out authzRM))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
            }
            else
            {
                remoteServerAvailable = true;
            }
        }

        private void GetEffectivePermissions_AuthzInitializeContextFromSid(IdentityReference2 id)
        {
            var rawSid = id.GetBinaryForm();

            //
            // Create an AuthZ context based on the user account
            //
            if (!AuthzInitializeContextFromSid(
                AuthzInitFlags.Default,
                rawSid,
                authzRM,
                IntPtr.Zero,
                Win32.LUID.NullLuid,
                IntPtr.Zero,
                out userClientCtxt))
            {
                Win32Exception win32Expn = new Win32Exception(Marshal.GetLastWin32Error());

                if (win32Expn.NativeErrorCode != Win32Error.RPC_S_SERVER_UNAVAILABLE)
                {
                    throw win32Expn;
                }
            }
        }

        private int GetEffectivePermissions_AuthzAccessCheck(ObjectSecurity sd)
        {
            var request = new AUTHZ_ACCESS_REQUEST();
            request.DesiredAccess = StdAccess.MAXIMUM_ALLOWED;
            request.PrincipalSelfSid = null;
            request.ObjectTypeList = IntPtr.Zero;
            request.ObjectTypeListLength = 0;
            request.OptionalArguments = IntPtr.Zero;

            var reply = new AUTHZ_ACCESS_REPLY();
            reply.ResultListLength = 1;
            reply.SaclEvaluationResults = IntPtr.Zero;
            reply.GrantedAccessMask = pGrantedAccess = Marshal.AllocHGlobal(sizeof(uint));
            reply.Error = pErrorSecObj = Marshal.AllocHGlobal(sizeof(uint));

            byte[] rawSD = sd.GetSecurityDescriptorBinaryForm();

            if (!AuthzAccessCheck(
                AuthzACFlags.None,
                userClientCtxt,
                ref request,
                IntPtr.Zero,
                rawSD,
                null,
                0,
                ref reply,
                IntPtr.Zero))
            {
                var error = Marshal.GetLastWin32Error();
                if (error != 0)
                {
                    throw new Win32Exception();
                }
            }

            var grantedAccess = Marshal.ReadInt32(pGrantedAccess);

            return grantedAccess;
        }

        private void GetEffectivePermissions_FreeResouces()
        {
            Marshal.FreeHGlobal(pGrantedAccess);
            Marshal.FreeHGlobal(pErrorSecObj);

            if (userClientCtxt != IntPtr.Zero)
            {
                AuthzFreeContext(userClientCtxt);
                userClientCtxt = IntPtr.Zero;
            }
        }

        static RawSecurityDescriptor GetRawSecurityDescriptor(SafeFileHandle handle, SecurityInformationClass infoClass)
        {
            return new RawSecurityDescriptor(GetByteSecurityDescriptor(handle, infoClass), 0);
        }

        public static byte[] GetByteSecurityDescriptor(SafeFileHandle handle, SecurityInformationClass infoClass)
        {
            var tempSD = IntPtr.Zero;
            var buffer = new byte[0];
            try
            {
                uint error = GetSecurityInfo(handle,
                                                    ObjectType.File,
                                                    infoClass,
                                                    IntPtr.Zero,
                                                    IntPtr.Zero,
                                                    IntPtr.Zero,
                                                    IntPtr.Zero,
                                                    out tempSD);
                if (error != Win32Error.ERROR_SUCCESS)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                UInt32 sdLength = GetSecurityDescriptorLength(tempSD);

                buffer = new byte[sdLength];
                Marshal.Copy(tempSD, buffer, 0, (int)sdLength);
            }
            finally
            {
                Marshal.FreeHGlobal(tempSD);
                tempSD = IntPtr.Zero;
            }

            return buffer;
        }
        #endregion
    }
}