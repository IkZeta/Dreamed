"""La Metrópolis (Acto 4): siete estéticas de ciudad. Para cada una se dibuja el fondo de
edificios (1920 x 304, se repite de lado a lado), la calle (1920 x 742), un coche aparcado, una
farola, el rascacielos que se derrumba y su montón de escombros. Y también la furgo de la Unidad
Especial, los policías y los antidisturbios con el uniforme de cada ciudad.
The Metropolis (Act 4): seven city looks. For each one we draw the building backdrop (1920 x 304,
tiles side to side), the street (1920 x 742), a parked car, a street lamp, the skyscraper that
collapses and its pile of rubble. Plus the Special Unit van, the police officers and the riot
police in each city's uniform.

Lo llama tools/make_sprites.py / Called by tools/make_sprites.py
"""
import math
import random

WB = 300          # donde la pared toca el suelo / where the wall meets the floor
FLOOR_H = 742
PERIOD = 1920

# Paleta y motivos de cada estética / Palette and motifs of each look
STYLES = {
    "synthwave": dict(sky=("#1a0b3a", "#7a1e6e", "#ff5fa0"), far="#2a1450", bld=("#24124a", "#341a66", "#4a2a8a"),
                      win=("#5ff2ff", "#ff5fa0", "#ffe36a"), trim="#ff5fa0", road="#1c1236", walk="#2c1c4e", curb="#ff5fa0",
                      line="#5ff2ff", car=("#ff5fa0", "#5ff2ff"), lamp="#5ff2ff", uni=("#1e1f2e", "#ff3aa0", "#5ff2ff"), van=("#1e1f2e", "#ff3aa0")),
    "steampunk": dict(sky=("#3a2418", "#8a5430", "#e0a45a"), far="#5a3a28", bld=("#6a3e28", "#8a5436", "#a86a42"),
                      win=("#ffd27a", "#ffb04a", "#f6e2a0"), trim="#c9961e", road="#5a4636", walk="#7a5e48", curb="#c9961e",
                      line="#c9961e", car=("#8a5436", "#c9961e"), lamp="#ffb04a", uni=("#2a3456", "#c9961e", "#e8e0d0"), van=("#5a3a28", "#c9961e")),
    "cheese": dict(sky=("#8fd0ff", "#c8ecff", "#fff6d0"), far="#f2d35a", bld=("#f6c83a", "#ffd95a", "#ffe98a"),
                   win=("#e0a020", "#c88a10", "#fff2b0"), trim="#ff9a3a", road="#e8b830", walk="#ffd95a", curb="#ff9a3a",
                   line="#fff6e0", car=("#ff9a3a", "#fff2b0"), lamp="#fff2b0", uni=("#f2c94c", "#e0702a", "#fff6e0"), van=("#f2c94c", "#e0702a")),
    "aero": dict(sky=("#2a9fe0", "#8fe0ff", "#f4fdff"), far="#bfe8ff", bld=("#d8f2ff", "#a8e0f8", "#f8feff"),
                 win=("#4ac0f0", "#7fe0d0", "#ffffff"), trim="#5fd07a", road="#c8e4f0", walk="#e8f6fc", curb="#5fd07a",
                 line="#ffffff", car=("#4ac0f0", "#ffffff"), lamp="#ffffff", uni=("#f4fbff", "#4ac0f0", "#5fd07a"), van=("#f4fbff", "#4ac0f0")),
    "solarpunk": dict(sky=("#6ac0d8", "#bfe8d8", "#fff0c0"), far="#a8d8b8", bld=("#f2ece0", "#e0d8c8", "#ffffff"),
                      win=("#2a5a8a", "#3a7aa8", "#bfe8ff"), trim="#4fa85a", road="#8aa878", walk="#d8d0b8", curb="#4fa85a",
                      line="#f6e2a0", car=("#4fa85a", "#f6e2a0"), lamp="#f6e2a0", uni=("#3f7a4a", "#f6d993", "#e8f0d8"), van=("#e8f0d8", "#3f7a4a")),
    "dieselpunk": dict(sky=("#1a1014", "#5a2418", "#c86a2a"), far="#2a2024", bld=("#2e2a30", "#3e3840", "#58505a"),
                       win=("#ffd27a", "#e8a03a", "#fff0c0"), trim="#c9961e", road="#2a2628", walk="#3e3a3c", curb="#e0b53a",
                       line="#e0b53a", car=("#5a1e1e", "#c9961e"), lamp="#ffd27a", uni=("#3a3a2e", "#c83a2a", "#c9961e"), van=("#2e2a30", "#c83a2a")),
    "brutalist": dict(sky=("#6a7080", "#9aa0ac", "#c8ccd4"), far="#7a7e88", bld=("#8a8a8a", "#a0a0a0", "#b8b8b4"),
                      win=("#2a2c34", "#3a3e48", "#e8d8a0"), trim="#6a6a6a", road="#6e6e70", walk="#9a9a98", curb="#c8c8c4",
                      line="#e8e8e0", car=("#5a6a7a", "#c8c8c4"), lamp="#e8d8a0", uni=("#4a4e58", "#e8e8e0", "#c83a3a"), van=("#4a4e58", "#e8e8e0")),
}
ORDER = list(STYLES)


def build(ms):
    flat, rect_d, ellipse_d, mix, light, dark, shaded = ms.flat, ms.rect_d, ms.ellipse_d, ms.mix, ms.light, ms.dark, ms.shaded
    room_add, add = ms.room_add, ms.add

    def R(x, y, w, h, c):
        return "<rect x='%g' y='%g' width='%g' height='%g' fill='%s'/>" % (x, y, w, h, c)

    def C(x, y, r, c):
        return "<circle cx='%g' cy='%g' r='%g' fill='%s'/>" % (x, y, r, c)

    def P(pts, c):
        return "<path d='M%s Z' fill='%s'/>" % (" L".join("%g,%g" % p for p in pts), c)

    def facade(name, st, rng, x, top, w, h, col):
        bottom = top + h
        wins = st["win"]
        b = R(x, top, w, h, col)
        b += R(x, top, 6, h, dark(col, 0.25)) + R(x + w - 6, top, 6, h, light(col, 0.12))
        if name == "synthwave":
            b += "<rect x='%g' y='%g' width='%g' height='%g' fill='none' stroke='%s' stroke-width='3'/>" % (x + 3, top + 3, w - 6, h - 6, rng.choice([st["trim"], wins[0]]))
            for wy in range(int(top + 20), bottom - 40, 26):
                for wx in range(int(x + 16), int(x + w - 24), 24):
                    if rng.random() < 0.6:
                        b += R(wx, wy, 14, 12, rng.choice(wins))
            # Letrero de neón / Neon sign
            sx = x + w / 2 - 40
            b += R(sx, top + 30, 80, 26, "#140a2a") + "<rect x='%g' y='%g' width='80' height='26' fill='none' stroke='%s' stroke-width='3'/>" % (sx, top + 30, wins[1])
            b += R(sx + 10, top + 40, 60, 6, wins[0])
        elif name == "steampunk":
            for by in range(int(top), bottom, 12):
                off = 0 if (by // 12) % 2 else 14
                for bx in range(int(x + off), int(x + w), 28):
                    b += R(bx, by, 2, 12, dark(col, 0.2))
                b += R(x, by, w, 2, dark(col, 0.2))
            for wy in range(int(top + 26), bottom - 50, 46):
                for wx in range(int(x + 22), int(x + w - 40), 46):
                    b += R(wx, wy, 24, 30, "#2a1a14") + R(wx + 3, wy + 3, 18, 24, rng.choice(wins)) + R(wx + 11, wy + 3, 2, 24, "#2a1a14")
            # Tubería con engranaje / Pipe with a gear
            px = x + w - 30
            b += R(px, top - 20, 12, h + 20, st["trim"])
            gx, gy = x + 40, top + 20
            b += C(gx, gy, 18, st["trim"]) + C(gx, gy, 7, dark(st["trim"], 0.4))
            for k in range(8):
                a = k * math.pi / 4
                b += R(gx + math.cos(a) * 20 - 4, gy + math.sin(a) * 20 - 4, 8, 8, st["trim"])
            # Chimenea / Chimney
            b += R(x + w / 2 - 10, top - 40, 20, 40, dark(col, 0.3))
        elif name == "cheese":
            for i in range(int(w * h / 3000)):
                r = rng.uniform(6, 22)
                cx, cy = rng.uniform(x + r, x + w - r), rng.uniform(top + r, bottom - r)
                b += C(cx, cy, r, dark(col, 0.18)) + C(cx - r * 0.2, cy - r * 0.2, r * 0.75, dark(col, 0.3))
            # Tejado en cuña / Wedge roof
            b += P([(x, top), (x + w, top), (x + w * 0.5, top - 30)], light(col, 0.15))
            b += R(x, bottom - 10, w, 10, st["trim"])
        elif name == "aero":
            for wy in range(int(top + 10), bottom - 20, 30):
                b += R(x + 10, wy, w - 20, 20, wins[0] if (wy // 30) % 2 else wins[1])
                b += R(x + 10, wy, w - 20, 4, "#ffffff")
            # Brillo de cristal / Glass gloss
            b += "<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#ffffff' opacity='0.45'/>" % (x + 20, top, x + 60, top, x + 30, bottom, x - 10, bottom)
            b += "<rect x='%g' y='%g' width='%g' height='14' rx='7' fill='%s'/>" % (x + 14, top - 10, w - 28, st["trim"])
        elif name == "solarpunk":
            for wy in range(int(top + 20), bottom - 30, 44):
                for wx in range(int(x + 16), int(x + w - 30), 40):
                    b += "<rect x='%g' y='%g' width='26' height='28' rx='12' fill='%s'/>" % (wx, wy, rng.choice(wins))
                # Terraza con plantas / Terrace with plants
                b += R(x, wy + 32, w, 6, dark(col, 0.15))
                for px in range(int(x + 6), int(x + w - 10), 22):
                    b += C(px + 8, wy + 30, rng.uniform(7, 12), rng.choice(["#4fa85a", "#3f9a4a", "#7fcf7a"]))
            # Placas solares / Solar panels
            for px in range(int(x + 10), int(x + w - 40), 44):
                b += P([(px, top), (px + 36, top), (px + 44, top - 16), (px + 8, top - 16)], "#2a4a8a")
                b += "<path d='M%g,%g L%g,%g' stroke='#8fb8f0' stroke-width='2'/>" % (px + 4, top - 8, px + 40, top - 8)
        elif name == "dieselpunk":
            # Aletas verticales art déco / Art deco vertical fins
            for fx in range(int(x + 20), int(x + w - 10), 30):
                b += R(fx, top + 10, 8, h - 10, light(col, 0.1))
            for wy in range(int(top + 30), bottom - 30, 30):
                for wx in range(int(x + 30), int(x + w - 20), 30):
                    if rng.random() < 0.55:
                        b += R(wx, wy, 12, 14, rng.choice(wins))
            # Remate escalonado dorado / Gold stepped crown
            b += R(x + 20, top - 16, w - 40, 16, col) + R(x + 50, top - 34, w - 100, 18, col) + R(x + 20, top - 4, w - 40, 4, st["trim"])
        elif name == "brutalist":
            # Hormigón con marcas de encofrado / Concrete with formwork marks
            for by in range(int(top), bottom, 24):
                b += R(x, by, w, 2, dark(col, 0.12))
            for wy in range(int(top + 24), bottom - 40, 48):
                for wx in range(int(x + 20), int(x + w - 30), 44):
                    b += R(wx, wy, 22, 16, wins[0]) + R(wx, wy + 16, 22, 6, dark(col, 0.25))
                    if rng.random() < 0.12:
                        b += R(wx + 4, wy + 4, 14, 8, wins[2])
            # Voladizo / Overhang
            b += R(x - 10, top, w + 20, 18, light(col, 0.08)) + R(x - 10, top + 18, w + 20, 4, dark(col, 0.3))
        return b

    # --- Baldosas del suelo (120 x 120, casan por los cuatro lados) / Ground tiles (120 x 120, tile on all four sides) ---
    T = 125

    def tiles(name, st):
        rng = random.Random(name + "tiles")
        road, walk, line, trim = st["road"], st["walk"], st["line"], st["trim"]
        # Baldosa de calle / Street paving
        b = R(0, 0, T, T, walk)
        if name == "synthwave":
            b += R(0, 0, T, 3, "#3a2266") + R(0, 0, 3, T, "#3a2266") + R(0, 0, 14, 3, "#ff3aa0")
        elif name == "steampunk":
            for gy, y in enumerate(range(0, T, 20)):
                for x in range(-20 + (gy % 2) * 15, T, 30):
                    b += "<rect x='%d' y='%d' width='27' height='17' rx='6' fill='%s'/>" % (x, y + 1, rng.choice([walk, light(walk, 0.08), dark(walk, 0.1)]))
        elif name == "cheese":
            b += R(0, 0, T, 4, dark(walk, 0.15)) + R(0, 0, 4, T, dark(walk, 0.15))
            for i in range(3):
                r = rng.uniform(6, 14)
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (rng.uniform(20, 100), rng.uniform(20, 100), r, r * 0.7, dark(walk, 0.18))
        elif name == "aero":
            b += R(0, 0, T, 3, "#ffffff") + R(0, 0, 3, T, "#ffffff") + R(6, 6, 50, 6, "#ffffff")
        elif name == "solarpunk":
            for (x, y) in ((0, 0), (60, 0), (0, 60), (60, 60)):
                b += "<rect x='%d' y='%d' width='56' height='56' rx='8' fill='%s'/>" % (x + 2, y + 2, light(walk, 0.06))
            b += R(56, 0, 8, T, "#7fcf7a") + R(0, 56, T, 8, "#7fcf7a")
        elif name == "dieselpunk":
            b += R(0, 0, T, 3, dark(walk, 0.4)) + R(0, 0, 3, T, dark(walk, 0.4))
            for (x, y) in ((10, 10), (110, 10), (10, 110), (110, 110)):
                b += C(x, y, 3, "#6a6468")
        elif name == "brutalist":
            b += R(0, 0, T, 3, dark(walk, 0.2)) + R(0, 0, 3, T, dark(walk, 0.2))
            for i in range(6):
                b += R(rng.uniform(4, 110), rng.uniform(4, 110), 4, 4, dark(walk, 0.12))
        room_add("city_%s_pave" % name, 0, 0, T, T, b, colors=8, outline=None, tile=True)
        # Baldosa de la plaza (dibujo propio) / Plaza tile (own pattern)
        b = R(0, 0, T, T, road)
        if name == "synthwave":
            b += R(0, 0, T, 2, "#2a1c4e") + R(0, 0, 2, T, "#2a1c4e") + R(60, 60, 6, 6, "#5ff2ff")
        elif name == "steampunk":
            b += R(0, 0, T, T, "#7a5e48")
            for k in range(4):
                b += "<path d='M0,%d L%d,0' stroke='%s' stroke-width='6'/>" % (30 * k + 30, 30 * k + 30, dark("#7a5e48", 0.2))
            pass
        elif name == "cheese":
            b += R(0, 0, T, T, "#ffe98a") + R(0, 0, T, 6, "#ff9a3a") + R(0, 0, 6, T, "#ff9a3a")
        elif name == "aero":
            b += R(0, 0, T, T, "#e8f8ff") + R(0, 0, T, 3, "#c8ecff") + R(0, 0, 3, T, "#c8ecff") + "<circle cx='62' cy='62' r='8' fill='#bfe8ff'/>"
        elif name == "solarpunk":
            b += R(0, 0, T, T, "#e8e0c8")
            b += R(0, 0, T, 3, "#cfc6a8") + R(0, 0, 3, T, "#cfc6a8") + "<ellipse cx='62' cy='62' rx='10' ry='5' fill='#9fd29a'/>"
        elif name == "dieselpunk":
            b += R(0, 0, T, T, "#3e3a3c")
            for k in range(0, T, 20):
                b += R(k, 0, 10, T, "#4a4648")
            b += R(0, 56, T, 8, "#e0b53a")
        elif name == "brutalist":
            b += R(0, 0, T, T, "#a8a8a6") + R(0, 0, T, 4, "#8a8a88") + R(0, 0, 4, T, "#8a8a88") + R(40, 40, 40, 40, "#b8b8b4")
        room_add("city_%s_plaza" % name, 0, 0, T, T, b, colors=8, outline=None, tile=True)
        # Césped y flores / Grass and flowers
        gcol = {"cheese": "#c8d860", "synthwave": "#2a6a5a", "dieselpunk": "#3a5a3a", "brutalist": "#6a8a5a"}.get(name, "#5fb86a")
        b = R(0, 0, T, T, gcol)
        for i in range(14):
            x, y = rng.uniform(0, 112), rng.uniform(0, 112)
            b += R(x, y, 4, 8, light(gcol, 0.18)) + R(x + 3, y + 2, 3, 6, dark(gcol, 0.15))
        room_add("city_%s_grass" % name, 0, 0, T, T, b, colors=6, outline=None, tile=True)
        for i in range(10):
            x, y = rng.uniform(8, 104), rng.uniform(8, 104)
            col = rng.choice(["#ff8fb0", "#f6d993", "#ffffff", "#c8a0ff", "#ff6a6a"])
            b += C(x, y, 5, col) + C(x, y, 2, "#fff0a0")
        room_add("city_%s_flowers" % name, 0, 0, T, T, b, colors=10, outline=None, tile=True)
        # Agua (del color de cada sueño) / Water (in each dream's colour)
        wcol = {"cheese": "#ff9a3a", "synthwave": "#3a1a8a", "steampunk": "#3a5a6a", "dieselpunk": "#2a3a4a", "brutalist": "#5a7a8a"}.get(name, "#4ac0f0")
        b = R(0, 0, T, T, wcol)
        for i in range(5):
            x, y = rng.uniform(0, 100), rng.uniform(0, 110)
            b += R(x, y, 22, 3, light(wcol, 0.35))
        room_add("city_%s_water" % name, 0, 0, T, T, b, colors=6, outline=None, tile=True)
        # Tejado (casa por los lados) / Roof (tiles at the sides)
        rc = st["bld"][0]
        b = R(0, 0, T, T, dark(rc, 0.1))
        if name == "synthwave":
            b += R(30, 40, 20, 14, "#1a0b3a") + R(80, 90, 14, 10, "#5ff2ff")
        elif name == "steampunk":
            for y in range(0, T, 20):
                for x in range(-10 + (y // 20 % 2) * 15, T, 30):
                    b += "<path d='M%d,%d Q%d,%d %d,%d' fill='%s'/>" % (x, y + 20, x + 15, y, x + 30, y + 20, "#a86a42")
        elif name == "cheese":
            b += R(0, 0, T, T, "#f2c83a") + C(30, 40, 12, "#d8a020") + C(84, 80, 16, "#d8a020")
        elif name == "aero":
            b += R(0, 0, T, T, "#c8ecff") + R(0, 10, T, 14, "#ffffff")
        elif name == "solarpunk":
            b += R(0, 0, T, T, "#5fb86a") + R(14, 14, 44, 36, "#2a4a8a") + R(64, 70, 44, 36, "#2a4a8a") + "<path d='M14,32 L58,32 M64,88 L108,88' stroke='#8fb8f0' stroke-width='3'/>"
        elif name == "dieselpunk":
            b += R(0, 0, T, T, "#3a363c")
            for k in range(10, T, 25):
                b += C(k, 10, 3, "#6a6468") + C(k, 110, 3, "#6a6468")
        elif name == "brutalist":
            b += R(0, 0, T, T, "#9a9a98") + R(20, 20, 30, 24, "#7a7a78") + R(24, 24, 22, 4, "#5a5a58")
        room_add("city_%s_roof" % name, 0, 0, T, T, b, colors=8, outline=None, tile=True)
        # Fachadas (240 x 240, casan por los lados): ventanas, escaparate y la de la torre (240 x 360)
        # Facades (240 x 240, tile at the sides): windows, shop front and the tower's (240 x 360)
        rng2 = random.Random(name + "facade")
        room_add("city_%s_facade" % name, 0, 0, 250, 250, facade(name, st, rng2, 0, 0, 250, 250, st["bld"][1]), colors=14, outline=None, tile=True)
        shop = facade(name, st, rng2, 0, 0, 250, 250, st["bld"][2])
        shop += R(20, 120, 200, 100, "#1e1f2e") + R(26, 126, 188, 88, light(st["win"][0], 0.3)) + R(26, 126, 188, 10, "#ffffff")
        shop += "".join(R(20 + k * 25, 96, 25, 24, (trim if k % 2 else "#ffffff")) for k in range(8))
        room_add("city_%s_shopfront" % name, 0, 0, 250, 250, shop, colors=14, outline=None, tile=True)
        room_add("city_%s_facade_tall" % name, 0, 0, 250, 375, facade(name, st, rng2, 0, 0, 250, 375, st["bld"][0]), colors=14, outline=None, tile=True)
        # Puerta / Door
        b = shaded(rect_d(12, 30, 100, 170), dark(st["bld"][1], 0.4), rim=0.2) + shaded(rect_d(22, 40, 36, 160), "#bfe8ff", outline=False, rim=0.4)
        b += shaded(rect_d(66, 40, 36, 160), "#bfe8ff", outline=False, rim=0.4) + R(0, 18, 125, 14, trim)
        room_add("city_%s_door" % name, 0, 10, 125, 192, b, colors=8)

    # --- Árbol, seto, farola, banco, rascacielos y escombros / Tree, hedge, lamp, bench, skyscraper and rubble ---
    def props(name, st):
        trunk = {"steampunk": "#4a3a3a", "dieselpunk": "#3a3438", "brutalist": "#5a5a58"}.get(name, "#7a5236")
        leaf = {"synthwave": "#ff3aa0", "cheese": "#f6c83a", "aero": "#5fd07a", "steampunk": "#8a6a3a", "dieselpunk": "#4a6a4a",
                "brutalist": "#6a8a5a", "solarpunk": "#3f9a4a"}[name]
        b = "<ellipse cx='0' cy='0' rx='44' ry='12' fill='#000000' opacity='0.3'/>" + shaded(rect_d(-10, -70, 20, 70), trunk, rim=0.2)
        if name == "synthwave":
            # Palmera de neón / Neon palm
            for a in (-60, -25, 15, 50, 90, 130):
                ang = math.radians(a - 90)
                b += "<path d='M0,-80 Q%g,%g %g,%g' fill='none' stroke='%s' stroke-width='10' stroke-linecap='round'/>" % (math.cos(ang) * 30, -80 + math.sin(ang) * 40, math.cos(ang) * 60, -70 + math.sin(ang) * 50, leaf)
        elif name == "cheese":
            b += shaded("M-50,-60 L50,-60 L0,-170 Z", leaf, rim=0.3) + C(-10, -100, 8, "#d8a020") + C(14, -80, 6, "#d8a020")
        elif name == "steampunk":
            b += shaded(ellipse_d(0, -110, 48, 44), leaf, rim=0.3) + "<circle cx='0' cy='-110' r='18' fill='none' stroke='#c9961e' stroke-width='6'/>"
        else:
            b += shaded(ellipse_d(0, -104, 52, 46), leaf, rim=0.4) + shaded(ellipse_d(-14, -128, 30, 24), light(leaf, 0.12), outline=False, rim=0.3)
            if name == "aero":
                b += C(-20, -130, 8, "#ffffff")
        room_add("city_%s_tree" % name, -64, -180, 128, 196, b, colors=10)
        # Seto / Hedge
        b = shaded("M-60,0 L60,0 L60,-46 Q0,-62 -60,-46 Z", dark(leaf, 0.15) if name != "cheese" else "#e0a020", rim=0.3)
        room_add("city_%s_hedge" % name, -64, -64, 128, 72, b, colors=6)
        # Farola / Lamp
        b = R(-5, -200, 10, 200, dark(st["walk"], 0.45)) + R(-16, -4, 32, 6, dark(st["walk"], 0.5))
        b += shaded(ellipse_d(0, -206, 16, 12), st["lamp"], outline=True, rim=0.5)
        room_add("city_%s_lamp" % name, -22, -222, 44, 230, b, colors=8)
        # Banco / Bench
        b = R(-48, -8, 8, 8, "#2b2945") + R(40, -8, 8, 8, "#2b2945") + shaded(rect_d(-52, -30, 104, 22), st["trim"], rim=0.3) + shaded(rect_d(-52, -52, 104, 14), st["trim"], rim=0.3)
        room_add("city_%s_bench" % name, -56, -58, 112, 66, b, colors=6)
        rng = random.Random(name + "tower")
        # El rascacielos que se cae (de pie; en el juego se tumba) / The skyscraper that falls (standing; tipped over in game)
        rng = random.Random(name + "tower")
        col = st["bld"][1]
        b = facade(name, st, rng, -80, -560, 160, 560, col)
        room_add("city_%s_tower" % name, -100, -620, 200, 624, b, colors=14)
        # Escombros: trozos de su fachada amontonados / Rubble: chunks of its facade piled up
        b = "<ellipse cx='0' cy='0' rx='160' ry='30' fill='#000000' opacity='0.3'/>"
        for i in range(16):
            cx, cy = rng.uniform(-130, 130), rng.uniform(-70, -8)
            cy -= (1 - abs(cx) / 140) * 40
            w, h = rng.uniform(30, 70), rng.uniform(20, 44)
            ang = rng.uniform(-30, 30)
            chunk = shaded(rect_d(-w / 2, -h / 2, w, h), rng.choice(st["bld"]), rim=0.3)
            b += "<g transform='translate(%g,%g) rotate(%g)'>%s</g>" % (cx, cy, ang, chunk)
            if rng.random() < 0.4:
                b += R(cx - 6, cy - 6, 10, 8, rng.choice(st["win"]))
        b += "<path d='M-60,-100 L-40,-150 M40,-90 L70,-140' stroke='%s' stroke-width='5'/>" % dark(st["walk"], 0.4)
        room_add("city_%s_rubble" % name, -170, -160, 340, 196, b, colors=14)

    # --- Policía: casco, chaleco, fusil de asalto (escala de enemigo) / Police: helmet, vest, assault rifle (enemy scale) ---
    def police(name, st):
        u1, u2, u3 = st["uni"]
        S = "#f0c8a8"
        b = ""
        for x in (-12, 4):
            b += shaded(rect_d(x, -54, 10, 50), dark(u1, 0.15), rim=0.2) + shaded(rect_d(x - 2, -8, 14, 8), "#1e1f2e", rim=0.1)
        b += shaded("M-20,-104 L20,-104 L22,-50 L-22,-50 Z", u1, rim=0.3)
        b += shaded(rect_d(-16, -96, 32, 30), u2, rim=0.2)
        b += R(-12, -88, 10, 4, u3) + R(2, -80, 12, 3, u3)
        # Cabeza con el casco / Head with helmet
        b += shaded(ellipse_d(0, -118, 13, 14), S, rim=0.3)
        hats = {
            "steampunk": "M-12,-126 Q0,-152 12,-126 L16,-124 L-16,-124 Z",       # casco de bobby / bobby helmet
            "dieselpunk": "M-16,-126 L16,-126 L12,-138 L-12,-138 Z",             # gorra de plato / peaked cap
            "cheese": "M-15,-124 L15,-124 L0,-148 Z",                           # gorro en cuña / wedge cap
        }
        hat = hats.get(name, "M-15,-120 Q-16,-140 0,-140 Q16,-140 15,-120 L15,-114 L-15,-114 Z")
        b += shaded(hat, u2 if name in ("steampunk", "cheese") else u1, rim=0.4)
        if name in ("synthwave", "aero", "brutalist", "solarpunk"):
            b += shaded("M-12,-124 L12,-124 L12,-112 L-12,-112 Z", u3 if name != "brutalist" else "#2a2c34", outline=False, rim=0.5)
        # Fusil de asalto / Assault rifle
        b += shaded("M-4,-76 L44,-80 L44,-70 L-4,-66 Z", "#2b2945", rim=0.2) + R(20, -70, 6, 12, "#2b2945") + R(40, -79, 14, 4, "#2b2945")
        b += shaded(ellipse_d(-2, -72, 6, 6), S, outline=False, rim=0)
        add("police_%s" % name, -28, -156, 86, 158, b, flat=True)

    # --- Antidisturbios: armadura gruesa, casco con visera y un escudo enorme / Riot police: thick armour, visored helmet and a huge shield ---
    def riot(name, st):
        u1, u2, u3 = st["uni"]
        b = ""
        for x in (-18, 4):
            b += shaded(rect_d(x, -60, 14, 56), dark(u1, 0.2), rim=0.2) + shaded(rect_d(x - 2, -10, 18, 10), "#1e1f2e", rim=0.1)
        b += shaded("M-28,-124 L28,-124 L30,-56 L-30,-56 Z", dark(u1, 0.1), rim=0.3)
        b += shaded(rect_d(-30, -126, 18, 18), u2, rim=0.3) + shaded(rect_d(12, -126, 18, 18), u2, rim=0.3)
        b += shaded(ellipse_d(0, -142, 20, 20), u1, rim=0.4)
        b += shaded("M-16,-148 L16,-148 L16,-132 L-16,-132 Z", "#8fd8ff" if name != "dieselpunk" else "#c8a060", outline=False, rim=0.6)
        # El escudo, por delante / The shield, in front
        b += shaded("M10,-130 L54,-134 L56,-6 L12,-2 Z", "#c8e0f0" if name not in ("steampunk", "dieselpunk", "cheese") else u3, rim=0.6)
        b += R(16, -110, 34, 8, u2) + "<path d='M18,-60 L50,-62' stroke='%s' stroke-width='4'/>" % u2
        add("riot_%s" % name, -34, -166, 96, 168, b, flat=True)

    # --- Furgo de la Unidad Especial: blindada, flotando, con luces y puerta lateral ---
    # --- Special Unit van: armoured, hovering, with lights and a side door ---
    def van(name, st):
        v1, v2 = st["van"]
        b = shaded("M-110,-20 L110,-20 L116,-70 L90,-96 L-80,-96 L-112,-66 Z", v1, rim=0.4)
        b += shaded("M60,-90 L88,-90 L106,-70 L60,-70 Z", "#bfe8ff", outline=False, rim=0.5)
        b += R(-110, -56, 226, 10, v2)
        b += shaded(rect_d(-60, -86, 70, 56), dark(v1, 0.15), rim=0.2)          # puerta / door
        b += R(-54, -80, 58, 18, "#2a2c34")
        # Cruz/emblema de la unidad y luces del techo / Unit emblem and roof lights
        b += "<path d='%s' fill='#f6d24a'/>" % ms.star_d(33, -42, 13, 0.45)
        b += R(-40, -104, 22, 8, "#ff3a4a") + R(20, -104, 22, 8, "#3a8aff")
        # Turbinas debajo (vuela) / Turbines underneath (it flies)
        for x in (-70, 70):
            b += shaded(ellipse_d(x, -16, 30, 12), "#3a3e48", rim=0.3) + shaded(ellipse_d(x, -12, 18, 5), "#8fe0ff", outline=False, rim=0)
        add("van_%s" % name, -124, -114, 250, 120, b, flat=True)

    for name in ORDER:
        st = STYLES[name]
        tiles(name, st)
        props(name, st)
        police(name, st)
        riot(name, st)
        van(name, st)
