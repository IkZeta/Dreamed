#!/usr/bin/env python3
"""Genera los sprites del juego (ilustración suave) / Generates the game's sprites (soft illustration).

Cada sprite es una pieza recortable dibujada en SVG con degradados, sombra interior y luz de
luna en el borde, y se rasteriza a PNG con Chromium (Playwright). Las piezas usan las mismas
coordenadas que el dibujo por código del juego, así que las animaciones siguen igual.
Each sprite is a cut-out piece drawn in SVG with gradients, inner shadow and moonlit rim,
rasterised to PNG with Chromium (Playwright). Pieces use the same coordinates as the game's
code drawing, so the animations stay the same.

Uso / Usage:  python3 tools/make_sprites.py
Salida / Output: assets/sprites/*.png y scripts/visual/sprite_rects.gd
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
RECTS = os.path.join(ROOT, "scripts", "visual", "sprite_rects.gd")
## Pixel art: la partida se ve a 960 x 540 (la mitad de 1920 x 1080). Un píxel del arte es un
## píxel de esa pantalla pequeña. Kroker se dibuja a 0,55 de su lienzo y los enemigos a 1.
## Pixel art: the game is seen at 960 x 540 (half of 1920 x 1080). One art pixel is one
## pixel of that small screen. Kroker is drawn at 0.55 of his canvas, enemies at 1.
PX_KROKER = 0.5 / 2.0     # Kroker se dibuja a 0,5 / Kroker is drawn at 0.5
PX_NPC = 0.42
PX_ROOM = 0.72 / 2.0      # la habitación se dibuja a 0,72 y luego a la mitad / the room is drawn at 0.72, then halved             # personajes del plano astral, que se ven grandes / astral characters, shown large
PX_ENEMY = 1.0 / 2.0
SUPER = 8          # se dibuja 8 veces más grande y luego se reduce / drawn 8x larger, then reduced

SPRITES = {}       # nombre → (x, y, w, h, svg)
_uid = [0]


# --- Color -------------------------------------------------------------------

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return hexc([a[i] + (b[i] - a[i]) * t for i in range(3)])


def light(c, t):
    return mix(c, "#ffffff", t)


def dark(c, t):
    return mix(c, "#0a0620", t)


def uid():
    _uid[0] += 1
    return "u%d" % _uid[0]


# --- Piezas de dibujo / Drawing pieces ------------------------------------------

FILTERS = """
<filter id="b1" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1"/></filter>
<filter id="b2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>
<filter id="b4" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>
"""
BIG = "M-2000,-2000 H4000 V4000 H-2000 Z "


def shaded(d, base, outline=True, shade=0.42, rim=0.5, grad=True, extra="", deep=None, sw=1.1, rim_color="#dfe6ff"):
    """Forma con degradado, sombra interior abajo a la derecha y luz de luna arriba a la izquierda.
    Shape with gradient, inner shadow bottom-right and moonlight top-left."""
    i = uid()
    deep = deep or dark(base, 0.5)
    out = ["<defs><clipPath id='c%s'><path d='%s'/></clipPath>" % (i, d)]
    if grad:
        out.append("<linearGradient id='g%s' x1='0' y1='0' x2='0.9' y2='1'>"
                   "<stop offset='0' stop-color='%s'/><stop offset='0.5' stop-color='%s'/>"
                   "<stop offset='1' stop-color='%s'/></linearGradient>" % (i, light(base, 0.16), base, dark(base, 0.22)))
    out.append("</defs>")
    out.append("<path d='%s' fill='%s'/>" % (d, "url(#g%s)" % i if grad else base))
    out.append("<g clip-path='url(#c%s)'>" % i)
    out.append(extra)
    out.append("<path d='%s%s' transform='translate(-5,-4)' fill-rule='evenodd' fill='%s' opacity='%.2f' filter='url(#b4)'/>"
               % (BIG, d, deep, shade))
    if rim > 0:
        out.append("<path d='%s%s' transform='translate(2.2,2.2)' fill-rule='evenodd' fill='%s' opacity='%.2f' filter='url(#b1)'/>"
                   % (BIG, d, rim_color, rim))
    out.append("</g>")
    if outline:
        out.append("<path d='%s' fill='none' stroke='%s' stroke-width='%.2f' stroke-linejoin='round' opacity='0.7'/>"
                   % (d, dark(base, 0.55), sw))
    return "".join(out)


def ellipse_d(cx, cy, rx, ry):
    return "M%.2f,%.2f A%.2f,%.2f 0 1 0 %.2f,%.2f A%.2f,%.2f 0 1 0 %.2f,%.2f Z" % (
        cx - rx, cy, rx, ry, cx + rx, cy, rx, ry, cx - rx, cy)


def star_d(cx, cy, r, inner=0.45, rot=-90):
    pts = []
    for k in range(10):
        a = math.radians(rot + k * 36)
        rr = r if k % 2 == 0 else r * inner
        pts.append("%.2f,%.2f" % (cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return "M" + " L".join(pts) + " Z"


def glow(cx, cy, r, color, op):
    i = uid()
    return ("<defs><radialGradient id='r%s'><stop offset='0' stop-color='%s' stop-opacity='%.2f'/>"
            "<stop offset='1' stop-color='%s' stop-opacity='0'/></radialGradient></defs>"
            "<circle cx='%.2f' cy='%.2f' r='%.2f' fill='url(#r%s)'/>" % (i, color, op, color, cx, cy, r, i))


def add(name, x, y, w, h, body, xf=(1, 1, 0, 0), px=PX_ENEMY, colors=12, ghost=False, post=None, flat=False, outline="#1a1024"):
    """xf = (sx, sy, tx, ty): escala y mueve la pieza (para hacer a Kroker más bajito).
    flat = pixel art de verdad: formas de color plano (sin degradados), cada píxel toma el color
    que más ocupa su celda y se añade un contorno de 1 píxel del color "outline".
    xf = (sx, sy, tx, ty): scales and moves the piece (to make Kroker shorter).
    flat = real pixel art: flat-colour shapes (no gradients), each pixel takes the colour that
    fills most of its cell, plus a 1-pixel outline in the "outline" colour."""
    SPRITES[name] = dict(x=x, y=y, w=w, h=h, body=body, xf=xf, px=px, colors=colors, ghost=ghost, post=post, flat=flat, outline=outline)


def flat_pixelize(img, tw, th, palette, outline):
    """Pixel art limpio: cada píxel toma el color de la paleta que más ocupa su celda (nada de
    mezclas), y alrededor de la silueta va un contorno de 1 píxel.
    Clean pixel art: each pixel takes the palette colour covering most of its cell (no blends),
    with a 1-pixel outline around the silhouette."""
    from PIL import Image
    pal = [rgb(c) for c in palette]
    W, H = img.size
    src = img.load()
    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    op = out.load()
    for yy in range(th):
        y0, y1 = int(yy * H / th), max(int(yy * H / th) + 1, int((yy + 1) * H / th))
        for xx in range(tw):
            x0, x1 = int(xx * W / tw), max(int(xx * W / tw) + 1, int((xx + 1) * W / tw))
            votes = {}
            n = 0
            for sy in range(y0, y1, 2):
                for sx in range(x0, x1, 2):
                    r, g, b, a = src[sx, sy]
                    n += 1
                    if a < 128:
                        votes[-1] = votes.get(-1, 0) + 1
                        continue
                    best = min(range(len(pal)), key=lambda k: (pal[k][0] - r) ** 2 + (pal[k][1] - g) ** 2 + (pal[k][2] - b) ** 2)
                    votes[best] = votes.get(best, 0) + 1
            k = max(votes, key=votes.get)
            if k >= 0:
                op[xx, yy] = pal[k] + (255,)
    oc = rgb(outline) + (255,)
    snap = out.copy()
    sp = snap.load()
    for yy in range(th):
        for xx in range(tw):
            if sp[xx, yy][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = xx + dx, yy + dy
                if 0 <= nx < tw and 0 <= ny < th and sp[nx, ny][3]:
                    op[xx, yy] = oc
                    break
    return out


def flat(d, color, extra_attrs=""):
    """Forma de color plano para el modo pixel art / Flat-colour shape for pixel-art mode."""
    return "<path d='%s' fill='%s' %s/>" % (d, color, extra_attrs)


## Kroker es un niño bajito: la cabeza no cambia, pero el torso, los brazos y las piernas
## son mucho más cortos (proporción de niño pequeño). Todo lo que está por encima de la cadera baja 78 unidades.
## Kroker is a short kid: the head stays the same, but the torso, arms and legs are shorter.
## Everything above the hips moves down 78 units.
DROP = 78
XF_HEAD = (1, 1, 0, DROP)
XF_TORSO = (1, 0.65, 0, 98 + DROP - 0.65 * 98)
XF_ARM = (1, 0.65, 0, 106 + DROP - 0.65 * 106)
XF_LEG = (1, 0.52, 0, 288 - 0.52 * 288)


def face_painter(eyes, mouth, glasses):
    """Pinta la cara píxel a píxel para que se lea a tamaño pequeño.
    Paints the face pixel by pixel so it reads at a small size."""
    def paint(img, to_px):
        pix = img.load()
        w, h = img.size

        def put(x, y, c):
            if 0 <= x < w and 0 <= y < h:
                pix[x, y] = c
        dark_c = (42, 34, 56, 255)
        frame = (43, 41, 69, 255)
        for cx in (90, 110):
            ex, ey = to_px(cx, 67)
            ex, ey = int(round(ex - 0.5)), int(round(ey - 0.5))
            if glasses:
                # Montura redonda de 5 x 4 con cristal claro / 5 x 4 round frame with a light lens
                for gx in range(-2, 3):
                    for gy in range(-2, 2):
                        edge = gx in (-2, 2) or gy in (-2, 1)
                        corner = gx in (-2, 2) and gy in (-2, 1)
                        if corner:
                            continue
                        if edge:
                            put(ex + gx, ey + gy, frame)
                        else:
                            r, g, b, a = pix[ex + gx, ey + gy]
                            pass  # el cristal deja ver la piel / the lens shows the skin
            if eyes == "open":
                put(ex, ey - 1, dark_c)
                put(ex, ey, dark_c)
            else:
                put(ex - 1, ey, dark_c)
                put(ex, ey, dark_c)
                put(ex + 1, ey, dark_c)
        if glasses:
            bx, by = to_px(100, 66)
            put(int(round(bx - 0.5)), int(round(by - 1.5)), frame)
        mx, my = to_px(100, 82)
        mx, my = int(round(mx - 0.5)), int(round(my - 0.5))
        if mouth == "smile":
            put(mx - 1, my, (154, 90, 108, 255))
            put(mx, my + 0, (154, 90, 108, 255))
        else:
            for dx in (-1, 0):
                for dy in (0, 1):
                    put(mx + dx, my + dy, (110, 52, 74, 255))
    return paint


# --- Kroker -------------------------------------------------------------------

SKIN = "#f1cfbb"
SKIN_SHADE = "#c3a0b0"
HAIR = "#16141f"
FRAME = "#2b2945"
PAJAMAS = {
    "bat": {"base": "#33457f", "pattern": "#ece6f4", "piping": "#ece6f4", "slippers": "#c9536b", "print": "stripes"},
    "shield": {"base": "#b46e8f", "pattern": "#7c4063", "piping": "#f6e9ef", "slippers": "#6d3a5a", "print": "plaid"},
    "book": {"base": "#2b3d8f", "pattern": "#f6d993", "piping": "#f6d993", "slippers": "#1d2560", "print": "stars"},
    "vacuum": {"base": "#62a9a1", "pattern": "#f4f1e6", "piping": "#f4f1e6", "slippers": "#2f6e69", "print": "dots"},
    "finger": {"base": "#3a2457", "pattern": "#ff5f7a", "piping": "#7ff5ff", "slippers": "#ff5f7a", "print": "bolts"},
    "teddy": {"base": "#b8845e", "pattern": "#f4e2c8", "piping": "#f4e2c8", "slippers": "#6e432c", "print": "paws"},
}


def pattern_fill(pj, d):
    """Estampado del pijama recortado a la forma / Pajama print clipped to the shape."""
    i = uid()
    col = pj["pattern"]
    kind = pj["print"]
    if kind == "stripes":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='9' height='9'>"
               "<rect x='3' y='0' width='2.4' height='9' fill='%s' opacity='0.5'/>"
               "<rect x='5.6' y='0' width='0.7' height='9' fill='%s' opacity='0.25'/></pattern>" % (i, col, col))
    elif kind == "plaid":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='16' height='16'>"
               "<rect x='0' y='5' width='16' height='4' fill='%s' opacity='0.5'/>"
               "<rect x='5' y='0' width='4' height='16' fill='%s' opacity='0.42'/>"
               "<rect x='0' y='11' width='16' height='1' fill='#f6e9ef' opacity='0.3'/>"
               "<rect x='12' y='0' width='1' height='16' fill='#f6e9ef' opacity='0.22'/></pattern>" % (i, col, col))
    elif kind == "stars":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='16' height='26'>"
               "<path d='%s' fill='%s' opacity='0.9'/><path d='%s' fill='%s' opacity='0.9'/>"
               "<circle cx='12' cy='5' r='0.7' fill='%s' opacity='0.7'/></pattern>"
               % (i, star_d(5, 6, 2.8), col, star_d(13, 19, 2.8), col, col))
    elif kind == "bolts":
        # Rayitos láser en diagonal / Little diagonal laser beams
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='16' height='18'>"
               "<path d='M3,13 L9,5' stroke='%s' stroke-width='2.2' stroke-linecap='round' opacity='0.9'/>"
               "<path d='M11,17 L15,11' stroke='#7ff5ff' stroke-width='1.6' stroke-linecap='round' opacity='0.8'/>"
               "<circle cx='9.5' cy='4.5' r='1.3' fill='#ffffff' opacity='0.8'/></pattern>" % (i, col))
    elif kind == "paws":
        # Huellas de oso / Bear paw prints
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='18' height='22'>"
               "<ellipse cx='6' cy='8' rx='3' ry='2.5' fill='%s' opacity='0.85'/>"
               "<circle cx='3.2' cy='4.6' r='1.1' fill='%s' opacity='0.85'/><circle cx='6' cy='3.8' r='1.1' fill='%s' opacity='0.85'/>"
               "<circle cx='8.8' cy='4.6' r='1.1' fill='%s' opacity='0.85'/>"
               "<ellipse cx='14' cy='18' rx='2.6' ry='2.2' fill='%s' opacity='0.6'/></pattern>" % (i, col, col, col, col, col))
    else:  # dots
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='14' height='22'>"
               "<circle cx='4' cy='5' r='2.3' fill='%s' opacity='0.85'/>"
               "<circle cx='11' cy='16' r='2.3' fill='%s' opacity='0.85'/></pattern>" % (i, col, col))
    return "<defs>%s</defs><rect x='0' y='0' width='300' height='400' fill='url(#p%s)'/>" % (pat, i)


def fold(d, base, w=2.2, op=0.35):
    return "<path d='%s' fill='none' stroke='%s' stroke-width='%.1f' stroke-linecap='round' opacity='%.2f' filter='url(#b1)'/>" % (
        d, dark(base, 0.45), w, op)


def kroker_leg(outfit, side):
    pj = PAJAMAS[outfit]
    base = dark(pj["base"], 0.08 if side == 0 else 0.16)
    dx = 0 if side == 0 else 25
    leg = "M%d,170 L%d,170 Q%d,222 %d,268 L%d,268 Q%d,222 %d,170 Z" % (
        77 + dx, 98 + dx, 100 + dx, 98 + dx, 77 + dx, 75 + dx, 77 + dx)
    body = shaded(leg, base, extra=pattern_fill(pj, leg) + fold("M%d,200 Q%d,215 %d,232" % (92 + dx, 95 + dx, 93 + dx), base), shade=0.5)
    # Puño con ribete / Cuff with piping
    cuff = "M%d,265 L%d,265 L%d,273 Q%d,275 %d,273 Z" % (76.5 + dx, 98.5 + dx, 98.5 + dx, 87.5 + dx, 76.5 + dx)
    body += shaded(cuff, pj["piping"], shade=0.3, rim=0.3)
    # Zapatilla mullida / Fluffy slipper
    cx = 87.5 + dx
    slip = "M%.1f,282 C%.1f,274 %.1f,274 %.1f,278 C%.1f,276 %.1f,280 %.1f,284 C%.1f,290 %.1f,290 %.1f,282 Z" % (
        cx - 15, cx - 14, cx - 2, cx + 2, cx + 10, cx + 16, cx + 15, cx + 12, cx - 12, cx - 15)
    body += shaded(slip, pj["slippers"], shade=0.5, rim=0.45)
    body += "<path d='M%.1f,279 Q%.1f,276 %.1f,279' stroke='#ffffff' stroke-width='1.6' fill='none' opacity='0.35' stroke-linecap='round'/>" % (
        cx - 9, cx - 3, cx + 3)
    add("kroker_leg_%s_%s" % ("l" if side == 0 else "r", outfit), 66 + dx, 166, 40, 128, body, XF_LEG, PX_KROKER)


def mirror_x(d):
    """Refleja una ruta (pares x,y absolutos) respecto a x = 100 / Mirrors a path (absolute x,y pairs) about x = 100."""
    import re
    return re.sub(r"(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)", lambda m: "%g,%s" % (200 - float(m.group(1)), m.group(2)), d)


def kroker_arm(outfit, side):
    pj = PAJAMAS[outfit]
    base = dark(pj["base"], 0.04 if side == 0 else 0.12)
    sleeve = "M68,104 Q77,100 82,110 L79,178 Q71,182 63,180 L64,140 Q65,118 68,104 Z"
    cuff = "M63.4,172 L79.4,172 L79,179 Q71,182.5 63,180 Z"
    hand = "M63,187 C63,181 67,180 70,180 C74,180 77,182 77,188 C77,194 74,196 70,196 C66,196 63,193 63,187 Z"
    thumb = "M75,184 C79,183 80,187 77,189 Z"
    skin = SKIN if side == 0 else mix(SKIN, SKIN_SHADE, 0.4)
    if side == 1:
        sleeve, cuff, hand, thumb = mirror_x(sleeve), mirror_x(cuff), mirror_x(hand), mirror_x(thumb)
    body = shaded(hand, skin, shade=0.35, rim=0.4, sw=0.9)
    body += shaded(thumb, skin, shade=0.2, rim=0.2, sw=0.7)
    dx = 0 if side == 0 else 62
    body += shaded(sleeve, base, extra=pattern_fill(pj, sleeve) + fold(
        "M%d,130 Q%d,145 %d,160" % (73 + (0 if side == 0 else 54), 72 + (0 if side == 0 else 56), 74 + (0 if side == 0 else 52)), base), shade=0.5)
    body += shaded(cuff, pj["piping"], shade=0.3, rim=0.25)
    add("kroker_arm_%s_%s" % ("l" if side == 0 else "r", outfit), 56 if side == 0 else 112, 96, 32, 104, body, XF_ARM, PX_KROKER)


def kroker_torso(outfit):
    pj = PAJAMAS[outfit]
    base = pj["base"]
    pip = pj["piping"]
    neck = "M93,84 L107,84 L107,102 L93,102 Z"
    body = shaded(neck, mix(SKIN, SKIN_SHADE, 0.45), shade=0.4, rim=0.2, outline=False)
    shirt = "M84,98 Q100,101 116,98 Q129,101 132,108 L134,176 Q100,181 66,176 L68,108 Q71,101 84,98 Z"
    folds = (fold("M78,150 Q84,160 82,172", base) + fold("M122,146 Q117,158 120,172", base) +
             fold("M90,128 Q96,134 94,142", base, 1.6, 0.25))
    body += shaded(shirt, base, extra=pattern_fill(pj, shirt) + folds, shade=0.5)
    # Solapas / Lapels
    body += shaded("M86,97 L99,99 L100,122 L90,110 Z", light(base, 0.12), shade=0.25, rim=0.3, sw=0.8)
    body += shaded("M114,97 L101,99 L100,122 L110,110 Z", dark(base, 0.05), shade=0.3, rim=0.15, sw=0.8)
    body += "<path d='M86,97 L90,110 L100,122 L110,110 L114,97' fill='none' stroke='%s' stroke-width='2' stroke-linejoin='round'/>" % pip
    body += "<path d='M100,122 L100,176' stroke='%s' stroke-width='1.4' opacity='0.7'/>" % pip
    for y in (134, 150, 166):
        body += "<circle cx='103' cy='%d' r='2.5' fill='%s'/><circle cx='102.3' cy='%.1f' r='0.9' fill='#ffffff' opacity='0.7'/>" % (y, pip, y - 0.8)
    body += "<path d='M76,126 L90,126 L90,138 Q83,140 76,138 Z' fill='none' stroke='%s' stroke-width='1.1' opacity='0.75'/>" % pip
    body += "<path d='M66.5,176 Q100,181 133.5,176' fill='none' stroke='%s' stroke-width='2.6' stroke-linecap='round'/>" % pip
    add("kroker_torso_%s" % outfit, 60, 80, 80, 104, body, XF_TORSO, PX_KROKER)


def kroker_head():
    body = ""
    for cx, col in ((76, SKIN), (124, SKIN_SHADE)):
        e = ellipse_d(cx, 68, 5.5, 7.5)
        body += shaded(e, col, shade=0.35, rim=0.3, sw=0.8)
        body += "<path d='%s' fill='%s' opacity='0.35'/>" % (ellipse_d(cx, 68.5, 2.5, 4), dark(col, 0.25))
    face = "M76,62 C76,44 88,37 100,37 C112,37 124,44 124,62 C124,80 113,91 100,91 C87,91 76,80 76,62 Z"
    i = uid()
    fgrad = ("<defs><radialGradient id='f%s' cx='0.4' cy='0.38' r='0.75'><stop offset='0' stop-color='#fde6d8'/>"
             "<stop offset='0.55' stop-color='%s'/><stop offset='1' stop-color='#d8aaa6'/></radialGradient></defs>" % (i, SKIN))
    body += fgrad
    body += shaded(face, SKIN, grad=False, shade=0.42, rim=0.35, deep=SKIN_SHADE, sw=0.9)
    body = body.replace("<path d='%s' fill='%s'/>" % (face, SKIN), "<path d='%s' fill='url(#f%s)'/>" % (face, i), 1)
    body += glow(87, 78, 6.5, "#f2a0ad", 0.45) + glow(114, 78, 6, "#f2a0ad", 0.35)
    # Nariz / Nose
    body += "<path d='M101,70 Q104,75 101,77' fill='none' stroke='%s' stroke-width='1.4' stroke-linecap='round' opacity='0.85'/>" % SKIN_SHADE
    # Pelo negro con volumen y reflejos azulados / Black hair with volume and bluish highlights
    hair = ("M75,70 C70,55 73,42 83,35 C91,29 108,27 117,32 C126,37 130,51 126,70 C124,62 121,57 117,55 "
            "C114,60 110,60 107,53 C103,59 97,60 94,52 C90,58 85,58 81,54 C78,58 76,63 75,70 Z")
    tuft = "M100,31 C99,24 104,21 109,23 C105,24 104,27 106,31 Z"
    j = uid()
    body += ("<defs><linearGradient id='h%s' x1='0' y1='0' x2='0.8' y2='1'><stop offset='0' stop-color='#3b4475'/>"
             "<stop offset='0.4' stop-color='#1b1a2b'/><stop offset='1' stop-color='#0a0912'/></linearGradient></defs>" % j)
    body += shaded(tuft, "#1b1a2b", shade=0.3, rim=0.35, sw=0.8)
    body += shaded(hair, HAIR, grad=False, shade=0.5, rim=0.55, rim_color="#8f9ee0", deep="#000000", sw=0.9)
    body = body.replace("<path d='%s' fill='%s'/>" % (hair, HAIR), "<path d='%s' fill='url(#h%s)'/>" % (hair, j), 1)
    for d, w, op in (("M80,47 C84,40 90,36 98,34", 2.4, 0.7), ("M84,53 C87,48 90,45 94,43", 1.6, 0.5), ("M110,35 C116,37 121,42 123,48", 1.6, 0.4)):
        body += "<path d='%s' fill='none' stroke='#9fb0ff' stroke-width='%.1f' stroke-linecap='round' opacity='%.2f' filter='url(#b1)'/>" % (d, w, op)
    # Cejas / Eyebrows
    body += "<path d='M85,59.5 Q90,57 95,58.5' fill='none' stroke='%s' stroke-width='2' stroke-linecap='round' opacity='0.9'/>" % HAIR
    body += "<path d='M105,58.5 Q110,57 115,59.5' fill='none' stroke='%s' stroke-width='2' stroke-linecap='round' opacity='0.9'/>" % HAIR
    head = body

    eyes = ""
    for x in (90, 110):
        eyes += "<path d='%s' fill='#2a2238'/>" % ellipse_d(x, 67, 3.0, 3.6)
        eyes += "<path d='%s' fill='#4d3f78' opacity='0.8'/>" % ellipse_d(x + 0.3, 68.2, 1.8, 1.7)
        eyes += "<circle cx='%.1f' cy='65.8' r='1.05' fill='#ffffff'/><circle cx='%.1f' cy='68.8' r='0.5' fill='#ffffff' opacity='0.6'/>" % (x - 1, x + 1)
    closed = ""
    for x in (90, 110):
        closed += "<path d='M%.1f,67 Q%.1f,69.4 %.1f,67' fill='none' stroke='#2a2238' stroke-width='1.6' stroke-linecap='round'/>" % (x - 3.4, x, x + 3.4)
    mouth = "<path d='M95,81 Q100,84.5 105,81' fill='none' stroke='#9a5a6c' stroke-width='2' stroke-linecap='round'/>"
    yawn = shaded(ellipse_d(100, 83, 3.8, 5.4), "#7d4a5e", shade=0.5, rim=0.2, sw=0.8)
    yawn += "<path d='%s' fill='#d98a9a' opacity='0.8'/>" % ellipse_d(100, 86.4, 2.2, 1.5)
    gl = ""
    for cx in (90, 110):
        i = uid()
        gl += ("<defs><linearGradient id='l%s' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#eef2ff' stop-opacity='0.4'/>"
               "<stop offset='0.6' stop-color='#cbd6ff' stop-opacity='0.1'/><stop offset='1' stop-color='#8f9ee0' stop-opacity='0.25'/></linearGradient></defs>" % i)
        gl += "<path d='%s' fill='url(#l%s)' stroke='%s' stroke-width='1.5'/>" % (ellipse_d(cx, 67, 9, 7.2), i, FRAME)
    gl += "<path d='M99,65.2 Q100,64 101,65.2' fill='none' stroke='%s' stroke-width='1.4'/>" % FRAME
    gl += "<path d='M81,64 L75.5,62' stroke='%s' stroke-width='1.6' stroke-linecap='round'/>" % FRAME
    gl += "<path d='M119,64 L124.5,62' stroke='%s' stroke-width='1.6' stroke-linecap='round'/>" % FRAME
    # La cara va pintada en la cabeza: ojos abiertos o cerrados, gafas o no, y bostezo
    # The face is painted onto the head: eyes open or closed, glasses or not, and yawning
    for suffix, e, m in (("", "open", "smile"), ("_blink", "closed", "smile"), ("_yawn", "closed", "yawn")):
        add("kroker_head" + suffix, 64, 18, 72, 78, head, XF_HEAD, PX_KROKER, 14, post=face_painter(e, m, False))
        add("kroker_head" + suffix + "_g", 64, 18, 72, 78, head, XF_HEAD, PX_KROKER, 14, post=face_painter(e, m, True))




def kroker_weapons():
    # Bate / Bat
    bat = "M-3,4 L3,4 C5,-40 8,-80 8,-96 C8,-104 5,-109 0,-109 C-5,-109 -8,-104 -8,-96 C-8,-80 -5,-40 -3,4 Z"
    i = uid()
    wood = ("<defs><linearGradient id='w%s' x1='0' y1='0' x2='1' y2='0'><stop offset='0' stop-color='#f0cb9a'/>"
            "<stop offset='0.45' stop-color='#c99a68'/><stop offset='1' stop-color='#87593a'/></linearGradient></defs>" % i)
    grain = "".join("<path d='M%.1f,-100 C%.1f,-70 %.1f,-40 %.1f,-10' fill='none' stroke='#7a4f33' stroke-width='0.6' opacity='0.35'/>" % (
        x, x + 0.5, x - 0.3, x * 0.4) for x in (-4, -1, 2.5, 5))
    b = wood + shaded(bat, "#c99a68", grad=False, extra=grain, shade=0.45, rim=0.5)
    b = b.replace("<path d='%s' fill='#c99a68'/>" % bat, "<path d='%s' fill='url(#w%s)'/>" % (bat, i), 1)
    b += shaded("M-3.9,-16 L3.9,-16 L3.6,4 L-3.6,4 Z", "#3a3355", shade=0.4, rim=0.3, sw=0.8)
    for y in range(-14, 4, 4):
        b += "<path d='M-3.8,%d L3.8,%d' stroke='#6b6394' stroke-width='1' opacity='0.7'/>" % (y + 2, y)
    b += shaded(ellipse_d(0, 5, 5.2, 2.6), "#2b2545", shade=0.3, rim=0.3, sw=0.7)
    b += "<path d='%s' fill='#f6d993'/>" % star_d(0, -86, 3.6)
    add("weapon_bat", -12, -113, 24, 122, b, px=PX_KROKER)

    # Almohada / Pillow
    pts = []
    for k in range(64):
        a = math.tau * k / 64
        c, s = math.cos(a), math.sin(a)
        p = (math.copysign(abs(c) ** 0.6, c) * 36, math.copysign(abs(s) ** 0.6, s) * 26)
        f = 1 - 0.07 * abs(math.sin(a * 2))
        pts.append("%.2f,%.2f" % (p[0] * f, p[1] * f))
    pil = "M" + " L".join(pts) + " Z"
    i = uid()
    pg = ("<defs><radialGradient id='q%s' cx='0.38' cy='0.35' r='0.8'><stop offset='0' stop-color='#ffffff'/>"
          "<stop offset='0.6' stop-color='#f0ebfb'/><stop offset='1' stop-color='#cfc6ee'/></radialGradient></defs>" % i)
    p = pg + shaded(pil, "#f0ebfb", grad=False, shade=0.5, rim=0.4, deep="#8d82c4",
                    extra="<path d='M-30,1 Q0,4 30,1' fill='none' stroke='#cfc6ee' stroke-width='1.2'/>"
                          + fold("M-20,-14 Q-12,-6 -16,4", "#cfc6ee", 2.5, 0.3) + fold("M18,12 Q10,4 16,-8", "#cfc6ee", 2.5, 0.3))
    p = p.replace("<path d='%s' fill='#f0ebfb'/>" % pil, "<path d='%s' fill='url(#q%s)'/>" % (pil, i), 1)
    p += "<path d='%s' fill='#f6d993' stroke='#d9b35e' stroke-width='0.6'/>" % star_d(-2, -2, 5.5)
    for cx, cy in ((-34, -24), (34, -24), (34, 24), (-34, 24)):
        p += "<circle cx='%d' cy='%d' r='2.2' fill='#ffffff' opacity='0.8'/>" % (cx * 0.92, cy * 0.92)
    add("weapon_pillow", -42, -32, 84, 64, p, px=PX_KROKER)

    # Libro de cuentos / Storybook
    bk = shaded("M-29,-14 Q-14,-12 0,-9 L0,16 Q-14,13 -29,12 Z", "#3b4fa8", shade=0.4, rim=0.4)
    bk += shaded("M29,-14 Q14,-12 0,-9 L0,16 Q14,13 29,12 Z", "#34479c", shade=0.45, rim=0.2)
    bk += shaded("M-25.5,-11.5 Q-12,-10 -0.8,-7 L-0.8,12.5 Q-12,10.5 -25.5,9.5 Z", "#fbf3dc", shade=0.25, rim=0.2, sw=0.6)
    bk += shaded("M25.5,-11.5 Q12,-10 0.8,-7 L0.8,12.5 Q12,10.5 25.5,9.5 Z", "#f1e6c8", shade=0.35, rim=0.1, sw=0.6)
    for ly in (-4, 0, 4, 8):
        bk += "<path d='M-21,%.1f Q-13,%.1f -5,%.1f' fill='none' stroke='#5a5a82' stroke-width='0.8' opacity='0.4'/>" % (ly - 2, ly - 1.4, ly)
        bk += "<path d='M5,%.1f Q13,%.1f 21,%.1f' fill='none' stroke='#5a5a82' stroke-width='0.8' opacity='0.4'/>" % (ly, ly - 1.4, ly - 2)
    bk += "<path d='M3,-7 L3,20 L5.5,17 L8,20 L8,-6' fill='#e3a6c4'/>"
    for cx, cy in ((-27, -12), (-27, 10), (27, -12), (27, 10)):
        bk += "<path d='%s' fill='#f6d993'/>" % star_d(cx, cy, 2.4)
    add("weapon_book", -32, -18, 64, 40, bk, px=PX_KROKER)

    # Depósito y boquilla del Barrepesadillas / Nightmare Sweeper tank and nozzle
    tank = shaded(ellipse_d(150, 252, 22, 30), "#e9e3f3", shade=0.5, rim=0.5, deep="#6c64a8")
    tank += "<path d='M129,262 Q150,270 171,262' fill='none' stroke='#b7b2d6' stroke-width='2.4'/>"
    tank += shaded(ellipse_d(148, 244, 10, 12), "#8fd6cf", shade=0.4, rim=0.5)
    tank += "<path d='M142,238 Q145,234 150,234' fill='none' stroke='#ffffff' stroke-width='1.8' stroke-linecap='round' opacity='0.8'/>"
    tank += "<path d='M140,226 Q150,220 160,226' fill='none' stroke='#4a4f86' stroke-width='4' stroke-linecap='round'/>"
    for cx in (136, 164):
        tank += shaded(ellipse_d(cx, 280, 5.5, 5.5), "#3b3f73", shade=0.4, rim=0.3, sw=0.7)
        tank += "<circle cx='%d' cy='280' r='1.6' fill='#b7b2d6'/>" % cx
    add("weapon_tank", 124, 218, 52, 70, tank, px=PX_KROKER)
    noz = shaded("M-4,-6.5 L10,-11.5 Q13,-11 13,-8 L13,8 Q13,11 10,11.5 L-4,6.5 Z", "#4a4f86", shade=0.45, rim=0.4)
    noz += "<path d='M11.5,-10.5 L11.5,10.5' stroke='#b9f0ea' stroke-width='1.8' stroke-linecap='round'/>"
    add("weapon_nozzle", -7, -14, 23, 28, noz, px=PX_KROKER)

    # Pistola de dedos: puño redondeado, pulgar recto hacia arriba e índice apuntando (origen en el
    # centro del puño, el índice hacia +x). Una versión para Kroker y otra más fina para los iconos.
    # Finger gun: rounded fist, thumb straight up and index finger pointing (origin at the fist's
    # centre, index towards +x). One version for Kroker and a finer one for the icons.
    hand = ("M-3,-6 L-3,-14 Q-3,-17 -0.5,-17 Q2,-17 2,-14 L2,-6 L15.5,-6 Q18.5,-6 18.5,-3 Q18.5,0 15.5,0 "
            "L10,0 L10,6 Q10,13 3,13 L-5,13 Q-10,13 -10,7 L-10,-3 Q-10,-6 -7,-6 Z")
    peach = "#e8bea6"
    fh = shaded(hand, peach, shade=0.38, rim=0.45, sw=1.0,
                extra="<path d='M2,-6 L2,-2' stroke='#c4957f' stroke-width='0.9' opacity='0.55'/>"
                      "<path d='M10,0 Q6,1.5 3,0.5' fill='none' stroke='#c4957f' stroke-width='0.9' opacity='0.55'/>")
    add("weapon_finger", -13, -20, 34, 36, fh, px=PX_KROKER * 1.6, colors=8)
    add("icon_finger", -13, -20, 34, 36, fh, px=1.25, colors=12)

    # Osito de peluche con una costura abierta por la que asoma pelusa (centrado en la mano)
    # Teddy bear with an open seam with fluff poking out (centred on the hand)
    t = "<circle cx='0' cy='30' r='22' fill='#000000' opacity='0.08'/>"
    for x in (-15, 15):
        t += shaded(ellipse_d(x, 26, 8, 8), "#a87a5c", shade=0.3, rim=0.3, sw=0.8)
    t += shaded(ellipse_d(0, 12, 18, 20), "#c99a78", shade=0.4, rim=0.4) + "<path d='%s' fill='#e8c9a8'/>" % ellipse_d(0, 15, 10, 12)
    # Costura y pelusa / Seam and fluff
    t += "<path d='M-4,8 L4,20' stroke='#7a4f33' stroke-width='1.6'/>"
    for (cx, cy, r) in ((1, 13, 4.5), (5, 10, 3.5), (-2, 18, 3.5)):
        t += "<circle cx='%g' cy='%g' r='%g' fill='#fbf5ea'/>" % (cx, cy, r)
    for x in (-17, 17):
        t += shaded(ellipse_d(x, 6, 6.5, 6.5), "#a87a5c", shade=0.3, rim=0.3, sw=0.8)
    for x in (-12, 12):
        t += shaded(ellipse_d(x, -22, 7.5, 7.5), "#c99a78", shade=0.3, rim=0.3, sw=0.8) + "<circle cx='%d' cy='-22' r='3.8' fill='#e8c9a8'/>" % x
    t += shaded(ellipse_d(0, -12, 15, 15), "#c99a78", shade=0.4, rim=0.4)
    t += ("<path d='%s' fill='#e8c9a8'/><circle cx='0' cy='-9' r='2.4' fill='#3a2a30'/>"
          "<circle cx='-6' cy='-15' r='2' fill='#3a2a30'/><circle cx='6' cy='-15' r='2' fill='#3a2a30'/>" % ellipse_d(0, -7, 7, 5))
    t += "<path d='M0,-1 L-8,-5 L-8,3 Z M0,-1 L8,-5 L8,3 Z' fill='#ff5f7a'/>"
    add("weapon_teddy", -26, -32, 52, 66, t, px=PX_KROKER)


# --- Enemigos / Enemies --------------------------------------------------------

def foox():
    body = "M-22,-16 C-22,-26 -10,-29 0,-29 C12,-29 22,-25 22,-16 C22,-9 16,-4 8,-3 C2,-1 -6,-1 -12,-3 C-18,-5 -22,-10 -22,-16 Z"
    i = uid()
    g = ("<defs><linearGradient id='v%s' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#f2f4ff' stop-opacity='0.85'/>"
         "<stop offset='0.7' stop-color='#cdd3f0' stop-opacity='0.55'/><stop offset='1' stop-color='#a9bcff' stop-opacity='0'/></linearGradient></defs>" % i)
    b = g + "<path d='%s' fill='url(#v%s)'/>" % (body, i)
    b += "<path d='M-14,-24 Q0,-30 16,-23' fill='none' stroke='#ffffff' stroke-width='2' opacity='0.6' filter='url(#b1)'/>"
    add("foox_body", -26, -33, 52, 34, b, ghost=True)
    head = ("M8,-30 C8,-36 10,-44 13,-48 C16,-42 18,-38 19,-35 C21,-39 23,-45 26,-48 C28,-42 29,-36 29,-31 "
            "C35,-28 42,-25 45,-22 C40,-18 33,-16 27,-16 C21,-15 15,-16 11,-19 C8,-22 7,-26 8,-30 Z")
    h = shaded(head, "#e8ebf8", shade=0.45, rim=0.55, deep="#7f8ccc", sw=0.9)
    h = h.replace("<path d='%s' fill='url(#g" % head, "<path opacity='0.92' d='%s' fill='url(#g" % head, 1)
    for d in ("M12,-44 C14,-40 15,-37 16,-35 L12,-34 Z", "M25,-44 C24,-40 24,-37 24,-35 L27,-34 Z"):
        h += "<path d='%s' fill='#c7b6e8' opacity='0.7'/>" % d
    h += "<path d='M41,-23 C43,-23 45,-22 45,-21.5 C44,-20.5 42,-20.5 41,-21 Z' fill='#4a4a7a'/>"
    h += "<path d='M14,-20 Q20,-17 27,-18' fill='none' stroke='#ffffff' stroke-width='1.6' opacity='0.5'/>"
    # Cuenca oscura del ojo; el brillo se dibuja en el juego / Dark eye socket; the glow is drawn in game
    h += "<path d='M21,-27.5 Q25,-29 29,-25.5 Q25,-25 21,-27.5 Z' fill='#2c3466' opacity='0.8'/>"
    add("foox_head", 4, -51, 44, 39, h, ghost=True)


def thug():
    """Matón en pixel art de verdad (modo flat): sudadera granate enorme con la capucha tapándole la
    cara (dentro solo brillan los ojos, que se pintan en el juego), bolsillo canguro, cordones,
    vaqueros anchos y zapatillas. Tres tonos por material y contorno de 1 píxel.
    Thug in real pixel art (flat mode): a huge maroon hoodie with the hood hiding his face (only
    the eyes glow inside, painted in game), kangaroo pocket, drawstrings, baggy jeans and
    trainers. Three tones per material and a 1-pixel outline."""
    H0, H1, H2, H3 = "#3b1422", "#62213a", "#8c3046", "#b04c5e"
    HOLE = "#120a16"
    STR, TIP = "#ece4ea", "#9a90a8"
    SK, SK1 = "#f0c8a8", "#c9957e"
    J1, J2, J3 = "#283153", "#3a4670", "#526094"
    SH, SH2, WH, WH1 = "#2a2838", "#45435a", "#ece8f2", "#b9b4c8"

    # --- Capucha / Hood ---
    hood = "M-30,-100 C-37,-122 -31,-150 -6,-158 C14,-163 33,-148 35,-126 C37,-112 33,-102 28,-97 C10,-93 -12,-93 -30,-100 Z"
    h = flat(hood, H2)
    h += flat("M14,-153 C31,-146 37,-128 34,-110 L28,-98 L20,-103 C25,-120 22,-137 11,-144 Z", H1)
    h += flat("M-27,-128 C-27,-146 -15,-155 -3,-157 L-2,-152 C-13,-150 -21,-141 -22,-127 Z", H3)
    h += flat("M-19,-107 C-23,-124 -15,-141 2,-141 C19,-141 25,-124 21,-107 C11,-101 -9,-101 -19,-107 Z", HOLE)
    h += "<path d='M-19,-107 C-23,-124 -15,-141 2,-141 C19,-141 25,-124 21,-107' fill='none' stroke='%s' stroke-width='3'/>" % H3
    h += "<path d='M21,-107 C25,-124 19,-138 8,-141' fill='none' stroke='%s' stroke-width='3'/>" % H1
    add("thug_head", -40, -166, 80, 72, h, flat=True)

    # --- Sudadera / Hoodie ---
    torso = "M-30,-104 C-14,-110 14,-110 30,-104 C40,-100 44,-92 44,-84 L42,-48 L-42,-48 L-44,-84 C-44,-92 -40,-100 -30,-104 Z"
    b = flat(torso, H2)
    b += flat("M30,-104 C40,-100 44,-92 44,-84 L42,-48 L30,-48 C32,-70 32,-90 25,-104 Z", H1)
    b += flat("M-28,-102 C-20,-106 -8,-108 2,-108 L2,-104 C-8,-104 -18,-102 -25,-97 Z", H3)
    b += flat("M-14,-106 C-6,-102 8,-102 16,-106 L14,-100 C6,-97 -6,-97 -12,-100 Z", H0)
    # Bolsillo canguro / Kangaroo pocket
    b += flat("M-22,-76 L22,-76 L26,-56 L-26,-56 Z", H1)
    b += "<path d='M-22,-76 L22,-76' stroke='%s' stroke-width='2.4'/>" % H0
    b += "<path d='M-22,-76 C-27,-68 -27,-62 -26,-56 M22,-76 C27,-68 27,-62 26,-56' fill='none' stroke='%s' stroke-width='2.4'/>" % H0
    b += "<path d='M-20,-74 L-6,-74' stroke='%s' stroke-width='2.2'/>" % H3
    # Cintura de canalé / Ribbed waistband
    b += flat("M-42,-56 L42,-56 L42,-46 L-42,-46 Z", H1)
    b += "".join("<path d='M%d,-55 L%d,-47' stroke='%s' stroke-width='2.2'/>" % (x, x, H0) for x in range(-36, 40, 8))
    # Cordones / Drawstrings
    b += "<path d='M-6,-104 L-8,-84 M7,-104 L9,-82' stroke='%s' stroke-width='2.6' stroke-linecap='round'/>" % STR
    b += flat("M-10.5,-86 L-5.5,-86 L-5.5,-79 L-10.5,-79 Z", TIP) + flat("M6.5,-84 L11.5,-84 L11.5,-77 L6.5,-77 Z", TIP)
    # Mangas que caen a los lados / Sleeves hanging at the sides
    b += flat("M-44,-97 C-53,-90 -55,-74 -53,-60 L-35,-58 C-35,-72 -36,-87 -33,-99 Z", H2)
    b += flat("M-41,-94 C-48,-86 -50,-74 -49,-62 L-45,-62 C-46,-74 -44,-86 -38,-94 Z", H3)
    b += flat("M44,-97 C53,-90 55,-74 53,-60 L35,-58 C35,-72 36,-87 33,-99 Z", H1)
    b += flat("M-54,-63 L-34,-61 L-34,-53 L-54,-55 Z", H1) + flat("M54,-63 L34,-61 L34,-53 L54,-55 Z", H0)
    b += "".join("<path d='M%d,-62 L%d,-54' stroke='%s' stroke-width='2'/>" % (x, x, H0) for x in (-48, -42))
    # Costura que separa mangas y cuerpo / Seam separating sleeves and body
    b += "<path d='M-33,-99 C-36,-87 -35,-72 -35,-60' fill='none' stroke='%s' stroke-width='2.6'/>" % H0
    b += "<path d='M33,-99 C36,-87 35,-72 35,-60' fill='none' stroke='%s' stroke-width='2.6'/>" % H0
    add("thug_body", -58, -112, 116, 72, b, flat=True)

    # --- Puño / Fist ---
    f = flat("M-10,0 C-10,-8 -5,-11 0,-11 C6,-11 10,-8 10,0 C10,7 6,10 0,10 C-6,10 -10,7 -10,0 Z", SK)
    f += flat("M10,0 C10,7 6,10 0,10 C-4,10 -7,8 -8,6 C-2,7 4,5 6,-2 C7,-5 8,-7 8,-8 C9,-6 10,-3 10,0 Z", SK1)
    f += "".join("<path d='M%d,-10 L%d,-4' stroke='%s' stroke-width='1.8'/>" % (x, x - 1, SK1) for x in (-3, 3))
    add("thug_fist", -13, -14, 26, 27, f, flat=True)

    # --- Pierna con vaquero ancho y zapatilla (la punta mira hacia delante) ---
    # --- Leg with baggy jeans and a trainer (toe points forward) ---
    l = flat("M-12,-50 L12,-50 L13,-15 L-13,-15 Z", J2)
    l += flat("M3,-50 L12,-50 L13,-15 L5,-15 Z", J1)
    l += flat("M-11,-48 L-7,-48 L-8,-18 L-12,-18 Z", J3)
    l += flat("M-14,-20 L14,-20 L14,-13 L-14,-13 Z", J1)
    l += flat("M-14,-13 C-14,-20 -4,-21 2,-19 L10,-18 C18,-17 22,-12 22,-7 L22,-3 L-14,-3 Z", SH)
    l += flat("M-12,-14 C-11,-18 -5,-19 0,-18 L0,-15 C-5,-16 -9,-15 -10,-13 Z", SH2)
    l += flat("M12,-16 C19,-15 22,-11 22,-7 L12,-7 C10,-10 10,-13 12,-16 Z", WH)
    l += flat("M-15,-6 L23,-6 L23,0 L-15,0 Z", WH) + flat("M-15,-2 L23,-2 L23,0 L-15,0 Z", WH1)
    l += "<path d='M-4,-17 L3,-15 M-2,-13 L5,-11' stroke='%s' stroke-width='2'/>" % WH
    add("thug_leg", -18, -53, 44, 56, l, flat=True)


def sling():
    jacket, jdark, cap, skin = "#4f5f8f", "#38456d", "#a34d5f", "#b9a3c9"
    body = shaded("M-18,-82 Q0,-86 18,-82 L22,-40 Q0,-37 -22,-40 Z", jacket, shade=0.5, rim=0.4,
                  extra=fold("M-10,-70 Q-12,-56 -8,-44", jacket, 2.4, 0.35))
    body += "<path d='M0,-82 L0,-41' stroke='%s' stroke-width='2'/>" % jdark
    body += "<path d='M-18,-82 L-10,-76 L0,-82 L10,-76 L18,-82' fill='none' stroke='%s' stroke-width='1.6' opacity='0.8'/>" % light(jacket, 0.25)
    add("sling_body", -25, -88, 50, 52, body)
    head = shaded(ellipse_d(0, -98, 15, 16), mix(skin, "#3a2a50", 0.4), shade=0.55, rim=0.3, sw=0.9)
    head += shaded("M-16,-104 Q-15,-116 0,-116 Q15,-116 16,-104 Q0,-108 -16,-104 Z", cap, shade=0.45, rim=0.4, sw=0.9)
    head += shaded("M-16,-106 L-29,-102 Q-24,-99 -16,-101 Z", dark(cap, 0.3), shade=0.3, rim=0.2, sw=0.7)
    head += "<circle cx='0' cy='-116' r='1.8' fill='%s'/>" % light(cap, 0.3)
    add("sling_head", -31, -119, 49, 38, head)
    leg = shaded("M-6,-40 L6,-40 L5,-6 Q0,-4 -5,-6 Z", jdark, shade=0.5, rim=0.3, sw=0.8)
    add("sling_leg", -8, -42, 16, 40, leg)


def skeleton():
    bone, shade_c = "#e8e2d4", "#b9b0a0"
    skull = shaded("M-13,-98 C-13,-108 -6,-113 2,-113 C11,-113 17,-107 17,-98 C17,-92 14,-89 11,-88 L11,-81 L-6,-81 L-6,-88 C-10,-90 -13,-93 -13,-98 Z",
                   bone, shade=0.5, rim=0.45, deep="#6f6658")
    for x in (-3, 8):
        skull += "<path d='%s' fill='#1a1328'/>" % ellipse_d(x, -98, 4.6, 4.8)
    skull += "<path d='M2,-93 L4,-89 L0,-89 Z' fill='#3a3040'/>"
    for k in range(4):
        skull += "<path d='M%.1f,-87 L%.1f,-81.5' stroke='#3a3040' stroke-width='1.1'/>" % (-3 + k * 4.5, -3 + k * 4.5)
    skull += "<path d='M-8,-107 Q-2,-111 6,-110' fill='none' stroke='#ffffff' stroke-width='1.8' opacity='0.6' stroke-linecap='round'/>"
    add("skel_skull", -16, -116, 36, 38, skull)
    ribs = "<path d='M0,-84 L0,-44' stroke='%s' stroke-width='4.5' stroke-linecap='round'/>" % shade_c
    for k in range(4):
        y = -78 + k * 8
        r = 13 - k * 1.5
        for sgn in (-1, 1):
            ribs += ("<path d='M0,%.1f Q%.1f,%.1f %.1f,%.1f' fill='none' stroke='%s' stroke-width='3.4' stroke-linecap='round'/>"
                     % (y - 2, sgn * r * 1.1, y - 4, sgn * r * 0.9, y + 5, bone))
            ribs += ("<path d='M0,%.1f Q%.1f,%.1f %.1f,%.1f' fill='none' stroke='#ffffff' stroke-width='1' stroke-linecap='round' opacity='0.5'/>"
                     % (y - 2.6, sgn * r * 1.0, y - 4.6, sgn * r * 0.7, y + 2))
    for k in range(5):
        ribs += "<path d='M-2,%d L2,%d' stroke='%s' stroke-width='1' opacity='0.7'/>" % (-50 - k * 7, -50 - k * 7, "#7d7464")
    add("skel_ribs", -17, -87, 34, 46, ribs)
    pelvis = shaded("M-12,-46 Q0,-49 12,-46 L8,-38 Q0,-35 -8,-38 Z", bone, shade=0.5, rim=0.4, deep="#6f6658", sw=0.8)
    pelvis += "<circle cx='-5' cy='-42' r='1.6' fill='#5a5060'/><circle cx='5' cy='-42' r='1.6' fill='#5a5060'/>"
    add("skel_pelvis", -14, -50, 28, 17, pelvis)
    # Hueso de 20 de largo, de (0,0) a (20,0) / A 20-long bone, from (0,0) to (20,0)
    bn = shaded("M1,-2.6 C-2,-4.6 -3.4,-1 -1.6,0 C-3.4,1 -2,4.6 1,2.6 L19,2.6 C22,4.6 23.4,1 21.6,0 C23.4,-1 22,-4.6 19,-2.6 Z",
                bone, shade=0.45, rim=0.4, deep="#6f6658", sw=0.7)
    add("skel_bone", -4, -5, 28, 10, bn)
    pile = ""
    for k in range(6):
        ang = k * 1.1
        cx, cy = math.cos(ang) * 14, -4 + math.sin(ang) * 4
        a = math.degrees(ang * 2)
        pile += "<g transform='translate(%.1f,%.1f) rotate(%.1f) translate(-10,0)'>%s</g>" % (cx, cy, a, bn)
    pile += shaded(ellipse_d(4, -12, 11, 10), bone, shade=0.5, rim=0.4, deep="#6f6658")
    pile += "<circle cx='1' cy='-12' r='3' fill='#1a1328'/><circle cx='8' cy='-12' r='3' fill='#1a1328'/>"
    add("skel_pile", -28, -26, 56, 34, pile)


# --- Jefe: muebles / Boss: furniture ----------------------------------------------

def boss():
    # Cama (coordenadas con la base en y = 0) / Bed (coordinates with the base at y = 0)
    w, h = 140, 150
    bed = shaded("M-76,-176 Q-76,-184 -68,-184 L68,-184 Q76,-184 76,-176 L76,-140 L-76,-140 Z", "#aab4ea", shade=0.45, rim=0.5)
    for x in (-72, 72):
        bed += shaded(ellipse_d(x, -178, 8, 8), "#cfd6f6", shade=0.35, rim=0.5, sw=0.8)
    bed += shaded("M-70,-150 L70,-150 L70,0 L-70,0 Z", "#e6e2f6", shade=0.4, rim=0.4)
    bed += shaded("M-52,-142 Q0,-148 52,-142 Q56,-125 52,-108 Q0,-102 -52,-108 Q-56,-125 -52,-142 Z", "#f8f6ff", shade=0.35, rim=0.4, sw=0.8)
    quilt = "M-74,-94 Q0,-100 74,-94 L74,0 L-74,0 Z"
    stars = "".join("<path d='%s' fill='#f6d993' opacity='0.85'/>" % star_d(-46 + c * 46 + r * 20, -60 + r * 34, 5.5)
                    for r in range(2) for c in range(3))
    bed += shaded(quilt, "#5b67c4", shade=0.5, rim=0.4, extra=stars + fold("M-40,-80 Q-30,-40 -38,-10", "#5b67c4", 3, 0.4) + fold("M30,-84 Q38,-50 30,-14", "#5b67c4", 3, 0.4))
    bed += shaded("M-74,-94 Q0,-100 74,-94 L74,-80 Q0,-86 -74,-80 Z", "#eeeaf8", shade=0.3, rim=0.3, sw=0.8)
    add("boss_bed", -80, -188, 160, 190, bed, colors=20)

    # Estantería / Bookshelf
    w, h = 120, 170
    sh = shaded("M-60,-170 L60,-170 L60,0 L-60,0 Z", "#4a4592", shade=0.55, rim=0.4, sw=1.4)
    cols = ["#e3a6c4", "#f6d993", "#8fb3e8", "#b6e0d6", "#c9b6f0"]
    for row in range(3):
        y = -170 + 54 * (row + 1)
        x = -52.0
        i = row * 2
        while x < 46:
            bw = 10 + (i % 3) * 3
            bh = 30 + (i % 4) * 5
            sh += shaded("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, y - bh, x + bw, y - bh, x + bw, y, x, y), cols[i % len(cols)], shade=0.35, rim=0.35, sw=0.8)
            sh += "<rect x='%g' y='%g' width='%g' height='2' fill='#ffffff' opacity='0.35'/>" % (x + 2, y - bh + 6, bw - 4)
            x += bw + 3
            i += 1
        sh += shaded("M-60,%g L60,%g L60,%g L-60,%g Z" % (y, y, y + 6, y + 6), "#2c2a66", shade=0.2, rim=0.2, sw=0.6)
    add("boss_shelf", -63, -173, 126, 176, sh, colors=32)

    # Baúl de juguetes: caja y tapa / Toy chest: box and lid
    box = shaded("M-60,-66 L60,-66 L60,0 L-60,0 Z", "#c0a0dc", shade=0.45, rim=0.45, sw=1.2)
    box += shaded("M-60,-18 L60,-18 L60,0 L-60,0 Z", "#9e7fbf", shade=0.3, rim=0.2, sw=0.8)
    box += "<path d='%s' fill='#f6d993' stroke='#c9a24e' stroke-width='1'/>" % star_d(0, -30, 11)
    for x in (-44, 44):
        box += shaded("M%g,-66 L%g,-66 L%g,0 L%g,0 Z" % (x - 4, x + 4, x + 4, x - 4), "#8f6aae", shade=0.3, rim=0.3, sw=0.6)
    add("boss_chest_box", -63, -69, 126, 72, box)
    lid = shaded("M-63,-16 Q0,-22 63,-16 L63,2 L-63,2 Z", "#a87fbf", shade=0.4, rim=0.5, sw=1.1)
    lid += "<path d='M-60,-6 Q0,-11 60,-6' fill='none' stroke='#d7bdea' stroke-width='1.6' opacity='0.7'/>"
    add("boss_chest_lid", -66, -24, 132, 28, lid)


# --- Proyectiles / Projectiles --------------------------------------------------------

def shots():
    bk = shaded("M-16,-11 L16,-11 L16,11 L-16,11 Z", "#6a4fa8", shade=0.4, rim=0.4)
    bk += shaded("M-13,-8 L13,-8 L13,8 L-13,8 Z", "#f1e6c8", shade=0.25, rim=0.2, sw=0.6)
    bk += "<path d='M0,-11 L0,11' stroke='#6a4fa8' stroke-width='3'/>"
    add("shot_book", -19, -14, 38, 28, bk)
    st = shaded(ellipse_d(0, 0, 10, 9), "#8f86b0", shade=0.5, rim=0.5)
    st += "<circle cx='-3' cy='-3' r='3' fill='#cfc6e8' opacity='0.8'/>"
    add("shot_stone", -12, -12, 24, 24, st)


# --- Personajes del plano astral / Astral plane characters ----------------------------

def npc_face(eye_y, ink, mood):
    """Cara pintada píxel a píxel / Face painted pixel by pixel."""
    def paint(img, to_px):
        pix = img.load()
        w, h = img.size

        def put(x, y, c):
            x, y = int(round(x - 0.5)), int(round(y - 0.5))
            if 0 <= x < w and 0 <= y < h:
                pix[x, y] = c
        ink_c = rgb(ink) + (255,)
        for cx in (91, 109):
            ex, ey = to_px(cx, eye_y)
            put(ex, ey, ink_c)
            put(ex, ey + 1, ink_c)
            put(ex + 1, ey, ink_c)
            put(ex + 1, ey + 1, ink_c)
            put(ex, ey, (255, 255, 255, 255))
        # Cejas / Eyebrows
        for cx, sgn in ((91, -1), (109, 1)):
            bx, by = to_px(cx, eye_y - 9)
            tilt = 1 if mood == 2 else 0
            put(bx - 1, by + (tilt if sgn < 0 else 0), ink_c)
            put(bx, by, ink_c)
            put(bx + 1, by + (tilt if sgn > 0 else 0), ink_c)
            put(bx + 2 * (1 if sgn > 0 else -1) * 0 + (2 if sgn > 0 else -2), by + tilt, ink_c)
        mx, my = to_px(100, eye_y + 14)
        if mood == 1:
            for dx in (-1, 0, 1):
                put(mx + dx, my, (125, 74, 94, 255))
            put(mx, my + 1, (125, 74, 94, 255))
        elif mood == 2:
            put(mx - 1, my, (138, 86, 98, 255))
            put(mx, my, (138, 86, 98, 255))
            put(mx + 1, my - 1, (138, 86, 98, 255))
        else:
            put(mx - 1, my - 1, (163, 104, 122, 255))
            put(mx, my, (163, 104, 122, 255))
            put(mx + 1, my - 1, (163, 104, 122, 255))
    return paint


def npcs():
    # Svinho: futbolista / footballer
    skin, shade_c = "#b97c56", "#8f5c45"
    b = ""
    for x in (82, 104):
        b += shaded("M%g,196 L%g,196 L%g,236 L%g,236 Z" % (x, x + 16, x + 16, x), skin, shade=0.4, rim=0.3)
        b += shaded("M%g,232 L%g,232 L%g,276 L%g,276 Z" % (x - 1, x + 17, x + 17, x - 1), "#f4f1ea", shade=0.35, rim=0.3,
                    extra="<rect x='%g' y='240' width='18' height='4' fill='#2f9e5b'/>" % (x - 1))
        b += shaded(ellipse_d(x + 9, 282, 13, 6), "#1e1f2e", shade=0.3, rim=0.4)
    b += shaded("M74,168 L126,168 L128,204 L102,204 L100,190 L98,204 L72,204 Z", "#2b4fa8", shade=0.45, rim=0.4)
    b += shaded("M62,104 L76,108 L72,168 L58,166 Z", skin, shade=0.4, rim=0.4)
    b += shaded("M138,104 L124,108 L128,168 L142,166 Z", shade_c, shade=0.4, rim=0.2)
    b += shaded(ellipse_d(65, 172, 7, 8), skin, shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(135, 172, 7, 8), shade_c, shade=0.3, rim=0.2, sw=0.8)
    shirt = "M82,96 L118,96 L140,106 L136,130 L128,128 L128,172 L72,172 L72,128 L64,130 L60,106 Z"
    b += shaded(shirt, "#f6d24a", shade=0.5, rim=0.4, extra="<text x='87' y='155' font-family='Arial Black,Arial' font-weight='900' font-size='26' fill='#2f9e5b'>10</text>")
    b += "<path d='M88,97 L100,110 L112,97' fill='none' stroke='#2f9e5b' stroke-width='4' stroke-linejoin='round'/>"
    b += shaded("M93,82 L107,82 L107,98 L93,98 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 60, 22, 26), skin, shade=0.45, rim=0.4)
    for px_, py_ in ((82, 44), (92, 36), (104, 34), (116, 40), (122, 52), (78, 56), (98, 40), (110, 44)):
        b += shaded(ellipse_d(px_, py_, 9, 9), "#1d1620", shade=0.4, rim=0.45, rim_color="#8a7aa8", sw=0.8)
    add("npc_svinho", 50, 22, 100, 270, b, px=PX_NPC, colors=32, post=npc_face(62, "#2a1d22", 1))
    ball = shaded(ellipse_d(0, 0, 13, 13), "#f7f3ea", shade=0.45, rim=0.4)
    ball += "<path d='M0,-5 L4.8,-1.5 L3,4 L-3,4 L-4.8,-1.5 Z' fill='#1e1f2e'/>"
    add("npc_ball", -15, -15, 30, 30, ball, px=PX_NPC)

    # Stolk: el matón / the bully
    skin, shade_c = "#f0c4aa", "#c99a8e"
    b = ""
    for x in (74, 104):
        b += shaded("M%g,186 L%g,186 L%g,276 L%g,276 Z" % (x, x + 24, x + 24, x), "#3b4a7a" if x == 74 else "#2f3c66", shade=0.45, rim=0.3)
        b += shaded(ellipse_d(x + 12, 282, 17, 7), "#e9e6f2", shade=0.35, rim=0.3)
    b += shaded("M78,94 L122,94 L150,108 L146,190 L54,190 L50,108 Z", "#b9474f", shade=0.55, rim=0.4,
                extra="<rect x='54' y='178' width='92' height='12' fill='#8f343c'/>")
    b += "<path d='%s' fill='#8f343c'/>" % ellipse_d(100, 96, 30, 10)
    b += shaded("M52,112 L70,110 L130,140 L128,156 L60,140 Z", "#c4545c", shade=0.4, rim=0.4)
    b += shaded("M148,112 L130,110 L70,146 L74,160 L142,140 Z", "#a83e46", shade=0.4, rim=0.3)
    b += shaded(ellipse_d(130, 148, 9, 9), skin, shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(70, 152, 9, 9), shade_c, shade=0.3, rim=0.2, sw=0.8)
    b += shaded("M90,80 L110,80 L110,96 L90,96 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 58, 25, 27), skin, shade=0.45, rim=0.4)
    b += shaded("M76,52 L80,38 L94,30 L108,30 L120,38 L124,52 L116,44 L84,44 Z", "#8a6a52", shade=0.4, rim=0.4, sw=0.8)
    b += "<g transform='translate(114,72) rotate(-23)'><rect x='-8' y='-3' width='16' height='6' rx='2' fill='#f2d4a6'/></g>"
    add("npc_stolk", 46, 26, 108, 266, b, px=PX_NPC, colors=32, post=npc_face(58, "#3a2a30", 2))

    # Silly: la hacker / the hacker
    skin, shade_c = "#f4d2c0", "#caa8b4"
    b = ""
    for x in (82, 102):
        b += shaded("M%g,186 L%g,186 L%g,276 L%g,276 Z" % (x, x + 16, x + 16, x), "#272a48", shade=0.4, rim=0.3)
        b += shaded(ellipse_d(x + 8, 282, 12, 6), "#5ff2ff", shade=0.35, rim=0.3)
    b += shaded("M80,96 L120,96 L144,110 L142,196 L58,196 L56,110 Z", "#2b2f5a", shade=0.55, rim=0.4)
    b += shaded("M66,150 L134,150 L128,168 L72,168 Z", "#3c4170", shade=0.3, rim=0.3, sw=0.8)
    b += shaded("M70,120 L130,120 L134,150 L66,150 Z", "#1a1d38", shade=0.3, rim=0.3, sw=0.8)
    b += shaded(ellipse_d(82, 160, 7, 7), skin, shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(118, 160, 7, 7), shade_c, shade=0.3, rim=0.2, sw=0.8)
    b += shaded("M93,82 L107,82 L107,98 L93,98 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 62, 22, 26), skin, shade=0.45, rim=0.4)
    b += shaded("M74,80 L74,50 Q78,38 84,36 Q92,31 100,31 Q108,31 116,36 Q122,38 126,50 L126,80 L118,80 L118,56 L110,54 L100,58 L90,54 L82,58 L82,80 Z",
                "#8a5bd6", shade=0.45, rim=0.5, rim_color="#e3d3ff")
    b += "<path d='M82,96 A18,18 0 0 0 118,96' fill='none' stroke='#5ff2ff' stroke-width='4'/>"
    b += shaded(ellipse_d(82, 98, 7, 7), "#3c4170", shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(118, 98, 7, 7), "#3c4170", shade=0.3, rim=0.3, sw=0.8)
    add("npc_silly", 50, 26, 100, 266, b, px=PX_NPC, colors=32, post=npc_face(62, "#2a2238", 3))

    # Doc: el doctor / the doctor
    skin, shade_c, coat, coat_s = "#e8c4a8", "#c2a092", "#f2f0f8", "#cfcbe2"
    b = ""
    for x in (80, 104):
        b += shaded("M%g,196 L%g,196 L%g,276 L%g,276 Z" % (x, x + 18, x + 18, x), "#4a4f7a", shade=0.4, rim=0.3)
        b += shaded(ellipse_d(x + 9, 282, 14, 6), "#2a2238", shade=0.3, rim=0.4)
    b += shaded("M80,94 L120,94 L142,106 L146,236 L54,236 L58,106 Z", coat, shade=0.5, rim=0.3, deep="#8a84b8")
    b += shaded("M88,96 L112,96 L106,200 L94,200 Z", "#9fc1e8", shade=0.3, rim=0.2, sw=0.8)
    b += shaded("M97,100 L103,100 L105,150 L100,158 L95,150 Z", "#c95f6f", shade=0.3, rim=0.3, sw=0.7)
    b += "<rect x='118' y='128' width='16' height='14' fill='none' stroke='%s' stroke-width='1.5'/>" % coat_s
    b += "<path d='M122,128 L122,118 M127,128 L127,120' stroke-width='2.5'/><path d='M122,128 L122,118' stroke='#5b67c4' stroke-width='2.5'/><path d='M127,128 L127,120' stroke='#c95f6f' stroke-width='2.5'/>"
    b += shaded("M58,106 L72,110 L74,176 L60,176 Z", coat, shade=0.4, rim=0.3, deep="#8a84b8")
    b += shaded("M142,106 L128,110 L126,176 L140,176 Z", coat_s, shade=0.4, rim=0.2, deep="#8a84b8")
    b += shaded("M52,150 L86,150 L86,194 L52,194 Z", "#b98a5a", shade=0.35, rim=0.3)
    b += shaded("M56,156 L82,156 L82,190 L56,190 Z", "#f7f3ea", shade=0.2, rim=0.1, sw=0.6)
    for y in (162, 170, 178):
        b += "<path d='M59,%d L78,%d' stroke='#5a5a82' stroke-width='1' opacity='0.5'/>" % (y, y)
    b += "<rect x='62' y='147' width='14' height='5' fill='#8f8fb8'/>"
    b += shaded(ellipse_d(67, 182, 7, 7), skin, shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(133, 180, 7, 7), shade_c, shade=0.3, rim=0.2, sw=0.8)
    b += "<path d='M86,110 A16,16 0 0 0 114,110' fill='none' stroke='#3c4170' stroke-width='3'/><path d='M114,110 L118,150' stroke='#3c4170' stroke-width='3'/>"
    b += shaded(ellipse_d(118, 154, 6, 6), "#8f8fb8", shade=0.3, rim=0.4, sw=0.7)
    b += shaded("M93,82 L107,82 L107,98 L93,98 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 60, 23, 27), skin, shade=0.45, rim=0.45)
    b += shaded(ellipse_d(78, 62, 5, 12), "#c9c6d6", shade=0.3, rim=0.3, sw=0.7) + shaded(ellipse_d(122, 62, 5, 12), "#c9c6d6", shade=0.3, rim=0.2, sw=0.7)
    b += shaded("M90,72 L100,69 L110,72 L106,76 L100,74 L94,76 Z", "#c9c6d6", shade=0.2, rim=0.3, sw=0.6)
    b += "<path d='M80,44 L120,44' stroke='#3c4170' stroke-width='2.5'/>"
    b += shaded(ellipse_d(100, 40, 8, 8), "#dfe6ff", shade=0.3, rim=0.5, sw=0.8)
    add("npc_doc", 48, 28, 104, 264, b, px=PX_NPC, colors=32, post=npc_face(62, "#2a2238", 1))


# --- Habitación de Kroker / Kroker's bedroom -------------------------------------------
# Coordenadas del lienzo de la habitación (1920 x 1080) / Room canvas coordinates (1920 x 1080)

def rect_d(x, y, w, h):
    return "M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, y, x + w, y, x + w, y + h, x, y + h)


def room_add(name, x, y, w, h, body, colors=24):
    add(name, x, y, w, h, body, px=PX_ROOM, colors=colors)


def room():
    WB = 300
    # Pared: un sprite por nivel de rareza / Wall: one sprite per strangeness level
    for wl in range(4):
        k = min(1.0, wl / 3.0)
        top, bot = mix("#1d2463", "#3a1d63", k), mix("#2c3681", "#1f6a7a", k)
        i = uid()
        b = ("<defs><linearGradient id='w%s' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='%s'/>"
             "<stop offset='1' stop-color='%s'/></linearGradient></defs><rect x='0' y='0' width='1920' height='%d' fill='url(#w%s)'/>" % (i, top, bot, WB, i))
        for x in range(0, 1920, 48):
            b += "<rect x='%d' y='0' width='18' height='%d' fill='#ffffff' opacity='0.035'/>" % (x, WB)
        b += shaded(rect_d(0, WB - 14, 1920, 18), "#cfc8ec", shade=0.3, rim=0.5, sw=1.2)
        room_add("room_wall_%d" % wl, 0, 0, 1920, WB + 4, b, colors=12)
    # Suelo de tablas / Floorboards
    i = uid()
    b = ("<defs><linearGradient id='f%s' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#3e3a7c'/>"
         "<stop offset='1' stop-color='#2f2c66'/></linearGradient></defs><rect x='0' y='%d' width='1920' height='740' fill='url(#f%s)'/>" % (i, WB, i))
    y, row = WB + 4, 0
    while y < 1000:
        b += "<rect x='0' y='%d' width='1920' height='3' fill='#1c1846' opacity='0.55'/>" % y
        b += "<rect x='0' y='%d' width='1920' height='2' fill='#5a54a8' opacity='0.25'/>" % (y + 3)
        x = -120 + (row % 3) * 140
        while x < 1920:
            b += "<rect x='%d' y='%d' width='3' height='46' fill='#1c1846' opacity='0.45'/>" % (x, y)
            for nx in (60, 300):
                b += "<circle cx='%d' cy='%d' r='2.4' fill='#24205a' opacity='0.6'/>" % (x + nx, y + 23)
            x += 420
        # Vetas / Grain
        for gx in range(row * 37 % 200, 1920, 240):
            b += "<path d='M%d,%d Q%d,%d %d,%d' fill='none' stroke='#4a4590' stroke-width='2' opacity='0.35'/>" % (gx, y + 16, gx + 50, y + 12, gx + 110, y + 18)
        y += 46
        row += 1
    room_add("room_floor", 0, WB, 1920, 742, b, colors=12)

    # Ventana: marco, alféizar, cortinas y barra / Window: frame, sill, curtains and rod
    wx, wy, ww, wh = 800, 46, 320, 214
    fr = "#ece6f6"
    b = "<path d='%s %s' fill-rule='evenodd' fill='%s'/>" % (rect_d(wx - 5, wy - 5, ww + 10, wh + 10), rect_d(wx + 5, wy + 5, ww - 10, wh - 10), fr)
    b += "<rect x='%g' y='%g' width='6' height='%g' fill='%s'/>" % (wx + ww / 2 - 3, wy, wh, fr)
    b += "<rect x='%g' y='%g' width='%g' height='6' fill='%s'/>" % (wx, wy + wh / 2 - 3, ww, fr)
    b += "<rect x='%g' y='%g' width='%g' height='3' fill='#b9b0dc'/>" % (wx + 5, wy + wh - 8, ww - 10)
    b += shaded(rect_d(wx - 22, wy + wh + 2, ww + 44, 14), "#f4f0fb", shade=0.3, rim=0.4, sw=1)
    room_add("room_window_frame", wx - 26, wy - 8, ww + 52, wh + 30, b, colors=8)
    for side, x0 in (("l", wx - 70), ("r", wx + ww + 6)):
        cur = "M%g,20 L%g,20 Q%g,150 %g,270 Q%g,276 %g,278 Q%g,150 %g,20 Z" % (x0, x0 + 64, x0 + 66, x0 + 64, x0 + 32, x0, x0 - 2, x0)
        folds = "".join(fold("M%g,26 Q%g,150 %g,272" % (x0 + 14 + k * 18, x0 + 18 + k * 18, x0 + 14 + k * 18), "#8a82d6", 3.5, 0.45) for k in range(3))
        b = shaded(cur, "#8a82d6", shade=0.45, rim=0.45, extra=folds)
        room_add("room_curtain_" + side, x0 - 6, 14, 78, 270, b)
    room_add("room_curtain_rod", wx - 94, 10, ww + 188, 16, shaded(rect_d(wx - 90, 14, ww + 180, 8), "#cfc8ec", shade=0.3, rim=0.5, sw=1), colors=6)

    # Estantería / Bookshelf
    r = (1236, 70, 170, 226)
    b = shaded(rect_d(*r), "#4a4592", shade=0.5, rim=0.35, sw=2)
    cols = ["#e3a6c4", "#f6d993", "#8fb3e8", "#b6e0d6", "#c9b6f0"]
    for row in range(3):
        y = r[1] + 70 * (row + 1)
        x, k = r[0] + 10, row * 2
        while x < r[0] + r[2] - 20:
            bw, bh = 12 + (k % 3) * 4, 40 + (k % 4) * 6
            b += shaded(rect_d(x, y - bh, bw, bh), cols[k % len(cols)], shade=0.35, rim=0.35, sw=1)
            b += "<rect x='%g' y='%g' width='%g' height='3' fill='#ffffff' opacity='0.35'/>" % (x + 2, y - bh + 8, bw - 4)
            x += bw + 3
            k += 1
        b += shaded(rect_d(r[0], y, r[2], 6), "#2c2a66", shade=0.2, rim=0.2, sw=0.6)
    room_add("room_shelf", r[0] - 4, r[1] - 4, r[2] + 8, r[3] + 8, b)

    # Escritorio / Desk
    dx, dy, dw, dh = 1470, 226, 300, 104
    b = ""
    for lx in (dx + 10, dx + dw - 24):
        b += shaded(rect_d(lx, dy + dh, 14, 40), "#3a346f", shade=0.3, rim=0.3, sw=1)
    b += shaded(rect_d(dx, dy, dw, dh), "#8a7fc4", shade=0.4, rim=0.4, sw=1.4)
    b += shaded(rect_d(dx, dy + dh - 18, dw, 18), "#6e64ad", shade=0.3, rim=0.2, sw=1)
    b += "<g transform='translate(%g,%g) rotate(4.6)'>%s<path d='M-19,-5 A13,13 0 1 0 -2,12' fill='none' stroke='#5b67c4' stroke-width='3'/></g>" % (
        dx + 130, dy + 46, shaded(rect_d(-36, -24, 72, 48), "#f7f3ea", shade=0.2, rim=0.2, sw=1))
    for k, cc in enumerate(("#e85d75", "#f6c86a", "#5b67c4", "#62a9a1")):
        cx, cy = dx + 180 + k * 8, dy + 34 + k * 6
        b += "<path d='M%g,%g L%g,%g' stroke='%s' stroke-width='4.5' stroke-linecap='round'/>" % (cx, cy, cx + 22, cy - 6, cc)
    base_x, base_y = dx + dw - 46, dy + 58
    b += shaded(ellipse_d(base_x, base_y, 18, 8), "#3a346f", shade=0.3, rim=0.3, sw=0.8)
    b += "<path d='M%g,%g L%g,%g L%g,%g' fill='none' stroke='#3a346f' stroke-width='4.5' stroke-linejoin='round'/>" % (base_x, base_y, base_x - 10, base_y - 40, base_x - 34, base_y - 30)
    b += shaded("M%g,%g L%g,%g L%g,%g Z" % (base_x - 26, base_y - 42, base_x - 48, base_y - 20, base_x - 28, base_y - 14), "#e3a6c4", shade=0.3, rim=0.4, sw=0.8)
    gx, gy = dx + 230, dy + 30
    b += shaded(ellipse_d(gx, gy, 18, 18), "#7fb0e0", shade=0.4, rim=0.4, sw=1,
                extra="<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#9fd29a'/>" % (gx - 8, gy - 10, gx + 4, gy - 12, gx + 6, gy + 2, gx - 6, gy + 6))
    b += "<path d='M%g,%g A22,22 0 0 1 %g,%g' fill='none' stroke='#cfc8ec' stroke-width='2.4'/>" % (gx - 16, gy - 15, gx + 15, gy + 16)
    b += shaded(rect_d(gx - 4, gy + 20, 8, 6), "#cfc8ec", shade=0.2, rim=0.2, sw=0.6)
    room_add("room_desk", dx - 4, dy - 30, dw + 8, dh + 76, b)

    # Silla de espaldas / Chair seen from behind
    sx_, sy_, sw_, sh_ = 1538, 326, 82, 44
    b = ""
    for lx in (1542, 1610):
        b += shaded(rect_d(lx, 368, 6, 30), "#3a346f", shade=0.2, rim=0.2, sw=0.6)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g Q%g,%g %g,%g Z" % (sx_ + 6, sy_, sx_ + sw_ / 2, sy_ - 3, sx_ + sw_ - 6, sy_, sx_ + sw_, sy_ + sh_,
                sx_ + sw_ / 2, sy_ + sh_ + 3, sx_, sy_ + sh_), "#7d73bd", shade=0.35, rim=0.35)
    b += shaded(rect_d(sx_ + 8, sy_ + 4, sw_ - 16, 18), "#e3a6c4", shade=0.3, rim=0.3, sw=0.8)
    bx, by, bw, bh = sx_ + 4, sy_ + sh_ - 58, sw_ - 8, 50
    for lx in (bx + 6, bx + bw - 12):
        b += shaded(rect_d(lx, by + bh, 6, 14), "#4a4592", shade=0.2, rim=0.2, sw=0.6)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g L%g,%g Z" % (bx, by + 10, bx + bw / 2, by - 6, bx + bw, by + 10, bx + bw, by + bh, bx, by + bh), "#5a4f9e", shade=0.4, rim=0.35)
    b += shaded(rect_d(bx + 10, by + 10, bw - 20, bh - 20), "#6a5fae", shade=0.25, rim=0.2, sw=0.6)
    room_add("room_chair", 1530, 300, 98, 102, b)

    # Mesilla con la lamparita / Nightstand with the night-light
    nx, ny, nw, nh = 372, 246, 90, 80
    b = shaded(rect_d(nx, ny, nw, nh), "#9b92d4", shade=0.4, rim=0.4, sw=1.2)
    b += shaded(rect_d(nx, ny + nh - 30, nw, 30), "#7d73bd", shade=0.3, rim=0.2, sw=0.8)
    b += "<circle cx='%g' cy='%g' r='3.5' fill='#f3effc'/>" % (nx + nw / 2, ny + nh - 15)
    b += shaded(ellipse_d(nx + 48, ny + 30, 16, 16), "#fff1c9", shade=0.2, rim=0.2, sw=0.8)
    b += "<path d='%s' fill='#f6c86a'/>" % star_d(nx + 48, ny + 30, 8.5)
    room_add("room_nightstand", nx - 4, ny - 4, nw + 8, nh + 8, b)
    g = (nx + 20, ny + 64)
    b = ("<circle cx='%g' cy='%g' r='7' fill='none' stroke='#2b2945' stroke-width='2.4'/><circle cx='%g' cy='%g' r='7' fill='none' stroke='#2b2945' stroke-width='2.4'/>"
         "<path d='M%g,%g L%g,%g' stroke='#2b2945' stroke-width='2.4'/>" % (g[0], g[1], g[0] + 18, g[1], g[0] + 7, g[1], g[0] + 11, g[1]))
    room_add("room_glasses", g[0] - 10, g[1] - 10, 40, 20, b, colors=4)

    # Cama: cabecero, colchón y sábana / Bed: headboard, mattress and sheet
    bx, by, bw, bh = 150, 236, 200, 262
    b = "<rect x='%g' y='%g' width='%g' height='16' fill='#0d0833' opacity='0.35'/>" % (bx + 12, by + bh - 6, bw - 4)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g L%g,%g Z" % (bx - 8, by - 26, bx + bw / 2, by - 48, bx + bw + 8, by - 26, bx + bw + 8, by + 24, bx - 8, by + 24),
                "#aab4ea", shade=0.45, rim=0.5)
    for x in (bx - 2, bx + bw + 2):
        b += shaded(ellipse_d(x, by - 36, 10, 10), "#cfd6f6", shade=0.35, rim=0.5, sw=0.8)
    b += shaded(rect_d(bx, by + 10, bw, bh - 10), "#e6e2f6", shade=0.4, rim=0.4)
    b += shaded(rect_d(bx, by + bh - 26, bw, 26), "#bdb5e2", shade=0.3, rim=0.2, sw=0.8)
    room_add("room_bed", bx - 20, by - 50, bw + 40, bh + 70, b)
    pl = (bx + 24, by + 24, bw - 48, 58)
    b = shaded("M%g,%g Q%g,%g %g,%g Q%g,%g %g,%g Q%g,%g %g,%g Q%g,%g %g,%g Z" % (
        pl[0] + 6, pl[1] + 2, pl[0] + pl[2] / 2, pl[1] - 6, pl[0] + pl[2] - 6, pl[1] + 2,
        pl[0] + pl[2] + 6, pl[1] + pl[3] / 2, pl[0] + pl[2] - 6, pl[1] + pl[3] - 2,
        pl[0] + pl[2] / 2, pl[1] + pl[3] + 6, pl[0] + 6, pl[1] + pl[3] - 2,
        pl[0] - 6, pl[1] + pl[3] / 2, pl[0] + 6, pl[1] + 2), "#f8f6ff", shade=0.35, rim=0.4, deep="#8d82c4")
    room_add("room_bed_pillow", pl[0] - 10, pl[1] - 10, pl[2] + 20, pl[3] + 20, b)
    # Edredón con su embozo (se recorta por arriba según dónde esté) / Quilt with its fold (cropped to height)
    qx, qy, qw, qh = bx - 6, by + 88, bw + 12, bh - 88 + 4
    stars = ""
    y, row = qy + 34, 0
    while y < qy + qh - 10:
        x = qx + (24 if row % 2 == 0 else 52)
        while x < qx + qw - 10:
            stars += "<path d='%s' fill='#f6d993' opacity='0.8'/>" % star_d(x, y, 5.5)
            x += 56
        y += 42
        row += 1
    b = shaded(rect_d(qx, qy, qw, qh), "#5b67c4", shade=0.5, rim=0.35, extra=stars + fold("M%g,%g Q%g,%g %g,%g" % (qx + 60, qy + 40, qx + 70, qy + 100, qx + 62, qy + 160), "#5b67c4", 4, 0.4))
    b += shaded(rect_d(qx, qy, qw, 22), "#eeeaf8", shade=0.3, rim=0.3, sw=0.8)
    room_add("room_quilt", qx - 2, qy - 2, qw + 4, qh + 4, b)

    # Baúl de juguetes con la tapa abierta / Toy chest with the lid open
    cx, cy, cw, ch = 500, 262, 150, 82
    b = shaded(rect_d(cx + 4, cy - 50, cw - 8, 50), "#a87fbf", shade=0.35, rim=0.4, sw=1.4)
    b += shaded(ellipse_d(cx + 40, cy + 8, 18, 18), "#e3a6c4", shade=0.35, rim=0.4, sw=0.8)
    b += shaded("M%g,%g L%g,%g L%g,%g Z" % (cx + 84, cy + 14, cx + 96, cy - 22, cx + 108, cy + 14), "#f6d993", shade=0.3, rim=0.4, sw=0.8)
    b += "<circle cx='%g' cy='%g' r='4' fill='#7fb0e0'/>" % (cx + 96, cy)
    b += shaded(rect_d(cx + 112, cy - 6, 20, 20), "#9fd29a", shade=0.3, rim=0.3, sw=0.8)
    b += shaded(rect_d(cx, cy, cw, ch), "#c0a0dc", shade=0.45, rim=0.45, sw=1.4)
    b += shaded(rect_d(cx, cy + ch - 22, cw, 22), "#9e7fbf", shade=0.3, rim=0.2, sw=0.8)
    b += "<path d='%s' fill='#f6d993' stroke='#c9a24e' stroke-width='1'/>" % star_d(cx + cw / 2, cy + ch / 2 - 6, 12)
    room_add("room_toy_chest", cx - 4, cy - 56, cw + 8, ch + 60, b)

    # Alfombra redonda con estrellas y luna / Round rug with stars and moon
    rx, ry = 1010, 700
    b = shaded(ellipse_d(rx, ry, 340, 150), "#5a4f9e", shade=0.35, rim=0.25, sw=2)
    b += "<path d='%s' fill='none' stroke='#f6d993' stroke-width='3' opacity='0.5'/>" % ellipse_d(rx, ry, 340 * 0.86, 150 * 0.86)
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        b += "<path d='%s' fill='#f6d993' opacity='0.45'/>" % star_d(rx + math.cos(a) * 225, ry + math.sin(a) * 92, 9.5)
    b += "<path d='M%g,%g A44,44 0 1 1 %g,%g' fill='none' stroke='#f6d993' stroke-width='6' opacity='0.5'/>" % (
        rx + 44 * math.cos(math.pi * 0.35), ry + 44 * math.sin(math.pi * 0.35), rx + 44 * math.cos(math.pi * 1.65), ry + 44 * math.sin(math.pi * 1.65))
    room_add("room_rug", rx - 346, ry - 156, 692, 312, b, colors=10)
    # Alfombrita y conejo / Bedside rug and bunny
    brx, bry = 450, 560
    b = shaded(ellipse_d(brx, bry, 92, 46), "#c98fb8", shade=0.3, rim=0.3, sw=1.4)
    b += "<path d='%s' fill='none' stroke='#f7e6f0' stroke-width='2.4' opacity='0.7'/>" % ellipse_d(brx, bry, 78, 36)
    room_add("room_bedside_rug", brx - 96, bry - 50, 192, 100, b, colors=8)
    bun = "<g transform='translate(%g,%g) rotate(-23)'>" % (brx + 56, bry - 16)
    bun += "<path d='%s' fill='#000000' opacity='0.12'/>" % ellipse_d(4, 30, 30, 8)
    for ex in (-4, 12):
        bun += shaded(ellipse_d(ex, -40 + (2 if ex > 0 else 0), 7, 20), "#eeeaf6", shade=0.3, rim=0.3, sw=0.8)
        bun += "<path d='%s' fill='#f2b8c8'/>" % ellipse_d(ex, -40 + (2 if ex > 0 else 0), 3, 13)
    bun += shaded(ellipse_d(4, 10, 20, 22), "#eeeaf6", shade=0.35, rim=0.35)
    bun += shaded(ellipse_d(4, -14, 16, 16), "#eeeaf6", shade=0.3, rim=0.35)
    bun += "<circle cx='-2' cy='-16' r='2.4' fill='#3a2a30'/><circle cx='10' cy='-16' r='2.4' fill='#3a2a30'/><circle cx='4' cy='-10' r='2.2' fill='#f2b8c8'/></g>"
    room_add("room_bunny", brx + 10, bry - 90, 90, 130, bun, colors=10)

    # Osito / Teddy bear (centrado en su punto, escala 0,7) / (centred on its point, scale 0.7)
    t = "<g transform='scale(0.7)'>"
    t += "<circle cx='0' cy='30' r='26' fill='#000000' opacity='0.1'/>"
    for x in (-18, 18):
        t += shaded(ellipse_d(x, 30, 10, 10), "#a87a5c", shade=0.3, rim=0.3, sw=0.8)
    t += shaded(ellipse_d(0, 14, 22, 24), "#c99a78", shade=0.4, rim=0.4) + "<path d='%s' fill='#e8c9a8'/>" % ellipse_d(0, 18, 12, 14)
    for x in (-20, 20):
        t += shaded(ellipse_d(x, 8, 8, 8), "#a87a5c", shade=0.3, rim=0.3, sw=0.8)
    for x in (-14, 14):
        t += shaded(ellipse_d(x, -28, 9, 9), "#c99a78", shade=0.3, rim=0.3, sw=0.8) + "<circle cx='%d' cy='-28' r='4.5' fill='#e8c9a8'/>" % x
    t += shaded(ellipse_d(0, -16, 18, 18), "#c99a78", shade=0.4, rim=0.4)
    t += "<path d='%s' fill='#e8c9a8'/><circle cx='0' cy='-12' r='2.8' fill='#3a2a30'/><circle cx='-7' cy='-20' r='2.4' fill='#3a2a30'/><circle cx='7' cy='-20' r='2.4' fill='#3a2a30'/>" % ellipse_d(0, -10, 8, 6)
    t += "<path d='M0,0 L-10,-6 L-10,6 Z M0,0 L10,-6 L10,6 Z' fill='#5b67c4'/></g>"
    room_add("room_teddy", -30, -36, 60, 66, t, colors=10)

    # Cubos y pelota / Blocks and ball
    b = ""
    for (x, y), col, letter in (((36, 318), "#f6d993", "A"), ((82, 318), "#a9c8f2", "B"), ((59, 276), "#e3a6c4", "C")):
        b += shaded(rect_d(x, y, 42, 42), col, shade=0.35, rim=0.4, sw=1.2)
        b += "<text x='%g' y='%g' font-family='Georgia,serif' font-weight='bold' font-size='26' fill='#3a346f'>%s</text>" % (x + 12, y + 30, letter)
    room_add("room_blocks", 32, 272, 94, 92, b, colors=12)
    bx_, by_ = 1214, 322
    b = "<path d='%s' fill='#000000' opacity='0.18'/>" % ellipse_d(bx_ + 2, by_ + 22, 22, 6)
    b += shaded(ellipse_d(bx_, by_, 22, 22), "#f3effc", shade=0.4, rim=0.4,
                extra="<path d='M%g,%g A22,22 0 0 1 %g,%g' fill='none' stroke='#e85d75' stroke-width='9'/><path d='M%g,%g A22,22 0 0 1 %g,%g' fill='none' stroke='#5b67c4' stroke-width='9'/>" % (
                    bx_ + 22 * math.cos(-0.6), by_ + 22 * math.sin(-0.6), bx_ + 22 * math.cos(0.9), by_ + 22 * math.sin(0.9),
                    bx_ + 22 * math.cos(2.4), by_ + 22 * math.sin(2.4), bx_ + 22 * math.cos(3.9), by_ + 22 * math.sin(3.9)))
    room_add("room_ball", bx_ - 26, by_ - 26, 54, 58, b, colors=10)

    # Dibujo y póster / Drawing and poster
    d = "<g transform='translate(615,134) rotate(-2.9)'>" + shaded(rect_d(-55, -42, 110, 84), "#f7f3ea", shade=0.2, rim=0.2, sw=1)
    d += "<circle cx='26' cy='-18' r='12' fill='#f6d993'/><path d='M-40,30 L-40,6 L-24,-8 L-8,6 L-8,30 Z' fill='#e3a6c4'/>"
    d += "<path d='M-50,32 L50,32' stroke='#9fd29a' stroke-width='3'/>"
    d += "<circle cx='14' cy='6' r='5' fill='#5b67c4'/><path d='M14,11 L14,22 L9,30 M14,22 L19,30 M8,14 L20,14' fill='none' stroke='#5b67c4' stroke-width='2.4'/>"
    d += "<rect x='-14' y='-46' width='28' height='8' fill='#ffffff' opacity='0.6'/></g>"
    room_add("room_drawing", 552, 84, 126, 102, d, colors=12)
    psx, psy, psw, psh = 1490, 52, 250, 150
    b = "<rect x='%g' y='%g' width='%g' height='%g' fill='#141a4a' stroke='#cfc8ec' stroke-width='3.5'/>" % (psx, psy, psw, psh)
    sun = (psx + 26, psy + 75)
    b += "<circle cx='%g' cy='%g' r='30' fill='#f6d993' opacity='0.25'/>" % sun + shaded(ellipse_d(sun[0], sun[1], 16, 16), "#f6c86a", shade=0.3, rim=0.3, sw=0.6)
    half = psh / 2 - 8
    for rr, pr, col, ph in ((42, 4, "#cfc8ec", 0.5), (70, 6, "#e3a6c4", -0.35), (100, 7, "#7fb0e0", 0.2), (136, 11, "#f0c38f", -0.25), (176, 8, "#b6e0d6", 0.1)):
        span = math.asin(min(0.98, half / rr))
        b += "<path d='M%g,%g A%g,%g 0 0 1 %g,%g' fill='none' stroke='#ffffff' stroke-width='1.4' opacity='0.25'/>" % (
            sun[0] + rr * math.cos(-span), sun[1] + rr * math.sin(-span), rr, rr, sun[0] + rr * math.cos(span), sun[1] + rr * math.sin(span))
        b += shaded(ellipse_d(sun[0] + math.cos(ph * span) * rr, sun[1] + math.sin(ph * span) * rr, pr, pr), col, shade=0.3, rim=0.3, sw=0.6)
    room_add("room_poster", psx - 4, psy - 4, psw + 8, psh + 8, b, colors=16)

    # Armas en su sitio / Weapons in place
    bat = "<g transform='rotate(11.5)'>" + shaded("M-3,0 L3,0 L7,-96 L0,-106 L-7,-96 Z", "#c99a68", shade=0.4, rim=0.4, sw=1) + shaded(rect_d(-4, -16, 8, 16), "#3a3355", shade=0.2, rim=0.2, sw=0.6) + "</g>"
    room_add("room_bat", -30, -112, 44, 116, bat, colors=8)
    bk = (1500, 250, 56, 40)
    b = shaded(rect_d(*bk), "#3b4fa8", shade=0.3, rim=0.3, sw=1) + shaded(rect_d(bk[0] + 4, bk[1] + 4, bk[2] - 8, bk[3] - 8), "#fbf3dc", shade=0.2, rim=0.2, sw=0.6)
    b += "<path d='M%g,%g L%g,%g' stroke='#3b4fa8' stroke-width='3'/>" % (bk[0] + bk[2] / 2, bk[1], bk[0] + bk[2] / 2, bk[1] + bk[3])
    room_add("room_book", bk[0] - 4, bk[1] - 4, bk[2] + 8, bk[3] + 8, b, colors=8)
    vx, vy = 1835, 330
    b = "<path d='%s' fill='#000000' opacity='0.2'/>" % ellipse_d(vx, vy + 30, 26, 8)
    b += "<path d='M%g,%g L%g,%g L%g,%g' fill='none' stroke='#4a4f86' stroke-width='6' stroke-linejoin='round'/>" % (vx - 16, vy - 10, vx - 40, vy - 40, vx - 30, vy - 80)
    b += shaded(rect_d(vx - 44, vy - 92, 26, 12), "#4a4f86", shade=0.3, rim=0.3, sw=0.8)
    b += shaded(ellipse_d(vx, vy, 22, 30), "#e9e3f3", shade=0.45, rim=0.4, deep="#6c64a8")
    b += shaded(ellipse_d(vx - 2, vy - 8, 10, 12), "#8fd6cf", shade=0.3, rim=0.4, sw=0.8)
    room_add("room_vacuum", vx - 50, vy - 96, 80, 136, b, colors=12)


# --- Objetos del suelo / Floor pickups ------------------------------------------------

def pickups():
    # Vaso de leche / Glass of milk
    b = shaded("M-11,-30 L11,-30 L9,0 Q0,3 -9,0 Z", "#cfd8f6", shade=0.35, rim=0.5, deep="#6c74b0")
    b += shaded("M-10,-22 L10,-22 L8.6,-1 Q0,1.6 -8.6,-1 Z", "#fbf8ff", shade=0.3, rim=0.3, sw=0.6)
    b += "<path d='M-6,-27 L-5,-4' stroke='#ffffff' stroke-width='2.4' opacity='0.8' stroke-linecap='round'/>"
    b += "<path d='M-10,-22 Q-4,-25 0,-22 Q5,-19 10,-22' fill='none' stroke='#ffffff' stroke-width='1.6'/>"
    add("pickup_milk", -15, -34, 30, 40, b)
    # Almohada escudo / Pillow shield
    pts = []
    for k in range(48):
        a = math.tau * k / 48
        c, s_ = math.cos(a), math.sin(a)
        pts.append("%.2f,%.2f" % (math.copysign(abs(c) ** 0.6, c) * 18, math.copysign(abs(s_) ** 0.6, s_) * 13 - 14))
    pil = "M" + " L".join(pts) + " Z"
    b = shaded(pil, "#f0ebfb", shade=0.45, rim=0.4, deep="#8d82c4")
    b += "<path d='%s' fill='#8fe0ff' stroke='#4aa8d0' stroke-width='1'/>" % star_d(0, -14, 6)
    add("pickup_pillow", -22, -32, 44, 36, b)
    # Despertador / Alarm clock
    b = ""
    for x in (-9, 9):
        b += shaded(ellipse_d(x, -30, 5.5, 5.5), "#f6c86a", shade=0.3, rim=0.4, sw=0.8)
    b += "<path d='M-8,-2 L-11,3 M8,-2 L11,3' stroke='#4a3f7a' stroke-width='3' stroke-linecap='round'/>"
    b += shaded(ellipse_d(0, -15, 14, 14), "#e85d75", shade=0.45, rim=0.45)
    b += shaded(ellipse_d(0, -15, 10, 10), "#fbf8ff", shade=0.2, rim=0.2, sw=0.6)
    b += "<path d='M0,-15 L0,-22 M0,-15 L5,-12' stroke='#2b2945' stroke-width='2' stroke-linecap='round'/>"
    add("pickup_clock", -18, -38, 36, 44, b)


# --- Dibujos infantiles de los logros / Children's drawings for achievements ---------
# Hoja de papel algo torcida con trazos de cera; van pegados en la pared de la habitación.
# A slightly crooked sheet of paper with crayon strokes; they're taped to the bedroom wall.

DRAWING_SLOTS = {
    "foox": (78, 150, -4),       # encima de los cubos / above the blocks
    "bed": (256, 108, 3),        # encima de la cama / above the bed
    "moon": (472, 176, -3),      # junto a la mesilla / by the nightstand
    "golden": (1834, 150, 4),    # esquina derecha / right corner
    "star": (1446, 132, -5),     # entre la estantería y el póster / between shelf and poster
    "chef": (1178, 80, 3),       # entre la ventana y la estantería / between window and shelf
    "coin": (350, 62, -4),       # sobre la cama, junto a la guirnalda / above the bed, by the garland
}


def crayon(d, color, w=4.0):
    return ("<path d='%s' fill='none' stroke='%s' stroke-width='%g' stroke-linecap='round' stroke-linejoin='round' opacity='0.95'/>" % (d, color, w))


def drawings():
    pics = {
        "foox": crayon("M-20,6 Q-6,-6 12,-2 L16,-12 L19,-3 L24,-12 L25,0 Q32,4 26,8 Q8,14 -20,6 Z", "#8fb3e8", 3.4)
        + crayon("M-20,6 Q-30,2 -32,-6", "#8fb3e8", 3.4) + "<circle cx='20' cy='2' r='2' fill='#2b2945'/>",
        "bed": crayon("M-26,12 L-26,-12 L26,-12 L26,12", "#5b67c4", 3.4) + crayon("M-26,0 L26,0", "#5b67c4", 3.4)
        + "<circle cx='-8' cy='-5' r='3' fill='#e85d75'/><circle cx='8' cy='-5' r='3' fill='#e85d75'/>"
        + crayon("M-26,12 L-30,18 M26,12 L30,18 M-10,12 L-12,18 M10,12 L12,18", "#4a4f86", 3),
        "moon": crayon("M6,-18 A18,18 0 1 0 6,18 A12,14 0 1 1 6,-18 Z", "#8a6ff0", 3.4)
        + "<path d='%s' fill='#e85d75'/>" % star_d(18, -10, 4) + "<path d='%s' fill='#f6c86a'/>" % star_d(20, 10, 3),
        "golden": crayon("M-20,6 Q-6,-6 12,-2 L16,-12 L19,-3 L24,-12 L25,0 Q32,4 26,8 Q8,14 -20,6 Z", "#f0b93a", 3.6)
        + "<path d='%s' fill='#f6d993'/>" % star_d(-24, -12, 5) + "<path d='%s' fill='#f6d993'/>" % star_d(30, -14, 4),
        "chef": crayon("M-16,2 Q-24,-10 -14,-18 Q-8,-28 0,-22 Q8,-28 14,-18 Q24,-10 16,2 Z", "#cfc8ec", 3.4)
        + crayon("M-14,2 L14,2 L14,8 L-14,8 Z", "#cfc8ec", 3) + crayon("M-10,18 Q-4,13 0,17 Q4,13 10,18", "#2b2945", 3)
        + "<circle cx='-6' cy='12' r='2.2' fill='#2b2945'/><circle cx='6' cy='12' r='2.2' fill='#2b2945'/>",
        "coin": crayon("M0,-20 L14,0 L0,20 L-14,0 Z", "#8a6ff0", 3.4) + crayon("M0,-20 L2,0 L14,0 M2,0 L0,20", "#b8a6ff", 2.4)
        + "<path d='%s' fill='#f6c86a'/>" % star_d(22, -14, 4),
        "star": "<path d='%s' fill='none' stroke='#f0b93a' stroke-width='3.6' stroke-linejoin='round'/>" % star_d(0, 0, 20)
        + crayon("M-28,-18 L-22,-12 M28,18 L22,12 M-28,18 L-22,13", "#e3a6c4", 3),
    }
    for name, pic in pics.items():
        x, y, rot = DRAWING_SLOTS[name]
        paper = shaded(rect_d(-38, -30, 76, 60), "#f7f3ea", shade=0.2, rim=0.2, sw=1)
        tape = "<rect x='-12' y='-34' width='24' height='8' fill='#ffffff' opacity='0.6'/>"
        b = "<g transform='translate(%g,%g) rotate(%g)'>%s%s%s</g>" % (x, y, rot, paper, pic, tape)
        room_add("room_draw_" + name, x - 46, y - 40, 92, 80, b, colors=12)


# --- Acto 2: el salón / Act 2: the living room -------------------------------------------
# Mismo lienzo que la habitación (1920 x 1080, pared hasta y = 300).
# Same canvas as the bedroom (1920 x 1080, wall down to y = 300).

def living_room():
    WB = 300
    # Papel pintado de rayas con flores y zócalo de madera; un sprite por nivel de rareza
    # Striped floral wallpaper with a wooden dado; one sprite per strangeness level
    for wl in range(4):
        k = min(1.0, wl / 3.0)
        base, stripe = mix("#4a2a5e", "#1f4a5a", k), mix("#5a3470", "#2a6a6a", k)
        flower = mix("#e3a6c4", "#9ff0d0", k)
        b = "<rect x='0' y='0' width='1920' height='%d' fill='%s'/>" % (WB, base)
        for x in range(0, 1920, 64):
            b += "<rect x='%d' y='0' width='30' height='210' fill='%s'/>" % (x, stripe)
        for row, y in enumerate(range(28, 200, 56)):
            for x in range(15 + (row % 2) * 32, 1920, 64):
                b += "<circle cx='%d' cy='%d' r='5' fill='%s' opacity='0.45'/><circle cx='%d' cy='%d' r='2' fill='#f6d993' opacity='0.6'/>" % (x, y, flower, x, y)
        # Moldura y zócalo / Picture rail and dado
        b += shaded(rect_d(0, 200, 1920, 10), "#c9a27a", shade=0.3, rim=0.5, sw=1)
        b += "<rect x='0' y='210' width='1920' height='%d' fill='%s'/>" % (WB - 210, mix("#6a4a3a", "#3a5a5a", k))
        for x in range(10, 1920, 120):
            b += shaded(rect_d(x, 224, 100, 56), mix("#7a5844", "#46706a", k), shade=0.3, rim=0.3, sw=0.8)
        b += shaded(rect_d(0, WB - 14, 1920, 18), "#d8b890", shade=0.3, rim=0.5, sw=1.2)
        room_add("lroom_wall_%d" % wl, 0, 0, 1920, WB + 4, b, colors=14)

    # Parqué en espiga cuadrada / Square basket-weave parquet
    b = "<rect x='0' y='%d' width='1920' height='740' fill='#4a3258'/>" % WB
    size = 96
    for gy, y in enumerate(range(WB + 4, 1040, size // 2)):
        for gx, x in enumerate(range(-48 * (gy % 2), 1920, size)):
            horiz = (gx + gy) % 2 == 0
            for k in range(3):
                if horiz:
                    r_ = (x, y + k * 16, size, 16)
                else:
                    r_ = (x + k * 32, y, 32, 48)
                tone = ["#56396a", "#4e3462", "#5c3e70"][(k + gx + gy) % 3]
                b += "<rect x='%g' y='%g' width='%g' height='%g' fill='%s' stroke='#2e1e40' stroke-width='2' stroke-opacity='0.6'/>" % (r_ + (tone,))
    room_add("lroom_floor", 0, WB, 1920, 742, b, colors=10)

    # Ventana con cortinas de terciopelo / Window with velvet curtains
    wx, wy, ww, wh = 200, 40, 200, 160
    fr = "#e8dcc8"
    b = "<path d='%s %s' fill-rule='evenodd' fill='%s'/>" % (rect_d(wx - 5, wy - 5, ww + 10, wh + 10), rect_d(wx + 5, wy + 5, ww - 10, wh - 10), fr)
    b += "<rect x='%g' y='%g' width='6' height='%g' fill='%s'/>" % (wx + ww / 2 - 3, wy, wh, fr)
    b += "<rect x='%g' y='%g' width='%g' height='6' fill='%s'/>" % (wx, wy + wh / 2 - 3, ww, fr)
    b += shaded(rect_d(wx - 18, wy + wh + 2, ww + 36, 12), "#efe4d2", shade=0.3, rim=0.4, sw=1)
    room_add("lroom_window_frame", wx - 22, wy - 8, ww + 44, wh + 26, b, colors=8)
    for side, x0 in (("l", wx - 58), ("r", wx + ww + 4)):
        cur = "M%g,16 L%g,16 Q%g,120 %g,210 Q%g,216 %g,218 Q%g,120 %g,16 Z" % (x0, x0 + 54, x0 + 56, x0 + 54, x0 + 27, x0, x0 - 2, x0)
        folds = "".join(fold("M%g,22 Q%g,120 %g,212" % (x0 + 12 + k * 15, x0 + 15 + k * 15, x0 + 12 + k * 15), "#8a2e4a", 3.5, 0.45) for k in range(3))
        tie = shaded(rect_d(x0 - 2, 130, 58, 10), "#e0b860", shade=0.3, rim=0.4, sw=0.8)
        b = shaded(cur, "#8a2e4a", shade=0.45, rim=0.4, extra=folds) + tie
        room_add("lroom_curtain_" + side, x0 - 6, 10, 68, 214, b)
    room_add("lroom_curtain_rod", wx - 80, 8, ww + 160, 14, shaded(rect_d(wx - 76, 10, ww + 152, 8), "#e0b860", shade=0.3, rim=0.5, sw=1), colors=6)

    # Mesita con teléfono de disco / Little table with a rotary phone
    tx_, ty_ = 70, 236
    b = ""
    for lx in (tx_ + 8, tx_ + 84):
        b += shaded(rect_d(lx, ty_ + 30, 8, 66), "#5a3a2a", shade=0.3, rim=0.3, sw=0.8)
    b += shaded(ellipse_d(tx_ + 50, ty_ + 30, 56, 14), "#8a5a3e", shade=0.35, rim=0.45)
    b += "<path d='%s' fill='#f4ecdc' opacity='0.8'/>" % ellipse_d(tx_ + 50, ty_ + 28, 40, 9)
    b += shaded("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (tx_ + 28, ty_ + 26, tx_ + 72, ty_ + 26, tx_ + 66, ty_ + 6, tx_ + 34, ty_ + 6), "#c9475a", shade=0.4, rim=0.4, sw=1)
    b += shaded(ellipse_d(tx_ + 50, ty_ + 16, 8, 6), "#f4ecdc", shade=0.2, rim=0.2, sw=0.6)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g Q%g,%g %g,%g Z" % (tx_ + 26, ty_ + 4, tx_ + 50, ty_ - 8, tx_ + 74, ty_ + 4, tx_ + 70, ty_ + 8, tx_ + 50, ty_ - 2, tx_ + 30, ty_ + 8), "#a83a4e", shade=0.3, rim=0.4, sw=0.8)
    room_add("lroom_phone_table", tx_ - 10, ty_ - 14, 124, 116, b, colors=12)

    # Fotos de familia en la pared / Family photos on the wall
    b = ""
    for (fx_, fy_, fw, fh, rot, col) in ((520, 50, 50, 62, -3, "#c9a24e"), (590, 70, 44, 44, 4, "#b8b0d8"), (536, 128, 60, 44, 2, "#8a5a3e")):
        inner = shaded(rect_d(-fw / 2, -fh / 2, fw, fh), col, shade=0.3, rim=0.4, sw=1)
        inner += "<rect x='%g' y='%g' width='%g' height='%g' fill='#3a4a7a'/>" % (-fw / 2 + 6, -fh / 2 + 6, fw - 12, fh - 12)
        inner += "<circle cx='0' cy='%g' r='%g' fill='#f1cfbb'/><path d='M%g,%g Q0,%g %g,%g Z' fill='#7a5a9e'/>" % (-fh / 8, fw / 8, -fw / 4, fh / 2 - 6, fh / 12, fw / 4, fh / 2 - 6)
        b += "<g transform='translate(%g,%g) rotate(%g)'>%s</g>" % (fx_, fy_, rot, inner)
    room_add("lroom_photos", 488, 14, 140, 160, b, colors=14)

    # Sillón de la abuela (de frente) / Grandma's armchair (facing us)
    ax, ay = 470, 196
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % ellipse_d(ax + 80, ay + 146, 84, 12)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g L%g,%g Z" % (ax + 14, ay + 70, ax + 80, ay - 6, ax + 146, ay + 70, ax + 146, ay + 110, ax + 14, ay + 110), "#4f7a6a", shade=0.45, rim=0.4)
    b += "<path d='%s' fill='#f4ecdc' opacity='0.85'/>" % ellipse_d(ax + 80, ay + 24, 30, 10)
    b += shaded(rect_d(ax + 22, ay + 96, 116, 36), "#5f8e7a", shade=0.4, rim=0.4)
    for sx_ in (ax, ax + 130):
        b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g L%g,%g Z" % (sx_, ay + 74, sx_ + 15, ay + 62, sx_ + 30, ay + 74, sx_ + 28, ay + 140, sx_ + 2, ay + 140), "#45705f", shade=0.4, rim=0.4)
    for lx in (ax + 10, ax + 140):
        b += shaded(rect_d(lx, ay + 138, 10, 12), "#4a2e22", shade=0.2, rim=0.2, sw=0.6)
    b += shaded(ellipse_d(ax + 104, ay + 98, 20, 13), "#e3a6c4", shade=0.35, rim=0.4, sw=0.8)
    room_add("lroom_armchair", ax - 6, ay - 12, 172, 170, b, colors=14)

    # Chimenea de piedra con repisa, reloj y velas / Stone fireplace with mantel, clock and candles
    b = shaded(rect_d(800, 120, 320, 182), "#b8a6a0", shade=0.4, rim=0.35, sw=1.6)
    for row, y in enumerate(range(128, 300, 24)):
        for x in range(800 + (row % 2) * 30, 1120, 60):
            b += "<rect x='%d' y='%d' width='56' height='20' fill='%s' opacity='0.35'/>" % (x + 2, y, ["#d8c8c0", "#9a8a88", "#c8b8b0"][(x // 60 + row) % 3])
    # Hueco del fuego con ladrillo dentro / Firebox with brick inside
    arch = "M870,302 L870,200 Q960,150 1050,200 L1050,302 Z"
    b += "<path d='%s' fill='#2a1a2e'/>" % arch
    for row, y in enumerate(range(196, 300, 14)):
        for x in range(872 + (row % 2) * 14, 1048, 28):
            b += "<rect x='%d' y='%d' width='26' height='12' fill='#5a2e34' opacity='0.5'/>" % (x, y)
    b += "<path d='%s' fill='none' stroke='#6a5a5e' stroke-width='6'/>" % arch
    # Rejilla y troncos / Grate and logs
    b += shaded(rect_d(888, 284, 144, 8), "#2b2945", shade=0.2, rim=0.3, sw=0.6)
    b += shaded("M900,284 L1010,270 L1016,282 L906,294 Z", "#6a4430", shade=0.3, rim=0.3, sw=0.8)
    b += shaded("M920,268 L1024,286 L1018,296 L914,278 Z", "#7a5038", shade=0.3, rim=0.3, sw=0.8)
    # Repisa / Mantel
    b += shaded(rect_d(780, 108, 360, 18), "#8a5a3e", shade=0.35, rim=0.5, sw=1.4)
    # Reloj de repisa / Mantel clock
    b += shaded("M930,108 L930,72 Q960,46 990,72 L990,108 Z", "#6a4430", shade=0.4, rim=0.45)
    b += shaded(ellipse_d(960, 80, 16, 16), "#f4ecdc", shade=0.2, rim=0.2, sw=0.8)
    b += "<path d='M960,80 L960,70 M960,80 L967,84' stroke='#2b2945' stroke-width='2.2' stroke-linecap='round'/>"
    for cx_ in (850, 1070):
        b += shaded(rect_d(cx_ - 6, 76, 12, 32), "#f4ecdc", shade=0.25, rim=0.3, sw=0.8)
        b += shaded(ellipse_d(cx_, 108, 14, 4), "#e0b860", shade=0.3, rim=0.4, sw=0.6)
    b += shaded("M1010,108 L1012,90 L1036,90 L1038,108 Z", "#c9a24e", shade=0.3, rim=0.4, sw=0.8)
    b += "<rect x='1016' y='94' width='16' height='10' fill='#3a4a7a'/>"
    b += shaded("M892,108 Q886,92 896,84 Q906,92 900,108 Z", "#5a8ec4", shade=0.3, rim=0.4, sw=0.8)
    # Losa del hogar / Hearth slab
    b += shaded(rect_d(820, 296, 280, 30), "#8a7a7e", shade=0.3, rim=0.4, sw=1.2)
    room_add("lroom_fireplace", 776, 40, 368, 290, b, colors=24)

    # Cuadro de paisaje / Landscape painting
    px_, py_ = 1180, 34
    b = shaded(rect_d(px_, py_, 150, 104), "#c9a24e", shade=0.3, rim=0.5, sw=1.2)
    b += "<rect x='%d' y='%d' width='130' height='84' fill='#7fb0e0'/>" % (px_ + 10, py_ + 10)
    b += "<path d='M%d,%d L%d,%d L%d,%d L%d,%d L%d,%d Z' fill='#5a8a5a'/>" % (px_ + 10, py_ + 94, px_ + 10, py_ + 60, px_ + 60, py_ + 36, px_ + 100, py_ + 64, px_ + 140, py_ + 94)
    b += "<path d='M%d,%d L%d,%d L%d,%d Z' fill='#f4ecdc'/>" % (px_ + 48, py_ + 44, px_ + 60, py_ + 36, px_ + 72, py_ + 45)
    b += "<circle cx='%d' cy='%d' r='9' fill='#f6d993'/>" % (px_ + 116, py_ + 28)
    room_add("lroom_painting", px_ - 4, py_ - 4, 158, 112, b, colors=12)

    # Lámpara de pie / Floor lamp
    lx_, ly_ = 1380, 330
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % ellipse_d(lx_, ly_ + 4, 26, 7)
    b += shaded(ellipse_d(lx_, ly_, 20, 6), "#c9a24e", shade=0.3, rim=0.4, sw=0.8)
    b += shaded(rect_d(lx_ - 3, 130, 6, ly_ - 130), "#c9a24e", shade=0.3, rim=0.4, sw=0.6)
    b += shaded("M%g,96 L%g,96 L%g,146 L%g,146 Z" % (lx_ - 24, lx_ + 24, lx_ + 40, lx_ - 40), "#f2d6a8", shade=0.35, rim=0.4,
                extra="<path d='M%g,140 L%g,140' stroke='#c98a5a' stroke-width='3'/>" % (lx_ - 38, lx_ + 38))
    room_add("lroom_lamp", lx_ - 46, 90, 92, 250, b, colors=10)

    # Mueble con televisor antiguo / Cabinet with an old television
    cx_, cy_ = 1440, 224
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % rect_d(cx_ + 8, cy_ + 100, 270, 12)
    b += shaded(rect_d(cx_, cy_, 280, 104), "#6a4430", shade=0.4, rim=0.45, sw=1.4)
    for k in range(2):
        b += shaded(rect_d(cx_ + 14 + k * 132, cy_ + 20, 120, 70), "#7a5038", shade=0.3, rim=0.3, sw=0.8)
        b += "<circle cx='%g' cy='%g' r='4' fill='#e0b860'/>" % (cx_ + 74 + k * 132 + (40 if k == 0 else -40), cy_ + 56)
    b += "<path d='%s' fill='#f4ecdc' opacity='0.8'/>" % rect_d(cx_ + 40, cy_ - 4, 200, 8)
    tvx, tvy = 1500, 116
    b += shaded(rect_d(tvx, tvy, 160, 110), "#8a7a9e", shade=0.45, rim=0.4, sw=1.4)
    b += "<rect x='%d' y='%d' width='124' height='84' rx='10' fill='#1a1a2e'/>" % (tvx + 10, tvy + 12)
    for k in range(2):
        b += shaded(ellipse_d(tvx + 148, tvy + 30 + k * 22, 5, 5), "#3a3355", shade=0.2, rim=0.3, sw=0.6)
    b += "<path d='M%d,%d L%d,%d M%d,%d L%d,%d' stroke='#cfc8ec' stroke-width='2.6' stroke-linecap='round'/>" % (tvx + 70, tvy, tvx + 40, tvy - 40, tvx + 90, tvy, tvx + 124, tvy - 44)
    b += shaded(ellipse_d(tvx + 80, tvy, 14, 6), "#3a3355", shade=0.2, rim=0.3, sw=0.6)
    room_add("lroom_tv", cx_ - 4, 66, 288, 274, b, colors=16)

    # Planta grande en maceta / Big potted plant
    pxp, pyp = 1836, 330
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % ellipse_d(pxp, pyp + 4, 36, 8)
    for k, (dx, dy, rot) in enumerate(((-30, -120, -40), (24, -140, 30), (-6, -170, -5), (40, -96, 60), (-44, -80, -70), (10, -110, 10))):
        b += "<g transform='translate(%g,%g) rotate(%g)'>%s</g>" % (pxp + dx * 0.4, pyp - 60 + dy * 0.2, rot, shaded(ellipse_d(0, -40, 16, 44), ["#4f9a6a", "#3f8a5e", "#5faa76"][k % 3], shade=0.4, rim=0.4, sw=0.8))
    b += shaded("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (pxp - 30, pyp - 56, pxp + 30, pyp - 56, pxp + 22, pyp, pxp - 22, pyp), "#c97a5a", shade=0.4, rim=0.4)
    b += shaded(rect_d(pxp - 34, pyp - 62, 68, 10), "#d98a6a", shade=0.3, rim=0.4, sw=0.8)
    room_add("lroom_plant", pxp - 74, 140, 148, 200, b, colors=12)

    # Alfombra persa / Persian rug
    rx, ry, rw, rh = 470, 560, 860, 300
    b = shaded(rect_d(rx, ry, rw, rh), "#7a2e4a", shade=0.3, rim=0.25, sw=2)
    b += "<rect x='%d' y='%d' width='%d' height='%d' fill='none' stroke='#e0b860' stroke-width='6' opacity='0.6'/>" % (rx + 22, ry + 22, rw - 44, rh - 44)
    b += "<rect x='%d' y='%d' width='%d' height='%d' fill='#5a2a5e' opacity='0.8'/>" % (rx + 40, ry + 40, rw - 80, rh - 80)
    for k in range(0, rw - 60, 40):
        b += "<path d='%s' fill='#e0b860' opacity='0.5'/>" % star_d(rx + 30 + k, ry + 11, 6, 0.5, 45)
        b += "<path d='%s' fill='#e0b860' opacity='0.5'/>" % star_d(rx + 30 + k, ry + rh - 11, 6, 0.5, 45)
    cxr, cyr = rx + rw / 2, ry + rh / 2
    b += "<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#c9475a' opacity='0.8'/>" % (cxr - 180, cyr, cxr, cyr - 90, cxr + 180, cyr, cxr, cyr + 90)
    b += "<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#e0b860' opacity='0.6'/>" % (cxr - 90, cyr, cxr, cyr - 45, cxr + 90, cyr, cxr, cyr + 45)
    b += "<path d='%s' fill='#4f7a6a'/>" % star_d(cxr, cyr, 22, 0.5, 45)
    for x in range(rx + 6, rx + rw, 16):
        b += "<path d='M%d,%d L%d,%d M%d,%d L%d,%d' stroke='#f4ecdc' stroke-width='2' opacity='0.6'/>" % (x, ry, x, ry - 10, x, ry + rh, x, ry + rh + 10)
    room_add("lroom_rug", rx - 6, ry - 14, rw + 12, rh + 28, b, colors=12)

    # Mesa de centro con té, revistas y caramelos / Coffee table with tea, magazines and sweets
    mx, my = 1480, 430
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % rect_d(mx + 8, my + 64, 190, 12)
    for lx in (mx + 10, mx + 182):
        b += shaded(rect_d(lx, my + 40, 10, 34), "#4a2e22", shade=0.2, rim=0.2, sw=0.6)
    b += shaded(rect_d(mx, my, 200, 50), "#8a5a3e", shade=0.35, rim=0.45, sw=1.2)
    b += shaded(rect_d(mx, my + 40, 200, 12), "#6a4430", shade=0.3, rim=0.2, sw=0.8)
    b += "<g transform='translate(%d,%d) rotate(-8)'>%s</g>" % (mx + 46, my + 22, shaded(rect_d(-28, -16, 56, 32), "#f4ecdc", shade=0.2, rim=0.2, sw=0.8) + "<rect x='-22' y='-10' width='20' height='16' fill='#c9475a'/>")
    b += shaded(ellipse_d(mx + 120, my + 22, 12, 8), "#f4ecdc", shade=0.3, rim=0.4, sw=0.8) + "<path d='%s' fill='#a86a3a'/>" % ellipse_d(mx + 120, my + 20, 7, 4)
    b += shaded(ellipse_d(mx + 166, my + 22, 20, 10), "#9fd0e8", shade=0.3, rim=0.5, sw=0.8)
    for k, cc in enumerate(("#e85d75", "#f6c86a", "#9be38a", "#c79bff")):
        b += "<circle cx='%g' cy='%g' r='4' fill='%s'/>" % (mx + 156 + k * 6, my + 18 + (k % 2) * 4, cc)
    room_add("lroom_table", mx - 6, my - 10, 212, 92, b, colors=16)

    # Sofá visto por detrás (mira a la tele) con una manta de ganchillo
    # Sofa seen from behind (facing the TV) with a crochet blanket
    sx, sy = 1360, 590
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % rect_d(sx + 10, sy + 116, 404, 14)
    for ex in (sx, sx + 380):
        b += shaded(rect_d(ex, sy + 10, 40, 110), "#7a4a8a", shade=0.4, rim=0.4)
    b += shaded("M%g,%g Q%g,%g %g,%g L%g,%g L%g,%g Z" % (sx + 30, sy + 20, sx + 210, sy - 10, sx + 390, sy + 20, sx + 390, sy + 124, sx + 30, sy + 124), "#8a5a9e", shade=0.45, rim=0.4)
    for k in range(1, 3):
        b += "<path d='M%g,%g L%g,%g' stroke='#5a3a6e' stroke-width='3' opacity='0.6'/>" % (sx + 30 + k * 120, sy + 14, sx + 30 + k * 120, sy + 120)
    blanket = "M%g,%g L%g,%g L%g,%g L%g,%g Z" % (sx + 220, sy + 6, sx + 330, sy + 14, sx + 320, sy + 100, sx + 230, sy + 92)
    squares = ""
    for gy in range(4):
        for gx in range(4):
            col = ["#f6d993", "#e85d75", "#9be38a", "#7fb8ff"][(gx + gy) % 4]
            squares += "<rect x='%g' y='%g' width='20' height='19' fill='%s' opacity='0.85'/>" % (sx + 232 + gx * 22, sy + 14 + gy * 20, col)
    b += shaded(blanket, "#f4ecdc", shade=0.3, rim=0.3, extra=squares)
    room_add("lroom_sofa", sx - 6, sy - 20, 432, 156, b, colors=18)


def charo_body(small):
    """Kioskera Charo: anciana bajita y redondita, con gafas, permanente gris y rebeca.
    Kiosk lady Charo: a short, round old woman with glasses, a grey perm and a cardigan."""
    skin, shade_c = "#f0cdb6", "#cfa898"
    b = ""
    for x in (84, 104):
        b += shaded("M%g,240 L%g,240 L%g,278 L%g,278 Z" % (x, x + 14, x + 14, x), "#d9b8a8", shade=0.35, rim=0.3)
        b += shaded(ellipse_d(x + 7, 282, 12, 6), "#5a3a2e", shade=0.3, rim=0.4)
    # Falda / Skirt
    b += shaded("M58,186 L142,186 L152,248 L48,248 Z", "#6a3a6e", shade=0.45, rim=0.35)
    # Vestido de flores y barriguita / Floral dress and round tummy
    dots = "".join("<circle cx='%g' cy='%g' r='2.6' fill='#fbe8f0'/>" % (70 + (k * 17) % 62, 120 + (k * 23) % 70) for k in range(14))
    b += shaded("M80,104 L120,104 Q162,126 162,172 Q162,204 136,206 L64,206 Q38,204 38,172 Q38,126 80,104 Z", "#d98aa6", shade=0.5, rim=0.4, extra=dots)
    # Delantal del kiosco con bolsillo / Kiosk apron with a pocket
    b += shaded("M68,150 L132,150 L138,234 L62,234 Z", "#4fa89a", shade=0.4, rim=0.4,
                extra="<rect x='84' y='190' width='32' height='18' fill='#3f8a7e'/><path d='M72,150 Q100,140 128,150' fill='none' stroke='#f4ecdc' stroke-width='2'/>")
    # Rebeca abierta / Open cardigan
    b += shaded("M78,102 L92,104 L82,204 L50,202 Q36,152 54,116 Z", "#7a6ab8", shade=0.45, rim=0.4)
    b += shaded("M122,102 L108,104 L118,204 L150,202 Q164,152 146,116 Z", "#6a5aa8", shade=0.45, rim=0.3)
    # Brazos regordetes con las manos juntas / Chubby arms with hands clasped
    b += shaded("M50,118 L66,112 L84,166 L68,176 Z", "#7a6ab8", shade=0.4, rim=0.4)
    b += shaded("M150,118 L134,112 L116,166 L132,176 Z", "#6a5aa8", shade=0.4, rim=0.3)
    b += shaded(ellipse_d(92, 170, 10, 9), skin, shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(108, 170, 10, 9), shade_c, shade=0.3, rim=0.2, sw=0.8)
    # Cuello y cabeza / Neck and head
    b += shaded("M92,94 L108,94 L108,108 L92,108 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 78, 25, 25), skin, shade=0.45, rim=0.4)
    b += "<circle cx='84' cy='88' r='5' fill='#f0a0a8' opacity='0.6'/><circle cx='116' cy='88' r='5' fill='#f0a0a8' opacity='0.6'/>"
    # Permanente gris / Grey perm
    for cx_, cy_, r in ((78, 64, 10), (86, 52, 11), (100, 47, 12), (114, 52, 11), (122, 64, 10), (74, 76, 8), (126, 76, 8), (92, 50, 8), (108, 50, 8)):
        b += shaded(ellipse_d(cx_, cy_, r, r), "#d8d4e6", shade=0.4, rim=0.5, rim_color="#ffffff", sw=0.8)
    # Pendientes de perla / Pearl earrings
    b += "<circle cx='75' cy='86' r='2.6' fill='#fbf8ff'/><circle cx='125' cy='86' r='2.6' fill='#fbf8ff'/>"
    # Gafas redondas con cadenita / Round glasses with a little chain
    b += "<circle cx='91' cy='80' r='8' fill='#dfe6ff' fill-opacity='0.25' stroke='#7a2e4a' stroke-width='2.4'/>"
    b += "<circle cx='109' cy='80' r='8' fill='#dfe6ff' fill-opacity='0.25' stroke='#7a2e4a' stroke-width='2.4'/>"
    b += "<path d='M99,80 L101,80' stroke='#7a2e4a' stroke-width='2.4'/>"
    b += "<path d='M83,82 Q76,100 88,106 M117,82 Q124,100 112,106' fill='none' stroke='#e0b860' stroke-width='1.2'/>"
    if small:
        add("charo_small", 30, 34, 140, 258, b, px=PX_KROKER, colors=24, post=charo_face_small)
    else:
        add("npc_charo", 30, 34, 140, 258, b, px=PX_NPC, colors=32, post=npc_face(80, "#3a2a30", 1))


def charo_face_small(img, to_px):
    pix = img.load()
    w, h = img.size
    for cx in (91, 109):
        x, y = to_px(cx, 80)
        x, y = int(x), int(y)
        if 0 <= x < w and 0 <= y < h:
            pix[x, y] = (42, 30, 40, 255)


def charo_kiosk(px, name):
    """El carrito del kiosco de Charo (a su derecha, mismo lienzo) / Charo's kiosk cart (to her right, same canvas)."""
    x0, x1 = 160, 380
    b = "<path d='%s' fill='#0d0833' opacity='0.3'/>" % ellipse_d((x0 + x1) / 2, 286, 120, 8)
    for x in (x0 + 10, x1 - 16):
        b += shaded(rect_d(x, 70, 6, 120), "#cfc8ec", shade=0.3, rim=0.4, sw=0.6)
    # Toldo de rayas / Striped awning
    stripes = ""
    for k in range(9):
        stripes += "<path d='M%g,56 L%g,56 L%g,92 L%g,92 Z' fill='%s'/>" % (x0 - 10 + k * 28, x0 + 4 + k * 28, x0 + 4 + k * 28, x0 - 10 + k * 28, "#f4ecdc" if k % 2 else "#c9475a")
    b += shaded("M%g,56 L%g,56 L%g,92 L%g,92 Z" % (x0 - 14, x1 + 14, x1 + 14, x0 - 14), "#c9475a", shade=0.3, rim=0.4, extra=stripes)
    for k in range(9):
        b += shaded(ellipse_d(x0 - 2 + k * 28, 94, 13, 8), "#c9475a" if k % 2 == 0 else "#f4ecdc", shade=0.3, rim=0.3, sw=0.6)
    # Mostrador con tarros de caramelos y periódicos / Counter with sweet jars and newspapers
    b += shaded(rect_d(x0, 180, x1 - x0, 92), "#4fa89a", shade=0.4, rim=0.4)
    b += shaded(rect_d(x0 - 6, 172, x1 - x0 + 12, 12), "#f4ecdc", shade=0.3, rim=0.4, sw=0.8)
    for k, cc in enumerate(("#e85d75", "#f6c86a", "#9be38a", "#c79bff")):
        jx = x0 + 22 + k * 50
        b += shaded("M%g,172 L%g,132 Q%g,124 %g,132 L%g,172 Z" % (jx, jx, jx + 16, jx + 32, jx + 32), "#dfe6ff", shade=0.2, rim=0.6, sw=0.8)
        for d in range(5):
            b += "<circle cx='%g' cy='%g' r='4.5' fill='%s'/>" % (jx + 7 + (d * 9) % 20, 164 - (d // 2) * 9, cc)
        b += shaded(rect_d(jx + 4, 122, 24, 8), "#c9475a", shade=0.2, rim=0.3, sw=0.6)
    for k in range(3):
        b += shaded(rect_d(x0 + 16 + k * 66, 198, 54, 60), "#f4ecdc", shade=0.2, rim=0.2, sw=0.8,
                    extra="<rect x='%g' y='206' width='40' height='8' fill='#2b2945'/><rect x='%g' y='220' width='40' height='26' fill='%s'/>" % (x0 + 23 + k * 66, x0 + 23 + k * 66, ["#7fb8ff", "#f6c86a", "#e3a6c4"][k]))
    for x in (x0 + 24, x1 - 24):
        b += shaded(ellipse_d(x, 278, 12, 12), "#2b2945", shade=0.3, rim=0.4, sw=0.8) + "<circle cx='%g' cy='278' r='4' fill='#cfc8ec'/>" % x
    add(name, x0 - 20, 40, x1 - x0 + 40, 256, b, px=px, colors=24)


def act2_enemies():
    # Mosquito: diminuto, a rayas, con trompa; las alas se dibujan en el juego
    # Mosquito: tiny and striped, with a proboscis; the wings are drawn in game
    b = ""
    for lx, ly in ((-2, -27), (2, -27), (5, -28)):
        b += "<path d='M%g,%g L%g,%g L%g,%g' fill='none' stroke='#2a2040' stroke-width='1.6'/>" % (lx, ly, lx - 4, ly + 5, lx - 5, ly + 9)
    stripes = "".join("<rect x='%g' y='-34' width='2.4' height='10' fill='#9a8ac8' opacity='0.8'/>" % x for x in (-14, -10, -6))
    b += "<g transform='rotate(-12 -8 -29)'>%s</g>" % shaded(ellipse_d(-9, -29, 10, 4.6), "#4a3a66", shade=0.4, rim=0.5, sw=0.8, extra=stripes)
    b += shaded(ellipse_d(2, -31, 5, 4.4), "#3a2e52", shade=0.35, rim=0.5, sw=0.8)
    b += shaded(ellipse_d(8, -33, 3.6, 3.4), "#3a2e52", shade=0.3, rim=0.5, sw=0.7)
    b += "<circle cx='9.5' cy='-34' r='1.6' fill='#ff5a7a'/>"
    b += "<path d='M11,-32.5 L21,-28' stroke='#2a2040' stroke-width='1.4' stroke-linecap='round'/>"
    add("mosquito_body", -22, -40, 46, 24, b)

    # Nido: montículo de barro y papel con agujeros de los que salen / Nest: mound of mud and paper with holes they come out of
    mound = "M-36,0 Q-40,-20 -22,-34 Q-4,-48 14,-40 Q36,-30 36,-8 Q36,0 30,2 L-30,2 Q-36,2 -36,0 Z"
    rings = ""
    for k, y in enumerate((-30, -20, -10)):
        rings += "<path d='M%g,%g Q0,%g %g,%g' fill='none' stroke='#5a4458' stroke-width='2.2' opacity='0.7'/>" % (-30 + k * -2, y + 2, y - 6, 30 + k * 2, y + 2)
    b = "<path d='%s' fill='#000000' opacity='0.25'/>" % ellipse_d(0, 2, 40, 7)
    b += shaded(mound, "#8a6a7a", shade=0.5, rim=0.4, deep="#4a3048", extra=rings)
    for hx, hy, r in ((-14, -18, 5), (8, -28, 4.5), (16, -10, 5.5)):
        b += "<path d='%s' fill='#1a1020'/>" % ellipse_d(hx, hy, r, r * 0.8)
        b += "<path d='M%g,%g A%g,%g 0 0 1 %g,%g' fill='none' stroke='#c9a8b8' stroke-width='1.4' opacity='0.8'/>" % (hx - r, hy, r, r * 0.8, hx + r, hy)
    for mx, my in ((-30, -4), (-24, -12), (26, -2), (30, -14)):
        b += "<circle cx='%g' cy='%g' r='4' fill='#5fa88a' opacity='0.9'/>" % (mx, my)
    add("nest_body", -42, -50, 84, 60, b, colors=14)


def dot_painter(points, color):
    """Pinta píxeles sueltos (ojos) / Paints single pixels (eyes)."""
    def paint(img, to_px):
        pix = img.load()
        w, h = img.size
        for (X, Y) in points:
            x, y = to_px(X, Y)
            x, y = int(x), int(y)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)) if len(points) and color[3] == 254 else ((0, 0),):
                if 0 <= x + dx < w and 0 <= y + dy < h:
                    pix[x + dx, y + dy] = color[:3] + (255,)
    return paint


def cyberpunk():
    """El Cyberpunk: chaqueta negra con luces de neón, cresta rosa y visor.
    The Cyberpunk: black jacket with neon lights, pink mohawk and a visor."""
    jacket, jdark, neon, neon2, skin = "#262140", "#17142c", "#5ff2ff", "#ff5fd2", "#c9b3d9"
    body = shaded("M-20,-86 Q0,-90 20,-86 L24,-40 Q0,-36 -24,-40 Z", jacket, shade=0.5, rim=0.5, rim_color="#8fe8ff")
    body += "<path d='M-20,-84 L-14,-42 M20,-84 L14,-42' stroke='%s' stroke-width='2.2' opacity='0.9'/>" % neon
    body += "<path d='M-8,-72 L8,-72 M-8,-64 L8,-64' stroke='%s' stroke-width='2' opacity='0.9'/>" % neon2
    body += shaded("M-24,-46 Q0,-42 24,-46 L24,-38 Q0,-34 -24,-38 Z", jdark, shade=0.3, rim=0.3, sw=0.8)
    add("cyber_body", -28, -92, 56, 58, body)
    head = shaded(ellipse_d(0, -102, 15, 16), mix(skin, "#3a2a50", 0.35), shade=0.55, rim=0.3, sw=0.9)
    head += shaded("M-4,-118 L-2,-134 L2,-130 L4,-138 L7,-128 L9,-134 L8,-116 Z", neon2, shade=0.3, rim=0.5, sw=0.8)
    head += shaded("M-15,-108 L16,-108 L17,-99 L-15,-99 Z", "#101830", shade=0.2, rim=0.6, rim_color=neon, sw=0.8)
    head += "<rect x='-12' y='-106' width='26' height='3' fill='%s' opacity='0.9'/>" % neon
    head += "<path d='M10,-94 L14,-92' stroke='%s' stroke-width='1.6'/>" % neon2
    add("cyber_head", -20, -140, 40, 58, head)
    leg = shaded("M-6,-42 L6,-42 L5,-8 Q0,-6 -5,-8 Z", jdark, shade=0.5, rim=0.3, sw=0.8,
                 extra="<rect x='-6' y='-26' width='12' height='2.4' fill='%s' opacity='0.8'/>" % neon)
    leg += shaded("M-7,-9 L8,-9 L9,-2 L-7,-2 Z", "#e9e6f2", shade=0.3, rim=0.3, sw=0.7)
    add("cyber_leg", -10, -45, 20, 45, leg)
    arm = shaded("M-5,0 L5,0 L4,30 L-4,30 Z", jacket, shade=0.4, rim=0.4, sw=0.8,
                 extra="<rect x='-5' y='18' width='10' height='3' fill='%s'/>" % neon)
    arm += shaded(ellipse_d(0, 34, 5, 5), mix(skin, "#3a2a50", 0.35), shade=0.3, rim=0.3, sw=0.7)
    add("cyber_arm", -8, -3, 16, 44, arm)


def chef():
    """El Chef: Kroker de mayor, cocinero. Gafas, pelo negro, bigote, gorro alto y delantal.
    The Chef: grown-up Kroker as a cook. Glasses, black hair, moustache, tall hat and apron."""
    white, shadew, apron, skin, hair = "#f4f1fa", "#b8b0d8", "#5b67c4", "#f1cfbb", "#16141f"
    # Piernas / Legs
    leg = shaded("M-11,-64 L11,-64 L10,-10 Q0,-7 -10,-10 Z", "#2b2945", shade=0.45, rim=0.3,
                 extra="<path d='M-10,-50 L10,-50 M-10,-38 L10,-38' stroke='#3a3866' stroke-width='2'/>")
    leg += shaded("M-12,-12 L14,-12 L16,-1 L-12,-1 Z", "#121020", shade=0.3, rim=0.4, sw=0.8)
    add("chef_leg", -16, -67, 34, 68, leg)
    # Torso: chaqueta cruzada de cocinero y delantal / Torso: double-breasted chef jacket and apron
    body = shaded("M-34,-158 Q0,-166 34,-158 Q46,-150 44,-134 L40,-60 Q0,-54 -40,-60 L-44,-134 Q-46,-150 -34,-158 Z", white, shade=0.45, rim=0.3, deep="#6c64a8")
    for y in (-140, -122, -104):
        for x in (-12, 12):
            body += "<circle cx='%d' cy='%d' r='3' fill='#2b2945'/>" % (x, y)
    body += "<path d='M-26,-158 L0,-142 L26,-158' fill='none' stroke='%s' stroke-width='2.4'/>" % shadew
    body += shaded("M-30,-112 L30,-112 L34,-56 Q0,-50 -34,-56 Z", apron, shade=0.4, rim=0.3,
                   extra="<path d='M-30,-112 L30,-112' stroke='#3e4892' stroke-width='3'/><rect x='-12' y='-92' width='24' height='16' fill='#4a55b0'/>")
    body += "<path d='M-6,-162 Q0,-152 6,-162' fill='none' stroke='#e85d75' stroke-width='4'/>"
    add("chef_body", -50, -168, 100, 118, body)
    # Cabeza con gorro, gafas y bigote / Head with hat, glasses and moustache
    head = shaded(ellipse_d(0, -190, 26, 28), skin, shade=0.45, rim=0.4)
    head += shaded("M-27,-196 Q-28,-216 -12,-220 L12,-220 Q28,-216 27,-196 Q22,-206 14,-204 L-14,-204 Q-22,-206 -27,-196 Z", hair, shade=0.4, rim=0.5, rim_color="#8a7aa8", sw=0.8)
    head += "<path d='M-26,-196 L-26,-184 M26,-196 L26,-184' stroke='%s' stroke-width='4'/>" % hair
    for cx in (-10, 10):
        head += "<circle cx='%d' cy='-190' r='8' fill='#dfe6ff' fill-opacity='0.3' stroke='#2b2945' stroke-width='2.6'/>" % cx
    head += "<path d='M-2,-190 L2,-190' stroke='#2b2945' stroke-width='2.6'/>"
    head += "<path d='M-14,-174 Q-6,-180 0,-175 Q6,-180 14,-174 Q8,-170 0,-172 Q-8,-170 -14,-174 Z' fill='%s'/>" % hair
    head += "<path d='M-8,-166 Q0,-162 8,-166' fill='none' stroke='#a3687a' stroke-width='2'/>"
    # Gorro alto / Tall chef's hat
    hat = shaded("M-22,-222 L22,-222 L24,-208 L-24,-208 Z", white, shade=0.3, rim=0.3, sw=0.9)
    hat += shaded("M-22,-222 Q-38,-236 -30,-256 Q-20,-276 0,-268 Q20,-278 30,-256 Q38,-236 22,-222 Z", white, shade=0.45, rim=0.4, deep="#8a84b8")
    head = hat + head
    add("chef_head", -40, -282, 80, 124, head, colors=20, post=dot_painter([(-10, -190), (10, -190)], (42, 30, 40, 254)))
    # Brazo con la mano / Arm with the hand
    arm = shaded("M-8,0 L8,0 L7,50 L-7,50 Z", white, shade=0.45, rim=0.3, deep="#6c64a8")
    arm += shaded(ellipse_d(0, 56, 8, 8), skin, shade=0.35, rim=0.3, sw=0.8)
    add("chef_arm", -12, -4, 24, 70, arm)
    # Sartén (mango hacia la mano en el origen) / Frying pan (handle towards the hand at the origin)
    pan = shaded("M-3,0 L3,0 L3,-34 L-3,-34 Z", "#6a4430", shade=0.3, rim=0.3, sw=0.8)
    pan += shaded(ellipse_d(0, -56, 24, 24), "#3a3a52", shade=0.5, rim=0.6, rim_color="#cfd6f6")
    pan += "<path d='%s' fill='#1e1e30'/>" % ellipse_d(0, -56, 17, 17)
    add("chef_pan", -28, -84, 56, 88, pan, colors=10)
    # Cuchillo (apunta a la derecha) / Knife (points right)
    knife = shaded("M-14,-3 L-2,-3 L-2,3 L-14,3 Z", "#4a2e22", shade=0.3, rim=0.3, sw=0.7)
    knife += shaded("M-2,-4 L14,-1 L16,0 L14,1 L-2,4 Z", "#dfe6ff", shade=0.4, rim=0.7, rim_color="#ffffff", sw=0.7)
    add("shot_knife", -17, -6, 35, 12, knife, colors=8)
    plate = shaded(ellipse_d(0, 0, 18, 8), "#f4f1fa", shade=0.4, rim=0.6, deep="#8a84b8")
    plate += "<path d='%s' fill='none' stroke='#5b67c4' stroke-width='1.6'/>" % ellipse_d(0, 0, 12, 5)
    add("shot_plate", -21, -10, 42, 20, plate, colors=8)
    shards_ = ""
    for (x, y, r) in ((-22, -2, 20), (6, -6, -30), (20, 4, 50), (-6, 8, 10), (-30, 8, -60), (28, -8, 80)):
        shards_ += "<g transform='translate(%d,%d) rotate(%d)'>%s</g>" % (x, y, r, shaded("M-6,-3 L6,-4 L2,4 Z", "#f4f1fa", shade=0.3, rim=0.6, sw=0.7))
    add("plate_shards", -40, -16, 80, 32, shards_, colors=8)


def mr_ad():
    """Mr. Ad: un humanoide cubierto de carteles y anuncios de marcas inventadas de chocolatinas y comida basura.
    Mr. Ad: a humanoid covered in banners and ads for made-up chocolate bar and junk food brands."""
    def txt(x, y, t, size, col, rot=0):
        return ("<text x='%g' y='%g' font-family='Arial Black,Arial' font-weight='900' font-size='%g' fill='%s' "
                "text-anchor='middle' transform='rotate(%g %g %g)'>%s</text>" % (x, y, size, col, rot, x, y, t))
    b = ""
    # Mástil con banderín a la espalda / Pole with a pennant on his back
    b += "<path d='M138,40 L138,150' stroke='#cfc8ec' stroke-width='4'/>"
    b += shaded("M138,40 L186,52 L138,66 Z", "#ff4f8a", shade=0.3, rim=0.4, sw=0.8, extra=txt(156, 58, "2x1", 11, "#fff6c9"))
    # Piernas con calcetines de rayas y pegatinas / Legs with striped socks and stickers
    for x in (80, 104):
        b += shaded("M%g,206 L%g,206 L%g,276 L%g,276 Z" % (x, x + 18, x + 18, x), "#f4f1fa", shade=0.4, rim=0.3,
                    extra="".join("<rect x='%g' y='%g' width='18' height='5' fill='%s'/>" % (x, y, c) for y, c in ((222, "#e8455a"), (236, "#3fa8ff"), (250, "#e8455a"))))
        b += shaded(ellipse_d(x + 9, 282, 14, 6), "#f6c24a", shade=0.3, rim=0.4)
    # Brazos envueltos en tiras de publicidad / Arms wrapped in advert strips
    for (pts, col, word) in (("M52,108 L68,104 L74,182 L56,184 Z", "#3fc1c9", "YUM!"), ("M148,108 L132,104 L126,182 L144,184 Z", "#f6c24a", "SODAX")):
        b += shaded(pts, col, shade=0.4, rim=0.4, sw=0.9)
    b += txt(64, 146, "YUM!", 10, "#1a1a3a", -86) + txt(137, 146, "SODAX", 10, "#1a1a3a", 86)
    b += shaded(ellipse_d(64, 190, 8, 8), "#e8c4a8", shade=0.3, rim=0.3, sw=0.8) + shaded(ellipse_d(136, 190, 8, 8), "#c2a092", shade=0.3, rim=0.2, sw=0.8)
    # Cartel-sándwich: el cuerpo entero es un anuncio / Sandwich board: the whole body is an ad
    b += shaded("M66,98 L134,98 L140,212 L60,212 Z", "#e8455a", shade=0.45, rim=0.4, sw=1.2)
    b += "<rect x='70' y='104' width='60' height='22' fill='#fff6c9'/>" + txt(100, 121, "CHOCO", 15, "#7a2e1a") 
    b += txt(100, 140, "LOCO", 16, "#fff6c9")
    # Chocolatina dibujada / Drawn chocolate bar
    b += shaded("M78,150 L122,150 L122,176 L78,176 Z", "#6a3a22", shade=0.3, rim=0.3, sw=0.8,
                extra="<path d='M92,150 L92,176 M107,150 L107,176 M78,163 L122,163' stroke='#4a2414' stroke-width='2'/>")
    b += shaded("M74,170 L126,170 L126,186 L74,186 Z", "#f6c24a", shade=0.3, rim=0.4, sw=0.8)
    b += txt(100, 204, "¡NUEVO!", 11, "#fff6c9")
    # Pegatinas sueltas / Loose stickers
    b += shaded(ellipse_d(132, 112, 10, 10), "#9be38a", shade=0.2, rim=0.4, sw=0.7, extra=txt(132, 116, "%", 11, "#1a3a1a"))
    b += "<g transform='rotate(-14 70 196)'>" + shaded(rect_d(56, 190, 28, 12), "#3fa8ff", shade=0.2, rim=0.3, sw=0.6) + txt(70, 199, "MEGA", 8, "#fff") + "</g>"
    # Cabeza: bolsa de papel de patatas con agujeros para los ojos y gorra con logo
    # Head: a crisps paper bag with eye holes and a cap with a logo
    b += shaded("M76,40 L124,40 L128,96 L72,96 Z", "#f6c24a", shade=0.45, rim=0.4, sw=1.1)
    b += "<path d='M76,96 L80,90 L84,96 L88,90 L92,96 L96,90 L100,96 L104,90 L108,96 L112,90 L116,96 L120,90 L124,96 L128,96' fill='none' stroke='#c9902a' stroke-width='2'/>"
    b += txt(100, 86, "PAPAS", 11, "#c9475a")
    b += shaded("M72,42 Q100,20 128,42 L128,48 L72,48 Z", "#3fa8ff", shade=0.3, rim=0.4, sw=0.9) + shaded("M118,46 L146,50 L142,56 L118,52 Z", "#2a7fd0", shade=0.3, rim=0.3, sw=0.8)
    b += txt(100, 44, "BURGUIX", 8, "#fff6c9")
    for ex in (89, 111):
        b += "<path d='%s' fill='#1a1020'/>" % ellipse_d(ex, 62, 6, 5)
    b += "<path d='M88,74 Q100,82 112,74' fill='none' stroke='#7a2e1a' stroke-width='2.4'/>"
    def eyes(img, to_px):
        pix = img.load()
        w, h = img.size
        for ex in (89, 111):
            x, y = to_px(ex, 62)
            x, y = int(x), int(y)
            if 0 <= x < w and 0 <= y < h:
                pix[x, y] = (255, 255, 255, 255)
    add("npc_ad", 46, 16, 144, 276, b, px=PX_NPC, colors=32, post=eyes)


def pinche():
    """El Pinche: un chaval aprendiz de cocina con gorro de papel, chaquetilla, pantalón de cuadros,
    un cuchillo en una mano y un soplete de cocina en la otra.
    The Kitchen Boy: a young kitchen apprentice with a paper hat, chef jacket, check trousers,
    a knife in one hand and a kitchen blowtorch in the other."""
    skin, shade_c, white = "#f0c8a8", "#c9a090", "#f4f1fa"
    b = ""
    # Pantalón de cuadros de cocina / Kitchen check trousers
    for x in (82, 102):
        checks = "".join("<rect x='%g' y='%g' width='4' height='4' fill='#1e1f2e' opacity='0.7'/>" % (x + dx, y)
                         for y in range(190, 272, 8) for dx in ((0, 8) if (y // 8) % 2 == 0 else (4, 12)))
        b += shaded("M%g,186 L%g,186 L%g,274 L%g,274 Z" % (x, x + 16, x + 16, x), "#e9e6f2", shade=0.4, rim=0.3, extra=checks)
        b += shaded(ellipse_d(x + 8, 282, 12, 6), "#2a2238", shade=0.3, rim=0.4)
    # Chaquetilla blanca y delantal de rayas / White jacket and striped apron
    b += shaded("M80,96 L120,96 L140,108 L138,196 L62,196 L60,108 Z", white, shade=0.5, rim=0.3, deep="#8a84b8")
    for y in (116, 132, 148):
        b += "<circle cx='92' cy='%d' r='2.6' fill='#2b2945'/><circle cx='108' cy='%d' r='2.6' fill='#2b2945'/>" % (y, y)
    stripes = "".join("<rect x='%g' y='150' width='4' height='60' fill='#ffffff' opacity='0.55'/>" % x for x in range(70, 132, 9))
    b += shaded("M68,150 L132,150 L134,210 L66,210 Z", "#4f7fd0", shade=0.4, rim=0.3, extra=stripes)
    b += "<path d='M68,150 L132,150' stroke='#2f5fae' stroke-width='3'/>"
    # Pañuelo rojo al cuello / Red neckerchief
    b += shaded("M86,96 L114,96 L100,112 Z", "#e2434f", shade=0.3, rim=0.3, sw=0.8)
    # Brazos / Arms
    b += shaded("M60,108 L74,112 L72,170 L58,168 Z", white, shade=0.4, rim=0.3, deep="#8a84b8")
    b += shaded("M140,108 L126,112 L130,160 L144,156 Z", "#d8d4ea", shade=0.4, rim=0.2, deep="#8a84b8")
    # Cuchillo en la mano izquierda (nuestra izquierda) / Knife in the left hand
    b += shaded("M62,178 L68,178 L68,196 L62,196 Z", "#4a2e22", shade=0.3, rim=0.3, sw=0.7)
    b += shaded("M61,178 L69,178 L67,148 Q64,142 62,150 Z", "#dfe6ff", shade=0.4, rim=0.7, rim_color="#ffffff", sw=0.7)
    b += shaded(ellipse_d(65, 176, 7, 7), skin, shade=0.3, rim=0.3, sw=0.8)
    # Soplete de cocina en la derecha / Kitchen blowtorch in the right hand
    b += shaded("M132,150 L150,150 L150,176 L132,176 Z", "#e2434f", shade=0.4, rim=0.4, sw=0.8)
    b += shaded("M136,140 L146,140 L146,150 L136,150 Z", "#3a3a52", shade=0.3, rim=0.4, sw=0.7)
    b += shaded("M140,132 L160,128 L160,134 L142,140 Z", "#8f8fb8", shade=0.3, rim=0.5, sw=0.7)
    b += shaded(ellipse_d(138, 160, 7, 7), shade_c, shade=0.3, rim=0.2, sw=0.8)
    # Cuello y cabeza / Neck and head
    b += shaded("M93,82 L107,82 L107,98 L93,98 Z", shade_c, shade=0.3, rim=0.1, outline=False)
    b += shaded(ellipse_d(100, 62, 22, 25), skin, shade=0.45, rim=0.4)
    # Pecas / Freckles
    for (fx, fy) in ((88, 72), (91, 75), (110, 72), (113, 75)):
        b += "<circle cx='%d' cy='%d' r='1.2' fill='#c47a5a'/>" % (fx, fy)
    # Pelo pelirrojo revuelto asomando del gorro / Messy red hair poking out of the hat
    b += shaded("M77,58 Q76,40 90,36 L112,36 Q126,40 124,58 L118,48 L110,52 L104,46 L96,52 L88,46 L82,54 Z", "#c8622e", shade=0.4, rim=0.5, sw=0.8)
    # Gorro de papel / Paper hat
    b += shaded("M76,42 L124,42 L120,20 L80,20 Z", white, shade=0.4, rim=0.4, deep="#8a84b8",
                extra="<path d='M78,34 L122,34' stroke='#cfcbe2' stroke-width='1.5'/>")
    add("npc_pinche", 50, 14, 116, 278, b, px=PX_NPC, colors=32, post=npc_face(62, "#2a1d22", 1))


def act2_npcs():
    charo_body(False)
    charo_body(True)
    charo_kiosk(PX_KROKER, "charo_kiosk")
    charo_kiosk(PX_NPC, "npc_kiosk")


# --- Render ---------------------------------------------------------------------

def build():
    for o in PAJAMAS:
        kroker_leg(o, 0)
        kroker_leg(o, 1)
        kroker_arm(o, 0)
        kroker_arm(o, 1)
        kroker_torso(o)
    kroker_head()
    kroker_weapons()
    foox()
    boss()
    shots()
    npcs()
    room()
    living_room()
    act2_npcs()
    act2_enemies()
    cyberpunk()
    chef()
    mr_ad()
    pinche()
    drawings()
    pickups()
    thug()
    sling()
    skeleton()


def pixelize(img, tw, th, colors, ghost):
    """Reduce a pixel art: paleta corta, transparencia dura y contorno de 1 píxel.
    Reduces to pixel art: short palette, hard transparency and a 1-pixel outline."""
    from PIL import Image
    small = img.resize((tw, th), Image.BOX)
    alpha = small.getchannel("A")
    rgb = Image.new("RGB", small.size, (0, 0, 0))
    rgb.paste(small.convert("RGB"), mask=alpha.point(lambda v: 255 if v > 20 else 0))
    q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    px, ap, op = q.load(), alpha.load(), out.load()
    for yy in range(th):
        for xx in range(tw):
            a = ap[xx, yy]
            if ghost:
                a = 0 if a < 40 else (150 if a < 170 else 230)
            else:
                a = 0 if a < 110 else 255
            if a:
                op[xx, yy] = px[xx, yy] + (a,)
    # Contorno oscuro del color de al lado (o claro en los fantasmas)
    # Dark outline in the neighbour's colour (or light for ghosts)
    src = out.copy()
    sp = src.load()
    for yy in range(th):
        for xx in range(tw):
            if sp[xx, yy][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = xx + dx, yy + dy
                if 0 <= nx < tw and 0 <= ny < th and sp[nx, ny][3]:
                    c = sp[nx, ny]
                    if ghost:
                        op[xx, yy] = (169, 188, 255, 120)
                    else:
                        op[xx, yy] = (int(c[0] * 0.25 + 10), int(c[1] * 0.22 + 6), int(c[2] * 0.3 + 26), 255)
                    break
    return out


def render(only=None):
    from playwright.sync_api import sync_playwright
    from PIL import Image
    import io
    os.makedirs(OUT, exist_ok=True)
    rects = {}
    with sync_playwright() as p:
        browser = p.chromium.launch()
        pages = {}
        for name, sp in SPRITES.items():
            sx, sy, tx, ty = sp["xf"]
            px = sp["px"]
            pad = 1.5 / px
            # Rectángulo final ya transformado y con margen / Final rectangle, transformed and padded
            x0 = sp["x"] * sx + tx - pad
            y0 = sp["y"] * sy + ty - pad
            w = sp["w"] * sx + pad * 2
            h = sp["h"] * sy + pad * 2
            tw, th = max(1, round(w * px)), max(1, round(h * px))
            rects[name] = (x0, y0, tw / px, th / px)
            if only and name not in only:
                continue
            dsf = px * SUPER
            if dsf not in pages:
                pages[dsf] = browser.new_page(device_scale_factor=dsf)
            page = pages[dsf]
            vw, vh = tw / px, th / px
            svg = ("<svg xmlns='http://www.w3.org/2000/svg' width='%g' height='%g' viewBox='%g %g %g %g'>"
                   "<defs>%s</defs><g transform='matrix(%g,0,0,%g,%g,%g)'>%s</g></svg>"
                   % (vw, vh, x0, y0, vw, vh, FILTERS, sx, sy, tx, ty, sp["body"]))
            page.set_viewport_size({"width": int(math.ceil(vw)) + 2, "height": int(math.ceil(vh)) + 2})
            page.set_content("<html><body style='margin:0;background:transparent'>%s</body></html>" % svg)
            hi = Image.open(io.BytesIO(page.locator("svg").screenshot(omit_background=True))).convert("RGBA")
            if sp["flat"]:
                import re as _re
                palette = sorted(set(c.lower() for c in _re.findall(r"(?:fill|stroke)='(#[0-9a-fA-F]{6})'", sp["body"])))
                img = flat_pixelize(hi, tw, th, palette, sp["outline"])
            else:
                img = pixelize(hi, tw, th, sp["colors"], sp["ghost"])
            if sp["post"]:
                sp["post"](img, lambda X, Y, sx=sx, sy=sy, tx=tx, ty=ty, x0=x0, y0=y0, px=px: ((X * sx + tx - x0) * px, (Y * sy + ty - y0) * px))
            img.save(os.path.join(OUT, name + ".png"))
        browser.close()
    with open(RECTS, "w") as f:
        f.write("class_name SpriteRects\n## Generado por tools/make_sprites.py: no editar a mano.\n"
                "## Generated by tools/make_sprites.py: do not edit by hand.\n"
                "## Rectángulo de cada sprite en las coordenadas del dibujo / Each sprite's rectangle in drawing coordinates\n\n"
                "const RECTS := {\n")
        for name in sorted(rects):
            x, y, w, h = rects[name]
            f.write("\t\"%s\": Rect2(%.3f, %.3f, %.3f, %.3f),\n" % (name, x, y, w, h))
        f.write("}\n")
    print("%d sprites" % len(rects))


if __name__ == "__main__":
    build()
    render(sys.argv[1:] or None)
