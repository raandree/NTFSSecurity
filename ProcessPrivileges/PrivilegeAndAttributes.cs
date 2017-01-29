// <copyright file="PrivilegeAndAttributes.cs" company="Nick Lowe">
// Copyright © Nick Lowe 2009
// </copyright>
// <author>Nick Lowe</author>
// <email>nick@int-r.net</email>
// <url>http://processprivileges.codeplex.com/</url>

namespace ProcessPrivileges
{
    using System;

    /// <summary>Structure that links <see cref="Privilege"/> and <see cref="PrivilegeAttributes"/> together.</summary>
    public struct PrivilegeAndAttributes : IEquatable<PrivilegeAndAttributes>
    {
        private readonly Privilege privilege;

        private readonly PrivilegeAttributes privilegeAttributes;

        internal PrivilegeAndAttributes(Privilege privilege, PrivilegeAttributes privilegeAttributes)
        {
            this.privilege = privilege;
            this.privilegeAttributes = privilegeAttributes;
        }

        /// <summary>Gets the privilege.</summary>
        /// <value>The privilege.</value>
        public Privilege Privilege
        {
            get
            {
                return this.privilege;
            }
        }

        /// <summary>Gets the privilege attributes.</summary>
        /// <value>The privilege attributes.</value>
        public PrivilegeAttributes PrivilegeAttributes
        {
            get
            {
                return this.privilegeAttributes;
            }
        }

        /// <summary>Gets the privilege state.</summary>
        /// <value>The privilege state.</value>
        /// <remarks>Derived from <see cref="PrivilegeAttributes"/>.</remarks>
        public PrivilegeState PrivilegeState
        {
            get
            {
                return ProcessExtensions.GetPrivilegeState(this.privilegeAttributes);
            }
        }

        /// <summary>Compares two instances for equality.</summary>
        /// <param name="first">First instance.</param>
        /// <param name="second">Second instance.</param>
        /// <returns>Value indicating equality of instances.</returns>
        public static bool operator ==(PrivilegeAndAttributes first, PrivilegeAndAttributes second)
        {
            return first.Equals(second);
        }

        /// <summary>Compares two instances for inequality.</summary>
        /// <param name="first">First instance.</param>
        /// <param name="second">Second instance.</param>
        /// <returns>Value indicating inequality of instances.</returns>
        public static bool operator !=(PrivilegeAndAttributes first, PrivilegeAndAttributes second)
        {
            return !first.Equals(second);
        }

        /// <summary>Returns the hash code for this instance.</summary>
        /// <returns>The hash code for this instance.</returns>
        public override int GetHashCode()
        {
            return this.privilege.GetHashCode() ^ this.privilegeAttributes.GetHashCode();
        }

        /// <summary>Indicates whether this instance and a specified object are equal.</summary>
        /// <param name="obj">Another object to compare to.</param>
        /// <returns>Value indicating whether this instance and a specified object are equal.</returns>
        public override bool Equals(object obj)
        {
            return obj is PrivilegeAttributes ? this.Equals((PrivilegeAttributes)obj) : false;
        }

        /// <summary>Indicates whether this instance and another instance are equal.</summary>
        /// <param name="other">Another instance to compare to.</param>
        /// <returns>Value indicating whether this instance and another instance are equal.</returns>
        public bool Equals(PrivilegeAndAttributes other)
        {
            return this.privilege == other.Privilege && this.privilegeAttributes == other.PrivilegeAttributes;
        }

        public override string ToString()
        {
            return privilege.ToString();
        }
    }
}