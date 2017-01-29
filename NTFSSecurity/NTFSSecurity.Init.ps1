#region Internals
#region C# Code
$type_NTFS1 = @' 
	using System;
	using System.IO;
	using System.Collections;
	using System.Runtime.InteropServices;
	using Microsoft.Win32.SafeHandles;
	
	namespace NTFS
	{
		public class DriveInfoExt
		{
			[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
			static extern bool GetDiskFreeSpace(string lpRootPathName,
				out uint lpSectorsPerCluster,
				out uint lpBytesPerSector,
				out uint lpNumberOfFreeClusters,
				out uint lpTotalNumberOfClusters);
	
			DriveInfo _drive = null;
			uint _sectorsPerCluster = 0;
			uint _bytesPerSector = 0;
			uint _numberOfFreeClusters = 0;
			uint _totalNumberOfClusters = 0;
	
			public uint SectorsPerCluster { get { return _sectorsPerCluster; } }
			public uint BytesPerSector { get { return _bytesPerSector; } }
			public uint NumberOfFreeClusters { get { return _numberOfFreeClusters; } }
			public uint TotalNumberOfClusters { get { return _totalNumberOfClusters; } }
			public DriveInfo Drive { get { return _drive; } }
			public string DriveName { get { return _drive.Name; } }
			public string VolumeName { get { return _drive.VolumeLabel; } }
	
			public DriveInfoExt(string DriveName)
			{
				_drive = new DriveInfo(DriveName);
	
				GetDiskFreeSpace(_drive.Name,
					out _sectorsPerCluster,
					out _bytesPerSector,
					out _numberOfFreeClusters,
					out _totalNumberOfClusters);
			}
		}
			
		public class FileInfoExt
		{
			[DllImport("kernel32.dll", SetLastError = true, EntryPoint = "GetCompressedFileSize")]
			static extern uint GetCompressedFileSize(string lpFileName, out uint lpFileSizeHigh);
	
			public static ulong GetCompressedFileSize(string filename)
			{
				uint high;
				uint low;
				low = GetCompressedFileSize(filename, out high);
				int error = Marshal.GetLastWin32Error();
	
				if (high == 0 && low == 0xFFFFFFFF && error != 0)
				{
					throw new System.ComponentModel.Win32Exception(error);
				}
				else
				{
					return ((ulong)high << 32) + low;
				}
			}
		}
	}
'@
#endregion
#endregion

Add-Type -TypeDefinition $type_NTFS1
Add-Type -Path $PSScriptRoot\Security2.dll
Add-Type -Path $PSScriptRoot\PrivilegeControl.dll -ReferencedAssemblies $PSScriptRoot\ProcessPrivileges.dll
Add-Type -Path $PSScriptRoot\ProcessPrivileges.dll

#using Update-FormatData and not FormatsToProcess in the PSD1 as FormatsToProcess does not offer
#putting format data in front of the default data. This is required to make the new formatter the default ones.
Update-FormatData -PrependPath $PSScriptRoot\NTFSSecurity.format.ps1xml