using System;
using System.Threading.Tasks;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;
using System.Drawing.Drawing2D;

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
        static PdfConverter()
        {
            // Set encoding for PdfSharp
            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
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

        private bool ProcessPage(PdfPage pdfPage, string outputFilePath, int dpi, out string error)
        {
            error = null;
            try
            {
                // Calculate dimensions based on DPI
                double width = pdfPage.Width.Point * (dpi / 72.0);
                double height = pdfPage.Height.Point * (dpi / 72.0);

                if (width <= 0 || height <= 0)
                {
                    error = $"Invalid page dimensions: Width={width}, Height={height}, Original Width={pdfPage.Width.Point}, Original Height={pdfPage.Height.Point}";
                    return false;
                }

                // Create bitmap and set its resolution
                using (var bitmap = new Bitmap(Math.Max(1, (int)width), Math.Max(1, (int)height)))
                {
                    bitmap.SetResolution(dpi, dpi);

                    using (Graphics graphics = Graphics.FromImage(bitmap))
                    {
                        graphics.Clear(Color.White);
                        graphics.SmoothingMode = SmoothingMode.HighQuality;
                        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        graphics.CompositingQuality = CompositingQuality.HighQuality;

                        // Create a PDF page for rendering
                        using (var tempDoc = new PdfDocument())
                        {
                            tempDoc.AddPage(pdfPage);

                            using (var ms = new MemoryStream())
                            {
                                tempDoc.Save(ms, false);
                                ms.Position = 0;

                                if (ms.Length == 0)
                                {
                                    error = "Failed to save temporary PDF to memory stream";
                                    return false;
                                }

                                using (var img = Image.FromStream(ms))
                                {
                                    graphics.DrawImage(img, 0, 0, (float)width, (float)height);
                                }
                            }
                        }
                    }

                    try
                    {
                        bitmap.Save(outputFilePath, ImageFormat.Png);
                        return true;
                    }
                    catch (Exception ex)
                    {
                        error = $"Failed to save image: {ex.Message}";
                        return false;
                    }
                }
            }
            catch (Exception ex)
            {
                error = $"{ex.GetType().Name} - {ex.Message}";
                return false;
            }
        }

        [ComVisible(true)]
        [DispId(1)]
        public string ConvertPdfToImage(string pdfPath, string outputPath, int dpi = 300)
        {
            try
            {
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
                    EnsureDirectoryExists(outputPath);
                }
                catch (Exception ex)
                {
                    return $"Error: Failed to create output directory: {ex.Message}";
                }

                // Load the PDF document
                PdfDocument document = null;
                try
                {
                    // First try to verify the PDF file
                    if (new FileInfo(pdfPath).Length == 0)
                    {
                        return "Error: PDF file is empty";
                    }

                    document = PdfReader.Open(pdfPath, PdfDocumentOpenMode.Import);
                    
                    if (document == null)
                    {
                        return "Error: Failed to open PDF document (null document returned)";
                    }
                }
                catch (Exception ex)
                {
                    return $"Error: Failed to open PDF: {ex.GetType().Name} - {ex.Message}";
                }

                using (document)
                {
                    if (document.PageCount == 0)
                    {
                        return "Error: PDF document has no pages";
                    }

                    // Process first page
                    var firstPage = document.Pages[0];
                    if (firstPage == null)
                    {
                        return "Error: First page is null";
                    }

                    string firstPageOutput = GetPageOutputPath(outputPath, 0, document.PageCount);
                    string error;
                    if (!ProcessPage(firstPage, firstPageOutput, dpi, out error))
                    {
                        return $"Error processing first page: {error}";
                    }

                    // If first page succeeds and there are more pages, process them
                    if (document.PageCount > 1)
                    {
                        var exceptions = new System.Collections.Concurrent.ConcurrentQueue<Exception>();
                        
                        Parallel.For(1, document.PageCount, pageNumber =>
                        {
                            try
                            {
                                var page = document.Pages[pageNumber];
                                string pageOutput = GetPageOutputPath(outputPath, pageNumber, document.PageCount);
                                
                                string pageError;
                                if (!ProcessPage(page, pageOutput, dpi, out pageError))
                                {
                                    throw new Exception(pageError);
                                }
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
                }

                return "SUCCESS: PDF converted successfully";
            }
            catch (Exception ex)
            {
                return $"Error: {ex.GetType().Name} - {ex.Message} - Location: {ex.StackTrace}";
            }
        }
    }
}