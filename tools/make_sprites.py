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


## Con FLAT_SHADED activo, "shaded" dibuja en pixel art plano: color base, una franja de sombra
## dura abajo a la derecha, un filo de luz arriba a la izquierda y un borde interior de 1 píxel.
## Se usa en los decorados, que son muchas piezas. / With FLAT_SHADED on, "shaded" draws in flat
## pixel art: base colour, a hard shadow band bottom-right, a light edge top-left and a 1-pixel
## inner border. It's used for the sets, which have lots of pieces.
FLAT_SHADED = False
FLAT_SW = 2.8


def shaded(d, base, outline=True, shade=0.42, rim=0.5, grad=True, extra="", deep=None, sw=1.1, rim_color="#dfe6ff"):
    """Forma con degradado, sombra interior abajo a la derecha y luz de luna arriba a la izquierda.
    Shape with gradient, inner shadow bottom-right and moonlight top-left."""
    i = uid()
    deep = deep or dark(base, 0.5)
    if FLAT_SHADED:
        out = ["<defs><clipPath id='c%s'><path d='%s'/></clipPath></defs>" % (i, d), "<path d='%s' fill='%s'/>" % (d, base),
               "<g clip-path='url(#c%s)'>" % i, extra,
               "<path d='%s%s' transform='translate(-6,-5)' fill-rule='evenodd' fill='%s'/>" % (BIG, d, mix(base, deep, min(0.75, shade * 1.1)))]
        if rim > 0:
            out.append("<path d='%s%s' transform='translate(3.5,3.5)' fill-rule='evenodd' fill='%s'/>" % (BIG, d, mix(base, rim_color, min(0.6, rim * 0.7))))
        out.append("</g>")
        if outline:
            out.append("<path d='%s' fill='none' stroke='%s' stroke-width='%.2f' stroke-linejoin='round'/>" % (d, dark(base, 0.55), FLAT_SW))
        return "".join(out)
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
    if outline is None:
        return out   # piezas que se repiten sin costuras / pieces that tile seamlessly
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
    """Estampado del pijama en pixel art: motivos opacos y gorditos (Kroker se dibuja muy pequeño,
    así que cada motivo mide al menos un píxel y medio), recortados a la forma "d".
    Pajama print in pixel art: opaque, chunky motifs (Kroker is drawn very small, so each motif
    is at least a pixel and a half), clipped to the shape "d"."""
    i = uid()
    col = pj["pattern"]
    kind = pj["print"]
    if kind == "stripes":
        pat = "<pattern id='p%s' patternUnits='userSpaceOnUse' width='13' height='9'><rect x='4' y='0' width='4.4' height='9' fill='%s'/></pattern>" % (i, col)
    elif kind == "plaid":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='18' height='22'>"
               "<rect x='0' y='7' width='18' height='7' fill='%s'/><rect x='7' y='0' width='4.6' height='22' fill='%s'/></pattern>" % (i, col, col))
    elif kind == "stars":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='18' height='28'>"
               "<path d='M5,3 L8,9 L5,15 L2,9 Z M14,17 L17,23 L14,29 L11,23 Z M14,-11 L17,-5 L14,1 L11,-5 Z' fill='%s'/></pattern>" % (i, col))
    elif kind == "bolts":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='18' height='26'>"
               "<path d='M3,18 L11,4' stroke='%s' stroke-width='4.4'/><rect x='12' y='16' width='4.4' height='7' fill='#7ff5ff'/></pattern>" % (i, col))
    elif kind == "paws":
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='18' height='26'>"
               "<ellipse cx='6' cy='9' rx='4' ry='4.5' fill='%s'/><ellipse cx='15' cy='22' rx='3' ry='3.6' fill='%s'/></pattern>" % (i, col, col))
    else:  # dots
        pat = ("<pattern id='p%s' patternUnits='userSpaceOnUse' width='16' height='24'>"
               "<ellipse cx='4' cy='5' rx='3' ry='4.2' fill='%s'/><ellipse cx='12' cy='17' rx='3' ry='4.2' fill='%s'/></pattern>" % (i, col, col))
    return "<defs>%s<clipPath id='k%s'><path d='%s'/></clipPath></defs><rect clip-path='url(#k%s)' x='0' y='0' width='300' height='400' fill='url(#p%s)'/>" % (pat, i, d, i, i)


def clipped(d, inner):
    """Dibuja "inner" recortado a la forma "d" / Draws "inner" clipped to the shape "d"."""
    i = uid()
    return "<defs><clipPath id='k%s'><path d='%s'/></clipPath></defs><g clip-path='url(#k%s)'>%s</g>" % (i, d, i, inner)


def fold(d, base, w=2.2, op=0.35):
    return "<path d='%s' fill='none' stroke='%s' stroke-width='%.1f' stroke-linecap='round' opacity='%.2f' filter='url(#b1)'/>" % (
        d, dark(base, 0.45), w, op)


def kroker_leg(outfit, side):
    """Pierna del pijama en pixel art plano, con estampado, puño de ribete y zapatilla mullida.
    Pajama leg in flat pixel art, with the print, a piped cuff and a fluffy slipper."""
    pj = PAJAMAS[outfit]
    base = dark(pj["base"], 0.0 if side == 0 else 0.1)
    dx = 0 if side == 0 else 25
    leg = "M%d,170 L%d,170 Q%d,222 %d,268 L%d,268 Q%d,222 %d,170 Z" % (
        77 + dx, 98 + dx, 100 + dx, 98 + dx, 77 + dx, 75 + dx, 77 + dx)
    body = flat(leg, base) + pattern_fill(pj, leg)
    # Sombra del lado de dentro / Shade on the inner side
    body += clipped(leg, flat("M%d,160 L%d,160 L%d,280 L%d,280 Z" % (92 + dx, 104 + dx, 104 + dx, 92 + dx), dark(base, 0.3)))
    cuff = "M%d,262 L%d,262 L%d,274 L%d,274 Z" % (76 + dx, 99 + dx, 99 + dx, 76 + dx)
    body += flat(cuff, pj["piping"])
    cx = 87.5 + dx
    slip = "M%.1f,284 C%.1f,274 %.1f,273 %.1f,277 C%.1f,275 %.1f,279 %.1f,284 C%.1f,291 %.1f,291 %.1f,284 Z" % (
        cx - 16, cx - 14, cx - 2, cx + 2, cx + 10, cx + 17, cx + 16, cx + 12, cx - 12, cx - 16)
    body += flat(slip, pj["slippers"])
    body += clipped(slip, flat("M%.1f,284 L%.1f,284 L%.1f,292 L%.1f,292 Z" % (cx - 20, cx + 20, cx + 20, cx - 20), dark(pj["slippers"], 0.3)))
    body += flat("M%.1f,276 L%.1f,276 L%.1f,280 L%.1f,280 Z" % (cx - 8, cx + 4, cx + 4, cx - 8), light(pj["slippers"], 0.35))
    add("kroker_leg_%s_%s" % ("l" if side == 0 else "r", outfit), 66 + dx, 166, 40, 128, body, XF_LEG, PX_KROKER, flat=True)


def mirror_x(d):
    """Refleja una ruta (pares x,y absolutos) respecto a x = 100 / Mirrors a path (absolute x,y pairs) about x = 100."""
    import re
    return re.sub(r"(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)", lambda m: "%g,%s" % (200 - float(m.group(1)), m.group(2)), d)


def kroker_arm(outfit, side):
    """Brazo del pijama en pixel art plano (manga con estampado, puño y mano).
    Pajama arm in flat pixel art (printed sleeve, cuff and hand)."""
    pj = PAJAMAS[outfit]
    base = dark(pj["base"], 0.0 if side == 0 else 0.1)
    sleeve = "M68,104 Q77,100 82,110 L79,178 Q71,182 63,180 L64,140 Q65,118 68,104 Z"
    cuff = "M63.4,170 L79.4,170 L79,180 Q71,182.5 63,180 Z"
    hand = "M62,188 C62,181 66,179 70,179 C75,179 78,182 78,188 C78,195 74,197 70,197 C65,197 62,194 62,188 Z"
    shade = "M75,100 L90,100 L90,190 L75,190 Z"
    skin = SKIN if side == 0 else mix(SKIN, SKIN_SHADE, 0.4)
    if side == 1:
        sleeve, cuff, hand, shade = mirror_x(sleeve), mirror_x(cuff), mirror_x(hand), mirror_x(shade)
    body = flat(hand, skin)
    body += flat(sleeve, base) + pattern_fill(pj, sleeve)
    body += clipped(sleeve, flat(shade, dark(base, 0.3)))
    body += flat(cuff, pj["piping"])
    add("kroker_arm_%s_%s" % ("l" if side == 0 else "r", outfit), 56 if side == 0 else 112, 96, 32, 104, body, XF_ARM, PX_KROKER, flat=True)


def kroker_torso(outfit):
    """Torso del pijama en pixel art plano: camisa con estampado, solapas con ribete, botones y
    bajo con ribete. / Pajama torso in flat pixel art: printed shirt, piped lapels, buttons and a piped hem."""
    pj = PAJAMAS[outfit]
    base = pj["base"]
    pip = pj["piping"]
    body = flat("M92,84 L108,84 L108,102 L92,102 Z", mix(SKIN, SKIN_SHADE, 0.45))
    shirt = "M84,98 Q100,101 116,98 Q129,101 132,108 L134,176 Q100,181 66,176 L68,108 Q71,101 84,98 Z"
    body += flat(shirt, base) + pattern_fill(pj, shirt)
    body += clipped(shirt, flat("M120,90 L140,90 L140,190 L120,190 Z", dark(base, 0.3)) + flat("M60,90 L74,90 L74,190 L60,190 Z", light(base, 0.12)))
    # Solapas con ribete / Piped lapels
    body += clipped(shirt, flat("M93,96 L107,96 L107,182 L93,182 Z", base))
    body += flat("M86,96 L100,99 L100,122 L90,110 Z", light(base, 0.15)) + flat("M114,96 L100,99 L100,122 L110,110 Z", dark(base, 0.15))
    body += "<path d='M85,96 L90,110 L100,123 L110,110 L115,96' fill='none' stroke='%s' stroke-width='4' stroke-linejoin='round'/>" % pip
    for y in (140, 160):
        body += flat(ellipse_d(100, y, 2.6, 4), pip)
    body += flat("M66,172 Q100,177 134,172 L134,180 Q100,185 66,180 Z", pip)
    add("kroker_torso_%s" % outfit, 60, 80, 80, 104, body, XF_TORSO, PX_KROKER, flat=True)


def kroker_head():
    """Cabeza de Kroker en pixel art plano: cara redonda, orejas, coloretes y pelo negro con un
    mechón de punta y reflejos azulados. Los ojos, las gafas y la boca se pintan píxel a píxel.
    Kroker's head in flat pixel art: a round face, ears, blush and black hair with a spiky tuft
    and bluish highlights. The eyes, glasses and mouth are painted pixel by pixel."""
    SK, SK1, BLUSH = SKIN, "#d8aaa6", "#f0a4ae"
    H1, H2, H3 = "#0c0b14", HAIR, "#3b4475"
    body = ""
    for cx, col in ((76, SK), (124, SK1)):
        body += flat(ellipse_d(cx, 68, 6, 8), col)
    face = "M76,62 C76,44 88,37 100,37 C112,37 124,44 124,62 C124,80 113,91 100,91 C87,91 76,80 76,62 Z"
    body += flat(face, SK)
    body += clipped(face, flat("M112,40 C122,48 126,60 124,72 C121,84 112,91 100,92 L100,96 L130,96 L130,40 Z", SK1))
    body += flat(ellipse_d(86, 78, 4.4, 3), BLUSH) + flat(ellipse_d(114, 78, 4.4, 3), BLUSH)
    hair = ("M75,70 C70,55 73,42 83,35 C91,29 108,27 117,32 C126,37 130,51 126,70 C124,62 121,57 117,55 "
            "C114,60 110,60 107,53 C103,59 97,60 94,52 C90,58 85,58 81,54 C78,58 76,63 75,70 Z")
    body += flat("M99,34 C98,27 103,24 110,26 C106,28 105,31 107,34 Z", H2)
    body += flat(hair, H2)
    body += clipped(hair, flat("M116,28 C128,36 132,52 128,72 L140,72 L140,20 Z", H1))
    body += "<path d='M81,48 C85,41 91,37 99,35' fill='none' stroke='%s' stroke-width='4.4'/>" % H3
    head = body
    # La cara va pintada en la cabeza: ojos abiertos o cerrados, gafas o no, y bostezo
    # The face is painted onto the head: eyes open or closed, glasses or not, and yawning
    for suffix, e, m in (("", "open", "smile"), ("_blink", "closed", "smile"), ("_yawn", "closed", "yawn")):
        add("kroker_head" + suffix, 64, 18, 72, 78, head, XF_HEAD, PX_KROKER, 14, post=face_painter(e, m, False), flat=True)
        add("kroker_head" + suffix + "_g", 64, 18, 72, 78, head, XF_HEAD, PX_KROKER, 14, post=face_painter(e, m, True), flat=True)




def kroker_weapons():
    """Armas de Kroker en pixel art plano (se dibujan muy pequeñas: los detalles miden al menos
    un píxel y medio). / Kroker's weapons in flat pixel art (drawn very small: details are at
    least a pixel and a half)."""
    # Bate de madera con cinta en el mango y una estrella / Wooden bat with grip tape and a star
    bat = "M-3,4 L3,4 C5,-40 8,-80 8,-96 C8,-104 5,-109 0,-109 C-5,-109 -8,-104 -8,-96 C-8,-80 -5,-40 -3,4 Z"
    b = flat(bat, "#c99a68")
    b += clipped(bat, flat("M2,-112 L12,-112 L12,6 L2,6 Z", "#8a5d3c") + flat("M-10,-112 L-4,-112 L-4,6 L-10,6 Z", "#f0cb9a"))
    b += flat("M-4.4,-20 L4.4,-20 L4,6 L-4,6 Z", "#3a3355")
    b += "".join(flat("M-4.4,%d L4.4,%d L4.4,%d L-4.4,%d Z" % (y, y - 4, y - 1, y + 3), "#6b6394") for y in (-12, -2))
    b += flat(ellipse_d(0, 6, 6, 3.4), "#2b2545")
    b += flat(star_d(0, -86, 5, inner=0.5), "#f6d993")
    add("weapon_bat", -12, -113, 24, 122, b, px=PX_KROKER, flat=True)

    # Almohada / Pillow
    pts = []
    for k in range(64):
        a = math.tau * k / 64
        c, s_ = math.cos(a), math.sin(a)
        p_ = (math.copysign(abs(c) ** 0.6, c) * 36, math.copysign(abs(s_) ** 0.6, s_) * 26)
        f = 1 - 0.07 * abs(math.sin(a * 2))
        pts.append("%.2f,%.2f" % (p_[0] * f, p_[1] * f))
    pil = "M" + " L".join(pts) + " Z"
    p = flat(pil, "#ece7fa")
    p += clipped(pil, flat("M-40,10 Q0,4 40,10 L40,40 L-40,40 Z", "#c4bbe8") + flat("M-34,-26 L-10,-26 L-10,-18 L-34,-14 Z", "#ffffff"))
    p += flat(star_d(-2, -2, 9, inner=0.5), "#f6d993")
    add("weapon_pillow", -42, -32, 84, 64, p, px=PX_KROKER, flat=True)

    # Libro de cuentos abierto / Open storybook
    bk = flat("M-29,-14 Q-14,-12 0,-9 L0,16 Q-14,13 -29,12 Z", "#3b4fa8") + flat("M29,-14 Q14,-12 0,-9 L0,16 Q14,13 29,12 Z", "#2c3c88")
    bk += flat("M-25,-11 Q-12,-9.5 -1,-6.5 L-1,12 Q-12,10 -25,9 Z", "#fbf3dc") + flat("M25,-11 Q12,-9.5 1,-6.5 L1,12 Q12,10 25,9 Z", "#e6d8b4")
    bk += flat("M3,-6 L9,-6 L9,22 L6,18 L3,22 Z", "#e3a6c4")
    add("weapon_book", -32, -18, 64, 42, bk, px=PX_KROKER, flat=True)

    # Depósito y boquilla del Barrepesadillas / Nightmare Sweeper tank and nozzle
    tk = ellipse_d(150, 252, 22, 30)
    tank = flat(tk, "#e3ddf0") + clipped(tk, flat("M158,210 L180,210 L180,290 L158,290 Z", "#a8a2cc"))
    tank += flat(ellipse_d(148, 244, 11, 13), "#8fd6cf") + flat(ellipse_d(152, 248, 7, 9), "#5fb0a8")
    tank += flat("M141,236 L148,233 L149,238 L143,241 Z", "#ffffff")
    tank += "<path d='M138,228 Q150,218 162,228' fill='none' stroke='#4a4f86' stroke-width='5'/>"
    for cx in (136, 164):
        tank += flat(ellipse_d(cx, 280, 6, 6), "#3b3f73") + flat(ellipse_d(cx, 280, 2.4, 2.4), "#b7b2d6")
    add("weapon_tank", 124, 216, 52, 72, tank, px=PX_KROKER, flat=True)
    noz = flat("M-4,-6.5 L10,-11.5 Q13,-11 13,-8 L13,8 Q13,11 10,11.5 L-4,6.5 Z", "#4a4f86")
    noz += flat("M-4,1 L13,3 L13,8 Q13,11 10,11.5 L-4,6.5 Z", "#33376a")
    noz += flat("M10,-10 L14,-10 L14,10 L10,10 Z", "#b9f0ea")
    add("weapon_nozzle", -7, -14, 24, 28, noz, px=PX_KROKER, flat=True)

    # Pistola de dedos: puño redondeado, pulgar recto hacia arriba e índice apuntando (origen en el
    # centro del puño, el índice hacia +x). Una versión para Kroker y otra más fina para los iconos.
    # Finger gun: rounded fist, thumb straight up and index finger pointing (origin at the fist's
    # centre, index towards +x). One version for Kroker and a finer one for the icons.
    hand = ("M-3,-6 L-3,-14 Q-3,-17 -0.5,-17 Q2,-17 2,-14 L2,-6 L15.5,-6 Q18.5,-6 18.5,-3 Q18.5,0 15.5,0 "
            "L10,0 L10,6 Q10,13 3,13 L-5,13 Q-10,13 -10,7 L-10,-3 Q-10,-6 -7,-6 Z")
    fh = flat(hand, "#ecc2aa") + clipped(hand, flat("M-12,6 L12,6 L12,16 L-12,16 Z", "#c4957f"))
    add("weapon_finger", -13, -20, 34, 36, fh, px=PX_KROKER * 1.6, flat=True)
    fi = fh + "<path d='M10,0 Q6,2 2,0.5 M2,-6 L2,-2' fill='none' stroke='#c4957f' stroke-width='1.4'/>"
    add("icon_finger", -13, -20, 34, 36, fi, px=1.25, flat=True)

    # Osito de peluche con una costura abierta por la que asoma pelusa (centrado en la mano)
    # Teddy bear with an open seam with fluff poking out (centred on the hand)
    BR, BR1, BR2, MZ = "#c99a78", "#a87a5c", "#e8c9a8", "#3a2a30"
    t = ""
    for x in (-15, 15):
        t += flat(ellipse_d(x, 27, 8.5, 8.5), BR1)
    bel = ellipse_d(0, 12, 18, 20)
    t += flat(bel, BR) + clipped(bel, flat("M8,-10 L22,-10 L22,34 L8,34 Z", BR1)) + flat(ellipse_d(-1, 15, 10, 12), BR2)
    t += flat(ellipse_d(1, 13, 6, 6), "#fbf5ea") + flat(ellipse_d(5, 8, 4, 4), "#fbf5ea")
    for x in (-17, 17):
        t += flat(ellipse_d(x, 6, 7, 7), BR1)
    for x in (-12, 12):
        t += flat(ellipse_d(x, -22, 8, 8), BR1 if x > 0 else BR) + flat(ellipse_d(x, -22, 4, 4), BR2)
    hd = ellipse_d(0, -12, 15, 15)
    t += flat(hd, BR) + clipped(hd, flat("M7,-30 L18,-30 L18,4 L7,4 Z", BR1))
    t += flat(ellipse_d(0, -7, 7.5, 5.5), BR2) + flat(ellipse_d(0, -9, 3, 2.6), MZ)
    t += flat(ellipse_d(-6, -15, 2.6, 2.6), MZ) + flat(ellipse_d(6, -15, 2.6, 2.6), MZ)
    t += flat("M0,0 L-9,-5 L-9,5 Z M0,0 L9,-5 L9,5 Z", "#ff5f7a")
    add("weapon_teddy", -26, -32, 52, 66, t, px=PX_KROKER, flat=True)


# --- Enemigos / Enemies --------------------------------------------------------

def foox():
    """Foox en pixel art plano: zorro fantasma con orejas de punta, hocico largo, pechera de pelo y
    la parte de abajo deshilachada en jirones de niebla (no tiene patas). La cola de humo y el
    brillo del ojo se dibujan en el juego.
    Foox in flat pixel art: a ghost fox with pointed ears, a long snout, a fluffy chest and its
    underside frayed into wisps of mist (it has no legs). The smoky tail and the eye glow are
    drawn in game."""
    G3, G2, G1, G0 = "#f6f7ff", "#d9ddf6", "#aeb5e4", "#858dcc"
    EAR, SOCK, NOSE = "#c9a8ec", "#2c3466", "#3d3f7a"
    b = ""
    # Torso con jirones abajo / Torso with wisps underneath
    b += flat("M-22,-18 C-22,-27 -8,-30 4,-30 C16,-30 24,-26 24,-18 C24,-11 20,-7 16,-5 L17,2 L10,-2 "
              "L5,3 L0,-3 L-6,2 L-9,-4 L-16,0 L-15,-8 C-20,-11 -22,-14 -22,-18 Z", G2)
    # Sombra de la barriga / Belly shade
    b += flat("M-21,-14 C-16,-12 -4,-10 8,-10 C16,-10 22,-12 24,-16 C24,-11 20,-7 16,-5 L17,2 L10,-2 "
              "L5,3 L0,-3 L-6,2 L-9,-4 L-16,0 L-15,-8 C-19,-10 -21,-12 -21,-14 Z", G1)
    b += flat("M-4,-4 L0,-3 L5,3 L3,-4 Z M10,-4 L17,2 L15,-5 Z M-14,-3 L-16,0 L-15,-8 L-12,-6 Z", G0)
    # Lomo con brillo / Shiny back
    b += flat("M-16,-24 C-10,-28 2,-29 12,-28 C6,-26 -6,-25 -16,-21 Z", G3)
    add("foox_body", -26, -33, 52, 37, b, ghost=True, flat=True, outline="#4b4f9a")
    h = ""
    # Orejas / Ears
    h += flat("M10,-32 L12,-49 L21,-36 Z", G2) + flat("M23,-36 L28,-50 L32,-31 Z", G1)
    h += flat("M13,-34 L13.5,-44 L18,-36 Z", EAR) + flat("M25,-35 L28,-45 L30,-33 Z", EAR)
    # Cabeza y hocico / Head and snout
    h += flat("M8,-28 C8,-35 14,-38 21,-38 C28,-38 32,-34 33,-30 C38,-28 43,-26 46,-23 "
              "C43,-19 36,-18 30,-18 C24,-15 16,-15 11,-19 C8,-21 8,-25 8,-28 Z", G2)
    h += flat("M33,-30 C38,-28 43,-26 46,-23 C43,-21 38,-21 32,-22 C33,-25 33,-27 33,-30 Z", G1)
    h += flat("M12,-33 C14,-36 18,-37 22,-37 C19,-35 15,-33 12,-30 Z", G3)
    # Mejilla de pelo blanco con mechones / White fluffy cheek with tufts
    h += flat("M12,-22 C16,-25 24,-25 30,-22 C27,-19 24,-17 22,-14 L20,-17 L17,-13 L16,-17 L12,-15 Z", G3)
    # Nariz y cuenca del ojo (el brillo va en el juego) / Nose and eye socket (glow drawn in game)
    h += flat("M42,-25 L47,-24 L46,-21 L42,-22 Z", NOSE)
    h += flat("M20,-29 L29,-30 L29,-25 L21,-26 Z", SOCK)
    add("foox_head", 4, -52, 46, 40, h, ghost=True, flat=True, outline="#4b4f9a")


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
    """Tirachinas en pixel art de verdad (modo flat): un chaval con la gorra roja calada, el pelo
    revuelto asomando, camiseta azul ancha de manga corta, pantalón oscuro y zapatillas. El brazo
    derecho, doblado, sujeta el tirachinas (que se pinta en el juego).
    Slingshot kid in real pixel art (flat mode): a boy with a red cap pulled down, messy hair
    poking out, a loose blue short-sleeved T-shirt, dark trousers and trainers. His bent right
    arm holds the slingshot (painted in game)."""
    T1, T2, T3 = "#2f4c86", "#4566a8", "#6c8cc8"
    S, S1 = "#f0c8a8", "#c9957e"
    C1, C2, C3 = "#7a2433", "#a8384c", "#cc5a68"
    HA, HA2 = "#1c1626", "#3a3050"
    P1, P2, P3 = "#1e1d2c", "#2e2c40", "#45425c"
    SH, WH, WH1 = "#2a2838", "#ece8f2", "#b9b4c8"

    # --- Cabeza / Head ---
    h = ""
    # Pelo revuelto por detrás y a los lados / Messy hair at the back and sides
    h += flat("M-16,-104 L-21,-99 L-16,-97 L-20,-91 L-14,-92 L-15,-86 L-9,-90 L-8,-102 Z", HA)
    h += flat("M12,-102 L17,-96 L13,-95 L15,-90 L9,-93 Z", HA)
    h += flat("M-17,-101 L-14,-100 L-16,-95 Z", HA2)
    h += flat("M-12,-96 C-12,-106 -6,-110 1,-110 C8,-110 13,-106 13,-96 C13,-88 8,-83 1,-83 C-6,-83 -12,-88 -12,-96 Z", S)
    h += flat("M6,-108 C11,-105 13,-100 13,-96 C13,-89 9,-84 3,-83 C8,-87 10,-93 9,-100 Z", S1)
    # Sombra de la visera sobre los ojos / Brim shadow over the eyes
    h += flat("M-12,-100 L13,-100 L13,-95 C6,-94 -6,-94 -12,-95 Z", S1)
    h += "<path d='M-2,-88 L4,-88' stroke='%s' stroke-width='2'/>" % S1
    # Gorra / Cap
    h += flat("M-15,-101 C-15,-115 -6,-120 2,-120 C12,-120 17,-113 16,-101 Z", C2)
    h += flat("M6,-119 C13,-116 17,-110 16,-101 L9,-101 C11,-108 10,-114 6,-119 Z", C1)
    h += flat("M-12,-104 C-12,-112 -6,-117 0,-118 L0,-115 C-5,-114 -9,-110 -9,-104 Z", C3)
    h += flat("M12,-104 L31,-101 C31,-96 24,-95 13,-98 Z", C1)
    h += "<path d='M-15,-101 L16,-101' stroke='%s' stroke-width='2.4'/>" % C1
    h += flat("M0.5,-122 L3.5,-122 L3.5,-119 L0.5,-119 Z", C3)
    add("sling_head", -24, -126, 58, 46, h, flat=True)

    # --- Camiseta y brazos / T-shirt and arms ---
    b = ""
    # Brazo izquierdo colgando / Left arm hanging
    b += flat("M-23,-69 L-16,-68 L-16,-51 L-23,-51 Z", S) + flat("M-18,-68 L-16,-68 L-16,-51 L-18,-51 Z", S1)
    b += flat("M-24,-49 C-24,-53 -21,-54 -19.5,-54 C-17,-54 -15,-53 -15,-49 C-15,-45 -17,-44 -19.5,-44 C-22,-44 -24,-45 -24,-49 Z", S)
    # Camiseta / T-shirt
    b += flat("M-14,-87 C-6,-89 6,-89 14,-87 L18,-44 C6,-41 -6,-41 -18,-44 Z", T2)
    b += flat("M8,-88 L14,-87 L18,-44 L11,-43 C13,-58 12,-74 8,-88 Z", T1)
    b += flat("M-12,-84 L-8,-85 L-10,-48 L-14,-48 Z", T3)
    b += flat("M-18,-47 C-6,-44 6,-44 18,-47 L18,-44 C6,-41 -6,-41 -18,-44 Z", T1)
    b += flat("M-5,-89 L5,-89 L4,-85 L-4,-85 Z", S1)
    b += "<path d='M-6,-88 C-3,-84 3,-84 6,-88' fill='none' stroke='%s' stroke-width='2.2'/>" % T1
    # Mangas cortas / Short sleeves
    b += flat("M-14,-87 L-25,-81 L-25,-68 L-15,-66 Z", T2) + flat("M-22,-80 L-25,-80 L-25,-69 L-22,-69 Z", T3)
    b += flat("M14,-87 L25,-81 L26,-70 L16,-68 Z", T1)
    # Brazo derecho doblado hacia delante, con la mano donde va el tirachinas
    # Right arm bent forward, with the hand where the slingshot goes
    b += flat("M18,-71 L24,-71 L31,-60 L26,-56 Z", S) + flat("M24,-71 L31,-60 L29,-58 L22,-69 Z", S1)
    b += flat("M24,-58 C24,-62 27,-63 28.5,-63 C31,-63 33,-62 33,-58 C33,-54 31,-53 28.5,-53 C26,-53 24,-54 24,-58 Z", S)
    add("sling_body", -30, -93, 68, 56, b, flat=True)

    # --- Pierna con zapatilla / Leg with a trainer ---
    l = flat("M-6,-43 L6,-43 L6,-12 L-6,-12 Z", P2) + flat("M1,-43 L6,-43 L6,-12 L2,-12 Z", P1)
    l += flat("M-5,-41 L-3,-41 L-3,-14 L-5,-14 Z", P3)
    l += flat("M-7,-12 C-7,-17 -1,-17 2,-16 L6,-15 C11,-14 13,-10 13,-6 L13,-3 L-7,-3 Z", SH)
    l += flat("M6,-14 C11,-13 13,-10 13,-7 L6,-7 Z", WH)
    l += flat("M-8,-5 L14,-5 L14,0 L-8,0 Z", WH) + flat("M-8,-2 L14,-2 L14,0 L-8,0 Z", WH1)
    add("sling_leg", -10, -46, 26, 48, l, flat=True)


def skeleton():
    """Esqueleto en pixel art de verdad (modo flat): cráneo grande y redondo de dibujo animado,
    cuencas negras (los ojos brillan en el juego), dientes, costillas y huesos en tres tonos.
    Skeleton in real pixel art (flat mode): a big round cartoon skull, black sockets (the eyes
    glow in game), teeth, ribs and bones in three tones."""
    B1, B2, B3, B4 = "#8f8574", "#c4b9a5", "#ece5d4", "#fffaf0"
    HOLE = "#1a1328"
    # --- Cráneo / Skull ---
    k = flat(ellipse_d(2, -103, 17, 16), B3)
    k += flat("M8,-117 C16,-114 20,-107 19,-99 C18,-93 15,-90 11,-89 C14,-94 15,-102 12,-109 C11,-112 10,-115 8,-117 Z", B2)
    k += flat("M-12,-108 C-11,-114 -5,-118 1,-119 L1,-115 C-4,-114 -8,-111 -9,-107 Z", B4)
    k += flat("M-8,-92 L13,-92 L13,-85 C9,-81 -4,-81 -8,-85 Z", B3) + flat("M8,-92 L13,-92 L13,-85 C11,-83 9,-82 7,-82 Z", B2)
    k += "<path d='M-8,-89 L13,-89' stroke='%s' stroke-width='1.8'/>" % B1
    k += "".join("<path d='M%g,-88 L%g,-83' stroke='%s' stroke-width='1.6'/>" % (x, x, B1) for x in (-3, 1.5, 6))
    for x in (-4, 9):
        k += flat(ellipse_d(x, -102, 5.4, 6), HOLE)
    k += flat("M2.5,-97 L5,-93 L0,-93 Z", HOLE)
    add("skel_skull", -20, -124, 44, 48, k, flat=True)
    # --- Costillas: caja torácica de una pieza con huecos oscuros / Ribs: one-piece ribcage with dark gaps ---
    r = flat("M-14,-86 Q0,-91 14,-86 L13,-55 Q6,-50 0,-50 Q-6,-50 -13,-55 Z", B3)
    r += flat("M6,-89 Q11,-88 14,-86 L13,-55 Q10,-52 7,-51 Q9,-70 6,-89 Z", B2)
    r += flat("M-12,-84 Q-9,-86 -6,-87 L-6,-58 L-11,-57 Z", B4)
    for y in (-79, -71, -63):
        for sgn in (-1, 1):
            r += "<path d='M%g,%g Q%g,%g %g,%g' fill='none' stroke='%s' stroke-width='2.4'/>" % (sgn * 3, y, sgn * 9, y - 2, sgn * 13, y + 3, HOLE)
    r += flat("M-1.8,-88 L1.8,-88 L1.8,-46 L-1.8,-46 Z", B2)
    r += "".join("<path d='M-2,%d L2,%d' stroke='%s' stroke-width='1.4'/>" % (yy, yy, B1) for yy in range(-50, -86, -6))
    add("skel_ribs", -18, -90, 36, 50, r, flat=True)
    # --- Pelvis ---
    pv = flat("M-12,-47 Q0,-50 12,-47 L8,-38 Q0,-35 -8,-38 Z", B3) + flat("M5,-48 Q9,-48 12,-47 L8,-38 Q6,-37 4,-37 Z", B2)
    pv += flat(ellipse_d(-5, -42, 2, 2), HOLE) + flat(ellipse_d(5, -42, 2, 2), HOLE)
    add("skel_pelvis", -15, -52, 30, 20, pv, flat=True)
    # --- Hueso de 20 de largo, de (0,0) a (20,0) / A 20-long bone, from (0,0) to (20,0) ---
    bone_d = "M1,-2.8 C-2,-5 -3.6,-1 -1.8,0 C-3.6,1 -2,5 1,2.8 L19,2.8 C22,5 23.6,1 21.8,0 C23.6,-1 22,-5 19,-2.8 Z"
    bn = flat(bone_d, B3) + flat("M1,1 L19,1 L19,2.8 C21,4 22.5,3 22.5,2 L22,2.8 L1,2.8 C-1,4 -2.5,3 -2.5,2 Z", B2)
    add("skel_bone", -5, -6, 30, 12, bn, flat=True)
    # --- Montón de huesos / Bone pile ---
    pile = ""
    for n in range(6):
        ang = n * 1.1
        cx, cy = math.cos(ang) * 14, -4 + math.sin(ang) * 4
        a = math.degrees(ang * 2)
        pile += "<g transform='translate(%.1f,%.1f) rotate(%.1f) translate(-10,0)'>%s</g>" % (cx, cy, a, bn)
    pile += flat(ellipse_d(4, -13, 11, 10), B3) + flat("M9,-21 C13,-19 15,-15 14,-11 C13,-8 11,-6 8,-5 C10,-9 11,-14 9,-21 Z", B2)
    pile += flat(ellipse_d(0.5, -13, 3, 3.2), HOLE) + flat(ellipse_d(8, -13, 3, 3.2), HOLE)
    add("skel_pile", -29, -27, 58, 36, pile, flat=True)


# --- Jefe: muebles / Boss: furniture ----------------------------------------------

def boss():
    # Cama en pixel art plano: cabecero de madera con barrotes y pomos, almohada mullida, sábana
    # doblada y edredón de estrellas y lunas que cuelga por los lados (base en y = 0; los ojos y
    # las patas se dibujan en el juego, los ojos sobre la almohada).
    # Bed in flat pixel art: wooden headboard with bars and knobs, a fluffy pillow, a folded sheet
    # and a star-and-moon quilt hanging over the sides (base at y = 0; the eyes and legs are drawn
    # in game, the eyes over the pillow).
    W0, W1, W2, W3 = "#2a2058", "#46388a", "#6553b0", "#8a78d4"
    KN, KN1 = "#e8ecff", "#aab4ea"
    S1, S2, S3 = "#aaa5d4", "#dcd8f2", "#fbfaff"
    Q0, Q1, Q2, Q3 = "#2c3480", "#4350ad", "#5b68c8", "#7e8ae0"
    GOLD, GOLD1 = "#f6d993", "#d6a94e"
    bed = ""
    # Postes y cabecero / Posts and headboard
    for x in (-74, 66):
        bed += flat("M%g,-176 L%g,-176 L%g,-6 L%g,-6 Z" % (x, x + 8, x + 8, x), W1)
        bed += flat("M%g,-176 L%g,-176 L%g,-6 L%g,-6 Z" % (x + 1, x + 3, x + 3, x + 1), W3)
        bed += flat(ellipse_d(x + 4, -180, 7, 7), KN) + flat("M%g,-180 C%g,-176 %g,-174 %g,-173 C%g,-175 %g,-177 %g,-180 Z" % (x + 9, x + 9, x + 6, x + 4, x + 7, x + 8, x + 9), KN1)
    bed += flat("M-66,-170 C-40,-182 40,-182 66,-170 L66,-128 L-66,-128 Z", W2)
    bed += flat("M-66,-170 C-40,-182 40,-182 66,-170 L66,-164 C40,-175 -40,-175 -66,-164 Z", W3)
    bed += flat("M-66,-136 L66,-136 L66,-128 L-66,-128 Z", W1)
    for x in range(-54, 60, 18):
        bed += flat("M%g,-166 L%g,-166 L%g,-140 L%g,-140 Z" % (x - 3, x + 3, x + 3, x - 3), W0)
    # Colchón con la sábana / Mattress with the sheet
    bed += flat("M-66,-130 L66,-130 L66,-6 L-66,-6 Z", S2)
    # Almohada mullida / Fluffy pillow
    bed += flat("M-50,-140 C-20,-146 20,-146 50,-140 C55,-128 55,-116 50,-104 C20,-99 -20,-99 -50,-104 C-55,-116 -55,-128 -50,-140 Z", S3)
    bed += flat("M-50,-110 C-20,-105 20,-105 50,-110 L50,-104 C20,-99 -20,-99 -50,-104 Z", S1)
    # Edredón que cuelga por los lados / Quilt hanging over the sides
    quilt = "M-73,-90 C-30,-96 30,-96 73,-90 L74,-2 L-74,-2 Z"
    bed += flat(quilt, Q2)
    bed += flat("M48,-93 C60,-92 68,-91 73,-90 L74,-2 L54,-2 C58,-30 56,-62 48,-93 Z", Q1)
    bed += flat("M-73,-90 C-66,-91 -60,-92 -54,-93 C-60,-60 -62,-30 -58,-2 L-74,-2 Z", Q1)
    bed += flat("M-74,-12 L74,-12 L74,-2 L-74,-2 Z", Q0)
    bed += flat("M-36,-86 C-30,-60 -32,-36 -38,-14 L-33,-14 C-27,-36 -26,-60 -32,-86 Z", Q1)
    bed += flat("M28,-88 C34,-62 34,-38 30,-14 L35,-14 C39,-38 38,-62 32,-88 Z", Q0)
    bed += flat("M-50,-86 C-46,-70 -46,-52 -50,-36 L-47,-36 C-43,-52 -43,-70 -47,-86 Z", Q3)
    # Estrellas y lunas del edredón / Quilt stars and moons
    for (x, y, r) in ((-44, -64, 9), (2, -70, 10), (-14, -32, 9), (40, -30, 8)):
        bed += flat(star_d(x, y, r, inner=0.5), GOLD)
    for (x, y) in ((-50, -30), (40, -64)):
        bed += flat(ellipse_d(x, y, 9, 9), GOLD1) + flat(ellipse_d(x + 5, y - 3, 8, 8), Q2)
    # Sábana doblada encima del edredón / Sheet folded over the quilt
    bed += flat("M-74,-94 C-30,-100 30,-100 74,-94 L74,-80 C30,-86 -30,-86 -74,-80 Z", S2)
    bed += flat("M-74,-84 C-30,-90 30,-90 74,-84 L74,-80 C30,-86 -30,-86 -74,-80 Z", S1)
    bed += flat("M-60,-95 C-30,-98 0,-98 20,-97 L20,-94 C0,-95 -30,-95 -60,-92 Z", S3)
    add("boss_bed", -82, -190, 164, 192, bed, flat=True)

    # Estantería en pixel art plano: mueble de madera con cornisa, tres baldas y libros de
    # cuentos de alturas y colores distintos (alguno inclinado). En la balda de arriba queda un
    # hueco oscuro en el centro: de ahí asoman los ojos, que se pintan en el juego.
    # Bookshelf in flat pixel art: a wooden unit with a cornice, three shelves and storybooks of
    # different heights and colours (some leaning). The top shelf has a dark gap in the middle:
    # the eyes, painted in game, peer out from there.
    W0, W1, W2, W3 = "#221a4c", "#3a2f7a", "#5446a4", "#7564c8"
    IN = "#16123a"
    BOOKS = [("#e3a6c4", "#b9739a"), ("#f6d993", "#c9a24e"), ("#8fb3e8", "#5d80c0"),
             ("#b6e0d6", "#7ab0a4"), ("#c9b6f0", "#9580c8"), ("#f2a07a", "#c46f50")]
    BAND = "#fbfaff"
    sh = flat("M-60,-166 L60,-166 L60,0 L-60,0 Z", W2)
    sh += flat("M50,-166 L60,-166 L60,0 L50,0 Z", W1) + flat("M-60,-166 L-56,-166 L-56,0 L-60,0 Z", W3)
    # Cornisa / Cornice
    sh += flat("M-64,-174 L64,-174 L64,-164 L-64,-164 Z", W3) + flat("M-64,-167 L64,-167 L64,-164 L-64,-164 Z", W1)
    # Zócalo / Plinth
    sh += flat("M-62,-10 L62,-10 L62,0 L-62,0 Z", W1)
    shelves = [(-160, -112), (-106, -60), (-54, -12)]
    for row, (top, bot) in enumerate(shelves):
        sh += flat("M-52,%g L52,%g L52,%g L-52,%g Z" % (top, top, bot, bot), IN)
        x = -50.0
        k = row * 2
        while x < 46:
            if row == 0 and -34 < x < 30:
                x = 31.0   # hueco para los ojos / gap for the eyes
                continue
            bw = 8 + (k * 5) % 7
            bh = (bot - top) - 4 - (k * 7) % 14
            c, c1 = BOOKS[k % len(BOOKS)]
            if row != 0 and k % 5 == 3 and x + bw + 12 < 50:
                # Libro inclinado apoyado en el siguiente / Book leaning on the next one
                lw = bw + 4
                lean = 10
                sh += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, bot, x + lw, bot, x + lw + lean, bot - bh + 6, x + lean, bot - bh + 2), c)
                sh += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x + lw - 3, bot, x + lw, bot, x + lw + lean, bot - bh + 6, x + lw + lean - 3, bot - bh + 5), c1)
                x += lw + lean + 1.5
                k += 1
                continue
            sh += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, bot - bh, x + bw, bot - bh, x + bw, bot, x, bot), c)
            sh += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x + bw - 2.5, bot - bh, x + bw, bot - bh, x + bw, bot, x + bw - 2.5, bot), c1)
            if bh > 26:
                sh += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, bot - bh + 6, x + bw, bot - bh + 6, x + bw, bot - bh + 9, x, bot - bh + 9), BAND)
            x += bw + 1.5
            k += 1
        # Balda / Shelf board
        sh += flat("M-56,%g L56,%g L56,%g L-56,%g Z" % (bot, bot, bot + 6, bot + 6), W3)
        sh += flat("M-56,%g L56,%g L56,%g L-56,%g Z" % (bot + 3, bot + 3, bot + 6, bot + 6), W1)
    add("boss_shelf", -66, -177, 132, 180, sh, flat=True)

    # Baúl de juguetes en pixel art plano: tablones lilas, cantoneras metálicas con remaches,
    # cierre dorado arriba y pegatinas de niño (cohete y corazón). Los ojos van en el frente.
    # Toy chest in flat pixel art: lilac planks, riveted metal corners, a golden latch at the top
    # and kid's stickers (a rocket and a heart). The eyes go on the front.
    P0, P1, P2, P3 = "#5a3f86", "#8a68b8", "#b294d8", "#d2baf0"
    MT, MT1, GOLD, GOLD1 = "#cfd6f6", "#8f96c4", "#f6d993", "#c9a24e"
    box = flat("M-60,-66 L60,-66 L60,0 L-60,0 Z", P2)
    box += flat("M48,-66 L60,-66 L60,0 L48,0 Z", P1)
    for y in (-46, -24):
        box += flat("M-60,%g L60,%g L60,%g L-60,%g Z" % (y, y, y + 2.6, y + 2.6), P1)
    box += flat("M-56,-64 L-40,-64 L-40,-60 L-56,-60 Z", P3)
    box += flat("M-60,-8 L60,-8 L60,0 L-60,0 Z", P0)
    for x in (-60, 50):
        box += flat("M%g,-66 L%g,-66 L%g,0 L%g,0 Z" % (x, x + 10, x + 10, x), MT1)
        box += flat("M%g,-66 L%g,-66 L%g,0 L%g,0 Z" % (x + 1, x + 5, x + 5, x + 1), MT)
        for y in (-58, -32, -8):
            box += flat(ellipse_d(x + 5, y, 2, 2), P0)
    # Cierre / Latch
    box += flat("M-8,-66 L8,-66 L8,-54 L0,-50 L-8,-54 Z", GOLD) + flat("M2,-66 L8,-66 L8,-54 L2,-52 Z", GOLD1)
    box += flat(ellipse_d(0, -59, 2, 2.4), P0)
    # Pegatinas: cohete y corazón / Stickers: rocket and heart
    box += flat("M-36,-14 L-30,-30 L-24,-14 Z", "#f2f2ff") + flat("M-33,-22 L-27,-22 L-27,-19 L-33,-19 Z", "#5fb8ff")
    box += flat("M-36,-14 L-38,-10 L-34,-14 Z M-24,-14 L-22,-10 L-26,-14 Z", "#e2434f")
    box += flat("M30,-22 C30,-27 37,-27 37,-22 C37,-27 44,-27 44,-22 C44,-17 37,-13 37,-12 C37,-13 30,-17 30,-22 Z", "#ff7fa8")
    add("boss_chest_box", -63, -69, 126, 72, box, flat=True)
    lid = flat("M-63,-16 Q0,-24 63,-16 L63,2 L-63,2 Z", P2)
    lid += flat("M50,-17 Q57,-17 63,-16 L63,2 L50,2 Z", P1)
    lid += flat("M-63,-4 L63,-4 L63,2 L-63,2 Z", P0)
    lid += flat("M-56,-16 Q-20,-21 20,-20 L20,-17 Q-20,-18 -56,-13 Z", P3)
    for x in (-63, 53):
        lid += flat("M%g,-17 L%g,-17 L%g,2 L%g,2 Z" % (x, x + 10, x + 10, x), MT1) + flat("M%g,-17 L%g,-17 L%g,2 L%g,2 Z" % (x + 1, x + 5, x + 5, x + 1), MT)
    lid += flat("M-8,-4 L8,-4 L8,2 L-8,2 Z", GOLD)
    add("boss_chest_lid", -66, -26, 132, 30, lid, flat=True)

# --- Proyectiles / Projectiles --------------------------------------------------------

def shots():
    bk = flat("M-16,-11 L16,-11 L16,11 L-16,11 Z", "#6a4fa8") + flat("M-13,-8 L13,-8 L13,8 L-13,8 Z", "#f1e6c8")
    bk += flat("M-13,4 L13,4 L13,8 L-13,8 Z", "#d6c8a4")
    bk += flat("M-1.5,-11 L1.5,-11 L1.5,11 L-1.5,11 Z", "#4a3488")
    add("shot_book", -19, -14, 38, 28, bk, flat=True)
    st = flat(ellipse_d(0, 0, 10, 9), "#8f86b0") + clipped(ellipse_d(0, 0, 10, 9), flat("M-12,3 L12,3 L12,12 L-12,12 Z", "#655c8a"))
    st += flat(ellipse_d(-3.5, -3.5, 3, 2.6), "#cfc6e8")
    add("shot_stone", -12, -12, 24, 24, st, flat=True)

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
    # Svinho: futbolista brasileño, en pixel art de verdad (modo flat). La pierna derecha va aparte
    # para dar toques al balón (se anima en NpcArt._svinho).
    # Svinho: Brazilian footballer, in real pixel art (flat mode). The right leg is separate so he
    # can do keepy-uppies (animated in NpcArt._svinho).
    Y1, Y2, Y3 = "#c99a1e", "#f6d24a", "#fff08a"
    G, G1 = "#2f9e5b", "#1f6e3e"
    B1, B2, B3 = "#1e3a80", "#2b4fa8", "#4a72cc"
    S, S1, S2 = "#b97c56", "#8f5c45", "#d49a72"
    HA, HA2 = "#1d1620", "#4a3a5a"
    SO, SO1, BO, WH = "#f4f1ea", "#c8c4d8", "#1e1f2e", "#ece8f2"

    def leg(x, sock_band=True):
        d = flat("M%g,196 L%g,196 L%g,236 L%g,236 Z" % (x, x + 15, x + 15, x), S)
        d += flat("M%g,196 L%g,196 L%g,236 L%g,236 Z" % (x + 10, x + 15, x + 15, x + 10), S1)
        d += flat("M%g,232 L%g,232 L%g,274 L%g,274 Z" % (x - 1, x + 16, x + 16, x - 1), SO)
        d += flat("M%g,232 L%g,232 L%g,274 L%g,274 Z" % (x + 11, x + 16, x + 16, x + 11), SO1)
        d += flat("M%g,240 L%g,240 L%g,245 L%g,245 Z" % (x - 1, x + 16, x + 16, x - 1), G)
        d += flat("M%g,274 L%g,274 C%g,274 %g,278 %g,282 L%g,286 L%g,286 Z" % (x - 2, x + 14, x + 22, x + 26, x + 26, x + 26, x - 2), BO)
        d += "".join(flat("M%g,286 L%g,286 L%g,288 L%g,288 Z" % (sx, sx + 3, sx + 3, sx), WH) for sx in (x, x + 9, x + 18))
        return d

    # Pierna derecha aparte (cadera en 106,196) / Separate right leg (hip at 106,196)
    add("npc_svinho_leg", 92, 192, 42, 100, leg(100), px=PX_NPC, flat=True)

    b = leg(80)
    # Pantalón corto azul / Blue shorts
    b += flat("M72,168 L128,168 L130,204 L103,204 L100,192 L97,204 L70,204 Z", B2)
    b += flat("M110,168 L128,168 L130,204 L112,204 C114,190 114,178 110,168 Z", B1)
    b += flat("M75,172 L80,172 L79,200 L74,200 Z", B3)
    b += "<path d='M72,170 L128,170' stroke='%s' stroke-width='2.6'/>" % SO
    # Brazos / Arms
    b += flat("M62,106 L76,110 L72,168 L58,166 Z", S) + flat("M68,110 L76,110 L72,168 L66,168 Z", S1)
    b += flat("M138,106 L124,110 L128,168 L142,166 Z", S1)
    b += flat(ellipse_d(65, 172, 7, 8), S) + flat(ellipse_d(135, 172, 7, 8), S1)
    # Camiseta amarilla con el 10 / Yellow shirt with the number 10
    shirt = "M82,96 L118,96 L140,106 L136,130 L128,128 L128,172 L72,172 L72,128 L64,130 L60,106 Z"
    b += flat(shirt, Y2)
    b += flat("M118,96 L140,106 L136,130 L128,128 L128,172 L114,172 C118,150 118,120 112,98 Z", Y1)
    b += flat("M66,106 L80,99 L82,104 L70,110 Z", Y3)
    b += "<path d='M60,106 L64,130 M140,106 L136,130' stroke='%s' stroke-width='2.6'/>" % G
    b += "<path d='M86,97 L100,111 L114,97' fill='none' stroke='%s' stroke-width='4' stroke-linejoin='round'/>" % G
    b += flat("M88,128 L94,124 L94,156 L88,156 Z", G)
    b += flat("M100,124 L112,124 L112,156 L100,156 Z", G) + flat("M104,129 L108,129 L108,151 L104,151 Z", Y2)
    # Cuello y cabeza / Neck and head
    b += flat("M93,82 L107,82 L107,98 L93,98 Z", S1)
    b += flat(ellipse_d(100, 60, 22, 26), S)
    b += flat("M110,38 C118,44 122,52 122,60 C122,74 115,84 104,86 C112,78 115,70 115,60 C115,50 113,43 110,38 Z", S1)
    b += flat("M82,62 C82,54 85,48 89,45 L90,49 C87,52 86,56 86,62 Z", S2)
    # Pelo rizado / Curly hair
    for (cx, cy) in ((82, 44), (92, 36), (104, 34), (116, 40), (122, 52), (78, 56), (98, 40), (110, 44), (86, 50)):
        b += flat(ellipse_d(cx, cy, 9, 9), HA)
    for (cx, cy) in ((90, 33), (102, 31), (80, 41)):
        b += flat(ellipse_d(cx, cy, 3.5, 3), HA2)
    add("npc_svinho", 50, 22, 100, 270, b, px=PX_NPC, flat=True, post=npc_face(62, "#2a1d22", 1))
    ball = flat(ellipse_d(0, 0, 13, 13), "#f7f3ea") + flat("M4,-12 C10,-9 13,-4 13,0 C13,7 8,12 2,13 C8,8 10,3 9,-3 C8,-7 6,-10 4,-12 Z", "#c8c4d8")
    ball += flat("M0,-5 L4.8,-1.5 L3,4 L-3,4 L-4.8,-1.5 Z", "#1e1f2e")
    ball += flat("M-11,-6 L-7,-9 L-6,-4 Z", "#1e1f2e") + flat("M10,7 L7,10 L5,6 Z", "#1e1f2e")
    add("npc_ball", -15, -15, 30, 30, ball, px=PX_NPC, flat=True)

    # Stolk: el matón del cole, en pixel art de verdad (modo flat). Grandullón con sudadera roja,
    # brazos cruzados, pelo rapado, tirita en la mejilla, palillo en la boca, vaqueros y
    # zapatillas blancas enormes.
    # Stolk: the school bully, in real pixel art (flat mode). A big lad in a red sweatshirt, arms
    # crossed, buzz cut, a plaster on his cheek, a toothpick in his mouth, jeans and huge white trainers.
    R1, R2, R3 = "#6e1f2a", "#a8323f", "#d0505a"
    J1, J2, J3 = "#283153", "#3a4670", "#526094"
    W, W1, RED = "#ece8f2", "#b9b4c8", "#c8304a"
    S, S1 = "#f0c4aa", "#c9957e"
    HA1, HA2 = "#5a3f2c", "#8a6448"
    b = ""
    # Piernas / Legs
    b += flat("M104,184 L127,184 L127,270 L104,270 Z", J1)
    b += flat("M74,184 L98,184 L98,270 L74,270 Z", J2) + flat("M89,184 L98,184 L98,270 L91,270 Z", J1)
    b += flat("M76,186 L80,186 L80,262 L76,262 Z", J3)
    b += flat("M73,260 L99,260 L99,268 L73,268 Z", J3) + flat("M103,260 L128,260 L128,268 L103,268 Z", J2)
    # Zapatillas blancas enormes / Huge white trainers
    for x0 in (66, 100):
        b += flat("M%g,268 L%g,268 C%g,268 %g,274 %g,280 L%g,288 L%g,288 Z" % (x0 + 4, x0 + 30, x0 + 36, x0 + 38, x0 + 38, x0 + 38, x0), W)
        b += flat("M%g,282 L%g,282 L%g,288 L%g,288 Z" % (x0, x0 + 38, x0 + 38, x0), W1)
        b += "<path d='M%g,276 L%g,276' stroke='%s' stroke-width='3'/>" % (x0 + 8, x0 + 30, RED)
    # Sudadera / Sweatshirt
    b += flat("M72,96 L128,96 C142,100 150,108 150,118 L146,192 L54,192 L50,118 C50,108 58,100 72,96 Z", R2)
    b += flat("M128,96 C142,100 150,108 150,118 L146,192 L130,192 C134,160 134,124 124,98 Z", R1)
    b += flat("M60,104 C64,100 70,98 76,97 L76,102 C70,103 66,106 62,110 Z", R3)
    b += flat("M54,180 L146,180 L146,192 L54,192 Z", R1)
    b += "".join("<path d='M%d,181 L%d,191' stroke='#4a141c' stroke-width='2.2'/>" % (x, x) for x in range(60, 146, 8))
    b += flat("M88,92 C92,98 108,98 112,92 L114,100 C106,104 94,104 86,100 Z", R1)
    # Cuello / Neck
    b += flat("M90,82 L110,82 L110,96 C104,99 96,99 90,96 Z", S1)
    # Brazos cruzados: los brazos bajan por los lados y los antebrazos se cruzan sobre el pecho
    # Crossed arms: the upper arms run down the sides and the forearms cross over the chest
    SEAM = "#4a141c"
    b += flat("M50,110 C45,124 45,142 49,158 L64,158 L64,110 Z", R2) + flat("M52,116 C49,128 49,142 51,152 L55,152 L55,116 Z", R3)
    b += flat("M150,110 C155,124 155,142 151,158 L136,158 L136,110 Z", R1)
    b += "<path d='M64,112 L64,156 M136,112 L136,156' stroke='%s' stroke-width='2.4'/>" % SEAM
    # Antebrazo de atrás (derecho) con la mano asomando por la izquierda / Back forearm (right) with the hand peeking out on the left
    b += flat("M151,140 L151,158 L70,140 L72,124 Z", R1)
    b += flat(ellipse_d(68, 128, 8, 8), S) + flat("M70,135 C73,134 76,131 76,128 L72,128 C72,131 70,133 67,134 Z", S1)
    # Antebrazo de delante (izquierdo) con la mano metida bajo el otro brazo / Front forearm (left) with the hand tucked under the other arm
    b += flat("M49,142 L49,160 L136,144 L134,126 Z", R2) + flat("M49,142 L134,126 L135,131 L49,147 Z", R3)
    b += "<path d='M49,142 L134,126 M49,160 L136,144' stroke='%s' stroke-width='2.4'/>" % SEAM
    b += flat(ellipse_d(140, 133, 8, 8), S) + flat("M142,140 C145,139 148,136 148,133 L144,133 C144,136 142,138 139,139 Z", S1)
    # Cabeza cuadrada / Square head
    b += flat(ellipse_d(76, 60, 5, 7), S) + flat(ellipse_d(124, 60, 5, 7), S1)
    b += flat("M77,56 C77,38 87,30 100,30 C113,30 123,38 123,56 L121,74 C117,84 110,88 100,88 C90,88 83,84 79,74 Z", S)
    b += flat("M112,34 C119,39 123,46 123,56 L121,74 C118,82 113,86 106,88 C114,80 117,70 116,58 C116,48 115,40 112,34 Z", S1)
    # Pelo rapado / Buzz cut
    b += flat("M77,52 C77,36 88,27 100,27 C112,27 123,36 123,52 L119,44 C112,41 88,41 81,44 Z", HA1)
    b += flat("M84,38 C89,32 95,30 101,30 L101,34 C95,34 90,36 86,41 Z", HA2)
    # Tirita en la mejilla y palillo en la boca / Plaster on the cheek and toothpick in the mouth
    b += "<g transform='rotate(-25 113 70)'>%s</g>" % flat("M106,67 L120,67 L120,73 L106,73 Z", "#f2d4a6")
    b += "<path d='M104,78 L118,73' stroke='#e8d0a0' stroke-width='2.6' stroke-linecap='round'/>"
    add("npc_stolk", 44, 22, 116, 272, b, px=PX_NPC, flat=True, post=npc_face(60, "#3a2a30", 2))

    # Silly: la hacker, en pixel art de verdad (modo flat). Media melena morada, sudadera oscura
    # con capucha, cascos cian al cuello y el portátil abierto mirando hacia nosotros (el código
    # de la pantalla se pinta y se mueve en el juego).
    # Silly: the hacker, in real pixel art (flat mode). A purple bob, a dark hoodie, cyan
    # headphones round her neck and an open laptop facing us (the code on screen is painted and
    # animated in game).
    D1, D2, D3 = "#252852", "#383e74", "#545ca0"
    P1, P2, P3 = "#5a3a9e", "#8a5bd6", "#b48cf0"
    S, S1 = "#f4d2c0", "#caa8b4"
    CY, CY1 = "#5ff2ff", "#2a9fb0"
    PA1, PA2 = "#1a1c34", "#272a48"
    WH = "#ece8f2"
    L1, L2, SCR = "#9aa0c0", "#c8cce0", "#0d1a2a"
    b = ""
    # Piernas y zapatillas cian / Legs and cyan trainers
    b += flat("M102,186 L117,186 L117,276 L102,276 Z", PA1) + flat("M83,186 L98,186 L98,276 L83,276 Z", PA2)
    for x0 in (79, 102):
        b += flat("M%g,274 L%g,274 C%g,274 %g,279 %g,283 L%g,288 L%g,288 Z" % (x0 + 2, x0 + 14, x0 + 18, x0 + 20, x0 + 20, x0 + 20, x0), CY)
        b += flat("M%g,284 L%g,284 L%g,288 L%g,288 Z" % (x0, x0 + 20, x0 + 20, x0), WH)
        b += "<path d='M%g,276 L%g,278' stroke='%s' stroke-width='2'/>" % (x0 + 6, x0 + 13, CY1)
    # Sudadera / Hoodie
    b += flat("M80,96 L120,96 C136,100 144,108 144,120 L140,196 L60,196 L56,120 C56,108 64,100 80,96 Z", D2)
    b += flat("M120,96 C136,100 144,108 144,120 L140,196 L126,196 C130,160 130,124 116,98 Z", D1)
    b += flat("M62,108 C66,102 72,99 78,98 L78,103 C72,104 68,108 65,113 Z", D3)
    b += flat("M60,186 L140,186 L140,196 L60,196 Z", D1)
    b += flat("M82,94 C88,102 112,102 118,94 L122,102 C110,108 90,108 78,102 Z", D1)
    # Cascos al cuello / Headphones round the neck
    b += "<path d='M83,100 C88,110 112,110 117,100' fill='none' stroke='%s' stroke-width='3.4'/>" % CY
    b += flat(ellipse_d(81, 100, 6, 7), CY) + flat(ellipse_d(119, 100, 6, 7), CY1)
    # Brazos que sujetan el portátil / Arms holding the laptop
    b += flat("M56,114 C51,130 53,146 60,156 L72,156 L70,116 Z", D2) + flat("M58,120 C55,132 56,144 60,150 L63,150 L61,120 Z", D3)
    b += flat("M144,114 C149,130 147,146 140,156 L128,156 L130,116 Z", D1)
    b += "<path d='M70,116 L72,156 M130,116 L128,156' stroke='#141630' stroke-width='2.4'/>"
    # Bolsillo de la sudadera / Hoodie pocket
    b += flat("M76,166 L124,166 L128,182 L72,182 Z", D1)
    b += "<path d='M76,166 C72,172 72,177 72,182 M124,166 C128,172 128,177 128,182' fill='none' stroke='#141630' stroke-width='2.2'/>"
    # Portátil abierto mirando hacia nosotros / Open laptop facing us
    b += flat("M66,116 L134,116 L134,150 L66,150 Z", L2) + flat("M126,116 L134,116 L134,150 L126,150 Z", L1)
    b += flat("M71,120 L129,120 L129,146 L71,146 Z", SCR)
    b += flat("M62,150 L138,150 L134,158 L66,158 Z", L1)
    b += flat(ellipse_d(66, 151, 6, 6), S) + flat(ellipse_d(134, 151, 6, 6), S1)
    # Cuello y cabeza / Neck and head
    b += flat("M93,82 L107,82 L107,96 C103,98 97,98 93,96 Z", S1)
    b += flat("M80,62 C80,44 89,36 100,36 C111,36 120,44 120,62 C120,76 112,86 100,86 C88,86 80,76 80,62 Z", S)
    b += flat("M110,40 C116,45 120,52 120,62 C120,74 115,82 106,86 C112,78 114,70 114,62 C114,52 113,45 110,40 Z", S1)
    # Media melena morada con flequillo / Purple bob with a fringe
    b += flat("M75,82 L75,52 C75,37 86,29 100,29 C114,29 125,37 125,52 L125,82 L117,82 L117,58 L109,52 L100,58 L91,52 L83,58 L83,82 Z", P2)
    b += flat("M117,40 C122,45 125,50 125,56 L125,82 L117,82 L117,58 L112,54 C115,50 116,45 117,40 Z", P1)
    b += flat("M80,50 C82,40 89,34 98,32 L98,36 C91,38 86,43 84,50 Z", P3)
    b += flat("M108,40 L114,40 L114,44 L108,44 Z", CY)
    add("npc_silly", 46, 24, 108, 268, b, px=PX_NPC, flat=True, post=npc_face(64, "#2a2238", 3))

    # Doc: el doctor, en pixel art de verdad (modo flat). Médico mayor con bata blanca, espejo
    # frontal, pelo canoso a los lados, bigote, estetoscopio, camisa azul con corbata roja y su
    # carpeta de historiales.
    # Doc: the doctor, in real pixel art (flat mode). An elderly doctor in a white coat, with a
    # head mirror, grey hair at the sides, a moustache, a stethoscope, a blue shirt with a red tie
    # and his clipboard of patient notes.
    W1, W2, W3 = "#a9a6c8", "#dcdaee", "#f8f7ff"
    SB1, SB2 = "#6f93c8", "#9fc1e8"
    TIE, TIE1 = "#c95f6f", "#8f3a4a"
    S, S1 = "#e8c4a8", "#c2a092"
    G1, G2 = "#9a97ae", "#d4d2e2"
    PA1, PA2 = "#2e3150", "#454a72"
    SHO, SHO1 = "#2a2238", "#4a3f5c"
    ST, ST1 = "#3c4170", "#8f8fb8"
    WOOD, WOOD1, PAPER, PAPER1 = "#b98a5a", "#8a6440", "#f7f3ea", "#c8c4d8"
    b = ""
    # Piernas y zapatos / Legs and shoes
    b += flat("M104,206 L120,206 L120,276 L104,276 Z", PA1) + flat("M80,206 L97,206 L97,276 L80,276 Z", PA2)
    b += flat("M90,206 L97,206 L97,276 L91,276 Z", PA1)
    for x0 in (78, 102):
        b += flat("M%g,274 L%g,274 C%g,274 %g,280 %g,288 L%g,288 Z" % (x0, x0 + 16, x0 + 20, x0 + 22, x0 + 22, x0), SHO)
        b += flat("M%g,276 L%g,276 L%g,280 L%g,280 Z" % (x0 + 3, x0 + 13, x0 + 13, x0 + 3), SHO1)
    # Bata blanca larga / Long white coat
    b += flat("M80,94 L120,94 L142,106 L146,238 L54,238 L58,106 Z", W2)
    b += flat("M120,94 L142,106 L146,238 L128,238 C132,190 130,130 116,96 Z", W1)
    b += flat("M62,110 C64,104 70,99 78,96 L78,101 C72,104 68,108 66,114 Z", W3)
    # Camisa y corbata / Shirt and tie
    b += flat("M88,96 L112,96 L106,200 L94,200 Z", SB2) + flat("M103,96 L112,96 L106,200 L102,200 Z", SB1)
    b += flat("M97,100 L103,100 L105,150 L100,158 L95,150 Z", TIE) + flat("M100,100 L103,100 L105,150 L100,158 Z", TIE1)
    # Solapas y bolsillo con bolígrafos / Lapels and pocket with pens
    b += "<path d='M88,96 L94,140 M112,96 L106,140' stroke='%s' stroke-width='2.6'/>" % W1
    b += flat("M118,128 L134,128 L134,142 L118,142 Z", W1)
    b += flat("M121,118 L124,118 L124,128 L121,128 Z", "#5b67c4") + flat("M126,120 L129,120 L129,128 L126,128 Z", TIE)
    # Estetoscopio / Stethoscope
    b += "<path d='M86,104 C86,120 112,120 114,106 M114,108 L118,150' fill='none' stroke='%s' stroke-width='3'/>" % ST
    b += flat(ellipse_d(118, 154, 6, 6), ST1) + flat(ellipse_d(117, 153, 2.5, 2.5), "#dfe6ff")
    # Brazos / Arms
    b += flat("M58,106 L72,110 L74,176 L60,176 Z", W2) + flat("M62,110 L66,110 L66,170 L62,170 Z", W3)
    b += flat("M142,106 L128,110 L126,176 L140,176 Z", W1)
    b += flat(ellipse_d(133, 180, 7, 7), S1)
    # La mano sujeta la carpeta por el borde: los dedos van detrás y solo asoma el pulgar
    # The hand holds the clipboard by its edge: the fingers go behind and only the thumb shows
    b += flat(ellipse_d(52, 184, 7, 8), S)
    # Carpeta de historiales / Clipboard
    b += flat("M50,148 L86,148 L86,196 L50,196 Z", WOOD) + flat("M78,148 L86,148 L86,196 L80,196 Z", WOOD1)
    b += flat("M54,154 L82,154 L82,192 L54,192 Z", PAPER) + flat("M76,154 L82,154 L82,192 L78,192 Z", PAPER1)
    b += "".join("<path d='M58,%d L76,%d' stroke='#7a78a0' stroke-width='2'/>" % (y, y) for y in (162, 170, 178, 186))
    b += flat("M62,144 L74,144 L74,151 L62,151 Z", G1)
    b += flat("M49,178 L56,176 L57,183 L50,186 Z", S)
    # Cuello y cabeza / Neck and head
    b += flat("M93,82 L107,82 L107,98 L93,98 Z", S1)
    b += flat(ellipse_d(100, 60, 23, 27), S)
    b += flat("M111,37 C119,43 123,51 123,60 C123,75 116,84 106,87 C113,79 116,70 116,60 C116,50 114,43 111,37 Z", S1)
    # Pelo canoso a los lados y calva / Grey hair at the sides and a bald top
    b += flat(ellipse_d(78, 62, 6, 13), G2) + flat(ellipse_d(122, 62, 6, 13), G1)
    b += flat("M80,50 C82,44 86,40 90,38 L91,42 C87,44 85,47 84,52 Z", "#fff4e8")
    # Bigote / Moustache
    b += flat("M89,73 L100,70 L111,73 L107,78 L100,75 L93,78 Z", G2)
    b += flat("M100,70 L111,73 L107,78 L100,75 Z", G1)
    # Espejo frontal con su cinta / Head mirror with its band
    b += "<path d='M79,46 C88,40 112,40 121,46' fill='none' stroke='%s' stroke-width='3'/>" % ST
    b += flat(ellipse_d(100, 40, 9, 9), G1) + flat(ellipse_d(100, 40, 6.5, 6.5), "#dfe6ff") + flat(ellipse_d(98, 38, 2.5, 2.5), "#ffffff")
    add("npc_doc", 46, 26, 106, 266, b, px=PX_NPC, flat=True, post=npc_face(62, "#2a2238", 1))


# --- Habitación de Kroker / Kroker's bedroom -------------------------------------------
# Coordenadas del lienzo de la habitación (1920 x 1080) / Room canvas coordinates (1920 x 1080)

def rect_d(x, y, w, h):
    return "M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x, y, x + w, y, x + w, y + h, x, y + h)


def room_add(name, x, y, w, h, body, colors=24, outline="#1a1024"):
    add(name, x, y, w, h, body, px=PX_ROOM, colors=colors, flat=True, outline=outline)


def room():
    WB = 300
    # Pared en pixel art plano: un sprite por nivel de rareza, con rayas verticales suaves y una
    # franja más oscura junto al rodapié / Wall in flat pixel art: one sprite per strangeness
    # level, with soft vertical stripes and a darker band by the skirting board
    for wl in range(4):
        k = min(1.0, wl / 3.0)
        top, bot = mix("#1d2463", "#3a1d63", k), mix("#2c3681", "#1f6a7a", k)
        wall = mix(top, bot, 0.45)
        b = "<rect x='0' y='0' width='1920' height='%d' fill='%s'/>" % (WB, wall)
        b += "<rect x='0' y='0' width='1920' height='70' fill='%s'/>" % mix(wall, top, 0.6)
        b += "<rect x='0' y='%d' width='1920' height='60' fill='%s'/>" % (WB - 74, mix(wall, bot, 0.8))
        for x in range(0, 1920, 48):
            b += "<rect x='%d' y='0' width='18' height='%d' fill='%s' opacity='0.5'/>" % (x, WB, light(wall, 0.06))
        b += shaded(rect_d(0, WB - 14, 1920, 18), "#cfc8ec", shade=0.3, rim=0.5, sw=1.2)
        room_add("room_wall_%d" % wl, 0, 0, 1920, WB + 4, b, colors=12)
    # Suelo de tablas / Floorboards
    b = "<rect x='0' y='%d' width='1920' height='740' fill='#36326f'/>" % WB
    y, row = WB + 4, 0
    while y < 1000:
        b += "<rect x='0' y='%d' width='1920' height='3' fill='#1c1846'/>" % y
        b += "<rect x='0' y='%d' width='1920' height='3' fill='#45408a'/>" % (y + 3)
        x = -120 + (row % 3) * 140
        while x < 1920:
            b += "<rect x='%d' y='%d' width='3' height='46' fill='#1c1846'/>" % (x, y)
            for nx in (60, 300):
                b += "<circle cx='%d' cy='%d' r='3' fill='#24205a'/>" % (x + nx, y + 23)
            x += 420
        # Vetas / Grain
        for gx in range(row * 37 % 200, 1920, 240):
            b += "<path d='M%d,%d L%d,%d' fill='none' stroke='#2c2862' stroke-width='3'/>" % (gx, y + 18, gx + 90, y + 18)
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
    gl = "M-11,-30 L11,-30 L9,0 Q0,3 -9,0 Z"
    b = flat(gl, "#b8c2ea")
    b += flat("M-10,-22 L10,-22 L8.6,-1 Q0,1.6 -8.6,-1 Z", "#fbf8ff") + flat("M3,-22 L10,-22 L8.6,-1 Q5,0 3,0 Z", "#d6dcf4")
    b += flat("M-7,-28 L-4.5,-28 L-4,-4 L-6.4,-4 Z", "#ffffff")
    add("pickup_milk", -15, -34, 30, 40, b, flat=True)
    # Almohada escudo / Pillow shield
    pts = []
    for k in range(48):
        a = math.tau * k / 48
        c, s_ = math.cos(a), math.sin(a)
        pts.append("%.2f,%.2f" % (math.copysign(abs(c) ** 0.6, c) * 18, math.copysign(abs(s_) ** 0.6, s_) * 13 - 14))
    pil = "M" + " L".join(pts) + " Z"
    b = flat(pil, "#ece7fa") + clipped(pil, flat("M-20,-10 L20,-10 L20,2 L-20,2 Z", "#c4bbe8"))
    b += flat(star_d(0, -14, 7, inner=0.5), "#8fe0ff")
    add("pickup_pillow", -22, -32, 44, 36, b, flat=True)
    # Despertador / Alarm clock
    b = ""
    for x in (-9, 9):
        b += flat(ellipse_d(x, -30, 5.5, 5.5), "#f6c86a")
    b += "<path d='M-8,-2 L-11,3 M8,-2 L11,3' stroke='#4a3f7a' stroke-width='3'/>"
    ck = ellipse_d(0, -15, 14, 14)
    b += flat(ck, "#e85d75") + clipped(ck, flat("M4,-32 L16,-32 L16,2 L4,2 Z", "#b83a56"))
    b += flat(ellipse_d(0, -15, 9.5, 9.5), "#fbf8ff")
    b += "<path d='M0,-14 L0,-22 M0,-14 L5,-11' stroke='#2b2945' stroke-width='2.4'/>"
    add("pickup_clock", -18, -38, 36, 44, b, flat=True)

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


def school_hall():
    """Acto 3: el pasillo del colegio, en pixel art plano. Es infinito: se dibuja a trozos de
    1920 de ancho que se repiten (tres paredes distintas que se van alternando y un suelo que
    casa por los lados). Taquillas, puertas de clase, baños, fuente, tablón de anuncios,
    ventanales a la noche y vitrina de trofeos.
    Act 3: the school hallway, in flat pixel art. It's endless: it's drawn in 1920-wide pieces
    that repeat (three different walls taking turns and a floor that tiles at the sides).
    Lockers, classroom doors, toilets, a water fountain, a notice board, big windows onto the
    night and a trophy case."""
    WB = 300
    # Colores de colegio: pintura crema, azulejos verdes, taquillas azules y suelo de terrazo
    # School colours: cream paint, green tiles, blue lockers and a terrazzo floor
    PAINT, PAINT1, TILE, TILE1, TRIM = "#e4d6b2", "#d2c39c", "#7fae96", "#62927c", "#f4eedf"
    LK, LK1, LK2, LK3 = "#3f72b8", "#2f5a96", "#6a98d8", "#24467a"
    WOOD, WOOD1, WOOD2 = "#8a5a3e", "#6a4430", "#a8714f"

    def wall_base():
        b = "<rect x='0' y='0' width='1920' height='%d' fill='%s'/>" % (WB, PAINT)
        b += "<rect x='0' y='0' width='1920' height='26' fill='%s'/>" % PAINT1
        # Zócalo de azulejos / Tiled dado
        b += "<rect x='0' y='196' width='1920' height='%d' fill='%s'/>" % (WB - 196, TILE)
        for x in range(0, 1920, 48):
            b += "<rect x='%d' y='196' width='3' height='%d' fill='%s'/>" % (x, WB - 196, TILE1)
        for y in (226, 256):
            b += "<rect x='0' y='%d' width='1920' height='3' fill='%s'/>" % (y, TILE1)
        b += shaded(rect_d(0, 190, 1920, 10), TRIM, shade=0.3, rim=0.5, sw=1)
        b += shaded(rect_d(0, WB - 14, 1920, 18), "#8a7e66", shade=0.3, rim=0.4, sw=1.2)
        # Fluorescentes del techo / Ceiling strip lights
        for x in range(120, 1920, 480):
            b += "<rect x='%d' y='4' width='220' height='12' fill='#fbfbf0'/><rect x='%d' y='14' width='220' height='4' fill='#b8b29a'/>" % (x, x)
        return b

    def lockers(x0, x1):
        b = ""
        x = x0
        n = 0
        while x + 70 <= x1:
            col = ["#c8463e", "#e0b53a"][n % 2] if n % 7 == 5 else LK
            b += shaded(rect_d(x, 60, 70, 240), col, shade=0.35, rim=0.35, sw=1)
            b += "<rect x='%d' y='60' width='70' height='8' fill='%s'/>" % (x, LK2)
            for y in (78, 88, 98):
                b += "<rect x='%d' y='%d' width='40' height='4' fill='%s'/>" % (x + 15, y, LK3)
            b += "<rect x='%d' y='150' width='6' height='26' fill='#d8dcf0'/>" % (x + 56)
            # Rejilla de abajo y patas a ras de suelo / Bottom vent and feet at floor level
            for y in (262, 272):
                b += "<rect x='%d' y='%d' width='40' height='4' fill='%s'/>" % (x + 15, y, LK3)
            b += "<rect x='%d' y='292' width='70' height='8' fill='%s'/>" % (x, LK1)
            b += "<rect x='%d' y='60' width='4' height='240' fill='%s'/>" % (x + 66, LK3)
            if n % 5 == 2:
                # Pegatina / Sticker
                b += "<rect x='%d' y='200' width='18' height='14' fill='%s'/>" % (x + 14, ["#f6d993", "#ff8fb0", "#8fe0ff"][n % 3])
            x += 72
            n += 1
        return b

    def door(x, label_col=None, icon=None):
        b = shaded(rect_d(x - 10, 50, 160, 250), "#8a7e66", shade=0.3, rim=0.3, sw=1)
        b += shaded(rect_d(x, 60, 140, 240), WOOD, shade=0.35, rim=0.3, sw=1)
        b += "<rect x='%d' y='60' width='12' height='240' fill='%s'/>" % (x + 128, WOOD1)
        b += "<rect x='%d' y='84' width='56' height='70' fill='#9fc4d8'/><rect x='%d' y='88' width='16' height='30' fill='#e4f2f8'/>" % (x + 42, x + 46)
        b += "<rect x='%d' y='180' width='18' height='8' fill='#e0b860'/>" % (x + 112)
        if icon == "boy":
            b += "<circle cx='%d' cy='200' r='9' fill='#8fc8ff'/><rect x='%d' y='212' width='22' height='34' fill='#8fc8ff'/>" % (x + 70, x + 59)
        elif icon == "girl":
            b += "<circle cx='%d' cy='200' r='9' fill='#ff9fc0'/><path d='M%d,212 L%d,212 L%d,248 L%d,248 Z' fill='#ff9fc0'/>" % (x + 70, x + 61, x + 79, x + 87, x + 53)
        elif label_col:
            b += "<rect x='%d' y='30' width='90' height='22' fill='%s'/><rect x='%d' y='38' width='60' height='5' fill='#2b2945'/>" % (x + 25, label_col, x + 40)
        return b

    # Pared A: taquillas, puerta de clase, tablón / Wall A: lockers, classroom door, notice board
    b = wall_base() + lockers(40, 700) + door(760, "#f6d993")
    b += shaded(rect_d(980, 70, 290, 150), "#b07a4a", shade=0.3, rim=0.3, sw=1)
    b += "<rect x='992' y='82' width='266' height='126' fill='#c8925e'/>"
    for i, (px_, py_, c) in enumerate(((1006, 92, "#fbf3dc"), (1066, 100, "#ff9fc0"), (1130, 90, "#fbf3dc"), (1196, 104, "#8fe0ff"), (1024, 150, "#f6d993"), (1150, 148, "#fbf3dc"))):
        b += "<rect x='%d' y='%d' width='46' height='40' fill='%s'/><rect x='%d' y='%d' width='6' height='6' fill='#e2434f'/>" % (px_, py_, c, px_ + 20, py_ - 2)
        b += "<rect x='%d' y='%d' width='30' height='4' fill='#6a6a8a'/>" % (px_ + 8, py_ + 14)
    b += lockers(1320, 1900)
    room_add("hall_wall_0", 0, 0, 1920, WB + 4, b, colors=16, outline=None)
    # Pared B: taquillas, baños y fuente / Wall B: lockers, toilets and fountain
    b = wall_base() + lockers(40, 560) + door(620, icon="boy") + door(820, icon="girl")
    b += shaded(rect_d(1040, 170, 90, 60), "#b8c2ea", shade=0.3, rim=0.4, sw=1)
    b += "<rect x='1048' y='176' width='74' height='16' fill='#8fc8e0'/><rect x='1080' y='162' width='8' height='12' fill='#9aa2c0'/>"
    b += "<rect x='1060' y='230' width='50' height='70' fill='#a8b0c0'/>"
    b += lockers(1220, 1900)
    room_add("hall_wall_1", 0, 0, 1920, WB + 4, b, colors=16, outline=None)
    # Pared C: ventanales, vitrina de trofeos y puerta / Wall C: big windows, trophy case and door
    b = wall_base()
    for wx in (120, 1420):
        b += shaded(rect_d(wx, 40, 400, 170), TRIM, shade=0.3, rim=0.4, sw=1)
        b += "<rect x='%d' y='50' width='380' height='150' fill='#141844'/>" % (wx + 10)
        for sx, sy in ((40, 30), (130, 80), (220, 40), (310, 110), (80, 120), (350, 50)):
            b += "<rect x='%d' y='%d' width='4' height='4' fill='#f6e9b0'/>" % (wx + 10 + sx, 50 + sy)
        for k in (1, 2, 3):
            b += "<rect x='%d' y='50' width='6' height='150' fill='%s'/>" % (wx + 10 + k * 95 - 3, TRIM)
        b += "<rect x='%d' y='122' width='380' height='6' fill='%s'/>" % (wx + 10, TRIM)
    b += "<circle cx='1530' cy='96' r='22' fill='#f6efc8'/><circle cx='1522' cy='90' r='5' fill='#d8d0a8'/>"
    b += shaded(rect_d(740, 60, 340, 200), WOOD1, shade=0.3, rim=0.3, sw=1)
    b += "<rect x='752' y='72' width='316' height='176' fill='#c8dce4'/>"
    for sy in (156, 236):
        b += "<rect x='752' y='%d' width='316' height='6' fill='%s'/>" % (sy, WOOD2)
    for i, tx in enumerate((790, 870, 960, 1030)):
        gold = ["#f6d24a", "#c9c9e0", "#e0a060", "#f6d24a"][i]
        b += "<path d='M%d,150 L%d,150 L%d,138 L%d,138 L%d,112 C%d,112 %d,96 %d,96 L%d,96 C%d,96 %d,112 %d,112 L%d,138 L%d,138 Z' fill='%s'/>" % (
            tx - 14, tx + 14, tx + 10, tx + 4, tx + 4, tx + 14, tx + 16, tx + 14, tx - 14, tx - 16, tx - 14, tx - 4, tx - 4, tx - 10, gold)
    for i, tx in enumerate((800, 900, 1000)):
        b += "<rect x='%d' y='200' width='40' height='36' fill='%s'/>" % (tx, ["#e2434f", "#5b8fe0", "#6fbf98"][i])
    b += door(1180, "#8fe0ff")
    room_add("hall_wall_2", 0, 0, 1920, WB + 4, b, colors=16, outline=None)
    # Suelo de linóleo a cuadros que casa por los lados / Chequered linoleum floor that tiles at the sides
    b = "<rect x='0' y='%d' width='1920' height='740' fill='#cfc7b0'/>" % WB
    for gy, y in enumerate(range(WB, 1040, 60)):
        for gx, x in enumerate(range(0, 1920, 120)):
            if (gx + gy) % 2 == 0:
                b += "<rect x='%d' y='%d' width='120' height='60' fill='#bdb49a'/>" % (x, y)
            # Motitas del terrazo / Terrazzo speckles
            for m in range(3):
                mx = x + (gx * 37 + gy * 53 + m * 41) % 110 + 4
                my = y + (gx * 29 + gy * 17 + m * 23) % 50 + 4
                b += "<rect x='%d' y='%d' width='5' height='5' fill='%s'/>" % (mx, my, ["#9a917a", "#e8e2d0", "#a8a088"][m])
        b += "<rect x='0' y='%d' width='1920' height='3' fill='#a49c86'/>" % y
    for x in range(0, 1920, 120):
        b += "<rect x='%d' y='%d' width='3' height='740' fill='#a49c86'/>" % (x, WB)
    # Brillo de los fluorescentes en el suelo / Strip-light shine on the floor
    for x in range(160, 1920, 480):
        b += "<rect x='%d' y='%d' width='140' height='8' fill='#f2eee2'/>" % (x, WB + 40)
    b += "<rect x='0' y='%d' width='1920' height='14' fill='#8f8872'/>" % WB
    room_add("hall_floor", 0, WB, 1920, 742, b, colors=10, outline=None)
    # Cartel de suelo mojado y cubo de fregar / Wet-floor sign and mop bucket
    b = flat("M-26,0 L-6,-70 L6,-70 L26,0 Z", "#f6d24a") + flat("M6,-70 L26,0 L16,0 L2,-60 Z", "#c9a428")
    b += flat("M-12,-38 L4,-38 L-2,-26 L8,-26 L-10,-8 L-4,-22 L-14,-22 Z", "#2b2945")
    add("hall_sign", -30, -74, 60, 78, b, px=PX_ROOM, flat=True)
    b = flat("M-30,-40 L30,-40 L24,0 L-24,0 Z", "#5b8fe0") + flat("M14,-40 L30,-40 L24,0 L12,0 Z", "#3a6ab8")
    b += flat("M-30,-44 L30,-44 L30,-36 L-30,-36 Z", "#8fb8f0")
    b += "<path d='M8,-40 L22,-110' stroke='#a87a5c' stroke-width='5'/>"
    b += flat("M-6,-44 L18,-44 L14,-54 L-2,-54 Z", "#e8e0d0")
    add("hall_bucket", -34, -114, 68, 118, b, px=PX_ROOM, flat=True)


def charo_body(small):
    """Kioskera Charo en pixel art de verdad (modo flat): anciana bajita y redondita, con gafas
    redondas y cadenita, permanente gris, pendientes de perla, coloretes, rebeca morada abierta,
    vestido rosa de flores y el delantal verde del kiosco.
    Kiosk lady Charo in real pixel art (flat mode): a short, round old woman with round glasses on
    a chain, a grey perm, pearl earrings, rosy cheeks, an open purple cardigan, a pink floral
    dress and the kiosk's green apron."""
    D1, D2, D3, FLW = "#a85a7a", "#d98aa6", "#f0b0c8", "#fbe8f0"
    C1, C2, C3 = "#4f4290", "#6a5aa8", "#8a7ac8"
    A1, A2, A3 = "#2f7e72", "#4fa89a", "#7fd0c0"
    K1, K2 = "#4a2850", "#6a3a6e"
    S, S1, CHEEK = "#f0cdb6", "#cfa898", "#f0a0a8"
    H1, H2, H3 = "#a8a4be", "#d8d4e6", "#f4f2fa"
    ST, ST1, SHO = "#d9b8a8", "#b8988a", "#5a3a2e"
    FR, GOLD = "#7a2e4a", "#e0b860"
    b = ""
    # Medias y zapatos / Stockings and shoes
    for x in (84, 104):
        b += flat("M%g,240 L%g,240 L%g,278 L%g,278 Z" % (x, x + 13, x + 13, x), ST) + flat("M%g,240 L%g,240 L%g,278 L%g,278 Z" % (x + 9, x + 13, x + 13, x + 9), ST1)
        b += flat(ellipse_d(x + 7, 282, 11, 6), SHO) + flat("M%g,279 L%g,279 L%g,281 L%g,281 Z" % (x + 1, x + 7, x + 7, x + 1), "#8a5a46")
    # Falda / Skirt
    b += flat("M58,186 L142,186 L152,248 L48,248 Z", K2) + flat("M126,186 L142,186 L152,248 L134,248 Z", K1)
    # Rebeca que envuelve todo el cuerpo (redondita) / Cardigan wrapping the whole (round) body
    body = "M80,102 L120,102 Q162,124 162,172 Q162,204 136,206 L64,206 Q38,204 38,172 Q38,124 80,102 Z"
    b += flat(body, C2)
    b += flat("M126,110 Q162,128 162,172 Q162,204 136,206 L124,206 Q146,190 146,160 Q146,128 126,110 Z", C1)
    b += flat("M52,132 Q58,118 72,108 L75,112 Q63,122 58,136 Z", C3)
    # Vestido de flores asomando por la abertura de delante / Floral dress showing through the front opening
    b += flat("M89,103 L111,103 L121,206 L79,206 Z", D2) + flat("M104,103 L111,103 L121,206 L112,206 Z", D1)
    for (fx, fy) in ((95, 118), (104, 132), (92, 146), (108, 160), (97, 176), (112, 190), (88, 196)):
        b += flat(ellipse_d(fx, fy, 2.6, 2.6), FLW)
    # Bordes de la rebeca a los lados de la abertura, con botones / Cardigan edges either side of the opening, with buttons
    b += "<path d='M89,103 L79,206 M111,103 L121,206' stroke='%s' stroke-width='3'/>" % C1
    for y in (128, 150, 172):
        b += flat(ellipse_d(85 - (y - 128) * 0.06, y, 2.6, 2.6), "#f4ecdc")
    # Delantal del kiosco con bolsillo / Kiosk apron with a pocket
    b += flat("M68,150 L132,150 L138,234 L62,234 Z", A2) + flat("M120,150 L132,150 L138,234 L126,234 Z", A1)
    b += flat("M70,152 L76,152 L72,230 L66,230 Z", A3)
    b += flat("M84,190 L116,190 L116,208 L84,208 Z", A1)
    b += "<path d='M72,150 Q100,140 128,150' fill='none' stroke='#f4ecdc' stroke-width='2.4'/>"
    # Brazos regordetes con las manos juntas / Chubby arms with hands clasped
    b += flat("M50,118 L66,112 L84,166 L68,176 Z", C2) + flat("M54,120 L60,118 L74,164 L70,168 Z", C3)
    b += flat("M150,118 L134,112 L116,166 L132,176 Z", C1)
    b += flat(ellipse_d(92, 170, 10, 9), S) + flat(ellipse_d(108, 170, 10, 9), S1)
    b += "<path d='M100,163 L100,177' stroke='%s' stroke-width='2'/>" % S1
    # Cuello y cabeza / Neck and head
    b += flat("M92,94 L108,94 L108,108 L92,108 Z", S1)
    b += flat(ellipse_d(100, 78, 25, 25), S)
    b += flat("M110,56 C120,62 125,70 125,78 C125,92 116,101 104,103 C113,96 118,88 118,78 C118,68 115,61 110,56 Z", S1)
    b += flat(ellipse_d(84, 89, 5, 4), CHEEK) + flat(ellipse_d(116, 89, 5, 4), CHEEK)
    # Permanente gris de rizos / Curly grey perm
    for cx_, cy_, r in ((78, 64, 10), (86, 52, 11), (100, 47, 12), (114, 52, 11), (122, 64, 10), (74, 76, 8), (126, 76, 8), (92, 50, 8), (108, 50, 8)):
        b += flat(ellipse_d(cx_, cy_, r, r), H2)
    for cx_, cy_, r in ((118, 54, 7), (124, 68, 6), (127, 78, 5)):
        b += flat(ellipse_d(cx_, cy_, r, r), H1)
    for cx_, cy_, r in ((84, 48, 4), (97, 42, 4.5), (75, 60, 3.5)):
        b += flat(ellipse_d(cx_, cy_, r, r), H3)
    # Pendientes de perla / Pearl earrings
    b += flat(ellipse_d(75, 87, 3, 3), "#fbf8ff") + flat(ellipse_d(125, 87, 3, 3), "#fbf8ff")
    # Gafas redondas con cadenita (en pequeño, solo dos lentes sin cadena)
    # Round glasses with a little chain (small size: just two lenses, no chain)
    if small:
        # Pensado para su tamaño real en la partida (unos 35 x 65 píxeles): rasgos más gruesos
        # Designed for her real in-game size (about 35 x 65 pixels): chunkier features
        b += flat(ellipse_d(75, 88, 4.5, 4.5), "#fbf8ff") + flat(ellipse_d(125, 88, 4.5, 4.5), "#fbf8ff")
        b += flat(ellipse_d(90, 80, 9.5, 9), FR) + flat(ellipse_d(110, 80, 9.5, 9), FR)
        b += flat(ellipse_d(90, 80, 5.5, 5), "#dfe6ff") + flat(ellipse_d(110, 80, 5.5, 5), "#dfe6ff")
        b += "<path d='M81,86 Q74,100 86,108 M119,86 Q126,100 114,108' fill='none' stroke='%s' stroke-width='4'/>" % GOLD
        b += flat(ellipse_d(82, 93, 5, 4), CHEEK) + flat(ellipse_d(118, 93, 5, 4), CHEEK)
        b += "<path d='M94,96 Q100,100 106,96' fill='none' stroke='#a85a6a' stroke-width='4'/>"
        add("charo_small", 30, 34, 140, 258, b, px=PX_KROKER, flat=True, post=charo_face_small)
        return
    b += "<circle cx='91' cy='80' r='8' fill='none' stroke='%s' stroke-width='2.6'/>" % FR
    b += "<circle cx='109' cy='80' r='8' fill='none' stroke='%s' stroke-width='2.6'/>" % FR
    b += "<path d='M99,80 L101,80' stroke='%s' stroke-width='2.6'/>" % FR
    b += "<path d='M83,82 Q76,100 88,106 M117,82 Q124,100 112,106' fill='none' stroke='%s' stroke-width='1.8'/>" % GOLD
    add("npc_charo", 30, 34, 140, 258, b, px=PX_NPC, flat=True, post=npc_face(80, "#3a2a30", 1))


def charo_face_small(img, to_px):
    """Ojos de la Charo pequeña: un píxel oscuro en el centro de cada lente.
    Small Charo's eyes: one dark pixel in the middle of each lens."""
    pix = img.load()
    w, h = img.size
    for cx in (90, 110):
        x, y = to_px(cx, 80)
        x, y = int(round(x - 0.5)), int(round(y - 0.5))
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
    # Mosquito en pixel art plano: abdomen a rayas, tórax, cabeza con ojo rojo, trompa larga y
    # patas finas colgando; las alas se dibujan en el juego.
    # Mosquito in flat pixel art: striped abdomen, thorax, head with a red eye, long proboscis and
    # thin dangling legs; the wings are drawn in game.
    D0, D1, D2, ST = "#1e1834", "#3a2e5a", "#5a4a86", "#a898d8"
    b = ""
    for lx, ly in ((-3, -27), (1, -27), (5, -28)):
        b += "<path d='M%g,%g L%g,%g L%g,%g' fill='none' stroke='%s' stroke-width='2.4'/>" % (lx, ly, lx - 4, ly + 6, lx - 6, ly + 10, D0)
    ab = "".join(flat("M%g,-32.5 L%g,-32.5 L%g,-25.5 L%g,-25.5 Z" % (x, x + 2.6, x + 2.6, x), ST) for x in (-14, -7))
    b += "<g transform='rotate(-12 -8 -29)'>%s%s%s</g>" % (flat(ellipse_d(-9, -29, 10, 5), D1), ab, flat("M-18,-28 C-14,-25 -6,-24 1,-26 L1,-24 C-6,-22 -14,-23 -18,-28 Z", D0))
    b += flat(ellipse_d(2, -31, 5.4, 4.8), D2) + flat("M-1,-28 C1,-27 4,-27 7,-29 L7,-27 C4,-25 0,-25 -1,-28 Z", D1)
    b += flat(ellipse_d(8, -33, 4, 3.8), D1)
    b += flat(ellipse_d(9.5, -34, 2.2, 2.2), "#ff5a7a")
    b += "<path d='M11,-32 L22,-27' stroke='%s' stroke-width='2.4'/>" % D0
    add("mosquito_body", -22, -40, 48, 26, b, flat=True)

    # Nido en pixel art plano: montículo de barro y papel mascado por capas, con agujeros oscuros
    # de los que salen los mosquitos y manchas de musgo.
    # Nest in flat pixel art: a mound of mud and chewed paper in layers, with dark holes the
    # mosquitoes come out of and patches of moss.
    N0, N1, N2, N3 = "#3a2638", "#6a4a62", "#8e6c84", "#b08ea4"
    HOLE, MOSS, MOSS1 = "#140c1a", "#6fbf98", "#3f8a6a"
    mound = "M-36,0 Q-40,-20 -22,-34 Q-4,-48 14,-40 Q36,-30 36,-8 Q36,0 30,2 L-30,2 Q-36,2 -36,0 Z"
    b = flat(mound, N2)
    b += flat("M14,-40 Q36,-30 36,-8 Q36,0 30,2 L18,2 Q28,-14 14,-40 Z", N1)
    b += flat("M-22,-34 Q-4,-48 14,-40 Q-2,-42 -20,-30 Z", N3)
    for k, y in enumerate((-30, -20, -10)):
        b += "<path d='M%g,%g Q0,%g %g,%g' fill='none' stroke='%s' stroke-width='2.6'/>" % (-30 + k * -2, y + 2, y - 6, 30 + k * 2, y + 2, N1)
    b += flat("M-36,-2 L34,-2 Q36,0 30,2 L-30,2 Q-36,2 -36,-2 Z", N0)
    for hx, hy, r in ((-14, -18, 5.5), (8, -28, 5), (16, -10, 6)):
        b += flat(ellipse_d(hx, hy - 1.5, r + 1.5, r * 0.8 + 1), N3)
        b += flat(ellipse_d(hx, hy + 0.5, r, r * 0.8), HOLE)
    for mx, my in ((-30, -4), (-25, -12), (26, -3), (30, -14)):
        b += flat(ellipse_d(mx, my, 4.5, 3.5), MOSS) + flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (mx - 4, my + 1, mx + 4, my + 1, mx + 3, my + 3, mx - 3, my + 3), MOSS1)
    add("nest_body", -42, -50, 84, 56, b, flat=True)

def act3_enemies():
    """Enemigos del Acto 3 en pixel art plano: la Marioneta (cuerpo, pierna, brazo y sus tres
    brazos-arma) y el Gólem de papel higiénico (cuerpo y brazo).
    Act 3 enemies in flat pixel art: the Puppet (body, leg, arm and its three weapon arms) and
    the Toilet-Paper Golem (body and arm)."""
    WD, WD1, WD2 = "#e2b98c", "#c0946a", "#f2d2ac"      # madera clara / light wood
    JK, JK1, GOLDB = "#c8463e", "#9a3030", "#f6d24a"
    SH, SH1 = "#3a5aa8", "#2a4080"
    HAIR = "#6a4026"
    # Cuerpo: cabeza de madera con mandíbula, mejillas pintadas y chaqueta roja
    # Body: wooden head with a hinged jaw, painted cheeks and a red jacket
    b = flat("M-14,-74 L14,-74 L16,-40 L-16,-40 Z", JK) + flat("M6,-74 L14,-74 L16,-40 L8,-40 Z", JK1)
    b += flat("M-16,-46 L16,-46 L16,-34 L-16,-34 Z", SH) + flat("M6,-46 L16,-46 L16,-34 L8,-34 Z", SH1)
    b += flat("M-6,-74 L0,-62 L6,-74 Z", "#fbf3dc")
    for y in (-64, -54):
        b += flat(ellipse_d(0, y, 2, 2), GOLDB)
    b += flat("M-5,-80 L5,-80 L5,-73 L-5,-73 Z", WD1)
    head = ellipse_d(0, -96, 17, 18)
    b += flat(head, WD) + flat("M8,-112 C15,-106 18,-98 16,-88 C14,-82 10,-79 6,-78 C11,-86 12,-96 8,-112 Z", WD1)
    b += flat("M-15,-102 C-14,-114 -4,-116 6,-115 C14,-114 17,-106 17,-102 C10,-108 -6,-108 -15,-102 Z", HAIR)
    b += flat("M-12,-84 L12,-84 L10,-78 L-10,-78 Z", WD2)
    b += "<path d='M-10,-86 L-10,-79 M10,-86 L10,-79' stroke='%s' stroke-width='2.4'/>" % WD1
    b += flat(ellipse_d(-9, -91, 4, 3), "#ff8fa0") + flat(ellipse_d(9, -91, 4, 3), "#ff8fa0")
    b += flat(ellipse_d(-6, -98, 2.6, 3.2), "#1a1328") + flat(ellipse_d(6, -98, 2.6, 3.2), "#1a1328")
    b += flat("M-5,-87 L5,-87 L4,-84 L-4,-84 Z", "#8a2a3a")
    add("puppet_body", -20, -118, 40, 86, b, flat=True)
    # Pierna: palo con articulación y zapato (cadera en el origen) / Leg: stick with a joint and a shoe (hip at the origin)
    l = flat("M-3.5,0 L3.5,0 L3.5,34 L-3.5,34 Z", WD) + flat("M1,0 L3.5,0 L3.5,34 L1,34 Z", WD1)
    l += flat(ellipse_d(0, 17, 4.4, 4.4), WD1)
    l += flat("M-5,32 L8,32 C11,32 12,36 11,40 L-5,40 Z", "#2b2238")
    add("puppet_leg", -8, -2, 22, 44, l, flat=True)
    # Brazo libre (hombro en el origen) / Free arm (shoulder at the origin)
    arm = flat("M-3,0 L3,0 L3,26 L-3,26 Z", JK) + flat("M0.5,0 L3,0 L3,26 L0.5,26 Z", JK1)
    arm += flat(ellipse_d(0, 30, 4.6, 4.6), WD)
    add("puppet_arm", -7, -3, 14, 40, arm, flat=True)
    # Brazos-arma, apuntando hacia +x desde el hombro / Weapon arms, pointing towards +x from the shoulder
    base = flat("M0,-3 L22,-3 L22,3 L0,3 Z", JK) + flat("M0,0.5 L22,0.5 L22,3 L0,3 Z", JK1) + flat(ellipse_d(25, 0, 4.4, 4.4), WD)
    blade = base + flat("M27,-4 L33,-4 L33,4 L27,4 Z", "#4a2e22")
    blade += flat("M33,-10 L58,-6 C62,-2 60,6 54,8 L33,6 Z", "#dfe6ff") + flat("M33,2 L56,4 C58,6 56,8 54,8 L33,6 Z", "#9aa2c0")
    add("puppet_blade", -4, -14, 68, 26, blade, flat=True)
    rod = base + flat("M27,-3 L36,-3 L36,3 L27,3 Z", "#2b2945")
    rod += flat("M36,-4 L64,-4 L64,4 L36,4 Z", "#f6d24a") + flat("M36,1 L64,1 L64,4 L36,4 Z", "#c9a428")
    rod += "".join(flat("M%g,-4 L%g,-4 L%g,4 L%g,4 Z" % (x, x + 3, x + 3, x), "#2b2945") for x in (44, 54))
    rod += flat(ellipse_d(66, 0, 4.4, 4.4), "#8fe0ff")
    add("puppet_rod", -4, -10, 76, 20, rod, flat=True)
    gun = base + flat("M18,2 L34,2 L30,12 L20,12 Z", "#8a5a3e")
    gun += flat("M24,-4 L54,-4 L54,2 L24,2 Z", "#8a5a3e") + flat("M24,-1 L54,-1 L54,2 L24,2 Z", "#6a4430")
    gun += flat("M34,-7 L80,-6 L80,-1 L34,-1 Z", "#5a5a72") + flat("M78,-9 L86,-10 L86,3 L78,2 Z", "#3a3a52")
    gun += flat("M40,-9 L46,-9 L46,-6 L40,-6 Z", "#c9a24e")
    add("puppet_gun", -4, -14, 94, 30, gun, flat=True)

    # Gólem de papel higiénico: rollos apilados envueltos en tiras de papel; tubo de cartón por cabeza
    # Toilet-paper golem: stacked rolls wrapped in strips of paper; a cardboard tube for a head
    P0, P1, P2, P3 = "#fbfaf2", "#e6e2d2", "#c8c2ae", "#a49c86"
    TUBE, TUBE1 = "#b98a5a", "#8a6040"
    g = ""
    # Piernas: rollos / Legs: rolls
    for x in (-22, 22):
        g += flat("M%g,-40 L%g,-40 L%g,0 L%g,0 Z" % (x - 16, x + 16, x + 16, x - 16), P1)
        g += flat("M%g,-40 L%g,-40 L%g,0 L%g,0 Z" % (x + 6, x + 16, x + 16, x + 6), P2)
        g += flat(ellipse_d(x, -40, 16, 5), P0) + flat(ellipse_d(x, -40, 6, 2.6), TUBE)
        g += flat("M%g,-20 L%g,-20 L%g,-17 L%g,-17 Z" % (x - 16, x + 16, x + 16, x - 16), P3)
    # Cuerpo: bulto de papel enrollado / Body: a lump of wound paper
    torso = "M-44,-150 C-56,-130 -56,-70 -42,-46 C-20,-36 20,-36 42,-46 C56,-70 56,-130 44,-150 C20,-162 -20,-162 -44,-150 Z"
    g += flat(torso, P1)
    g += flat("M20,-158 C34,-156 42,-152 44,-150 C56,-130 56,-70 42,-46 C34,-42 26,-40 18,-39 C34,-70 34,-120 20,-158 Z", P2)
    for y, w in ((-136, 2.8), (-112, 2.8), (-88, 2.8), (-64, 2.8)):
        g += "<path d='M-48,%g Q0,%g 48,%g' fill='none' stroke='%s' stroke-width='%g'/>" % (y, y + 10, y - 4, P3, w)
    g += flat("M-30,-150 C-24,-154 -14,-156 -4,-156 L-4,-150 C-14,-150 -22,-148 -28,-144 Z", P0)
    # Tira suelta que cuelga / Loose hanging strip
    g += flat("M30,-100 L42,-98 L40,-40 L34,-24 L28,-40 Z", P0) + flat("M36,-99 L42,-98 L40,-40 L36,-32 Z", P2)
    # Cabeza: tubo de cartón con ojos en el hueco / Head: a cardboard tube with eyes in the hole
    g += flat("M-20,-188 L20,-188 L22,-152 L-22,-152 Z", TUBE) + flat("M8,-188 L20,-188 L22,-152 L10,-152 Z", TUBE1)
    g += flat(ellipse_d(0, -188, 20, 6), TUBE1) + flat(ellipse_d(0, -188, 14, 4), "#3a2618")
    g += "<path d='M-20,-176 L22,-166 M-21,-164 L21,-158' stroke='%s' stroke-width='2.4'/>" % TUBE1
    g += flat(ellipse_d(-8, -170, 4, 5), "#1a1328") + flat(ellipse_d(8, -170, 4, 5), "#1a1328")
    add("golem_body", -60, -196, 120, 200, g, flat=True)
    # Brazo: dos rollos y una mano de papel arrugado (hombro en el origen) / Arm: two rolls and a crumpled paper fist (shoulder at the origin)
    a = ""
    for y in (0, 30):
        a += flat("M-12,%g L12,%g L12,%g L-12,%g Z" % (y, y, y + 30, y + 30), P1) + flat("M4,%g L12,%g L12,%g L4,%g Z" % (y, y, y + 30, y + 30), P2)
        a += flat(ellipse_d(0, y + 30, 12, 4), P3)
    a += flat(ellipse_d(0, 70, 14, 12), P0) + flat("M4,62 C12,64 14,72 10,80 C6,82 2,82 0,82 C8,76 8,68 4,62 Z", P2)
    add("golem_arm", -16, -4, 32, 90, a, flat=True)


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
    J0, J1, J2, J3 = "#0f0d1e", "#1e1a36", "#2e2850", "#463e72"
    NEON, NEON2, SK, SK1 = "#5ff2ff", "#ff5fd2", "#a88fbf", "#7a6292"
    VIS = "#101830"
    body = flat("M-20,-86 Q0,-90 20,-86 L24,-40 Q0,-36 -24,-40 Z", J2)
    body += flat("M12,-88 Q17,-87 20,-86 L24,-40 Q20,-39 16,-38 Q18,-62 12,-88 Z", J1)
    body += flat("M-18,-84 L-12,-84 L-14,-60 L-20,-60 Z", J3)
    body += "<path d='M-18,-84 L-13,-42 M18,-84 L13,-42' stroke='%s' stroke-width='2.6'/>" % NEON
    body += "<path d='M-8,-72 L8,-72 M-8,-64 L8,-64' stroke='%s' stroke-width='2.6'/>" % NEON2
    body += flat("M-2,-88 L2,-88 L2,-44 L-2,-44 Z", J0)
    body += flat("M-24,-46 Q0,-42 24,-46 L24,-38 Q0,-34 -24,-38 Z", J0)
    body += flat("M-4,-45 L4,-45 L4,-39 L-4,-39 Z", NEON)
    add("cyber_body", -28, -92, 56, 58, body, flat=True)
    head = flat(ellipse_d(0, -102, 15, 16), SK) + flat("M6,-116 C12,-112 15,-106 15,-100 C15,-93 11,-88 6,-87 C9,-92 10,-98 9,-104 C9,-109 8,-113 6,-116 Z", SK1)
    head += flat("M-6,-116 L-4,-134 L0,-128 L3,-140 L6,-128 L10,-135 L9,-115 Z", NEON2)
    head += flat("M3,-140 L6,-128 L10,-135 L9,-115 L4,-116 Z", "#c43aa4")
    head += flat("M-16,-109 L17,-109 L18,-98 L-16,-98 Z", VIS)
    head += flat("M-13,-106 L15,-106 L15,-102 L-13,-102 Z", NEON)
    head += "<path d='M9,-93 L14,-91' stroke='%s' stroke-width='2.4'/>" % NEON2
    add("cyber_head", -20, -144, 40, 62, head, flat=True)
    leg = flat("M-6,-42 L6,-42 L5,-8 L-5,-8 Z", J1) + flat("M2,-42 L6,-42 L5,-8 L2,-8 Z", J0)
    leg += flat("M-6,-27 L6,-27 L6,-24 L-6,-24 Z", NEON)
    leg += flat("M-7,-10 L8,-10 L9,-2 L-7,-2 Z", "#e9e6f2") + flat("M-7,-4 L9,-4 L9,-2 L-7,-2 Z", "#a9a6c8")
    add("cyber_leg", -10, -45, 20, 45, leg, flat=True)
    arm = flat("M-5,0 L5,0 L4,30 L-4,30 Z", J2) + flat("M1,0 L5,0 L4,30 L1,30 Z", J1)
    arm += flat("M-5,18 L5,18 L5,21 L-5,21 Z", NEON)
    arm += flat(ellipse_d(0, 34, 5, 5), SK)
    add("cyber_arm", -8, -3, 16, 44, arm, flat=True)

def chef():
    """El Chef: Kroker de mayor, cocinero. Gafas, pelo negro, bigote, gorro alto y delantal.
    The Chef: grown-up Kroker as a cook. Glasses, black hair, moustache, tall hat and apron."""
    W1, W2, W3 = "#a9a6c8", "#dcdaee", "#f8f7ff"
    A0, A1, A2 = "#2f3a8a", "#4652b0", "#5b68c8"
    SK, SK1, HAIR, HAIR1 = "#f1cfbb", "#c99a86", "#16141f", "#3a3456"
    PANT, PANT1, SHOE = "#2b2945", "#3a3866", "#121020"
    # Piernas / Legs
    leg = flat("M-11,-64 L11,-64 L10,-10 L-10,-10 Z", PANT) + flat("M4,-64 L11,-64 L10,-10 L4,-10 Z", "#211f38")
    leg += "<path d='M-10,-50 L10,-50 M-10,-38 L10,-38' stroke='%s' stroke-width='2.4'/>" % PANT1
    leg += flat("M-12,-12 L13,-12 C16,-12 17,-6 16,-1 L-12,-1 Z", SHOE) + flat("M-10,-11 L-2,-11 L-2,-9 L-10,-9 Z", "#3a3456")
    add("chef_leg", -16, -67, 34, 68, leg, flat=True)
    # Torso: chaqueta cruzada y delantal / Torso: double-breasted jacket and apron
    torso = "M-34,-158 Q0,-166 34,-158 Q46,-150 44,-134 L40,-60 Q0,-54 -40,-60 L-44,-134 Q-46,-150 -34,-158 Z"
    body = flat(torso, W2)
    body += flat("M26,-160 Q32,-159 34,-158 Q46,-150 44,-134 L40,-60 Q34,-59 28,-58 Q34,-110 26,-160 Z", W1)
    body += flat("M-38,-150 Q-34,-156 -26,-158 L-26,-152 Q-32,-150 -36,-142 Z", W3)
    for y in (-140, -122):
        for x in (-12, 12):
            body += flat(ellipse_d(x, y, 3, 3), "#2b2945")
    body += "<path d='M-26,-158 L0,-142 L26,-158' fill='none' stroke='%s' stroke-width='2.6'/>" % W1
    body += flat("M-30,-112 L30,-112 L34,-56 Q0,-50 -34,-56 Z", A2)
    body += flat("M20,-112 L30,-112 L34,-56 Q28,-55 24,-54 Q26,-80 20,-112 Z", A1)
    body += flat("M-30,-114 L30,-114 L30,-109 L-30,-109 Z", A0)
    body += flat("M-12,-92 L12,-92 L12,-76 L-12,-76 Z", A1) + flat("M-12,-92 L12,-92 L12,-89 L-12,-89 Z", A0)
    body += flat("M-8,-164 Q0,-150 8,-164 L6,-158 Q0,-152 -6,-158 Z", "#e85d75")
    add("chef_body", -50, -168, 100, 118, body, flat=True)
    # Cabeza con gorro, gafas y bigote / Head with hat, glasses and moustache
    head = flat(ellipse_d(0, -190, 26, 28), SK)
    head += flat("M12,-214 C22,-208 27,-198 26,-188 C25,-176 18,-166 8,-163 C15,-172 18,-182 18,-190 C18,-200 16,-208 12,-214 Z", SK1)
    head += flat("M-27,-196 Q-28,-216 -12,-220 L12,-220 Q28,-216 27,-196 Q22,-206 14,-204 L-14,-204 Q-22,-206 -27,-196 Z", HAIR)
    head += flat("M-20,-212 Q-14,-218 -4,-218 L-4,-215 Q-13,-215 -18,-209 Z", HAIR1)
    head += flat("M-28,-196 L-24,-196 L-24,-182 L-28,-182 Z M24,-196 L28,-196 L28,-182 L24,-182 Z", HAIR)
    for cx in (-10, 10):
        head += flat(ellipse_d(cx, -190, 8, 8), "#2b2945") + flat(ellipse_d(cx, -190, 5.6, 5.6), "#e8eeff")
    head += "<path d='M-3,-190 L3,-190' stroke='#2b2945' stroke-width='2.6'/>"
    head += flat("M-15,-174 Q-7,-181 0,-176 Q7,-181 15,-174 Q8,-169 0,-171 Q-8,-169 -15,-174 Z", HAIR)
    head += "<path d='M-7,-166 Q0,-162 7,-166' fill='none' stroke='#a3687a' stroke-width='2.4'/>"
    # Gorro alto / Tall chef's hat
    hat = flat("M-22,-222 Q-38,-236 -30,-256 Q-20,-276 0,-268 Q20,-278 30,-256 Q38,-236 22,-222 Z", W3)
    hat += flat("M14,-270 Q24,-272 30,-256 Q38,-236 22,-222 L12,-222 Q30,-240 14,-270 Z", W2)
    hat += "<path d='M-12,-226 Q-16,-244 -10,-258 M6,-226 Q8,-246 4,-262' fill='none' stroke='%s' stroke-width='2.6'/>" % W2
    hat += flat("M-22,-224 L22,-224 L24,-208 L-24,-208 Z", W2) + flat("M-22,-224 L22,-224 L22,-220 L-22,-220 Z", W1)
    head = hat + head
    add("chef_head", -40, -282, 80, 124, head, flat=True, post=dot_painter([(-10, -190), (10, -190)], (42, 30, 40, 254)))
    # Brazo con la mano / Arm with the hand
    arm = flat("M-8,0 L8,0 L7,50 L-7,50 Z", W2) + flat("M3,0 L8,0 L7,50 L3,50 Z", W1)
    arm += flat("M-8,44 L8,44 L7,50 L-7,50 Z", W1)
    arm += flat(ellipse_d(0, 56, 8, 8), SK) + flat("M3,50 C7,52 8,56 7,60 C5,63 2,64 0,64 C4,61 5,56 3,50 Z", SK1)
    add("chef_arm", -12, -4, 24, 70, arm, flat=True)
    # Sartén (mango hacia la mano en el origen) / Frying pan (handle towards the hand at the origin)
    pan = flat("M-3,0 L3,0 L3,-34 L-3,-34 Z", "#6a4430") + flat("M1,0 L3,0 L3,-34 L1,-34 Z", "#4a2e22")
    pan += flat(ellipse_d(0, -56, 24, 24), "#4a4a66") + flat(ellipse_d(0, -56, 18, 18), "#1e1e30")
    pan += flat("M-14,-66 Q-8,-72 0,-73 L0,-70 Q-7,-69 -12,-64 Z", "#5a5a7a")
    pan += flat("M-20,-70 Q-14,-78 -4,-80 L-4,-77 Q-12,-76 -18,-68 Z", "#cfd6f6")
    add("chef_pan", -28, -84, 56, 88, pan, flat=True)
    # Cuchillo (apunta a la derecha) / Knife (points right)
    knife = flat("M-14,-3 L-2,-3 L-2,3 L-14,3 Z", "#4a2e22")
    knife += flat("M-2,-4 L14,-1 L16,0 L14,1 L-2,4 Z", "#dfe6ff") + flat("M-2,1 L14,1 L-2,4 Z", "#9aa2c0")
    add("shot_knife", -17, -6, 35, 12, knife, flat=True)
    plate = flat(ellipse_d(0, 0, 18, 8), "#f4f1fa") + flat("M-18,0 Q0,12 18,0 Q0,8 -18,0 Z", "#b8b0d8")
    plate += "<path d='%s' fill='none' stroke='#5b67c4' stroke-width='2.4'/>" % ellipse_d(0, -0.5, 11, 4.5)
    add("shot_plate", -21, -10, 42, 20, plate, flat=True)
    shards_ = ""
    for (x, y, r) in ((-22, -2, 20), (6, -6, -30), (20, 4, 50), (-6, 8, 10), (-30, 8, -60), (28, -8, 80)):
        shards_ += "<g transform='translate(%d,%d) rotate(%d)'>%s</g>" % (x, y, r, flat("M-6,-3 L6,-4 L2,4 Z", "#f4f1fa") + flat("M2,4 L6,-4 L4,-1 Z", "#b8b0d8"))
    add("plate_shards", -40, -16, 80, 32, shards_, flat=True)

def mr_ad():
    """Mr. Ad en pixel art de verdad (modo flat): un robot anunciante medio roto y demacrado. Cabeza
    de chapa abollada con la pegatina de patatas medio despegada, ojos-pantalla con «$» (uno rajado),
    antena doblada, cables sueltos, cuerpo oxidado lleno de pegatinas con una pantalla rajada en la
    barriga (los anuncios pasan por ella en el juego, con la tira "ad_strip"), un brazo aún
    envuelto en publicidad y el otro mecánico al descubierto, y piernas desparejadas.
    Mr. Ad in real pixel art (flat mode): a half-broken, worn-out advertising robot. A dented tin
    head with a half-peeled crisp sticker, screen eyes with "$" (one cracked), a bent antenna, loose
    wires, a rusty body covered in stickers with a cracked screen in his belly (the ads scroll
    across it in game, using the "ad_strip" sprite), one arm still wrapped in adverts and the
    other bare and mechanical, and mismatched legs."""
    M1, M2, M3, M4 = "#3e4258", "#6a7090", "#9aa2c0", "#c8cee4"
    RU1, RU2 = "#7a3a20", "#b0602e"
    P1, P2, P3 = "#c9902a", "#f6c24a", "#ffe08a"
    R1, R2 = "#a83246", "#e8455a"
    T1, T2 = "#2a8f96", "#3fc1c9"
    FR, SCR = "#2a2838", "#0d1a2a"
    WH, WH1, BLU = "#f4f1fa", "#c8c4d8", "#3fa8ff"
    HOLE, PINK, POLE = "#1a1020", "#ff4f8a", "#cfc8ec"
    CRACK = "#e8ecff"
    b = ""
    # Mástil con banderín roto / Pole with a torn pennant
    b += flat("M136,36 L140,36 L140,150 L136,150 Z", POLE)
    b += flat("M140,38 L184,48 L172,52 L182,58 L164,60 L140,64 Z", PINK) + flat("M140,56 L164,60 L140,64 Z", "#c8306a")
    # Pierna izquierda: tubo de metal con rodilla al aire / Left leg: a metal tube with a bare knee joint
    b += flat("M80,208 L96,208 L96,276 L80,276 Z", M2) + flat("M90,208 L96,208 L96,276 L90,276 Z", M1)
    b += flat("M82,210 L85,210 L85,272 L82,272 Z", M3)
    b += flat(ellipse_d(88, 240, 9, 7), M1) + flat(ellipse_d(87, 239, 5, 4), M3)
    b += flat("M74,274 L100,274 L102,288 L72,288 Z", M1) + flat("M74,274 L100,274 L100,278 L74,278 Z", M2)
    # Pierna derecha con el calcetín de rayas roto y una zapatilla amarilla / Right leg with a torn striped sock and a yellow trainer
    b += flat("M104,208 L121,208 L121,276 L104,276 Z", WH) + flat("M116,208 L121,208 L121,276 L116,276 Z", WH1)
    for y, c in ((222, R2), (236, BLU), (250, R2)):
        b += flat("M104,%g L121,%g L121,%g L104,%g Z" % (y, y, y + 5, y + 5), c)
    b += flat("M108,256 L116,254 L114,262 L106,263 Z", M2)
    b += flat("M100,274 L120,274 C126,274 128,280 128,288 L100,288 Z", P2) + flat("M100,284 L128,284 L128,288 L100,288 Z", P1)
    # Brazo izquierdo aún envuelto en publicidad / Left arm still wrapped in adverts
    b += flat("M52,108 L68,104 L74,182 L56,184 Z", T2) + flat("M62,106 L68,104 L74,182 L66,183 Z", T1)
    b += "".join("<path d='M53,%g L71,%g' stroke='%s' stroke-width='2.6'/>" % (y, y - 3, WH) for y in (124, 144, 164))
    b += flat("M54,150 L62,146 L60,156 Z", M3)
    b += flat(ellipse_d(64, 190, 8, 8), M3) + flat("M60,194 L68,194 L67,198 L61,198 Z", M1)
    # Brazo derecho mecánico al descubierto, con un cable colgando y pinza / Bare mechanical right arm, a dangling wire and a claw
    b += flat("M132,106 L146,108 L144,142 L132,142 Z", M2) + flat("M140,108 L146,108 L144,142 L140,142 Z", M1)
    b += flat(ellipse_d(139, 146, 8, 7), M1) + flat(ellipse_d(138, 145, 4, 3.5), RU2)
    b += flat("M133,150 L145,150 L143,182 L135,182 Z", M3) + flat("M140,150 L145,150 L143,182 L140,182 Z", M2)
    b += "<path d='M144,148 C152,156 150,170 146,178' fill='none' stroke='%s' stroke-width='2.4'/>" % R2
    b += flat("M132,182 L138,182 L136,196 L130,192 Z", M1) + flat("M140,182 L146,182 L148,192 L142,196 Z", M1)
    # Cuerpo de chapa oxidada / Rusty tin body
    b += flat("M64,98 L136,98 L140,212 L60,212 Z", M2)
    b += flat("M122,98 L136,98 L140,212 L128,212 C130,170 128,130 122,98 Z", M1)
    b += flat("M67,102 L74,102 L70,206 L63,206 Z", M3)
    b += flat("M64,198 L140,198 L140,212 L60,212 Z", M1)
    b += flat(ellipse_d(84, 190, 7, 4), RU1) + flat(ellipse_d(83, 189, 4, 2), RU2)
    b += flat(ellipse_d(126, 168, 4, 6), RU1)
    for (rx, ry) in ((70, 104), (130, 104), (66, 204), (134, 204)):
        b += flat(ellipse_d(rx, ry, 2, 2), M4)
    # Pegatinas de anuncios medio despegadas / Half-peeled advert stickers
    b += flat("M72,160 L98,158 L100,176 L74,178 Z", P2) + flat("M90,158 L98,158 L100,166 L92,168 Z", P3)
    b += "<path d='M78,166 L94,165 M78,171 L90,170' stroke='%s' stroke-width='2.2'/>" % R1
    b += "<g transform='rotate(12 118 182)'>%s</g>" % flat("M106,174 L130,174 L130,190 L106,190 Z", PINK)
    b += flat("M108,190 L118,186 L116,196 Z", "#ffb0d0")
    # Pantalla rajada en la barriga / Cracked screen in the belly
    b += flat("M71,114 L129,114 L129,156 L71,156 Z", FR) + flat("M75,118 L125,118 L125,152 L75,152 Z", SCR)
    b += flat("M96,108 L104,108 L104,114 L96,114 Z", M1)
    # Cables sueltos en el cuello / Loose wires at the neck
    b += flat("M90,90 L110,90 L110,100 L90,100 Z", M1)
    b += "<path d='M94,92 C88,98 86,104 90,108' fill='none' stroke='%s' stroke-width='2.6'/>" % R2
    b += "<path d='M106,92 C112,98 114,102 110,106' fill='none' stroke='%s' stroke-width='2.6'/>" % BLU
    # Cabeza de chapa abollada / Dented tin head
    b += flat("M74,44 L82,38 L126,38 L126,92 L74,92 Z", M2)
    b += flat("M116,38 L126,38 L126,92 L118,92 C121,76 120,56 116,38 Z", M1)
    b += flat("M77,46 L82,42 L82,88 L77,88 Z", M3)
    b += flat("M96,38 L104,44 L110,38 Z", M1)
    b += flat("M85,80 L115,80 L115,88 L85,88 Z", M1)
    b += "".join("<path d='M%g,81 L%g,87' stroke='%s' stroke-width='2'/>" % (x, x, M3) for x in (90, 96, 102, 108))
    for (rx, ry) in ((78, 50), (122, 50), (78, 86), (122, 86)):
        b += flat(ellipse_d(rx, ry, 1.8, 1.8), M4)
    # Pegatina de la bolsa de patatas medio despegada / Half-peeled crisp-bag sticker
    b += flat("M104,40 L126,40 L126,52 L114,56 L104,50 Z", P2) + flat("M114,56 L126,52 L122,60 Z", P3)
    b += "<path d='M107,45 L122,45' stroke='%s' stroke-width='2'/>" % R1
    # Ojos-pantalla (los «$» se pintan después) / Screen eyes (the "$" is painted afterwards)
    b += flat("M80,53 L96,53 L96,72 L80,72 Z", FR) + flat("M104,53 L120,53 L120,72 L104,72 Z", FR)
    b += flat("M81,54 L95,54 L95,71 L81,71 Z", HOLE) + flat("M105,54 L119,54 L119,71 L105,71 Z", HOLE)
    # Antena doblada / Bent antenna
    b += "<path d='M86,38 L84,26 L74,20' fill='none' stroke='%s' stroke-width='2.6'/>" % M3
    b += flat(ellipse_d(73, 19, 3.5, 3.5), R1)

    def dollar_eyes(img, to_px):
        """Ojos de «$» pintados píxel a píxel; el derecho, rajado / "$" eyes painted pixel by pixel; the right one, cracked."""
        pix = img.load()
        w, h = img.size
        glyph = ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."]
        for ex, ey in ((88, 62.5), (112, 62.5)):
            cx, cy = to_px(ex, ey)
            x0, y0 = int(round(cx - 2.5)), int(round(cy - 3.5))
            for gy, row in enumerate(glyph):
                for gx, ch in enumerate(row):
                    if ch == "#" and 0 <= x0 + gx < w and 0 <= y0 + gy < h:
                        pix[x0 + gx, y0 + gy] = (255, 224, 74, 255)
        # Grieta en el ojo derecho y en la pantalla de la barriga / Crack in the right eye and in the belly screen
        crack = (232, 236, 255, 255)
        for (sx, sy, pts) in ((106, 55, [(0, 0), (1, 1), (2, 1), (3, 2), (3, 3), (4, 4), (4, 5)]),
                              (118, 120, [(0, 0), (-1, 1), (-1, 2), (-2, 3), (-3, 3), (-3, 4), (-4, 5), (-4, 6), (-5, 7)])):
            px0, py0 = to_px(sx, sy)
            for dx, dy in pts:
                x, y = int(round(px0)) + dx, int(round(py0)) + dy
                if 0 <= x < w and 0 <= y < h:
                    pix[x, y] = crack
    add("npc_ad", 46, 12, 144, 280, b, px=PX_NPC, flat=True, post=dollar_eyes)

    # Tira de anuncios inventados que pasa por la pantalla (6 paneles de 50 x 34)
    # Strip of made-up adverts scrolling across the screen (6 panels of 50 x 34)
    st = ""
    panels = [
        ("#e8455a", "choco"), ("#f6c24a", "burger"), ("#3fa8ff", "soda"),
        ("#ff9a3a", "papas"), ("#ff7ab8", "donut"), ("#5fd08a", "2x1"),
    ]
    for n, (bg, kind) in enumerate(panels):
        x = n * 50
        st += flat("M%g,0 L%g,0 L%g,34 L%g,34 Z" % (x, x + 50, x + 50, x), bg)
        st += flat("M%g,0 L%g,0 L%g,4 L%g,4 Z" % (x, x + 50, x + 50, x), "#fff6c9")
        cx = x + 25
        if kind == "choco":
            st += flat("M%g,10 L%g,10 L%g,28 L%g,28 Z" % (cx - 14, cx + 14, cx + 14, cx - 14), "#6a3a22")
            st += "<path d='M%g,10 L%g,28 M%g,10 L%g,28 M%g,19 L%g,19' stroke='#3e1e10' stroke-width='2.4'/>" % (cx - 5, cx - 5, cx + 5, cx + 5, cx - 14, cx + 14)
            st += flat("M%g,22 L%g,22 L%g,30 L%g,30 Z" % (cx - 16, cx + 16, cx + 16, cx - 16), "#f6c24a")
        elif kind == "burger":
            st += flat("M%g,18 Q%g,6 %g,18 Z" % (cx - 15, cx, cx + 15), "#c9802a")
            st += flat("M%g,18 L%g,18 L%g,22 L%g,22 Z" % (cx - 16, cx + 16, cx + 16, cx - 16), "#5fd08a")
            st += flat("M%g,22 L%g,22 L%g,26 L%g,26 Z" % (cx - 15, cx + 15, cx + 15, cx - 15), "#6a3a22")
            st += flat("M%g,26 L%g,26 Q%g,31 %g,26 Z" % (cx - 14, cx + 14, cx, cx - 14), "#c9802a")
        elif kind == "soda":
            st += flat("M%g,8 L%g,8 L%g,30 L%g,30 Z" % (cx - 8, cx + 8, cx + 8, cx - 8), "#f4f1fa")
            st += flat("M%g,13 L%g,13 L%g,24 L%g,24 Z" % (cx - 8, cx + 8, cx + 8, cx - 8), "#e8455a")
            st += flat("M%g,6 L%g,6 L%g,8 L%g,8 Z" % (cx - 5, cx + 5, cx + 5, cx - 5), "#c8c4d8")
        elif kind == "papas":
            st += flat("M%g,8 L%g,8 L%g,30 L%g,30 Z" % (cx - 11, cx + 11, cx + 13, cx - 13), "#f6c24a")
            st += flat(ellipse_d(cx, 19, 6, 6), "#e8455a")
            st += "<path d='M%g,8 L%g,6 L%g,8 L%g,6 L%g,8' fill='none' stroke='#c9902a' stroke-width='2'/>" % (cx - 11, cx - 5, cx, cx + 5, cx + 11)
        elif kind == "donut":
            st += flat(ellipse_d(cx, 19, 13, 11), "#c9802a") + flat(ellipse_d(cx, 17, 12, 9), "#ffd0e8")
            st += flat(ellipse_d(cx, 18, 4, 3.5), "#ff7ab8")
            st += "".join("<path d='M%g,%g L%g,%g' stroke='%s' stroke-width='2'/>" % (cx + dx, 12 + dy, cx + dx + 2, 13 + dy, c)
                          for dx, dy, c in ((-8, 0, "#3fa8ff"), (5, -1, "#5fd08a"), (-2, 8, "#f6c24a"), (7, 6, "#e8455a")))
        else:
            st += ("<text x='%g' y='28' font-family='Arial Black,Arial' font-weight='900' font-size='22' fill='#fff6c9' "
                   "text-anchor='middle'>2x1</text>" % cx)
    add("ad_strip", 0, 0, 300, 34, st, px=PX_NPC, flat=True, outline="#000000")


def pinche():
    """El Pinche en pixel art de verdad (modo flat): chaval aprendiz de cocina, pelirrojo y con
    pecas, gorro de papel, chaquetilla blanca, pañuelo rojo, delantal de rayas, pantalón de
    cuadros, un cuchillo en una mano y el soplete de cocina en la otra (la llama se anima en el juego).
    The Kitchen Boy in real pixel art (flat mode): a red-haired, freckled young kitchen apprentice
    with a paper hat, white chef's jacket, red neckerchief, striped apron, check trousers, a knife
    in one hand and the kitchen blowtorch in the other (the flame is animated in game)."""
    W1, W2, W3 = "#a9a6c8", "#dcdaee", "#f8f7ff"
    B1, B2 = "#2f5fae", "#4f7fd0"
    RED, RED1 = "#e2434f", "#a82a36"
    PC, CHK = "#e9e6f2", "#1e1f2e"
    SHO = "#2a2238"
    S, S1, FREC = "#f0c8a8", "#c9957e", "#c47a5a"
    HA1, HA2, HA3 = "#8a3e1a", "#c8622e", "#e08a4a"
    BLADE, BLADE1, HANDLE = "#dfe6ff", "#9aa2c0", "#4a2e22"
    TR, TR1, NOZ = "#e2434f", "#a82a36", "#8f8fb8"
    b = ""
    # Pantalón de cuadros de cocina / Kitchen check trousers
    for x in (82, 102):
        b += flat("M%g,186 L%g,186 L%g,274 L%g,274 Z" % (x, x + 16, x + 16, x), PC)
        for y in range(190, 272, 8):
            for dx in ((0, 8) if (y // 8) % 2 == 0 else (4, 12)):
                b += flat("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (x + dx, y, x + dx + 4, y, x + dx + 4, y + 4, x + dx, y + 4), CHK)
        b += flat("M%g,274 L%g,274 C%g,274 %g,280 %g,288 L%g,288 Z" % (x - 2, x + 14, x + 19, x + 21, x + 21, x - 2), SHO)
    # Chaquetilla blanca / White chef's jacket
    b += flat("M80,96 L120,96 L140,108 L138,196 L62,196 L60,108 Z", W2)
    b += flat("M120,96 L140,108 L138,196 L124,196 C128,160 128,122 116,98 Z", W1)
    b += flat("M64,112 C66,106 70,101 76,99 L76,104 C72,106 69,110 67,116 Z", W3)
    for y in (116, 132, 148):
        b += flat(ellipse_d(92, y, 2.4, 2.4), "#2b2945") + flat(ellipse_d(108, y, 2.4, 2.4), "#2b2945")
    # Delantal de rayas / Striped apron
    b += flat("M68,150 L132,150 L134,212 L66,212 Z", B2)
    b += "".join(flat("M%g,150 L%g,150 L%g,212 L%g,212 Z" % (x, x + 3, x + 3, x), W3) for x in range(72, 132, 9))
    b += flat("M120,150 L132,150 L134,212 L122,212 Z", B1)
    b += "<path d='M68,150 L132,150' stroke='%s' stroke-width='3'/>" % B1
    # Pañuelo rojo al cuello / Red neckerchief
    b += flat("M86,96 L114,96 L100,114 Z", RED) + flat("M100,96 L114,96 L100,114 Z", RED1)
    # Brazos / Arms
    b += flat("M60,108 L74,112 L72,170 L58,168 Z", W2) + flat("M62,112 L66,112 L64,164 L60,164 Z", W3)
    b += flat("M140,108 L126,112 L130,156 L144,152 Z", W1)
    # Cuchillo en la mano izquierda: la mano agarra el mango / Knife in the left hand: the hand grips the handle
    b += flat("M61,178 L69,178 L67,148 Q64,142 62,150 Z", BLADE) + flat("M65,178 L69,178 L67,148 Q66,146 65,148 Z", BLADE1)
    b += flat("M61,178 L69,178 L69,196 L61,196 Z", HANDLE)
    b += flat(ellipse_d(65, 180, 7, 7), S) + flat("M65,187 C69,186 72,183 72,180 L68,180 C68,183 67,184 64,185 Z", S1)
    # Soplete en la mano derecha / Blowtorch in the right hand
    b += flat("M132,150 L150,150 L150,176 L132,176 Z", TR) + flat("M144,150 L150,150 L150,176 L144,176 Z", TR1)
    b += flat("M136,140 L146,140 L146,150 L136,150 Z", "#3a3a52")
    b += flat("M140,132 L160,128 L160,134 L142,140 Z", NOZ)
    b += flat(ellipse_d(138, 160, 7, 7), S) + flat("M138,167 C142,166 145,163 145,160 L141,160 C141,163 140,164 137,165 Z", S1)
    # Cuello y cabeza / Neck and head
    b += flat("M93,82 L107,82 L107,98 L93,98 Z", S1)
    b += flat(ellipse_d(100, 62, 22, 25), S)
    b += flat("M110,40 C117,46 122,53 122,62 C122,75 115,84 106,87 C112,79 115,71 115,62 C115,53 113,46 110,40 Z", S1)
    for (fx, fy) in ((88, 72), (92, 75), (85, 75), (110, 72), (114, 75), (108, 75)):
        b += flat(ellipse_d(fx, fy, 1.3, 1.3), FREC)
    # Pelo pelirrojo revuelto asomando del gorro / Messy red hair poking out of the hat
    b += flat("M77,58 Q76,40 90,36 L112,36 Q126,40 124,58 L118,48 L110,52 L104,46 L96,52 L88,46 L82,54 Z", HA2)
    b += flat("M112,36 Q126,40 124,58 L118,48 L114,50 C116,44 115,40 112,36 Z", HA1)
    b += flat("M80,50 C80,44 84,40 89,38 L90,41 C86,43 84,46 83,51 Z", HA3)
    b += flat("M75,58 L71,66 L78,62 Z", HA2) + flat("M125,56 L130,63 L123,61 Z", HA1)
    # Gorro de papel / Paper hat
    b += flat("M76,42 L124,42 L120,18 L80,18 Z", W2) + flat("M110,18 L120,18 L124,42 L114,42 Z", W1)
    b += flat("M80,20 L86,20 L83,40 L78,40 Z", W3)
    b += "<path d='M78,34 L122,34' stroke='%s' stroke-width='2.4'/>" % W1
    add("npc_pinche", 50, 12, 116, 280, b, px=PX_NPC, flat=True, post=npc_face(62, "#2a1d22", 1))


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
    global FLAT_SHADED
    FLAT_SHADED = True
    room()
    living_room()
    school_hall()
    drawings()
    FLAT_SHADED = False
    act2_npcs()
    act2_enemies()
    act3_enemies()
    cyberpunk()
    chef()
    mr_ad()
    pinche()
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
                if sp["ghost"]:
                    # Fantasma: cuerpo algo translúcido y contorno más suave / Ghost: slightly see-through body, softer outline
                    oc = rgb(sp["outline"])
                    gp = img.load()
                    for gy in range(img.size[1]):
                        for gx in range(img.size[0]):
                            c = gp[gx, gy]
                            if c[3]:
                                gp[gx, gy] = c[:3] + ((150,) if c[:3] == oc else (225,))
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
