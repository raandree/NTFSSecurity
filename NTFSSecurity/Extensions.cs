using System;
using System.Collections.Generic;
using Alphaleonis.Win32.Filesystem;

namespace NTFSSecurity
{
    public static class Extensions
    {
        public static void ForEach<T>(this IEnumerable<T> source, Action<T> action)
        {
            if (source == null) { throw new ArgumentException(); }
            if (action == null) { throw new ArgumentException(); }

            foreach (T element in source)
            {
                action(element);
            }
        }

        public static FileSystemInfo GetParent(this FileSystemInfo item)
        {
            var parentPath = System.IO.Path.GetDirectoryName(item.FullName);

            if (File.Exists(parentPath))
            {
                return new FileInfo(parentPath);
            }
            else if (Directory.Exists(parentPath))
            {
                return new DirectoryInfo(parentPath);
            }
            else
            {
                throw new System.IO.FileNotFoundException();
            }
        }

        public static System.IO.FileSystemInfo GetParent(this System.IO.FileSystemInfo item)
        {
            var parentPath = System.IO.Path.GetDirectoryName(item.FullName);

            if (File.Exists(parentPath))
            {
                return new System.IO.FileInfo(parentPath);
            }
            else if (Directory.Exists(parentPath))
            {
                return new System.IO.DirectoryInfo(parentPath);
            }
            else
            {
                throw new System.IO.FileNotFoundException();
            }
        }
    }   
}