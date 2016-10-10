using Microsoft.Win32.SafeHandles;
using System;
using System.Runtime.InteropServices;

namespace Security2
{
    internal partial class Win32
    {
        const string ADVAPI32_DLL = "advapi32.dll";
        internal const string KERNEL32_DLL = "kernel32.dll";
        internal const string AUTHZ_DLL = "authz.dll";

        [DllImport(ADVAPI32_DLL, EntryPoint = "GetInheritanceSourceW", CharSet = CharSet.Unicode)]
        static extern UInt32 GetInheritanceSource(
                [MarshalAs(UnmanagedType.LPTStr)] string pObjectName,
                System.Security.AccessControl.ResourceType ObjectType,
                SECURITY_INFORMATION SecurityInfo,
                [MarshalAs(UnmanagedType.Bool)]bool Container,
                IntPtr pObjectClassGuids,
                UInt32 GuidCount,
                byte[] pAcl,
                IntPtr pfnArray,
                ref GENERIC_MAPPING pGenericMapping,
                IntPtr pInheritArray
        );

        [DllImport(ADVAPI32_DLL, EntryPoint = "FreeInheritedFromArray", CharSet = CharSet.Unicode)]
        static extern UInt32 FreeInheritedFromArray(
           IntPtr pInheritArray,
           UInt16 AceCnt,
           IntPtr pfnArray
       );

        [DllImport(AUTHZ_DLL, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool AuthzInitializeRemoteResourceManager(
            IntPtr rpcInitInfo,
            out SafeAuthzRMHandle authRM);

        [DllImport(AUTHZ_DLL, CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool AuthzInitializeResourceManager(
            AuthzResourceManagerFlags flags,
            IntPtr pfnAccessCheck,
            IntPtr pfnComputeDynamicGroups,
            IntPtr pfnFreeDynamicGroups,
            string szResourceManagerName,
            out SafeAuthzRMHandle phAuthzResourceManager);

        [DllImport(Win32.AUTHZ_DLL, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AuthzInitializeContextFromSid(
            AuthzInitFlags flags,
            byte[] rawUserSid,
            SafeAuthzRMHandle authzRM,
            IntPtr expirationTime,
            Win32.LUID Identifier,
            IntPtr DynamicGroupArgs,
            out IntPtr authzClientContext);

        [DllImport(Win32.AUTHZ_DLL, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AuthzAccessCheck(
            AuthzACFlags flags,
            IntPtr hAuthzClientContext,
            ref AUTHZ_ACCESS_REQUEST pRequest,
            IntPtr AuditEvent,
            byte[] rawSecurityDescriptor,
            IntPtr[] OptionalSecurityDescriptorArray,
            UInt32 OptionalSecurityDescriptorCount,
            ref AUTHZ_ACCESS_REPLY pReply,
            IntPtr cachedResults);

        [DllImport(Win32.AUTHZ_DLL, CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AuthzFreeContext(IntPtr authzClientContext);

        [DllImport(Win32.ADVAPI32_DLL, CallingConvention = CallingConvention.Winapi, CharSet = CharSet.Unicode)]
        public static extern UInt32 GetSecurityDescriptorLength(IntPtr pSecurityDescriptor);


        [DllImport(Win32.ADVAPI32_DLL, CallingConvention = CallingConvention.Winapi, SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern UInt32 GetSecurityInfo(
            SafeFileHandle handle,
            ObjectType objectType,
            SecurityInformationClass infoClass,
            IntPtr owner,
            IntPtr group,
            IntPtr dacl,
            IntPtr sacl,
            out IntPtr securityDescriptor);

        [DllImport(Win32.KERNEL32_DLL, SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern SafeFileHandle CreateFile(
            string lpFileName,
            FileAccess desiredAccess,
            FileShare shareMode,
            IntPtr lpSecurityAttributes,
            FileMode mode,
            FileFlagAttrib flagsAndAttributes,
            IntPtr hTemplateFile);
    }
}