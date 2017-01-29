using System;
using System.Diagnostics;

namespace Log
{
    #region Log

    namespace Log
    {
        public class ParameterCountMismatchArgumentCountException : Exception
        {
            public ParameterCountMismatchArgumentCountException()
                : base() { }

            public ParameterCountMismatchArgumentCountException(string message)
                : base(message)
            { }
        }

        public class Log : Microsoft.VisualBasic.Logging.Log, IDisposable
        {
            public Log()
                : base()
            {
                if (!string.IsNullOrEmpty(System.Configuration.ConfigurationManager.AppSettings["LogPath"]))
                {
                    string LogPath = System.Configuration.ConfigurationManager.AppSettings["LogPath"];
                    string LogName = System.Reflection.Assembly.GetCallingAssembly().GetName().Name;
                    DefaultFileLogWriter.CustomLocation = System.IO.Path.GetDirectoryName(LogPath);
                    DefaultFileLogWriter.BaseFileName = LogName;
                    DefaultFileLogWriter.Location = Microsoft.VisualBasic.Logging.LogFileLocation.Custom;
                    DefaultFileLogWriter.CustomLocation = LogPath;
                }
                else if (System.Reflection.Assembly.GetEntryAssembly() != null)
                {
                    DefaultFileLogWriter.Location = Microsoft.VisualBasic.Logging.LogFileLocation.ExecutableDirectory;
                }

                DefaultFileLogWriter.Append = true;
                DefaultFileLogWriter.AutoFlush = true;
                DefaultFileLogWriter.Delimiter = ";";
                DefaultFileLogWriter.MaxFileSize = 2621440000; //2500 MB
                DefaultFileLogWriter.ReserveDiskSpace = 1048576000; //1000 MB
                DefaultFileLogWriter.LogFileCreationSchedule = Microsoft.VisualBasic.Logging.LogFileCreationScheduleOption.Daily;
                if (System.Configuration.ConfigurationManager.AppSettings["Debug"] == "true")
                    TraceSource.Switch.Level = SourceLevels.All;
                else
                    TraceSource.Switch.Level = SourceLevels.Information;

                WriteEntry("Starting log...");
                WriteEntry("Log instance created");
            }

            public Log(string name)
                : this()
            {
                DefaultFileLogWriter.BaseFileName = name;
            }

            public Log(string name, string logPath, SourceLevels level)
                : this()
            {
                DefaultFileLogWriter.CustomLocation = System.IO.Path.GetDirectoryName(logPath);
                DefaultFileLogWriter.BaseFileName = name;
                DefaultFileLogWriter.Location = Microsoft.VisualBasic.Logging.LogFileLocation.Custom;
                DefaultFileLogWriter.CustomLocation = logPath;
                DefaultFileLogWriter.Append = true;
                DefaultFileLogWriter.AutoFlush = true;
                DefaultFileLogWriter.Delimiter = ";";
                DefaultFileLogWriter.MaxFileSize = 2621440000; //2500 MB
                DefaultFileLogWriter.ReserveDiskSpace = 1048576000; //1000 MB
                DefaultFileLogWriter.LogFileCreationSchedule = Microsoft.VisualBasic.Logging.LogFileCreationScheduleOption.Daily;
                TraceSource.Switch.Level = level;

                WriteEntry("Starting log...");
                WriteEntry("Log instance created");
            }

            public void Dispose()
            {
                WriteEntry("Log Class gets disposed.");
                WriteEntry("Closing log...");
                DefaultFileLogWriter.Close();
            }

            public void WriteFunctionEntry()
            {
                string message = string.Empty;

                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format("{0} : {1}(", callingClass, callingMethod);

                System.Reflection.ParameterInfo[] parameterInfos = new StackFrame(1, true).GetMethod().GetParameters();
                foreach (System.Reflection.ParameterInfo parameterInfo in parameterInfos)
                {
                    message += parameterInfo.ParameterType.Name + " " + parameterInfo.Name + ", ";
                }

                //remove the "," at the end of the line
                if (message.EndsWith(", ")) { message = message.Substring(0, message.Length - 2); }

                message += ") : entering...";

                WriteEntry(message, TraceEventType.Verbose);
            }

            public void WriteFunctionEntry(params object[] args)
            {
                string message = string.Empty;

                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format("{0} : {1}(", callingClass, callingMethod);

                System.Reflection.ParameterInfo[] parameterInfos = new StackFrame(1, true).GetMethod().GetParameters();
                if (parameterInfos.Length != args.Length)
                {
                    throw new ParameterCountMismatchArgumentCountException();
                }

                int parameterIterator = 0;
                foreach (System.Reflection.ParameterInfo parameterInfo in parameterInfos)
                {
                    message += parameterInfo.ParameterType.Name + " " + parameterInfo.Name;
                    message += string.Format("={0}, ",
                        args[parameterIterator] != null ?
                        args[parameterIterator].ToString() :
                        "null");
                    parameterIterator++;
                }

                //remove the "," at the end of the line
                if (message.EndsWith(", ")) { message = message.Substring(0, message.Length - 2); }

                message += ") : entering...";

                WriteEntry(message, TraceEventType.Verbose);
            }

            public void WriteFunctionExit()
            {
                string message = string.Empty;

                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format("{0} : {1}(", callingClass, callingMethod);

                System.Reflection.ParameterInfo[] parameterInfos = new StackFrame(1, true).GetMethod().GetParameters();
                foreach (System.Reflection.ParameterInfo parameterInfo in parameterInfos)
                {
                    message += parameterInfo.ParameterType.Name + " " + parameterInfo.Name + ", ";
                }

                //remove the "," at the end of the line
                if (message.EndsWith(", ")) { message = message.Substring(0, message.Length - 2); }

                message += ") : leaving...";

                WriteEntry(message, TraceEventType.Verbose);
            }

            public void WriteFunctionExit(object returnValue)
            {
                string message = string.Empty;

                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format("{0} : {1}(", callingClass, callingMethod);

                System.Reflection.ParameterInfo[] parameterInfos = new StackFrame(1, true).GetMethod().GetParameters();
                foreach (System.Reflection.ParameterInfo parameterInfo in parameterInfos)
                {
                    message += parameterInfo.ParameterType.Name + " " + parameterInfo.Name + ", ";
                }

                //remove the "," at the end of the line
                if (message.EndsWith(", ")) { message = message.Substring(0, message.Length - 2); }

                message += ") : leaving... ReturnValue is " + returnValue.ToString();

                WriteEntry(message, TraceEventType.Verbose);
            }

            public void WriteFunctionExitWithError(Exception ex)
            {
                string message = string.Empty;
                string error = ex.GetType().Name;
                if (!string.IsNullOrEmpty(error))
                {
                    error += ": " + ex.Message;
                }

                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format("{0} : {1}(", callingClass, callingMethod);

                System.Reflection.ParameterInfo[] parameterInfos = new StackFrame(1, true).GetMethod().GetParameters();
                foreach (System.Reflection.ParameterInfo parameterInfo in parameterInfos)
                {
                    message += parameterInfo.ParameterType.Name + " " + parameterInfo.Name + ", ";
                }

                //remove the "," at the end of the line
                if (message.EndsWith(", ")) { message = message.Substring(0, message.Length - 2); }

                message += ") : leaving with error '" + error + "'";

                WriteEntry(message, TraceEventType.Error);
            }

            private new void WriteEntry(string message, TraceEventType severity)
            {
                message = string.Format("{0}:{1}:{2}.{3};{4}",
                    DateTime.Now.Hour,
                    DateTime.Now.Minute,
                    DateTime.Now.Second,
                    DateTime.Now.Millisecond,
                    message);
                base.WriteEntry(message, severity);
            }

            private new void WriteEntry(string message)
            {
                WriteEntry(message, TraceEventType.Information);
            }

            public void WriteEntry(string message, TraceEventType severity, params object[] args)
            {
                string callingMethod = new StackFrame(1, true).GetMethod().Name;
                string callingClass = new StackFrame(1, true).GetMethod().ReflectedType.Name;

                message = string.Format(message, args);
                string messageHeader = string.Format("{0} : {1}", callingClass, callingMethod);
                message = string.Format("{0};{1}", messageHeader, message);

                WriteEntry(message, severity);
            }

            private void WriteEntry(string message, params object[] args)
            {
                message = string.Format(message, args);
                WriteEntry(message, TraceEventType.Information);
            }
        }
    }
    #endregion Log
}