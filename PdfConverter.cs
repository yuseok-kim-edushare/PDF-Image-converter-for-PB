using System;
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
                    return "Error: Invalid PDF path format";
                }

                if (!ValidateFilePath(outputPath))
                {
                    return "Error: Invalid output path format";
                }

                if (!File.Exists(pdfPath))
                {
                    return "Error: PDF file not found at path: " + pdfPath;
                }

                // Ensure output directory exists before proceeding
                EnsureDirectoryExists(outputPath);

                // Load the PDF document
                using (var document = PdfReader.Open(pdfPath, PdfDocumentOpenMode.Import))
                {
                    if (document.PageCount == 0)
                    {
                        return "Error: PDF document has no pages";
                    }

                    Parallel.For(0, document.PageCount, pageNumber =>
                    {
                        var page = document.Pages[pageNumber];

                        // Calculate dimensions based on DPI
                        double width = page.Width.Point * (dpi / 72.0);
                        double height = page.Height.Point * (dpi / 72.0);

                        string pageOutputPath = GetPageOutputPath(outputPath, pageNumber, document.PageCount);
                        EnsureDirectoryExists(pageOutputPath);

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
                                    // Import the page from the original document
                                    tempDoc.AddPage(page);

                                    // Save to memory stream and load as image
                                    using (var ms = new MemoryStream())
                                    {
                                        tempDoc.Save(ms, false);
                                        ms.Position = 0;

                                        // Draw to graphics
                                        using (var img = Image.FromStream(ms))
                                        {
                                            graphics.DrawImage(img, 0, 0, (float)width, (float)height);
                                        }
                                    }
                                }
                            }

                            // Save as PNG
                            bitmap.Save(pageOutputPath, ImageFormat.Png);
                        }
                    });
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