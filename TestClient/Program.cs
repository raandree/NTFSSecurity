using Alphaleonis.Win32.Filesystem;
using NTFSSecurity;
using Security2;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Security.AccessControl;
using System.Security.Principal;

namespace TestClient
{
    class Program
    {
        static void Main(string[] args)
        {
            var item1 = new FileInfo("D:\\file1.txt");
            var item2 = new DirectoryInfo("D:\\test3");
            var account1 = new List<IdentityReference2>() { (IdentityReference2)@"raandree1\randr_000" };

            FileSystemAccessRule2.AddFileSystemAccessRule(item1, account1, FileSystemRights2.FullControl, AccessControlType.Allow, InheritanceFlags.ContainerInherit, PropagationFlags.None);

            return;
            var path = @"C:\Windows";
            var account = @"raandree1\randr_000";
            var server = "localhost";

            var sd = Directory.GetAccessControl(path, AccessControlSections.Access);
            var id = new IdentityReference2(account);
            EffectiveAccess.GetEffectiveAccess(new FileInfo(path), id, "localhost");

            var result1 = InvokeCommand("gi2 c:\\windows");

            var result2 = InvokeCommand(@"gi -Path D:\SingleMachine\ | Get-EffectiveAccess")
                .Select(ace => ace.ImmediateBaseObject)
                .Cast<FileSystemAccessRule2>().ToList();

            foreach (var ace in result2)
            {
                Console.WriteLine(string.Format("{0};{1}", ace.Account, ace.IsInherited));
            }

            Console.ReadKey();
        }

        public static List<PSObject> InvokeCommand(string script)
        {
            var runspace = RunspaceFactory.CreateRunspace();
            runspace.Open();
            var powershell = PowerShell.Create();
            powershell.Runspace = runspace;

            powershell.Commands.AddScript(script);
            var result = powershell.Invoke();

            powershell.Dispose();
            runspace.Close();

            return result.ToList();
        }

        public static List<PSObject> InvokeCommand(string command, Dictionary<string, object> parameters)
        {
            var runspace = RunspaceFactory.CreateRunspace();
            runspace.Open();
            var powershell = PowerShell.Create();
            powershell.Runspace = runspace;

            var cmd = new Command(command);
            foreach (var parameter in parameters)
            {
                cmd.Parameters.Add(parameter.Key, parameter.Value);
            }

            powershell.Commands.AddCommand(cmd);
            var result = powershell.Invoke();

            powershell.Dispose();
            runspace.Close();

            return result.ToList();
        }
    }
}