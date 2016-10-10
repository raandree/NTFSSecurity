using System.Text;

namespace Security2.FileSystem.FileInfo
{
    public enum HashAlgorithms
    {
        SHA1,
        SHA256,
        SHA384,
        SHA512,
        MACTripleDES,
        MD5,
        RIPEMD160
    }

    public static class Extensions
    {
        
        public static string GetHash(this Alphaleonis.Win32.Filesystem.FileInfo file, HashAlgorithms algorithm)
        {
            byte[] hash = null;

            using (var fileStream = file.OpenRead())
            {
                switch (algorithm)
                {
                    case HashAlgorithms.MD5:
                        hash = System.Security.Cryptography.MD5.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.SHA1:
                        hash = System.Security.Cryptography.SHA1.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.SHA256:
                        hash = System.Security.Cryptography.SHA256.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.SHA384:
                        hash = System.Security.Cryptography.SHA384.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.SHA512:
                        hash = System.Security.Cryptography.SHA512.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.MACTripleDES:
                        hash = System.Security.Cryptography.MACTripleDES.Create().ComputeHash(fileStream);
                        break;
                    case HashAlgorithms.RIPEMD160:
                        hash = System.Security.Cryptography.RIPEMD160.Create().ComputeHash(fileStream);
                        break;
                }

                fileStream.Close();
            }

            var sb = new StringBuilder(hash.Length);
            for (var i = 0; i < hash.Length; i++)
            {
                sb.Append(hash[i].ToString("X2"));
            }
            
            return sb.ToString();
        }
    }
}