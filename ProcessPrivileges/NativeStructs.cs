// <copyright file="NativeStructs.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System.Runtime.InteropServices;

    [StructLayout(LayoutKind.Sequential)]
    internal struct Luid
    {
        internal int LowPart;

        internal int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct LuidAndAttributes
    {
        internal Luid Luid;

        internal PrivilegeAttributes Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct TokenPrivilege
    {
        internal int PrivilegeCount;

        internal LuidAndAttributes Privilege;
    }
}