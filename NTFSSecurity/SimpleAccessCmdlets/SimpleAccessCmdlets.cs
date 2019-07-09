using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Management.Automation;
using Security2;
using Alphaleonis.Win32.Filesystem;

namespace NTFSSecurity
{
    #region Get-SimpleAccess
    [Cmdlet(VerbsCommon.Get, "NTFSSimpleAccess")]
    [OutputType(typeof(Security2.SimpleFileSystemAccessRule))]
    public class GetSimpleAccess : GetAccess
    {
        private bool includeRootFolder = true;
        protected List<SimpleFileSystemAccessRule> aceList = new List<SimpleFileSystemAccessRule>();
        protected List<DirectoryInfo> directoryList = new List<DirectoryInfo>();

        [Parameter]
        public SwitchParameter IncludeRootFolder
        {
            get { return includeRootFolder; }
            set { includeRootFolder = value; }
        }

        Dictionary<string, IEnumerable<SimpleFileSystemAccessRule>> previousAcls = new Dictionary<string, IEnumerable<SimpleFileSystemAccessRule>>();
        DirectoryInfo item;
        FileSystemInfo previousItem;
        bool isFirstFolder = true;

        protected override void ProcessRecord()
        {
            //as this cmdlet retreives also the current working folder to show the permissions.
            if (includeRootFolder & isFirstFolder)
            {
                string rootPath = System.IO.Path.GetDirectoryName(paths[0]);

                if (!string.IsNullOrEmpty(rootPath))
                {
                    List<string> l = new List<string>();
                    l.Add(rootPath);
                    l.AddRange(paths);
                    paths = l;
                }
            }

            foreach (var p in paths)
            {
                try
                {
                    item = GetFileSystemInfo2(p) as DirectoryInfo;

                    if (item != null)
                    {
                        WriteVerbose(string.Format("New folder: {0}", item.FullName));
                        directoryList.Add(item);

                        var acl = FileSystemAccessRule2.GetFileSystemAccessRules(item, !ExcludeExplicit, !ExcludeInherited).Select(ace => ace.ToSimpleFileSystemAccessRule2());

                        try
                        {
                            previousItem = item.GetParent();
                        }
                        catch { }
                        IEnumerable<SimpleFileSystemAccessRule> previousAcl = null;

                        if (isFirstFolder)
                        {
                            previousAcls.Add(item.FullName, acl);
                            aceList.AddRange(acl);
                            acl.ForEach(ace => WriteObject(ace));

                            isFirstFolder = false;
                        }
                        else
                        {
                            if (previousAcls.ContainsKey(previousItem.FullName))
                            {
                                previousAcl = previousAcls[previousItem.FullName];
                                previousAcls.Add(item.FullName, acl);

                                List<SimpleFileSystemAccessRule> diffAcl = new List<SimpleFileSystemAccessRule>();

                                foreach (var ace in acl)
                                {
                                    var equalsUser = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity);
                                    var equalsUserAndAccessType = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity & prevAce.AccessControlType == ace.AccessControlType);
                                    var equalsRights = previousAcl.Where(prevAce => (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights);
                                    var totalEqual = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity & prevAce.AccessControlType == ace.AccessControlType & (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights);

                                    if (previousAcl.Where(prevAce =>
                                        prevAce.AccessControlType == ace.AccessControlType &
                                        (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights &
                                        prevAce.Identity == ace.Identity).Count() == 0)
                                    {
                                        diffAcl.Add(ace);
                                    }
                                }

                                aceList.AddRange(diffAcl);
                                diffAcl.ForEach(ace => WriteObject(ace));
                            }
                        }
                    }

                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "ReadError", ErrorCategory.OpenError, p));
                }
            }
        }
    }
    #endregion

    //#region Get-SimpleEffectiveAccess
    //[Cmdlet(VerbsCommon.Get, "SimpleEffectiveAccess")]
    //public class GetSimpleEffectiveAccess : GetEffectiveAccess
    //{
    //    private bool includeRootFolder = true;
    //    protected List<SimpleFileSystemAccessRule> aceList = new List<SimpleFileSystemAccessRule>();
    //    protected List<DirectoryInfo> directoryList = new List<DirectoryInfo>();

    //    [Parameter]
    //    public SwitchParameter IncludeRootFolder
    //    {
    //        get { return includeRootFolder; }
    //        set { includeRootFolder = value; }
    //    }

    //    Dictionary<string, IQueryable<SimpleFileSystemAccessRule>> previousAcls = new Dictionary<string, IQueryable<SimpleFileSystemAccessRule>>();
    //    DirectoryInfo item;
    //    FileSystemInfo previousItem;
    //    bool isFirstFolder = true;

    //    protected override void ProcessRecord()
    //    {
    //        //as this cmdlet retreives also the current working folder to show the permissions.
    //        if (includeRootFolder & isFirstFolder)
    //        {
    //            string rootPath = System.IO.Path.GetDirectoryName(path[0]);

    //            if (!string.IsNullOrEmpty(rootPath))
    //            {
    //                List<string> l = new List<string>();
    //                l.Add(rootPath);
    //                l.AddRange(path);
    //                path = l.ToArray<string>();
    //            }
    //        }

    //        foreach (var p in path)
    //        {
    //            try
    //            {
    //                item = this.GetFileSystemInfo(p) as DirectoryInfo;

    //                if (item != null)
    //                {
    //                    WriteVerbose(string.Format("New folder: {0}", item.FullName));
    //                    directoryList.Add(item);

    //                    //var acl = FileSystemAccessRule2.GetFileSystemAccessRules(item, true, true).Select(ace => ace.ToSimpleFileSystemAccessRule2());
    //                    var acl = (new List<SimpleFileSystemAccessRule>() { EffectivePermissions.GetEffectiveAccess(item, Account).ToSimpleFileSystemAccessRule2() }).AsQueryable();

    //                    try
    //                    {
    //                        previousItem = item.GetParent();
    //                    }
    //                    catch { }
    //                    IQueryable<SimpleFileSystemAccessRule> previousAcl = null;

    //                    if (isFirstFolder)
    //                    {
    //                        previousAcls.Add(item.FullName, acl);
    //                        aceList.AddRange(acl);
    //                        acl.ForEach(ace => WriteObject(ace));

    //                        isFirstFolder = false;
    //                    }
    //                    else
    //                    {
    //                        if (previousAcls.ContainsKey(previousItem.FullName))
    //                        {
    //                            previousAcl = previousAcls[previousItem.FullName];
    //                            previousAcls.Add(item.FullName, acl);

    //                            List<SimpleFileSystemAccessRule> diffAcl = new List<SimpleFileSystemAccessRule>();
                                
    //                            foreach (var ace in acl)
    //                            {
    //                                var equalsUser = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity);
    //                                var equalsUserAndAccessType = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity & prevAce.AccessControlType == ace.AccessControlType);
    //                                var equalsRights = previousAcl.Where(prevAce => (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights);
    //                                var totalEqual = previousAcl.Where(prevAce => prevAce.Identity == ace.Identity & prevAce.AccessControlType == ace.AccessControlType & (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights);

    //                                if (previousAcl.Where(prevAce =>
    //                                    prevAce.AccessControlType == ace.AccessControlType &
    //                                    (prevAce.AccessRights & ace.AccessRights) == ace.AccessRights &
    //                                    prevAce.Identity == ace.Identity).Count() == 0)
    //                                {
    //                                    diffAcl.Add(ace);
    //                                }
    //                            }

    //                            aceList.AddRange(diffAcl);
    //                            diffAcl.ForEach(ace => WriteObject(ace));
    //                        }
    //                    }
    //                }

    //            }
    //            catch (Exception ex)
    //            {
    //                this.WriteError(new ErrorRecord(ex, "ReadError", ErrorCategory.OpenError, p));
    //            }
    //        }
    //    }
    //}
    //#endregion

    
}