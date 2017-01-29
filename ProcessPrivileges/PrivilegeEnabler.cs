// <copyright file="PrivilegeEnabler.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Security.Permissions;

    /// <summary>Enables privileges on a process in a safe way, ensuring that they are returned to their original state when an operation that requires a privilege completes.</summary>
    /// <example>
    ///     <code>
    /// using System;
    /// using System.Diagnostics;
    /// using ProcessPrivileges;
    /// 
    /// internal static class PrivilegeEnablerExample
    /// {
    ///     public static void Main()
    ///     {
    ///         Process process = Process.GetCurrentProcess();
    /// 
    ///         using (new PrivilegeEnabler(process, Privilege.TakeOwnership))
    ///         {
    ///             // Privilege is enabled within the using block.
    ///             Console.WriteLine(
    ///                 "{0} => {1}",
    ///                 Privilege.TakeOwnership,
    ///                 process.GetPrivilegeState(Privilege.TakeOwnership));
    ///         }
    /// 
    ///         // Privilege is disabled outside the using block.
    ///         Console.WriteLine(
    ///             "{0} => {1}",
    ///             Privilege.TakeOwnership,
    ///             process.GetPrivilegeState(Privilege.TakeOwnership));
    ///     }
    /// }
    ///     </code>
    /// </example>
    /// <remarks>
    ///     <para>When disabled, privileges are enabled until the instance of the PrivilegeEnabler class is disposed.</para>
    ///     <para>If the privilege specified is already enabled, it is not modified and will not be disabled when the instance of the PrivilegeEnabler class is disposed.</para>
    ///     <para>If desired, multiple privileges can be specified in the constructor.</para>
    ///     <para>If using multiple instances on the same process, do not dispose of them out-of-order. Making use of a using statement, the recommended method, enforces this.</para>
    ///     <para>For more information on privileges, see:</para>
    ///     <para><a href="http://msdn.microsoft.com/en-us/library/aa379306.aspx">Privileges</a></para>
    ///     <para><a href="http://msdn.microsoft.com/en-us/library/bb530716.aspx">Privilege Constants</a></para>
    /// </remarks>
    public sealed class PrivilegeEnabler : IDisposable
    {
        private static readonly Dictionary<Privilege, PrivilegeEnabler> sharedPrivileges =
            new Dictionary<Privilege, PrivilegeEnabler>();

        private static readonly Dictionary<Process, AccessTokenHandle> accessTokenHandles =
            new Dictionary<Process, AccessTokenHandle>();

        private AccessTokenHandle accessTokenHandle;

        private bool disposed;

        private bool ownsHandle;

        private Process process;

        /// <summary>Initializes a new instance of the PrivilegeEnabler class.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which privileges should be enabled.</param>
        /// <exception cref="InvalidOperationException">Thrown when another instance exists and has not been disposed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public PrivilegeEnabler(AccessTokenHandle accessTokenHandle)
        {
            this.accessTokenHandle = accessTokenHandle;
        }

        /// <summary>Initializes a new instance of the PrivilegeEnabler class.</summary>
        /// <param name="process">The <see cref="Process"/> on which privileges should be enabled.</param>
        /// <exception cref="InvalidOperationException">Thrown when another instance exists and has not been disposed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public PrivilegeEnabler(Process process)
        {
            lock (accessTokenHandles)
            {
                if (accessTokenHandles.ContainsKey(process))
                {
                    this.accessTokenHandle = accessTokenHandles[process];
                }
                else
                {
                    this.accessTokenHandle =
                        process.GetAccessTokenHandle(TokenAccessRights.AdjustPrivileges | TokenAccessRights.Query);
                    accessTokenHandles.Add(process, this.accessTokenHandle);
                    this.ownsHandle = true;
                }
            }

            this.process = process;
        }

        /// <summary>Initializes a new instance of the PrivilegeEnabler class with the specified privileges to be enabled.</summary>
        /// <param name="accessTokenHandle">The <see cref="AccessTokenHandle"/> for a <see cref="Process"/> on which privileges should be enabled.</param>
        /// <param name="privileges">The privileges to be enabled.</param>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public PrivilegeEnabler(AccessTokenHandle accessTokenHandle, params Privilege[] privileges)
            : this(accessTokenHandle)
        {
            foreach (Privilege privilege in privileges)
            {
                this.EnablePrivilege(privilege);
            }
        }

        /// <summary>Initializes a new instance of the PrivilegeEnabler class with the specified privileges to be enabled.</summary>
        /// <param name="process">The <see cref="Process"/> on which privileges should be enabled.</param>
        /// <param name="privileges">The privileges to be enabled.</param>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public PrivilegeEnabler(Process process, params Privilege[] privileges)
            : this(process)
        {
            foreach (Privilege privilege in privileges)
            {
                this.EnablePrivilege(privilege);
            }
        }

        /// <summary>Finalizes an instance of the PrivilegeEnabler class.</summary>
        ~PrivilegeEnabler()
        {
            this.InternalDispose();
        }

        /// <summary>Disposes of an instance of the PrivilegeEnabler class.</summary>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.Demand">Requires the call stack to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.Demand, Name = "FullTrust")]
        public void Dispose()
        {
            this.InternalDispose();
            GC.SuppressFinalize(this);
        }

        /// <summary>Enables the specified <see cref="Privilege"/>.</summary>
        /// <param name="privilege">The <see cref="Privilege"/> to be enabled.</param>
        /// <returns>
        ///     <para>Result from the privilege adjustment.</para>
        ///     <para>If the <see cref="Privilege"/> is already enabled, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        ///     <para>If the <see cref="Privilege"/> is owned by another instance of the PrivilegeEnabler class, <see cref="AdjustPrivilegeResult.None"/> is returned.</para>
        ///     <para>If a <see cref="Privilege"/> is removed from a process, it cannot be enabled.</para>
        /// </returns>
        /// <remarks>
        ///     <para>When disabled, privileges are enabled until the instance of the PrivilegeEnabler class is disposed.</para>
        ///     <para>If the privilege specified is already enabled, it is not modified and will not be disabled when the instance of the PrivilegeEnabler class is disposed.</para>
        /// </remarks>
        /// <exception cref="Win32Exception">Thrown when an underlying Win32 function call does not succeed.</exception>
        /// <permission cref="SecurityAction.LinkDemand">Requires the immediate caller to have FullTrust.</permission>
        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        public AdjustPrivilegeResult EnablePrivilege(Privilege privilege)
        {
            lock (sharedPrivileges)
            {
                if (!sharedPrivileges.ContainsKey(privilege) &&
                    this.accessTokenHandle.GetPrivilegeState(privilege) == PrivilegeState.Disabled &&
                    this.accessTokenHandle.EnablePrivilege(privilege) == AdjustPrivilegeResult.PrivilegeModified)
                {
                    sharedPrivileges.Add(privilege, this);
                    return AdjustPrivilegeResult.PrivilegeModified;
                }

                return AdjustPrivilegeResult.None;
            }
        }

        [PermissionSetAttribute(SecurityAction.LinkDemand, Name = "FullTrust")]
        private void InternalDispose()
        {
            if (!this.disposed)
            {
                lock (sharedPrivileges)
                {
                    Privilege[] privileges = sharedPrivileges
                        .Where(keyValuePair => keyValuePair.Value == this)
                        .Select(keyValuePair => keyValuePair.Key)
                        .ToArray();

                    foreach (Privilege privilege in privileges)
                    {
                        this.accessTokenHandle.DisablePrivilege(privilege);
                        sharedPrivileges.Remove(privilege);
                    }

                    if (this.ownsHandle)
                    {
                        this.accessTokenHandle.Dispose();
                        lock (this.accessTokenHandle)
                        {
                            accessTokenHandles.Remove(this.process);
                        }
                    }

                    this.accessTokenHandle = null;
                    this.ownsHandle = false;
                    this.process = null;

                    this.disposed = true;
                }
            }
        }
    }
}