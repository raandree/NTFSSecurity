// <copyright file="NativeEnums.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;
    using System.Diagnostics.CodeAnalysis;

    /// <summary>
    ///     <para>Privilege attributes that augment a <see cref="Privilege"/> with state information.</para>
    /// </summary>
    /// <remarks>
    ///     <para>Use the following checks to interpret privilege attributes:</para>
    ///     <para>
    ///         <c>// Privilege is disabled.<br/>if (attributes == PrivilegeAttributes.Disabled) { /* ... */ }</c>
    ///     </para>
    ///     <para>
    ///         <c>// Privilege is enabled.<br/>if ((attributes &amp; PrivilegeAttributes.Enabled) == PrivilegeAttributes.Enabled) { /* ... */ }</c>
    ///     </para>
    ///     <para>
    ///         <c>// Privilege is removed.<br/>if ((attributes &amp; PrivilegeAttributes.Removed) == PrivilegeAttributes.Removed) { /* ... */ }</c>
    ///     </para>
    ///     <para>To avoid having to work with a flags based enumerated type, use <see cref="ProcessExtensions.GetPrivilegeState(PrivilegeAttributes)"/> on attributes.</para>
    /// </remarks>
    [Flags,
    SuppressMessage(
        "Microsoft.Design",
        "CA1008:EnumsShouldHaveZeroValue",
        Justification = "Native enum."),
    SuppressMessage(
        "Microsoft.Usage",
        "CA2217:DoNotMarkEnumsWithFlags",
        Justification = "Native enum.")]
    public enum PrivilegeAttributes
    {
        /// <summary>Privilege is disabled.</summary>
        Disabled = 0,

        /// <summary>Privilege is enabled by default.</summary>
        EnabledByDefault = 1,

        /// <summary>Privilege is enabled.</summary>
        Enabled = 2,

        /// <summary>Privilege is removed.</summary>
        Removed = 4,

        /// <summary>Privilege used to gain access to an object or service.</summary>
        UsedForAccess = -2147483648
    }

    /// <summary>Access rights for access tokens.</summary>
    [Flags,
    SuppressMessage(
        "Microsoft.Design",
        "CA1008:EnumsShouldHaveZeroValue",
        Justification = "Native enum."),
    SuppressMessage("Microsoft.Usage",
        "CA2217:DoNotMarkEnumsWithFlags",
        Justification = "Native enum.")]
    public enum TokenAccessRights
    {
        /// <summary>Right to attach a primary token to a process.</summary>
        AssignPrimary = 0,

        /// <summary>Right to duplicate an access token.</summary>
        Duplicate = 1,

        /// <summary>Right to attach an impersonation access token to a process.</summary>
        Impersonate = 4,

        /// <summary>Right to query an access token.</summary>
        Query = 8,

        /// <summary>Right to query the source of an access token.</summary>
        QuerySource = 16,

        /// <summary>Right to enable or disable the privileges in an access token.</summary>
        AdjustPrivileges = 32,

        /// <summary>Right to adjust the attributes of the groups in an access token.</summary>
        AdjustGroups = 64,

        /// <summary>Right to change the default owner, primary group, or DACL of an access token.</summary>
        AdjustDefault = 128,

        /// <summary>Right to adjust the session ID of an access token.</summary>
        AdjustSessionId = 256,

        /// <summary>Combines all possible access rights for a token.</summary>
        AllAccess = AccessTypeMasks.StandardRightsRequired |
            AssignPrimary |
            Duplicate |
            Impersonate |
            Query |
            QuerySource |
            AdjustPrivileges |
            AdjustGroups |
            AdjustDefault |
            AdjustSessionId,

        /// <summary>Combines the standard rights required to read with <see cref="Query"/>.</summary>
        Read = AccessTypeMasks.StandardRightsRead |
            Query,

        /// <summary>Combines the standard rights required to write with <see cref="AdjustDefault"/>, <see cref="AdjustGroups"/> and <see cref="AdjustPrivileges"/>.</summary>
        Write = AccessTypeMasks.StandardRightsWrite |
            AdjustPrivileges |
            AdjustGroups |
            AdjustDefault,

        /// <summary>Combines the standard rights required to execute with <see cref="Impersonate"/>.</summary>
        Execute = AccessTypeMasks.StandardRightsExecute |
            Impersonate
    }

    [Flags]
    internal enum AccessTypeMasks
    {
        Delete = 65536,

        ReadControl = 131072,

        WriteDAC = 262144,

        WriteOwner = 524288,

        Synchronize = 1048576,

        StandardRightsRequired = 983040,

        StandardRightsRead = ReadControl,

        StandardRightsWrite = ReadControl,

        StandardRightsExecute = ReadControl,

        StandardRightsAll = 2031616,

        SpecificRightsAll = 65535
    }

    internal enum TokenInformationClass
    {
        None,
        TokenUser,
        TokenGroups,
        TokenPrivileges,
        TokenOwner,
        TokenPrimaryGroup,
        TokenDefaultDacl,
        TokenSource,
        TokenType,
        TokenImpersonationLevel,
        TokenStatistics,
        TokenRestrictedSids,
        TokenSessionId,
        TokenGroupsAndPrivileges,
        TokenSessionReference,
        TokenSandBoxInert,
        TokenAuditPolicy,
        TokenOrigin,
        TokenElevationType,
        TokenLinkedToken,
        TokenElevation,
        TokenHasRestrictions,
        TokenAccessInformation,
        TokenVirtualizationAllowed,
        TokenVirtualizationEnabled,
        TokenIntegrityLevel,
        TokenUIAccess,
        TokenMandatoryPolicy,
        TokenLogonSid,
        MaxTokenInfoClass
    }
}