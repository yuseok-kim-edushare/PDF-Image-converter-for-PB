# Test script for PDF to Image Converter - Combined Tests

# Kill any running instances of the test
Get-Process | Where-Object {$_.ProcessName -like "*PdfToImageConverter*" -or $_.ProcessName -like "*RegAsm*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Clean up existing files
Remove-Item -Path ".\*" -Include "*.dll","*.pdb","*.xml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\de" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\runtimes" -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Define source and destination paths
$sourceDir = "..\bin\x86\Debug\net481"
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
        
        # Robocopy success codes are 0-7
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

# Verify DLLs exist and show all DLLs in directory
Write-Host "`nVerifying DLLs:"
Get-ChildItem -Filter "PdfToImageConverter.dll" | ForEach-Object {
    Write-Host "$($_.Name) exists: True"
    Write-Host "Size: $($_.Length) bytes"
    Write-Host "Last Modified: $($_.LastWriteTime)"
    
    try {
        $assembly = [System.Reflection.Assembly]::LoadFile($_.FullName)
        Write-Host "Assembly Full Name: $($assembly.FullName)"
        Write-Host "Runtime Version: $($assembly.ImageRuntimeVersion)"
    } catch {
        Write-Host "Failed to load assembly: $_"
    }
    Write-Host ""
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
    
    # First unregister if it exists
    & $regasmPath "PdfToImageConverter.dll" /unregister 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    
    # Ensure native dependencies are in the current directory
    $nativeDllPath1 = Join-Path $PSScriptRoot "libSkiaSharp.dll"
    if (!(Test-Path $nativeDllPath1)) {
        Write-Host "Error: Could not find native SkiaSharp DLL" -ForegroundColor Red
    }
    $nativeDllPath2 = Join-Path $PSScriptRoot "pdfium.dll"
    if (!(Test-Path $nativeDllPath2)) {
        Write-Host "Error: Could not find native pdfium DLL" -ForegroundColor Red
    }    

    # Register the COM object
    $regasmOutput = & $regasmPath "PdfToImageConverter.dll" /codebase /tlb
    Write-Host $regasmOutput
    Start-Sleep -Seconds 1
} catch {
    Write-Host "Error registering COM object: $_" -ForegroundColor Red
    exit 1
}

# Test parameters
$pdfPath = Join-Path $PSScriptRoot "test.pdf"
$outputBasePath = Join-Path $PSScriptRoot "output.png"
$dpi = 300
$totalPagesNumber = 2  # Our test.pdf has 2 pages
$pageNames = [string[]]@("Apple", "Banana")

# Display test configuration
Write-Host "`nTest Configuration:"
Write-Host "PDF Path: $pdfPath"
Write-Host "Output Base Path: $outputBasePath"
Write-Host "DPI: $dpi"
Write-Host "Total PDF Pages: $totalPagesNumber"
Write-Host "Page Names: $($pageNames -join ', ')"
Write-Host "PDF exists: $(Test-Path $pdfPath)"

if (Test-Path $pdfPath) {
    $pdfInfo = Get-Item $pdfPath
    Write-Host "PDF File Size: $($pdfInfo.Length) bytes"
    Write-Host "PDF Last Modified: $($pdfInfo.LastWriteTime)"
}

Write-Host "`nOutput directory info:"
$outputDir = Split-Path $outputBasePath -Parent
Write-Host "Output directory: $outputDir"
Write-Host "Directory exists: $(Test-Path $outputDir)"
Write-Host "Directory is writable: $((Get-Acl $outputDir).AccessToString)"

# Function to check for errors in test output
function Test-ForErrors {
    param (
        [string[]]$output
    )
    
    $hasErrors = $output | Where-Object { 
        $_ -like "*Error:*" -or 
        $_ -like "*Error processing first page:*" -or
        $_ -like "*Error Type:*"
    }
    
    if ($hasErrors) {
        Write-Error "Test failed with errors:"
        $hasErrors | ForEach-Object { Write-Error $_ }
        return $true
    }
    return $false
}

# Create COM object and run tests
$converter = $null
$testsFailed = $false

try {
    Write-Host "`nCreating COM object..."
    $converter = New-Object -ComObject PdfToImageConverter.PdfConverter
    Write-Host "Successfully created COM object"

    # Test 1: Basic PDF to Image conversion
    Write-Host "`n=== Running Test 1: Basic PDF to Image Conversion ==="
    Write-Host "Starting conversion..."
    $output = @()
    $result = $converter.ConvertPdfToImage($pdfPath, $outputBasePath, $dpi)
    $output += "Conversion result: $result"
    
    if (Test-ForErrors $output) {
        $testsFailed = $true
    } else {
        Write-Host "Test 1 completed successfully"
    }

    # Clean up output files between tests
    Remove-Item -Path "$outputDir\output*.png" -Force -ErrorAction SilentlyContinue
    
    # Test 2: PDF to Image conversion with page names
    Write-Host "`n=== Running Test 2: PDF to Image Conversion with Page Names ==="
    Write-Host "Starting conversion..."
    $output = @()
    
    try {
        Write-Host "Page names type: $($pageNames.GetType().FullName)"
        Write-Host "Page names: $($pageNames -join ', ')"
        
        # Create a strongly-typed string array for COM
        $comArray = [string[]]::new($totalPagesNumber)
        for ($i = 0; $i -lt $totalPagesNumber; $i++) {
            $comArray[$i] = $pageNames[$i]
        }
        
        Write-Host "Calling COM method..."
        # Call the COM method directly with the string array
        $result = $converter.ConvertPdfToImageWithPageNames(
            [string]$pdfPath,
            [string]$outputBasePath,
            [int]$dpi,
            [int]$totalPagesNumber,
            $comArray
        )
        $output += "Conversion result: $result"
    }
    catch {
        Write-Host "Error in Test 2:" -ForegroundColor Red
        Write-Host "Error Message: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)"
        }
        Write-Host "Stack Trace:"
        Write-Host $_.ScriptStackTrace
        $testsFailed = $true
    }
    
    if (Test-ForErrors $output) {
        $testsFailed = $true
    } else {
        Write-Host "Test 2 completed successfully"
    }

    # Check for generated output files
    Write-Host "`nChecking generated output files:"
    $outputFiles = Get-ChildItem -Path $outputDir -Filter "*.png"
    
    if ($outputFiles.Count -gt 0) {
        Write-Host "Found $($outputFiles.Count) output files:"
        foreach ($file in $outputFiles) {
            Write-Host "- $($file.Name): $($file.Length) bytes"
        }
    } else {
        Write-Host "Warning: No output files were created" -ForegroundColor Yellow
        $testsFailed = $true
    }

} catch {
    Write-Host "`nError Details:" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)"
    Write-Host "Error Type: $($_.Exception.GetType().FullName)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    $testsFailed = $true
} finally {
    if ($null -ne $converter) {
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

if ($testsFailed) {
    exit 1
} else {
    Write-Host "`nAll tests completed successfully!" -ForegroundColor Green
    exit 0
} 
