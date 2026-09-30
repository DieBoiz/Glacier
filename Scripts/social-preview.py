#!/usr/bin/env python3
"""Draws the repository preview image (Resources/social-preview.png, 1280x640)."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

root = os.path.join(os.path.dirname(__file__), "..")
W, H = 1280, 640

img = Image.new("RGB", (W, H))
px = ImageDraw.Draw(img)
top, bottom = (222, 242, 253), (150, 203, 238)
for y in range(H):
    t = y / H
    px.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
img = img.convert("RGBA")

def poly(points, color):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(points, fill=color)
    return layer

for points, color in [
    ([(-40, 640), (120, 500), (220, 550), (340, 460), (500, 580), (600, 640)], (255, 255, 255, 120)),
    ([(680, 640), (820, 510), (920, 560), (1060, 450), (1180, 550), (1300, 500), (1340, 640)], (255, 255, 255, 120)),
    ([(-40, 640), (60, 560), (180, 600), (300, 530), (420, 640)], (214, 236, 250, 200)),
    ([(860, 640), (1000, 580), (1140, 610), (1260, 550), (1340, 640)], (214, 236, 250, 200)),
]:
    img = Image.alpha_composite(img, poly(points, color))

icon = Image.open(os.path.join(root, "Resources", "Icon.png")).convert("RGBA").resize((300, 300), Image.LANCZOS)
shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
shadow.paste((20, 50, 80, 90), (150, 150), icon.split()[3])
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(18)))
img.alpha_composite(icon, (130, 130))

d = ImageDraw.Draw(img)
def font(size, bold=False):
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            f = ImageFont.truetype(path, size)
            if bold:
                try:
                    f.set_variation_by_name("Bold")
                except Exception:
                    pass
            return f
        except OSError:
            pass
    return ImageFont.load_default()

d.text((490, 215), "Glacier", font=font(110, True), fill=(24, 62, 96))
d.text((494, 345), "A menu bar manager for macOS 27", font=font(38), fill=(44, 92, 130))

img.convert("RGB").save(os.path.join(root, "Resources", "social-preview.png"))
print("wrote Resources/social-preview.png")
