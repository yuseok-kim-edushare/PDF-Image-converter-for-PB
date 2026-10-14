// Loads the Native AOT PdfToImageConverter.dll and calls ConvertPdfToImage (stdcall, UTF-16).
//
// Publish first:
//   dotnet publish ..\..\src\PdfToImageConverter\PdfToImageConverter.csproj -f net10.0 -r win-x64 -c Release -p:NativeAot=true -o .\publish
// Copy pdfium.dll and libSkiaSharp.dll next to PdfToImageConverter.dll.
//
// Usage:
//   PdfToImageCppSample.exe <input.pdf> <output.png> [dpi]

#include <windows.h>
#include <cstdio>
#include <cwchar>

typedef int(__stdcall* ConvertPdfToImageFn)(
    const wchar_t* pdfPath,
    const wchar_t* outputPath,
    int dpi,
    wchar_t* messageBuf,
    int messageBufChars);

int wmain(int argc, wchar_t* argv[])
{
    if (argc < 3)
    {
        wprintf(L"Usage: PdfToImageCppSample.exe <input.pdf> <output.png> [dpi]\n");
        return 1;
    }

    const wchar_t* pdfPath = argv[1];
    const wchar_t* outputPath = argv[2];
    int dpi = (argc > 3) ? _wtoi(argv[3]) : 300;

    HMODULE module = LoadLibraryW(L"PdfToImageConverter.dll");
    if (module == nullptr)
    {
        wprintf(L"Failed to load PdfToImageConverter.dll (error %lu)\n", GetLastError());
        return 1;
    }

    auto convert = reinterpret_cast<ConvertPdfToImageFn>(GetProcAddress(module, "ConvertPdfToImage"));
    if (convert == nullptr)
    {
        wprintf(L"ConvertPdfToImage was not exported.\n");
        FreeLibrary(module);
        return 1;
    }

    wchar_t message[2048] = {};
    int code = convert(pdfPath, outputPath, dpi, message, 2048);
    wprintf(L"code=%d message=%s\n", code, message);
    FreeLibrary(module);
    return code == 0 ? 0 : 1;
}
