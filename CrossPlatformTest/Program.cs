using System;
using System.IO;
using System.Runtime.InteropServices;
using PdfToImageConverter;

namespace CrossPlatformTest
{
    class Program
    {
        static int Main(string[] args)
        {
            Console.WriteLine("=== PDF to Image Converter - Cross-Platform Functionality Test ===");
            Console.WriteLine($"Platform: {RuntimeInformation.OSDescription}");
            Console.WriteLine($"Architecture: {RuntimeInformation.OSArchitecture}");
            Console.WriteLine($"Runtime: {RuntimeInformation.FrameworkDescription}");
            Console.WriteLine();

            try
            {
                // Initialize test parameters
                string testPdfPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "test.pdf");
                string tempDir = Path.Combine(Path.GetTempPath(), "CrossPlatformTest", Guid.NewGuid().ToString());
                Directory.CreateDirectory(tempDir);

                Console.WriteLine($"Test PDF: {testPdfPath}");
                Console.WriteLine($"Output directory: {tempDir}");
                Console.WriteLine();

                // Verify test PDF exists
                if (!File.Exists(testPdfPath))
                {
                    Console.WriteLine($"❌ ERROR: Test PDF not found at {testPdfPath}");
                    return 1;
                }

                // Create converter instance - this works cross-platform (no COM)
                var converter = new PdfConverter();
                Console.WriteLine("✅ PdfConverter instance created successfully");

                // Test 1: Basic PDF to Image conversion
                Console.WriteLine("\n--- Test 1: Basic PDF to Image Conversion ---");
                string outputPath1 = Path.Combine(tempDir, "test_basic.png");
                try
                {
                    string result1 = converter.ConvertPdfToImage(testPdfPath, outputPath1, 150);
                    Console.WriteLine($"Result: {result1}");
                    
                    // Verify output files were created
                    var outputFiles = Directory.GetFiles(tempDir, "test_basic*.png");
                    if (outputFiles.Length > 0)
                    {
                        Console.WriteLine($"✅ Test 1 PASSED - Created {outputFiles.Length} image file(s)");
                        foreach (var file in outputFiles)
                        {
                            var fileInfo = new FileInfo(file);
                            Console.WriteLine($"   - {Path.GetFileName(file)} ({fileInfo.Length} bytes)");
                        }
                    }
                    else
                    {
                        Console.WriteLine("❌ Test 1 FAILED - No output files created");
                        return 1;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Test 1 FAILED - Exception: {ex.Message}");
                    return 1;
                }

                // Test 2: PDF to Image conversion with page names
                Console.WriteLine("\n--- Test 2: PDF to Image Conversion with Page Names ---");
                string outputPath2 = Path.Combine(tempDir, "test_named.png");
                string[] pageNames = { "Apple", "Banana" };
                try
                {
                    string result2 = converter.ConvertPdfToImageWithPageNames(testPdfPath, outputPath2, 150, 2, pageNames);
                    Console.WriteLine($"Result: {result2}");
                    
                    // Verify output files were created with expected names
                    bool allNamesFound = true;
                    foreach (var pageName in pageNames)
                    {
                        var expectedFile = Path.Combine(tempDir, $"{pageName}.png");
                        if (File.Exists(expectedFile))
                        {
                            var fileInfo = new FileInfo(expectedFile);
                            Console.WriteLine($"   ✅ Found: {Path.GetFileName(expectedFile)} ({fileInfo.Length} bytes)");
                        }
                        else
                        {
                            Console.WriteLine($"   ❌ Missing: {pageName}.png");
                            allNamesFound = false;
                        }
                    }
                    
                    if (allNamesFound)
                    {
                        Console.WriteLine("✅ Test 2 PASSED - All named files created");
                    }
                    else
                    {
                        Console.WriteLine("❌ Test 2 FAILED - Some named files missing");
                        return 1;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Test 2 FAILED - Exception: {ex.Message}");
                    return 1;
                }

                // Test 3: PDF to Image conversion with page names and output paths
                Console.WriteLine("\n--- Test 3: PDF to Image Conversion with Page Names and Output Paths ---");
                string outputPath3 = Path.Combine(tempDir, "test_paths.png");
                string[] pagePaths = { "alpha", "beta" };
                try
                {
                    string result3 = converter.ConvertPdfToImageWithPageNamesAndOutputPaths(testPdfPath, outputPath3, 150, 2, pageNames, pagePaths);
                    Console.WriteLine($"Result: {result3}");
                    
                    // Verify output files were created with expected paths and names
                    bool allPathsFound = true;
                    for (int i = 0; i < Math.Min(pageNames.Length, pagePaths.Length); i++)
                    {
                        var expectedFile = Path.Combine(tempDir, pagePaths[i], $"{pageNames[i]}.png");
                        if (File.Exists(expectedFile))
                        {
                            var fileInfo = new FileInfo(expectedFile);
                            Console.WriteLine($"   ✅ Found: {pagePaths[i]}/{pageNames[i]}.png ({fileInfo.Length} bytes)");
                        }
                        else
                        {
                            Console.WriteLine($"   ❌ Missing: {pagePaths[i]}/{pageNames[i]}.png");
                            allPathsFound = false;
                        }
                    }
                    
                    if (allPathsFound)
                    {
                        Console.WriteLine("✅ Test 3 PASSED - All path-based files created");
                    }
                    else
                    {
                        Console.WriteLine("❌ Test 3 FAILED - Some path-based files missing");
                        return 1;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Test 3 FAILED - Exception: {ex.Message}");
                    return 1;
                }

                // All tests passed
                Console.WriteLine("\n🎉 ALL TESTS PASSED - Cross-platform functionality verified!");
                
                // Clean up temp directory
                try
                {
                    Directory.Delete(tempDir, true);
                    Console.WriteLine($"🧹 Cleaned up temporary directory: {tempDir}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"⚠️  Warning: Could not clean up temporary directory: {ex.Message}");
                }

                return 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\n💥 CRITICAL ERROR: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return 1;
            }
        }
    }
}