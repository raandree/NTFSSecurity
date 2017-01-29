using System;
using System.Security.AccessControl;

namespace Security2
{
    public enum ApplyTo
    {
        ThisFolderOnly, //InheritanceFlags None / PropagationFlags None

        ThisFolderSubfoldersAndFiles, //InheritanceFlags ContainerInherit, ObjectInherit / PropagationFlags None
        ThisFolderAndSubfolders, //InheritanceFlags ContainerInherit / PropagationFlags None
        ThisFolderAndFiles, //InheritanceFlags ObjectInherit / PropagationFlags None
        SubfoldersAndFilesOnly, //InheritanceFlags ContainerInherit, ObjectInherit / PropagationFlags InheritOnly
        SubfoldersOnly, //InheritanceFlags ContainerInherit / PropagationFlags InheritOnly
        FilesOnly, //InheritanceFlags ObjectInherit / PropagationFlags InheritOnly

        ThisFolderSubfoldersAndFilesOneLevel, //InheritanceFlags ContainerInherit, ObjectInherit / PropagationFlags NoPropagateInherit
        ThisFolderAndSubfoldersOneLevel, //InheritanceFlags ContainerInherit / PropagationFlags NoPropagateInherit
        ThisFolderAndFilesOneLevel, //InheritanceFlags ObjectInherit / PropagationFlags NoPropagateInherit
        SubfoldersAndFilesOnlyOneLevel, //InheritanceFlags ContainerInherit, ObjectInherit / PropagationFlags InheritOnly, NoPropagateInherit
        SubfoldersOnlyOneLevel, //InheritanceFlags ContainerInherit / PropagationFlags InheritOnly, NoPropagateInherit
        FilesOnlyOneLevel, //InheritanceFlags ObjectInherit / PropagationFlags InheritOnly, NoPropagateInherit
    }

    [Flags]
    public enum FileSystemRights2 : uint
    {
        None = 0,
        ListDirectory = 1,
        ReadData = 1,
        WriteData = 2,
        CreateFiles = 2,
        CreateDirectories = 4,
        AppendData = 4,
        ReadExtendedAttributes = 8,
        WriteExtendedAttributes = 16,
        ExecuteFile = 32,
        Traverse = 32,
        DeleteSubdirectoriesAndFiles = 64,
        ReadAttributes = 128,
        WriteAttributes = 256,
        Write = 278,
        Delete = 65536,
        ReadPermissions = 131072,
        Read = 131209,
        ReadAndExecute = 131241,
        Modify = 197055,
        ChangePermissions = 262144,
        TakeOwnership = 524288,
        Synchronize = 1048576,
        FullControl = 2032127,
        GenericRead = 0x80000000,
        GenericWrite = 0x40000000,
        GenericExecute = 0x20000000,
        GenericAll = 0x10000000
    }

    [Flags]
    public enum SimpleFileSystemAccessRights
    {
        None = 0,
        Read = 1,
        Write = 2,
        Delete = 4
    }

    public enum GenericRights : uint
    {
        GENERIC_READ = 0x80000000,
        GENERIC_WRITE = 0x40000000,
        GENERIC_EXECUTE = 0x20000000,
        GENERIC_ALL = 0x10000000
    }

    public enum MappedGenericRights : uint
    {
        FILE_GENERIC_EXECUTE = FileSystemRights.ExecuteFile | FileSystemRights.ReadPermissions | FileSystemRights.ReadAttributes | FileSystemRights.Synchronize,
        FILE_GENERIC_READ = FileSystemRights.ReadAttributes | FileSystemRights.ReadData | FileSystemRights.ReadExtendedAttributes | FileSystemRights.ReadPermissions | FileSystemRights.Synchronize,
        FILE_GENERIC_WRITE = FileSystemRights.AppendData | FileSystemRights.WriteAttributes | FileSystemRights.WriteData | FileSystemRights.WriteExtendedAttributes | FileSystemRights.ReadPermissions | FileSystemRights.Synchronize,
        FILE_GENERIC_ALL = FileSystemRights.FullControl
    }
}