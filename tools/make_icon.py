#!/usr/bin/env python3
"""Renders the 1024x1024 app icon (RGB, no alpha): an ivory tile with a red flower on a jade background.

    python3 tools/make_icon.py App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

Needs Pillow (`pip install pillow`). The art is original; it contains no NMJL marks.
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 2  # draw at 2x and downsample for smooth edges
S = SIZE * SCALE

JADE = (0x1F, 0x6B, 0x52)
JADE_DARK = (0x16, 0x50, 0x3D)
JADE_LIGHT = (0x2A, 0x7F, 0x63)
IVORY = (0xFF, 0xFD, 0xF7)
IVORY_SHADE = (0xEC, 0xE4, 0xD0)
RED = (0xC8, 0x42, 0x3B)
RED_DARK = (0xA3, 0x31, 0x2B)
GREEN = (0x2E, 0x7D, 0x4F)
GOLD = (0xB8, 0x86, 0x2A)


def px(v):
    return int(round(v * SCALE))


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle([px(v) for v in box], radius=px(radius), fill=fill)


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (S, S), top)
    px_data = []
    for y in range(S):
        t = y / (S - 1)
        px_data.append(tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    column = Image.new("RGB", (1, S))
    column.putdata(px_data)
    return column.resize((S, S))


def main(path):
    img = vertical_gradient(JADE_LIGHT, JADE_DARK)
    draw = ImageDraw.Draw(img)

    # Soft shadow under the tile.
    shadow = Image.new("L", (S, S), 0)
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle([px(212), px(190), px(812), px(910)], radius=px(96), fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(26)))
    img = Image.composite(Image.new("RGB", (S, S), (8, 40, 30)), img, shadow)
    draw = ImageDraw.Draw(img)

    # Tile: jade "back" edge below, ivory face on top.
    rounded(draw, (212, 168, 812, 868), 96, JADE_DARK)
    rounded(draw, (212, 168, 812, 868), 96, IVORY_SHADE)
    rounded(draw, (212, 150, 812, 836), 96, IVORY)

    # Flower: five red petals around a gold centre, with two leaves.
    cx, cy = 512, 470
    petal = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(petal)
    pw, ph = 112, 150
    pdraw.ellipse([px(cx - pw / 2), px(cy - ph - 18), px(cx + pw / 2), px(cy - 18)], fill=RED + (255,))
    pdraw.ellipse(
        [px(cx - pw / 2 + 22), px(cy - ph - 6), px(cx + pw / 2 - 22), px(cy - 40)], fill=(0xDB, 0x62, 0x59, 255)
    )
    for i in range(5):
        rotated = petal.rotate(-72 * i, center=(px(cx), px(cy)), resample=Image.BICUBIC)
        img.paste(rotated, (0, 0), rotated)
    draw = ImageDraw.Draw(img)
    draw.ellipse([px(cx - 46), px(cy - 46), px(cx + 46), px(cy + 46)], fill=GOLD)
    draw.ellipse([px(cx - 26), px(cy - 30), px(cx + 18), px(cy + 14)], fill=(0xD6, 0xA8, 0x4C))

    # Stem and leaves.
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([px(cx - 11), px(cy + 60), px(cx + 11), px(cy + 300)], radius=px(11), fill=GREEN)
    leaf = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(leaf)
    # A leaf pointing up-right from the stem, then mirrored for the other side.
    ldraw.ellipse([px(cx + 8), px(cy + 196), px(cx + 128), px(cy + 260)], fill=GREEN + (255,))
    rotated = leaf.rotate(28, center=(px(cx), px(cy + 261)), resample=Image.BICUBIC)
    img.paste(rotated, (0, 0), rotated)
    mirrored = rotated.transpose(Image.FLIP_LEFT_RIGHT)
    mirrored = ImageChops.offset(mirrored, px(2 * cx - SIZE), 0)
    img.paste(mirrored, (0, 0), mirrored)

    out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    out.save(path, "PNG")
    print(f"wrote {path}: mode={out.mode} size={out.size}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png")
