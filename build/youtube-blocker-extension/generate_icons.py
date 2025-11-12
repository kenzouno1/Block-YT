#!/usr/bin/env python3
"""
Generate simple PNG icons for the Chrome extension
"""

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Error: PIL/Pillow not installed!")
    print("Please install it with: sudo apt-get install python3-pil")
    import sys
    sys.exit(1)

def create_icon(size):
    """Create a simple icon with shield emoji"""
    # Create image with gradient background
    img = Image.new('RGB', (size, size), color=(102, 126, 234))
    draw = ImageDraw.Draw(img)

    # Draw gradient-like circles
    for i in range(5):
        opacity = 255 - (i * 30)
        circle_size = size - (i * size // 10)
        offset = (size - circle_size) // 2
        draw.ellipse(
            [offset, offset, offset + circle_size, offset + circle_size],
            fill=(118, 75, 162, opacity)
        )

    # Draw shield shape
    shield_size = size * 0.6
    offset = (size - shield_size) // 2

    # Shield body
    points = [
        (size // 2, offset),  # top center
        (offset + shield_size, offset + shield_size * 0.3),  # top right
        (offset + shield_size, offset + shield_size * 0.7),  # bottom right
        (size // 2, offset + shield_size),  # bottom center
        (offset, offset + shield_size * 0.7),  # bottom left
        (offset, offset + shield_size * 0.3),  # top left
    ]

    draw.polygon(points, fill=(255, 255, 255))

    # Draw a cross symbol in the shield
    line_width = max(2, size // 20)
    center_x, center_y = size // 2, size // 2
    cross_size = shield_size * 0.3

    # Horizontal line
    draw.rectangle(
        [center_x - cross_size, center_y - line_width,
         center_x + cross_size, center_y + line_width],
        fill=(239, 68, 68)
    )

    # Vertical line
    draw.rectangle(
        [center_x - line_width, center_y - cross_size,
         center_x + line_width, center_y + cross_size],
        fill=(239, 68, 68)
    )

    return img

# Generate icons
for size in [16, 48, 128]:
    icon = create_icon(size)
    icon.save(f'icons/icon{size}.png')
    print(f'Created icon{size}.png')

print('All icons generated successfully!')
