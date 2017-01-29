// <copyright file="ProcessHandle.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;
    using System.ComponentModel;
    using System.Runtime.ConstrainedExecution;
    using System.Runtime.InteropServices;
    using Microsoft.Win32.SafeHandles;

    internal sealed class ProcessHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        internal ProcessHandle(IntPtr processHandle, bool ownsHandle)
            : base(ownsHandle)
        {
            handle = processHandle;
        }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            if (!NativeMethods.CloseHandle(handle))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            return true;
        }
    }
}