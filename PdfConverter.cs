using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using PdfiumViewer;

namespace PdfToImageConverter
{
    [ComVisible(true)]
    [Guid("A8B9E0C1-D513-4D8A-B11F-4A10E3D0C1A8")]
    [ClassInterface(ClassInterfaceType.None)]
    public static class PdfConverter
    {
        private static void EnsureDirectoryExists(string filePath)
        {
            string directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }

        [ComVisible(true)]
        public static string ConvertPdfToImage(string pdfPath, string outputPath, int dpi = 300)
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
                using (var document = PdfDocument.Load(pdfPath))
                {
                    if (document.PageCount == 0)
                    {
                        return "Error: PDF document has no pages";
                    }

                    for (int pageNumber = 0; pageNumber < document.PageCount; pageNumber++)
                    {
                        // Calculate the size based on DPI
                        var pdfSize = document.PageSizes[pageNumber];
                        int width = (int)((pdfSize.Width / 72.0f) * dpi);
                        int height = (int)((pdfSize.Height / 72.0f) * dpi);

                        // Render the page to an image
                        using (var image = document.Render(pageNumber, width, height, dpi, dpi, false))
                        {
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
                            image.Save(pageOutputPath, ImageFormat.Png);
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