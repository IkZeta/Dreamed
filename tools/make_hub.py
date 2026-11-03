#!/usr/bin/env python3
"""Genera el terreno del plano astral (el lobby) píxel a píxel / Generates the astral plane's (lobby) terrain pixel by pixel.

Todo el plano es un archipiélago de islas flotantes hechas de la misma piedra astral: losas
irregulares (nada de cuadrícula), un borde que brilla con la luna, un acantilado con vetas y
una panza de roca con cristales del color de cada personaje. Encima de cada isla hay un trozo
del mundo de su personaje (césped, tatami, cocina...) incrustado en la piedra con los bordes
desmigados, como un recuerdo que se ha quedado flotando. Todos los colores pasan por el mismo
filtro nocturno para que todo case.
The whole plane is an archipelago of floating islands made of the same astral stone: irregular
flagstones (no grid), a moonlit edge, a veined cliff and a rocky belly with crystals in each
character's colour. On top of each island sits a piece of its character's world (grass, mats,
kitchen...) set into the stone with crumbly edges, like a memory left floating. Every colour
goes through the same night filter so everything matches.

Uso / Usage:  python3 tools/make_hub.py
Salida / Output: assets/sprites/hub_isle_*.png, hub_far_*.png, hub_step_*.png
                 y scripts/visual/hub_layout.gd (posiciones y zonas por las que se anda / positions and walkable areas)
Un píxel del dibujo es un píxel de la pantalla a media resolución (960 x 540).
One drawing pixel is one pixel of the half-resolution screen (960 x 540).
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
LAYOUT = os.path.join(ROOT, "scripts", "visual", "hub_layout.gd")

T = 18            # grosor del canto de las islas / island edge thickness
NIGHT = (34, 30, 84)


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def mix(a, b, t):
    return a + (b - a) * t


def night(h, k=0.3):
    """Filtro nocturno común: todo tira un poco hacia el añil / Common night filter: everything leans a bit towards indigo."""
    c = rgb(h) if isinstance(h, str) else h
    return mix(c, np.array(NIGHT, dtype=np.float32), k)


# Paleta de la piedra astral / Astral stone palette
STONE = [rgb("#4b4392"), rgb("#453d89"), rgb("#3f377f")]
GROUT = rgb("#29245e")
BEVEL_L = rgb("#5d55a8")
BEVEL_D = rgb("#332d6e")
CURB = rgb("#574fa2")
LIP = rgb("#a59ce6")
LIP_N = rgb("#7066c2")
CLIFF = [rgb("#5e55a8"), rgb("#4a4290"), rgb("#413a82"), rgb("#4a4290"), rgb("#3a3376")]
ROCK = [rgb("#544a9c"), rgb("#453c88"), rgb("#363072"), rgb("#29245c"), rgb("#1d1946"), rgb("#130f30")]
OUTLINE = rgb("#140e26")
FLOWERS = [rgb("#9be3ff"), rgb("#f6d993"), rgb("#ff9fc8"), rgb("#c9b8ff")]

# Islas: centro en el mundo, radios, color de sus cristales y suelo / Islands: world centre, radii, crystal colour and floor
ISLES = {
    "nexus": dict(pos=(0, 0), r=(250, 145), aura="#f6d993", seed=1, floor=None),
    "wardrobe": dict(pos=(0, -400), r=(170, 100), aura="#c9b8ff", seed=2, floor="bedroom", inset=(130, 72, 0, 4)),
    "charo": dict(pos=(-450, -380), r=(160, 98), aura="#7fe0d0", seed=3, floor="charo", inset=(118, 66, 0, 4)),
    "magnus": dict(pos=(450, -380), r=(165, 100), aura="#4fd39a", seed=4, floor="magnus", inset=(125, 70, 0, 4)),
    "svinho": dict(pos=(-700, -80), r=(185, 108), aura="#9be38a", seed=5, floor="grass", inset=(140, 74, 0, 3), shape="rect"),
    "stolk": dict(pos=(-710, 250), r=(165, 100), aura="#ff8f9e", seed=6, floor="gym", inset=(125, 70, 0, 4)),
    "doc": dict(pos=(700, -80), r=(170, 102), aura="#ffe3a3", seed=7, floor="clinic", inset=(130, 72, 0, 4)),
    "ad": dict(pos=(710, 250), r=(175, 104), aura="#ffb04a", seed=8, floor="street", inset=(140, 76, 0, 4)),
    "silly": dict(pos=(-520, 520), r=(160, 98), aura="#5ff2ff", seed=9, floor="dark", inset=(120, 68, 0, 4)),
    "museum": dict(pos=(0, 545), r=(285, 140), aura="#e8e4f6", seed=10, floor="marble", inset=(245, 108, 0, 4)),
    "pinche": dict(pos=(520, 520), r=(165, 100), aura="#ff9a3a", seed=11, floor="kitchen", inset=(125, 70, 0, 4)),
    # Detrás del armario: el tatami de entrenamiento con el muñeco de pruebas
    # Behind the wardrobe: the training mat with the practice dummy
    "training": dict(pos=(-260, -690), r=(230, 112), aura="#ff8f6a", seed=12, floor="dojo", inset=(196, 90, 0, 4)),
    # SuperK, en lo alto, junto a Magnus; Lil Key, a la izquierda del todo, junto a Svinho y Stolk
    # SuperK, high up, next to Magnus; Lil Key, far left, next to Svinho and Stolk
    "superk": dict(pos=(300, -720), r=(165, 100), aura="#b48cff", seed=13, floor="roof", inset=(125, 70, 0, 4)),
    "lilkey": dict(pos=(-1090, 85), r=(165, 100), aura="#ff6a8a", seed=14, floor="stage", inset=(125, 68, 0, 4)),
}


def edge_noise(rng, amp=1.0, fine=True):
    """Función del borde: cuánto sobresale la isla en cada ángulo / Edge function: how far the island sticks out at each angle."""
    terms = [(k, rng.uniform(0.02, 0.05) / math.sqrt(k) * amp, rng.uniform(0, math.tau)) for k in range(2, 8)]
    if fine:
        terms += [(k, 0.012 * amp, rng.uniform(0, math.tau)) for k in (11, 13, 17)]

    def f(th):
        out = np.zeros_like(th) if isinstance(th, np.ndarray) else 0.0
        for k, a, ph in terms:
            out = out + a * np.sin(k * th + ph)
        return out
    return f


def erode(mask):
    m = mask.copy()
    m[1:, :] &= mask[:-1, :]
    m[:-1, :] &= mask[1:, :]
    m[:, 1:] &= mask[:, :-1]
    m[:, :-1] &= mask[:, 1:]
    return m


def depth_from_edge(mask, n):
    """Distancia al borde (en píxeles, hasta n) / Distance to the edge (in pixels, up to n)."""
    d = np.zeros(mask.shape, dtype=np.int32)
    m = mask.copy()
    for i in range(n):
        d[m] += 1
        m = erode(m)
    return d


def voronoi_stone(img, mask, X, Y, rng, spacing=17, jitter=6.5):
    """Losas irregulares con junta y bisel de un píxel / Irregular flagstones with grout and a one-pixel bevel."""
    h, w = mask.shape
    pts = []
    row = 0
    for y in range(-spacing, h + spacing, int(spacing * 0.86)):
        off = (spacing / 2) if row % 2 else 0
        for x in range(-spacing, w + spacing, spacing):
            pts.append((x + off + rng.uniform(-jitter, jitter), y + rng.uniform(-jitter, jitter)))
        row += 1
    P = np.array(pts, dtype=np.float32)
    ys, xs = np.nonzero(mask)
    best = np.full(xs.shape, 1e9, dtype=np.float32)
    second = np.full(xs.shape, 1e9, dtype=np.float32)
    idx = np.zeros(xs.shape, dtype=np.int32)
    for i, (px, py) in enumerate(P):
        d = np.sqrt((xs - px) ** 2 + ((ys - py) * 1.25) ** 2)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        idx = np.where(closer, i, idx)
        best = np.where(closer, d, best)
    tone = np.array([rng.randrange(3) for _ in range(len(P))])
    grout = (second - best) < 1.15
    cells = np.full(mask.shape, -1, dtype=np.int32)
    cells[ys, xs] = idx
    gmask = np.zeros(mask.shape, dtype=bool)
    gmask[ys[grout], xs[grout]] = True
    for k in range(3):
        sel = (~grout) & (tone[idx] == k)
        img[ys[sel], xs[sel]] = STONE[k]
    img[gmask] = GROUT
    # Bisel: arriba de cada losa, luz; abajo, sombra / Bevel: light at the top of each slab, shadow at the bottom
    above = np.zeros_like(gmask)
    above[1:, :] = gmask[:-1, :]
    below = np.zeros_like(gmask)
    below[:-1, :] = gmask[1:, :]
    img[mask & ~gmask & above] = BEVEL_L
    img[mask & ~gmask & below] = BEVEL_D
    # Alguna losa con una grieta / The odd slab with a crack
    for i in range(len(P)):
        if rng.random() < 0.12:
            px, py = P[i]
            x, y = int(px), int(py)
            for s in range(rng.randint(3, 7)):
                if 0 <= y < h and 0 <= x < w and mask[y, x] and not gmask[y, x]:
                    img[y, x] = BEVEL_D
                x += rng.choice((-1, 0, 1))
                y += 1
    return gmask


# --- Suelos de cada personaje / Each character's floor ------------------------------------

def floor_grass(lx, ly, rng, irx, iry):
    """Medio campo visto desde detrás de Svinho: la portería arriba, con su área, el punto de
    penalti y la media luna; abajo la línea de medio campo con medio círculo central. Franjas de
    cortacésped paralelas a la portería.
    Half a pitch seen from behind Svinho: the goal at the top, with its box, the penalty spot and
    the arc; at the bottom the halfway line with half the centre circle. Mowing stripes parallel
    to the goal."""
    G = [night("#3f9a4a"), night("#4aa856"), night("#357f3e"), night("#5bb866")]
    WH = night("#e8ecf0", 0.15)
    out = np.where((((ly + 400) // 12) % 2 == 0)[..., None], G[0], G[1])
    noise = np.random.default_rng(5).random(lx.shape)
    out[noise < 0.05] = G[2]
    out[noise > 0.975] = G[3]
    T, B, S = -(iry - 8), iry - 8, irx - 9     # bandas / touchlines
    on = lambda a, b: np.abs(a - b) < 0.6
    within_x = np.abs(lx) <= S
    within_y = (ly >= T) & (ly <= B)
    line = (on(ly, T) | on(ly, B)) & within_x
    line |= on(np.abs(lx), S) & within_y
    # Área grande y área chica / Penalty box and six-yard box
    for hw, d in ((70, 36), (36, 13)):
        box = (np.abs(lx) <= hw) & (ly >= T) & (ly <= T + d)
        line |= box & (on(np.abs(lx), hw) | on(ly, T + d))
    # Punto de penalti y media luna / Penalty spot and arc
    spot = T + 25
    line |= (np.abs(lx) < 1.2) & (np.abs(ly - spot) < 1.2)
    rr = np.sqrt(lx ** 2 + ((ly - spot) * 1.45) ** 2)
    line |= (np.abs(rr - 24) < 0.7) & (ly > T + 36)
    # Medio círculo central y punto / Half the centre circle and the spot
    rc = np.sqrt(lx ** 2 + ((ly - B) * 1.45) ** 2)
    line |= (np.abs(rc - 30) < 0.7) & (ly < B)
    line |= (np.abs(lx) < 1.2) & (np.abs(ly - B) < 1.2)
    # Esquinas / Corner arcs
    for sx in (-1, 1):
        rq = np.sqrt((lx - sx * S) ** 2 + ((ly - T) * 1.45) ** 2)
        line |= (np.abs(rq - 7) < 0.6) & (sx * lx < S) & (ly > T)
    out[line] = WH
    return out


def floor_gym(lx, ly, rng, irx, iry):
    A, B, S = night("#3c3c52"), night("#38384c"), night("#2c2c40")
    out = np.where(((((lx + 400) // 26) + ((ly + 400) // 26)) % 2 == 0)[..., None], A, B)
    seam = ((lx + 400) % 26 == 0) | ((ly + 400) % 26 == 0)
    out[seam] = S
    noise = np.random.default_rng(6).random(lx.shape)
    out[noise < 0.03] = night("#5a5a74")
    out[(noise > 0.985)] = night("#d0505e")
    # Tarima de madera donde levanta Stolk / Wooden platform where Stolk lifts
    plat = (np.abs(lx + 20) <= 26) & (np.abs(ly - 8) <= 16)
    out[plat] = night("#8a5a3e")
    out[plat & ((ly + 400) % 6 == 0)] = night("#6a4430")
    out[plat & ((np.abs(lx + 20) == 26) | (np.abs(ly - 8) == 16))] = night("#e0b53a")
    return out


def floor_dark(lx, ly, rng, irx, iry):
    # Moqueta oscura con cables que salen de la mesa / Dark carpet with cables running from the desk
    out = np.zeros(lx.shape + (3,), dtype=np.float32) + rgb("#2c2650")
    noise = np.random.default_rng(9).random(lx.shape)
    out[noise < 0.15] = rgb("#352e5e")
    out[noise > 0.93] = rgb("#241f44")
    r2 = np.random.default_rng(19)
    h, w = lx.shape
    cx0 = int(-lx[0, 0])
    cy0 = int(-ly[0, 0])
    for k, col in enumerate(("#2a9a68", "#2a7aa0", "#2a9a68", "#6a54a8", "#2a7aa0", "#2a9a68", "#6a54a8")):
        x, y = cx0 + int(r2.integers(-26, 26)), cy0 - 42
        ang = -math.pi * 0.1 + k * math.pi * 1.2 / 6
        dx, dy = math.cos(ang), abs(math.sin(ang)) + 0.25
        fx, fy = float(x), float(y)
        for _ in range(240):
            xi, yi = int(round(fx)), int(round(fy))
            if 0 <= yi < h and 0 <= xi < w:
                out[yi, xi] = rgb(col)
            fx += dx * 0.8 + r2.uniform(-0.6, 0.6)
            fy += dy * 0.5 + r2.uniform(-0.4, 0.4)
    return out


def floor_clinic(lx, ly, rng, irx, iry):
    A, B, S = night("#cfdbe2", 0.38), night("#c6d3dc", 0.38), night("#b4c1cc", 0.38)
    out = np.where(((((lx + 400) // 18) + ((ly + 400) // 12)) % 2 == 0)[..., None], A, B)
    out[((lx + 400) % 18 == 0) | ((ly + 400) % 12 == 0)] = S
    band = np.abs(ly + iry * 0.55) <= 2
    out[band] = night("#5b9ad6")
    return out


def floor_street(lx, ly, rng, irx, iry):
    A, B, S = night("#8f8aa4"), night("#847f99"), night("#5f5a74")
    row = (ly + 400) // 12
    off = (row % 2) * 10
    out = np.where(((((lx + 400 + off) // 20) * 7 + row * 3) % 3 == 0)[..., None], B, A)
    out[((lx + 400 + off) % 20 == 0) | ((ly + 400) % 12 == 0)] = S
    # Bordillo / Kerb
    kerb = ly > iry * 0.55
    out[kerb] = night("#b8b4c8")
    out[kerb & (np.abs(ly - iry * 0.55) < 1)] = night("#e4e0f0")
    noise = np.random.default_rng(8).random(lx.shape)
    out[(noise < 0.004) & ~kerb] = night("#4a4560")
    return out


def floor_kitchen(lx, ly, rng, irx, iry):
    A, B = night("#d8d0c4", 0.38), night("#3a3448")
    out = np.where(((((lx + 400) // 10) + ((ly + 400) // 8)) % 2 == 0)[..., None], A, B)
    # Manchas de quemado / Scorch marks
    r2 = np.random.default_rng(11)
    for _ in range(9):
        cx, cy, rr = r2.uniform(-irx, irx), r2.uniform(-iry, iry), r2.uniform(6, 16)
        d = np.sqrt((lx - cx) ** 2 + ((ly - cy) * 1.4) ** 2)
        noise = r2.random(lx.shape)
        burn = d < rr * (0.7 + 0.5 * noise)
        out[burn] = mix(out[burn], rgb("#1a1424"), 0.55)
    return out


def floor_boards(lx, ly, base, joint, line):
    out = np.zeros(lx.shape + (3,), dtype=np.float32) + base
    row = (ly + 400) // 9
    out[(ly + 400) % 9 == 0] = line
    j = ((lx + 400 + (row * 37) % 60) % 64 == 0)
    out[j] = joint
    return out


def floor_bedroom(lx, ly, rng, irx, iry):
    out = floor_boards(lx, ly, rgb("#36326f"), rgb("#1c1846"), rgb("#1c1846"))
    hl = ((ly + 400) % 9 == 1)
    out[hl] = rgb("#45408a")
    # Alfombra redonda de estrellas, como la del cuarto de Kroker / Round star rug, like the one in Kroker's room
    rr = np.sqrt((lx / 62.0) ** 2 + ((ly - 10) / 30.0) ** 2)
    out[rr < 1.0] = rgb("#4a4592")
    out[(rr < 1.0) & (rr > 0.9)] = rgb("#8f86d6")
    out[(np.abs(rr - 0.72) < 0.025)] = rgb("#6e66b8")
    noise = np.random.default_rng(2).random(lx.shape)
    out[(rr < 0.85) & (noise < 0.012)] = rgb("#f6d993")
    return out


def floor_charo(lx, ly, rng, irx, iry):
    out = floor_boards(lx, ly, night("#8a5a3e"), night("#5a3a2a"), night("#6a4430"))
    out[((ly + 400) % 9 == 1)] = night("#9a6a4a")
    # Alfombra de trapillo / Braided rag rug
    rr = np.sqrt((lx / 56.0) ** 2 + ((ly - 2) / 32.0) ** 2)
    rings = [night("#b8506a"), night("#d0885a"), night("#b8506a"), night("#d8c4a0")]
    ring = (rr * 15).astype(np.int32) % 4
    for k in range(4):
        out[(rr < 1.0) & (ring == k)] = rings[k]
    return out


def floor_magnus(lx, ly, rng, irx, iry):
    W = [night("#6a3e2a"), night("#5a3424"), night("#7a4a32")]
    u = (lx + 400) // 6
    v = (ly + 400) // 6
    herr = ((u + v) % 2 == 0)
    out = np.where(herr[..., None], W[0], W[1])
    out[(((lx + 400) % 12 == 0) & herr) | (((ly + 400) % 12 == 0) & ~herr)] = W[2]
    # Alfombra granate con ribete dorado / Burgundy carpet with gold trim
    car = (np.abs(lx) <= 58) & (np.abs(ly - 4) <= 32)
    out[car] = night("#6a1e30")
    trim = car & ((np.abs(np.abs(lx) - 54) < 1) & (np.abs(ly - 4) <= 28) | (np.abs(np.abs(ly - 4) - 28) < 1) & (np.abs(lx) <= 54))
    out[trim] = night("#c9961e")
    return out


def floor_marble(lx, ly, rng, irx, iry):
    A, B, S = night("#c4bedc", 0.58), night("#bdb6d6", 0.58), night("#aea6cc", 0.58)
    row = (ly + 400) // 20
    off = (row % 2) * 17
    out = np.where(((((lx + 400 + off) // 34) * 5 + row * 3) % 3 == 0)[..., None], B, A)
    out[((lx + 400 + off) % 34 == 0) | ((ly + 400) % 20 == 0)] = S
    # Vetas del mármol / Marble veins
    r2 = np.random.default_rng(10)
    vein = np.zeros(lx.shape, dtype=bool)
    h, w = lx.shape
    for _ in range(40):
        x, y = r2.integers(0, w), r2.integers(0, h)
        for s in range(r2.integers(6, 18)):
            if 0 <= x < w and 0 <= y < h:
                vein[y, x] = True
            x += 1
            y += r2.integers(-1, 2)
    out[vein] = mix(out[vein], night("#a39cc4", 0.58), 0.6)
    # Alfombra roja entre las filas de pedestales / Red runner between the rows of pedestals
    run = np.abs(ly - 2) <= 7
    out[run] = night("#8a2438")
    out[run & (np.abs(np.abs(ly - 2) - 6) < 1)] = night("#d0a040")
    return out


def floor_dojo(lx, ly, rng, irx, iry):
    """Tatami: esteras de 2 x 1 al tresbolillo con ribete verde y un círculo rojo en medio
    Tatami: staggered 2 x 1 mats with a green border and a red circle in the middle"""
    A, B, E = night("#c8c08a"), night("#bab27c"), night("#3f6a4a")
    row = (ly + 400) // 24
    off = (row % 2) * 24
    col = (lx + 400 + off) // 48
    out = np.where(((col + row) % 2 == 0)[..., None], A, B)
    out[((lx + 400 + off) % 48 == 0) | ((ly + 400) % 24 == 0)] = E
    # Rayitas del junco / Rush weave lines
    out[((ly + 400) % 3 == 0) & ((lx + 400 + off) % 48 != 0) & ((ly + 400) % 24 != 0)] = mix(out[((ly + 400) % 3 == 0) & ((lx + 400 + off) % 48 != 0) & ((ly + 400) % 24 != 0)], E, 0.12)
    rr = np.sqrt(lx ** 2 + ((ly - 2) * 2.0) ** 2)
    out[np.abs(rr - 52) < 1.6] = night("#c8464f")
    out[np.abs(rr - 40) < 0.8] = night("#c8464f")
    return out


def floor_roof(lx, ly, rng, irx, iry):
    """Azotea de SuperK: losas de hormigón y un helipuerto con su K en un círculo dorado
    SuperK's rooftop: concrete slabs and a helipad with his K in a gold circle"""
    A, B, S = night("#9a96b0"), night("#8c88a2"), night("#6a6684")
    out = np.where(((((lx + 400) // 18) + ((ly + 400) // 12)) % 2 == 0)[..., None], A, B)
    out[((lx + 400) % 18 == 0) | ((ly + 400) % 12 == 0)] = S
    noise = np.random.default_rng(13).random(lx.shape)
    out[noise < 0.02] = night("#7a7690")
    GOLD, PUR = night("#f2c94c", 0.2), night("#5a34a8", 0.2)
    cx, cy = 10, 6
    rr = np.sqrt((lx - cx) ** 2 + ((ly - cy) * 1.6) ** 2)
    out[rr < 30] = PUR
    out[(rr >= 30) & (rr < 34)] = GOLD
    # La K / The K
    x, y = lx - cx, (ly - cy) * 1.6
    k = (np.abs(x + 8) < 3) & (np.abs(y) < 18)
    k |= (np.abs((x + 6) - (-y) * 0.75) < 3) & (y < 0) & (y > -18) & (x > -7)
    k |= (np.abs((x + 6) - y * 0.75) < 3) & (y > 0) & (y < 18) & (x > -7)
    out[k & (rr < 30)] = GOLD
    return out


def floor_stage(lx, ly, rng, irx, iry):
    """Escenario de Lil Key: tablas de madera oscura, focos de colores y luces en el borde
    Lil Key's stage: dark wooden boards, coloured spotlights and lights along the edge"""
    A, B, S = night("#6a3e3a"), night("#5e3634"), night("#3a2026")
    row = (ly + 400) // 7
    off = (row % 3) * 13
    out = np.where(((((lx + 400 + off) // 38) + row) % 2 == 0)[..., None], A, B)
    out[((ly + 400) % 7 == 0) | ((lx + 400 + off) % 38 == 0)] = S
    for (cx, cy, col) in ((-50, -10, "#ff6a8a"), (50, 4, "#8fe0ff"), (0, -30, "#f6d993")):
        d = np.sqrt((lx - cx) ** 2 + ((ly - cy) * 1.5) ** 2)
        k = (np.floor(np.clip(1.0 - d / 46.0, 0.0, 0.999) * 3.0) / 3.0)[..., None] * 0.4
        out = out + (rgb(col) - out) * k
    # Luces en el borde de delante / Lights along the front edge
    edge = (np.abs(ly - (iry - 8)) < 1.5) & (((lx + 400) % 16) < 3)
    out[edge] = night("#fff0a0", 0.1)
    return out


FLOORS = {"grass": floor_grass, "gym": floor_gym, "dark": floor_dark, "clinic": floor_clinic, "street": floor_street,
          "kitchen": floor_kitchen, "bedroom": floor_bedroom, "charo": floor_charo, "magnus": floor_magnus, "marble": floor_marble, "dojo": floor_dojo,
          "roof": floor_roof, "stage": floor_stage}


def make_isle(name, rx, ry, aura, seed, floor=None, inset=None, deep=1.3, flowers=True, nexus=False, crystals=True, thick=18, pad=30, shape=None):
    T = thick
    rng = random.Random(seed)
    D = int(ry * deep) + 6
    W = 2 * rx + pad
    H = 2 * ry + T + D + pad
    cx, cy = W // 2, ry + pad // 2 - 3
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    nx, ny = (X - cx) / rx, (Y - cy) / ry
    th = np.arctan2(ny, nx)
    rn = np.sqrt(nx ** 2 + ny ** 2)
    edge = edge_noise(rng)
    top = rn < 1.0 + edge(th)
    img = np.zeros((H, W, 3), dtype=np.float32)
    solid = top.copy()

    # Canto y panza de roca / Edge and rocky belly
    cols = np.nonzero(top.any(axis=0))[0]
    yb = np.full(W, -1)
    for x in cols:
        yb[x] = np.nonzero(top[:, x])[0].max()
    x0, x1 = cols.min(), cols.max()
    # Perfil de la panza: un cono redondeado con unas cuantas estalactitas grandes
    # Belly profile: a rounded cone with a few big stalactites
    extra = np.zeros(W)
    for _ in range(rng.randint(3, 6)):
        sx = rng.uniform(x0 + (x1 - x0) * 0.15, x1 - (x1 - x0) * 0.15)
        sl, sw = rng.uniform(0.25, 0.55) * D, rng.uniform(6, 13)
        for x in range(int(sx - sw), int(sx + sw) + 1):
            if x0 <= x <= x1:
                extra[x] = max(extra[x], sl * (1 - abs(x - sx) / sw))
    jag = np.zeros(W)
    x = x0
    while x <= x1:
        wseg = rng.randint(3, 6)
        jag[x:x + wseg] = rng.uniform(-3.5, 1.5)
        x += wseg
    facet_tone = {}
    fx = x0
    facets = np.zeros(W, dtype=np.int32)
    seams = set()
    fid = 0
    while fx <= x1:
        wseg = rng.randint(12, 26)
        facets[fx:fx + wseg] = fid
        mid = (fx + wseg / 2 - cx) / rx
        facet_tone[fid] = 0.66 - 0.42 * mid + rng.uniform(-0.08, 0.08)
        if rng.random() < 0.6:
            seams.add(fx)
        fid += 1
        fx += wseg
    bayer = np.array([[0.0, 0.5], [0.75, 0.25]])
    for x in cols:
        xn = (x - cx) / max(1.0, (x1 - x0) / 2)
        u = max(0.0, D * max(0.0, 1 - abs(xn) ** 1.25) ** 1.5 + extra[x] * (1 - abs(xn) * 0.6) + jag[x])
        y0 = yb[x] + 1
        for y in range(y0, min(H, y0 + T + int(u) + 1)):
            if top[y, x]:
                continue
            s = y - y0
            solid[y, x] = True
            if s < T:
                # Canto con vetas; a la derecha, más oscuro / Veined edge; darker to the right
                c = CLIFF[min(len(CLIFF) - 1, 0 if s < 2 else 1 + (s // 5) % 4)]
                if xn > 0.35:
                    c = mix(c, ROCK[4], 0.35)
                elif xn < -0.6:
                    c = mix(c, LIP, 0.12)
                img[y, x] = c
            else:
                f = (s - T) / max(1.0, D)
                b = facet_tone[facets[x]] - f * 1.5
                v = (1 - b) * 4.0 + bayer[y % 2, x % 2] - 0.4
                k = int(np.clip(v, 0, len(ROCK) - 1))
                img[y, x] = ROCK[k]
    # Juntas entre facetas y grietas / Seams between facets and cracks
    for x in seams:
        if yb[x] < 0:
            continue
        for y in range(yb[x] + T + 3, H):
            if solid[y, x] and not top[y, x]:
                img[y, x] = mix(img[y, x], OUTLINE, 0.35)
    for _ in range(int((x1 - x0) / 14)):
        x = rng.randint(x0 + 4, x1 - 4)
        if yb[x] < 0:
            continue
        y = yb[x] + T + rng.randint(6, int(D * 0.5) + 7)
        for s in range(rng.randint(4, 10)):
            if 0 <= y < H and solid[y, x] and not top[y, x]:
                img[y, x] = mix(img[y, x], OUTLINE, 0.4)
            x += 1
            y += rng.choice((0, 0, 1, -1))
    # Juntas entre facetas y grietas del canto / Seams between facets and cracks in the edge
    for x in cols[1:]:
        if facets[x] != facets[x - 1]:
            for y in range(yb[x] + T + 2, H):
                if solid[y, x] and not top[y, x]:
                    img[y, x] = mix(img[y, x], OUTLINE, 0.45)
    for _ in range(int((x1 - x0) / 9) if T >= 10 else 0):
        x = rng.randint(x0 + 3, x1 - 3)
        if yb[x] < 0:
            continue
        y = yb[x] + rng.randint(4, T - 3)
        for s in range(rng.randint(3, 6)):
            if 0 <= y < H and solid[y, x] and not top[y, x] and y - yb[x] < T:
                img[y, x] = ROCK[3]
            y += 1
            x += rng.choice((0, 0, 1, -1))

    # Cristales que cuelgan / Hanging crystals
    if crystals:
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dr = ImageDraw.Draw(lay)
        ac = rgb(aura)
        cl = tuple(int(v) for v in mix(ac, rgb("#ffffff"), 0.45))
        cm = tuple(int(v) for v in ac)
        cd = tuple(int(v) for v in mix(ac, ROCK[5], 0.5))
        for _ in range(rng.randint(4, 7)):
            x = rng.randint(int(cx - rx * 0.6), int(cx + rx * 0.6))
            if yb[x] < 0:
                continue
            xn = (x - cx) / rx
            u = D * max(0.0, 1 - abs(xn) ** 1.25) ** 1.5
            y = int(yb[x] + T + u * rng.uniform(0.25, 0.75))
            ln, wd = rng.randint(10, 26), rng.randint(4, 7)
            lean = rng.uniform(-0.35, 0.35)
            tip = (x + lean * ln, y + ln)
            dr.polygon([(x - wd, y), (x, y - 2), tip], fill=cl + (255,))
            dr.polygon([(x, y - 2), (x + wd, y), tip], fill=cd + (255,))
            dr.line([(x, y - 1), tip], fill=cm + (255,))
        a = np.array(lay)
        on = a[..., 3] > 0
        img[on] = a[..., :3][on]
        solid |= on

    # Superficie de piedra astral / Astral stone surface
    voronoi_stone(img, top, X, Y, rng)
    dist = depth_from_edge(top, 12)
    # Bordillo y filo de luna / Kerb and moonlit lip
    img[top & (dist <= 3) & (dist > 1)] = CURB
    south = ny > 0.0
    img[top & (dist == 1) & south] = LIP
    img[top & (dist == 1) & ~south] = LIP_N
    img[top & (dist == 4)] = mix(CURB, GROUT, 0.5)

    floor_mask = np.zeros_like(top)
    if floor:
        irx, iry, ox, oy = inset
        lx = X - (cx + ox)
        ly = Y - (cy + oy)
        inn = np.sqrt((lx / irx) ** 2 + (ly / iry) ** 2)
        iedge = edge_noise(random.Random(seed * 7 + 1), amp=1.4)
        ith = np.arctan2(ly / iry, lx / irx)
        if shape == "rect":
            # Rectángulo de esquinas redondeadas y borde limpio (un campo de verdad)
            # Rounded rectangle with a clean edge (a proper pitch)
            cr = 22.0
            qx = np.maximum(np.abs(lx) - (irx - cr), 0)
            qy = np.maximum(np.abs(ly) - (iry - cr), 0)
            floor_mask = top & (np.sqrt(qx ** 2 + qy ** 2) < cr) & (dist > 5)
        else:
            floor_mask = top & (inn < 1.0 + iedge(ith)) & (dist > 6)
        # Bordes desmigados / Crumbly edges
        fd = depth_from_edge(floor_mask, 3)
        crumble = np.random.default_rng(seed).random(top.shape)
        if shape != "rect":
            floor_mask &= ~((fd == 1) & (crumble < 0.45))
            floor_mask &= ~((fd == 2) & (crumble < 0.12))
        fl = FLOORS[floor](lx.astype(np.int32), ly.astype(np.int32), rng, irx, iry)
        img[floor_mask] = fl[floor_mask]
        # Sombra fina alrededor del trozo de mundo / Thin shadow around the piece of world
        ring = top & ~floor_mask
        grow = floor_mask.copy()
        grow[1:, :] |= floor_mask[:-1, :]
        grow[:, 1:] |= floor_mask[:, :-1]
        grow[:, :-1] |= floor_mask[:, 1:]
        img[ring & grow] = GROUT
        # Algún trocito suelto fuera / The odd loose crumb outside
        r2 = np.random.default_rng(seed + 50)
        fy, fx = np.nonzero(fd == 1)
        for i in (r2.choice(len(fy), size=min(len(fy), 14), replace=False) if shape != "rect" else []):
            ddx, ddy = r2.integers(-5, 6), r2.integers(-4, 5)
            yy, xx = fy[i] + ddy, fx[i] + ddx
            if 0 <= yy < H and 0 <= xx < W and top[yy, xx] and not floor_mask[yy, xx] and dist[yy, xx] > 4:
                img[yy, xx] = fl[fy[i], fx[i]]

    if nexus:
        # Círculo de runas y constelaciones que salen hacia cada puente / Rune circle and constellations reaching out to each bridge
        GOLD, GOLD_D, CYAN = rgb("#f6d993"), rgb("#b89a5e"), rgb("#9be3ff")
        lx, ly = X - cx, (Y - cy - 12) / 0.6
        rr = np.sqrt(lx ** 2 + ly ** 2)
        ring = top & ((np.abs(rr - 58) < 1.0) | (np.abs(rr - 70) < 1.0))
        img[ring] = GOLD
        img[top & (rr > 59) & (rr < 69)] = rgb("#3a3480")
        ang = np.arctan2(ly, lx)
        for k in range(16):
            a = k * math.tau / 16
            d = np.abs(np.angle(np.exp(1j * (ang - a)))) * 64
            glyph = top & (d < 1.6) & (np.abs(rr - 64) < 3.5)
            img[glyph] = GOLD if k % 2 else CYAN
        img[top & (np.abs(rr - 36) < 0.8)] = GOLD_D
        for name2, isle in ISLES.items():
            # Las islas lejanas no tienen puente desde el centro / The far islands have no bridge from the centre
            if name2 in ("nexus", "training", "superk", "lilkey"):
                continue
            vx, vy = isle["pos"]
            a = math.atan2(vy, vx)
            # constelación hacia el puente / constellation towards the bridge
            p0 = np.array([math.cos(a) * 74, math.sin(a) * 74 * 0.6])
            p1 = np.array([math.cos(a) * rx * 0.82, math.sin(a) * ry * 0.82])
            nodes = [p0 + (p1 - p0) * t + np.array([rng.uniform(-6, 6), rng.uniform(-4, 4)]) * (0 < t < 1) for t in (0, 0.35, 0.7, 1.0)]
            for i in range(len(nodes) - 1):
                a0, a1 = nodes[i], nodes[i + 1]
                n = int(np.linalg.norm(a1 - a0))
                for s in range(0, n, 2):
                    q = a0 + (a1 - a0) * s / max(1, n)
                    xx, yy = int(round(cx + q[0])), int(round(cy + 12 + q[1]))
                    if top[yy, xx] and dist[yy, xx] > 3:
                        img[yy, xx] = GOLD_D
            for q in nodes[1:]:
                xx, yy = int(round(cx + q[0])), int(round(cy + 12 + q[1]))
                for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    if top[yy + ddy, xx + ddx]:
                        img[yy + ddy, xx + ddx] = GOLD if (ddx, ddy) == (0, 0) else GOLD_D

    # Florecillas astrales cerca del borde / Little astral flowers near the edge
    if flowers:
        r3 = np.random.default_rng(seed + 99)
        noise = r3.random(top.shape)
        sel = top & ~floor_mask & (dist >= 4) & (dist <= 9) & (noise < 0.02)
        ys, xs = np.nonzero(sel)
        for y, x in zip(ys, xs):
            c = FLOWERS[r3.integers(0, len(FLOWERS))]
            img[y, x] = c
            if r3.random() < 0.25:
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if top[y + ddy, x + ddx]:
                        img[y + ddy, x + ddx] = mix(c, STONE[0], 0.5)

    # Contorno de un píxel / One-pixel outline
    grow = solid.copy()
    grow[1:, :] |= solid[:-1, :]
    grow[:-1, :] |= solid[1:, :]
    grow[:, 1:] |= solid[:, :-1]
    grow[:, :-1] |= solid[:, 1:]
    outl = grow & ~solid
    img[outl] = OUTLINE
    alpha = (solid | outl).astype(np.uint8) * 255
    out = np.dstack([np.clip(img, 0, 255).astype(np.uint8), alpha])
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, name + ".png"))
    # Borde por el que se anda (un poco hacia dentro) / Walkable outline (pulled in a little)
    walk = []
    rim = []
    for k in range(56):
        a = k * math.tau / 56
        r = 1.0 + float(edge(a))
        mx = max(0.0, r * rx - 9)
        my = max(0.0, r * ry - 7)
        walk.append((math.cos(a) * mx, math.sin(a) * my))
        rim.append((math.cos(a) * r * rx, math.sin(a) * r * ry))
    return dict(offset=(-cx, -cy), size=(W, H), walk=walk, rim=rim)


def main():
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for name, d in ISLES.items():
        info = make_isle("hub_isle_" + name, d["r"][0], d["r"][1], d["aura"], d["seed"], d.get("floor"), d.get("inset"), nexus=(name == "nexus"), shape=d.get("shape"))
        data[name] = info
        print(name, info["size"])
    # Islotes lejanos del fondo / Far-off islets in the background
    for i, (rx, ry) in enumerate(((70, 34), (46, 24), (100, 46), (34, 18))):
        make_isle("hub_far_%d" % i, rx, ry, ["#9be3ff", "#ff9fc8", "#f6d993", "#c9b8ff"][i], 40 + i, flowers=False, deep=1.6)
    # Piedras de los puentes / Bridge stepping stones
    for i in range(3):
        make_isle("hub_step_%d" % i, 7 + i, 4, "#c9b8ff", 70 + i, flowers=False, deep=1.0, crystals=False, thick=3, pad=6)
    with open(LAYOUT, "w") as f:
        f.write("class_name HubLayout\n## Generado por tools/make_hub.py: no editar a mano.\n## Generated by tools/make_hub.py: do not edit by hand.\n"
                "## Islas del plano astral: centro, dónde va su textura y por dónde se anda (relativo al centro)\n"
                "## Astral plane islands: centre, where their texture goes and where you can walk (relative to the centre)\n\n"
                "const ISLES := {\n")
        for name, d in ISLES.items():
            info = data[name]
            pts = ", ".join("Vector2(%.1f, %.1f)" % p for p in info["walk"])
            rim = ", ".join("Vector2(%.1f, %.1f)" % p for p in info["rim"])
            f.write("\t\"%s\": {\"pos\": Vector2(%d, %d), \"r\": Vector2(%d, %d), \"offset\": Vector2(%d, %d), \"aura\": Color(\"%s\"),\n\t\t\"walk\": [%s],\n\t\t\"rim\": [%s]},\n"
                    % (name, d["pos"][0], d["pos"][1], d["r"][0], d["r"][1], info["offset"][0], info["offset"][1], d["aura"], pts, rim))
        f.write("}\n")


if __name__ == "__main__":
    main()
