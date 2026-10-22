#!/bin/bash
# Regenerates Resources/AppIcon.icns from a source image (default: icon.jpg).
#
# AI-generated icons often come as JPEG with a baked-in checkerboard instead of
# real alpha. The script:
#   1. flood-fills the checkerboard pattern from the image borders,
#   2. turns it into true transparency, recovering the soft drop shadow around
#      the artwork as alpha (white-unpremultiply), with a small falloff band —
#      so design elements that overflow the squircle (pop-out style) survive,
#   3. emits the full iconset via sips and packs it with iconutil.
#
# Usage: scripts/make-icon.sh [source-image]
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-icon.jpg}"
OUT_DIR="Resources"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/make-icon-XXXXXX")"
ICONSET="$WORK/AppIcon.iconset"

command -v iconutil >/dev/null || { echo "iconutil not found" >&2; exit 1; }

mkdir -p "$OUT_DIR" "$ICONSET"

SWIFT_TMP="$WORK/helper.swift"
cat > "$SWIFT_TMP" <<'SWIFT'
import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: helper <source> <dest.png>\n", stderr); exit(1)
}
let srcPath = CommandLine.arguments[1]
let destPath = CommandLine.arguments[2]

guard let src = NSImage(contentsOfFile: srcPath),
      let tiff = src.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let data = rep.bitmapData else {
    fputs("cannot read \(srcPath)\n", stderr); exit(1)
}
let w = rep.pixelsWide, h = rep.pixelsHigh
let bpp = rep.bitsPerPixel / 8

@inline(__always) func chan(_ x: Int, _ y: Int, _ c: Int) -> Int {
    Int(data[(y * w + x) * bpp + c])
}
// Checkerboard is near-neutral and bright (two tones, ~243 and ~255 here).
@inline(__always) func isChecker(_ x: Int, _ y: Int) -> Bool {
    let r = chan(x, y, 0), g = chan(x, y, 1), b = chan(x, y, 2)
    let mn = min(r, g, b), mx = max(r, g, b)
    return mx - mn <= 12 && mn >= 225
}

// 1. Flood-fill checkerboard from the borders.
var flags = [UInt8](repeating: 0, count: w * h) // 0=unknown 1=checker 2=band
var queue = [Int32]()
queue.reserveCapacity(w * h)
func pushIfChecker(_ x: Int, _ y: Int) {
    guard flags[y * w + x] == 0, isChecker(x, y) else { return }
    flags[y * w + x] = 1
    queue.append(Int32(y * w + x))
}
for x in 0..<w { pushIfChecker(x, 0); pushIfChecker(x, h - 1) }
for y in 0..<h { pushIfChecker(0, y); pushIfChecker(w - 1, y) }
var head = 0
while head < queue.count {
    let p = Int(queue[head]); head += 1
    let x = p % w, y = p / w
    if x > 0 { pushIfChecker(x - 1, y) }
    if x < w - 1 { pushIfChecker(x + 1, y) }
    if y > 0 { pushIfChecker(x, y - 1) }
    if y < h - 1 { pushIfChecker(x, y + 1) }
}

// 2. Dilate the checker region into a 12px band that catches the drop shadow.
var band = [Int32]()
var dist = [UInt8](repeating: 0, count: w * h)
for p in queue where flags[Int(p)] == 1 { band.append(p) }
var bhead = 0
while bhead < band.count {
    let p = Int(band[bhead]); bhead += 1
    let d = Int(dist[p])
    if d >= 12 { continue }
    let x = Int(p) % w, y = Int(p) / w
    let neigh = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
    for (nx, ny) in neigh where nx >= 0 && nx < w && ny >= 0 && ny < h {
        let np = ny * w + nx
        if dist[np] == 0 && flags[np] == 0 {
            dist[np] = UInt8(d + 1)
            flags[np] = 2
            band.append(Int32(np))
        }
    }
}

// 3. Alpha map: checker -> 0, shadow band -> darkness-based alpha, content -> 1.
var alpha = [Float](repeating: 1.0, count: w * h)
for y in 0..<h {
    for x in 0..<w {
        let i = y * w + x
        switch flags[i] {
        case 1:
            alpha[i] = 0
        case 2:
            let r = chan(x, y, 0), g = chan(x, y, 1), b = chan(x, y, 2)
            let mn = Double(min(r, g, b))
            var a = Float((255.0 - mn) / 255.0 * Double(12 - Int(dist[i])) / 12.0)
            if a < 0.08 { a = 0 } // floor kills checker two-tone speckle
            alpha[i] = a
        default:
            break
        }
    }
}

// 4. Box-blur the alpha map to smooth glow/shadow speckle into a gradient.
var smooth = alpha
for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
        var s: Float = 0
        for dy in -1...1 { for dx in -1...1 { s += alpha[(y + dy) * w + x + dx] } }
        smooth[y * w + x] = s / 9.0
    }
}

let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
out.size = NSSize(width: w, height: h)
guard let odata = out.bitmapData else { fputs("no out bitmap\n", stderr); exit(1) }

for y in 0..<h {
    for x in 0..<w {
        let i = y * w + x
        let o = i * 4
        if flags[i] == 0 {
            let r = chan(x, y, 0), g = chan(x, y, 1), b = chan(x, y, 2)
            odata[o] = UInt8(r); odata[o + 1] = UInt8(g)
            odata[o + 2] = UInt8(b); odata[o + 3] = 255
        } else {
            let a = smooth[i]
            odata[o] = 0; odata[o + 1] = 0; odata[o + 2] = 0
            odata[o + 3] = UInt8(max(0, min(1, a)) * 255)
        }
    }
}

guard let png = out.representation(using: .png, properties: [:]),
      FileManager.default.createFile(atPath: destPath, contents: png) else {
    fputs("failed to write \(destPath)\n", stderr); exit(1)
}
print("master: \(w)x\(h) -> \(destPath)")
SWIFT

echo "Cleaning background of $SRC ..."
swiftc -O "$SWIFT_TMP" -o "$WORK/helper" -framework AppKit
"$WORK/helper" "$SRC" "$ICONSET/icon_512x512@2x.png"

# Standard iconset sizes from the 1024 master.
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  dbl=$((size * 2))
  sips -z "$dbl" "$dbl" "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT_DIR/AppIcon.icns"
rm -rf "$WORK"
echo "Wrote $OUT_DIR/AppIcon.icns"
