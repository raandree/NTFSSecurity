using Alphaleonis.Win32.Filesystem;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Text;

namespace Security2
{
    internal partial class Win32
    {
        public static List<string> GetInheritedFrom(string path, ObjectSecurity sd, bool isContainer)
        {
            var inheritedFrom = new List<string>();
            path = Path.GetLongPath(path);

            uint returnValue = 0;
            GENERIC_MAPPING genericMap = new GENERIC_MAPPING();
            genericMap.GenericRead = (uint)MappedGenericRights.FILE_GENERIC_READ;
            genericMap.GenericWrite = (uint)MappedGenericRights.FILE_GENERIC_WRITE;
            genericMap.GenericExecute = (uint)MappedGenericRights.FILE_GENERIC_EXECUTE;
            genericMap.GenericAll = (uint)MappedGenericRights.FILE_GENERIC_ALL;

            var sdBytes = sd.GetSecurityDescriptorBinaryForm();
            var commonSd = new CommonSecurityDescriptor(isContainer, false, sdBytes, 0);

            var aclBytes = new byte[commonSd.DiscretionaryAcl.BinaryLength];
            commonSd.DiscretionaryAcl.GetBinaryForm(aclBytes, 0);

            var pInheritInfo = Marshal.AllocHGlobal(commonSd.DiscretionaryAcl.Count * Marshal.SizeOf(typeof(PINHERITED_FROM)));

            returnValue = GetInheritanceSource(
                path,
                ResourceType.FileObject,
                SECURITY_INFORMATION.DACL_SECURITY_INFORMATION,
                isContainer,
                IntPtr.Zero,
                0,
                aclBytes,
                IntPtr.Zero,
                ref genericMap,
                pInheritInfo
                );

            if (returnValue != 0)
            {
                throw new System.ComponentModel.Win32Exception((int)returnValue);
            }

            for (int i = 0; i < commonSd.DiscretionaryAcl.Count; i++)
            {
                var inheritInfo = pInheritInfo.ElementAt<PINHERITED_FROM>(i);

                inheritedFrom.Add(
                    !string.IsNullOrEmpty(inheritInfo.AncestorName) && inheritInfo.AncestorName.StartsWith(@"\\?\") ? inheritInfo.AncestorName.Substring(4) : inheritInfo.AncestorName
                );
            }

            FreeInheritedFromArray(pInheritInfo, (ushort)commonSd.DiscretionaryAcl.Count, IntPtr.Zero);
            Marshal.FreeHGlobal(pInheritInfo);

            return inheritedFrom;
        }
    }
}
