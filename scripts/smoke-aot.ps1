param(
    [Parameter(Mandatory = $true)][string]$PublishDir,
    [Parameter(Mandatory = $true)][string]$PdfPath
)

$ErrorActionPreference = "Stop"
$PublishDir = (Resolve-Path $PublishDir).Path
$PdfPath = (Resolve-Path $PdfPath).Path
$dll = Join-Path $PublishDir "PdfToImageConverter.dll"
if (-not (Test-Path $dll)) {
    throw "Native AOT library was not published: $dll"
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class PdfConvSmoke {
    [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32", SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr module, string name);
    [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Unicode)]
    public delegate int ConvertPdfToImage(string pdfPath, string outputPath, int dpi, StringBuilder message, int messageChars);
}
"@

$module = [PdfConvSmoke]::LoadLibrary($dll)
if ($module -eq [IntPtr]::Zero) {
    throw "LoadLibrary failed for $dll (Win32 $($([Runtime.InteropServices.Marshal]::GetLastWin32Error())))"
}

$exports = @(
    "ConvertPdfToImage",
    "ConvertPdfToImageWithPageNames",
    "ConvertPdfToImageWithPageNamesAndOutputPaths"
)
foreach ($name in $exports) {
    $ptr = [PdfConvSmoke]::GetProcAddress($module, $name)
    if ($ptr -eq [IntPtr]::Zero) {
        throw "Export $name was not found"
    }
    Write-Host "export $name"
}

$outDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfconv-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $outDir | Out-Null
$outFile = Join-Path $outDir "output.png"
$fnPtr = [PdfConvSmoke]::GetProcAddress($module, "ConvertPdfToImage")
$fn = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($fnPtr, [PdfConvSmoke+ConvertPdfToImage])
$message = New-Object System.Text.StringBuilder 2048
$code = $fn.Invoke($PdfPath, $outFile, 72, $message, 2048)
Write-Host "code=$code"
Write-Host "message=$($message.ToString())"
if ($code -ne 0) {
    throw "ConvertPdfToImage failed: $($message.ToString())"
}
$png = Get-ChildItem $outDir -Filter *.png
if (-not $png) {
    throw "Conversion reported success but wrote no PNG files"
}
Write-Host "wrote $($png.Name)"
