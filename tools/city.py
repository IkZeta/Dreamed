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
    "cheese": dict(sky=("#8fd0ff", "#c8ecff", "#fff6d0"), far="#f2d35a", bld=("#f0a828", "#ffc83a", "#ffdc6a"),
                   win=("#7a4520", "#a85a28", "#fff2b0"), trim="#7a4520", road="#e8a85a", walk="#fff0b8", curb="#7a4520",
                   line="#fff6e0", car=("#ff9a3a", "#fff2b0"), lamp="#fff2b0", uni=("#f2c94c", "#e0702a", "#fff6e0"), van=("#f2c94c", "#e0702a")),
    "aero": dict(sky=("#2a9fe0", "#8fe0ff", "#f4fdff"), far="#bfe8ff", bld=("#3aa8e8", "#5cc4f2", "#8ad8f8"),
                 win=("#1a7ac8", "#2ad0b0", "#ffffff"), trim="#2cc84a", road="#a8d8f0", walk="#d0ecf8", curb="#2cc84a",
                 line="#ffffff", car=("#4ac0f0", "#ffffff"), lamp="#ffffff", uni=("#f4fbff", "#4ac0f0", "#5fd07a"), van=("#f4fbff", "#4ac0f0")),
    "solarpunk": dict(sky=("#6ac0d8", "#bfe8d8", "#fff0c0"), far="#a8d8b8", bld=("#f2ece0", "#e0d8c8", "#ffffff"),
                      win=("#2a5a8a", "#3a7aa8", "#bfe8ff"), trim="#4fa85a", road="#8aa878", walk="#d8d0b8", curb="#4fa85a",
                      line="#f6e2a0", car=("#4fa85a", "#f6e2a0"), lamp="#f6e2a0", uni=("#3f7a4a", "#f6d993", "#e8f0d8"), van=("#e8f0d8", "#3f7a4a")),
    "dieselpunk": dict(sky=("#1a1014", "#5a2418", "#c86a2a"), far="#2a2024", bld=("#3a2c2c", "#4a3634", "#2e3a3c"),
                       win=("#ffd27a", "#ffb04a", "#fff0c0"), trim="#e0b53a", road="#3a3430", walk="#4e4844", curb="#e0b53a",
                       line="#e0b53a", car=("#5a1e1e", "#c9961e"), lamp="#ffd27a", uni=("#3a3a2e", "#c83a2a", "#c9961e"), van=("#2e2a30", "#c83a2a")),
    "brutalist": dict(sky=("#6a7080", "#9aa0ac", "#c8ccd4"), far="#7a7e88", bld=("#7e7a74", "#928e86", "#a6a198"),
                      win=("#1e2026", "#2a2e38", "#f2c86a"), trim="#f2b632", road="#8a8680", walk="#b2aea6", curb="#f2b632",
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
            # Queso con agujeros grandes con fondo y brillo, chorreón de chocolate arriba
            # Cheese with big holes with depth and a gleam, a chocolate drip on top
            for i in range(int(w * h / 4200)):
                r = rng.uniform(10, 28)
                cx, cy = rng.uniform(x + r, x + w - r), rng.uniform(top + r + 30, bottom - r - 10)
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (cx, cy, r, r * 0.85, dark(col, 0.22))
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (cx + r * 0.12, cy + r * 0.15, r * 0.8, r * 0.62, dark(col, 0.42))
                b += "<path d='M%g,%g A%g,%g 0 0 1 %g,%g' fill='none' stroke='%s' stroke-width='3'/>" % (cx - r * 0.7, cy + r * 0.35, r, r * 0.85, cx + r * 0.7, cy + r * 0.35, light(col, 0.3))
            for wy in range(int(top + 60), bottom - 60, 80):
                for wx in range(int(x + 30), int(x + w - 50), 96):
                    b += "<rect x='%g' y='%g' width='40' height='44' rx='20' fill='%s'/>" % (wx, wy, "#5a2e14")
                    b += "<rect x='%g' y='%g' width='32' height='38' rx='16' fill='%s'/>" % (wx + 4, wy + 4, rng.choice(["#fff2b0", "#ffe08a"]))
                    b += R(wx + 4, wy + 22, 32, 3, "#5a2e14")
            choc = "#6a3818"
            d = "M%g,%g L%g,%g" % (x, top, x + w, top)
            pts = [(x, top)]
            for k in range(9):
                px = x + w * (k + 0.5) / 9
                pts += [(px - 10, top + 22), (px, top + 22 + (rng.uniform(10, 36) if k % 2 else 8)), (px + 10, top + 22)]
            pts += [(x + w, top + 22), (x + w, top)]
            b += P(pts, choc) + R(x, top, w, 6, "#8a5028")
            b += R(x, bottom - 14, w, 14, "#e8b468") + R(x, bottom - 14, w, 3, "#f4cc88")
        elif name == "aero":
            # Muro cortina de cristal con degradado, franjas brillantes, burbujas y remate verde
            # Glass curtain wall with a gradient, glossy bands, bubbles and a green top
            gid = "ag%d" % rng.randint(0, 99999)
            b += ("<defs><linearGradient id='%s' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='%s'/>"
                  "<stop offset='1' stop-color='%s'/></linearGradient></defs>") % (gid, light(col, 0.25), dark(col, 0.2))
            b += "<rect x='%g' y='%g' width='%g' height='%g' fill='url(#%s)'/>" % (x, top, w, h, gid)
            for mx in range(int(x + 40), int(x + w), 52):
                b += R(mx, top, 4, h, "#ffffff")
            for wy in range(int(top + 40), bottom - 20, 44):
                b += R(x, wy, w, 5, "#1a6aa8") + R(x, wy + 5, w, 2, "#ffffff")
            b += "<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#ffffff' opacity='0.4'/>" % (x + 10, top, x + 70, top, x + 20, bottom, x - 40, bottom)
            b += "<path d='M%g,%g L%g,%g L%g,%g L%g,%g Z' fill='#ffffff' opacity='0.25'/>" % (x + 120, top, x + 140, top, x + 90, bottom, x + 70, bottom)
            for i in range(3):
                bx, by, r = rng.uniform(x + 20, x + w - 20), rng.uniform(top + 30, bottom - 40), rng.uniform(8, 16)
                b += "<circle cx='%g' cy='%g' r='%g' fill='#ffffff' opacity='0.25' stroke='#ffffff' stroke-width='2'/>" % (bx, by, r)
                b += C(bx - r * 0.35, by - r * 0.35, r * 0.25, "#ffffff")
            b += "<rect x='%g' y='%g' width='%g' height='18' rx='9' fill='%s'/>" % (x + 6, top + 2, w - 12, st["trim"])
            b += "<rect x='%g' y='%g' width='%g' height='5' rx='3' fill='#c8ffd0'/>" % (x + 16, top + 5, w - 32)
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
            # Art déco: zócalo de piedra crema, pilastras con remate dorado, ventanas altas con luz cálida,
            # sol naciente dorado arriba y estandartes rojos colgando
            # Art deco: cream stone base, pilasters with gold caps, tall warmly lit windows, a gold rising
            # sun on top and red banners hanging
            gold, cream, red = st["trim"], "#d8c8a8", "#b8302a"
            for fx in range(int(x + 12), int(x + w), 42):
                b += R(fx, top + 34, 10, h - 34, light(col, 0.16)) + R(fx, top + 34, 3, h - 34, light(col, 0.3))
                b += R(fx - 2, top + 28, 14, 8, gold)
            for wy in range(int(top + 52), bottom - 40, 44):
                for wx in range(int(x + 26), int(x + w - 20), 42):
                    lit = rng.random() < 0.7
                    b += R(wx, wy, 22, 32, "#1a1210") + R(wx + 2, wy + 2, 18, 28, rng.choice(st["win"]) if lit else "#2a2220")
                    b += R(wx + 10, wy + 2, 2, 28, "#1a1210") + R(wx + 2, wy + 14, 18, 2, "#1a1210")
                    if lit:
                        b += R(wx + 3, wy + 3, 6, 10, "#fff8e0")
            # Banda superior con abanico dorado / Top band with a gold fan
            b += R(x, top, w, 28, dark(col, 0.25)) + R(x, top + 24, w, 4, gold) + R(x, top, w, 3, gold)
            cx = x + w / 2
            for k in range(9):
                a = math.pi + math.pi * (k + 0.5) / 9
                b += "<path d='M%g,%g L%g,%g' stroke='%s' stroke-width='4'/>" % (cx, top + 24, cx + math.cos(a) * 22, top + 24 + math.sin(a) * 20, gold)
            b += C(cx, top + 24, 8, gold)
            # Estandarte rojo con insignia / Red banner with an emblem
            if rng.random() < 0.7:
                bx = x + rng.choice([40, w - 70])
                b += P([(bx, top + 32), (bx + 30, top + 32), (bx + 30, top + 120), (bx + 15, top + 108), (bx, top + 120)], red)
                b += R(bx, top + 32, 30, 4, gold) + C(bx + 15, top + 62, 8, gold) + C(bx + 15, top + 62, 4, red)
            b += R(x, bottom - 22, w, 22, cream) + R(x, bottom - 22, w, 3, "#f0e4c8") + R(x, bottom - 6, w, 6, dark(cream, 0.3))
        elif name == "brutalist":
            # Hormigón con tablas de encofrado y agujeros de los latiguillos / Concrete with board marks and tie holes
            for by in range(int(top), bottom, 16):
                b += R(x, by, w, 2, dark(col, 0.1))
                for bx in range(int(x + 12), int(x + w), 40):
                    b += R(bx + (by // 16 % 2) * 20, by + 6, 3, 3, dark(col, 0.25))
            # Costillas verticales y ventanas muy hundidas, con su sombra / Vertical ribs and deep-set windows with their shadow
            for wy in range(int(top + 34), bottom - 50, 62):
                for wx in range(int(x + 22), int(x + w - 40), 56):
                    b += R(wx - 6, wy - 6, 42, 42, light(col, 0.12))
                    b += R(wx, wy, 30, 30, "#16181e")
                    b += R(wx, wy, 30, 9, "#0c0d10") + R(wx, wy, 6, 30, "#0c0d10")
                    if rng.random() < 0.3:
                        b += R(wx + 8, wy + 12, 18, 14, st["win"][2])
                    b += R(wx - 8, wy + 36, 46, 8, light(col, 0.2)) + R(wx - 8, wy + 44, 46, 3, dark(col, 0.35))
                    if rng.random() < 0.25:
                        for k in range(4):
                            b += C(wx - 4 + k * 12, wy + 46 + (k % 2) * 6, 5, rng.choice(["#4a7a3a", "#5a8a4a"]))
            for rx in range(int(x), int(x + w), 125):
                b += R(rx, top, 10, h, dark(col, 0.18)) + R(rx + 10, top, 3, h, light(col, 0.1))
            # Señalética amarilla pintada y voladizo / Painted yellow signage and an overhang
            b += R(x, top + 6, w, 22, light(col, 0.1)) + R(x, top + 28, w, 5, dark(col, 0.35))
            b += R(x + 14, top + 12, 40, 10, st["trim"]) + R(x + 60, top + 12, 10, 10, "#c83a3a")
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
            # Loncha de queso: canto suave y agujeros con sombra / Cheese slice: soft edge and shaded holes
            b += R(0, 0, T, 2, dark(walk, 0.08)) + R(0, 0, 2, T, dark(walk, 0.08))
            for i in range(2):
                r = rng.uniform(7, 13)
                cx, cy = rng.uniform(22, 100), rng.uniform(22, 100)
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (cx, cy, r, r * 0.7, dark(walk, 0.16))
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (cx + 1, cy + 2, r * 0.7, r * 0.45, dark(walk, 0.26))
        elif name == "aero":
            b += R(0, 0, T, 3, "#9cd0ec") + R(0, 0, 3, T, "#9cd0ec") + R(3, 3, T - 3, 3, "#ffffff") + R(3, 3, 3, T - 3, "#ffffff")
            b += "<ellipse cx='40' cy='34' rx='26' ry='8' fill='#ffffff' opacity='0.6'/>"
        elif name == "solarpunk":
            for (x, y) in ((0, 0), (60, 0), (0, 60), (60, 60)):
                b += "<rect x='%d' y='%d' width='56' height='56' rx='8' fill='%s'/>" % (x + 2, y + 2, light(walk, 0.06))
            b += R(56, 0, 8, T, "#7fcf7a") + R(0, 56, T, 8, "#7fcf7a")
        elif name == "dieselpunk":
            # Plancha de acero remachada, con óxido / Riveted steel plate, with rust
            b += R(0, 0, T, 4, dark(walk, 0.45)) + R(0, 0, 4, T, dark(walk, 0.45)) + R(4, 4, T - 4, 2, light(walk, 0.12))
            for k in range(8, T, 22):
                b += C(k, 12, 2.5, "#8a8078") + C(12, k, 2.5, "#8a8078")
            for i in range(2):
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='#7a4a2a' opacity='0.45'/>" % (rng.uniform(30, 100), rng.uniform(30, 100), rng.uniform(8, 16), rng.uniform(5, 9))
        elif name == "brutalist":
            # Losa grande con bisel, juntas y agujeros de encofrado / Big slab with a bevel, joints and formwork holes
            b += R(0, 0, T, 4, dark(walk, 0.3)) + R(0, 0, 4, T, dark(walk, 0.3)) + R(4, 4, T - 4, 3, light(walk, 0.12)) + R(4, 4, 3, T - 4, light(walk, 0.12))
            for (x, y) in ((24, 24), (100, 24), (24, 100), (100, 100)):
                b += C(x, y, 3, dark(walk, 0.3))
            for i in range(10):
                b += R(rng.uniform(8, 112), rng.uniform(8, 112), 3, 3, dark(walk, 0.1) if i % 2 else light(walk, 0.08))
        room_add("city_%s_pave" % name, 0, 0, T, T, b, colors=8, outline=None, tile=True)
        # Baldosa de la plaza (dibujo propio) / Plaza tile (own pattern)
        b = R(0, 0, T, T, road)
        if name == "synthwave":
            b += R(0, 0, T, 2, "#2a1c4e") + R(0, 0, 2, T, "#2a1c4e") + R(60, 60, 6, 6, "#5ff2ff")
        elif name == "steampunk":
            # Adoquín en espiga / Herringbone cobbles
            b += R(0, 0, T, T, dark("#7a5e48", 0.25))
            for gy in range(0, T, 25):
                for gx in range(0, T, 50):
                    o = (gy // 25) % 2 * 25
                    b += "<rect x='%d' y='%d' width='46' height='21' rx='5' fill='%s'/>" % ((gx + o) % T - 2, gy + 2, rng.choice(["#7a5e48", "#86684e", "#6e5440"]))
                    b += "<rect x='%d' y='%d' width='46' height='21' rx='5' fill='%s'/>" % ((gx + o) % T - 2 - T, gy + 2, rng.choice(["#7a5e48", "#86684e", "#6e5440"]))
        elif name == "cheese":
            # Galleta salada con agujeritos / Cracker with little holes
            b += R(0, 0, T, T, "#e8b468") + R(0, 0, T, 4, "#c8904a") + R(0, 0, 4, T, "#c8904a") + R(4, 4, T - 8, 3, "#f4cc88")
            for gy in range(22, T, 34):
                for gx in range(22, T, 34):
                    b += C(gx, gy, 3.5, "#b07a3a")
        elif name == "aero":
            b += R(0, 0, T, T, "#8ad0f0") + R(0, 0, T, 4, "#5ab4e0") + R(0, 0, 4, T, "#5ab4e0")
            b += R(4, 4, T - 4, 3, "#c8ecfa") + "<ellipse cx='44' cy='30' rx='30' ry='7' fill='#ffffff' opacity='0.45'/>"
        elif name == "solarpunk":
            b += R(0, 0, T, T, "#e8e0c8")
            b += R(0, 0, T, 3, "#cfc6a8") + R(0, 0, 3, T, "#cfc6a8") + "<ellipse cx='62' cy='62' rx='10' ry='5' fill='#9fd29a'/>"
        elif name == "dieselpunk":
            b += R(0, 0, T, T, "#3e3a3c")
            # Terrazo oscuro con cuadrante de sol dorado art déco / Dark terrazzo with an art deco gold sunburst quarter
            b += R(0, 0, T, T, "#2e2a2c")
            for i in range(40):
                b += R(rng.uniform(0, 122), rng.uniform(0, 122), 3, 3, rng.choice(["#4a4446", "#6a6062", "#8a7a5a"]))
            for k in range(6):
                a = math.pi / 2 * (k + 0.5) / 6
                b += "<path d='M0,0 L%g,%g' stroke='#4a3e30' stroke-width='3'/>" % (math.cos(a) * 60, math.sin(a) * 60)
            b += "<path d='M60,0 A60,60 0 0 1 0,60' fill='none' stroke='#6a5430' stroke-width='4'/>"
            b += R(0, 0, T, 2, "#7a6030") + R(0, 0, 2, T, "#7a6030")
        elif name == "brutalist":
            b += R(0, 0, T, T, "#8e8a84") + R(0, 0, T, 5, "#6a6660") + R(0, 0, 5, T, "#6a6660")
            b += R(5, 5, T - 5, 3, "#a29e96")
            for (x, y) in ((24, 24), (100, 24), (24, 100), (100, 100)):
                b += C(x, y, 3, "#5a5650")
            b += R(54, 54, 18, 18, "#f2b632") + R(54, 54, 18, 4, "#ffd878") + R(58, 58, 10, 10, "#2a2c34")
        room_add("city_%s_plaza" % name, 0, 0, T, T, b, colors=8, outline=None, tile=True)
        # Césped y flores / Grass and flowers
        gcol = {"cheese": "#a8c850", "synthwave": "#2a6a5a", "dieselpunk": "#3a5a3a", "brutalist": "#5a7a4a", "aero": "#3cd060"}.get(name, "#5fb86a")
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
        rng = random.Random(name + "props")
        b = "<ellipse cx='4' cy='0' rx='54' ry='15' fill='#000000' opacity='0.3'/>"
        # Tronco con raíces / Trunk with roots
        b += shaded("M-12,0 L-20,4 L-8,-4 L-9,-72 L9,-72 L8,-4 L20,4 L12,0 Z", trunk, rim=0.2)
        b += R(-3, -60, 3, 40, dark(trunk, 0.25))
        if name == "synthwave":
            # Palmera de neón con cocos / Neon palm with coconuts
            b += shaded("M-8,-70 Q-14,-110 -4,-150 L6,-150 Q-2,-110 8,-70 Z", trunk, rim=0.3)
            for k in range(6):
                b += R(-8 + k * 0.6, -80 - k * 12, 14, 3, dark(trunk, 0.3))
            for a in (-70, -35, 0, 35, 75, 115, 150):
                ang = math.radians(a - 90)
                ex, ey = math.cos(ang) * 64, -150 + math.sin(ang) * 46 + 24
                b += "<path d='M0,-152 Q%g,%g %g,%g' fill='none' stroke='%s' stroke-width='13' stroke-linecap='round'/>" % (ex * 0.5, -176 + math.sin(ang) * 30, ex, ey, dark(leaf, 0.25))
                b += "<path d='M0,-154 Q%g,%g %g,%g' fill='none' stroke='%s' stroke-width='7' stroke-linecap='round'/>" % (ex * 0.5, -178 + math.sin(ang) * 30, ex, ey - 2, leaf)
            b += C(-6, -146, 7, "#5ff2ff") + C(7, -144, 7, "#3ad0e0")
        elif name == "cheese":
            # Árbol de cuña de queso con agujeros / Cheese wedge tree with holes
            b += shaded("M-56,-62 L56,-62 L46,-80 L0,-182 Z", leaf, rim=0.3)
            b += P([(-56, -62), (56, -62), (56, -48), (-56, -48)], dark(leaf, 0.2))
            for (x, y, r) in ((-14, -100, 9), (16, -84, 7), (2, -130, 6), (-30, -74, 5), (26, -110, 5)):
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (x, y, r, r * 0.8, "#d8a020")
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (x + 1, y + 1.5, r * 0.6, r * 0.5, "#b07a10")
        elif name == "steampunk":
            # Árbol de engranajes / Clockwork tree
            for (x, y, r) in ((-24, -108, 34), (24, -104, 32), (0, -138, 36)):
                b += shaded(ellipse_d(x, y, r, r * 0.92), leaf, rim=0.3)
            b += "<circle cx='0' cy='-118' r='22' fill='none' stroke='#c9961e' stroke-width='7'/>"
            for k in range(8):
                a = k * math.pi / 4
                b += R(math.cos(a) * 26 - 4, -118 + math.sin(a) * 26 - 4, 8, 8, "#c9961e")
            b += C(0, -118, 6, "#f0c860")
        else:
            # Copa redonda de varias bolas con brillo y sombra / Round canopy of several clumps with light and shade
            clumps = ((-30, -96, 34), (30, -94, 34), (0, -82, 38), (-18, -128, 32), (20, -126, 32), (0, -150, 26))
            for (x, y, r) in clumps:
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (x, y + 4, r + 3, r * 0.92 + 3, dark(leaf, 0.35))
            for (x, y, r) in clumps:
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (x, y, r, r * 0.9, leaf)
            for (x, y, r) in clumps:
                b += "<ellipse cx='%g' cy='%g' rx='%g' ry='%g' fill='%s'/>" % (x - r * 0.25, y - r * 0.3, r * 0.5, r * 0.4, light(leaf, 0.16))
            for i in range(26):
                x, y = rng.uniform(-50, 50), rng.uniform(-160, -70)
                b += R(x, y, 5, 4, light(leaf, 0.3) if i % 2 else dark(leaf, 0.2))
            if name == "aero":
                b += C(-24, -140, 9, "#ffffff") + C(-16, -150, 4, "#ffffff")
            if name == "solarpunk":
                for i in range(6):
                    b += C(rng.uniform(-44, 44), rng.uniform(-150, -80), 5, "#ff7a6a" if i % 2 else "#ffd060")
            if name == "brutalist":
                # Seto cúbico podado / Clipped cube topiary
                b = "<ellipse cx='4' cy='0' rx='54' ry='15' fill='#000000' opacity='0.3'/>" + shaded(rect_d(-8, -50, 16, 50), trunk, rim=0.2)
                b += shaded(rect_d(-48, -150, 96, 100), leaf, rim=0.3) + R(-48, -150, 96, 12, light(leaf, 0.2)) + R(-48, -62, 96, 12, dark(leaf, 0.2))
        room_add("city_%s_tree" % name, -70, -196, 140, 214, b, colors=14)
        # Seto con hojitas y flores / Hedge with leaves and flowers
        hc = dark(leaf, 0.15) if name != "cheese" else "#e0a020"
        b = "<ellipse cx='4' cy='2' rx='64' ry='10' fill='#000000' opacity='0.25'/>"
        b += shaded("M-62,0 L62,0 L62,-44 Q52,-60 30,-56 Q14,-66 0,-58 Q-16,-66 -32,-56 Q-52,-60 -62,-44 Z", hc, rim=0.3)
        for i in range(18):
            x, y = rng.uniform(-56, 52), rng.uniform(-54, -10)
            b += R(x, y, 6, 4, light(hc, 0.22) if i % 2 else dark(hc, 0.22))
        if name in ("solarpunk", "aero", "cheese"):
            for i in range(4):
                b += C(rng.uniform(-50, 50), rng.uniform(-50, -24), 4, "#ffb0c8" if i % 2 else "#fff0a0")
        room_add("city_%s_hedge" % name, -68, -70, 136, 80, b, colors=8)
        # Farola: base, poste con anillos y farol de cada estética / Lamp: base, post with rings and each look's lantern
        pole = dark(st["walk"], 0.45)
        b = "<ellipse cx='4' cy='0' rx='22' ry='6' fill='#000000' opacity='0.3'/>"
        b += shaded("M-12,0 L12,0 L8,-16 L-8,-16 Z", pole, rim=0.3) + shaded(rect_d(-4, -196, 8, 182), pole, rim=0.3)
        b += R(-6, -120, 12, 6, light(pole, 0.2)) + R(-6, -60, 12, 6, light(pole, 0.2))
        lamp = st["lamp"]
        b += "<circle cx='0' cy='-208' r='30' fill='%s' opacity='0.25'/>" % lamp
        if name in ("steampunk", "dieselpunk", "brutalist"):
            b += shaded("M-14,-196 L14,-196 L10,-224 L-10,-224 Z", lamp, rim=0.5) + shaded("M-18,-224 L18,-224 L0,-238 Z", pole, rim=0.3)
            b += R(-1.5, -224, 3, 28, pole)
        elif name == "synthwave":
            b += shaded(rect_d(-20, -206, 40, 8), lamp, rim=0.5) + R(-24, -198, 48, 3, "#ff3aa0")
        else:
            b += shaded(ellipse_d(0, -210, 16, 14), lamp, rim=0.5) + C(-5, -215, 4, "#ffffff")
        room_add("city_%s_lamp" % name, -34, -244, 68, 252, b, colors=10)
        # Banco de listones / Slatted bench
        tc = st["trim"]
        b = "<ellipse cx='4' cy='0' rx='56' ry='8' fill='#000000' opacity='0.25'/>"
        for x in (-46, 38):
            b += shaded(rect_d(x, -30, 8, 30), "#2b2945", rim=0.2)
        for k in range(3):
            b += shaded(rect_d(-52, -60 + k * 9, 104, 7), tc, rim=0.25)
        for k in range(3):
            b += shaded(rect_d(-52, -30 + k * 8, 104, 7), light(tc, 0.08), rim=0.25)
        room_add("city_%s_bench" % name, -60, -66, 120, 74, b, colors=8)
        # Papelera / Litter bin
        b = "<ellipse cx='3' cy='0' rx='20' ry='6' fill='#000000' opacity='0.3'/>" + shaded("M-14,0 L14,0 L16,-44 L-16,-44 Z", dark(tc, 0.2), rim=0.3)
        b += R(-16, -48, 32, 6, dark(tc, 0.45)) + R(-10, -34, 3, 26, light(tc, 0.1)) + R(-2, -34, 3, 26, light(tc, 0.1)) + R(6, -34, 3, 26, light(tc, 0.1))
        room_add("city_%s_bin" % name, -24, -54, 48, 62, b, colors=6)
        # Máquina expendedora / Vending machine
        vc = {"cheese": "#e0702a", "solarpunk": "#4fa85a", "brutalist": "#c83a3a"}.get(name, st["curb"])
        b = "<ellipse cx='6' cy='0' rx='36' ry='8' fill='#000000' opacity='0.3'/>" + shaded(rect_d(-30, -104, 60, 104), vc, rim=0.35)
        b += R(-24, -96, 34, 62, "#1a2a3a")
        for r in range(4):
            for c in range(3):
                b += R(-21 + c * 11, -92 + r * 15, 8, 10, ["#ff6a6a", "#ffe36a", "#5ff2ff", "#7aff8a"][(r + c) % 4])
        b += R(14, -92, 10, 20, "#2a2c34") + R(16, -66, 6, 4, "#ffe36a") + R(-24, -24, 34, 12, "#1a1024")
        b += R(-24, -96, 6, 62, "#ffffff") .replace("fill='#ffffff'", "fill='#ffffff' opacity='0.25'")
        room_add("city_%s_vending" % name, -38, -112, 80, 120, b, colors=12)
        # Jardinera con flores / Flower planter
        b = "<ellipse cx='4' cy='0' rx='40' ry='8' fill='#000000' opacity='0.3'/>" + shaded(rect_d(-34, -30, 68, 30), light(st["walk"], 0.15) if name != "synthwave" else "#3a2466", rim=0.3)
        b += R(-34, -30, 68, 5, light(st["walk"], 0.35))
        for i in range(7):
            x = -26 + i * 8.6
            b += C(x, -38 - (i % 2) * 6, 9, dark(leaf, 0.1) if name not in ("cheese", "synthwave") else "#4fa85a")
        for i in range(5):
            b += C(-22 + i * 11, -44 - (i % 2) * 5, 4.5, ["#ff8fb0", "#ffd060", "#ffffff", "#c8a0ff", "#ff6a6a"][i])
        room_add("city_%s_planter" % name, -44, -60, 88, 68, b, colors=12)

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
