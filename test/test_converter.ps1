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
    # Copy all DLL files from debug folder
    Copy-Item -Path "..\bin\debug\*.dll" -Destination ".\" -Force
    Start-Sleep -Seconds 1
    
    # Create new 'de' directory and copy contents if they exist
    if (Test-Path "..\bin\debug\de") {
        New-Item -ItemType Directory -Path ".\de" -Force | Out-Null
        Copy-Item -Path "..\bin\debug\de\*" -Destination ".\de\" -Force
    }
} catch {
    Write-Host "Warning: Some files could not be copied: $_"
    Write-Host "Trying alternative copy method..."
    Start-Sleep -Seconds 2
    
    # Try robocopy as an alternative for all DLLs
    robocopy "..\bin\debug" "." "*.dll" /R:3 /W:1
    if (Test-Path "..\bin\debug\de") {
        robocopy "..\bin\debug\de" ".\de" /E /R:3 /W:1
    }
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

# List all DLLs in debug folder before copying
Write-Host "`nListing DLLs in debug folder:"
Get-ChildItem -Path "..\bin\debug\*.dll" | ForEach-Object {
    Write-Host $_.Name
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
    Write-Host "`nAttempting to create COM object..."
    
    # First verify the type is registered
    $type = [Type]::GetTypeFromProgID("PdfToImageConverter.PdfConverter")
    if ($type -eq $null) {
        Write-Host "Error: COM type not found in registry. Registration may have failed."
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
    Write-Host "Output Path: $outputPath"
    Write-Host "DPI: $dpi"
    
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
    Write-Host "`nError Details:"
    Write-Host "Error Message: $($_.Exception.Message)"
    Write-Host "Error Type: $($_.Exception.GetType().FullName)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    
    # Get more details about COM registration
    Write-Host "`nChecking COM registration details:"
    $regPath = "HKLM:\SOFTWARE\Classes\PdfToImageConverter.PdfConverter"
    if (Test-Path $regPath) {
        Get-ItemProperty $regPath | Format-List
    } else {
        Write-Host "COM registration not found in registry"
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
        $unregisterOutput = & "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe" "PdfToImageConverter.dll" /unregister
        Write-Host $unregisterOutput
    } catch {
        Write-Host "Error unregistering COM object: $_"
    }
} 
