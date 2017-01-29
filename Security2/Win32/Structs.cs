using System;
using System.Runtime.InteropServices;

namespace Security2
{
    internal partial class Win32
    {
        [StructLayout(LayoutKind.Sequential)]
        struct PINHERITED_FROM
        {
            public Int32 GenerationGap;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string AncestorName;
        }        

        [StructLayout(LayoutKind.Sequential)]
        struct GENERIC_MAPPING
        {
            public uint GenericRead;
            public uint GenericWrite;
            public uint GenericExecute;
            public uint GenericAll;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct AUTHZ_RPC_INIT_INFO_CLIENT
        {
            public AuthzRpcClientVersion version;
            public string objectUuid;
            public string protocol;
            public string server;
            public string endPoint;
            public string options;
            public string serverSpn;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct LUID
        {
            public uint LowPart;
            public uint HighPart;

            public static LUID NullLuid
            {
                get
                {
                    LUID Empty;
                    Empty.LowPart = 0;
                    Empty.HighPart = 0;

                    return Empty;
                }
            }
        }

        #region authz
        [StructLayout(LayoutKind.Sequential)]
        internal struct AUTHZ_ACCESS_REQUEST
        {
            public StdAccess DesiredAccess;
            public byte[] PrincipalSelfSid;
            public IntPtr ObjectTypeList;
            public int ObjectTypeListLength;
            public IntPtr OptionalArguments;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct AUTHZ_ACCESS_REPLY
        {
            public int ResultListLength;
            public IntPtr GrantedAccessMask;
            public IntPtr SaclEvaluationResults;
            public IntPtr Error;
        }

        internal enum AuthzACFlags : uint // DWORD
        {
            None = 0,
            NoDeepCopySD
        }
        #endregion
    }
}