#!/usr/bin/env python3
"""Segmenti fanmade per Snow Tails: partono dai rettilinei scansionati e aggiungono
cartelli (stesso stile dei cartelli delle curve: disco bianco bordato di rosso, doppia
linea rossa all'ingresso) e qualche ritocco dipinto sulla pista. Gli effetti veri
(neve, vento, pendenza) li fa il gioco in 3D.

I segmenti si sommano ai rettilinei: qui si preparano solo i livelli trasparenti che il
gioco stende sopra la pista (ghiaccio, tracce di salita e discesa, increspature del vento),
i dischi dei cartelli e la tessera del bivio, che ha una geometria sua.

Uso: python3 tools/make_fan_tiles.py   (dalla cartella del progetto)
Crea assets/fan/*.png, assets/tiles/fan_fork.webp e data/faces/fan_fork.json.
"""
import json, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parent.parent
FACES = ROOT / "data/faces"
TILES = ROOT / "assets/tiles"
FONT = str(ROOT / "assets/fonts/Nunito-900.woff2")

RED = (200, 50, 42, 255)
INK = (24, 24, 28, 255)

FAN = ROOT / "assets/fan"
BAND_W = 1200
BAND_H = int(BAND_W * (5 * 53.8) / (6 * 97.0))   # 5 corsie x 6 caselle

def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except Exception:
        return ImageFont.load_default()


def sign(kind, r=34):
    """Disco del cartello con il simbolo del segmento (come i cartelli delle curve)."""
    s = 4  # disegno ingrandito, poi ridotto: bordi morbidi
    R = r * s
    im = Image.new("RGBA", (2 * R + 8 * s, 2 * R + 8 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = R + 4 * s
    # ombra leggera
    d.ellipse([c - R + 3 * s, c - R + 4 * s, c + R + 3 * s, c + R + 4 * s], fill=(0, 0, 0, 70))
    d.ellipse([c - R, c - R, c + R, c + R], fill=(255, 255, 255, 255), outline=RED, width=int(R * 0.2))
    k = R * 0.55
    if kind in ("up", "down"):
        # pendenza: triangolo rettangolo con la freccia e il numero
        up = kind == "up"
        tri = [(c - k, c + k * 0.55), (c + k, c + k * 0.55), (c + k, c - k * 0.45)] if up else \
              [(c - k, c - k * 0.45), (c - k, c + k * 0.55), (c + k, c + k * 0.55)]
        d.polygon(tri, fill=INK)
        txt = "4" if up else "5+"
        f = font(int(R * (0.62 if up else 0.5)))
        tx = c - k * (0.45 if up else -0.05)
        d.text((tx, c - k * 0.62), txt, font=f, fill=INK, anchor="mm")
    elif kind == "wind":
        # manica a vento
        d.line([(c - k * 0.85, c - k * 0.9), (c - k * 0.85, c + k * 0.95)], fill=INK, width=int(R * 0.09))
        cone = [(c - k * 0.8, c - k * 0.75), (c + k * 0.95, c - k * 0.45), (c + k * 0.95, c - k * 0.05), (c - k * 0.8, c + k * 0.15)]
        d.polygon(cone, fill=INK)
        for i in range(2):
            x = c - k * 0.25 + i * k * 0.55
            d.line([(x, c - k * 0.62 + i * 0.07 * k), (x, c + 0.06 * k - i * 0.05 * k)], fill=(255, 255, 255, 255), width=int(R * 0.06))
        for i in range(3):
            y = c + k * (0.4 + i * 0.22)
            d.line([(c - k * 0.3, y), (c + k * 0.9 - i * k * 0.2, y)], fill=INK, width=int(R * 0.05))
    elif kind == "ice":
        # cristallo di ghiaccio
        for a in range(6):
            ang = a * math.pi / 3
            x2, y2 = c + math.cos(ang) * k, c + math.sin(ang) * k
            d.line([(c, c), (x2, y2)], fill=INK, width=int(R * 0.1))
            for sgn in (-1, 1):
                bx, by = c + math.cos(ang) * k * 0.55, c + math.sin(ang) * k * 0.55
                d.line([(bx, by), (bx + math.cos(ang + sgn * 0.8) * k * 0.3, by + math.sin(ang + sgn * 0.8) * k * 0.3)], fill=INK, width=int(R * 0.07))
    elif kind == "fresh":
        # cumuli di neve con fiocchi
        d.pieslice([c - k * 1.0, c - k * 0.1, c + k * 0.2, c + k * 1.1], 180, 360, fill=INK)
        d.pieslice([c - k * 0.3, c - k * 0.3, c + k * 1.0, c + k * 1.1], 180, 360, fill=INK)
        d.rectangle([c - k * 1.0, c + k * 0.45, c + k * 1.0, c + k * 0.6], fill=INK)
        for (fx, fy) in ((-0.55, -0.6), (0.1, -0.85), (0.6, -0.45)):
            px, py = c + fx * k, c + fy * k
            for a in range(3):
                ang = a * math.pi / 3
                d.line([(px - math.cos(ang) * k * 0.16, py - math.sin(ang) * k * 0.16), (px + math.cos(ang) * k * 0.16, py + math.sin(ang) * k * 0.16)], fill=INK, width=int(R * 0.05))
    elif kind == "fork":
        # bivio: una freccia che si divide in due
        w = int(R * 0.12)
        d.line([(c, c + k * 0.95), (c, c + k * 0.05)], fill=INK, width=w)
        for sgn in (-1, 1):
            ex, ey = c + sgn * k * 0.62, c - k * 0.62
            d.line([(c, c + k * 0.1), (ex, ey)], fill=INK, width=w)
            ang = math.atan2(ey - c, ex - c)
            for da in (2.5, -2.5):
                d.line([(ex, ey), (ex + math.cos(ang + da) * k * 0.32, ey + math.sin(ang + da) * k * 0.32)], fill=INK, width=w)
    elif kind == "hut":
        # casetta con la chiave inglese (riparazioni)
        d.polygon([(c - k * 0.95, c - k * 0.05), (c, c - k * 0.9), (c + k * 0.95, c - k * 0.05)], fill=INK)
        d.rectangle([c - k * 0.7, c - k * 0.1, c + k * 0.7, c + k * 0.85], fill=INK)
        d.rectangle([c - k * 0.18, c + k * 0.3, c + k * 0.18, c + k * 0.85], fill=(255, 255, 255, 255))
        d.rectangle([c + k * 0.32, c + k * 0.05, c + k * 0.58, c + k * 0.3], fill=(255, 255, 255, 255))
    im = im.resize((im.width // s, im.height // s), Image.LANCZOS)
    return im


def lane_band(face):
    sc = face["img_scale"]
    ys = sorted(set(round(p[1], 1) for p in face["cells"]))
    lane = face["lane_width"]
    top = (ys[0] - lane / 2) * sc
    bot = (ys[-1] + lane / 2) * sc
    x0 = 0
    x1 = face["entry"]["mid"][0] * sc
    return x0, top, x1, bot


def keep_lines(base, edited, box):
    """Dove la scansione ha le linee nere della griglia, le rimette sopra il ritocco."""
    g = base.convert("L")
    mask = g.point(lambda v: 255 if v < 95 else 0).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = edited.copy()
    out.paste(base, (0, 0), mask)
    return out



def overlay(kind, rnd):
    """Livello trasparente grande quanto la fascia delle corsie; x = senso di marcia."""
    W, H = BAND_W, BAND_H
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    if kind == "ice":
        noise = Image.effect_noise((W // 24 + 1, H // 24 + 1), 60).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10))
        tint = Image.new("RGBA", (W, H), (140, 198, 235, 0))
        tint.putalpha(noise.point(lambda v: int(70 + v * 0.45)))
        ov = Image.alpha_composite(ov, tint)
        refl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rd = ImageDraw.Draw(refl)
        for i in range(9):
            x = rnd.uniform(-60, W + 60)
            w = rnd.uniform(14, 44)
            rd.polygon([(x, 0), (x + w, 0), (x + w - 160, H), (x - 160, H)], fill=(255, 255, 255, rnd.randint(45, 80)))
        ov = Image.alpha_composite(ov, refl.filter(ImageFilter.GaussianBlur(8)))
        d = ImageDraw.Draw(ov)
        for i in range(14):
            x, y = rnd.uniform(30, W - 30), rnd.uniform(20, H - 20)
            pts = [(x, y)]
            ang = rnd.uniform(0, math.tau)
            for j in range(rnd.randint(4, 9)):
                ang += rnd.uniform(-0.9, 0.9)
                x += math.cos(ang) * rnd.uniform(14, 34)
                y += math.sin(ang) * rnd.uniform(14, 34)
                pts.append((x, y))
            d.line(pts, fill=(70, 120, 165, 160), width=3)
            d.line([(p[0] + 1.5, p[1] + 1.5) for p in pts], fill=(255, 255, 255, 140), width=2)
    elif kind == "up":
        # spina di pesce che punta nel senso di marcia (+x)
        for lane in range(5):
            y = (lane + 0.5) * H / 5
            x = 50
            while x < W - 20:
                for sgn in (-1, 1):
                    d.line([(x, y), (x - 22, y + sgn * 17)], fill=(110, 140, 178, 95), width=5)
                x += 66
    elif kind == "down":
        for lane in range(5):
            y = (lane + 0.5) * H / 5
            for off in (-13, 13):
                pts = [(x, y + off + math.sin(x * 0.01 + lane) * 3) for x in range(0, W + 20, 20)]
                d.line(pts, fill=(120, 150, 185, 95), width=4)
        light = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(light)
        for x in range(W):
            ld.line([(x, 0), (x, H)], fill=(255, 255, 255, int(50 * (1 - x / W))))
        ov = Image.alpha_composite(ov, light)
    elif kind == "wind":
        for i in range(90):
            x = rnd.uniform(0, W)
            y = rnd.uniform(0, H)
            L = rnd.uniform(35, 80)
            d.arc([x - L * 0.3, y - L, x + 10, y + L * 0.2], 110, 250, fill=(140, 170, 200, 120), width=4)
            d.arc([x - L * 0.3 + 3, y - L, x + 13, y + L * 0.2], 110, 250, fill=(255, 255, 255, 150), width=3)
        ov = ov.filter(ImageFilter.GaussianBlur(0.8))
    return ov


def keep_lines(base, edited, box):
    g = base.convert("L")
    mask = g.point(lambda v: 255 if v < 95 else 0).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = edited.copy()
    out.paste(base, (0, 0), mask)
    return out


def make_fork(rnd):
    """Bivio: isola di neve con abeti al centro; il corridoio di sinistra (corsie 0-1) ha
    4 caselle lunghe (scorciatoia, con un po' di neve fresca), quello di destra 6 normali."""
    src = "straight_p16a"
    face = json.loads((FACES / f"{src}.json").read_text())
    base = Image.open(TILES / f"{src}.webp").convert("RGBA")
    sc = face["img_scale"]
    x0, top, x1, bot = lane_band(face)
    lane_px = (bot - top) / 5
    img = base.copy()
    # corridoio corto: si cancellano le linee della griglia e si ridisegnano 4 caselle lunghe
    left = (int(x0), int(top + 3), int(x1 - 2), int(top + lane_px * 2 - 3))
    region = img.crop(left).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.5))
    img.paste(region, left[:2])
    d = ImageDraw.Draw(img)
    line = (34, 40, 52, 255)
    for k in range(1, 4):
        x = x1 - (x1 - x0) * k / 4
        d.line([(x, top), (x, top + lane_px * 2)], fill=line, width=3)
    d.line([(x0, top + lane_px), (x1, top + lane_px)], fill=line, width=3)
    d.line([(x0, top), (x1, top)], fill=line, width=3)
    # isola di neve sulla corsia di mezzo
    y0, y1 = top + lane_px * 2 - 2, top + lane_px * 3 + 2
    isl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    idr = ImageDraw.Draw(isl)
    idr.rounded_rectangle([x0 + 6, y0 + 7, x1 - 22, y1 + 9], radius=int(lane_px * 0.45), fill=(120, 150, 180, 120))
    idr.rounded_rectangle([x0 + 6, y0, x1 - 22, y1], radius=int(lane_px * 0.45), fill=(246, 249, 252, 255))
    for i in range(40):
        x = rnd.uniform(x0 + 20, x1 - 40)
        y = rnd.uniform(y0 + 6, y1 - 6)
        r = rnd.uniform(5, 14)
        idr.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(222, 232, 242, 160))
    img = Image.alpha_composite(img, isl.filter(ImageFilter.GaussianBlur(1.2)))
    # cartello all'ingresso
    d2 = ImageDraw.Draw(img)
    ex = x1 - 8
    for off in (-4, 4):
        d2.line([(ex + off, top - 8), (ex + off, bot + 8)], fill=RED, width=3)
    sg = sign("fork")
    for y in (top - sg.height * 0.55, bot - sg.height * 0.45):
        img.alpha_composite(sg, (int(ex - sg.width / 2), int(y)))
    img.save(TILES / "fan_fork.webp", "WEBP", quality=88)
    # geometria: caselle e collegamenti nuovi (coordinate della faccia, img/sc)
    ys = sorted(set(round(p[1], 1) for p in face["cells"]))
    ex_f = face["entry"]["mid"][0]
    cells, links = [], []
    for lane, n in ((0, 4), (1, 4), (3, 6), (4, 6)):
        first = len(cells)
        for k in range(n):
            cells.append([round(ex_f - ex_f * (k + 0.5) / n, 1), ys[lane]])
            if k > 0:
                links.append([first + k - 1, first + k])
    nf = dict(face)
    nf.update({"id": "fan_fork", "image": "res://assets/tiles/fan_fork.webp", "label": "Bivio (fanmade)",
               "type": "fork", "special": "fork", "fanmade": True, "cells": cells, "links": links,
               "saplings": [], "fresh": [1, 6], "hut": [],
               "island": [[round(ex_f - ex_f * (k + 0.5) / 6, 1), ys[2]] for k in range(1, 5)]})
    (FACES / "fan_fork.json").write_text(json.dumps(nf, ensure_ascii=False, indent=1))


def main():
    rnd = random.Random(7)
    FAN.mkdir(parents=True, exist_ok=True)
    for kind in ("ice", "up", "down", "wind"):
        overlay(kind, rnd).save(FAN / f"{kind}.png")
    for kind in ("up", "down", "wind", "ice", "fresh", "hut"):
        sign(kind).save(FAN / f"sign_{kind}.png")
    make_fork(rnd)
    print("ok")


if __name__ == "__main__":
    main()
