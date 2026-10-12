#!/usr/bin/env python3
"""Draws the desk pet layers into Packaging/Pet/ (all the same size, stacked at runtime).

  tail.png               tail only (sways)
  body.png               ground shadow, body, paws, scarf, head, ears
  face-calm.png          normal eyes
  face-blink.png         closed eyes (blinking)
  face-happy.png         ^ ^ eyes, open smile
  face-dizzy.png         swirl eyes, sweat drop

Requires Pillow: pip install pillow
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

UNIT = 64            # design grid, in points
PX = 4               # output pixels per point (@4x, crisp on Retina)
SS = 2               # supersampling for smooth edges
K = PX * SS
SIZE = UNIT * K
OUT = Path(__file__).resolve().parent.parent / "Packaging" / "Pet"

FUR_TOP = (255, 255, 255, 255)
FUR_BOTTOM = (232, 238, 247, 255)
LINE = (150, 162, 180, 255)
INK = (40, 45, 56, 255)
PINK = (255, 148, 166, 255)
EAR_PINK = (255, 196, 206, 255)
TEAL_TOP = (92, 214, 210, 255)
TEAL_BOTTOM = (46, 172, 196, 255)
LINE_W = 1.0


def p(x, y):
    return (x * K, y * K)


def box(cx, cy, w, h):
    return [(cx - w / 2) * K, (cy - h / 2) * K, (cx + w / 2) * K, (cy + h / 2) * K]


def layer():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def gradient(top, bottom, y0, y1):
    g = Image.new("RGBA", (1, SIZE))
    for y in range(SIZE):
        t = min(max((y / K - y0) / max(y1 - y0, 0.01), 0), 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return g.resize((SIZE, SIZE))


def outlined(img, draw_shape, fill, y0, y1, line=LINE, width=LINE_W):
    """draw_shape(draw, grow) draws the shape inflated by `grow` points."""
    m = Image.new("L", (SIZE, SIZE), 0)
    draw_shape(ImageDraw.Draw(m), width)
    img.paste(Image.new("RGBA", (SIZE, SIZE), line), (0, 0), m)
    m = Image.new("L", (SIZE, SIZE), 0)
    draw_shape(ImageDraw.Draw(m), 0)
    fill_img = gradient(*fill, y0, y1) if isinstance(fill, tuple) and isinstance(fill[0], tuple) else Image.new("RGBA", (SIZE, SIZE), fill)
    img.paste(fill_img, (0, 0), m)


def ellipse_shape(cx, cy, w, h):
    return lambda d, g: d.ellipse(box(cx, cy, w + 2 * g, h + 2 * g), fill=255)


def rounded_triangle(points, radius):
    """Polygon with rounded corners, approximated by circles at the corners plus the inner polygon."""
    def shape(d, g):
        r = radius + g
        cx = sum(x for x, _ in points) / 3
        cy = sum(y for _, y in points) / 3
        inner = []
        for x, y in points:
            dx, dy = cx - x, cy - y
            dist = math.hypot(dx, dy)
            inner.append((x + dx / dist * radius, y + dy / dist * radius))
        for x, y in inner:
            d.ellipse(box(x, y, 2 * r, 2 * r), fill=255)
        for i in range(3):
            a, b = inner[i], inner[(i + 1) % 3]
            nx, ny = b[1] - a[1], a[0] - b[0]
            n = math.hypot(nx, ny)
            nx, ny = nx / n * r, ny / n * r
            if (cx - a[0]) * nx + (cy - a[1]) * ny > 0:
                nx, ny = -nx, -ny
            d.polygon([p(a[0], a[1]), p(b[0], b[1]), p(b[0] + nx, b[1] + ny), p(a[0] + nx, a[1] + ny)], fill=255)
        d.polygon([p(x, y) for x, y in inner], fill=255)
    return shape


def bezier(p0, p1, p2, steps=60):
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
         (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
        for t in (i / steps for i in range(steps + 1))
    ]


def stroke(d, pts, width, color):
    r = width / 2
    for x, y in pts:
        d.ellipse(box(x, y, 2 * r, 2 * r), fill=color)


def soft_shadow(img, cx, cy, w, h, opacity):
    m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(m).ellipse(box(cx, cy, w, h), fill=int(255 * opacity))
    m = m.filter(ImageFilter.GaussianBlur(1.6 * K))
    img.paste(Image.new("RGBA", (SIZE, SIZE), (30, 40, 60, 255)), (0, 0), m)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.resize((UNIT * PX, UNIT * PX), Image.LANCZOS).save(OUT / name)


# ---------------------------------------------------------------- layers

def tail():
    img = layer()
    pts = bezier((44, 54), (60, 52), (55, 34))
    m_line, m_fill = Image.new("L", (SIZE, SIZE), 0), Image.new("L", (SIZE, SIZE), 0)
    stroke(ImageDraw.Draw(m_line), pts, 7 + 2 * LINE_W, 255)
    stroke(ImageDraw.Draw(m_fill), pts, 7, 255)
    img.paste(Image.new("RGBA", (SIZE, SIZE), LINE), (0, 0), m_line)
    img.paste(gradient(FUR_TOP, FUR_BOTTOM, 34, 56), (0, 0), m_fill)
    return img


def body():
    img = layer()
    soft_shadow(img, 32, 60.5, 36, 4.5, 0.28)

    outlined(img, ellipse_shape(32, 48, 32, 23), (FUR_TOP, FUR_BOTTOM), 37, 60)
    for x in (25.5, 38.5):
        outlined(img, ellipse_shape(x, 57.2, 9, 5.6), FUR_TOP, 0, 0)
        d = ImageDraw.Draw(img)
        for dx in (-1.3, 1.3):
            d.line([p(x + dx, 58.0), p(x + dx, 59.2)], fill=LINE, width=int(0.7 * K))

    # scarf: band + little knot tail, under the head
    band = lambda d, g: d.rounded_rectangle(box(32, 42.6, 27 + 2 * g, 5.4 + 2 * g), radius=(2.7 + g) * K, fill=255)
    outlined(img, band, (TEAL_TOP, TEAL_BOTTOM), 40, 45.5, line=(34, 140, 160, 255), width=1.0)
    knot = rounded_triangle([(37.5, 43), (44.5, 44.5), (41, 51)], 1.2)
    outlined(img, knot, (TEAL_TOP, TEAL_BOTTOM), 43, 51, line=(34, 140, 160, 255), width=1.0)

    for side in (-1, 1):
        ear = rounded_triangle([(32 + side * 18.5, 22), (32 + side * 16.5, 5.5), (32 + side * 5.5, 13.5)], 2.6)
        outlined(img, ear, FUR_TOP, 0, 0)
    outlined(img, ellipse_shape(32, 26.5, 42, 32.5), (FUR_TOP, FUR_BOTTOM), 10, 43)
    for side in (-1, 1):
        inner = rounded_triangle([(32 + side * 15.6, 16.5), (32 + side * 15.4, 8.6), (32 + side * 9.6, 13.2)], 1.6)
        m = Image.new("L", (SIZE, SIZE), 0)
        inner(ImageDraw.Draw(m), 0)
        img.paste(Image.new("RGBA", (SIZE, SIZE), EAR_PINK), (0, 0), m)

    # a small highlight on the forehead keeps the white from looking flat
    m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(m).ellipse(box(26, 15.5, 10, 4), fill=150)
    img.paste(Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255)), (0, 0), m.filter(ImageFilter.GaussianBlur(0.8 * K)))
    return img


EYE_Y = 27.5
EYES = (23.5, 40.5)


def face_base(img, blush=0.5, mouth="omega"):
    d = ImageDraw.Draw(img, "RGBA")
    for x in (18.5, 45.5):
        d.ellipse(box(x, 33.2, 6.5, 3.6), fill=PINK[:3] + (int(255 * blush),))
    nose = Image.new("L", (SIZE, SIZE), 0)
    rounded_triangle([(30.4, 30.8), (33.6, 30.8), (32, 32.9)], 0.6)(ImageDraw.Draw(nose), 0)
    img.paste(Image.new("RGBA", (SIZE, SIZE), PINK), (0, 0), nose)
    w = 0.95
    if mouth == "omega":
        stroke(d, bezier((32, 33.0), (31.6, 35.4), (29.4, 34.4)), w, INK)
        stroke(d, bezier((32, 33.0), (32.4, 35.4), (34.6, 34.4)), w, INK)
    elif mouth == "open":
        d.chord(box(32, 33.8, 5.2, 5.4), 0, 180, fill=INK)
        d.chord(box(32, 35.2, 3.2, 2.4), 0, 180, fill=PINK)
    elif mouth == "wavy":
        pts = [(29.0 + i * 0.1, 35.0 + 0.6 * math.sin(i * 0.1 * 2.2)) for i in range(61)]
        stroke(d, pts, w, INK)


def face_calm():
    img = layer()
    d = ImageDraw.Draw(img)
    for x in EYES:
        d.ellipse(box(x, EYE_Y, 5.4, 6.6), fill=INK)
        d.ellipse(box(x + 1.1, EYE_Y - 1.5, 2.0, 2.0), fill=(255, 255, 255, 255))
        d.ellipse(box(x - 1.0, EYE_Y + 1.7, 0.9, 0.9), fill=(255, 255, 255, 200))
    face_base(img)
    return img


def face_blink():
    img = layer()
    d = ImageDraw.Draw(img)
    for x in EYES:
        stroke(d, bezier((x - 2.8, EYE_Y + 0.4), (x, EYE_Y + 2.6), (x + 2.8, EYE_Y + 0.4)), 1.3, INK)
    face_base(img)
    return img


def face_happy():
    img = layer()
    d = ImageDraw.Draw(img)
    for x in EYES:
        stroke(d, bezier((x - 3.0, EYE_Y + 1.2), (x, EYE_Y - 3.4), (x + 3.0, EYE_Y + 1.2)), 1.5, INK)
    face_base(img, blush=0.7, mouth="open")
    return img


def face_dizzy():
    img = layer()
    d = ImageDraw.Draw(img)
    for x in EYES:
        pts = []
        for i in range(140):
            t = i / 140 * 1.7 * 2 * math.pi
            r = 0.3 + 2.8 * i / 140
            pts.append((x + r * math.cos(t), EYE_Y + r * math.sin(t)))
        stroke(d, pts, 0.8, INK)
    face_base(img, blush=0.3, mouth="wavy")
    drop = Image.new("L", (SIZE, SIZE), 0)
    dd = ImageDraw.Draw(drop)
    dd.ellipse(box(52, 17.5, 4.6, 4.6), fill=255)
    dd.polygon([p(49.8, 17.0), p(54.2, 17.0), p(52, 12.2)], fill=255)
    img.paste(gradient((150, 225, 245, 255), (70, 175, 225, 255), 12, 20), (0, 0), drop)
    ImageDraw.Draw(img).ellipse(box(51.2, 17.2, 1.2, 1.6), fill=(255, 255, 255, 220))
    return img


def main():
    save(tail(), "tail.png")
    save(body(), "body.png")
    save(face_calm(), "face-calm.png")
    save(face_blink(), "face-blink.png")
    save(face_happy(), "face-happy.png")
    save(face_dizzy(), "face-dizzy.png")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
