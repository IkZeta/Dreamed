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
PX_KROKER = 0.55 / 2.0
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


def add(name, x, y, w, h, body, xf=(1, 1, 0, 0), px=PX_ENEMY, colors=12, ghost=False, post=None):
    """xf = (sx, sy, tx, ty): escala y mueve la pieza (para hacer a Kroker más bajito).
    xf = (sx, sy, tx, ty): scales and moves the piece (to make Kroker shorter)."""
    SPRITES[name] = dict(x=x, y=y, w=w, h=h, body=body, xf=xf, px=px, colors=colors, ghost=ghost, post=post)


## Kroker es un niño bajito: la cabeza no cambia, pero el torso, los brazos y las piernas
## son más cortos. Todo lo que está por encima de la cadera baja 48 unidades.
## Kroker is a short kid: the head stays the same, but the torso, arms and legs are shorter.
## Everything above the hips moves down 48 units.
DROP = 48
XF_HEAD = (1, 1, 0, DROP)
XF_TORSO = (1, 0.75, 0, 98 + DROP - 0.75 * 98)
XF_ARM = (1, 0.75, 0, 106 + DROP - 0.75 * 106)
XF_LEG = (1, 0.68, 0, 288 - 0.68 * 288)


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
                            put(ex + gx, ey + gy, (min(255, r + 10), min(255, g + 14), min(255, b + 26), 255))
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
    hood, dark_h, skin = "#7a3a58", "#5a2742", "#b9a3c9"
    body = "M-30,-104 Q0,-110 30,-104 Q40,-98 40,-88 L36,-42 Q0,-38 -36,-42 L-40,-88 Q-40,-98 -30,-104 Z"
    b = shaded(body, hood, shade=0.55, rim=0.4,
               extra=fold("M-20,-80 Q-24,-64 -18,-50", hood, 3, 0.4) + fold("M18,-84 Q24,-66 20,-50", hood, 3, 0.4))
    b += shaded("M-18,-66 L18,-66 Q20,-52 16,-48 L-16,-48 Q-20,-52 -18,-66 Z", dark(hood, 0.1), shade=0.4, rim=0.2, sw=0.8)
    b += "<path d='M-6,-104 L-8,-82 M6,-104 L8,-80' stroke='#e9d6e4' stroke-width='1.6' stroke-linecap='round' opacity='0.8'/>"
    b += "<circle cx='-8' cy='-81' r='1.8' fill='#e9d6e4'/><circle cx='8' cy='-79' r='1.8' fill='#e9d6e4'/>"
    b += shaded("M-36,-50 Q0,-46 36,-50 L36,-42 Q0,-38 -36,-42 Z", dark_h, shade=0.3, rim=0.2, sw=0.8)
    add("thug_body", -44, -112, 88, 74, b)
    head = shaded(ellipse_d(0, -124, 27, 26), dark_h, shade=0.5, rim=0.45, sw=1)
    head += shaded(ellipse_d(0, -120, 19, 19), mix(skin, "#3a2a50", 0.45), shade=0.6, rim=0.15, deep="#1a1030", sw=0.8)
    head += "<path d='M-19,-128 Q0,-142 19,-128' fill='none' stroke='%s' stroke-width='3' opacity='0.7'/>" % light(dark_h, 0.15)
    add("thug_head", -30, -153, 60, 56, head)
    fist = shaded("M-10,0 C-10,-7 -5,-11 0,-11 C6,-11 10,-7 10,0 C10,7 6,10 0,10 C-6,10 -10,6 -10,0 Z", skin, shade=0.45, rim=0.4)
    for x in (-4, 1, 6):
        fist += "<path d='M%d,-9 L%d,-3' stroke='%s' stroke-width='0.9' opacity='0.6'/>" % (x, x - 1, dark(skin, 0.35))
    add("thug_fist", -13, -14, 26, 27, fist)
    leg = shaded("M-11,-44 L11,-44 L9,-8 Q0,-5 -9,-8 Z", dark_h, shade=0.5, rim=0.3)
    add("thug_leg", -14, -47, 28, 44, leg)


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
