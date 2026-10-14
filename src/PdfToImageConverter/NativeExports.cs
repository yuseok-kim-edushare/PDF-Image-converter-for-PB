#if NET
using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;

namespace PdfToImageConverter
{
    /// <summary>
    /// Native AOT exports. Windows publishes use stdcall; Apple publishes use the platform C convention.
    /// Strings are UTF-16 (<c>char*</c> / <c>char16_t</c>). Return 0 on success.
    /// </summary>
    public static unsafe class NativeExports
    {
        public const int Success = 0;
        public const int InvalidArgument = -1;
        public const int ConversionFailed = -2;

#if PDFCONVERTER_WINDOWS
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImage", CallConvs = new[] { typeof(CallConvStdcall) })]
#else
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImage", CallConvs = new[] { typeof(CallConvCdecl) })]
#endif
        public static int ConvertPdfToImage(char* pdfPath, char* outputPath, int dpi, char* messageBuf, int messageBufChars)
        {
            if (pdfPath == null || outputPath == null)
            {
                WriteMessage(messageBuf, messageBufChars, "Error: PDF path or output path is null");
                return InvalidArgument;
            }

            return Invoke(
                messageBuf,
                messageBufChars,
                () => new PdfConverter().ConvertPdfToImage(new string(pdfPath), new string(outputPath), dpi));
        }

#if PDFCONVERTER_WINDOWS
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImageWithPageNames", CallConvs = new[] { typeof(CallConvStdcall) })]
#else
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImageWithPageNames", CallConvs = new[] { typeof(CallConvCdecl) })]
#endif
        public static int ConvertPdfToImageWithPageNames(
            char* pdfPath,
            char* outputPath,
            int dpi,
            int totalPagesNumber,
            char* pageNamesJoined,
            char* messageBuf,
            int messageBufChars)
        {
            if (pdfPath == null || outputPath == null)
            {
                WriteMessage(messageBuf, messageBufChars, "Error: PDF path or output path is null");
                return InvalidArgument;
            }

            var pageNames = SplitList(pageNamesJoined);
            return Invoke(
                messageBuf,
                messageBufChars,
                () => new PdfConverter().ConvertPdfToImageWithPageNames(
                    new string(pdfPath),
                    new string(outputPath),
                    dpi,
                    totalPagesNumber,
                    pageNames));
        }

#if PDFCONVERTER_WINDOWS
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImageWithPageNamesAndOutputPaths", CallConvs = new[] { typeof(CallConvStdcall) })]
#else
        [UnmanagedCallersOnly(EntryPoint = "ConvertPdfToImageWithPageNamesAndOutputPaths", CallConvs = new[] { typeof(CallConvCdecl) })]
#endif
        public static int ConvertPdfToImageWithPageNamesAndOutputPaths(
            char* pdfPath,
            char* outputPath,
            int dpi,
            int totalPagesNumber,
            char* pageNamesJoined,
            char* pagePathsJoined,
            char* messageBuf,
            int messageBufChars)
        {
            if (pdfPath == null || outputPath == null)
            {
                WriteMessage(messageBuf, messageBufChars, "Error: PDF path or output path is null");
                return InvalidArgument;
            }

            var pageNames = SplitList(pageNamesJoined);
            var pagePaths = SplitList(pagePathsJoined);
            return Invoke(
                messageBuf,
                messageBufChars,
                () => new PdfConverter().ConvertPdfToImageWithPageNamesAndOutputPaths(
                    new string(pdfPath),
                    new string(outputPath),
                    dpi,
                    totalPagesNumber,
                    pageNames,
                    pagePaths));
        }

        private static int _nativePathReady;

        private static int Invoke(char* messageBuf, int messageBufChars, Func<string> convert)
        {
            try
            {
                EnsureNativeDependencyPath();
                string result = convert();
                WriteMessage(messageBuf, messageBufChars, result);
                if (result != null && result.StartsWith("SUCCESS", StringComparison.Ordinal))
                    return Success;
                return ConversionFailed;
            }
            catch (Exception ex)
            {
                WriteMessage(messageBuf, messageBufChars, "Error: " + ex.Message);
                return ConversionFailed;
            }
        }

        private static void EnsureNativeDependencyPath()
        {
            if (Interlocked.Exchange(ref _nativePathReady, 1) == 1)
                return;

            string directory = GetModuleDirectory();
            if (string.IsNullOrEmpty(directory))
                return;

#if PDFCONVERTER_WINDOWS
            SetDllDirectoryW(directory);
#else
            RegisterResolver(directory, typeof(SkiaSharp.SKBitmap).Assembly);
            RegisterResolver(directory, typeof(PDFtoImage.Conversion).Assembly);
#endif
        }

        private static unsafe string GetModuleDirectory()
        {
#if PDFCONVERTER_WINDOWS
            char* buffer = stackalloc char[1024];
            IntPtr module = GetModuleHandleW("PdfToImageConverter.dll");
            int length = GetModuleFileNameW(module, buffer, 1024);
            if (length <= 0)
                return null;
            return Path.GetDirectoryName(new string(buffer, 0, length));
#else
            IntPtr symbol = dlsym(new IntPtr(-2), "ConvertPdfToImage");
            if (symbol == IntPtr.Zero || dladdr(symbol, out DlInfo info) == 0 || info.FileName == IntPtr.Zero)
                return null;
            string path = Marshal.PtrToStringUTF8(info.FileName);
            return string.IsNullOrEmpty(path) ? null : Path.GetDirectoryName(path);
#endif
        }

#if PDFCONVERTER_WINDOWS
        [DllImport("kernel32", CharSet = CharSet.Unicode, EntryPoint = "GetModuleHandleW")]
        private static extern IntPtr GetModuleHandleW(string moduleName);

        [DllImport("kernel32", CharSet = CharSet.Unicode, EntryPoint = "GetModuleFileNameW")]
        private static extern int GetModuleFileNameW(IntPtr module, char* filename, int size);

        [DllImport("kernel32", CharSet = CharSet.Unicode, EntryPoint = "SetDllDirectoryW")]
        private static extern bool SetDllDirectoryW(string path);
#else
        [StructLayout(LayoutKind.Sequential)]
        private struct DlInfo
        {
            public IntPtr FileName;
            public IntPtr BaseAddress;
            public IntPtr SymbolName;
            public IntPtr SymbolAddress;
        }

        [DllImport("libSystem")]
        private static extern IntPtr dlsym(IntPtr handle, string symbol);

        [DllImport("libSystem")]
        private static extern int dladdr(IntPtr address, out DlInfo info);

        private static void RegisterResolver(string directory, System.Reflection.Assembly assembly)
        {
            NativeLibrary.SetDllImportResolver(assembly, (libraryName, _, _) =>
            {
                string[] names = { libraryName, "lib" + libraryName };
                var candidates = new System.Collections.Generic.List<string>();
                foreach (string name in names)
                {
                    candidates.Add(Path.Combine(directory, name));
                    candidates.Add(Path.Combine(directory, name + ".dll"));
                    candidates.Add(Path.Combine(directory, name + ".dylib"));
                    candidates.Add(Path.Combine(directory, name + ".so"));
                    candidates.Add(Path.GetFullPath(Path.Combine(directory, "..", name + ".framework", name)));
                    candidates.Add(Path.GetFullPath(Path.Combine(directory, "..", "..", "..", name + ".framework", "Versions", "A", name)));
                }

                foreach (string candidate in candidates)
                {
                    if (File.Exists(candidate) && NativeLibrary.TryLoad(candidate, out IntPtr handle))
                        return handle;
                }

                return IntPtr.Zero;
            });
        }
#endif

        private static string[] SplitList(char* joined)
        {
            if (joined == null)
                return null;

            string text = new string(joined);
            if (text.Length == 0)
                return Array.Empty<string>();

            return text.Split(new[] { "\r\n", "\n", "\r" }, StringSplitOptions.None);
        }

        private static void WriteMessage(char* buffer, int capacity, string message)
        {
            if (buffer == null || capacity <= 0)
                return;

            message ??= string.Empty;
            int count = message.Length;
            int max = capacity - 1;
            if (count > max)
                count = max;

            for (int i = 0; i < count; i++)
                buffer[i] = message[i];

            buffer[count] = '\0';
        }
    }
}
#endif
