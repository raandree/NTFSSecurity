using System;

namespace Security2
{
    enum SECURITY_INFORMATION
    {
        OWNER_SECURITY_INFORMATION = 1,
        GROUP_SECURITY_INFORMATION = 2,
        DACL_SECURITY_INFORMATION = 4,
        SACL_SECURITY_INFORMATION = 8,
    }

    internal enum AuthzRpcClientVersion : ushort // USHORT
    {
        V1 = 1
    }

    [Flags]
    internal enum AuthzResourceManagerFlags : uint
    {
        NO_AUDIT = 0x1,
    }

    [Flags]
    internal enum StdAccess : uint
    {
        None = 0x0,

        SYNCHRONIZE = 0x100000,
        STANDARD_RIGHTS_REQUIRED = 0xF0000,

        MAXIMUM_ALLOWED = 0x2000000,
    }

    [Flags]
    internal enum AuthzInitFlags : uint
    {
        Default = 0x0,
        SkipTokenGroups = 0x2,
        RequireS4ULogon = 0x4,
        ComputePrivileges = 0x8,
    }

    internal enum AuthzACFlags : uint // DWORD
    {
        None = 0,
        NoDeepCopySD
    }

    [Flags]
    internal enum SecurityInformationClass : uint
    {
        Owner = 0x00001,
        Group = 0x00002,
        Dacl = 0x00004,
        Sacl = 0x00008,
        Label = 0x00010,
        Attribute = 0x00020,
        Scope = 0x00040
    }

    internal enum ObjectType : uint
    {
        File = 1,
    }

    [Flags]
    internal enum FileAccess : uint
    {
        None = 0x0,
        ReadData = 0x1,
        WriteData = 0x2,
        AppendData = 0x4,
        ReadExAttrib = 0x8,
        WriteExAttrib = 0x10,
        Execute = 0x20,
        DeleteChild = 0x40,
        ReadAttrib = 0x80,
        WriteAttrib = 0x100,

        Delete = 0x10000,   // DELETE,
        ReadPermissions = 0x20000,   // READ_CONTROL
        ChangePermissions = 0x40000,   // WRITE_DAC,
        TakeOwnership = 0x80000,   // WRITE_OWNER,

        GenericRead = ReadPermissions
                    | ReadData
                    | ReadAttrib
                    | ReadExAttrib
                    | StdAccess.SYNCHRONIZE,

        GenericAll = (StdAccess.STANDARD_RIGHTS_REQUIRED | 0x1FF),

        CategoricalAll = uint.MaxValue
    }

    [Flags]
    internal enum FileShare : uint
    {
        None = 0x0,
        Read = 0x1,
        Write = 0x2,
        Delete = 0x4
    }

    internal enum FileMode : uint
    {
        OpenExisting = 3,
    }

    [Flags]
    internal enum FileFlagAttrib : uint
    {
        BackupSemantics = 0x02000000,
    }
}
