#!/usr/bin/env python3
"""
Create simple PNG icons without requiring PIL
Uses raw PNG format
"""

import struct
import zlib

def create_simple_png(size, color=(102, 126, 234)):
    """Create a simple solid color PNG"""
    # PNG header
    png = b'\x89PNG\r\n\x1a\n'

    # Create IHDR chunk (image header)
    ihdr_data = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)
    ihdr = create_chunk(b'IHDR', ihdr_data)
    png += ihdr

    # Create image data
    raw_data = b''
    for y in range(size):
        raw_data += b'\x00'  # Filter type (none)
        for x in range(size):
            # Gradient effect
            factor = 1.0 - (abs(x - size/2) + abs(y - size/2)) / size
            r = int(color[0] * factor)
            g = int(color[1] * factor)
            b = int(color[2] * factor)
            raw_data += bytes([r, g, b])

    compressed_data = zlib.compress(raw_data, 9)
    idat = create_chunk(b'IDAT', compressed_data)
    png += idat

    # Create IEND chunk
    iend = create_chunk(b'IEND', b'')
    png += iend

    return png

def create_chunk(chunk_type, data):
    """Create a PNG chunk"""
    length = struct.pack('>I', len(data))
    chunk = chunk_type + data
    crc = struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)
    return length + chunk + crc

# Create icons directory
import os
os.makedirs('icons', exist_ok=True)

# Generate icons
for size in [16, 48, 128]:
    png_data = create_simple_png(size)
    with open(f'icons/icon{size}.png', 'wb') as f:
        f.write(png_data)
    print(f'Created icon{size}.png')

print('All icons generated successfully!')
