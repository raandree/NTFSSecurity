using Alphaleonis.Win32.Filesystem;
using Security2;
using System;
using System.Management.Automation;
using Security2.FileSystem.FileInfo;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "FileHash2")]
    [OutputType(typeof(FileInfo))]
    public class GetFileHash2 : BaseCmdlet
    {
        private HashAlgorithms algorithm = HashAlgorithms.SHA256;
        private bool deprecationWarningWritten = false;

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true)]
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
            try
            {
                Security2.FileSystem.FileInfo.Extensions.CreateHashAlgorithm(algorithm).Dispose();
            }
            catch (PlatformNotSupportedException ex)
            {
                ThrowTerminatingError(new ErrorRecord(ex, "HashAlgorithmNotAvailable", ErrorCategory.NotImplemented, algorithm));
            }
            catch (Exception ex)
            {
                // For example, an algorithm that a FIPS policy doesn't allow.
                ThrowTerminatingError(new ErrorRecord(ex, "HashAlgorithmNotAvailable", ErrorCategory.NotImplemented, algorithm));
            }

            if (algorithm == HashAlgorithms.MACTripleDES && !deprecationWarningWritten)
            {
                WriteWarning("The MACTripleDES algorithm uses a random key, so its result differs on every call. The value is deprecated and will be removed in a future version.");
                deprecationWarningWritten = true;
            }

            foreach (var path in paths)
            {
                string hash = null;
                FileSystemInfo item = null;

                try
                {
                    item = GetFileSystemInfo2(path) as FileInfo;
                    if (item == null)
                    {
                        // Like Get-FileHash, skip folders and continue with the next path.
                        WriteVerbose(string.Format("Skipping '{0}', which is a folder", path));
                        continue;
                    }
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
                        InvokeAsOwner(item, path, () =>
                        {
                            hash = ((FileInfo)item).GetHash(algorithm);
                        });
                    }
                    catch (Exception ex2)
                    {
                        WriteError(new ErrorRecord(ex2, "GetHashError", ErrorCategory.WriteError, path));
                        continue;
                    }
                }
                catch (Exception ex)
                {
                    WriteError(new ErrorRecord(ex, "GetHashError", ErrorCategory.WriteError, path));
                    continue;
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