using Alphaleonis.Win32.Filesystem;
using System.Linq;
using System.Management.Automation;

namespace NTFSSecurity
{
    [Cmdlet(VerbsCommon.Get, "DiskSpace")]
    [OutputType(typeof(DiskSpaceInfo))]
    public class GetDiskSpace : PSCmdlet
    {
        private string[] driveLetter;

        [Parameter(Position = 1)]
        [ValidatePattern("^[A-Za-z]:$")]
        public string[] DriveLetter
        {
            get { return driveLetter; }
            set { driveLetter = value; }
        }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            var volumes = Alphaleonis.Win32.Filesystem.Volume.EnumerateVolumes();

            if (driveLetter == null)
            {
                driveLetter = volumes.ToArray();
            }

            foreach (var letter in driveLetter)
            {
                var diskSpaceInfo = new DiskSpaceInfo(letter);
                try
                {
                    diskSpaceInfo.Refresh();
                    if (diskSpaceInfo.TotalNumberOfBytes > 0)
                    {
                        this.WriteObject(diskSpaceInfo);
                    }
                }
                catch
                {
                    this.WriteWarning(string.Format("Could not get drive details for '{0}'", letter));
                }
            }
        }

        protected override void EndProcessing()
        {
            base.EndProcessing();
        }
    }
}
