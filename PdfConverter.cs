using System;
using System.Threading.Tasks;
using System.Linq;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections.Concurrent;
using PDFtoImage;
using SkiaSharp;

namespace PdfToImageConverter
{
    [ComVisible(true)]
    [Guid("B8B9E0C1-D513-4D8A-B11F-4A10E3D0C1A9")]
    public interface IPdfConverter
    {
        [ComVisible(true)]
        [DispId(1)]
        string ConvertPdfToImage(string pdfPath, string outputPath, int dpi);

        [ComVisible(true)]
        [DispId(2)]
        string ConvertPdfToImageWithPageNames(string pdfPath, string outputPath, int dpi, int totalPagesNumber, string[] pageNames);
    }

    [ComVisible(true)]
    [Guid("02FCF9B4-E978-4FE0-B5F3-F66F11B30AE7")]
    [ClassInterface(ClassInterfaceType.None)]
    [ComDefaultInterface(typeof(IPdfConverter))]
    [ProgId("PdfToImageConverter.PdfConverter")]
    public class PdfConverter : IPdfConverter
    {
        private const string TEMP_DIR = @"C:\temp\Powerbuilder-pdf2img";
        private static readonly object _initLock = new object();
        private static bool _initialized = false;

        public PdfConverter()
        {
            try
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\n\nConstructing PdfConverter instance at {DateTime.Now}\n");

                lock (_initLock)
                {
                    if (!_initialized)
                    {
                        InitializeConverter();
                        _initialized = true;
                    }
                }
            }
            catch (Exception ex)
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\nError in constructor: {ex.GetType().FullName}\n");
                File.AppendAllText(logPath, $"Error Message: {ex.Message}\n");
                File.AppendAllText(logPath, $"Stack Trace:\n{ex.StackTrace}\n");
                
                // Rethrow with more specific message for COM clients
                throw new COMException($"Failed to initialize PdfConverter: {ex.Message}", ex);
            }
        }

        private void InitializeConverter()
        {
            string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
            
            try
            {
                // Log environment details
                File.AppendAllText(logPath, $"OS Version: {Environment.OSVersion}\n");
                File.AppendAllText(logPath, $"64-bit OS: {Environment.Is64BitOperatingSystem}\n");
                File.AppendAllText(logPath, $"64-bit Process: {Environment.Is64BitProcess}\n");
                File.AppendAllText(logPath, $"Current Directory: {Environment.CurrentDirectory}\n");
                File.AppendAllText(logPath, $"Module Path: {System.Reflection.Assembly.GetExecutingAssembly().Location}\n");

                // Ensure temp directory exists
                if (!Directory.Exists(TEMP_DIR))
                {
                    Directory.CreateDirectory(TEMP_DIR);
                    File.AppendAllText(logPath, $"Created temp directory: {TEMP_DIR}\n");
                }

                // Test SkiaSharp initialization
                try
                {
                    var dummyObject = new SKBitmap();
                    File.AppendAllText(logPath, "SkiaSharp initialized successfully\n");
                }
                catch (DllNotFoundException dllEx)
                {
                    File.AppendAllText(logPath, $"SkiaSharp DLL not found: {dllEx.Message}\n");
                    throw new COMException("Failed to load SkiaSharp native dependencies. Please ensure all required DLLs are present.", dllEx);
                }
                catch (Exception ex)
                {
                    File.AppendAllText(logPath, $"SkiaSharp initialization failed: {ex.Message}\n");
                    File.AppendAllText(logPath, $"SkiaSharp error details: {ex}\n");
                    throw new COMException("Failed to initialize SkiaSharp. Please ensure all native dependencies are properly installed.", ex);
                }
            }
            catch (Exception ex)
            {
                File.AppendAllText(logPath, $"\nError in initialization: {ex.GetType().FullName}\n");
                File.AppendAllText(logPath, $"Error Message: {ex.Message}\n");
                File.AppendAllText(logPath, $"Stack Trace:\n{ex.StackTrace}\n");
                throw;
            }
        }

        private void EnsureDirectoryExists(string filePath)
        {
            string directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }

        private bool ValidateFilePath(string path)
        {
            if (string.IsNullOrEmpty(path)) return false;
            try
            {
                Path.GetFullPath(path);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private string GetPageOutputPath(string outputPath, int pageNumber, int pageCount)
        {
            if (pageCount > 1)
            {
                string extension = Path.GetExtension(outputPath);
                string fileNameWithoutExt = Path.GetFileNameWithoutExtension(outputPath);
                string directory = Path.GetDirectoryName(outputPath);
                return Path.Combine(directory, $"{fileNameWithoutExt}_page{pageNumber + 1}{extension}");
            }
            return outputPath;
        }
        private string GetPageOutputPathForPageName(string outputPath, string pageName)
        {
            string extension = Path.GetExtension(outputPath);
            string directory = Path.GetDirectoryName(outputPath);
            return Path.Combine(directory, $"{pageName}{extension}");
        }

        private RenderOptions CreateRenderOptions(int dpi)
        {
            return new RenderOptions(
                Dpi: dpi,
                Width: null,
                Height: null,
                WithAnnotations: true,
                WithFormFill: true,
                WithAspectRatio: true,
                Rotation: PdfRotation.Rotate0,
                AntiAliasing: PdfAntiAliasing.All,
                BackgroundColor: null,
                Bounds: null,
                UseTiling: true,
                DpiRelativeToBounds: false
            );
        }

        private string ValidateAndLoadPdf(string pdfPath, string outputPath, int dpi, out byte[] pdfBytes)
        {
            pdfBytes = null;

            if (!ValidateFilePath(pdfPath))
            {
                return $"Error: Invalid PDF path format: {pdfPath}";
            }

            if (!ValidateFilePath(outputPath))
            {
                return $"Error: Invalid output path format: {outputPath}";
            }

            if (!File.Exists(pdfPath))
            {
                return $"Error: PDF file not found at path: {pdfPath}";
            }

            if (dpi <= 0 || dpi > 1200)
            {
                return $"Error: Invalid DPI value. Must be between 1 and 1200. Got: {dpi}";
            }

            try
            {
                EnsureDirectoryExists(outputPath);
            }
            catch (Exception ex)
            {
                return $"Error: Failed to create output directory: {ex.Message}";
            }

            try
            {
                pdfBytes = File.ReadAllBytes(pdfPath);
                int pageCount = PDFtoImage.Conversion.GetPageCount(pdfBytes, null);
                if (pageCount == 0)
                {
                    return "Error: PDF document has no pages";
                }
            }
            catch (Exception ex)
            {
                return $"Error: Failed to read PDF file: {ex.Message}";
            }

            return null; // null means validation passed
        }

        [ComVisible(true)]
        [DispId(1)]
        public string ConvertPdfToImage(string pdfPath, string outputPath, int dpi = 300)
        {
            try
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\n\nStarting conversion at {DateTime.Now}\n");
                File.AppendAllText(logPath, $"PDF Path: {pdfPath}\n");
                File.AppendAllText(logPath, $"Output Path: {outputPath}\n");
                File.AppendAllText(logPath, $"DPI: {dpi}\n");

                byte[] pdfBytes;
                string validationError = ValidateAndLoadPdf(pdfPath, outputPath, dpi, out pdfBytes);
                if (validationError != null)
                {
                    return validationError;
                }

                int pageCount = PDFtoImage.Conversion.GetPageCount(pdfBytes, null);
                var options = CreateRenderOptions(dpi);

                // Process first page
                try
                {
                    string firstPageOutput = GetPageOutputPath(outputPath, 0, pageCount);
                    PDFtoImage.Conversion.SavePng(firstPageOutput, pdfBytes, null, 0, options);
                }
                catch (Exception ex)
                {
                    return $"Error processing first page: {ex.Message}";
                }

                // If first page succeeds and there are more pages, process them
                if (pageCount > 1)
                {
                    var exceptions = new ConcurrentQueue<Exception>();
                    
                    Parallel.For(1, pageCount, pageNumber =>
                    {
                        try
                        {
                            string pageOutput = GetPageOutputPath(outputPath, pageNumber, pageCount);
                            PDFtoImage.Conversion.SavePng(pageOutput, pdfBytes, null, pageNumber, options);
                        }
                        catch (Exception ex)
                        {
                            exceptions.Enqueue(ex);
                        }
                    });

                    if (exceptions.Count > 0)
                    {
                        var firstEx = exceptions.TryDequeue(out var ex) ? ex : null;
                        return $"Error: {firstEx?.GetType().Name} - {firstEx?.Message}";
                    }
                }

                return "SUCCESS: PDF converted successfully";
            }
            catch (Exception ex)
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\nError in ConvertPdfToImage: {ex.GetType().Name} - {ex.Message}\n");
                File.AppendAllText(logPath, $"Stack Trace:\n{ex.StackTrace}\n");
                return $"Error: {ex.GetType().Name} - {ex.Message} - Location: {ex.StackTrace}";
            }
        }

        [ComVisible(true)]
        [DispId(2)]
        public string ConvertPdfToImageWithPageNames(string pdfPath, string outputPath, int dpi, int totalPagesNumber, string[] pageNames)
        {
            try
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\n\nStarting conversion at {DateTime.Now}\n");
                File.AppendAllText(logPath, $"PDF Path: {pdfPath}\n");
                File.AppendAllText(logPath, $"Output Path: {outputPath}\n");
                File.AppendAllText(logPath, $"DPI: {dpi}\n");
                File.AppendAllText(logPath, $"Total Pages Number: {totalPagesNumber}\n");
                File.AppendAllText(logPath, $"Page Names: {string.Join(", ", pageNames)}\n");

                // Use common validation method first
                byte[] pdfBytes;
                string validationError = ValidateAndLoadPdf(pdfPath, outputPath, dpi, out pdfBytes);
                if (validationError != null)
                {
                    return validationError;
                }

                int pdfPageCount = PDFtoImage.Conversion.GetPageCount(pdfBytes, null);

                // Validate totalPagesNumber matches PDF page count
                if (totalPagesNumber != pdfPageCount)
                {
                    return $"Error: Total pages number ({totalPagesNumber}) does not match PDF page count ({pdfPageCount})";
                }

                // Validate page names array length matches total pages
                if (pageNames.Length < totalPagesNumber)
                {
                    return $"Error: Page names array length ({pageNames.Length}) is less than total pages ({totalPagesNumber})";
                }

                if (pageNames.Length == 0)
                {
                    return "Error: Page names array is empty";  
                }

                if (pageNames.Any(name => string.IsNullOrEmpty(name)))
                {
                    return "Error: Page names array contains empty strings";
                }

                var options = CreateRenderOptions(dpi);

                // Process all pages using their page names
                for (int pageNumber = 0; pageNumber < totalPagesNumber; pageNumber++)
                {
                    try
                    {
                        string pageOutput = GetPageOutputPathForPageName(outputPath, pageNames[pageNumber]);
                        PDFtoImage.Conversion.SavePng(pageOutput, pdfBytes, null, pageNumber, options);
                    }
                    catch (Exception ex)
                    {
                        return $"Error processing page {pageNumber} ({pageNames[pageNumber]}): {ex.Message}";
                    }
                }

                return "SUCCESS: PDF converted successfully";
            }
            catch (Exception ex)
            {
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\nError in ConvertPdfToImageWithPageNames: {ex.GetType().Name} - {ex.Message}\n");
                File.AppendAllText(logPath, $"Stack Trace:\n{ex.StackTrace}\n");    
                return $"Error: {ex.GetType().Name} - {ex.Message} - Location: {ex.StackTrace}";
            }
        }
    }   
}