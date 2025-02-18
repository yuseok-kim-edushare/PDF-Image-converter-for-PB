# Test script for PDF to Image Converter

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
        # Create destination if it doesn't exist
        if (!(Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Write-Host "Created directory: $destination"
        }
        
        # Use robocopy for reliable copying
        $robocopyArgs = @(
            $source
            $destination
            $filter
            "/E"      # Copy subdirectories, including empty ones
            "/R:3"    # Number of retries
            "/W:1"    # Wait time between retries
            "/NFL"    # No file list - don't log file names
            "/NDL"    # No directory list - don't log directory names
            "/NJH"    # No job header
            "/NJS"    # No job summary
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
Get-ChildItem -Filter "*.dll" | ForEach-Object {
    Write-Host "$($_.Name) exists: True"
    Write-Host "Size: $($_.Length) bytes"
    Write-Host "Last Modified: $($_.LastWriteTime)"
    
    # Get assembly details
    try {
        $assembly = [System.Reflection.Assembly]::LoadFile($_.FullName)
        Write-Host "Assembly Full Name: $($assembly.FullName)"
        Write-Host "Runtime Version: $($assembly.ImageRuntimeVersion)"
    } catch {
        Write-Host "Failed to load assembly: $_"
    }
    Write-Host ""
}

# Add assembly resolution handler
$assemblyResolver = [System.ResolveEventHandler] {
    param($sender, $args)
    Write-Host "Attempting to resolve assembly: $($args.Name)"
    
    # Check if the DLL exists in the current directory
    $assemblyName = [System.Reflection.AssemblyName]::GetAssemblyName($args.Name)
    $dllPath = Join-Path $PSScriptRoot "$($assemblyName.Name).dll"
    
    if (Test-Path $dllPath) {
        Write-Host "Found assembly at: $dllPath"
        return [System.Reflection.Assembly]::LoadFrom($dllPath)
    }
    
    Write-Host "Assembly not found in current directory"
    return $null
}
[System.AppDomain]::CurrentDomain.add_AssemblyResolve($assemblyResolver)

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

# Test parameters - adjust these paths as needed
$pdfPath = Join-Path $PSScriptRoot "test.pdf"  # PDF file in the same directory as the script
$outputBasePath = Join-Path $PSScriptRoot "output.png"  # Base name for output files
$dpi = 300

# Display file information
Write-Host "`nTest Configuration:"
Write-Host "PDF Path: $pdfPath"
Write-Host "Output Base Path: $outputBasePath"
Write-Host "DPI: $dpi"
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

# Create COM object
$converter = $null
try {
    Write-Host "`nAttempting to create COM object..."
    
    # First verify the type is registered
    $type = [Type]::GetTypeFromProgID("PdfToImageConverter.PdfConverter")
    if ($type -eq $null) {
        Write-Host "Error: COM type not found in registry. Registration may have failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "COM type found in registry: $($type.FullName)"
    
    # Try to create the object
    Write-Host "Creating COM object instance..."
    $converter = New-Object -ComObject PdfToImageConverter.PdfConverter
    Write-Host "Successfully created COM object"

    # Convert PDF to image
    Write-Host "`nStarting conversion..."
    Write-Host "PDF Path: $pdfPath (Exists: $(Test-Path $pdfPath))"
    Write-Host "Output Base Path: $outputBasePath"
    Write-Host "DPI: $dpi"
    
    $result = $converter.ConvertPdfToImage($pdfPath, $outputBasePath, $dpi)
    Write-Host "Conversion result: $result"

    # Check for all generated output files
    Write-Host "`nChecking generated output files:"
    $outputDir = Split-Path $outputBasePath -Parent
    $outputBaseName = [System.IO.Path]::GetFileNameWithoutExtension($outputBasePath)
    $outputExt = [System.IO.Path]::GetExtension($outputBasePath)
    
    # Get all generated output files
    $outputFiles = Get-ChildItem -Path $outputDir -Filter "$outputBaseName*$outputExt"
    
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
    
    # Get more details about COM registration
    Write-Host "`nChecking COM registration details:"
    $regPath = "HKLM:\SOFTWARE\Classes\PdfToImageConverter.PdfConverter"
    if (Test-Path $regPath) {
        Get-ItemProperty $regPath | Format-List
    } else {
        Write-Host "COM registration not found in registry" -ForegroundColor Yellow
    }
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
