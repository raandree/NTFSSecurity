// <copyright file="ProcessExtensions.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System.Diagnostics;
    using System.Runtime.CompilerServices;
    using System.Security.Permissions;

    /// <summary>Provides extension methods to the <see cref="Process" /> class, implementing the functionality necessary to query, enable, disable or remove privileges on a process.</summary>
    /// <example>
    ///     <code>
    /// using System;
    /// using System.Diagnostics;
    /// using System.Linq;
    /// using ProcessPrivileges;
    /// 
    /// internal static class ProcessPrivilegesExample
    /// {
    ///     public static void Main()
    ///     {
    ///         // Get the current process.
    ///         Process process = Process.GetCurrentProcess();
    /// 
    ///         // Get the privileges and associated attributes.
    ///         PrivilegeAndAttributesCollection privileges = process.GetPrivileges();
    /// 
    ///         int maxPrivilegeLength = privileges.Max(privilege =&gt; privilege.Privilege.ToString().Length);
    /// 
    ///         foreach (PrivilegeAndAttributes privilegeAndAttributes in privileges)
    ///         {
    ///             // The privilege.
    ///             Privilege privilege = privilegeAndAttributes.Privilege;
    /// 
    ///             // The privilege state.
    ///             PrivilegeState privilegeState = privilegeAndAttributes.PrivilegeState;
    /// 
    ///             // Write out the privilege and its state.
    ///             Console.WriteLine(
    ///                 "{0}{1} =&gt; {2}",
    ///                 privilege,
    ///                 GetPadding(privilege.ToString().Length, maxPrivilegeLength),
    ///                 privilegeState);
    ///         }
    /// 
    ///         Console.WriteLine();
    /// 
    ///         // Privileges can only be enabled on a process if they are disabled.
    ///         if (process.GetPrivilegeState(Privilege.TakeOwnership) == PrivilegeState.Disabled)
    ///         {
    ///             // Enable the TakeOwnership privilege on it.
    ///             AdjustPrivilegeResult result = process.EnablePrivilege(Privilege.TakeOwnership);
    /// 
    ///             // Get the state of the TakeOwnership privilege.
    ///             PrivilegeState takeOwnershipState = process.GetPrivilegeState(Privilege.TakeOwnership);
    /// 
    ///             // Write out the TakeOwnership privilege, its state and the result.
    ///             Console.WriteLine(
    ///                 "{0}{1} =&gt; {2} ({3})",
    ///                 Privilege.TakeOwnership,
    ///                 GetPadding(Privilege.TakeOwnership.ToString().Length, maxPrivilegeLength),
    ///                 takeOwnershipState,
    ///                 result);
    ///         }
    ///     }
    /// 
    ///     private static string GetPadding(int length, int maxLength)
    ///     {
    ///         int paddingLength = maxLength - length;
    ///         char[] padding = new char[paddingLength];
    ///         for (int i = 0; i &lt; paddingLength; i++)
    ///         {
    ///             padding[i] = ' ';
    ///         }
    /// 
    ///         return new string(padding);
    ///     }
    /// }
    ///     </code>
    ///     <code>
    /// using System;
    /// using System.Diagnostics;
    /// using ProcessPrivileges;
    /// 
    /// internal static class ReusingAccessTokenHandleExample
    /// {
    ///     public static void Main()
    ///     {
    ///         // Access token handle reused within the using block.
    ///         using (AccessTokenHandle accessTokenHandle =
    ///             Process.GetCurrentProcess().GetAccessTokenHandle(
    ///                 TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query))
    ///         {
    ///             // Enable privileges using the same access token handle.
    ///             AdjustPrivilegeResult backupResult = accessTokenHandle.EnablePrivilege(Privilege.Backup);
    ///             AdjustPrivilegeResult restoreResult = accessTokenHandle.EnablePrivilege(Privilege.Restore);
    /// 
    ///             Console.WriteLine(
    ///                 "{0} => {1} ({2})",
    ///                 Privilege.Backup,
    ///                 accessTokenHandle.GetPrivilegeState(Privilege.Backup),
    ///                 backupResult);
    /// 
    ///             Console.WriteLine(
    ///                 "{0} => {1} ({2})",
    ///                 Privilege.Restore,
    ///                 accessTokenHandle.GetPrivilegeState(Privilege.Restore),
    ///                 restoreResult);
    ///         }
    ///     }
    /// }
    ///     </code>
    /// </example>
    /// <remarks>
    ///     <para>For more information on privileges, see:</para>
    ///     <para><a href="http://msdn.microsoft.com/en-us/library/aa379306.aspx">Privileges</a></para>
    ///     <para><a href="http://msdn.microsoft.com/en-us/library/bb530716.aspx">Privilege Constants</a></para>
    /// </remarks>
    public static class ProcessExtensions
    {
        /// <summary>Disables the specified <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be disabled.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>If the <see cref="Privilege"/> is already disabled, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>The caller must have permission to query and adjust token privileges on the target process.</remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult DisablePrivilege(this AccessTokenHandle accessTokenHandle, Privilege privilege)
        {
            return Privileges.DisablePrivilege(accessTokenHandle, privilege);
        }

        /// <summary>Disables the specified <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be disabled.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>If the <see cref="Privilege"/> is already disabled, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>If you are adjusting multiple privileges on a process, consider using <see cref="DisablePrivilege(AccessTokenHandle, Privilege)"/> with an access token handle for the process.</para>
        ///     <para>The caller must have permission to query and adjust token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult DisablePrivilege(this Process process, Privilege privilege)
        {
            using (AccessTokenHandle accessTokenHandle = new AccessTokenHandle(
                new ProcessHandle(process.Handle, false),
                TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query))
            {
                return DisablePrivilege(accessTokenHandle, privilege);
            }
        }

        /// <summary>Enables the specified <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be enabled.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>If the <see cref="Privilege"/> is already enabled, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Enabling a privilege allows a process to perform system-level actions that it could not previously.</para>
        ///     <para>Before enabling a privilege, many potentially dangerous, thoroughly verify that functions or operations in your code actually require them.</para>
        ///     <para>It is not normally appropriate to hold privileges for the lifetime of a process. Use sparingly; enable when needed, disable when not.</para>
        ///     <para>Consider using <see cref="PrivilegeEnabler"/> that enables privileges on a process in a safe way, ensuring that they are returned to their original state when an operation that requires a privilege completes.</para>
        ///     <para>The caller must have permission to query and adjust token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult EnablePrivilege(this AccessTokenHandle accessTokenHandle, Privilege privilege)
        {
            return Privileges.EnablePrivilege(accessTokenHandle, privilege);
        }

        /// <summary>Enables the specified <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be enabled.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>If the <see cref="Privilege"/> is already enabled, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        ///     <para>If a <see cref="Privilege"/> is removed from a process, it cannot be enabled.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Enabling a privilege allows a process to perform system-level actions that it could not previously.</para>
        ///     <para>Before enabling a privilege, many potentially dangerous, thoroughly verify that functions or operations in your code actually require them.</para>
        ///     <para>It is not normally appropriate to hold privileges for the lifetime of a process. Use sparingly; enable when needed, disable when not.</para>
        ///     <para>Consider using <see cref="PrivilegeEnabler"/> that enables privileges on a process in a safe way, ensuring that they are returned to their original state when an operation that requires a privilege completes.</para>
        ///     <para>If you are adjusting multiple privileges on a process, consider using <see cref="EnablePrivilege(AccessTokenHandle, Privilege)"/> with an access token handle for the process.</para>
        ///     <para>The caller must have permission to query and adjust token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult EnablePrivilege(this Process process, Privilege privilege)
        {
            using (AccessTokenHandle accessTokenHandle = new AccessTokenHandle(
                new ProcessHandle(process.Handle, false),
                TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query))
            {
                return EnablePrivilege(accessTokenHandle, privilege);
            }
        }

        /// <summary>Gets an access token handle for a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which an access token handle should be retrieved.</param>
        /// <returns>An access token handle for a <see cref="Process"/> with <see cref="TokenAccessRights.AllAccess"/> access rights.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>The caller must have permission to acquire an access token handle with all access rights.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AccessTokenHandle GetAccessTokenHandle(this Process process)
        {
            return GetAccessTokenHandle(process, TokenAccessRights.AllAccess);
        }

        /// <summary>Gets an access token handle for a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which an access token handle should be retrieved.</param>
        /// <param name="tokenAccessRights">The desired access rights for the access token handle.</param>
        /// <returns>An access token handle for a <see cref="Process"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>The caller must have permission to acquire an access token handle with the desired access rights.</para>
        ///     <para>To query permissions, the access token handle must have permission to query and adjust token privileges:</para>
        ///     <c>TokenAccessRights.Query</c>
        ///     <para>To enable, disable or remove a permission, the access token handle must have permission to query and adjust token privileges:</para>
        ///     <c>TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query</c>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AccessTokenHandle GetAccessTokenHandle(this Process process, TokenAccessRights tokenAccessRights)
        {
            return new AccessTokenHandle(new ProcessHandle(process.Handle, false), tokenAccessRights);
        }

        /// <summary>Gets the attributes for a <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> on which the attributes should be retrieved.</param>
        /// <returns>The <see cref="PrivilegeAttributes"/> for a <see cref="Privilege"/> on a <see cref="Process"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Consider using <see cref="GetPrivilegeState(AccessTokenHandle, Privilege)"/> as it avoids the need to work with a flags based enumerated type.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeAttributes GetPrivilegeAttributes(this AccessTokenHandle accessTokenHandle, Privilege privilege)
        {
            return Privileges.GetPrivilegeAttributes(privilege, GetPrivileges(accessTokenHandle));
        }

        /// <summary>Gets the attributes for a <see cref="Privilege"/> on a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> on which the attributes should be retrieved.</param>
        /// <returns>The <see cref="PrivilegeAttributes"/> for a <see cref="Privilege"/> on a <see cref="Process"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Consider using <see cref="GetPrivilegeState(Process, Privilege)"/> as it avoids the need to work with a flags based enumerated type.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeAttributes GetPrivilegeAttributes(this Process process, Privilege privilege)
        {
            return Privileges.GetPrivilegeAttributes(privilege, GetPrivileges(process));
        }

        /// <summary>Gets the privileges and associated attributes from a <see cref="Process"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <returns>The privileges associated with a process.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Consider using <see cref="GetPrivilegeState(PrivilegeAttributes)"/> on attributes within the collection as it avoids the need to work with a flags based enumerated type.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeAndAttributesCollection GetPrivileges(this AccessTokenHandle accessTokenHandle)
        {
            return Privileges.GetPrivileges(accessTokenHandle);
        }

        /// <summary>Gets the privileges and associated attributes from a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <returns>The privileges associated with a process.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Consider using <see cref="GetPrivilegeState(PrivilegeAttributes)"/> method on attributes within the collection as it avoids the need to work with a flags based enumerated type.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeAndAttributesCollection GetPrivileges(this Process process)
        {
            using (AccessTokenHandle accessTokenHandle = new AccessTokenHandle(
                new ProcessHandle(process.Handle, false),
                TokenAccessRights.Query))
            {
                return Privileges.GetPrivileges(accessTokenHandle);
            }
        }

        /// <summary>Gets the state of a <see cref="Privilege"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> that should be checked.</param>
        /// <returns>The <see cref="PrivilegeState"/> of the <see cref="Privilege"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Derives <see cref="GetPrivilegeAttributes(AccessTokenHandle, Privilege)"/> to establish the <see cref="PrivilegeState"/> of a <see cref="Privilege"/>.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeState GetPrivilegeState(this AccessTokenHandle accessTokenHandle, Privilege privilege)
        {
            return GetPrivilegeState(GetPrivilegeAttributes(accessTokenHandle, privilege));
        }

        /// <summary>Gets the state of a <see cref="Privilege"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> that should be checked.</param>
        /// <returns>The <see cref="PrivilegeState"/> of the <see cref="Privilege"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>Derives <see cref="GetPrivilegeAttributes(AccessTokenHandle, Privilege)"/> to establish the <see cref="PrivilegeState"/> of a <see cref="Privilege"/>.</para>
        ///     <para>The caller must have permission to query token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static PrivilegeState GetPrivilegeState(this Process process, Privilege privilege)
        {
            return GetPrivilegeState(GetPrivilegeAttributes(process, privilege));
        }

        /// <summary>Gets the state of a <see cref="Privilege"/>.</summary>
        /// <param name="privilegeAttributes">The privilege attributes.</param>
        /// <returns>The <see cref="PrivilegeState"/> of the <see cref="Privilege"/>.</returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <remarks>Derives <see cref="PrivilegeAttributes"/> to establish the <see cref="PrivilegeState"/> of a <see cref="Privilege"/>.</remarks>
        [MethodImpl(MethodImplOptions.Synchronized)]
        public static PrivilegeState GetPrivilegeState(PrivilegeAttributes privilegeAttributes)
        {
            if ((privilegeAttributes & PrivilegeAttributes.Enabled) == PrivilegeAttributes.Enabled)
            {
                return PrivilegeState.Enabled;
            }

            if ((privilegeAttributes & PrivilegeAttributes.Removed) == PrivilegeAttributes.Removed)
            {
                return PrivilegeState.Removed;
            }

            return PrivilegeState.Disabled;
        }

        /// <summary>Removes the specified <see cref="Privilege"/> from a <see cref="Process"/>.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be removed.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>Once a privilege has been removed from a process, it cannot be restored afterwards.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>The caller must have permission to query and adjust token privileges on the target process.</remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult RemovePrivilege(this AccessTokenHandle accessTokenHandle, Privilege privilege)
        {
            return Privileges.RemovePrivilege(accessTokenHandle, privilege);
        }

        /// <summary>Removes the specified <see cref="Privilege"/> from a <see cref="Process"/>.</summary>
        /// <param name="process">The <see cref="Process"/> on which the operation should be performed.</param>
        /// <param name="privilege">The <see cref="Privilege"/> to be removed.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>Once a privilege has been removed from a process, it cannot be restored afterwards.</para>
        /// </returns>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        /// <remarks>
        ///     <para>If you are adjusting multiple privileges on a process, consider using <see cref="RemovePrivilege(AccessTokenHandle, Privilege)"/> with an access token handle for the process.</para>
        ///     <para>The caller must have permission to query and adjust token privileges on the target process.</para>
        /// </remarks>
        [MethodImpl(MethodImplOptions.Synchronized),
        PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public static AdjustPrivilegeResult RemovePrivilege(this Process process, Privilege privilege)
        {
            using (AccessTokenHandle accessTokenHandle = new AccessTokenHandle(
                new ProcessHandle(process.Handle, false),
                TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query))
            {
                return RemovePrivilege(accessTokenHandle, privilege);
            }
        }
    }
}