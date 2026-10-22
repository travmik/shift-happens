#!/bin/bash
# Regenerates Resources/MenuBarIconTemplate.png from menubar.jpg.
#
# The source mockup shows the menu bar glyph twice: white-on-dark (left half)
# and black-on-checkerboard (right half), with the big artwork straddling the
# divide. The script reconstructs a single macOS *template image* — black
# shapes + alpha — by converting each half's luminance to alpha with the
# appropriate inversion, then trims and downscales to 64px.
#
# One template covers both menu bar appearances: the system tints template
# images automatically on dark and light menu bars.
#
# Usage: scripts/make-menubar-icon.sh [source-image]
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-menubar.jpg}"
OUT="Resources/MenuBarIconTemplate.png"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/make-menubar-XXXXXX")"

mkdir -p "$(dirname "$OUT")"

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
let stride = rep.bytesPerRow // rows may be padded — never assume w * bpp
let mid = w / 2

@inline(__always) func chan(_ x: Int, _ y: Int, _ c: Int) -> Int {
    Int(data[y * stride + x * bpp + c])
}

// Luminance -> alpha, inverted per half:
//   left  (glyph white on dark bg): brighter = more opaque
//   right (glyph black on light checker): darker = more opaque
@inline(__always) func alpha(_ x: Int, _ y: Int) -> Double {
    let r = Double(chan(x, y, 0)), g = Double(chan(x, y, 1)), b = Double(chan(x, y, 2))
    let lum = (r + g + b) / 3.0
    if x < mid {
        return max(0, min(1, (lum - 50) / 140))
    } else {
        return max(0, min(1, (245 - lum) / 195))
    }
}

// The mockup also contains small preview icons in a top strip; isolate the
// glyph as the largest connected component of sufficiently opaque pixels.
var comp = [Int32](repeating: -1, count: w * h) // component id per pixel
var sizes = [Int]()
var stack = [Int32]()
for start in 0..<(w * h) where comp[start] == -1 {
    let sx = start % w, sy = start / w
    guard alpha(sx, sy) > 0.35 else { continue }
    let id = sizes.count
    sizes.append(0)
    stack.append(Int32(start))
    comp[start] = Int32(id)
    while let p = stack.popLast() {
        let pi = Int(p)
        sizes[id] += 1
        let px = pi % w, py = pi / w
        for (nx, ny) in [(px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)] {
            guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
            let ni = ny * w + nx
            if comp[ni] == -1, alpha(nx, ny) > 0.35 {
                comp[ni] = Int32(id)
                stack.append(Int32(ni))
            }
        }
    }
}
guard let best = sizes.indices.max(by: { sizes[$0] < sizes[$1] }) else {
    fputs("no glyph found\n", stderr); exit(1)
}
var minX = w, minY = h, maxX = 0, maxY = 0
for i in 0..<(w * h) where comp[i] == Int32(best) {
    let x = i % w, y = i / w
    minX = min(minX, x); maxX = max(maxX, x)
    minY = min(minY, y); maxY = max(maxY, y)
}
let side = max(maxX - minX, maxY - minY)
guard side > 0 else { fputs("no glyph found\n", stderr); exit(1) }
let cx = Double(minX + maxX) / 2, cy = Double(minY + maxY) / 2
let crop = NSRect(x: cx - Double(side) / 2, y: cy - Double(side) / 2,
                  width: Double(side), height: Double(side))

let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
out.size = NSSize(width: side, height: side)
guard let odata = out.bitmapData else { fputs("no out bitmap\n", stderr); exit(1) }
let ostride = out.bytesPerRow

for y in 0..<side {
    for x in 0..<side {
        let sx = Int(crop.origin.x) + x
        let sy = Int(crop.origin.y) + y
        let o = y * ostride + x * 4
        odata[o] = 0; odata[o + 1] = 0; odata[o + 2] = 0
        odata[o + 3] = UInt8((alpha(sx, sy) * 255).rounded())
    }
}

guard let png = out.representation(using: .png, properties: [:]),
      FileManager.default.createFile(atPath: destPath, contents: png) else {
    fputs("failed to write \(destPath)\n", stderr); exit(1)
}
print("glyph \(side)x\(side) -> \(destPath)")
SWIFT

echo "Extracting template glyph from $SRC ..."
swiftc -O "$SWIFT_TMP" -o "$WORK/helper" -framework AppKit
"$WORK/helper" "$SRC" "$WORK/master.png"
sips -z 64 64 "$WORK/master.png" --out "$OUT" >/dev/null
rm -rf "$WORK"
echo "Wrote $OUT"
