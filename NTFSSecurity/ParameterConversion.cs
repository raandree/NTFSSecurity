using System;
using System.Collections;
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
        /// an enumeration instance. An enumeration that is not a flags enumeration takes one value: PowerShell would
        /// add up the numbers of a list for it, which selects a value that the caller did not name, so a list is
        /// rejected for it.
        /// </summary>
        /// <param name="value">
        /// The raw value of the parameter. Not null: the caller keeps the default of the parameter for null instead
        /// of calling this method, because null means that the parameter was not specified.
        /// </param>
        /// <param name="parameterName">The name of the parameter, without the leading dash, for the message.</param>
        /// <returns>The converted value.</returns>
        /// <exception cref="ArgumentException">
        /// The value is blank (an empty or a white-space-only string, the usual blank CSV cell), is a list for an
        /// enumeration that is not a flags enumeration, or the conversion failed. The message names the value, unless
        /// it is blank, the parameter, and the valid names of T; the inner exception of a failed conversion is the
        /// error that LanguagePrimitives.ConvertTo raised.
        /// </exception>
        internal static T Convert<T>(object value, string parameterName)
        {
            var text = value as string;
            if (text != null && string.IsNullOrWhiteSpace(text))
            {
                throw new ArgumentException(string.Format(
                    "The value for parameter -{0} is blank. {1}", parameterName, DescribeValidValues(typeof(T))));
            }

            if (!typeof(T).IsDefined(typeof(FlagsAttribute), false))
            {
                var list = DescribeList(value);
                if (list != null)
                {
                    throw new ArgumentException(string.Format(
                        "The value '{0}' for parameter -{1} is not valid: the parameter takes one value, not a list. {2}",
                        list, parameterName, DescribeValidValues(typeof(T))));
                }
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

        /// <summary>
        /// Builds the message for a parameter whose value is explicitly null although it was bound on the command
        /// line (a literal $null, a variable that holds $null, or a null entry of $PSDefaultParameterValues): "The
        /// value for parameter -AccessType is null. Valid values: Allow, Deny." A piped property that is null is
        /// not an error there: it means the property was not specified and the parameter's own default applies;
        /// only the cmdlet knows, from MyInvocation.BoundParameters, whether a null came from such a named value.
        /// </summary>
        /// <param name="parameterName">The name of the parameter, without the leading dash, for the message.</param>
        internal static string DescribeNull<T>(string parameterName)
        {
            return string.Format("The value for parameter -{0} is null. {1}", parameterName, DescribeValidValues(typeof(T)));
        }

        // The text of a list that the conversion would add up, for the message: a string that holds a comma, or a
        // collection of more than one element (a wrapped PSObject counts as what it wraps). Null for any other value,
        // such as a single name or a collection of one element, which convert to that one value.
        private static string DescribeList(object value)
        {
            var unwrapped = value is PSObject ? ((PSObject)value).BaseObject : value;

            var text = unwrapped as string;
            if (text != null)
            {
                return text.IndexOf(',') >= 0 ? text : null;
            }

            var list = unwrapped as IList;
            if (list == null || list.Count < 2)
            {
                return null;
            }

            var items = new string[list.Count];
            for (var i = 0; i < items.Length; i++)
            {
                items[i] = string.Format("{0}", list[i]);
            }

            return string.Join(", ", items);
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
