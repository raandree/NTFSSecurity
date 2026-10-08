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

        // A security descriptor that was read without its audit entries, such as without the Security privilege, has
        // nothing for the audit cmdlets to read or change. They report it the same way (#109).
        internal bool TestAuditSection(FileSystemSecurity2 sd)
        {
            if (sd.HasAuditSection)
            {
                return true;
            }

            var ex = new InvalidOperationException(string.Format(
                "The security descriptor of '{0}' doesn't contain the audit entries. Read it with Get-NTFSSecurityDescriptor in a session that holds the Security privilege.", sd.FullName));
            WriteError(new ErrorRecord(ex, "ReadSecurityError", ErrorCategory.InvalidData, sd));
            return false;
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
            else if (path == ".." || path.StartsWith("..\\"))
            {
                var currentLocation = GetCurrentLocation();
                path = System.IO.Path.Combine(
                    string.Join("\\", currentLocation.Split('\\').Take(currentLocation.Split('\\').Count() - path.Split('\\').Count(s => s == "..")).ToArray()),
                    string.Join("\\", path.Split('\\').Where(e => e != "..").ToArray()));
            }
            else if (path.StartsWith(".\\") || path.StartsWith("./"))
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

        /// <summary>
        /// Returns the current file system location of the session. It is read from the session state, not from
        /// $PWD, which a variable named PWD in the scope of the caller can hide (#86). In a location of another
        /// provider, such as the registry, this is the last file system location.
        /// </summary>
        /// <returns>The provider path of the current file system location.</returns>
        protected string GetCurrentLocation()
        {
            return SessionState.Path.CurrentFileSystemLocation.ProviderPath;
        }
        #endregion

        #region WriteMissingDestinationFolderError
        /// <summary>
        /// Returns the folder of a destination path when that folder doesn't exist.
        /// </summary>
        /// <param name="destinationPath">The full path of the item that the operation would create.</param>
        /// <returns>The missing folder, or null when the folder exists or the path has none, such as a share root.</returns>
        protected string GetMissingDestinationFolder(string destinationPath)
        {
            var folder = Alphaleonis.Win32.Filesystem.Path.GetDirectoryName(destinationPath.TrimEnd('\\'));
            if (string.IsNullOrEmpty(folder) || Alphaleonis.Win32.Filesystem.Directory.Exists(folder))
            {
                return null;
            }

            return folder;
        }

        /// <summary>
        /// Writes an error that names the folder of a destination path when that folder doesn't exist. Before
        /// 5.0.0-rc6, AlphaFS reported such a destination as the source path that could not be found (#21), and
        /// Copy-Item2 created the missing folders for a folder.
        /// </summary>
        /// <param name="destinationPath">The full path of the item that the operation would create.</param>
        /// <param name="errorId">The error ID of the cmdlet for a failed operation.</param>
        /// <returns>Whether the folder is missing and the error was written.</returns>
        protected bool WriteMissingDestinationFolderError(string destinationPath, string errorId)
        {
            var folder = GetMissingDestinationFolder(destinationPath);
            if (folder == null)
            {
                return false;
            }

            var exception = new System.IO.DirectoryNotFoundException(string.Format("The destination folder '{0}' does not exist.", folder));
            WriteError(new ErrorRecord(exception, errorId, ErrorCategory.ObjectNotFound, destinationPath));
            return true;
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

    public class BaseCmdletWithPrivControl : BaseCmdlet, IDisposable
    {
        protected PrivilegeAndAttributesCollection privileges = null;
        protected PrivilegeControl privControl = new PrivilegeControl();
        private List<string> enabledPrivileges = new List<string>();
        Hashtable privateData = null;

        // A cmdlet that enables the privileges for the session, such as Enable-Privileges, keeps them enabled.
        protected virtual bool KeepEnabledPrivileges
        {
            get { return false; }
        }

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
                var failed = new Dictionary<string, Exception>();
                foreach (var privilege in DisableEnabledPrivileges(failed))
                {
                    WriteVerbose(string.Format("\t{0} disabled", privilege));
                }
                foreach (var failure in failed)
                {
                    WriteDebug(string.Format("Could not disable privilege {0}. The error was: {1}", failure.Key, failure.Value.Message));
                    WriteWarning(string.Format("The privilege '{0}' could not be disabled.", failure.Key));
                }
                WriteVerbose(string.Format("...finished"));
            }
        }

        // PowerShell calls Dispose also when a later command or a terminating error stops the pipeline, and then
        // skips EndProcessing. Before 5.0.0-rc6, the privileges that the cmdlet had enabled stayed enabled in the
        // session in that case. PowerShell ignores an exception from Dispose and no stream is open anymore, so a
        // privilege that can't be disabled goes unreported here.
        public void Dispose()
        {
            DisableEnabledPrivileges(new Dictionary<string, Exception>());
            GC.SuppressFinalize(this);
        }

        // Disables the privileges that this cmdlet enabled, once, and returns their names. A privilege that can't be
        // disabled goes to failed with its error and doesn't keep the others enabled.
        private List<string> DisableEnabledPrivileges(Dictionary<string, Exception> failed)
        {
            var disabled = new List<string>();
            if (!KeepEnabledPrivileges)
            {
                foreach (var privilege in enabledPrivileges)
                {
                    try
                    {
                        DisablePrivilege((Privilege)Enum.Parse(typeof(Privilege), privilege));
                        disabled.Add(privilege);
                    }
                    catch (Exception ex)
                    {
                        failed[privilege] = ex;
                    }
                }
            }

            enabledPrivileges.Clear();
            return disabled;
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
            // The current state, not the one that the cmdlet read when it enabled the privileges: another command, also
            // one in the same pipeline, can have disabled the privilege since then. Before 5.0.0-rc6, the cmdlet then
            // failed with "Priviledge already disabled" and left the privileges after this one enabled.
            if (privControl.GetPrivileges().Any(p => p.Privilege == privilege && p.PrivilegeState == PrivilegeState.Enabled))
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
                WriteDebug("The privilege 'TakeOwnership' could not be enabled. Make sure your user account does have this privilege");

            if (!TryEnablePrivilege(Privilege.Restore))
                WriteDebug("The privilege 'Restore' could not be enabled. Make sure your user account does have this privilege");

            if (!TryEnablePrivilege(Privilege.Backup))
                WriteDebug("The privilege 'Backup' could not be enabled. Make sure your user account does have this privilege");

            if (!TryEnablePrivilege(Privilege.Security))
                WriteDebug("The privilege 'Security' could not be enabled. Make sure your user account does have this privilege");

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

            // Only the privileges that the access token holds; disabling another one fails.
            foreach (var privilege in new[] { Privilege.TakeOwnership, Privilege.Restore, Privilege.Backup, Privilege.Security })
            {
                if (!privileges.Any(p => p.Privilege == privilege))
                    continue;

                if (!TryDisablePrivilege(privilege))
                    WriteWarning(string.Format("The privilege '{0}' could not be disabled.", privilege));
                else
                    WriteDebug(string.Format("The privilege '{0}' was disabled.", privilege));
            }
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

    /// <summary>
    /// Converts file and folder objects to their full path. Windows PowerShell binds an object that is passed by
    /// position to a string parameter through ToString, which returns only the name of a child item, so the cmdlet
    /// resolved it against the current location (#88).
    /// </summary>
    [AttributeUsage(AttributeTargets.Property | AttributeTargets.Field)]
    public sealed class FileSystemPathTransformationAttribute : ArgumentTransformationAttribute
    {
        /// <summary>
        /// Returns the full path of a file or folder object, or of each one in a collection, and any other value
        /// unchanged.
        /// </summary>
        /// <param name="engineIntrinsics">The engine APIs of the session.</param>
        /// <param name="inputData">The argument to transform.</param>
        /// <returns>The transformed argument.</returns>
        public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
        {
            var input = inputData is PSObject ? ((PSObject)inputData).BaseObject : inputData;

            if (input is string || !(input is IEnumerable))
            {
                return ToPath(inputData);
            }

            var result = new List<object>();
            foreach (var item in (IEnumerable)input)
            {
                result.Add(ToPath(item));
            }

            return result.ToArray();
        }

        private static object ToPath(object value)
        {
            var baseObject = value is PSObject ? ((PSObject)value).BaseObject : value;

            if (baseObject is System.IO.FileSystemInfo)
            {
                return ((System.IO.FileSystemInfo)baseObject).FullName;
            }

            if (baseObject is Alphaleonis.Win32.Filesystem.FileSystemInfo)
            {
                return ((Alphaleonis.Win32.Filesystem.FileSystemInfo)baseObject).FullName;
            }

            return value;
        }
    }
}