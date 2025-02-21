# Test script for PDF to Image Converter - Combined Tests

# Force PowerShell to run in 32-bit mode
if (-not [Environment]::Is64BitProcess) {
    Write-Host "Already running in 32-bit mode"
} else {
    Write-Host "Restarting script in 32-bit PowerShell..."
    if ($MyInvocation.MyCommand.Path) {
        & "$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -File $MyInvocation.MyCommand.Path
        exit $LASTEXITCODE
    }
}

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
        
        Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force
        Write-Host "Successfully copied files from $source" -ForegroundColor Green
        
        # Copy x86 native DLLs to root
        if (Test-Path "$destination\x86") {
            Write-Host "Copying x86 native DLLs to root..."
            Copy-Item -Path "$destination\x86\*.dll" -Destination $destination -Force
            Write-Host "Copied x86 native DLLs"
        }
        
        # List all copied files
        Write-Host "`nFiles in destination:"
        Get-ChildItem -Path $destination -Filter "*.dll" | ForEach-Object {
            Write-Host $_.FullName
        }
        return $true
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

# Clean up platform-specific directories
Write-Host "`nCleaning up platform directories..."
@("arm", "arm64", "musl-arm64", "musl-x64", "musl-x86", "win-x86", "x64", "x86") | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item -Path $_ -Recurse -Force
        Write-Host "Removed $_"
    }
}

# Verify DLLs exist and show all DLLs in directory
Write-Host "`nVerifying DLLs:"
Get-ChildItem -Filter "*.dll" | ForEach-Object {
    Write-Host "$($_.Name) exists: True"
    Write-Host "Size: $($_.Length) bytes"
    Write-Host "Last Modified: $($_.LastWriteTime)"
}

# Register the COM object
try {
    Write-Host "`nRegistering COM object..."
    Write-Host "Current process is 32-bit: $(-not [Environment]::Is64BitProcess)"
    
    $regasmPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\RegAsm.exe"
    
    if (!(Test-Path $regasmPath)) {
        Write-Host "RegAsm.exe not found at expected path." -ForegroundColor Red
        exit 1
    }
    
    $dllPath = Join-Path $PSScriptRoot "PdfToImageConverter.dll"
    $dllPath = [System.IO.Path]::GetFullPath($dllPath)
    Write-Host "DLL Full Path: $dllPath"
    
    # First unregister if it exists (try both 32-bit and 64-bit unregister to be safe)
    Write-Host "Unregistering existing COM object..."
    & "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\RegAsm.exe" $dllPath /unregister /verbose 2>&1 | ForEach-Object { Write-Host $_ }
    & $regasmPath $dllPath /unregister /verbose 2>&1 | ForEach-Object { Write-Host $_ }
    Start-Sleep -Seconds 1
    
    # Register the COM object with full path
    Write-Host "Registering COM object with 32-bit RegAsm..."
    $regasmOutput = & $regasmPath $dllPath /codebase /tlb /verbose
    Write-Host $regasmOutput
    Start-Sleep -Seconds 1

    # Verify registration in registry
    Write-Host "`nVerifying COM registration..."
    $clsid = "{02FCF9B4-E978-4FE0-B5F3-F66F11B30AE7}"
    $regPath = "HKCR\CLSID\$clsid"
    
    if (Test-Path "Registry::$regPath") {
        Write-Host "COM object found in registry at: $regPath"
        Get-Item "Registry::$regPath" | Select-Object -ExpandProperty Property | ForEach-Object {
            $value = (Get-ItemProperty "Registry::$regPath").$_
            Write-Host "$_ = $value"
        }

        # Check InprocServer32 registration
        $inprocPath = "Registry::$regPath\InprocServer32"
        if (Test-Path $inprocPath) {
            Write-Host "`nInprocServer32 registration:"
            Get-Item $inprocPath | Select-Object -ExpandProperty Property | ForEach-Object {
                $value = (Get-ItemProperty $inprocPath).$_
                Write-Host "$_ = $value"
            }
        } else {
            Write-Host "InprocServer32 key not found!" -ForegroundColor Red
        }
    } else {
        Write-Host "COM object not found in registry!" -ForegroundColor Red
    }

    # Verify runtime environment
    Write-Host "`nRuntime Environment:"
    Write-Host "Is 64-bit OS: $([Environment]::Is64BitOperatingSystem)"
    Write-Host "Is 64-bit Process: $([Environment]::Is64BitProcess)"
    Write-Host "Runtime Directory: $([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())"
    Write-Host "Current Directory: $(Get-Location)"
    
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

# Create COM object and run tests
try {
    Write-Host "`nCreating COM object..."
    Write-Host "Attempting to create COM object with ProgID: PdfToImageConverter.PdfConverter"
    $converter = New-Object -ComObject "PdfToImageConverter.PdfConverter"
    Write-Host "Successfully created COM object"

    # Test 1: Basic PDF to Image conversion
    Write-Host "`n=== Running Test 1: Basic PDF to Image Conversion ==="
    Write-Host "Starting conversion..."
    $result = $converter.ConvertPdfToImage($pdfPath, $outputBasePath, $dpi)
    Write-Host "Conversion result: $result"

    # Test 2: PDF to Image conversion with page names
    Write-Host "`n=== Running Test 2: PDF to Image Conversion with Page Names ==="
    Write-Host "Starting conversion..."
    $result = $converter.ConvertPdfToImageWithPageNames($pdfPath, $outputBasePath, $dpi, $totalPagesNumber, $pageNames)
    Write-Host "Conversion result: $result"
} catch {
    Write-Host "Error in tests:" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)"
    Write-Host "Error Type: $($_.Exception.GetType().FullName)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
} 
