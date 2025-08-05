# PDF to Image Converter .NET Library (Cross-Platform)

This is a cross-platform .NET library that converts PDF files to PNG images while maintaining the original PDF dimensions. </br>
The library is designed to work on Windows and macOS systems. </br>
It can be used with PowerBuilder applications on Windows, or as a .NET library on supported platforms.

[![CI tests](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml)
[![local CI tests with Powerbuilder](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci-pb.yaml)

## Features

- Convert PDF files to PNG images
- Maintains original PDF dimensions
- Supports multi-page PDFs
- Configurable DPI settings
- **Cross-platform support**: Windows, macOS (Intel/Apple Silicon)
- COM-visible for use in PowerBuilder (Windows only)
- Self-contained deployment options

## Requirements

### Windows (PowerBuilder/COM)
- .NET Framework 4.8.1 SDK for Development with build tool (select 1 of 2 options)
   - Visual Studio 2019 or later for building the library
   - .NET 8 SDK for building the library
- PowerBuilder 2019 R3 or later

### Cross-Platform (.NET 8)
- .NET 8 Runtime or SDK
- Supported platforms:
  - Windows (x64, x86)
  - macOS (Intel x64, Apple Silicon ARM64)

## Building the Library

### Windows (for PowerBuilder)
1. Open the solution in Visual Studio
2. Build the solution in Release mode
3. if you want to build with dotnet cli(cause of not having visual studio)
   ```powershell
   dotnet build PdfToImageConverter.csproj --configuration Release
   ```

### Cross-Platform (.NET 8)
For platform-specific builds:

```bash
# Windows x64
dotnet publish PdfToImageConverter.csproj -c Release -f net8.0 -r win-x64 --self-contained

# macOS Intel
dotnet publish PdfToImageConverter.csproj -c Release -f net8.0 -r osx-x64 --self-contained

# macOS Apple Silicon  
dotnet publish PdfToImageConverter.csproj -c Release -f net8.0 -r osx-arm64 --self-contained
```

The `--self-contained` flag includes all native dependencies needed for PDF processing.

## Usage in .NET Applications (Cross-Platform)

You can use the library directly in any .NET 8+ application:

### C# Example
```csharp
using PdfToImageConverter;

class Program
{
    static void Main()
    {
        var converter = new PdfConverter();
        
        string result = converter.ConvertPdfToImage(
            "/path/to/input.pdf", 
            "/path/to/output.png", 
            300  // DPI
        );
        
        if (result.StartsWith("SUCCESS"))
        {
            Console.WriteLine("Conversion successful!");
        }
        else
        {
            Console.WriteLine($"Error: {result}");
        }
    }
}
```

### F# Example
```fsharp
open PdfToImageConverter

let converter = new PdfConverter()
let result = converter.ConvertPdfToImage("/path/to/input.pdf", "/path/to/output.png", 300)

match result.StartsWith("SUCCESS") with
| true -> printfn "Conversion successful!"
| false -> printfn "Error: %s" result
```

### VB.NET Example
```vb
Imports PdfToImageConverter

Module Program
    Sub Main()
        Dim converter As New PdfConverter()
        Dim result As String = converter.ConvertPdfToImage("/path/to/input.pdf", "/path/to/output.png", 300)
        
        If result.StartsWith("SUCCESS") Then
            Console.WriteLine("Conversion successful!")
        Else
            Console.WriteLine($"Error: {result}")
        End If
    End Sub
End Module
```

## Usage in PowerBuilder (Windows)

1. Use PowerBuilder's ".NET DLL Importer" tool to import the assembly:
   - Open your PowerBuilder project
   - Select Tools → ".NET DLL Importer"
   - Browse to and select "PdfToImageConverter.dll"
     - Un-Zip release assets and select "PdfToImageConverter.dll"
     - Asset name is "PdfToImageConverter-Full.zip"
   - Generate the proxy object

2. Create an instance of the converter:
   ```powerbuilder
   nvo_pdfconverter lnvo_pdfconverter // if you use other name for the proxy object need to change the name in the code
   lnvo_pdfconverter = Create nvo_pdfconverter 
   ```
   but PB IDE automatic created proxy object name and function name shown as readme example

3. Convert PDF to PNG:
   ```powerbuilder
   string ls_result
   ls_result = lnvo_pdfconverter.of_convertpdftoimage("C:\input.pdf", "C:\output.png", 300)
   
   if Left(ls_result, 7) = "SUCCESS" then
       MessageBox("Success", ls_result)
   else
       MessageBox("Error", ls_result)
   end if
   ```

4. Convert PDF to PNG with page names:
   ```powerbuilder
   string ls_result
   string ls_page_names[]
   ls_page_names[1] = "Apple"
   ls_page_names[2] = "Banana"
   ls_result = lnvo_pdfconverter.of_ConvertPdfToImageWithPageNames("C:\input.pdf", "C:\output.png", 300, 2, ls_page_names)
   ```

5. Convert PDF to PNG with page names and custom output paths:
   ```powerbuilder
   string ls_result
   string ls_page_names[]
   string ls_output_paths[]
   ls_page_names[1] = "Apple"
   ls_page_names[2] = "Banana"
   ls_output_paths[1] = "C:\output\folder1"
   ls_output_paths[2] = "C:\output\folder2"
   ls_result = lnvo_pdfconverter.of_ConvertPdfToImageWithPageNamesAndOutputPaths("C:\input.pdf", "C:\output.png", 300, 2, ls_page_names, ls_output_paths)
   ```

## Parameters

- `pdfPath`: Full path to the input PDF file
- `outputPath`: Full path for the output PNG file
- `dpi`: Optional. DPI value for the output image (default: 300)

for `ConvertPdfToImageWithPageNames` method required some additional parameters:
- `totalPagesNumber`: Total number of pages in the PDF
- `pageNames`: Array of page names for the output images

for `ConvertPdfToImageWithPageNamesAndOutputPaths` method required these parameters:
- `outputPaths`: Array of output directory names for each page
- `totalPagesNumber`: Total number of pages in the PDF
- `pageNames`: Array of page names for the output images

## Multi-page PDFs

When converting multi-page PDFs, the library will automatically append page numbers to the output filename:
- Single page: `output.png`
- Multi-page: `output_page1.png`, `output_page2.png`, etc.

If you want to use your own page names, you can use `ConvertPdfToImageWithPageNames` method.
- Ensure the `totalPagesNumber` is correct
- Ensure the `pageNames` array is the same size as the number of pages in the PDF
- then you got specific page names for each page like
  - `Apple.png`
  - `Banana.png`

If you want to specify custom output paths for each page, you can use `ConvertPdfToImageWithPageNamesAndOutputPaths` method.
- Ensure the `outputPaths` array contains valid directory paths for each page
- Ensure the `pageNames` array contains the desired filenames for each page
- then you got specific page names in specific folders like
  - `C:\output\folder1\Apple.png`
  - `C:\output\folder2\Banana.png`

## Deployment

### Windows PowerBuilder
- Deploy the .NET Framework 4.8.1 version (net481)
- Register with regasm.exe for COM visibility
- Include all managed dependencies

### Cross-Platform .NET Applications
For cross-platform deployment, use the published self-contained versions which include all native dependencies:

- **Windows**: Include libpdfium.dll and libSkiaSharp.dll
- **macOS**: Include libpdfium.dylib and libSkiaSharp.dylib

The `--self-contained` publish option automatically includes these dependencies.

## Error Handling

The conversion method returns a string starting with either "SUCCESS" or "ERROR" followed by additional details. Make sure to handle both cases in your PowerBuilder code as shown in the usage example above. 

## Acknowledgements

- [PDFtoImage](https://github.com/sungaila/PDFtoImage) for the PDF conversion library


Certainly! Here’s a COM-based usage example you can add to your README for users who want to use the PDF-Image Converter .NET DLL via COM (e.g., from VBScript, VBA, or other COM-aware environments).

---

## Usage via COM (VBScript Example)

If you want to use the PDF-Image Converter library from a COM-based language (like VBScript, VBA, or classic ASP), make sure the DLL is registered as a COM-visible assembly.  
You must register the DLL using regasm.exe and ensure all dependencies are available.

### 1. Register the DLL for COM

Open a command prompt as Administrator and run:
```shell
regasm PdfToImageConverter.dll /codebase
```

If you need to create a type library (.tlb):
```shell
regasm PdfToImageConverter.dll /codebase /tlb:PdfToImageConverter.tlb
```
> Note: On 64-bit Windows, use the 64-bit regasm.exe for 64-bit clients, and the 32-bit version for 32-bit clients.

### 2. Example Usage in VBScript

Create a file named convert_pdf.vbs with the following contents:
```vbscript
' Create the COM object
Set converter = CreateObject("PdfToImageConverter.PdfConverter")

' Convert a PDF to PNG
pdfPath = "C:\input.pdf"
outputPath = "C:\output.png"
dpi = 300

result = converter.ConvertPdfToImage(pdfPath, outputPath, dpi)

If Left(result, 7) = "SUCCESS" Then
    MsgBox "Success: " & result
Else
    MsgBox "Error: " & result
End If
```

### 3. Example Usage in VBA (e.g., Excel Macro)

```vba
Sub ConvertPDF()
    Dim converter As Object
    Set converter = CreateObject("PdfToImageConverter.PdfConverter")
    
    Dim pdfPath As String
    Dim outputPath As String
    Dim dpi As Integer
    Dim result As String

    pdfPath = "C:\input.pdf"
    outputPath = "C:\output.png"
    dpi = 300

    result = converter.ConvertPdfToImage(pdfPath, outputPath, dpi)

    If Left(result, 7) = "SUCCESS" Then
        MsgBox "Success: " & result
    Else
        MsgBox "Error: " & result
    End If
End Sub
```

### 4. Notes

- The ProgID/class name (`PdfToImageConverter.PdfConverter`) may differ depending on your assembly’s namespace and class.  
  Check your DLL's exposed class name or use OLE/COM Object Viewer to confirm.
- You must ensure the assembly is registered as COM visible and all dependencies are present.
- For advanced functions (like page names or custom output paths), you may need to pass arrays.  
  COM clients like VBScript may not support passing arrays easily—consider using PowerBuilder or .NET clients for those features.

---

Would you like a sample for another COM-capable language or more details on DLL registration?
