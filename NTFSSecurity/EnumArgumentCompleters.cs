using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Security.AccessControl;
using Security2;

namespace NTFSSecurity
{
    // Completes the names of an enumeration for a parameter that is declared as object (Decision 27, fix B) and so
    // does not get the completion that a parameter of an enumeration type gets from PowerShell itself.
    internal static class EnumArgumentCompletion
    {
        /// <summary>
        /// Returns the names of the enumeration that start with the word the user already typed, compared without
        /// regard to case, in the order Enum.GetNames returns them.
        /// </summary>
        /// <param name="enumType">The enumeration to complete the names of.</param>
        /// <param name="wordToComplete">The word the user already typed; empty or null completes every name.</param>
        internal static IEnumerable<CompletionResult> Complete(Type enumType, string wordToComplete)
        {
            var word = wordToComplete ?? string.Empty;
            var results = new List<CompletionResult>();

            foreach (var name in Enum.GetNames(enumType))
            {
                if (name.StartsWith(word, StringComparison.OrdinalIgnoreCase))
                {
                    results.Add(new CompletionResult(name, name, CompletionResultType.ParameterValue, name));
                }
            }

            return results;
        }
    }

    /// <summary>Completes the names of System.Security.AccessControl.AccessControlType for -AccessType.</summary>
    public class AccessControlTypeArgumentCompleter : IArgumentCompleter
    {
        public IEnumerable<CompletionResult> CompleteArgument(
            string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
        {
            return EnumArgumentCompletion.Complete(typeof(AccessControlType), wordToComplete);
        }
    }

    /// <summary>Completes the names of System.Security.AccessControl.AuditFlags for -AuditFlags.</summary>
    public class AuditFlagsArgumentCompleter : IArgumentCompleter
    {
        public IEnumerable<CompletionResult> CompleteArgument(
            string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
        {
            return EnumArgumentCompletion.Complete(typeof(AuditFlags), wordToComplete);
        }
    }

    /// <summary>Completes the names of System.Security.AccessControl.InheritanceFlags for -InheritanceFlags.</summary>
    public class InheritanceFlagsArgumentCompleter : IArgumentCompleter
    {
        public IEnumerable<CompletionResult> CompleteArgument(
            string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
        {
            return EnumArgumentCompletion.Complete(typeof(InheritanceFlags), wordToComplete);
        }
    }

    /// <summary>Completes the names of System.Security.AccessControl.PropagationFlags for -PropagationFlags.</summary>
    public class PropagationFlagsArgumentCompleter : IArgumentCompleter
    {
        public IEnumerable<CompletionResult> CompleteArgument(
            string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
        {
            return EnumArgumentCompletion.Complete(typeof(PropagationFlags), wordToComplete);
        }
    }

    /// <summary>Completes the names of Security2.ApplyTo for -AppliesTo.</summary>
    public class ApplyToArgumentCompleter : IArgumentCompleter
    {
        public IEnumerable<CompletionResult> CompleteArgument(
            string commandName, string parameterName, string wordToComplete, CommandAst commandAst, IDictionary fakeBoundParameters)
        {
            return EnumArgumentCompletion.Complete(typeof(ApplyTo), wordToComplete);
        }
    }
}
