using System;
using System.Runtime.InteropServices;

namespace Security2
{
    internal partial class Win32
    {
        const string ADVAPI32_DLL = "advapi32.dll";
        const string KERNEL32_DLL = "kernel32.dll";

        [DllImport(Win32.ADVAPI32_DLL, EntryPoint = "GetInheritanceSourceW", CharSet = CharSet.Unicode)]
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

        [DllImport(Win32.ADVAPI32_DLL, EntryPoint = "FreeInheritedFromArray", CharSet = CharSet.Unicode)]
        static extern UInt32 FreeInheritedFromArray(
           IntPtr pInheritArray,
           UInt16 AceCnt,
           IntPtr pfnArray
       );
    }
}