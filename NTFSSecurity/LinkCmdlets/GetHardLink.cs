using Alphaleonis.Win32.Filesystem;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "NTFSHardLink")]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class GetHardLink : BaseCmdlet
    {
        System.Reflection.MethodInfo modeMethodInfo = null;

        [Parameter(Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [Alias("FullName")]
        public string[] Path
        {
            get { return paths.ToArray(); }
            set
            {
                paths.Clear();
                paths.AddRange(value);
            }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetVariableValue("PWD").ToString() };
            }

            modeMethodInfo = typeof(FileSystemCodeMembers).GetMethod("Mode");
        }

        protected override void ProcessRecord()
        {
            foreach (var path in paths)
            {
                try
                {
                    var root = System.IO.Path.GetPathRoot(GetRelativePath(path));

                    //access the path to make sure it exists and is a file
                    var item = GetFileSystemInfo2(path);

                    if (item is DirectoryInfo)
                        throw new ArgumentException("The item must be a file");

                    var links = File.EnumerateHardlinks(item.FullName);

                    foreach (var link in links)
                    {
                        var target = new PSObject(GetFileSystemInfo2(System.IO.Path.Combine(root, link.Substring(1))));
                        target.Properties.Add(new PSCodeProperty("Mode", modeMethodInfo));
                        WriteObject(target);
                    }
                }
                catch (System.IO.FileNotFoundException ex)
                {
                    WriteError(new ErrorRecord(ex, "FileNotFound", ErrorCategory.ObjectNotFound, path));
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
