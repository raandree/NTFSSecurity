using System;
using System.Security.AccessControl;
using ProcessPrivileges;
using System.Diagnostics;

namespace Security2
{
    public class AdjustPriviledgeException : Exception
    {
        public AdjustPriviledgeException(string message)
            : base(message)
        { }
    }

    public class PrivilegeControl
    {
        private Process p;

        public PrivilegeControl()
        {
            p = Process.GetCurrentProcess();
        }

        public PrivilegeAndAttributesCollection GetPrivileges()
        {
            return p.GetPrivileges();
        }

        public AdjustPrivilegeResult EnablePrivilege(Privilege privilege)
        {
            if (p.GetPrivilegeState(privilege) == PrivilegeState.Disabled)
            {
                AdjustPrivilegeResult result = p.EnablePrivilege(privilege);
                return result;
            }
            else if (p.GetPrivilegeState(privilege) == PrivilegeState.Removed)
            {
                throw new PrivilegeNotHeldException(privilege.ToString());
            }
            else if (p.GetPrivilegeState(privilege) == PrivilegeState.Enabled)
            {
                throw new AdjustPriviledgeException("Priviledge already enabled");
            }
            else
            {
                throw new AdjustPriviledgeException("Unknown Error");
            }
        }

        public AdjustPrivilegeResult DisablePrivilege(Privilege privilege)
        {
            if (p.GetPrivilegeState(privilege) == PrivilegeState.Enabled)
            {
                AdjustPrivilegeResult result = p.DisablePrivilege(privilege);
                return result;
            }
            else if (p.GetPrivilegeState(privilege) == PrivilegeState.Removed)
            {
                throw new PrivilegeNotHeldException(privilege.ToString());
            }
            else if (p.GetPrivilegeState(privilege) == PrivilegeState.Disabled)
            {
                throw new AdjustPriviledgeException("Priviledge already disabled");
            }
            else
            {
                throw new AdjustPriviledgeException("Unknown Error");
            }
        }
    }
}
