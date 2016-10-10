using Alphaleonis.Win32.Filesystem;
using System.Management.Automation;

namespace NTFSSecurity
{
    public class FileSystemCodeMembers
    {
        public static string Mode(PSObject obj)
        {
            if (obj == null)
            {
                return string.Empty;
            }
            FileSystemInfo item = (FileSystemInfo)obj.BaseObject;
            if (item == null)
            {
                return string.Empty;
            }

            string text = "";
            if ((item.Attributes & System.IO.FileAttributes.Directory) == System.IO.FileAttributes.Directory)
            {
                text += "d";
            }
            else
            {
                text += "-";
            }
            if ((item.Attributes & System.IO.FileAttributes.Archive) == System.IO.FileAttributes.Archive)
            {
                text += "a";
            }
            else
            {
                text += "-";
            }
            if ((item.Attributes & System.IO.FileAttributes.ReadOnly) == System.IO.FileAttributes.ReadOnly)
            {
                text += "r";
            }
            else
            {
                text += "-";
            }
            if ((item.Attributes & System.IO.FileAttributes.Hidden) == System.IO.FileAttributes.Hidden)
            {
                text += "h";
            }
            else
            {
                text += "-";
            }
            if ((item.Attributes & System.IO.FileAttributes.System) == System.IO.FileAttributes.System)
            {
                text += "s";
            }
            else
            {
                text += "-";
            }
            return text;
        }
    }
}
