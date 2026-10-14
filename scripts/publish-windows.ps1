param(
    [string]$Configuration = "Release",
    [string]$OutputRoot = "artifacts/release"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$project = Join-Path $root "src\PdfToImageConverter\PdfToImageConverter.csproj"
$out = Join-Path $root $OutputRoot
$snk = Join-Path $root "PdfToImageConverter.snk"
$nativeNames = @("pdfium.dll", "libSkiaSharp.dll")

function Publish-NativeAotAndManaged {
    param([string]$Rid)
    $managed = Join-Path $out "net10\managed\$Rid"
    $aot = Join-Path $out "native-aot\$Rid"
    dotnet publish $project -f net10.0 -r $Rid -c $Configuration -o $managed
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    dotnet publish $project -f net10.0 -r $Rid -c $Configuration -p:NativeAot=true -o $aot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

dotnet build $project -c $Configuration -f net481
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$buildPath = Join-Path $root "src\PdfToImageConverter\bin\$Configuration\net481\win-x86"
$net481Out = Join-Path $out "net481\win-x86"
New-Item -ItemType Directory -Force -Path $net481Out | Out-Null

$x86Native = Join-Path $buildPath "x86"
if (Test-Path $x86Native) {
    Copy-Item (Join-Path $x86Native "*") $net481Out -Force
}
Get-ChildItem $net481Out -Filter *.so -ErrorAction SilentlyContinue | Remove-Item -Force

$toolPath = Join-Path $env:USERPROFILE ".dotnet\tools"
if (Test-Path $toolPath) {
    $env:PATH = "$toolPath;$env:PATH"
}
if (-not (Get-Command ilrepack -ErrorAction SilentlyContinue)) {
    dotnet tool install -g dotnet-ilrepack
    $env:PATH = "$toolPath;$env:PATH"
}

$managedInputs = @(Get-ChildItem $buildPath -Filter *.dll | Where-Object { $nativeNames -notcontains $_.Name } | ForEach-Object { $_.FullName })
if ($managedInputs.Count -eq 0) {
    throw "No managed DLLs found in $buildPath"
}

$ilArgs = @(
    "/out:$net481Out\PdfToImageConverter.dll",
    "/lib:$buildPath",
    "/targetplatform:v4,C:\Windows\Microsoft.NET\Framework\v4.0.30319",
    "/union",
    "/copyattrs",
    "/internalize",
    "/keyfile:$snk"
) + $managedInputs
& ilrepack @ilArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($rid in @("win-x86", "win-x64", "win-arm64")) {
    Publish-NativeAotAndManaged -Rid $rid
}

$include = Join-Path $out "include"
New-Item -ItemType Directory -Force -Path $include | Out-Null
Copy-Item (Join-Path $root "include\PdfToImageConverter.h") $include -Force
