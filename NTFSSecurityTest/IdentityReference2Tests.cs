using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Security.Principal;

namespace Security2.Tests
{
    [TestClass()]
    public class IdentityReference2Tests
    {
        IdentityReference2 currentUser;
        IdentityReference2 currentUser2;
        IdentityReference2 systemAccount;
        string invalidSid;

        [TestInitialize]
        public void Init()
        {
            currentUser = WindowsIdentity.GetCurrent().User;
            currentUser2 = WindowsIdentity.GetCurrent().User;
            systemAccount = new IdentityReference2(@"NT AUTHORITY\SYSTEM");
            invalidSid = "S-1-5-2-123456789-2021496291-1752113662-1002";
        }        

        [TestMethod()]
        public void EqualsToNameStringTest()
        {
            var name = WindowsIdentity.GetCurrent().User.Translate(typeof(NTAccount)).Value;
            Assert.IsTrue(currentUser.Equals(name));
        }

        [TestMethod()]
        public void NotEqualsToNameStringTest()
        {
            var name = systemAccount.AccountName;
            Assert.IsFalse(currentUser.Equals(name));
        }

        [TestMethod()]
        public void EqualsToSidStringTest()
        {
            var sid = WindowsIdentity.GetCurrent().User.Value;
            Assert.IsTrue(currentUser.Equals(sid));
        }

        [TestMethod()]
        public void NotEqualsToSidStringTest()
        {
            var sid = systemAccount.Sid;
            Assert.IsFalse(currentUser.Equals(sid));
        }

        [TestMethod()]
        public void NotEqualsToStringTest()
        {
            Assert.IsFalse(currentUser.Equals(systemAccount.AccountName));
        }

        [TestMethod()]
        public void EqualsToNTAccount()
        {
            var ntAccount = WindowsIdentity.GetCurrent().User.Translate(typeof(NTAccount));
            Assert.IsTrue(currentUser.Equals(ntAccount));
        }

        [TestMethod()]
        public void NotEqualsToNTAccount()
        {
            var ntAccount = new NTAccount(systemAccount.AccountName);
            Assert.IsFalse(currentUser.Equals(ntAccount));
        }

        [TestMethod()]
        public void EqualsToSecurityIdentifier()
        {
            var sid = WindowsIdentity.GetCurrent().User;
            Assert.IsTrue(currentUser.Equals(sid));
        }

        [TestMethod()]
        public void NotEqualsToSecurityIdentifier()
        {
            var sid = new SecurityIdentifier(systemAccount.Sid);
            Assert.IsFalse(currentUser.Equals(sid));
        }

        [TestMethod()]
        public void EqualsToIdentityReference2()
        {
            Assert.IsTrue(currentUser.Equals(currentUser2));
        }

        [TestMethod()]
        public void NotEqualsToIdentityReference2()
        {
            Assert.IsFalse(currentUser.Equals(systemAccount));
        }

        [TestMethod()]
        [ExpectedException(typeof(System.NullReferenceException))]
        public void EqualsToNullThrowsException()
        {
            IdentityReference2 ir2 = null;
            ir2.Equals(null);
        }

        [TestMethod()]
        public void NotEqualsToNull()
        {
            Assert.IsFalse(currentUser.Equals(null));
        }

        [TestMethod()]
        public void GetHashCodeWithCurrentUserTest()
        {
            var sid = new SecurityIdentifier(currentUser.GetBinaryForm(), 0);

            Assert.AreEqual(sid.GetHashCode(), currentUser.GetHashCode());
        }

        [TestMethod()]
        public void GetBinaryFormWithCurrentUserTest()
        {
            var sid = new SecurityIdentifier(currentUser.GetBinaryForm(), 0);

            Assert.AreEqual(sid.Value, currentUser.Sid);
        }

        [TestMethod()]
        public void ToStringWithCurrentUserTest()
        {
            var sid = WindowsIdentity.GetCurrent().User;
            var ntAccount = sid.Translate(typeof(NTAccount));

            Assert.AreEqual(currentUser.ToString(), ntAccount.Value);
        }

        [TestMethod()]
        public void ToStringWithInvalidSidEqualsNull()
        {
            var ir2 = (IdentityReference2)invalidSid;
            Assert.AreEqual(ir2.ToString(), invalidSid);
        }

        [TestMethod()]
        public void op_ReferenceEquals()
        {
            var temp = currentUser;
            Assert.IsTrue(currentUser == temp);
        }

        [TestMethod()]
        public void op_EqualsToIdentityReference2()
        {
            Assert.IsTrue(currentUser == currentUser2);
        }

        [TestMethod()]
        public void op_NotEqualsToIdentityReference2()
        {
            Assert.IsTrue(currentUser != systemAccount);
        }

        [TestMethod()]
        public void op_EqualsToNTAccout()
        {
            var ntAccount = new NTAccount(currentUser.AccountName);
            Assert.IsTrue(currentUser == ntAccount);
        }

        [TestMethod()]
        public void op_NotEqualsToNTAccount()
        {
            var ntAccount = new NTAccount(systemAccount.AccountName);
            Assert.IsTrue(currentUser != ntAccount);
        }

        [TestMethod()]
        public void op_EqualsToSecurityIdentifier()
        {
            var sid = new SecurityIdentifier(currentUser.Sid);
            Assert.IsTrue(currentUser == sid);
        }

        [TestMethod()]
        public void op_NotEqualsToSecurityIdentifier()
        {
            var sid = new SecurityIdentifier(systemAccount.Sid);
            Assert.IsTrue(currentUser != sid);
        }
    }
}