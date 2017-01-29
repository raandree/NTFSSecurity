using System;
using System.Security.Principal;
using System.Text.RegularExpressions;

namespace Security2
{
    public class IdentityReference2
    {
        protected static Regex sidValidation = new Regex("(S-1-)[0-9-]+", RegexOptions.IgnoreCase);
        protected SecurityIdentifier sid;
        protected NTAccount ntAccount;
        protected string lastError;

        #region Properties

        public string Sid
        {
            get { return sid.Value; }
        }

        public string AccountName
        {
            get
            {
                return ntAccount != null ? ntAccount.Value : string.Empty;
            }
        }

        public string LastError
        {
            get { return lastError; }
        }

        #endregion Properties

        #region Constructors

        public IdentityReference2(IdentityReference ir)
        {
            ntAccount = ir as NTAccount;
            if (ntAccount != null)
            {
                //throws an IdentityNotMapped Exception if the account cannot be translated
                sid = (SecurityIdentifier)ntAccount.Translate(typeof(SecurityIdentifier));
            }
            else
            {
                sid = ir as SecurityIdentifier;
                if (sid != null)
                {
                    try
                    {
                        ntAccount = (NTAccount)sid.Translate(typeof(NTAccount));
                    }
                    catch (Exception ex)
                    {
                        lastError = ex.Message;
                    }
                }
            }
        }

        public IdentityReference2(string value)
        {
            if (string.IsNullOrEmpty(value))
                throw new ArgumentException("The value cannot be empty");

            var sidMatch = sidValidation.Match(value);

            if (!string.IsNullOrEmpty(sidMatch.Value))
            {
                //creating a SecurityIdentifier should always work if the string is in the right format
                try
                {
                    sid = new SecurityIdentifier(sidMatch.Value);
                }
                catch (Exception ex)
                {
                    throw new InvalidCastException("Could not create an IdentityReference2 with the given SID", ex);
                }

                //this is only going to work if the SID can be resolved
                try
                {
                    ntAccount = (NTAccount)sid.Translate(typeof(NTAccount));
                }
                catch (Exception ex)
                {
                    lastError = ex.Message;
                }
            }
            else
            {
                try
                {
                    //creating an NTAccount always works, the OS does not verify the name
                    ntAccount = new NTAccount(value);
                    //verification si done by translating the name into a SecurityIdentifier (SID)
                    sid = (SecurityIdentifier)ntAccount.Translate(typeof(SecurityIdentifier));
                }
                catch (IdentityNotMappedException ex)
                {
                    throw ex;
                }
            }
        }

        #endregion Constructors

        #region Conversion

        //NTAccount
        public static explicit operator NTAccount(IdentityReference2 ir2)
        {
            return ir2.ntAccount;
        }

        public static explicit operator IdentityReference2(NTAccount ntAccount)
        {
            return new IdentityReference2(ntAccount);
        }

        //SecurityIdentifier
        public static explicit operator SecurityIdentifier(IdentityReference2 ir2)
        {
            return ir2.sid;
        }

        public static explicit operator IdentityReference2(SecurityIdentifier sid)
        {
            return new IdentityReference2(sid);
        }

        //IdentityReference
        public static implicit operator IdentityReference(IdentityReference2 ir2)
        {
            return ir2.sid;
        }

        public static implicit operator IdentityReference2(IdentityReference ir)
        {
            return new IdentityReference2(ir);
        }

        //string
        public static implicit operator IdentityReference2(string value)
        {
            return new IdentityReference2(value);
        }

        public static implicit operator string(IdentityReference2 ir2)
        {
            return ir2.ToString();
        }

        #endregion Conversion

        #region comparison

        public override bool Equals(object obj)
        {
            //Instance cannot be null
            if (ReferenceEquals(obj, null))
                return false;

            //Instances are equal
            if (ReferenceEquals(this, obj))
                return true;

            SecurityIdentifier sid = obj as SecurityIdentifier;
            if (sid != null)
            {
                return this.sid == sid;
            }

            var ntAccount = obj as NTAccount;
            if (ntAccount != null)
            {
                return this.ntAccount == ntAccount;
            }

            IdentityReference2 ir2 = obj as IdentityReference2;
            if (ir2 != null)
            {
                return this.sid == ir2.sid;
            }

            string value = obj as string;
            if (value != null)
            {
                if (this.sid.Value == value)
                {
                    return true;
                }

                if (this.ntAccount != null)
                {
                    if (this.ntAccount.Value.ToLower() == value.ToLower())
                    {
                        return true;
                    }
                }
            }

            return false;
        }

        public override int GetHashCode()
        {
            return sid.GetHashCode();
        }

        public static bool operator ==(IdentityReference2 ir1, IdentityReference2 ir2)
        {
            //Instances are equal
            if (ReferenceEquals(ir1, ir2))
                return true;

            //Instance cannot be null
            if (ReferenceEquals(ir1, null) | ReferenceEquals(ir2, null))
                return false;

            return ir1.Equals(ir2);
        }

        public static bool operator !=(IdentityReference2 ir1, IdentityReference2 ir2)
        {
            //Instances are equal
            if (ReferenceEquals(ir1, ir2))
                return false;

            //Instance cannot be null
            if (ReferenceEquals(ir1, null) | ReferenceEquals(ir2, null))
                return true;

            return !ir1.Equals(ir2);
        }

        #endregion comparison

        #region Methods

        public byte[] GetBinaryForm()
        {
            byte[] rawSid = new byte[sid.BinaryLength];
            sid.GetBinaryForm(rawSid, 0);
            return rawSid;
        }

        public override string ToString()
        {
            if (ntAccount == null)
            {
                return sid.ToString();
            }
            else
            {
                return ntAccount.ToString();
            }
        }

        #endregion Methods
    }
}