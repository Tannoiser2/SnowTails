#!/usr/bin/env python3
"""Segmenti fanmade per Snow Tails: partono dai rettilinei scansionati e aggiungono
cartelli (stesso stile dei cartelli delle curve: disco bianco bordato di rosso, doppia
linea rossa all'ingresso) e qualche ritocco dipinto sulla pista. Gli effetti veri
(neve, vento, pendenza) li fa il gioco in 3D.

Uso: python3 tools/make_fan_tiles.py   (dalla cartella del progetto)
Crea assets/tiles/fan_*.webp e data/faces/fan_*.json.
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

# segmento -> rettilineo di partenza, etichetta, parametri
SEGMENTS = {
    "up":    ("straight_p14a", "Salita (fanmade)", {}),
    "down":  ("straight_p14b", "Discesa (fanmade)", {}),
    "wind":  ("straight_p18a", "Vento laterale (fanmade)", {"wind": "R"}),
    "ice":   ("straight_p16b", "Lago ghiacciato (fanmade)", {}),
    "fresh": ("straight_p18b", "Neve fresca (fanmade)", {}),
    "hut":   ("straight_p20b", "Baita (fanmade)", {}),
    "wind_l": ("straight_p18b", "Vento laterale da destra (fanmade)", {"wind": "L"}),
    "fork":  ("straight_p16a", "Bivio (fanmade)", {}),
}


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


def paint(kind, base, face, rnd):
    if kind == "wind_l":
        kind = "wind"
    img = base.copy()
    x0, top, x1, bot = lane_band(face)
    W, H = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    if kind == "ice":
        # superficie ghiacciata: azzurro trasparente a chiazze, riflessi morbidi, crepe sottili
        noise = Image.effect_noise((max(1, W // 24), max(1, H // 24)), 60).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10))
        tint = Image.new("RGBA", img.size, (140, 198, 235, 0))
        band = Image.new("L", img.size, 0)
        ImageDraw.Draw(band).rectangle([x0, top, x1, bot], fill=255)
        alpha = ImageChops.multiply(noise.point(lambda v: int(70 + v * 0.45)), band)
        tint.putalpha(alpha)
        ov = Image.alpha_composite(ov, tint)
        refl = Image.new("RGBA", img.size, (0, 0, 0, 0))
        rd = ImageDraw.Draw(refl)
        for i in range(7):
            x = rnd.uniform(x0 + 40, x1 + 60)
            w = rnd.uniform(10, 34)
            rd.polygon([(x, top), (x + w, top), (x + w - 110, bot), (x - 110, bot)], fill=(255, 255, 255, rnd.randint(45, 80)))
        refl = refl.filter(ImageFilter.GaussianBlur(7))
        refl.putalpha(ImageChops.multiply(refl.getchannel("A"), band))
        ov = Image.alpha_composite(ov, refl)
        d = ImageDraw.Draw(ov)
        for i in range(10):  # crepe
            x, y = rnd.uniform(x0 + 30, x1 - 30), rnd.uniform(top + 20, bot - 20)
            pts = [(x, y)]
            ang = rnd.uniform(0, math.tau)
            for j in range(rnd.randint(4, 9)):
                ang += rnd.uniform(-0.9, 0.9)
                x += math.cos(ang) * rnd.uniform(10, 26)
                y += math.sin(ang) * rnd.uniform(10, 26)
                pts.append((x, y))
            d.line(pts, fill=(70, 120, 165, 150), width=2)
            d.line([(p[0] + 1.2, p[1] + 1.2) for p in pts], fill=(255, 255, 255, 130), width=1)
    elif kind == "up":
        # tracce a spina di pesce (si sale a piedi accanto ai cani) e ombra di pendio
        for lane in range(5):
            y = top + (lane + 0.5) * (bot - top) / 5
            x = x1 - 40
            while x > x0 + 20:
                for sgn in (-1, 1):
                    d.line([(x, y), (x + 15, y + sgn * 12)], fill=(120, 150, 185, 70), width=3)
                x -= 48
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        for x in range(int(x0), int(x1)):
            t = (x - x0) / (x1 - x0)
            sd.line([(x, top), (x, bot)], fill=(70, 100, 140, int(55 * t)))
        ov = Image.alpha_composite(ov, sh)
    elif kind == "down":
        # solchi lisci dei pattini e luce sul pendio
        for lane in range(5):
            y = top + (lane + 0.5) * (bot - top) / 5
            for off in (-9, 9):
                d.line([(x0, y + off), (x1, y + off + rnd.uniform(-3, 3))], fill=(130, 160, 190, 80), width=3)
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        for x in range(int(x0), int(x1)):
            t = (x - x0) / (x1 - x0)
            sd.line([(x, top), (x, bot)], fill=(255, 255, 255, int(55 * (1 - t))))
        ov = Image.alpha_composite(ov, sh)
    elif kind == "wind":
        # sastrugi: increspature della neve spazzata dal vento, di traverso
        for i in range(60):
            x = rnd.uniform(x0, x1)
            y = rnd.uniform(top, bot)
            L = rnd.uniform(25, 60)
            d.arc([x - L, y - 6, x + L * 0.2, y + 10], 200, 330, fill=(140, 170, 200, 110), width=3)
            d.arc([x - L, y - 4, x + L * 0.2, y + 12], 200, 330, fill=(255, 255, 255, 140), width=2)
    elif kind == "fresh":
        # ombre azzurre dei cumuli (i cumuli veri sono in 3D)
        pass
    elif kind == "hut":
        pass
    elif kind == "fork":
        # isola di neve al centro: copre la corsia di mezzo (gli abeti sono in 3D)
        lane = (bot - top) / 5
        y0, y1 = top + lane * 2 + 4, top + lane * 3 - 4
        x_a, x_b = x0 + 8, x1 - 26
        isl = Image.new("RGBA", img.size, (0, 0, 0, 0))
        idr = ImageDraw.Draw(isl)
        idr.rounded_rectangle([x_a, y0 + 6, x_b, y1 + 8], radius=int(lane * 0.45), fill=(120, 150, 180, 120))
        idr.rounded_rectangle([x_a, y0, x_b, y1], radius=int(lane * 0.45), fill=(246, 249, 252, 255))
        for i in range(40):
            x = rnd.uniform(x_a + 10, x_b - 10)
            y = rnd.uniform(y0 + 6, y1 - 6)
            r = rnd.uniform(5, 14)
            idr.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(222, 232, 242, 160))
        isl = isl.filter(ImageFilter.GaussianBlur(1.2))
        ov = Image.alpha_composite(ov, isl)
    edited = Image.alpha_composite(img, ov)
    if kind in ("ice", "up", "down", "wind"):
        edited = keep_lines(img, edited, (x0, top, x1, bot))
    # cartelli all'ingresso: doppia linea rossa e due dischi, come le curve
    d2 = ImageDraw.Draw(edited)
    ex = x1 - 8
    for off in (-4, 4):
        d2.line([(ex + off, top - 8), (ex + off, bot + 8)], fill=RED, width=3)
    sg = sign("wind" if kind == "wind_l" else kind)
    for y in (top - sg.height * 0.55, bot - sg.height * 0.45):
        edited.alpha_composite(sg, (int(ex - sg.width / 2), int(y)))
    return edited


def main():
    rnd = random.Random(7)
    for kind, (src, label, extra) in SEGMENTS.items():
        face = json.loads((FACES / f"{src}.json").read_text())
        base = Image.open(TILES / f"{src}.webp").convert("RGBA")
        out = paint(kind, base, face, rnd)
        fid = f"fan_{kind}"
        out.save(TILES / f"{fid}.webp", "WEBP", quality=88)
        nf = dict(face)
        nf["id"] = fid
        nf["image"] = f"res://assets/tiles/{fid}.webp"
        nf["label"] = label
        nf["segment"] = kind
        nf["fanmade"] = True
        nf.update(extra)
        cells = face["cells"]
        # caselle speciali scelte per posizione: (colonna dall'ingresso, corsia dall'alto)
        xs = sorted(set(round(p[0]) for p in cells), reverse=True)
        ys = sorted(set(round(p[1]) for p in cells))
        def idx(col, lane):
            for i, p in enumerate(cells):
                if round(p[0]) == xs[col] and round(p[1]) == ys[lane]:
                    return i
            return -1
        if kind == "fresh":
            nf["fresh"] = [idx(c, l) for (c, l) in ((1, 0), (2, 0), (2, 1), (3, 3), (3, 4), (4, 4), (4, 0))]
        if kind == "hut":
            nf["hut"] = [idx(3, 0)]
        if kind == "fork":
            # niente corsia di mezzo: si toglie con i suoi collegamenti e si rinumera
            mid_lane = [idx(c, 2) for c in range(len(xs))]
            keep = [i for i in range(len(cells)) if i not in mid_lane]
            remap = {old: new for new, old in enumerate(keep)}
            nf["cells"] = [cells[i] for i in keep]
            nf["links"] = [[remap[a], remap[b]] for a, b in face.get("links", []) if a in remap and b in remap]
            cells2 = nf["cells"]
            def idx2(col, lane):
                for i, p in enumerate(cells2):
                    if round(p[0]) == xs[col] and round(p[1]) == ys[lane]:
                        return i
                return -1
            # corridoio di sinistra con neve fresca, quello di destra con gli alberelli
            nf["fresh"] = [idx2(c, l) for (c, l) in ((2, 0), (2, 1), (3, 1))]
            nf["saplings"] = [idx2(2, 4), idx2(4, 3)]
            ymid = ys[2]
            nf["island"] = [[xs[c], ymid] for c in range(1, len(xs) - 1)]
            nf["special"] = "fork"
        (FACES / f"{fid}.json").write_text(json.dumps(nf, ensure_ascii=False, indent=1))
        print("ok", fid)


if __name__ == "__main__":
    main()
