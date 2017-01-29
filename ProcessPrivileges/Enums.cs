// <copyright file="Enums.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System.Diagnostics.CodeAnalysis;

    /// <summary>Result from a privilege adjustment.</summary>
    public enum AdjustPrivilegeResult
    {
        /// <summary>Privilege not modified.</summary>
        None,

        /// <summary>Privilege modified.</summary>
        PrivilegeModified
    }

    /// <summary>Privilege determining the type of system operations that can be performed.</summary>
    public enum Privilege
    {
        /// <summary>Privilege to replace a process-level token.</summary>
        AssignPrimaryToken,

        /// <summary>Privilege to generate security audits.</summary>
        Audit,

        /// <summary>Privilege to backup files and directories.</summary>
        Backup,

        /// <summary>Privilege to bypass traverse checking.</summary>
        ChangeNotify,

        /// <summary>Privilege to create global objects.</summary>
        CreateGlobal,

        /// <summary>Privilege to create a pagefile.</summary>
        CreatePageFile,

        /// <summary>Privilege to create permanent shared objects.</summary>
        CreatePermanent,

        /// <summary>Privilege to create symbolic links.</summary>
        CreateSymbolicLink,

        /// <summary>Privilege to create a token object.</summary>
        CreateToken,

        /// <summary>Privilege to debug programs.</summary>
        Debug,

        /// <summary>Privilege to enable computer and user accounts to be trusted for delegation.</summary>
        EnableDelegation,

        /// <summary>Privilege to impersonate a client after authentication.</summary>
        Impersonate,

        /// <summary>Privilege to increase scheduling priority.</summary>
        IncreaseBasePriority,

        /// <summary>Privilege to adjust memory quotas for a process.</summary>
        IncreaseQuota,

        /// <summary>Privilege to increase a process working set.</summary>
        IncreaseWorkingSet,

        /// <summary>Privilege to load and unload device drivers.</summary>
        LoadDriver,

        /// <summary>Privilege to lock pages in memory.</summary>
        LockMemory,

        /// <summary>Privilege to add workstations to domain.</summary>
        MachineAccount,

        /// <summary>Privilege to manage the files on a volume.</summary>
        ManageVolume,

        /// <summary>Privilege to profile single process.</summary>
        ProfileSingleProcess,

        /// <summary>Privilege to modify an object label.</summary>
        [SuppressMessage(
            "Microsoft.Naming",
            "CA1704:IdentifiersShouldBeSpelledCorrectly",
            Justification = "Spelling is correct.",
            MessageId = "Relabel")]
        Relabel,

        /// <summary>Privilege to force shutdown from a remote system.</summary>
        RemoteShutdown,

        /// <summary>Privilege to restore files and directories.</summary>
        Restore,

        /// <summary>Privilege to manage auditing and security log.</summary>
        Security,

        /// <summary>Privilege to shut down the system.</summary>
        Shutdown,

        /// <summary>Privilege to synchronize directory service data.</summary>
        SyncAgent,

        /// <summary>Privilege to modify firmware environment values.</summary>
        SystemEnvironment,

        /// <summary>Privilege to profile system performance.</summary>
        SystemProfile,

        /// <summary>Privilege to change the system time.</summary>
        SystemTime,

        /// <summary>Privilege to take ownership of files or other objects.</summary>
        TakeOwnership,

        /// <summary>Privilege to act as part of the operating system.</summary>
        TrustedComputerBase,

        /// <summary>Privilege to change the time zone.</summary>
        TimeZone,

        /// <summary>Privilege to access Credential Manager as a trusted caller.</summary>
        TrustedCredentialManagerAccess,

        /// <summary>Privilege to remove computer from docking station.</summary>
        Undock,

        /// <summary>Privilege to read unsolicited input from a terminal device.</summary>
        UnsolicitedInput
    }

    /// <summary>State of a <see cref="Privilege"/>, derived from <see cref="PrivilegeAttributes"/>.</summary>
    public enum PrivilegeState
    {
        /// <summary>
        /// Privilege is disabled.
        /// </summary>
        Disabled,

        /// <summary>
        /// Privilege is enabled.
        /// </summary>
        Enabled,

        /// <summary>
        /// Privilege is removed.
        /// </summary>
        Removed
    }
}