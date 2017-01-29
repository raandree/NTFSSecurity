using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "Item2")]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public class GetItem2 : BaseCmdlet
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
                    var item = new PSObject(GetFileSystemInfo2(path));
                    item.Properties.Add(new PSCodeProperty("Mode", modeMethodInfo));

                    WriteObject(item);
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
