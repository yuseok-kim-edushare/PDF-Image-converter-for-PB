# Test script for PDF to Image Converter

# Kill any running instances of the test
Get-Process | Where-Object {$_.ProcessName -like "*PdfToImageConverter*" -or $_.ProcessName -like "*RegAsm*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Clean up existing files
Remove-Item -Path ".\*.dll" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\de" -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# copy debug artifacts to test folder
try {
    # First try to copy PdfSharp.dll
    Copy-Item -Path "..\bin\debug\PdfSharp.dll" -Destination ".\" -Force
    Start-Sleep -Seconds 1
    
    # Then copy the converter DLL
    Copy-Item -Path "..\bin\debug\PdfToImageConverter.dll" -Destination ".\" -Force
    
    # Create new 'de' directory and copy contents
    New-Item -ItemType Directory -Path ".\de" -Force | Out-Null
    Copy-Item -Path "..\bin\debug\de\*" -Destination ".\de\" -Force
} catch {
    Write-Host "Warning: Some files could not be copied: $_"
    Write-Host "Trying alternative copy method..."
    Start-Sleep -Seconds 2
    
    # Try robocopy as an alternative
    robocopy "..\bin\debug" "." "*.dll" /R:3 /W:1
}

# Verify DLLs exist
Write-Host "`nVerifying DLLs:"
$dlls = @("PdfSharp.dll", "PdfToImageConverter.dll")
foreach ($dll in $dlls) {
    $exists = Test-Path $dll
    Write-Host "$dll exists: $exists"
    if ($exists) {
        $fileInfo = Get-Item $dll
        Write-Host "Size: $($fileInfo.Length) bytes"
        Write-Host "Last Modified: $($fileInfo.LastWriteTime)"
    }
}

# Register the COM object
try {
    Write-Host "`nRegistering COM object..."
    $regasmOutput = & "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe" "PdfToImageConverter.dll" /codebase
    Write-Host $regasmOutput
} catch {
    Write-Host "Error registering COM object: $_"
    exit 1
}

# Test parameters - adjust these paths as needed
$pdfPath = Join-Path $PSScriptRoot "test.pdf"  # PDF file in the same directory as the script
$outputPath = Join-Path $PSScriptRoot "output.png"
$dpi = 300

# Display file information
Write-Host "`nTest Configuration:"
Write-Host "PDF Path: $pdfPath"
Write-Host "Output Path: $outputPath"
Write-Host "DPI: $dpi"
Write-Host "PDF exists: $(Test-Path $pdfPath)"

if (Test-Path $pdfPath) {
    $pdfInfo = Get-Item $pdfPath
    Write-Host "PDF File Size: $($pdfInfo.Length) bytes"
    Write-Host "PDF Last Modified: $($pdfInfo.LastWriteTime)"
}

Write-Host "`nOutput directory info:"
$outputDir = Split-Path $outputPath -Parent
Write-Host "Output directory: $outputDir"
Write-Host "Directory exists: $(Test-Path $outputDir)"
Write-Host "Directory is writable: $((Get-Acl $outputDir).AccessToString)"

# Create COM object
$converter = $null
try {
    $converter = New-Object -ComObject PdfToImageConverter.PdfConverter
    Write-Host "`nSuccessfully created COM object"

    # Convert PDF to image
    Write-Host "Starting conversion..."
    $result = $converter.ConvertPdfToImage($pdfPath, $outputPath, $dpi)
    Write-Host "Conversion result: $result"

    # Check if output was created
    if (Test-Path $outputPath) {
        $outputInfo = Get-Item $outputPath
        Write-Host "Output file created: $($outputInfo.Length) bytes"
    } else {
        Write-Host "Warning: Output file was not created"
    }

} catch {
    Write-Host "Error: $_"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
} finally {
    if ($converter) {
        # Properly release COM object
        try {
            [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($converter) | Out-Null
        } catch {
            Write-Host "Note: COM object already released"
        }
        $converter = $null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    # Unregister the COM object
    try {
        Write-Host "`nUnregistering COM object..."
        $unregisterOutput = & "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe" "PdfToImageConverter.dll" /unregister
        Write-Host $unregisterOutput
    } catch {
        Write-Host "Error unregistering COM object: $_"
    }
} 
