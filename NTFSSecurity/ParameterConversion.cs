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
        /// an enumeration instance. An enumeration that is not a flags enumeration takes one value: PowerShell
        /// combines the numbers of a list for it bit by bit, so that one of the values wins silently or a value that
        /// the caller did not name is chosen, so a list is rejected for it, in whatever kind of collection it comes.
        /// A collection of one element converts as that element.
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
            var convertible = value;

            if (!typeof(T).IsDefined(typeof(FlagsAttribute), false))
            {
                bool isList;
                convertible = TakeOneValue(value, out isList);
                if (isList)
                {
                    throw new ArgumentException(string.Format(
                        "The value '{0}' for parameter -{1} is not valid: the parameter takes one value, not a list. {2}",
                        Describe(value), parameterName, DescribeValidValues(typeof(T))));
                }
            }

            var text = convertible as string;
            if (text != null && string.IsNullOrWhiteSpace(text))
            {
                throw new ArgumentException(string.Format(
                    "The value for parameter -{0} is blank. {1}", parameterName, DescribeValidValues(typeof(T))));
            }

            try
            {
                return (T)LanguagePrimitives.ConvertTo(convertible, typeof(T));
            }
            catch (Exception ex)
            {
                throw new ArgumentException(
                    string.Format("The value '{0}' for parameter -{1} is not valid. {2}", Describe(value), parameterName, DescribeValidValues(typeof(T))),
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

        // The most levels of nested collections that the conversion looks into, counting the argument itself: a value
        // that is wrapped in more of them counts as a list. Enough for any real argument, and a stop for a collection
        // that holds itself.
        private const int MaxNesting = 32;

        // The one value that the conversion takes from the argument of an enumeration that is not a flags enumeration:
        // the argument itself, or the only element of a collection of any kind (a wrapped PSObject counts as what it
        // wraps, and a collection that holds a collection is opened too). isList is true when the argument holds more
        // than one value: a string that holds a comma, a collection of several elements (two are enough to know, so
        // a long or endless sequence is not read to its end), a collection of one element that holds such a list, or
        // collections nested deeper than MaxNesting; the returned value is then not used. A dictionary, an empty
        // collection, or a collection that cannot be enumerated is returned as it is, for the conversion to reject or
        // convert with its own error.
        private static object TakeOneValue(object value, out bool isList)
        {
            isList = false;
            var current = value;

            for (var depth = 0; depth < MaxNesting; depth++)
            {
                var unwrapped = current is PSObject ? ((PSObject)current).BaseObject : current;

                var text = unwrapped as string;
                if (text != null)
                {
                    isList = text.IndexOf(',') >= 0;
                    return unwrapped;
                }

                var collection = unwrapped as IEnumerable;
                if (collection == null || unwrapped is IDictionary)
                {
                    return unwrapped;
                }

                var count = 0;
                object only = null;
                try
                {
                    foreach (var item in collection)
                    {
                        count++;
                        if (count > 1)
                        {
                            break;
                        }

                        only = item;
                    }
                }
                catch (Exception)
                {
                    return value;
                }

                if (count == 1)
                {
                    current = only;
                    continue;
                }

                isList = count > 1;
                return value;
            }

            isList = true;
            return value;
        }

        // The value as a message names it: a collection of one element by that element (also when it is a collection
        // itself), a collection of several elements by its first ten, anything else by its text. The message is built
        // inside a catch block, so this method must not fail whatever the text or the enumeration of a value does; a
        // value that cannot be formatted is named by its type.
        private static string Describe(object value)
        {
            try
            {
                return DescribeValue(value);
            }
            catch (Exception)
            {
                var unwrapped = value is PSObject ? ((PSObject)value).BaseObject : value;
                return unwrapped == null ? string.Empty : unwrapped.GetType().FullName;
            }
        }

        private static string DescribeValue(object value)
        {
            var current = value;

            for (var depth = 0; depth < MaxNesting; depth++)
            {
                var unwrapped = current is PSObject ? ((PSObject)current).BaseObject : current;
                var collection = unwrapped as IEnumerable;

                if (unwrapped is string || collection == null || unwrapped is IDictionary)
                {
                    return string.Format("{0}", current);
                }

                var shown = new System.Collections.Generic.List<object>();
                var more = false;
                foreach (var item in collection)
                {
                    if (shown.Count == 10)
                    {
                        more = true;
                        break;
                    }

                    shown.Add(item);
                }

                if (shown.Count == 1 && !more)
                {
                    current = shown[0];
                    continue;
                }

                if (shown.Count == 0)
                {
                    return string.Format("{0}", current);
                }

                return string.Join(", ", shown.ConvertAll(item => string.Format("{0}", item))) + (more ? ", ..." : string.Empty);
            }

            return string.Format("{0}", value);
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
