using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.IO;
using NTFSSecurityTest.Properties;

namespace NTFSSecurityTest
{
    [TestClass]
    public class UnitTest1
    {
        [TestMethod]
        public void TestMethod1()
        {
            Assert.IsTrue(Directory.Exists(Settings.Default.path + "1"));
        }

        [TestInitialize]
        public void Init()
        {
            System.Threading.Thread.Sleep(3000);
            Directory.CreateDirectory(Settings.Default.path);
        }

        [TestCleanup]
        public void Cleanup()
        {
            Directory.Delete(Settings.Default.path);
        }
    }
}
