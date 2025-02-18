using System;
using System.Threading.Tasks;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Threading;
using System.Collections.Concurrent;
using PDFtoImage;

namespace PdfToImageConverter
{
    [ComVisible(true)]
    [Guid("B8B9E0C1-D513-4D8A-B11F-4A10E3D0C1A9")]
    public interface IPdfConverter
    {
        [ComVisible(true)]
        [DispId(1)]
        string ConvertPdfToImage(string pdfPath, string outputPath, int dpi);
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

        static PdfConverter()
        {
            try
            {
                // Log current directory and loaded assemblies
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\n\nStarting static constructor at {DateTime.Now}\n");
                
                // Ensure temp directory exists
                if (!Directory.Exists(TEMP_DIR))
                {
                    Directory.CreateDirectory(TEMP_DIR);
                    File.AppendAllText(logPath, $"Created temp directory: {TEMP_DIR}\n");
                }
                
                // Clean any existing temp files
                try
                {
                    foreach (var file in Directory.GetFiles(TEMP_DIR, "*.pdf"))
                    {
                        File.Delete(file);
                    }
                    File.AppendAllText(logPath, "Cleaned existing temp files\n");
                }
                catch (Exception ex)
                {
                    File.AppendAllText(logPath, $"Warning: Failed to clean temp files: {ex.Message}\n");
                }
            }
            catch (Exception ex)
            {
                // Log the error
                string logPath = Path.Combine(Path.GetTempPath(), "PdfConverter_Debug.log");
                File.AppendAllText(logPath, $"\nError in static constructor: {ex.GetType().FullName}\n");
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

                // Ensure output directory exists before proceeding
                try
                {
                    File.AppendAllText(logPath, "Creating output directory...\n");
                    EnsureDirectoryExists(outputPath);
                }
                catch (Exception ex)
                {
                    File.AppendAllText(logPath, $"Failed to create output directory: {ex.Message}\n");
                    return $"Error: Failed to create output directory: {ex.Message}";
                }

                // Read the PDF file into a byte array
                byte[] pdfBytes = File.ReadAllBytes(pdfPath);

                // Get the page count
                int pageCount = PDFtoImage.Conversion.GetPageCount(pdfBytes, null);
                if (pageCount == 0)
                {
                    return "Error: PDF document has no pages";
                }

                // Create render options
                var options = new RenderOptions(
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
    }
}