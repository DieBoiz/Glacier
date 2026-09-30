#!/usr/bin/env python3
"""Draws the background image for the installer disk image (Resources/dmg-background.png)."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

W, H, S = 660, 400, 2
out = os.path.join(os.path.dirname(__file__), "..", "Resources", "dmg-background.png")

img = Image.new("RGB", (W * S, H * S))
px = ImageDraw.Draw(img)
top, bottom = (222, 242, 253), (150, 203, 238)
for y in range(H * S):
    t = y / (H * S)
    px.line([(0, y), (W * S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))

def poly(points, color):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon([(x * S, y * S) for x, y in points], fill=color)
    return layer

# Icebergs along the bottom edge.
layers = [
    poly([(-20, 400), (60, 318), (110, 346), (170, 292), (250, 360), (300, 400)], (255, 255, 255, 120)),
    poly([(330, 400), (400, 330), (450, 356), (520, 300), (580, 352), (640, 318), (690, 400)], (255, 255, 255, 120)),
    poly([(-20, 400), (30, 352), (90, 372), (150, 340), (210, 400)], (214, 236, 250, 200)),
    poly([(420, 400), (490, 362), (560, 380), (620, 350), (690, 400)], (214, 236, 250, 200)),
]
for layer in layers:
    img = Image.alpha_composite(img.convert("RGBA"), layer)

# Soft snow dots.
snow = Image.new("RGBA", img.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(snow)
for x, y, r in [(60, 50, 3), (130, 90, 2), (210, 40, 3), (300, 70, 2), (420, 36, 3),
                (500, 80, 2), (590, 52, 3), (620, 130, 2), (40, 150, 2), (350, 120, 2)]:
    sd.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=(255, 255, 255, 200))
img = Image.alpha_composite(img, snow.filter(ImageFilter.GaussianBlur(0.6)))

d = ImageDraw.Draw(img)

def font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size * S)
        except OSError:
            pass
    return ImageFont.load_default()

title = "Drag Glacier into Applications"
f = font(20)
w = d.textlength(title, font=f)
d.text(((W * S - w) / 2, 34 * S), title, font=f, fill=(32, 78, 112))

# Arrow between the two icons (icons sit at x=180 and x=480, y=190).
ax0, ax1, ay = 250, 410, 190
color = (255, 255, 255, 235)
d.line([(ax0 * S, ay * S), (ax1 * S, ay * S)], fill=color, width=6 * S)
d.polygon([((ax1 + 22) * S, ay * S), ((ax1 - 4) * S, (ay - 16) * S), ((ax1 - 4) * S, (ay + 16) * S)], fill=color)

img.convert("RGB").save(out, dpi=(72 * S, 72 * S))
print("wrote", os.path.normpath(out))
