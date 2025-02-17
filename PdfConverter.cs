using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;

namespace PdfToImageConverter
{
    [ComVisible(true)]
    [Guid("A8B9E0C1-D513-4D8A-B11F-4A10E3D0C1A8")]
    [ClassInterface(ClassInterfaceType.None)]
    public class PdfConverter
    {
        private void EnsureDirectoryExists(string filePath)
        {
            string directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }

        [ComVisible(true)]
        public string ConvertPdfToImage(string pdfPath, string outputPath, int dpi = 300)
        {
            try
            {
                if (string.IsNullOrEmpty(pdfPath))
                {
                    return "Error: PDF path is empty or null";
                }

                if (string.IsNullOrEmpty(outputPath))
                {
                    return "Error: Output path is empty or null";
                }

                if (!File.Exists(pdfPath))
                {
                    return $"Error: PDF file not found at path: {pdfPath}";
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

                    for (int pageNumber = 0; pageNumber < document.PageCount; pageNumber++)
                    {
                        var page = document.Pages[pageNumber];
                        
                        // Calculate dimensions based on DPI
                        double width = page.Width.Point * (dpi / 72.0);
                        double height = page.Height.Point * (dpi / 72.0);

                        // Create a new PDF document for this page
                        using (var singlePageDoc = new PdfDocument())
                        {
                            // Add the page to the new document
                            singlePageDoc.AddPage(page);

                            // Save to memory stream
                            using (var ms = new MemoryStream())
                            {
                                singlePageDoc.Save(ms, false);
                                ms.Position = 0;

                                // Create a bitmap with the right dimensions
                                using (var bitmap = new Bitmap((int)width, (int)height))
                                {
                                    bitmap.SetResolution(dpi, dpi);

                                    using (Graphics graphics = Graphics.FromImage(bitmap))
                                    {
                                        // Set high quality rendering
                                        graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
                                        graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                                        graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;

                                        // Clear background to white
                                        graphics.FillRectangle(Brushes.White, 0, 0, (int)width, (int)height);

                                        // Load and draw the PDF page
                                        using (var img = Image.FromStream(ms))
                                        {
                                            graphics.DrawImage(img, 0, 0, (int)width, (int)height);
                                        }
                                    }

                                    string pageOutputPath = outputPath;
                                    if (document.PageCount > 1)
                                    {
                                        string extension = Path.GetExtension(outputPath);
                                        string fileNameWithoutExt = Path.GetFileNameWithoutExtension(outputPath);
                                        string directory = Path.GetDirectoryName(outputPath);
                                        pageOutputPath = Path.Combine(directory, $"{fileNameWithoutExt}_page{pageNumber + 1}{extension}");
                                        
                                        // Ensure directory exists for multi-page output
                                        EnsureDirectoryExists(pageOutputPath);
                                    }

                                    // Save the image as PNG
                                    bitmap.Save(pageOutputPath, ImageFormat.Png);
                                }
                            }
                        }
                    }
                }

                return "SUCCESS: PDF converted successfully";
            }
            catch (Exception ex)
            {
                return $"Error: {ex.GetType().Name} - {ex.Message}";
            }
        }
    }
} 