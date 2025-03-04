#!/usr/bin/env pwsh
# run_pb_tests.ps1
# PowerShell script to run Powerbuilder tests and validate results

# Set parameters - you can customize these as needed
param(
    [string]$InputPdfPath = "test.pdf",
    [string]$OutputPngPath = "test.png",
    [string]$PbRuntimeDir = "PB2019R3"
)

# Initialize script
$ErrorActionPreference = "Stop"
$filePaths = "$InputPdfPath $OutputPngPath"

# Kill any running instances of the test
Get-Process | Where-Object {$_.ProcessName -like "*PdfToImageConverter*" -or $_.ProcessName -like "*RegAsm*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Clean up existing files
Remove-Item -Path ".\*" -Include "*.dll","*.pdb","*.xml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\de" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\runtimes" -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Define source and destination paths
$sourceDir = "..\bin\Debug\net481\win-x86"
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

# Remove previous test result artifacts
Write-Host "Removing previous PNG files..."
Remove-Item -Path .\*.png -Force -ErrorAction SilentlyContinue

# Show current directory for debugging
Write-Host "Current directory: $(Get-Location)"

# List files before moving
Write-Host "Files in $PbRuntimeDir before moving:"
if (Test-Path -Path .\$PbRuntimeDir\*) {
    Get-ChildItem -Path .\$PbRuntimeDir\* | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No files found in $PbRuntimeDir directory"
}

# Move files from runtime directory to current directory
Write-Host "Moving files from $PbRuntimeDir to current directory..."
if (Test-Path -Path .\$PbRuntimeDir\*) {
    Move-Item -Path .\$PbRuntimeDir\* -Destination .\ -Force
} else {
    Write-Error "No files found in $PbRuntimeDir directory"
    exit 1
}

# List files after moving to verify
Write-Host "Files in current directory after moving:"
Get-ChildItem -Path .\ | ForEach-Object { Write-Host "  $_" }

# Debug information
Write-Host "Running test.exe with arguments: '$filePaths'"

# Run the executable with quoted arguments
try {
    # Try to run the executable directly first
    Write-Host "Starting test.exe process..."
    & .\test.exe $InputPdfPath $OutputPngPath
    $processExitCode = $LASTEXITCODE
    Write-Host "test.exe direct execution exit code: $processExitCode"
} catch {
    Write-Host "Direct execution failed, trying Start-Process: $_"
    try {
        # Fall back to Start-Process without -Wait to avoid hanging
        Start-Process -FilePath .\test.exe -ArgumentList $filePaths
        Write-Host "test.exe process started asynchronously"
    } catch {
        Write-Error "Failed to execute test.exe: $_"
        exit 1
    }
}

# Add a longer delay to ensure file operations are complete
Write-Host "Waiting for file operations to complete..."
Start-Sleep -Seconds 20
Write-Host "Checking for test.ini file after delay..."

# Check for test.ini file details
if (Test-Path -Path .\test.ini) {
    $fileInfo = Get-Item .\test.ini
    Write-Host "test.ini file exists - Size: $($fileInfo.Length) bytes, Last modified: $($fileInfo.LastWriteTime)"
    
    # Try different ways to read the file content
    try {
        $iniContent = Get-Content .\test.ini -Raw -ErrorAction Stop
        Write-Host "INI Content (Get-Content): $iniContent"
    } catch {
        Write-Host "Error reading with Get-Content: $_"
    }
    
    try {
        $iniContent2 = [System.IO.File]::ReadAllText((Resolve-Path .\test.ini))
        Write-Host "INI Content ([System.IO.File]::ReadAllText): $iniContent2"
        
        # If the first reading method failed, use the second method's result
        if ([string]::IsNullOrWhiteSpace($iniContent) -and -not [string]::IsNullOrWhiteSpace($iniContent2)) {
            $iniContent = $iniContent2
        }
    } catch {
        Write-Host "Error reading with [System.IO.File]::ReadAllText: $_"
    }
} else {
    Write-Host "test.ini file does not exist"
    # Search for test.ini in other locations
    $foundFiles = Get-ChildItem -Path .\ -Recurse -Filter "test.ini"
    if ($foundFiles.Count -gt 0) {
        Write-Host "Found test.ini files in other locations:"
        $foundFiles | ForEach-Object { Write-Host "  $($_.FullName)" }
    } else {
        Write-Host "No test.ini files found in any subdirectory"
    }
    exit 1
}

# Check for empty INI content
if ([string]::IsNullOrWhiteSpace($iniContent)) {
    Write-Error "test.ini file exists but is empty or could not be read correctly"
        exit 1
}

# Validate test results
$tests = @('test 1', 'test 2')
$allTestsPassed = $true

foreach ($test in $tests) {
    if ($iniContent -match "\[$test\]([^\[]*)") {
        $section = $Matches[1]
        
        if ($section -match 'Error=(.*)') {
            Write-Error "Test [$test] failed with error: $($Matches[1])"
            $allTestsPassed = $false
        }
        
        if ($section -match 'Result=(.*)') {
            $result = $Matches[1].Trim()
            if ($result -ne 'SUCCESS: PDF converted successfully') {
                Write-Error "Test [$test] failed with unexpected result: $result"
                $allTestsPassed = $false
            } else {
                Write-Host "Test [$test] passed successfully"
            }
        } else {
            Write-Error "Test [$test] has no Result entry"
            $allTestsPassed = $false
        }
    } else {
        Write-Error "Test section [$test] not found in test.ini"
        $allTestsPassed = $false
    }
}

if ($allTestsPassed) {
    Write-Host "All Powerbuilder tests completed successfully"
    exit 0
} else {
    Write-Error "One or more Powerbuilder tests failed"
    exit 1
}
