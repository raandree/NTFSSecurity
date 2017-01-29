using System.Security.AccessControl;

namespace Security2
{
    public class FileSystemFlags
    {
        public InheritanceFlags InheritanceFlags { get; set; }
        public PropagationFlags PropagationFlags { get; set; }
    }
}
