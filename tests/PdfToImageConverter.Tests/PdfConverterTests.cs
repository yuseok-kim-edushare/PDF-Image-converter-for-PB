using PdfToImageConverter;

namespace PdfToImageConverter.Tests;

public class PdfConverterTests
{
    private static string FixturePdf()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "test.pdf");
        Assert.True(File.Exists(path), "test.pdf was not copied to the test output.");
        return path;
    }

    private static string TempDirectory()
    {
        string path = Path.Combine(Path.GetTempPath(), "pdfconv-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }

    [Fact]
    public void ConvertPdfToImage_MissingFile_ReturnsError()
    {
        var converter = new PdfConverter();
        string output = Path.Combine(TempDirectory(), "missing.png");
        string result = converter.ConvertPdfToImage(Path.Combine(Path.GetTempPath(), "pdfconv-missing.pdf"), output, 72);

        Assert.StartsWith("Error:", result, StringComparison.Ordinal);
    }

    [Fact]
    public void ConvertPdfToImage_InvalidDpi_ReturnsError()
    {
        var converter = new PdfConverter();
        string output = Path.Combine(TempDirectory(), "dpi.png");
        string result = converter.ConvertPdfToImage(FixturePdf(), output, 0);

        Assert.Contains("Invalid DPI", result, StringComparison.Ordinal);
    }

    [Fact]
    public void ConvertPdfToImage_WritesPngForEachPage()
    {
        var converter = new PdfConverter();
        string directory = TempDirectory();
        string output = Path.Combine(directory, "output.png");

        string result = converter.ConvertPdfToImage(FixturePdf(), output, 72);

        Assert.StartsWith("SUCCESS", result, StringComparison.Ordinal);
        Assert.True(File.Exists(Path.Combine(directory, "output_page1.png")));
        Assert.True(File.Exists(Path.Combine(directory, "output_page2.png")));
        AssertPng(Path.Combine(directory, "output_page1.png"));
    }

    [Fact]
    public void ConvertPdfToImageWithPageNames_UsesRequestedNames()
    {
        var converter = new PdfConverter();
        string directory = TempDirectory();
        string output = Path.Combine(directory, "ignored.png");

        string result = converter.ConvertPdfToImageWithPageNames(
            FixturePdf(),
            output,
            72,
            2,
            new[] { "Apple", "Banana" });

        Assert.StartsWith("SUCCESS", result, StringComparison.Ordinal);
        AssertPng(Path.Combine(directory, "Apple.png"));
        AssertPng(Path.Combine(directory, "Banana.png"));
    }

    [Fact]
    public void ConvertPdfToImageWithPageNames_MismatchedCount_ReturnsError()
    {
        var converter = new PdfConverter();
        string output = Path.Combine(TempDirectory(), "names.png");

        string result = converter.ConvertPdfToImageWithPageNames(
            FixturePdf(),
            output,
            72,
            1,
            new[] { "Only" });

        Assert.Contains("does not match PDF page count", result, StringComparison.Ordinal);
    }

    [Fact]
    public void ConvertPdfToImageWithPageNamesAndOutputPaths_WritesIntoFolders()
    {
        var converter = new PdfConverter();
        string directory = TempDirectory();
        string output = Path.Combine(directory, "base.png");

        string result = converter.ConvertPdfToImageWithPageNamesAndOutputPaths(
            FixturePdf(),
            output,
            72,
            2,
            new[] { "Apple", "Banana" },
            new[] { "alpha", "beta" });

        Assert.StartsWith("SUCCESS", result, StringComparison.Ordinal);
        AssertPng(Path.Combine(directory, "alpha", "Apple.png"));
        AssertPng(Path.Combine(directory, "beta", "Banana.png"));
    }

    [Fact]
    public void ConvertPdfToImageWithPageNames_NullNames_ReturnsError()
    {
        var converter = new PdfConverter();
        string output = Path.Combine(TempDirectory(), "null-names.png");

        string result = converter.ConvertPdfToImageWithPageNames(FixturePdf(), output, 72, 2, null);

        Assert.Contains("Page names array is null or empty", result, StringComparison.Ordinal);
    }

    private static void AssertPng(string path)
    {
        Assert.True(File.Exists(path), path);
        byte[] header = new byte[4];
        using (var stream = File.OpenRead(path))
        {
            Assert.Equal(4, stream.Read(header, 0, 4));
        }

        Assert.Equal(new byte[] { 0x89, 0x50, 0x4E, 0x47 }, header);
    }
}
