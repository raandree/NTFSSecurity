// <copyright file="NativeMethods.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;
    using System.Runtime.ConstrainedExecution;
    using System.Runtime.InteropServices;
    using System.Security;
    using System.Text;

    /// <summary>Static class containing Win32 native methods.</summary>
    internal static class NativeMethods
    {
        internal const int ErrorInsufficientBuffer = 122;

        private const string AdvApi32 = "advapi32.dll";

        private const string Kernel32 = "kernel32.dll";

        [DllImport(AdvApi32, SetLastError = true),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AdjustTokenPrivileges(
            [In] AccessTokenHandle accessTokenHandle, 
            [In, MarshalAs(UnmanagedType.Bool)] bool disableAllPrivileges,
            [In] ref TokenPrivilege newState,
            [In] int bufferLength,
            [In, Out] ref TokenPrivilege previousState,
            [In, Out] ref int returnLength);

        [DllImport(Kernel32, SetLastError = true),
        ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseHandle(
            [In] IntPtr handle);

        [DllImport(AdvApi32, CharSet = CharSet.Unicode, SetLastError = true),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool LookupPrivilegeName(
           [In] string systemName,
           [In] ref Luid luid,
           [In, Out] StringBuilder name,
           [In, Out] ref int nameLength);

        [DllImport(AdvApi32, CharSet = CharSet.Unicode, SetLastError = true),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool LookupPrivilegeValue(
            [In] string systemName,
            [In] string name,
            [In, Out] ref Luid luid);

        [DllImport(AdvApi32, SetLastError = true),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetTokenInformation(
            [In] AccessTokenHandle accessTokenHandle,
            [In] TokenInformationClass tokenInformationClass,
            [Out] IntPtr tokenInformation,
            [In] int tokenInformationLength,
            [In, Out] ref int returnLength);

        [DllImport(AdvApi32, SetLastError = true),
        SuppressUnmanagedCodeSecurity]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool OpenProcessToken(
            [In] ProcessHandle processHandle,
            [In] TokenAccessRights desiredAccess,
            [In, Out] ref IntPtr tokenHandle);
    }
}