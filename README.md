# PDF to Image Converter .NET Library For PowerBuilder

This is a .NET library that converts PDF files to PNG images while maintaining the original PDF dimensions. The library is specifically designed to be used with PowerBuilder applications.

[![CI tests](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml)
[![CI tests with Powerbuilder(local)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci.yaml/badge.svg)](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB/actions/workflows/ci-pb.yaml)

## Features

- Convert PDF files to PNG images
- Maintains original PDF dimensions
- Supports multi-page PDFs
- Configurable DPI settings
- COM-visible for use in PowerBuilder

## Requirements

- .NET Framework 4.8.1 SDK for Development with build tool(select 1 of 2 options)
   - Visual Studio 2019 or later for building the library
   - .NET 8 SDK for building the library
- PowerBuilder 2019 R3 or later

## Building the Library

1. Open the solution in Visual Studio
2. Build the solution in Release mode
3. if you want to build with dotnet cli(cause of not having visual studio)
   ```powershell
   dotnet build PdfToImageConverter.csproj --configuration Release
   ```

## Usage in PowerBuilder

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

## Parameters

- `pdfPath`: Full path to the input PDF file
- `outputPath`: Full path for the output PNG file
- `dpi`: Optional. DPI value for the output image (default: 300)

for `ConvertPdfToImageWithPageNames` method required some additional parameters:
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

## Error Handling

The conversion method returns a string starting with either "SUCCESS" or "ERROR" followed by additional details. Make sure to handle both cases in your PowerBuilder code as shown in the usage example above. 

## Acknowledgements

- [PDFtoImage](https://github.com/sungaila/PDFtoImage) for the PDF conversion library
