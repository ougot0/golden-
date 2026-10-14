#!/usr/bin/env python3
"""Draws the GoldenHour app icon (1024×1024, no transparency) with Pillow.

Motif: the sun's path (slate arc) over the horizon, ending at the amber sun 20° above the
horizon on the setting side (golden hour), reflected on water. Rendered at 4× and downsampled for clean anti-aliasing.

    python3 tools/assets/make_app_icon.py GoldenHour/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import sys
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 1024 * SCALE
CHARCOAL = (21, 23, 23)
WARM_WHITE = (243, 240, 233)
AMBER = (217, 154, 69)
SLATE = (114, 119, 117)


def main(path):
    img = Image.new("RGB", (SIZE, SIZE), CHARCOAL)
    d = ImageDraw.Draw(img)
    s = SCALE
    horizon_y = 640 * s

    # Sun path: arc centred on the horizon, from sunrise (left) to the sun's current position,
    # 20° above the horizon on the setting side: golden hour.
    cx, R = 462 * s, 330 * s
    d.arc((cx - R, horizon_y - R, cx + R, horizon_y + R), start=180, end=340, fill=SLATE, width=10 * s)

    import math
    angle = math.radians(20)
    sun_x = cx + R * math.cos(angle)
    sun_y = horizon_y - R * math.sin(angle)
    r = 92 * s
    d.ellipse((sun_x - r, sun_y - r, sun_x + r, sun_y + r), fill=AMBER)

    # Horizon line.
    d.rectangle((120 * s, horizon_y - 5 * s, 904 * s, horizon_y + 5 * s), fill=WARM_WHITE)

    # Reflections of the sun on the water.
    for i, w in enumerate((200, 120, 60)):
        y = horizon_y + (60 + 50 * i) * s
        d.rectangle((sun_x - w * s / 2, y - 5 * s, sun_x + w * s / 2, y + 5 * s), fill=AMBER)

    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(path, "PNG")


if __name__ == "__main__":
    main(sys.argv[1])
