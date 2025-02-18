# Test script for PDF to Image Converter with Page Names

# Kill any running instances of the test
Get-Process | Where-Object {$_.ProcessName -like "*PdfToImageConverter*" -or $_.ProcessName -like "*RegAsm*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Clean up existing files
Remove-Item -Path ".\*" -Include "*.dll","*.pdb","*.xml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\de" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\runtimes" -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Define source and destination paths
$sourceDir = "..\bin\Debug\net481"
$destDir = "."

Write-Host "`nCopying build artifacts from: $sourceDir"
Write-Host "To: $destDir"

# Function to copy files with detailed logging
function Copy-WithLogging {
    param (
        [string]$source,
        [string]$destination,
        [string]$filter = "*"
    )
    
    Write-Host "Copying from $source to $destination"
    if (!(Test-Path $source)) {
        Write-Host "Source path does not exist: $source" -ForegroundColor Red
        return $false
    }
    
    try {
        if (!(Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Write-Host "Created directory: $destination"
        }
        
        $robocopyArgs = @(
            $source
            $destination
            $filter
            "/E"
            "/R:3"
            "/W:1"
            "/NFL"
            "/NDL"
            "/NJH"
            "/NJS"
        )
        
        $result = Start-Process "robocopy" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
        
        if ($result.ExitCode -lt 8) {
            Write-Host "Successfully copied files from $source" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Error copying files from $source. Exit code: $($result.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error copying files: $_" -ForegroundColor Red
        return $false
    }
}

# Copy all build artifacts
$copySuccess = Copy-WithLogging -source $sourceDir -destination $destDir

if (!$copySuccess) {
    Write-Host "Failed to copy build artifacts. Aborting test." -ForegroundColor Red
    exit 1
}

# Register the COM object
try {
    Write-Host "`nRegistering COM object..."
    $regasmPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe"
    if (!(Test-Path $regasmPath)) {
        Write-Host "RegAsm.exe not found at expected path. Trying 32-bit path..." -ForegroundColor Yellow
        $regasmPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\RegAsm.exe"
    }
    
    if (!(Test-Path $regasmPath)) {
        Write-Host "RegAsm.exe not found. Cannot register COM object." -ForegroundColor Red
        exit 1
    }
    
    $regasmOutput = & $regasmPath "PdfToImageConverter.dll" /codebase
    Write-Host $regasmOutput
} catch {
    Write-Host "Error registering COM object: $_" -ForegroundColor Red
    exit 1
}

# Test parameters
$pdfPath = Join-Path $PSScriptRoot "test.pdf"
$outputBasePath = Join-Path $PSScriptRoot "output.png"
$dpi = 300
$totalPagesNumber = 2  # Our test.pdf has 2 pages
$pageNames = @("Apple", "Banana")  # Example page names

# Display test configuration
Write-Host "`nTest Configuration:"
Write-Host "PDF Path: $pdfPath"
Write-Host "Output Base Path: $outputBasePath"
Write-Host "DPI: $dpi"
Write-Host "Total PDF Pages: $totalPagesNumber"
Write-Host "Page Names: $($pageNames -join ', ')"
Write-Host "PDF exists: $(Test-Path $pdfPath)"

# Create COM object and run test
$converter = $null
try {
    Write-Host "`nCreating COM object..."
    $converter = New-Object -ComObject PdfToImageConverter.PdfConverter
    Write-Host "Successfully created COM object"

    # Convert PDF to image with page names
    Write-Host "`nStarting conversion..."
    $result = $converter.ConvertPdfToImageWithPageNames($pdfPath, $outputBasePath, $dpi, $totalPagesNumber, $pageNames)
    Write-Host "Conversion result: $result"

    # Check for generated output file
    Write-Host "`nChecking generated output files:"
    $outputDir = Split-Path $outputBasePath -Parent
    $outputExt = [System.IO.Path]::GetExtension($outputBasePath)
    
    # Get all generated output files
    $outputFiles = Get-ChildItem -Path $outputDir -Filter "*$outputExt"
    
    if ($outputFiles.Count -gt 0) {
        Write-Host "Found $($outputFiles.Count) output files:"
        foreach ($file in $outputFiles) {
            Write-Host "- $($file.Name): $($file.Length) bytes"
        }
    } else {
        Write-Host "Warning: No output files were created" -ForegroundColor Yellow
    }

} catch {
    Write-Host "`nError Details:" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)"
    Write-Host "Error Type: $($_.Exception.GetType().FullName)"
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
        $unregisterOutput = & $regasmPath "PdfToImageConverter.dll" /unregister
        Write-Host $unregisterOutput
    } catch {
        Write-Host "Error unregistering COM object: $_" -ForegroundColor Red
    }
} 