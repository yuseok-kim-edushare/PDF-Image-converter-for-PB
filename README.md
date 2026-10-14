# PDF to Image Converter .NET Library For PowerBuilder

This is a .NET library that converts PDF files to PNG images while maintaining the original PDF dimensions. </br>
The library is specifically designed to be used with PowerBuilder applications. </br>
but other COM or anyway to invoke .NET(C#) DLL invoking way can works

[![CI tests](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml)
[![local CI tests with Powerbuilder](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci-pb.yaml)

## Features

- Convert PDF files to PNG images
- Maintains original PDF dimensions
- Supports multi-page PDFs
- Configurable DPI settings
- .NET Framework 4.8.1 COM library for PowerBuilder .NET DLL Importer
- .NET 10 managed DLL
- .NET 10 Native AOT library for Windows x86/x64/arm64 and macOS/iOS interop

## Requirements

- .NET 10 SDK
- .NET Framework 4.8.1 targeting pack, for the COM build
- PowerBuilder 2019 R3 or later for the .NET DLL Importer sample

## Building the Library

```powershell
dotnet build PdfToImageConverter.slnx --configuration Release
dotnet test tests\PdfToImageConverter.Tests\PdfToImageConverter.Tests.csproj --configuration Release
```

Windows release layout (Framework, .NET 10 managed, and Native AOT):

```powershell
./scripts/publish-windows.ps1
```

Apple Native AOT frameworks are packaged on macOS:

```bash
bash scripts/package-apple-xcframework.sh artifacts/release
```

## Deployment layouts

- `net481/win-x86/`: delay-signed inputs are ILRepack-merged into one COM DLL, plus `pdfium.dll` and `libSkiaSharp.dll`
- `net10/managed/{rid}/`: ordinary .NET 10 DLL. Windows RIDs are `win-x86`, `win-x64`, and `win-arm64`. macOS RIDs are `osx-x64` and `osx-arm64`. Platform assemblies are `net10.0-ios`, `net10.0-macos`, and `net10.0-maccatalyst`
- `native-aot/win-x86`, `win-x64`, `win-arm64`: stdcall exports. Keep `pdfium.dll` and `libSkiaSharp.dll` beside `PdfToImageConverter.dll`
- `native-aot/osx-x64`, `osx-arm64`: `PdfToImageConverter.dylib` with PDFium and Skia beside it
- `apple/PdfToImageConverter.xcframework`, `apple/pdfium.xcframework`, `apple/libSkiaSharp.xcframework`: iOS device, iOS simulator, and Mac Catalyst

## Usage in PowerBuilder

1. Use PowerBuilder's ".NET DLL Importer" tool to import the assembly:
   - Open your PowerBuilder project
   - Select Tools → ".NET DLL Importer"
   - Browse to and select "PdfToImageConverter.dll"
     - Un-Zip release assets and select `net481/win-x86/PdfToImageConverter.dll` from "PdfToImageConverter-Full.zip"
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

## Error Handling

The conversion method returns a string starting with either "SUCCESS" or "ERROR" followed by additional details. Make sure to handle both cases in your PowerBuilder code as shown in the usage example above.

## .NET 10 managed DLL

Publish without Native AOT and reference `PdfToImageConverter.dll` from a .NET 10 app. Place the RID's `pdfium` and `libSkiaSharp` native library next to the application.

```powershell
dotnet publish src\PdfToImageConverter\PdfToImageConverter.csproj -f net10.0 -r win-x64 -c Release -o .\publish\net10\managed\win-x64
```

`PdfConverter` is a normal public class. It is not COM-visible on .NET 10. The three methods and their `SUCCESS:` / `Error:` strings are the same as the Framework library.

## Native AOT

Native AOT publishes a shared library. Windows exports use stdcall. Apple exports use the platform C calling convention. Strings are UTF-16 (`char16_t` in `include/PdfToImageConverter.h`, not Apple `wchar_t`).

```powershell
dotnet publish src\PdfToImageConverter\PdfToImageConverter.csproj -f net10.0 -r win-x64 -c Release -p:NativeAot=true -o .\publish\native-aot\win-x64
```

Return `0` on success, `-1` for a null path, and `-2` when conversion fails. The managed `SUCCESS:` / `Error:` text is written into a caller-allocated UTF-16 buffer. Page names and output folders are one UTF-16 string separated by line breaks.

PowerBuilder external functions, for a DLL whose bitness matches the application:

```powerbuilder
FUNCTION long ConvertPdfToImage(string pdfPath, string outputPath, long dpi, ref string message, long messageChars) LIBRARY "PdfToImageConverter.dll"
FUNCTION long ConvertPdfToImageWithPageNames(string pdfPath, string outputPath, long dpi, long totalPages, string pageNames, ref string message, long messageChars) LIBRARY "PdfToImageConverter.dll"
FUNCTION long ConvertPdfToImageWithPageNamesAndOutputPaths(string pdfPath, string outputPath, long dpi, long totalPages, string pageNames, string pagePaths, ref string message, long messageChars) LIBRARY "PdfToImageConverter.dll"
```

```powerbuilder
string ls_message
ls_message = Space(2048)
long ll_code
ll_code = ConvertPdfToImage("C:\input.pdf", "C:\output.png", 300, ls_message, 2048)
```

Join page names with `~n`, for example `"Apple~nBanana"`. Do not add `CDECL` on Windows. `samples/CppSample` loads the same stdcall export with `LoadLibraryW`.

The existing PowerBuilder test executable still loads the .NET Framework DLL through `nvo_pdfconverter`. Rebuild that executable in the PowerBuilder IDE only if you switch the test application to these external functions.

iOS and Mac Catalyst apps embed `PdfToImageConverter.xcframework`, `pdfium.xcframework`, and `libSkiaSharp.xcframework`.

## Acknowledgements

- [PDFtoImage](https://github.com/sungaila/PDFtoImage) for the PDF conversion library

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
