#!/usr/bin/env bash
# Publish Native AOT slices for macOS, iOS, and Mac Catalyst, then pack xcframeworks.
# Usage: scripts/package-apple-xcframework.sh [output-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/src/PdfToImageConverter/PdfToImageConverter.csproj"
OUT="${1:-$ROOT/artifacts/release}"
NUGET="${NUGET_PACKAGES:-$HOME/.nuget/packages}"
VERSION="1.3.2"

publish_rid() {
  local rid="$1"
  local dest="$OUT/native-aot/$rid"
  mkdir -p "$dest"
  extra=()
  if [[ "$rid" == osx-* ]]; then
    extra+=(-p:UseMonoRuntime=false)
  fi
  dotnet publish "$PROJECT" -f net10.0 -r "$rid" -c Release -p:NativeAot=true "${extra[@]}" -o "$dest"
  copy_natives "$rid" "$dest"
}

copy_natives() {
  local rid="$1"
  local dest="$2"
  local pkg
  for pkg in bblanchon.pdfium.macos bblanchon.pdfium.ios skiasharp.nativeassets.macos skiasharp.nativeassets.ios skiasharp.nativeassets.maccatalyst; do
    if [[ -d "$NUGET/$pkg" ]]; then
      find "$NUGET/$pkg" -type f \( -name 'libpdfium.dylib' -o -name 'libSkiaSharp.dylib' -o -name 'pdfium.dylib' \) | while read -r file; do
        case "$file" in
          *"/$rid/"*) cp -f "$file" "$dest/" ;;
        esac
      done
    fi
  done
}

dylib_path() {
  local dir="$1"
  local preferred="$2"
  if [[ -f "$dir/$preferred" ]]; then
    echo "$dir/$preferred"
    return
  fi
  local found
  found="$(find "$dir" -maxdepth 1 -name '*.dylib' ! -name 'libpdfium.dylib' ! -name 'libSkiaSharp.dylib' ! -name 'pdfium.dylib' | head -n 1)"
  if [[ -z "$found" ]]; then
    echo "missing dylib in $dir" >&2
    exit 1
  fi
  echo "$found"
}

write_plist() {
  local dest="$1"
  local name="$2"
  cat > "$dest" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${name}</string>
    <key>CFBundleIdentifier</key>
    <string>com.yuseok.${name}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF
}

prepare_ios_slice() {
  local src="$1"
  local id_name="$2"
  install_name_tool -id "@rpath/${id_name}.framework/${id_name}" "$src"
  if otool -l "$src" | grep -q 'path @executable_path '; then
    install_name_tool -rpath @executable_path @executable_path/Frameworks "$src" || true
  fi
}

prepare_catalyst_slice() {
  local src="$1"
  local id_name="$2"
  install_name_tool -id "@rpath/${id_name}.framework/Versions/A/${id_name}" "$src"
  if otool -l "$src" | grep -q 'path @executable_path '; then
    install_name_tool -rpath @executable_path @executable_path/../Frameworks "$src" || true
  fi
}

make_ios_framework() {
  local name="$1"
  local binary="$2"
  local dest="$3"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$binary" "$dest/$name"
  write_plist "$dest/Info.plist" "$name"
  if [[ "$name" == "PdfToImageConverter" ]]; then
    mkdir -p "$dest/Headers"
    cp "$ROOT/include/PdfToImageConverter.h" "$dest/Headers/PdfToImageConverter.h"
  fi
  codesign --force --sign - "$dest"
}

make_catalyst_framework() {
  local name="$1"
  local binary="$2"
  local dest="$3"
  rm -rf "$dest"
  mkdir -p "$dest/Versions/A/Resources"
  cp "$binary" "$dest/Versions/A/$name"
  write_plist "$dest/Versions/A/Resources/Info.plist" "$name"
  ln -sfn A "$dest/Versions/Current"
  ln -sfn Versions/Current/$name "$dest/$name"
  ln -sfn Versions/Current/Resources "$dest/Resources"
  if [[ "$name" == "PdfToImageConverter" ]]; then
    mkdir -p "$dest/Versions/A/Headers"
    cp "$ROOT/include/PdfToImageConverter.h" "$dest/Versions/A/Headers/PdfToImageConverter.h"
    ln -sfn Versions/Current/Headers "$dest/Headers"
  fi
  codesign --force --sign - "$dest"
}

resolve_file() {
  local dir="$1"
  local preferred="$2"
  if [[ -f "$dir/$preferred" ]]; then
    echo "$dir/$preferred"
    return
  fi
  local alt="${preferred#lib}"
  if [[ -f "$dir/lib$alt" ]]; then
    echo "$dir/lib$alt"
    return
  fi
  echo "missing $preferred in $dir" >&2
  exit 1
}

pack_library() {
  local name="$1"
  local file_name="$2"
  local work="$OUT/apple-work/$name"
  mkdir -p "$work"

  local ios_bin sim_arm sim_x64 cat_arm cat_x64
  ios_bin="$(resolve_file "$OUT/native-aot/ios-arm64" "$file_name")"
  sim_arm="$(resolve_file "$OUT/native-aot/iossimulator-arm64" "$file_name")"
  sim_x64="$(resolve_file "$OUT/native-aot/iossimulator-x64" "$file_name")"
  cat_arm="$(resolve_file "$OUT/native-aot/maccatalyst-arm64" "$file_name")"
  cat_x64="$(resolve_file "$OUT/native-aot/maccatalyst-x64" "$file_name")"

  cp "$ios_bin" "$work/ios"
  cp "$sim_arm" "$work/sim-arm64"
  cp "$sim_x64" "$work/sim-x64"
  cp "$cat_arm" "$work/cat-arm64"
  cp "$cat_x64" "$work/cat-x64"
  prepare_ios_slice "$work/ios" "$name"
  prepare_ios_slice "$work/sim-arm64" "$name"
  prepare_ios_slice "$work/sim-x64" "$name"
  prepare_catalyst_slice "$work/cat-arm64" "$name"
  prepare_catalyst_slice "$work/cat-x64" "$name"
  lipo -create "$work/sim-arm64" "$work/sim-x64" -output "$work/simulator"
  lipo -create "$work/cat-arm64" "$work/cat-x64" -output "$work/catalyst"

  make_ios_framework "$name" "$work/ios" "$work/ios.framework"
  make_ios_framework "$name" "$work/simulator" "$work/simulator.framework"
  make_catalyst_framework "$name" "$work/catalyst" "$work/catalyst.framework"

  rm -rf "$OUT/apple/${name}.xcframework"
  xcodebuild -create-xcframework \
    -framework "$work/ios.framework" \
    -framework "$work/simulator.framework" \
    -framework "$work/catalyst.framework" \
    -output "$OUT/apple/${name}.xcframework"
}

add_osx_rpath() {
  local rid="$1"
  local dylib
  dylib="$(dylib_path "$OUT/native-aot/$rid" "PdfToImageConverter.dylib")"
  if ! otool -l "$dylib" | grep -q '@loader_path'; then
    install_name_tool -add_rpath @loader_path "$dylib"
  fi
}

for rid in osx-x64 osx-arm64 ios-arm64 iossimulator-arm64 iossimulator-x64 maccatalyst-arm64 maccatalyst-x64; do
  publish_rid "$rid"
done

add_osx_rpath osx-x64
add_osx_rpath osx-arm64

pack_library "PdfToImageConverter" "PdfToImageConverter.dylib"
pack_library "pdfium" "libpdfium.dylib"
pack_library "libSkiaSharp" "libSkiaSharp.dylib"

echo "Apple frameworks written to $OUT/apple"
