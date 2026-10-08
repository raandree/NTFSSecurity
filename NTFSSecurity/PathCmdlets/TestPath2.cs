using Alphaleonis.Win32.Filesystem;
using System.Collections.Generic;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsDiagnostic.Test, "Path2")]
    [OutputType(typeof(bool))]
    public class TestPath2 : BaseCmdlet
    {
        private TestPathType pathType = TestPathType.Any;

        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        [Alias("FullName")]
        [FileSystemPathTransformation]
        public string[] Path
        {
            get { return paths.ToArray(); }
            set
            {
                paths.Clear();
                paths.AddRange(value);
            }
        }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public TestPathType PathType
        {
            get { return pathType; }
            set { pathType = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            if (paths.Count == 0)
            {
                paths = new List<string>() { GetCurrentLocation() };
            }
        }

        protected override void ProcessRecord()
        {
            foreach (var path in paths)
            {
                try
                {
                    FileSystemInfo item;
                    TryGetFileSystemInfo2(path, out item);

                    if (item == null)
                        WriteObject(false);
                    else
                    {
                        if (PathType == TestPathType.Any)
                            WriteObject(true);
                        else if (PathType == TestPathType.Container & item is DirectoryInfo)
                            WriteObject(true);
                        else if (PathType == TestPathType.Leaf & item is FileInfo)
                            WriteObject(true);
                        else
                            WriteObject(false);
                    }
                }
                catch (System.IO.FileNotFoundException ex)
                {
                    WriteError(new ErrorRecord(ex, "PathNotFound", ErrorCategory.ObjectNotFound, path));
                }
                // In Windows PowerShell, .NET rejects a path with a character that Windows doesn't allow in names.
                // Such an item can't exist, so the cmdlet writes $false, as in PowerShell 7 and like Test-Path.
                catch (System.ArgumentException)
                {
                    WriteObject(false);
                }
                catch (System.NotSupportedException)
                {
                    WriteObject(false);
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }

    public enum TestPathType
    {
        Any,
        Container,
        Leaf
    }
}