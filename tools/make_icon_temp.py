#!/usr/bin/env python3
"""Temporary Phase 0 icon: ivory tile on jade, RGB (no alpha). Phase 12 replaces it."""
import sys
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGB", (S, S), (0x1F, 0x6B, 0x52))
d = ImageDraw.Draw(img)
d.rounded_rectangle((232, 160, 792, 864), radius=72, fill=(0x1A, 0x57, 0x43))  # tile edge
d.rounded_rectangle((232, 140, 792, 836), radius=72, fill=(0xFF, 0xFD, 0xF7))  # tile face
d.ellipse((372, 300, 652, 580), outline=(0xC8, 0x42, 0x3B), width=36)
d.ellipse((472, 400, 552, 480), fill=(0xC8, 0x42, 0x3B))
for i in range(3):
    x = 392 + i * 120
    d.rounded_rectangle((x, 640, x + 40, 780), radius=14, fill=(0x2E, 0x7D, 0x4F))
img.save(sys.argv[1], "PNG")
