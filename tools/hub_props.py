"""Muebles y objetos del plano astral (el lobby), en pixel art plano a escala 1:1 con la pantalla
pequeña (960 x 540). Cada pieza se dibuja con su punto de apoyo en el suelo en (0, 0), así en el
juego se coloca en su sitio y se ordena por profundidad con Kroker.
Furniture and props for the astral plane (the lobby), in flat pixel art at 1:1 with the small
screen (960 x 540). Each piece is drawn with its footing on the ground at (0, 0), so in game it
is placed at its spot and depth-sorted with Kroker.

Lo llama tools/make_sprites.py / Called by tools/make_sprites.py
"""

NIGHT = "#221e54"


def build(ms):
    mix, light, dark, rect_d, ellipse_d, star_d = ms.mix, ms.light, ms.dark, ms.rect_d, ms.ellipse_d, ms.star_d

    def ng(c, k=0.28):
        """El mismo filtro nocturno que el terreno / The same night filter as the terrain"""
        return mix(c, NIGHT, k)

    def hs(d, base, sh=0.42, rim=0.45, stroke=True, rim_c="#e8e4ff"):
        """Forma con sombra dura abajo a la derecha y filo de luz arriba a la izquierda
        Shape with a hard shadow bottom-right and a light edge top-left"""
        i = ms.uid()
        out = ["<defs><clipPath id='c%s'><path d='%s'/></clipPath></defs><path d='%s' fill='%s'/>" % (i, d, d, base),
               "<g clip-path='url(#c%s)'>" % i,
               "<path d='%s%s' transform='translate(-2.2,-1.8)' fill-rule='evenodd' fill='%s'/>" % (ms.BIG, d, mix(base, dark(base, 0.6), sh))]
        if rim > 0:
            out.append("<path d='%s%s' transform='translate(1.1,1.1)' fill-rule='evenodd' fill='%s'/>" % (ms.BIG, d, mix(base, rim_c, rim * 0.5)))
        out.append("</g>")
        if stroke:
            out.append("<path d='%s' fill='none' stroke='%s' stroke-width='1' stroke-linejoin='round'/>" % (d, dark(base, 0.5)))
        return "".join(out)

    def R(x, y, w, h, c, **k):
        return hs(rect_d(x, y, w, h), c, **k)

    def F(x, y, w, h, c):
        return "<rect x='%g' y='%g' width='%g' height='%g' fill='%s'/>" % (x, y, w, h, c)

    def E(cx, cy, rx, ry, c, **k):
        return hs(ellipse_d(cx, cy, rx, ry), c, **k)

    def P(pts, c, **k):
        d = "M" + " L".join("%g,%g" % p for p in pts) + " Z"
        return hs(d, c, **k)

    def put(name, x, y, w, h, body):
        ms.add(name, x, y, w, h, body, px=1.0, flat=True, outline="#140e26")

    # --- Plaza central / Central plaza ---
    STONE, STONE_L, STONE_D = "#6e66b8", "#8f86d6", "#4a4292"
    GOLD = "#f6d993"
    b = E(0, -4, 34, 12, STONE_D)
    b += E(0, -9, 34, 12, STONE)
    b += E(0, -10, 28, 9, "#1e2a6a", stroke=False, rim=0)
    b += E(0, -10, 22, 6, "#2a3c8a", stroke=False, rim=0)
    b += R(-4, -38, 8, 30, STONE)
    b += E(0, -38, 14, 5, STONE_L)
    b += E(0, -39, 10, 3, "#2a3c8a", stroke=False, rim=0)
    b += R(-2, -50, 4, 12, STONE)
    b += hs(star_d(0, -56, 7, 0.45), GOLD, rim=0.6)
    put("hub_fountain", -36, -66, 72, 70, b)

    b = R(-5, -3, 10, 3, STONE_D)
    b += R(-2, -34, 4, 31, STONE)
    b += R(-5, -46, 10, 12, "#3a3480")
    b += F(-3, -44, 6, 8, "#9be3ff")
    b += P([(-6, -46), (0, -51), (6, -46)], STONE_L)
    put("hub_lantern", -8, -54, 16, 56, b)

    # --- Svinho: campo de fútbol / football pitch ---
    WH = ng("#f4f1e6", 0.15)
    NET = ng("#c8c4d8", 0.2)
    b = ""
    # Red: de lado, con fondo hacia la derecha / Net: side-on, going back to the right
    b += P([(0, -24), (12, -14), (12, 0), (0, 0)], ng("#2a3a2e"), stroke=False, rim=0)
    b += P([(0, -54), (12, -44), (12, -14), (0, -24)], ng("#26302a"), stroke=False, rim=0)
    for k in range(1, 6):
        b += "<path d='M0,%g L12,%g' stroke='%s' stroke-width='0.9'/>" % (-k * 9, -k * 9 + 10, NET)
    for k in range(1, 3):
        b += "<path d='M%g,%g L%g,%g' stroke='%s' stroke-width='0.9'/>" % (k * 4, -54 + k * 3.3, k * 4, -k * 3.3 + 0, NET)
    b += "<path d='M12,-44 L12,0' stroke='%s' stroke-width='1.2'/>" % NET
    b += R(-1.5, -54, 3, 30, WH)       # poste de atrás / back post
    b += R(-1.5, -24, 3, 24, WH)       # poste de delante / front post
    b += R(-1.5, -56, 3, 4, WH)
    put("hub_goal", -4, -58, 20, 60, b)
    b = R(-0.8, -18, 1.6, 18, ng("#e8e4f0"))
    b += P([(0.8, -18), (9, -15), (0.8, -12)], ng("#ffd23a"))
    put("hub_flag", -3, -20, 14, 22, b)
    # Saco de balones / Ball bag
    b = P([(-9, 0), (-11, -10), (-6, -16), (6, -16), (11, -10), (9, 0)], ng("#2b4fa8"))
    for (x, y) in ((-4, -15), (3, -16), (0, -19)):
        b += E(x, y, 4, 4, ng("#f4f1e6"))
    put("hub_ballbag", -13, -24, 26, 26, b)

    # --- Stolk: gimnasio / gym ---
    MET, MET_D = ng("#9aa0c0"), ng("#4a4f72")
    RED = ng("#d8434f")
    b = R(-16, -6, 3, 6, MET_D) + R(13, -6, 3, 6, MET_D)
    b += R(-18, -11, 36, 6, RED)
    b += R(10, -26, 3, 20, MET_D) + R(-13, -26, 3, 20, MET_D)
    b += R(-15, -27, 30, 2, MET)
    put("hub_bench", -20, -30, 40, 32, b)
    b = R(-22, -4, 44, 4, MET_D)
    b += R(-20, -20, 3, 16, MET_D) + R(17, -20, 3, 16, MET_D)
    b += R(-20, -21, 40, 3, MET)
    b += R(-20, -11, 40, 3, MET)
    for k in range(4):
        x = -16 + k * 9
        b += R(x, -26, 2, 5, "#2b2945") + R(x + 5, -26, 2, 5, "#2b2945") + R(x + 1, -24.5, 5, 1.5, MET)
        b += R(x, -16, 2, 5, "#2b2945") + R(x + 5, -16, 2, 5, "#2b2945") + R(x + 1, -14.5, 5, 1.5, MET)
    put("hub_rack", -24, -30, 48, 32, b)
    b = E(0, -2, 10, 3, MET_D)
    b += R(-1.5, -48, 3, 46, MET_D)
    b += R(-1.5, -48, 12, 3, MET_D)
    b += R(9, -45, 1, 6, MET)
    b += hs("M4,-39 L16,-39 L16,-16 Q10,-12 4,-16 Z", RED)
    b += R(4, -36, 12, 2, ng("#2b2945"), stroke=False, rim=0)
    put("hub_bag", -12, -52, 32, 54, b)

    # --- Silly: cuarto oscuro con pantallas / dark room with screens ---
    DK, DK2 = "#1e1f2e", "#2b2c40"
    b = R(-34, -16, 68, 5, DK2)
    b += R(-32, -11, 3, 11, DK) + R(29, -11, 3, 11, DK)
    for (x, y, w, h) in ((-33, -40, 20, 16), (-10, -46, 20, 18), (13, -40, 20, 16)):
        b += R(x, y, w, h, DK)
        b += F(x + 2, y + 2, w - 4, h - 4, "#06140c")
        b += R(x + w / 2 - 1.5, y + h, 3, -y - h - 16, DK)
    b += R(-12, -19, 24, 3, "#3a3c58")
    put("hub_monitors", -38, -50, 76, 52, b)
    b = R(-7, -36, 14, 36, DK)
    for y in range(-32, -4, 4):
        b += F(-5, y, 10, 1.5, "#2b2c40")
    put("hub_server", -10, -40, 20, 42, b)
    b = E(0, -3, 9, 3, DK)
    b += R(-1, -14, 2, 11, DK)
    b += R(-8, -18, 16, 4, "#3a2a5a")
    b += R(-7, -34, 14, 16, "#3a2a5a")
    put("hub_gamerchair", -11, -38, 22, 40, b)
    b = ""
    for ang in (-1, 1):
        b += "<path d='M0,-4 L%g,-1' stroke='%s' stroke-width='2'/>" % (ang * 11, DK)
        b += E(ang * 11, -1, 2, 1.5, "#141226", stroke=False, rim=0)
    b += R(-1.5, -12, 3, 8, DK)
    b += R(-13, -14, 26, 4, "#2a1f48")
    b += hs("M-13,-12 L-14,-36 Q-14,-42 -8,-42 L8,-42 Q14,-42 14,-36 L13,-12 Z", "#3a2a5a")
    b += F(-6, -40, 3, 27, ng("#2fbf7a", 0.1)) + F(3, -40, 3, 27, ng("#2fbf7a", 0.1))
    b += R(-8, -48, 16, 7, "#3a2a5a")
    put("hub_gamerchair_back", -16, -50, 32, 52, b)

    # --- Doc: clínica podológica / podiatry clinic ---
    CH = ng("#c9cce0", 0.2)
    b = R(-26, -10, 3, 10, CH) + R(23, -10, 3, 10, CH)
    b += R(-28, -16, 56, 7, ng("#5b9ad6"))
    b += R(-30, -18, 10, 4, ng("#f4f4fa", 0.15))
    # El pie gigante, de perfil y de pie sobre la camilla, con su calcetín de rayas
    # The giant foot, side-on and standing on the couch, with its striped sock
    SK = ng("#f2c9a8", 0.15)
    SKD = dark(SK, 0.22)
    b += hs("M-16,-16 L26,-16 C29,-16 30,-22 25,-23 L16,-24 C11,-26 6,-30 1,-35 L-2,-44 L-16,-44 L-17,-36 C-20,-32 -22,-26 -21,-21 C-21,-17 -19,-16 -16,-16 Z", SK)
    for (x, y, rx, ry) in ((23, -20, 5, 4), (17, -22.5, 3.2, 3), (12.6, -24.6, 2.7, 2.6), (9, -26.8, 2.3, 2.2)):
        b += E(x, y, rx, ry, SK, rim=0.35)
    b += E(26, -21, 1.6, 1.3, ng("#ffe0e0", 0.1), stroke=False, rim=0)
    b += E(-9, -34, 2, 2, SKD, stroke=False, rim=0)
    b += "<path d='M-12,-17 C-6,-19 2,-19 8,-17' fill='none' stroke='%s' stroke-width='1'/>" % SKD
    # Calcetín / Sock
    SO = ng("#ece8f4", 0.2)
    b += R(-18, -50, 17, 10, SO)
    b += F(-18, -47, 17, 2, ng("#e2434f")) + F(-18, -43, 17, 2, ng("#5b9ad6"))
    b += R(-19, -52, 19, 3, ng("#ffffff", 0.2))
    put("hub_couch", -34, -54, 66, 56, b)
    b = R(-11, -30, 22, 30, ng("#e8eaf4", 0.2))
    b += R(-9, -28, 9, 26, ng("#d8dcec", 0.2)) + R(0, -28, 9, 26, ng("#d8dcec", 0.2))
    b += F(-3, -42, 6, 10, ng("#e2434f")) + F(-6, -39, 12, 4, ng("#e2434f"))
    b += R(-11, -44, 22, 14, ng("#e8eaf4", 0.2))
    b += F(-2, -41, 4, 8, ng("#e2434f")) + F(-5, -39, 10, 4, ng("#e2434f"))
    put("hub_cabinet", -13, -46, 26, 48, b)
    b = R(-1, -30, 2, 30, ng("#8a5a3e")) + R(-8, -2, 16, 2, ng("#8a5a3e"))
    b += R(-10, -40, 20, 26, ng("#f4f1e6", 0.15))
    b += hs("M-4,-20 L-4,-34 Q-2,-37 2,-35 L5,-28 Q7,-24 5,-20 Z", SK)
    for k, (x, y) in enumerate(((-3, -37), (0, -38), (3, -36.5))):
        b += E(x, y, 1.4, 1.4, SK, stroke=False)
    put("hub_poster", -12, -42, 24, 44, b)

    # --- Mr. Ad: escaparate de teles / TV shop window ---
    WALL, WALL_D = ng("#6a4a6a"), ng("#4a3450")
    b = R(-100, -96, 200, 96, WALL)
    for y in range(-90, -10, 8):
        off = 0 if (y // 8) % 2 else 10
        for x in range(-100 + off, 100, 20):
            b += F(x, y, 1, 7, WALL_D)
        b += F(-100, y + 7, 200, 1, WALL_D)
    # Toldo de rayas / Striped awning
    for k in range(10):
        c = ng("#ffb04a") if k % 2 == 0 else ng("#f4f1e6", 0.2)
        b += P([(-104 + k * 20.8, -96), (-104 + (k + 1) * 20.8, -96), (-104 + (k + 1) * 20.8, -84), (-104 + k * 20.8, -84)], c, stroke=False, rim=0.3)
    for k in range(10):
        b += "<path d='M%g,-84 Q%g,-79 %g,-84' fill='%s'/>" % (-104 + k * 20.8, -104 + k * 20.8 + 10.4, -104 + (k + 1) * 20.8, ng("#ffb04a") if k % 2 == 0 else ng("#f4f1e6", 0.2))
    b += R(-104, -97, 208, 3, ng("#c9a27a"))
    # Escaparate con 6 teles / Window with 6 TVs
    b += R(-90, -76, 180, 64, ng("#c9a27a"))
    b += F(-86, -72, 172, 56, "#120e2a")
    for k in range(3):
        x = -84 + k * 57
        b += R(x, -71, 54, 52, ng("#9aa0c0"))
        b += F(x + 4, -67, 46, 38, "#1e3a50")
        b += F(x + 4, -27, 46, 6, ng("#7a80a0"))
        b += E(x + 40, -24, 2, 2, "#2b2945", stroke=False, rim=0) + E(x + 46, -24, 2, 2, "#2b2945", stroke=False, rim=0)
        b += F(x + 6, -26, 20, 3, "#2b2945")
    b += R(-92, -14, 184, 6, ng("#c9a27a"))
    b += F(-92, -8, 184, 8, WALL_D)
    put("hub_shopfront", -106, -100, 212, 102, b)
    # Tele pequeña en su carrito / Small TV on its trolley
    b = R(-9, -12, 18, 3, ng("#4a4f72"))
    b += R(-8, -9, 2, 9, ng("#4a4f72")) + R(6, -9, 2, 9, ng("#4a4f72"))
    b += R(-12, -32, 24, 20, ng("#8a6440"))
    b += F(-9, -29, 16, 13, "#1e3a50")
    b += E(10, -26, 1.2, 1.2, "#2b2945", stroke=False, rim=0) + E(10, -21, 1.2, 1.2, "#2b2945", stroke=False, rim=0)
    b += "<path d='M-4,-32 L-8,-38 M2,-32 L6,-39' stroke='%s' stroke-width='1'/>" % ng("#c9cce0")
    put("hub_tv", -14, -42, 28, 44, b)

    # --- El Pinche: cocina en llamas / kitchen on fire ---
    TILE, TILE_D = ng("#e8e2d4", 0.3), ng("#c8c0b0", 0.3)
    STEEL, STEEL_D = ng("#a8aec8"), ng("#6a7090")
    b = R(-60, -70, 120, 40, TILE)
    for y in range(-66, -30, 6):
        b += F(-60, y, 120, 1, TILE_D)
    for x in range(-56, 60, 8):
        b += F(x, -70, 1, 40, TILE_D)
    b += P([(-30, -70), (30, -70), (22, -84), (-22, -84)], STEEL)
    b += R(-60, -32, 120, 6, STEEL)
    b += R(-58, -26, 116, 26, STEEL_D)
    for x in (-54, -16, 22):
        b += R(x, -22, 32, 18, STEEL)
        b += F(x + 4, -16, 24, 1.5, STEEL_D)
    for x in (-38, 0, 38):
        b += E(x, -30, 9, 2.5, "#2b2945", stroke=False, rim=0)
    # Sartenes colgadas / Hanging pans
    for x in (-50, 46):
        b += "<path d='M%g,-70 L%g,-62' stroke='%s' stroke-width='1'/>" % (x, x, STEEL_D)
        b += E(x, -56, 6, 6, "#2b2945")
    put("hub_stove", -64, -88, 128, 90, b)
    b = R(-12, -46, 24, 46, ng("#e8eaf4", 0.25))
    b += F(-12, -30, 24, 1, ng("#9aa0c0"))
    b += R(7, -42, 2, 9, ng("#9aa0c0")) + R(7, -26, 2, 12, ng("#9aa0c0"))
    b += R(-6, -40, 6, 5, ng("#ff8fb0")) + R(1, -38, 4, 5, ng("#8fe0ff"))
    put("hub_fridge", -14, -48, 28, 50, b)
    b = P([(-6, 0), (-7, -18), (-4, -22), (4, -22), (7, -18), (6, 0)], ng("#e2434f"))
    b += R(-3, -27, 6, 5, "#2b2945")
    b += R(2, -27, 7, 2, "#2b2945")
    put("hub_extinguisher", -9, -30, 20, 32, b)

    # --- Charo: sillón de tejer / knitting armchair ---
    TEAL, TEAL_D = ng("#4fa89a"), ng("#3f8a7e")
    b = hs("M-20,-12 L-20,-44 Q-20,-50 -12,-50 L12,-50 Q20,-50 20,-44 L20,-12 Z", TEAL)
    b += R(-17, -18, 34, 8, TEAL)
    b += R(-18, -10, 3, 10, ng("#6a4430")) + R(15, -10, 3, 10, ng("#6a4430"))
    put("hub_chair_back", -24, -54, 48, 56, b)
    b = hs("M-25,-6 L-25,-26 Q-25,-30 -20,-30 Q-15,-30 -15,-26 L-15,-6 Z", TEAL_D)
    b += hs("M15,-6 L15,-26 Q15,-30 20,-30 Q25,-30 25,-26 L25,-6 Z", TEAL_D)
    b += R(-25, -6, 50, 4, TEAL_D)
    b += F(-24, -2, 3, 2, ng("#6a4430")) + F(21, -2, 3, 2, ng("#6a4430"))
    put("hub_chair_front", -28, -34, 56, 36, b)
    b = E(0, -2, 7, 2.5, ng("#6a4430"))
    b += R(-1, -40, 2, 38, ng("#6a4430"))
    b += P([(-10, -38), (-6, -52), (6, -52), (10, -38)], ng("#f2c2a0", 0.2))
    for x in range(-9, 10, 3):
        b += F(x, -38, 1, 2, ng("#c8506a"))
    put("hub_floorlamp", -12, -56, 24, 58, b)
    b = R(-9, -14, 18, 14, ng("#c9a27a"))
    for y in (-11, -7, -3):
        b += F(-9, y, 18, 1, ng("#a8804a"))
    b += E(-3, -16, 4, 4, ng("#e85d75")) + E(4, -16, 4, 4, ng("#7fbfe0")) + E(0, -19, 3.5, 3.5, ng("#f6d993"))
    b += "<path d='M-1,-21 L-1,-28' stroke='#dfe6ff' stroke-width='1'/><path d='M2,-21 L4,-28' stroke='#dfe6ff' stroke-width='1'/>"
    put("hub_basket", -12, -30, 24, 32, b)

    # --- Magnus: despacho / office ---
    WOOD, WOOD_D, WOOD_L = ng("#6a3424"), ng("#4a2418"), ng("#8a4a32")
    GOLD2 = ng("#c9961e", 0.15)
    b = hs("M-12,-14 L-12,-40 Q-12,-46 0,-46 Q12,-46 12,-40 L12,-14 Z", ng("#2a1d22"))
    for y in (-40, -32, -24):
        b += F(-9, y, 18, 1, ng("#3a2a32"))
    put("hub_bigchair", -16, -50, 32, 38, b)
    b = R(-36, -24, 72, 6, WOOD_L)
    b += R(-34, -18, 68, 18, WOOD)
    b += F(-34, -18, 68, 2, GOLD2)
    b += R(-30, -15, 18, 12, WOOD_D) + R(12, -15, 18, 12, WOOD_D)
    b += F(-22, -10, 3, 2, GOLD2) + F(19, -10, 3, 2, GOLD2)
    b += R(-6, -28, 12, 4, GOLD2)      # placa con su nombre / nameplate
    b += R(-28, -27, 12, 3, ng("#f4f1e6", 0.2))  # papeles / papers
    b += R(18, -29, 10, 5, "#2b2945")  # teléfono / phone
    b += R(19, -32, 8, 2, "#2b2945")
    put("hub_desk", -40, -36, 80, 38, b)
    b = R(-11, -24, 22, 24, ng("#4a4f72"))
    b += R(-8, -21, 16, 18, ng("#3a3f5c"))
    b += E(0, -12, 4, 4, ng("#9aa0c0"))
    b += F(6, -14, 2, 4, ng("#9aa0c0"))
    put("hub_safe", -13, -26, 26, 28, b)
    b = "<path d='M-8,0 L0,-36 L8,0 M0,-36 L0,-2' fill='none' stroke='%s' stroke-width='1.6'/>" % WOOD_D
    b += R(-13, -38, 26, 22, GOLD2)
    b += F(-10, -35, 20, 16, ng("#2f6e4a"))
    b += "<path d='M-8,-21 L-3,-25 L1,-23 L8,-32' fill='none' stroke='%s' stroke-width='1.4'/>" % ng("#f2c94c")
    b += P([(8, -32), (5, -32), (8, -29)], ng("#f2c94c"), stroke=False, rim=0)
    put("hub_chart", -15, -40, 30, 42, b)
    b = P([(-6, 0), (-7, -9), (7, -9), (6, 0)], ng("#a85a3e"))
    for (x, y, rx, ry) in ((-4, -15, 4, 7), (4, -16, 4, 7), (0, -21, 4, 8), (-6, -12, 3, 5), (6, -12, 3, 5)):
        b += E(x, y, rx, ry, ng("#3f8a4a"))
    put("hub_plant", -10, -32, 20, 34, b)

    # --- Armario / Wardrobe ---
    WD, WD_D, WD_L = ng("#7a5236", 0.2), ng("#5a3a2a", 0.2), ng("#9a6a46", 0.2)
    b = R(-46, -86, 92, 86, WD)
    b += R(-44, -82, 88, 76, "#1e1630")
    b += F(-42, -74, 84, 2, ng("#c9a27a"))
    # Perchas y alguna prenda / Hangers and a few clothes
    for k, c in enumerate(("#ff8fb0", "#8fe0ff", "#f6d993", "#b46e8f", "#62a9a1")):
        x = -34 + k * 16
        b += "<path d='M%g,-72 L%g,-68 M%g,-68 L%g,-68' stroke='#c9cce0' stroke-width='1'/>" % (x, x, x - 5, x + 5)
        if k % 2 == 0:
            b += P([(x - 6, -68), (x + 6, -68), (x + 5, -44), (x - 5, -44)], ng(c), rim=0.3)
    b += R(-44, -24, 88, 16, WD_D)
    b += F(-4, -18, 8, 2, ng("#c9a27a"))
    b += R(-48, -90, 96, 6, WD_L)
    # Puertas abiertas / Open doors
    b += P([(-46, -86), (-62, -80), (-62, -4), (-46, 0)], WD_L)
    b += P([(46, -86), (62, -80), (62, -4), (46, 0)], WD_L)
    b += F(-58, -46, 2, 6, ng("#c9a27a")) + F(56, -46, 2, 6, ng("#c9a27a"))
    put("hub_wardrobe", -64, -92, 128, 94, b)
    b = E(0, -1.5, 8, 2.5, ng("#8a8fb0"))
    b += R(-1, -50, 2, 48, ng("#8a8fb0"))
    b += R(-9, -52, 18, 2, ng("#8a8fb0"))
    put("hub_stand", -10, -54, 20, 56, b)
    b = R(-10, -42, 20, 40, WD)
    b += F(-8, -40, 16, 36, ng("#8fb8e0", 0.35))
    b += "<path d='M-6,-34 L-2,-38 M-6,-28 L2,-36' stroke='#e8f4ff' stroke-width='1'/>"
    b += R(-6, -2, 3, 2, WD) + R(3, -2, 3, 2, WD)
    put("hub_mirror", -12, -44, 24, 46, b)

    # --- Museo / Museum ---
    MB, MB_L, MB_D = ng("#d4cde6", 0.3), ng("#ece8f6", 0.3), ng("#a8a0c8", 0.3)
    b = R(-9, -6, 18, 6, MB_D)
    b += R(-6, -62, 12, 56, MB)
    for x in (-3, 0, 3):
        b += F(x, -60, 1, 52, MB_D)
    b += R(-9, -68, 18, 6, MB_L)
    put("hub_column", -11, -70, 22, 72, b)
    b = R(-12, -16, 24, 16, MB)
    b += R(-14, -19, 28, 4, MB_L)
    b += R(-14, -2, 28, 2, MB_D)
    b += R(-5, -11, 10, 5, GOLD2)
    put("hub_pedestal", -16, -22, 32, 24, b)
    b = E(0, -1, 3, 1.5, GOLD2) + R(-1, -13, 2, 12, GOLD2) + E(0, -14, 2, 2, GOLD2)
    put("hub_post", -4, -17, 8, 19, b)
