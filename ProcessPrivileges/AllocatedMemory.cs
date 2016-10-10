// <copyright file="AllocatedMemory.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;
    using System.Diagnostics.CodeAnalysis;
    using System.Runtime.InteropServices;

    internal sealed class AllocatedMemory : IDisposable
    {
        [SuppressMessage("Microsoft.Reliability",
            "CA2006:UseSafeHandleToEncapsulateNativeResources",
            Justification = "Not pointing to a native resource.")]
        private IntPtr pointer;

        internal AllocatedMemory(int bytesRequired)
        {
            this.pointer = Marshal.AllocHGlobal(bytesRequired);
        }

        ~AllocatedMemory()
        {
            this.InternalDispose();
        }

        internal IntPtr Pointer
        {
            get
            {
                return this.pointer;
            }
        }

        public void Dispose()
        {
            this.InternalDispose();
            GC.SuppressFinalize(this);
        }

        private void InternalDispose()
        {
            if (this.pointer != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(this.pointer);
                this.pointer = IntPtr.Zero;
            }
        }
    }
}