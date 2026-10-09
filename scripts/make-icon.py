#!/usr/bin/env python3
"""Draws Packaging/AppIcon.png (1024x1024), the DeskTidy app icon.

Requires Pillow: pip install pillow
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SCALE = 2  # draw large, then downsample for smooth edges
SIZE = 1024 * SCALE
OUT = Path(__file__).resolve().parent.parent / "Packaging" / "AppIcon.png"


def s(v):
    return int(round(v * SCALE))


def squircle(cx, cy, half, n=5.0, steps=720):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, si = math.cos(t), math.sin(t)
        x = math.copysign(abs(c) ** (2 / n), c) * half
        y = math.copysign(abs(si) ** (2 / n), si) * half
        pts.append((cx + x, cy + y))
    return pts


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return grad.resize((w, h))


def diagonal_gradient(size, a, b):
    w, h = size
    small = Image.new("RGBA", (64, 64))
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            small.putpixel((x, y), tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4)))
    return small.resize((w, h), Image.BICUBIC)


def shadow(mask, offset, blur, opacity):
    layer = Image.new("RGBA", mask.size, (20, 40, 80, 0))
    alpha = mask.point(lambda p: int(p * opacity))
    layer.putalpha(alpha)
    layer = layer.filter(ImageFilter.GaussianBlur(s(blur)))
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    out.paste(layer, (s(offset[0]), s(offset[1])), layer)
    return out


def rounded_mask(box, radius):
    m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(m).rounded_rectangle([s(v) for v in box], radius=s(radius), fill=255)
    return m


def card(icon, box, radius, fill, bar_fill, dots, shadow_opacity):
    m = rounded_mask(box, radius)
    icon.alpha_composite(shadow(m, (0, 14), 22, shadow_opacity))
    layer = Image.new("RGBA", (SIZE, SIZE), fill)
    icon.paste(layer, (0, 0), m)
    d = ImageDraw.Draw(icon)
    x0, y0, x1, _ = box
    bar = [x0, y0, x1, y0 + 64]
    bar_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(bar_mask).rectangle([s(v) for v in bar], fill=255)
    bar_mask = Image.composite(bar_mask, Image.new("L", (SIZE, SIZE), 0), m)
    icon.paste(Image.new("RGBA", (SIZE, SIZE), bar_fill), (0, 0), bar_mask)
    if dots:
        for i, color in enumerate(dots):
            cx, cy = x0 + 44 + i * 34, y0 + 32
            d.ellipse([s(cx - 10), s(cy - 10), s(cx + 10), s(cy + 10)], fill=color)


def sparkle(icon, cx, cy, r, colors):
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * 0.26
        pts.append((s(cx + math.cos(ang) * rad), s(cy + math.sin(ang) * rad)))
    m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    icon.alpha_composite(shadow(m, (0, 6), 10, 0.14))
    box = (s(cx - r), s(cy - r), s(cx + r), s(cy + r))
    grad = diagonal_gradient((box[2] - box[0], box[3] - box[1]), *colors)
    icon.paste(grad, box[:2], m.crop(box))


def main():
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    body = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(body).polygon(squircle(SIZE / 2, SIZE / 2, s(412)), fill=255)
    icon.alpha_composite(shadow(body, (0, 12), 18, 0.22))
    bg = vertical_gradient((SIZE, SIZE), (240, 248, 255, 255), (196, 225, 250, 255))
    icon.paste(bg, (0, 0), body)

    content = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card(content, (310, 250, 714, 540), 40, (226, 238, 251, 255), (218, 232, 249, 255), None, 0.04)
    card(content, (266, 308, 758, 650), 46, (240, 246, 253, 255), (231, 240, 251, 255), None, 0.06)
    card(
        content,
        (222, 372, 802, 790),
        54,
        (255, 255, 255, 255),
        (241, 246, 252, 255),
        [(255, 112, 102, 255), (255, 196, 70, 255), (64, 205, 120, 255)],
        0.16,
    )
    d = ImageDraw.Draw(content)
    for i, w in enumerate((330, 250)):
        y = 520 + i * 70
        d.rounded_rectangle([s(290), s(y), s(290 + w), s(y + 26)], radius=s(13), fill=(222, 233, 245, 255))
    sparkle(content, 742, 236, 112, ((92, 196, 255, 255), (52, 214, 186, 255)))
    sparkle(content, 618, 172, 40, ((126, 210, 255, 255), (88, 222, 198, 255)))

    clipped = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    clipped.paste(content, (0, 0), Image.composite(content.getchannel("A"), Image.new("L", (SIZE, SIZE), 0), body))
    icon.alpha_composite(clipped)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.resize((1024, 1024), Image.LANCZOS).save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
