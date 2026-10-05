using System;
using System.Security.Cryptography;
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

            using (var hashAlgorithm = CreateHashAlgorithm(algorithm))
            using (var fileStream = file.OpenRead())
            {
                hash = hashAlgorithm.ComputeHash(fileStream);
            }

            var sb = new StringBuilder(hash.Length * 2);
            for (var i = 0; i < hash.Length; i++)
            {
                sb.Append(hash[i].ToString("X2"));
            }

            return sb.ToString();
        }

        /// <summary>
        /// Creates the hash algorithm. Throws a PlatformNotSupportedException that names the algorithm when the
        /// .NET runtime lacks it, as .NET Core and later lack RIPEMD160 and MACTripleDES.
        /// </summary>
        /// <param name="algorithm">The hash algorithm to create.</param>
        /// <returns>A new instance of the hash algorithm.</returns>
        public static HashAlgorithm CreateHashAlgorithm(HashAlgorithms algorithm)
        {
            switch (algorithm)
            {
                case HashAlgorithms.MD5:
                    return MD5.Create();
                case HashAlgorithms.SHA1:
                    return SHA1.Create();
                case HashAlgorithms.SHA256:
                    return SHA256.Create();
                case HashAlgorithms.SHA384:
                    return SHA384.Create();
                case HashAlgorithms.SHA512:
                    return SHA512.Create();
                case HashAlgorithms.MACTripleDES:
                case HashAlgorithms.RIPEMD160:
                    // Created by name: a reference to the type would make every hash fail where the type is missing.
                    var hashAlgorithm = CryptoConfig.CreateFromName(algorithm.ToString()) as HashAlgorithm;
                    if (hashAlgorithm == null)
                    {
                        throw new PlatformNotSupportedException(string.Format(
                            "The hash algorithm '{0}' is not available in this version of .NET. Use Windows PowerShell 5.1 to calculate it.",
                            algorithm));
                    }

                    return hashAlgorithm;
                default:
                    throw new ArgumentOutOfRangeException("algorithm", algorithm, "Unknown hash algorithm.");
            }
        }
    }
}