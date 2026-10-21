using System;
using System.Management.Automation;

namespace NTFSSecurity
{
    /// <summary>
    /// Converts the raw value of a parameter that is declared as object back into the enumeration the parameter
    /// describes, the way the PowerShell binder converts an argument for a typed parameter. AccessType, AuditFlags,
    /// InheritanceFlags, PropagationFlags, and AppliesTo of the access and audit cmdlets are declared as object
    /// (Decision 27, fix B), so that the binder does not silently skip a piped property it cannot convert and keep
    /// the parameter at its default; this class gives the cmdlet the same conversion, with a message it can report
    /// as its own error instead of a binding error. This class writes nothing; the cmdlet writes the error.
    /// </summary>
    internal static class ParameterConversion
    {
        /// <summary>
        /// Converts the raw value of a parameter to T, the way the PowerShell binder converts an argument for a
        /// parameter of that type: names in any case, a comma-separated list for a flags enumeration, a number, or
        /// an enumeration instance.
        /// </summary>
        /// <param name="value">
        /// The raw value of the parameter. Not null: the caller keeps the default of the parameter for null instead
        /// of calling this method, because null means that the parameter was not specified.
        /// </param>
        /// <param name="parameterName">The name of the parameter, without the leading dash, for the message.</param>
        /// <returns>The converted value.</returns>
        /// <exception cref="ArgumentException">
        /// The value is blank (an empty or a white-space-only string, the usual blank CSV cell) or the conversion
        /// failed. The message names the value, unless it is blank, the parameter, and the valid names of T; the
        /// inner exception of a failed conversion is the error that LanguagePrimitives.ConvertTo raised.
        /// </exception>
        internal static T Convert<T>(object value, string parameterName)
        {
            var text = value as string;
            if (text != null && string.IsNullOrWhiteSpace(text))
            {
                throw new ArgumentException(string.Format(
                    "The value for parameter -{0} is blank. {1}", parameterName, DescribeValidValues(typeof(T))));
            }

            try
            {
                return (T)LanguagePrimitives.ConvertTo(value, typeof(T));
            }
            catch (Exception ex)
            {
                throw new ArgumentException(
                    string.Format("The value '{0}' for parameter -{1} is not valid. {2}", value, parameterName, DescribeValidValues(typeof(T))),
                    ex);
            }
        }

        // The valid names of the enumeration, in declaration order, with a note for a flags enumeration that a
        // combination of them is written separated with commas.
        private static string DescribeValidValues(Type enumType)
        {
            var names = string.Join(", ", Enum.GetNames(enumType));

            if (enumType.IsDefined(typeof(FlagsAttribute), false))
            {
                return string.Format("Valid values: {0}. Combine several with a comma.", names);
            }

            return string.Format("Valid values: {0}.", names);
        }
    }
}
