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
                    document = PdfReader.Open(pdfPath, PdfDocumentOpenMode.Import);
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

                    var exceptions = new System.Collections.Concurrent.ConcurrentQueue<Exception>();

                    Parallel.For(0, document.PageCount, pageNumber =>
                    {
                        try
                        {
                            var page = document.Pages[pageNumber];

                            // Calculate dimensions based on DPI
                            double width = page.Width.Point * (dpi / 72.0);
                            double height = page.Height.Point * (dpi / 72.0);

                            if (width <= 0 || height <= 0)
                            {
                                throw new ArgumentException($"Invalid page dimensions: Width={width}, Height={height}");
                            }

                            string pageOutputPath = GetPageOutputPath(outputPath, pageNumber, document.PageCount);

                            // Create bitmap and set its resolution
                            using (var bitmap = new Bitmap((int)width, (int)height))
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
                                        tempDoc.AddPage(page);

                                        using (var ms = new MemoryStream())
                                        {
                                            tempDoc.Save(ms, false);
                                            ms.Position = 0;

                                            using (var img = Image.FromStream(ms))
                                            {
                                                graphics.DrawImage(img, 0, 0, (float)width, (float)height);
                                            }
                                        }
                                    }
                                }

                                try
                                {
                                    bitmap.Save(pageOutputPath, ImageFormat.Png);
                                }
                                catch (Exception ex)
                                {
                                    throw new Exception($"Failed to save image to {pageOutputPath}: {ex.Message}", ex);
                                }
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

                return "SUCCESS: PDF converted successfully";
            }
            catch (Exception ex)
            {
                return $"Error: {ex.GetType().Name} - {ex.Message} - Location: {ex.StackTrace}";
            }
        }
    }
}