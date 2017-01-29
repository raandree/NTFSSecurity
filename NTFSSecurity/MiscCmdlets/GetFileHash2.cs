using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;
using Security2.FileSystem.FileInfo;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "FileHash2")]
    [OutputType(typeof(FileSystemAccessRule2))]
    public class GetFileHash2 : BaseCmdlet
    {
        private HashAlgorithms algorithm = HashAlgorithms.SHA256;

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
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

        [Parameter(Position = 2, ValueFromPipelineByPropertyName = true)]
        public HashAlgorithms Algorithm
        {
            get { return algorithm; }
            set { algorithm = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            string hash = string.Empty;
            FileSystemInfo item = null;

            foreach (var path in paths)
            {
                try
                {
                    item = GetFileSystemInfo2(path) as FileInfo;
                    if (item == null)
                        return;
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "ReadFileError", ErrorCategory.OpenError, path));
                    continue;
                }

                try
                {
                    hash = ((FileInfo)item).GetHash(algorithm);
                }
                catch (UnauthorizedAccessException)
                {
                    try
                    {
                        var ownerInfo = FileSystemOwner.GetOwner(item);
                        var previousOwner = ownerInfo.Owner;

                        FileSystemOwner.SetOwner(item, System.Security.Principal.WindowsIdentity.GetCurrent().User);

                        hash = ((FileInfo)item).GetHash(algorithm);

                        FileSystemOwner.SetOwner(item, previousOwner);
                    }
                    catch (Exception ex2)
                    {
                        WriteError(new ErrorRecord(ex2, "GetHashError", ErrorCategory.WriteError, path));
                    }
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "GetHashError", ErrorCategory.WriteError, path));
                }

                var result = new PSObject(item);
                result.Properties.Add(new PSNoteProperty("Hash", hash));
                result.Properties.Add(new PSNoteProperty("Algorithm", algorithm.ToString()));
                result.TypeNames.Insert(0, "Alphaleonis.Win32.Filesystem.FileInfo+Hash");
                WriteObject(result);
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}