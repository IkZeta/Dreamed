"""Plano de la Metrópolis (Acto 4): una ciudad grande para recorrer en todas direcciones, al
estilo de las ciudades centrales de los juegos de Pokémon. Cuadrícula de baldosas de 120 x 120
(en el lienzo de la habitación): avenidas, plaza con fuente, parques, estanque, árboles, setos,
farolas y bancos, y edificios de varios tamaños con su torre de los sueños en el centro.
Escribe scripts/visual/city_layout.gd.

Map of the Metropolis (Act 4): a big city to roam in every direction, in the style of the
central cities in the Pokémon games. A grid of 120 x 120 tiles (on the room canvas): avenues, a
plaza with a fountain, parks, a pond, trees, hedges, lamps and benches, and buildings of several
sizes with the dream tower in the middle. Writes scripts/visual/city_layout.gd.

Leyenda / Legend:
  .  baldosa / paving        :  plaza / plaza paving     ,  césped / grass
  *  flores / flowers        T  árbol / tree             h  seto / hedge
  W  agua / water            l  farola / lamp            b  banco / bench
  o  alcantarilla (puede abrirse) / manhole (can open)
"""
from pathlib import Path

W, H = 44, 30
g = [["." for _ in range(W)] for _ in range(H)]


def fill(c0, r0, c1, r1, ch):
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            g[r][c] = ch


def put(c, r, ch):
    g[r][c] = ch


# Borde de bosque alrededor de la ciudad (flota en el sueño) / Forest rim round the city (it floats in the dream)
fill(0, 0, W - 1, 0, "T")
fill(0, H - 1, W - 1, H - 1, "T")
fill(0, 0, 0, H - 1, "T")
fill(W - 1, 0, W - 1, H - 1, "T")
for c in range(1, W - 1, 3):
    put(c, 1, "T")
    put(c + 1, H - 2, "T")
for r in range(2, H - 2, 3):
    put(1, r, "T")
    put(W - 2, r + 1, "T")

# Avenidas en cruz y gran plaza central / Cross avenues and the big central plaza
fill(2, 13, W - 3, 16, ":")
fill(19, 2, 24, H - 3, ":")
fill(16, 10, 27, 19, ":")
fill(20, 13, 23, 15, "W")                 # fuente / fountain
for c, r in ((17, 11), (26, 11), (17, 18), (26, 18)):
    put(c, r, "*")
for c in (16, 27):
    for r in (12, 17):
        put(c, r, "b")
# Farolas a lo largo de las avenidas / Lamps along the avenues
for c in range(4, W - 4, 5):
    if not 16 <= c <= 27:
        put(c, 12, "l")
        put(c, 17, "l")
for r in range(3, H - 3, 5):
    if r >= 20:
        put(18, r, "l")
        put(25, r, "l")

# Parque del oeste con estanque / West park with a pond
fill(2, 18, 14, 27, ",")
fill(4, 21, 9, 24, "W")
for c, r in ((3, 19), (6, 19), (11, 19), (13, 21), (12, 25), (3, 26), (8, 26), (11, 23)):
    put(c, r, "T")
for c, r in ((10, 20), (10, 21), (2, 23), (13, 24), (6, 25), (7, 25)):
    put(c, r, "*")
fill(2, 17, 14, 17, "h")
put(8, 17, ".")
put(9, 17, ".")

# Jardín del sur con parterres / South garden with flower beds
fill(17, 22, 26, 27, ",")
fill(19, 22, 24, 27, ":")
for c, r in ((17, 22), (26, 22), (17, 27), (26, 27), (18, 25), (25, 25)):
    put(c, r, "T")
fill(18, 23, 18, 24, "*")
fill(25, 23, 25, 24, "*")

# Edificios: columna, fila, ancho, fondo (en baldosas) y tipo / Buildings: column, row, width, depth (in tiles) and kind
BUILDINGS = [
    (17, 2, 10, 6, "tower"),     # la torre de los sueños, al norte de la plaza / the dream tower, north of the plaza
    (3, 2, 6, 5, "shop"),
    (10, 3, 5, 4, "house"),
    (28, 2, 6, 6, "apart"),
    (35, 3, 6, 5, "shop"),
    (3, 8, 5, 4, "house"),
    (10, 8, 6, 4, "apart"),
    (28, 9, 6, 4, "shop"),
    (35, 9, 6, 4, "house"),
    (28, 18, 6, 5, "apart"),
    (35, 18, 6, 6, "shop"),
    (29, 25, 5, 3, "house"),
    (36, 25, 5, 3, "house"),
]
for c, r, w, d, _ in BUILDINGS:
    for rr in range(r, r + d):
        for cc in range(c, c + w):
            assert g[rr][cc] in ".:olb*,", (c, r, rr, cc, g[rr][cc])
            g[rr][cc] = "."

# Alcantarillas que se pueden abrir / Manholes that can open
HOLES = [(6, 14), (12, 15), (30, 14), (37, 15), (21, 5), (22, 9), (21, 20), (22, 25), (34, 16), (9, 13),
         (27, 6), (32, 22), (15, 9), (4, 8), (39, 26), (14, 20), (28, 26), (35, 9), (10, 28 - 1), (40, 12)]
# Solo las que caen en baldosa (no bajo edificios, agua ni árboles) / Only those on paving (not under buildings, water or trees)
_under = {(cc, rr) for c, r, w, d, _ in BUILDINGS for rr in range(r, r + d) for cc in range(c, c + w)}
HOLES = [(c, r) for c, r in HOLES if (c, r) not in _under and g[r][c] in ".:"]
for c, r in HOLES:
    put(c, r, "o")

START = (21, 17)   # delante de la fuente / in front of the fountain

# Huecos cerrados entre árboles a los que no se llega: más bosque (que no salga nadie ahí)
# Closed gaps between trees nobody can reach: more forest (so nobody spawns there)
_blocked = {(cc, rr) for c, r, w, d, _ in BUILDINGS for rr in range(r, r + d) for cc in range(c, c + w)}
_seen = {START}
_q = [START]
while _q:
    c, r = _q.pop()
    for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (c + dc, r + dr)
        if 0 <= n[0] < W and 0 <= n[1] < H and n not in _seen and n not in _blocked and g[n[1]][n[0]] not in "ThWlb":
            _seen.add(n)
            _q.append(n)
for r in range(H):
    for c in range(W):
        if (c, r) not in _seen and (c, r) not in _blocked and g[r][c] not in "ThWlb":
            g[r][c] = "T"

out = ["## Generado por tools/make_city_map.py: plano de la Metrópolis (Acto 4).",
       "## Generated by tools/make_city_map.py: map of the Metropolis (Act 4).",
       "class_name CityLayout", "extends RefCounted", "",
       "const TILE := 125.0", "const COLS := %d" % W, "const ROWS := %d" % H,
       "const START := Vector2i(%d, %d)" % START, "", "const MAP: Array[String] = ["]
out += ['\t"%s",' % "".join(row) for row in g]
out += ["]", "", "## [columna, fila, ancho, fondo, tipo] / [column, row, width, depth, kind]", "const BUILDINGS := ["]
out += ['\t[%d, %d, %d, %d, "%s"],' % b for b in BUILDINGS]
out += ["]", "", "const HOLES: Array[Vector2i] = ["]
out += ["\tVector2i(%d, %d)," % h for h in HOLES]
out += ["]", ""]
Path(__file__).resolve().parent.parent.joinpath("scripts/visual/city_layout.gd").write_text("\n".join(out))
for row in g:
    print("".join(row))
