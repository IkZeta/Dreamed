#!/usr/bin/env python3
"""Genera la fuente pixel para el chino (assets/fonts/dreampix_zh.fnt/.png).
Builds the pixel font for Chinese (assets/fonts/dreampix_zh.fnt/.png).

Solo lleva los caracteres que usa la traducción (tools/i18n/zh.json) que no estén ya en
Dreampix: así ocupa poco. Cada carácter se rasteriza a 12 px desde Noto Sans CJK SC (licencia
SIL OFL 1.1) y se umbraliza a píxeles duros, para que encaje con el resto del pixel art. El juego
la usa como respaldo de Dreampix (UITheme), así que el latín sigue saliendo con la letra propia.
Hay que volver a generarla cada vez que cambie la traducción al chino.

It only holds the characters the translation (tools/i18n/zh.json) uses that aren't in Dreampix
already, so it stays small. Each character is rasterised at 12 px from Noto Sans CJK SC (SIL OFL
1.1 licence) and thresholded to hard pixels, to match the rest of the pixel art. The game uses it as
Dreampix's fallback (UITheme), so Latin text keeps our own letters. Rebuild it whenever the Chinese
translation changes.

    python3 tools/make_font_zh.py
"""
import json
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts")
SRC_FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
SRC_INDEX = 2            # Noto Sans CJK SC dentro del .ttc / Noto Sans CJK SC inside the .ttc
SIZE = 12
ROWS = 11                # alto de línea de Dreampix / Dreampix's line rows
BASE = 9
# Los caracteres chinos miden ~13 filas (de 11 por encima de la línea base a 2 por debajo): la
# celda es más alta y sube 2 filas (yoffset), para que la línea base coincida con la del latín
# Chinese characters are ~13 rows tall (11 above the baseline, 2 below): the cell is taller and
# moves up 2 rows (yoffset) so the baseline matches the Latin one
CELL = 13
CELL_BASE = 11
YOFF = BASE - CELL_BASE
THRESHOLD = 110


def wanted_chars():
    with open(os.path.join(ROOT, "tools", "i18n", "zh.json"), encoding="utf-8") as f:
        text = "".join(json.load(f).values())
    # Lo que Dreampix ya tiene no hace falta / Whatever Dreampix already has isn't needed
    with open(os.path.join(OUT, "dreampix.fnt"), encoding="utf-8") as f:
        have = {int(x) for x in re.findall(r"^char id=(\d+)", f.read(), re.M)}
    # Puntuación de ancho completo que conviene tener siempre / Full-width punctuation worth always having
    extra = "，。！？：；、“”‘’（）《》「」…—·～中文"
    chars = sorted({c for c in text + extra if ord(c) > 127 and ord(c) not in have and not c.isspace()})
    return chars


def render(font, ch):
    # Línea base en la fila 10: los caracteres chinos ocupan casi toda la altura (filas 0-10)
    # Baseline on row 10: Chinese characters fill nearly the whole height (rows 0-10)
    img = Image.new("L", (SIZE + 4, CELL + 2), 0)
    d = ImageDraw.Draw(img)
    d.text((0, CELL_BASE), ch, font=font, fill=255, anchor="ls")
    img = img.point(lambda v: 255 if v > THRESHOLD else 0)
    adv = int(round(font.getlength(ch)))
    w = max(1, min(SIZE, adv))
    grid = [[1 if img.getpixel((x, y)) else 0 for x in range(w)] for y in range(CELL)]
    return grid, adv


def main():
    font = ImageFont.truetype(SRC_FONT, SIZE, index=SRC_INDEX)
    chars = wanted_chars()
    cols = 32
    cw, ch_h = SIZE + 2, CELL + 2
    rows_n = (len(chars) + cols - 1) // cols
    W = 1
    while W < cols * cw:
        W *= 2
    H = 1
    while H < max(1, rows_n) * ch_h:
        H *= 2
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lines = []
    for i, c in enumerate(chars):
        grid, adv = render(font, c)
        gx, gy = (i % cols) * cw + 1, (i // cols) * ch_h + 1
        w = len(grid[0])
        for y in range(CELL):
            for x in range(w):
                if grid[y][x]:
                    sheet.putpixel((gx + x, gy + y), (255, 255, 255, 255))
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15" % (
            ord(c), gx, gy, w, CELL, YOFF, adv + 1))
    sheet.save(os.path.join(OUT, "dreampix_zh.png"))
    with open(os.path.join(OUT, "dreampix_zh.fnt"), "w", encoding="utf-8") as f:
        f.write('info face="dreampix_zh" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1\n' % (ROWS + 1))
        f.write("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0\n" % (ROWS + 2, BASE, W, H))
        f.write('page id=0 file="dreampix_zh.png"\n')
        f.write("chars count=%d\n" % len(lines))
        f.write("\n".join(lines) + "\n")
    print("%d caracteres / characters, %dx%d" % (len(chars), W, H))


if __name__ == "__main__":
    main()
