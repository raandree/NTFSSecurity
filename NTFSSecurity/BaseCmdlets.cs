using System.Management.Automation;
using Security2;
using ProcessPrivileges;
using System.Linq;
using System.Collections.Generic;
using System;
using System.Collections;

namespace NTFSSecurity
{
    public class BaseCmdlet : PSCmdlet
    {
        protected List<string> paths = new List<string>();
        protected List<FileSystemSecurity2> securityDescriptors = new List<FileSystemSecurity2>();

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
        }

        #region GetFileSystemInfo
        protected System.IO.FileSystemInfo GetFileSystemInfo(string path)
        {
            path = GetRelativePath(path);

            if (System.IO.File.Exists(path))
            {
                return new System.IO.FileInfo(path);
            }
            else if (System.IO.Directory.Exists(path))
            {
                return new System.IO.DirectoryInfo(path);
            }
            else
            {
                throw new System.IO.FileNotFoundException();
            }
        }
        #endregion

        #region GetFileSystemInfo2
        protected Alphaleonis.Win32.Filesystem.FileSystemInfo GetFileSystemInfo2(string path)
        {
            path = GetRelativePath(path);

            if (Alphaleonis.Win32.Filesystem.File.Exists(path))
            {
                return new Alphaleonis.Win32.Filesystem.FileInfo(path);
            }
            else if (Alphaleonis.Win32.Filesystem.Directory.Exists(path))
            {
                return new Alphaleonis.Win32.Filesystem.DirectoryInfo(path);
            }
            else
            {
                throw new System.IO.FileNotFoundException();
            }
        }
        #endregion

        #region TryGetFileSystemInfo2
        protected bool TryGetFileSystemInfo2(string path, out Alphaleonis.Win32.Filesystem.FileSystemInfo item)
        {
            path = GetRelativePath(path);
            item = null;

            if (Alphaleonis.Win32.Filesystem.File.Exists(path))
            {
                item = new Alphaleonis.Win32.Filesystem.FileInfo(path);
            }
            else if (Alphaleonis.Win32.Filesystem.Directory.Exists(path))
            {
                item = new Alphaleonis.Win32.Filesystem.DirectoryInfo(path);
            }
            else
            {
                return false;
            }

            return true;
        }
        #endregion

        #region GetRelativePath
        protected string GetRelativePath(string path)
        {
            if (string.IsNullOrEmpty(path))
            {
                path = GetCurrentLocation();
            }
            else if (path == ".")
            {
                path = GetCurrentLocation();
            }
            else if (path.StartsWith(".."))
            {
                var currentLocation = GetCurrentLocation();
                path = System.IO.Path.Combine(
                    string.Join("\\", currentLocation.Split('\\').Take(currentLocation.Split('\\').Count() - path.Split('\\').Count(s => s == "..")).ToArray()),
                    string.Join("\\", path.Split('\\').Where(e => e != "..").ToArray()));
            }
            else if (path.StartsWith("."))
            {
                //combine . and .\path\subpath
                path = System.IO.Path.Combine(GetCurrentLocation(), path.Substring(2));
            }
            else if (path.StartsWith("\\") || System.IO.Path.IsPathRooted(path))
            {
                //an absolute path needs no location
            }
            else
            {
                ////combine . and path\subpath
                path = System.IO.Path.Combine(GetCurrentLocation(), path);
            }

            return path;
        }

        // Read from the session state, not from $PWD: a variable named PWD in the caller's scope shadows the
        // automatic variable and can be $null (#86). In a location of another provider, such as the registry, this
        // is the last file system location.
        private string GetCurrentLocation()
        {
            return SessionState.Path.CurrentFileSystemLocation.ProviderPath;
        }
        #endregion

        #region InvokeAsOwner
        /// <summary>
        /// Takes ownership of the item, runs the action, and restores the previous owner on every exit path.
        /// A failure to restore the owner is written as a RestoreOwnerError and doesn't hide an error of the action.
        /// </summary>
        /// <param name="item">The file or folder to take ownership of.</param>
        /// <param name="path">The path the user specified, used as the error target.</param>
        /// <param name="action">The operation to run while the current user owns the item.</param>
        protected void InvokeAsOwner(Alphaleonis.Win32.Filesystem.FileSystemInfo item, string path, Action action)
        {
            var previousOwner = FileSystemOwner.GetOwner(item).Owner;

            FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

            try
            {
                action();
            }
            finally
            {
                try
                {
                    FileSystemOwner.SetOwner(item, previousOwner);
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "RestoreOwnerError", ErrorCategory.WriteError, path));
                }
            }
        }
        #endregion
    }

    public class BaseCmdletWithPrivControl : BaseCmdlet
    {
        protected PrivilegeAndAttributesCollection privileges = null;
        protected PrivilegeControl privControl = new PrivilegeControl();
        private List<string> enabledPrivileges = new List<string>();
        Hashtable privateData = null;

        protected override void BeginProcessing()
        {
            privateData = (Hashtable)MyInvocation.MyCommand.Module.PrivateData;

            if ((bool)privateData["EnablePrivileges"])
            {
                WriteVerbose("EnablePrivileges enabled in PrivateDate");
                EnableFileSystemPrivileges(true);
            }
        }

        protected override void EndProcessing()
        {
            if ((bool)privateData["EnablePrivileges"])
            {
                WriteVerbose("EnablePrivileges enabled in PrivateDate");

                //disable all privileges that have been enabled by this cmdlet
                WriteVerbose(string.Format("Disabeling all {0} enabled privileges...", enabledPrivileges.Count));
                foreach (var privilege in enabledPrivileges)
                {
                    DisablePrivilege((Privilege)Enum.Parse(typeof(Privilege), privilege));
                    WriteVerbose(string.Format("\t{0} disabled", privilege));
                }
                WriteVerbose(string.Format("...finished"));
            }
        }

        protected void EnablePrivilege(Privilege privilege)
        {
            //throw an exception if the specified prililege is not held by the client
            if (!privileges.Any(p => p.Privilege == privilege))
                throw new System.Security.AccessControl.PrivilegeNotHeldException(privilege.ToString());

            //if the privilege is disabled
            if (privileges.Single(p => p.Privilege == privilege).PrivilegeState == PrivilegeState.Disabled)
            {
                WriteDebug(string.Format("The privilege {0} is disabled...", privilege));
                //activate it
                privControl.EnablePrivilege(privilege);
                WriteDebug(string.Format("..enabled"));
                //remember the privilege so that we can automatically disable it after the cmdlet finished processing
                enabledPrivileges.Add(privilege.ToString());

                privileges = privControl.GetPrivileges();
            }
        }

        public void DisablePrivilege(Privilege privilege)
        {
            //if the privilege is enabled
            if (privileges.Single(p => p.Privilege == privilege).PrivilegeState == PrivilegeState.Enabled)
                privControl.DisablePrivilege(privilege);
        }

        protected bool TryEnablePrivilege(Privilege privilege)
        {
            try
            {
                EnablePrivilege(privilege);
                return true;
            }
            catch(Exception ex)
            {
                WriteDebug(string.Format("Could not enable privilege {0}. The error was: {1}", privilege, ex.Message));
                return false;
            }
        }

        protected bool TryDisablePrivilege(Privilege privilege)
        {
            try
            {
                DisablePrivilege(privilege);
                return true;
            }
            catch
            {
                WriteDebug(string.Format("Could not disable privilege {0}.", privilege));
                return false;
            }
        }

        protected void EnableFileSystemPrivileges(bool quite = true)
        {
            privileges = (new PrivilegeControl()).GetPrivileges();

            if (!TryEnablePrivilege(Privilege.TakeOwnership))
                WriteDebug("The privilige 'TakeOwnership' could not be enabled. Make sure your user account does have this privilige");

            if (!TryEnablePrivilege(Privilege.Restore))
                WriteDebug("The privilige 'Restore' could not be enabled. Make sure your user account does have this privilige");

            if (!TryEnablePrivilege(Privilege.Backup))
                WriteDebug("The privilige 'Backup' could not be enabled. Make sure your user account does have this privilige");

            if (!TryEnablePrivilege(Privilege.Security))
                WriteDebug("The privilige 'Security' could not be enabled. Make sure your user account does have this privilige");

            if (!quite)
            {
                if (privControl.GetPrivileges()
                    .Where(p => p.PrivilegeState == PrivilegeState.Enabled)
                    .Where(p =>
                        (p.Privilege == Privilege.TakeOwnership) |
                        (p.Privilege == Privilege.Restore) |
                        (p.Privilege == Privilege.Backup) |
                        (p.Privilege == Privilege.Security)).Count() == 4)
                {
                    WriteVerbose("The privileges 'Backup', 'Restore', 'TakeOwnership' and 'Security' are now enabled giving you access to all files and folders. Use Disable-Privileges to disable them and Get-Privileges for an overview.");
                }
                else
                {
                    WriteError(new ErrorRecord(new AdjustPriviledgeException("Could not enable requested privileges. Cmdlets of NTFSSecurity will only work on resources you have access to."), "Enable Privilege Error", ErrorCategory.SecurityError, null));
                    return;
                }
            }
        }

        protected void DisableFileSystemPrivileges()
        {
            // Refreshes the field that DisablePrivilege reads; it is null when BeginProcessing enabled nothing.
            privileges = privControl.GetPrivileges();

            if (privileges.Where(p => p.Privilege == Privilege.TakeOwnership) != null)
                if (!TryDisablePrivilege(Privilege.TakeOwnership))
                    WriteWarning("The privilige 'TakeOwnership' could not be disabled.");
                else
                    WriteDebug("The privilige 'TakeOwnership' was disabled.");

            if (privileges.Where(p => p.Privilege == Privilege.Restore) != null)
                if (!TryDisablePrivilege(Privilege.Restore))
                    WriteWarning("The privilige 'Restore' could not be disabled.");
                else
                    WriteDebug("The privilige 'Restore' was disabled.");

            if (privileges.Where(p => p.Privilege == Privilege.Backup) != null)
                if (!TryDisablePrivilege(Privilege.Backup))
                    WriteWarning("The privilige 'Backup' could not be disabled.");
                else
                    WriteDebug("The privilige 'Backup' was disabled.");

            if (!TryDisablePrivilege(Privilege.Security))
                WriteWarning("The privilige 'Security' could not be disabled.");
            else
                WriteDebug("The privilige 'Security' was disabled.");
        }

        // These overloads hide the single-argument methods of Cmdlet, so a message without arguments must not be
        // formatted: a path with braces in it would make string.Format throw (#3).
        protected void WriteWarning(string text, params string[] args)
        {
            base.WriteWarning(args == null || args.Length == 0 ? text : string.Format(text, args));
        }
        protected void WriteVerbose(string text, params string[] args)
        {
            base.WriteVerbose(args == null || args.Length == 0 ? text : string.Format(text, args));
        }

        protected void WriteDebug(string text, params string[] args)
        {
            base.WriteDebug(args == null || args.Length == 0 ? text : string.Format(text, args));
        }
    }
}
