#!/usr/bin/env python3
"""Generate StudyFlow launcher icons from the official logo.

The source logo lives in `design/app-icon/studyflow-logo-source.png`.
This script intentionally uses only Python's standard library so everyone in
the project can regenerate the mobile icons without installing extra tools.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/app-icon/studyflow-logo-source.png"
MASTER = ROOT / "design/app-icon/studyflow-icon-1024.png"
BACKGROUND = (7, 59, 76)  # StudyFlow petrol blue, used behind transparent pixels.


class RgbImage:
    def __init__(self, width: int, height: int, pixels: bytearray) -> None:
        self.width = width
        self.height = height
        self.pixels = pixels

    def resize_square(self, size: int) -> "RgbImage":
        """Resize with simple box sampling; launcher icons stay crisp at small sizes."""
        out = bytearray(size * size * 3)
        scale_x = self.width / size
        scale_y = self.height / size

        for y in range(size):
            sy0 = int(y * scale_y)
            sy1 = max(sy0 + 1, int((y + 1) * scale_y))
            for x in range(size):
                sx0 = int(x * scale_x)
                sx1 = max(sx0 + 1, int((x + 1) * scale_x))

                r = g = b = count = 0
                for sy in range(sy0, min(sy1, self.height)):
                    row = sy * self.width * 3
                    for sx in range(sx0, min(sx1, self.width)):
                        index = row + sx * 3
                        r += self.pixels[index]
                        g += self.pixels[index + 1]
                        b += self.pixels[index + 2]
                        count += 1

                index = (y * size + x) * 3
                out[index] = round(r / count)
                out[index + 1] = round(g / count)
                out[index + 2] = round(b / count)

        return RgbImage(size, size, out)

    def save_png(self, path: Path) -> None:
        """Write an RGB PNG with no alpha channel, which is safer for iOS icons."""
        path.parent.mkdir(parents=True, exist_ok=True)

        raw = bytearray()
        for y in range(self.height):
            raw.append(0)  # PNG filter type 0.
            start = y * self.width * 3
            raw.extend(self.pixels[start : start + self.width * 3])

        def chunk(kind: bytes, data: bytes) -> bytes:
            checksum = zlib.crc32(kind + data) & 0xFFFFFFFF
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", checksum)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        path.write_bytes(png)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def unfilter_scanline(filter_type: int, current: bytearray, previous: bytearray, bpp: int) -> bytearray:
    result = bytearray(current)
    for i, value in enumerate(current):
        left = result[i - bpp] if i >= bpp else 0
        up = previous[i] if previous else 0
        up_left = previous[i - bpp] if previous and i >= bpp else 0

        if filter_type == 0:
            result[i] = value
        elif filter_type == 1:
            result[i] = (value + left) & 0xFF
        elif filter_type == 2:
            result[i] = (value + up) & 0xFF
        elif filter_type == 3:
            result[i] = (value + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            result[i] = (value + paeth(left, up, up_left)) & 0xFF
        else:
            raise ValueError(f"Unsupported PNG filter type: {filter_type}")
    return result


def read_png_flattened(path: Path) -> RgbImage:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{path} is not a PNG file")

    position = 8
    width = height = color_type = bit_depth = None
    idat = bytearray()

    while position < len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        kind = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        position += 12 + length

        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if bit_depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError("Only non-interlaced 8-bit PNG files are supported")
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            break

    if width is None or height is None or color_type is None:
        raise ValueError("PNG header is missing")

    if color_type == 6:
        channels = 4
    elif color_type == 2:
        channels = 3
    else:
        raise ValueError(f"Unsupported PNG color type: {color_type}")

    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    previous = bytearray(stride)
    source_rows: list[bytearray] = []
    offset = 0

    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        scanline = bytearray(raw[offset : offset + stride])
        offset += stride
        row = unfilter_scanline(filter_type, scanline, previous, channels)
        source_rows.append(row)
        previous = row

    flattened = bytearray(width * height * 3)
    index = 0
    for row in source_rows:
        for x in range(width):
            source_index = x * channels
            r = row[source_index]
            g = row[source_index + 1]
            b = row[source_index + 2]

            if channels == 4:
                alpha = row[source_index + 3] / 255
                r = round(r * alpha + BACKGROUND[0] * (1 - alpha))
                g = round(g * alpha + BACKGROUND[1] * (1 - alpha))
                b = round(b * alpha + BACKGROUND[2] * (1 - alpha))

            flattened[index] = r
            flattened[index + 1] = g
            flattened[index + 2] = b
            index += 3

    return RgbImage(width, height, flattened)


def icon_targets() -> dict[Path, int]:
    ios = ROOT / "src/app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    return {
        ROOT / "src/app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        ROOT / "src/app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        ROOT / "src/app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        ROOT / "src/app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        ROOT / "src/app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
        ROOT / "src/app/web/favicon.png": 32,
        ROOT / "src/app/web/icons/Icon-192.png": 192,
        ROOT / "src/app/web/icons/Icon-maskable-192.png": 192,
        ROOT / "src/app/web/icons/Icon-512.png": 512,
        ROOT / "src/app/web/icons/Icon-maskable-512.png": 512,
        ios / "Icon-App-20x20@1x.png": 20,
        ios / "Icon-App-20x20@2x.png": 40,
        ios / "Icon-App-20x20@3x.png": 60,
        ios / "Icon-App-29x29@1x.png": 29,
        ios / "Icon-App-29x29@2x.png": 58,
        ios / "Icon-App-29x29@3x.png": 87,
        ios / "Icon-App-40x40@1x.png": 40,
        ios / "Icon-App-40x40@2x.png": 80,
        ios / "Icon-App-40x40@3x.png": 120,
        ios / "Icon-App-60x60@2x.png": 120,
        ios / "Icon-App-60x60@3x.png": 180,
        ios / "Icon-App-76x76@1x.png": 76,
        ios / "Icon-App-76x76@2x.png": 152,
        ios / "Icon-App-83.5x83.5@2x.png": 167,
        ios / "Icon-App-1024x1024@1x.png": 1024,
    }


def main() -> None:
    source = read_png_flattened(SOURCE)
    cache: dict[int, RgbImage] = {}

    for target, size in sorted(icon_targets().items(), key=lambda item: item[1]):
        if size not in cache:
            cache[size] = source.resize_square(size)
        cache[size].save_png(target)

    cache[1024].save_png(MASTER)
    print(f"Generated icons from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
