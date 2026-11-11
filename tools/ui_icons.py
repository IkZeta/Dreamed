"""Iconos de la interfaz en pixel art plano, con el mismo sombreado duro que el resto del juego:
uno por estadística (para las cartas de subir de nivel y la pausa) y uno por estado alterado
(para la fila de estados bajo la vida). Cada icono se dibuja en un cuadro de 32 x 32 centrado en
(0, 0); las estadísticas salen a 32 píxeles y los estados a 16.
UI icons in flat pixel art, with the same hard shading as the rest of the game: one per stat (for
the level-up cards and the pause screen) and one per status effect (for the status row under the
health bar). Each icon is drawn in a 32 x 32 box centred on (0, 0); stats render at 32 pixels and
statuses at 16.

Lo llama tools/make_sprites.py / Called by tools/make_sprites.py
"""

OUTLINE = "#140e26"


def build(ms):
    mix, light, dark, ellipse_d, star_d = ms.mix, ms.light, ms.dark, ms.ellipse_d, ms.star_d

    def hs(d, base, sh=0.4, rim=0.5):
        """Forma con sombra dura abajo a la derecha y filo de luz arriba a la izquierda
        Shape with a hard shadow bottom-right and a light edge top-left"""
        i = ms.uid()
        return ("<defs><clipPath id='c%s'><path d='%s'/></clipPath></defs><path d='%s' fill='%s'/>"
                "<g clip-path='url(#c%s)'><path d='%s%s' transform='translate(-2,-2)' fill-rule='evenodd' fill='%s'/>"
                "<path d='%s%s' transform='translate(1.4,1.4)' fill-rule='evenodd' fill='%s'/></g>") % (
            i, d, d, base, i, ms.BIG, d, mix(base, dark(base, 0.6), sh), ms.BIG, d, mix(base, "#fbf8ff", rim * 0.6))

    def F(d, c):
        return "<path d='%s' fill='%s'/>" % (d, c)

    def P(pts):
        return "M" + " L".join("%g,%g" % p for p in pts) + " Z"

    def E(cx, cy, rx, ry):
        return ellipse_d(cx, cy, rx, ry)

    def icon(name, body, px):
        ms.add(name, -16, -16, 32, 32, body, px=px, flat=True, outline=OUTLINE)

    STEEL, STEEL_D = "#d8dcf0", "#8a90b8"
    GOLD, GOLD_D = "#f6c95a", "#b8862a"
    PINK, RED, RED_D = "#ff8fb0", "#e8455a", "#a82a44"
    WHITE = "#fbf8ff"
    GREEN, GREEN_D = "#7fdc6a", "#3f9a4a"
    BLUE, BLUE_D = "#7fb8ff", "#3f6ac8"
    BROWN = "#8a5a3e"
    PURPLE = "#b48cff"

    icons = {}

    # Ataque: espada en diagonal / Attack: a diagonal sword
    b = hs(P([(-11, 11), (-14, 8), (8, -14), (13, -13), (11, -8)]), STEEL)
    b += F(P([(-9, 9), (8, -8), (9, -9), (-8, 8)]), WHITE)
    b += hs(P([(-12, 2), (-2, 12), (0, 10), (-10, 0)]), GOLD)
    b += hs(P([(-13, 9), (-9, 13), (-12, 16), (-16, 12)]), BROWN, rim=0.2)
    b += hs(E(-15, 15, 2.5, 2.5), GOLD)
    icons["attack"] = b

    # Defensa: escudo con una luna / Defence: a shield with a moon
    d = "M0,-14 L12,-10 L12,0 Q12,10 0,15 Q-12,10 -12,0 L-12,-10 Z"
    b = hs(d, BLUE)
    b += hs("M0,-10 L8,-7 L8,0 Q8,7 0,11 Q-8,7 -8,0 L-8,-7 Z", BLUE_D, sh=0.2, rim=0.2)
    b += hs(star_d(0, 0, 7, 0.45), GOLD, rim=0.3)
    icons["defense"] = b

    # Velocidad: zapatilla con ala / Speed: a winged sneaker
    b = ""
    for y, x0 in ((-6, -15), (0, -16), (6, -15)):
        b += F(P([(x0, y - 1), (x0 + 6, y - 1), (x0 + 6, y + 1), (x0, y + 1)]), BLUE)
    b += hs("M-8,-4 L-2,-8 L4,-4 Q12,0 14,4 L14,8 L-10,8 Z", PINK)
    b += F(P([(-10, 8), (14, 8), (14, 11), (-10, 11)]), WHITE)
    b += F(P([(-2, -2), (4, -1), (3, 1), (-3, 0)]), WHITE)
    b += F(P([(2, 1), (8, 2), (7, 4), (1, 3)]), WHITE)
    icons["speed"] = b

    # Velocidad de ataque: cronómetro con un rayo / Attack speed: a stopwatch with a lightning bolt
    b = hs(E(0, 2, 12, 12), STEEL)
    b += hs(E(0, 2, 9, 9), WHITE, sh=0.15, rim=0.0)
    b += hs(P([(-3, -14), (3, -14), (3, -10), (-3, -10)]), GOLD)
    b += hs(P([(8, -10), (12, -6), (10, -4), (6, -8)]), STEEL_D)
    b += F(P([(2, -6), (-4, 3), (0, 3), (-2, 10), (5, 0), (1, 0)]), GOLD)
    icons["attack_speed"] = b

    # Alcance: diana con una flecha clavada / Range: a target with an arrow stuck in it
    b = hs(E(-2, 2, 12, 12), WHITE)
    b += F(E(-2, 2, 9, 9), RED)
    b += F(E(-2, 2, 6, 6), WHITE)
    b += F(E(-2, 2, 3, 3), RED)
    b += F(P([(-2, 1), (12, -13), (13, -12), (-1, 2)]), BROWN)
    b += hs(P([(10, -15), (15, -15), (15, -10), (13, -12), (11, -13)]), PURPLE)
    icons["range"] = b

    # Recuperación de salud: corazón con una cruz / Health regeneration: a heart with a cross
    heart = "M0,13 L-12,1 Q-15,-3 -13,-8 Q-10,-13 -5,-12 Q-2,-11 0,-8 Q2,-11 5,-12 Q10,-13 13,-8 Q15,-3 12,1 Z"
    b = hs(heart, PINK)
    b += F(P([(-2, -6), (2, -6), (2, -2), (6, -2), (6, 2), (2, 2), (2, 6), (-2, 6), (-2, 2), (-6, 2), (-6, -2), (-2, -2)]), WHITE)
    icons["regen"] = b

    # Robo de salud: colmillo y gota / Life steal: a fang and a drop
    # (corazón con dos colmillos que lo muerden y gotean / a heart bitten by two dripping fangs)
    b = hs("M0,14 L-12,2 Q-15,-2 -13,-7 Q-10,-12 -5,-11 Q-2,-10 0,-7 Q2,-10 5,-11 Q10,-12 13,-7 Q15,-2 12,2 Z", RED)
    b += hs(P([(-8, -16), (-3, -16), (-5.5, -5)]), WHITE, rim=0.2)
    b += hs(P([(3, -16), (8, -16), (5.5, -5)]), WHITE, rim=0.2)
    b += F("M-5.5,-4 Q-3.5,-1 -5.5,1 Q-7.5,-1 -5.5,-4 Z", WHITE)
    b += F("M5.5,-4 Q7.5,-1 5.5,1 Q3.5,-1 5.5,-4 Z", WHITE)
    icons["lifesteal"] = b

    # Suerte: trébol de cuatro hojas / Luck: a four-leaf clover
    b = F("M0,0 Q4,10 2,16 L0,16 Q2,10 -1,1 Z", GREEN_D)
    for ang in (0, 90, 180, 270):
        b += "<g transform='rotate(%d)'>%s</g>" % (ang, hs("M0,0 Q-2,-6 -7,-9 Q-10,-11 -10,-7 Q-12,-3 -7,-2 Q-3,-1 0,0 Z", GREEN))
    b += F(E(0, 0, 2, 2), GREEN_D)
    icons["luck"] = b

    # Parry: chasquido de dedos con destello / Parry: a finger snap with a flash
    b = hs("M-8,14 L-12,2 Q-13,-4 -8,-6 L-4,-7 L-6,-14 Q-4,-16 -2,-14 L1,-6 L6,-6 Q10,-5 9,0 L6,8 L2,14 Z", "#f2c4a8")
    b += F(P([(-4, -7), (1, -6), (0, -3), (-4, -4)]), "#d8a488")
    b += F(star_d(9, -10, 7, 0.4), GOLD)
    b += F(star_d(9, -10, 3, 0.5), WHITE)
    for x1, y1, x2, y2 in ((14, -2, 16, 0), (2, -15, 1, -16), (15, -15, 16, -16)):
        b += "<path d='M%g,%g L%g,%g' stroke='%s' stroke-width='1.6'/>" % (x1, y1, x2, y2, GOLD)
    icons["parry"] = b

    for k, body in icons.items():
        icon("icon_" + k, body, 1.0)

    # --- Estados alterados / Status effects ---
    st = {}
    st["bleed"] = hs("M0,-14 Q10,0 9,6 Q8,14 0,14 Q-8,14 -9,6 Q-10,0 0,-14 Z", RED) + F(E(-4, 4, 2.5, 3.5), WHITE)
    st["rooted"] = (hs(P([(4, -15), (-9, 2), (-1, 2), (-5, 15), (10, -3), (2, -3)]), "#f6d24a"))
    st["slow"] = (hs("M-14,10 Q-14,4 -8,4 L6,4 Q8,4 10,8 L14,10 Z", "#bfe0ff")
                  + hs(E(2, -2, 8, 8), BLUE) + hs(E(2, -2, 4, 4), BLUE_D, rim=0.1)
                  + "<path d='M-10,4 L-13,-6 M-7,4 L-8,-7' stroke='#bfe0ff' stroke-width='2'/>")
    st["stench"] = (hs("M-12,8 Q-15,2 -9,-1 Q-9,-8 -2,-8 Q3,-13 8,-7 Q15,-6 13,2 Q15,9 8,10 L-8,11 Q-12,11 -12,8 Z", "#8fd14f")
                    + "<path d='M-6,-11 Q-8,-14 -5,-16 M2,-13 Q0,-16 3,-17' fill='none' stroke='#8fd14f' stroke-width='2'/>"
                    + F(E(-4, 2, 2, 2), "#3f6a2a") + F(E(4, 2, 2, 2), "#3f6a2a"))
    st["hack"] = (hs(P([(-13, -10), (13, -10), (13, 8), (-13, 8)]), "#2a2440", sh=0.1, rim=0.2)
                  + F(P([(-10, -7), (10, -7), (10, 5), (-10, 5)]), "#ff5fd2")
                  + F(P([(-7, -4), (-3, -4), (-3, -1), (-7, -1)]), "#2a2440") + F(P([(3, -4), (7, -4), (7, -1), (3, -1)]), "#2a2440")
                  + F(P([(-6, 2), (6, 2), (6, 3), (-6, 3)]), "#2a2440")
                  + F(P([(-4, 8), (4, 8), (6, 13), (-6, 13)]), "#2a2440") + F(P([(-14, -3), (-10, -3), (-10, -1), (-14, -1)]), "#5ff2ff"))
    for k, body in st.items():
        icon("status_" + k, body, 0.5)


def wares(ms):
    """Los artículos del kiosco de Charo (32 x 32, a 32 píxeles) / Charo's kiosk wares (32 x 32, at 32 pixels)"""
    mix, dark, ellipse_d, star_d = ms.mix, ms.dark, ms.ellipse_d, ms.star_d

    def hs(d, base, sh=0.4, rim=0.5):
        i = ms.uid()
        return ("<defs><clipPath id='c%s'><path d='%s'/></clipPath></defs><path d='%s' fill='%s'/>"
                "<g clip-path='url(#c%s)'><path d='%s%s' transform='translate(-2,-2)' fill-rule='evenodd' fill='%s'/>"
                "<path d='%s%s' transform='translate(1.4,1.4)' fill-rule='evenodd' fill='%s'/></g>") % (
            i, d, d, base, i, ms.BIG, d, mix(base, dark(base, 0.6), sh), ms.BIG, d, mix(base, "#fbf8ff", rim * 0.6))

    def F(d, c):
        return "<path d='%s' fill='%s'/>" % (d, c)

    def P(pts):
        return "M" + " L".join("%g,%g" % p for p in pts) + " Z"

    def R(x, y, w, h):
        return P([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])

    E = ellipse_d
    W, INK, PINK, RED, GOLD, BLUE, GREEN, CREAM = "#fbf8ff", "#2a2440", "#f2b8d8", "#e85d75", "#ffd27a", "#7fb8ff", "#8fd17a", "#f4ecdc"
    out = {}
    # Nivel 1 / Tier 1
    out["milk"] = (hs(P([(-8, -8), (8, -8), (9, 14), (-9, 14)]), PINK) + hs(P([(-8, -12), (8, -12), (8, -8), (-8, -8)]), W)
                   + F(R(-4, -2, 8, 8), W) + "<path d='M3,-12 L8,-19' stroke='%s' stroke-width='2.4'/>" % RED + F(E(0, 2, 2.5, 2.5), PINK))
    out["candy"] = (hs(P([(-8, 0), (-15, -7), (-15, 7)]), RED) + hs(P([(8, 0), (15, -7), (15, 7)]), RED)
                    + hs(E(0, 0, 9, 9), "#f6c86a") + "<path d='M-6,-3 Q0,-8 6,-3 M-6,3 Q0,-2 6,3' fill='none' stroke='%s' stroke-width='2'/>" % W)
    out["glasses"] = (hs(E(-7, 0, 7, 6), "#7a2e4a") + hs(E(7, 0, 7, 6), "#7a2e4a") + F(E(-7, 0, 5, 4), "#cfe0ff") + F(E(7, 0, 5, 4), "#cfe0ff")
                      + F(R(-1, -2, 2, 2), "#7a2e4a") + F(R(-9, -2, 2, 2), W) + F(R(5, -2, 2, 2), W))
    out["sneakers"] = (hs("M-14,8 L-13,-4 L-5,-7 L1,0 Q12,1 14,4 L14,8 Z", BLUE) + F(R(-14, 8, 28, 4), W)
                       + "<path d='M-6,-4 L0,-1 M-8,0 L-2,2' stroke='%s' stroke-width='1.6'/>" % W + F(E(-9, 10, 1.5, 1.5), RED) + F(E(0, 10, 1.5, 1.5), GOLD) + F(E(9, 10, 1.5, 1.5), GREEN))
    out["plasters"] = ("<g transform='rotate(35)'>%s%s</g>" % (hs(R(-14, -4, 28, 8), "#f2c4a8"), F(R(-4, -4, 8, 8), "#e6d0c0"))
                       + "<g transform='rotate(-35)'>%s%s</g>" % (hs(R(-14, -4, 28, 8), "#f2c4a8"), F(R(-4, -4, 8, 8), "#e6d0c0")))
    # Nivel 2 / Tier 2
    out["gum"] = hs(E(0, -2, 11, 11), "#f2a6c8") + F(E(-4, -6, 3, 3), W) + hs(R(-7, 9, 14, 5), "#e3a6c4")
    out["soda"] = (hs(R(-8, -12, 16, 25), RED) + hs(R(-8, -14, 16, 3), "#cfc8ec") + F(R(-8, -3, 16, 6), W)
                   + F(E(-2, -18, 1.5, 1.5), W) + F(E(3, -21, 1.5, 1.5), W))
    out["stickers"] = (hs(R(-12, -13, 19, 23), "#cfc8ec") + hs(R(-7, -10, 19, 23), W) + F(R(-5, -8, 15, 13), BLUE)
                       + F(E(2, -3, 3, 3), "#f1cfbb") + F(R(-1, 0, 6, 4), "#2f9e5b"))
    out["sandwich"] = (hs(P([(-14, 2), (-10, -7), (10, -7), (14, 2)]), "#e0a95a") + F(R(-14, 2, 28, 3), "#c9534a") + F(R(-13, 5, 26, 2), GREEN)
                       + hs(P([(-14, 7), (14, 7), (12, 12), (-12, 12)]), "#e0a95a"))
    out["battery"] = (hs(R(-7, -12, 14, 25), "#4fa89a") + hs(R(-3, -15, 6, 3), "#cfc8ec") + F(R(-7, 2, 14, 11), GOLD)
                      + F(P([(1, -9), (-3, 0), (0, 0), (-1, 8), (4, -1), (1, -1)]), W))
    out["newspaper"] = (hs(R(-13, -10, 26, 21), CREAM) + F(R(-11, -8, 22, 3), INK) + F(R(-11, -2, 10, 9), BLUE)
                        + F(R(1, -2, 10, 1.5), mix(INK, CREAM, 0.4)) + F(R(1, 1.5, 10, 1.5), mix(INK, CREAM, 0.4)) + F(R(1, 5, 10, 1.5), mix(INK, CREAM, 0.4)))
    # Nivel 3 / Tier 3
    out["gold_sticker"] = (hs(R(-12, -13, 19, 23), "#cfc8ec") + hs(R(-7, -10, 19, 23), GOLD) + F(R(-5, -8, 15, 13), "#e0a93a")
                           + F(star_d(2, -2, 5, 0.45), W) + F(star_d(12, -12, 3, 0.4), W))
    out["cake"] = (hs(R(-13, -2, 26, 14), PINK) + hs(R(-13, -5, 26, 4), W) + F(E(-8, -1, 1.6, 1.6), W) + F(E(0, -1, 1.6, 1.6), W) + F(E(8, -1, 1.6, 1.6), W)
                   + F(R(-1, -13, 2, 8), BLUE) + F(E(0, -15, 2.4, 3), GOLD))
    out["coin"] = hs(E(0, 0, 12, 12), "#e0a93a") + F(E(0, 0, 9, 9), GOLD) + "".join(F(E(x, y, 2.5, 2.5), "#2f9e5b") for x, y in ((-3, -3), (3, -3), (-3, 3), (3, 3)))
    out["batteries"] = "".join(hs(R(x - 5, y - 11, 10, 22), GOLD) + hs(R(x - 2, y - 14, 4, 3), "#cfc8ec") + F(R(x - 5, y + 2, 10, 9), RED)
                               for x, y in ((-7, -1), (7, 2)))
    out["sunday_paper"] = (hs(R(-9, -13, 24, 21), "#d8ceb8") + hs(R(-14, -9, 24, 21), CREAM) + F(R(-12, -7, 20, 3), INK) + F(R(-12, -2, 9, 9), GOLD)
                           + F(R(-1, -2, 9, 1.5), mix(INK, CREAM, 0.4)) + F(R(-1, 2, 9, 1.5), mix(INK, CREAM, 0.4)))
    # Nivel 4 / Tier 4
    out["energy_drink"] = (hs(R(-8, -13, 16, 26), "#2a2a3a") + hs(R(-8, -15, 16, 3), "#cfc8ec")
                           + F(P([(2, -9), (-4, 1), (0, 1), (-2, 9), (5, -2), (1, -2)]), "#9cff5a"))
    out["lucky_cat"] = (hs(E(0, 5, 11, 9), W) + hs(E(0, -6, 9, 8), W) + hs(P([(-8, -9), (-6, -16), (-2, -12)]), W) + hs(P([(8, -9), (6, -16), (2, -12)]), W)
                        + F(R(-5, -7, 3, 1.5), INK) + F(R(2, -7, 3, 1.5), INK) + F(R(-8, 2, 16, 2), RED) + F(E(0, 6, 3, 3), GOLD)
                        + hs(P([(9, -1), (13, -9), (15, -8), (11, 1)]), W))
    out["first_aid"] = (hs(R(-13, -9, 26, 20), W) + hs(R(-5, -13, 10, 4), "#cfc8ec") + F(R(-2, -6, 4, 14), RED) + F(R(-7, -1, 14, 4), RED))
    out["comic"] = (hs(R(-11, -14, 22, 28), BLUE) + F(R(-9, -12, 18, 6), GOLD) + hs(P([(0, -4), (8, 10), (-8, 10)]), RED)
                    + F(P([(-3, 2), (-1, 2), (-1, 4), (1, 2), (3, 2), (0, 5), (3, 8), (1, 8), (-1, 6), (-1, 8), (-3, 8)]), W))
    out["encyclopedia"] = "".join(hs(R(-13 + k * 9, -13, 8, 26), c) + F(R(-12 + k * 9, -8, 6, 2), GOLD) + F(R(-12 + k * 9, 6, 6, 2), GOLD)
                                  for k, c in enumerate(("#7a2e4a", "#2f5e9e", "#2f9e5b")))
    # Cachivaches con efecto propio / Knick-knacks with an effect of their own
    YEL, ORANGE, PURPLE, BROWN, ICE = "#ffd84a", "#ff9a3a", "#b77bff", "#9a5a3a", "#bfe8ff"
    out["rubber_duck"] = (hs(E(0, 6, 12, 8), YEL) + hs(E(-4, -5, 7, 7), YEL) + F(P([(-11, -5), (-16, -3), (-11, -1)]), ORANGE)
                          + F(E(-5, -7, 1.5, 1.5), INK) + F(E(-6, -8, 0.6, 0.6), W) + hs(P([(4, 2), (12, 0), (9, 8)]), "#f6c43a"))
    out["firecrackers"] = ("".join(hs(R(x - 3, y - 10, 6, 20), RED) + F(R(x - 3, y - 4, 6, 3), GOLD)
                                   + "<path d='M%g,%g q3,-4 1,-7' fill='none' stroke='%s' stroke-width='1.6'/>" % (x, y - 10, INK)
                                   for x, y in ((-8, 3), (0, -1), (8, 3)))
                           + F(star_d(2, -16, 4, 0.4), YEL))
    out["piggy_bank"] = (hs(E(0, 2, 13, 10), PINK) + hs(E(-12, 1, 3.5, 4), "#f29ac0") + F(E(-13, 0, 0.8, 1.2), "#a8507a") + F(E(-13, 2.5, 0.8, 1.2), "#a8507a")
                         + hs(P([(-6, -6), (-4, -12), (-1, -7)]), PINK) + F(R(-2, -9, 6, 2), INK) + F(E(-6, -1, 1.3, 1.3), INK)
                         + F(R(-8, 10, 4, 4), "#e48ab0") + F(R(5, 10, 4, 4), "#e48ab0") + F(E(4, -14, 4, 4), GOLD) + F(E(4, -14, 2.5, 2.5), "#e0a93a"))
    out["water_balloon"] = (hs(P([(0, -14), (9, -8), (11, 2), (6, 10), (0, 12), (-6, 10), (-11, 2), (-9, -8)]), "#4fa8e8")
                            + F(E(-4, -5, 3, 4), ICE) + hs(P([(-2, 12), (2, 12), (3, 16), (-3, 16)]), "#2a6fae")
                            + F(E(10, 12, 1.5, 2), "#7fd0ff") + F(E(-11, 10, 1.2, 1.6), "#7fd0ff"))
    out["whistle"] = (hs("M-12,-2 L4,-2 Q12,-2 12,6 Q12,13 4,13 Q-3,13 -3,6 L-12,6 Z", "#cfc8ec") + F(R(-12, -2, 3, 8), "#a39cc4")
                      + F(E(4, 6, 3.5, 3.5), "#7a7298") + "<path d='M10,-1 Q16,-8 13,-14' fill='none' stroke='%s' stroke-width='1.8'/>" % RED
                      + F(R(-4, -6, 4, 4), INK))
    out["voodoo"] = (hs(E(0, -8, 7, 7), "#c9a074") + hs(P([(-6, -2), (6, -2), (8, 13), (-8, 13)]), "#c9a074") + hs(R(-13, 0, 26, 4), "#c9a074")
                     + "<path d='M-3,-10 l2,2 m0,-2 l-2,2 M2,-10 l2,2 m0,-2 l-2,2' stroke='%s' stroke-width='1.2'/>" % INK
                     + F(R(-3, -4, 6, 1.2), INK) + "<path d='M-2,2 L-2,12 M2,4 L3,11' stroke='%s' stroke-width='0.8' stroke-dasharray='1.5,1.5'/>" % BROWN
                     + "<path d='M4,4 L15,-6' stroke='%s' stroke-width='1.5'/>" % "#cfc8ec" + F(E(15, -6, 2.4, 2.4), RED))
    out["magnet"] = (hs("M-11,-10 L-4,-10 L-4,3 Q-4,7 0,7 Q4,7 4,3 L4,-10 L11,-10 L11,3 Q11,14 0,14 Q-11,14 -11,3 Z", RED)
                     + F(R(-11, -14, 7, 4), "#dfe3f0") + F(R(4, -14, 7, 4), "#dfe3f0")
                     + F(star_d(-14, -2, 3, 0.4), "#ff6fb5") + F(star_d(14, -3, 3, 0.4), "#5fc8ff"))
    out["matches"] = (hs(R(-12, -4, 24, 16), "#e8b84a") + F(R(-12, 2, 24, 4), RED) + hs(R(-9, -10, 14, 7), "#f4ecdc")
                      + "".join(F(R(x, -15, 2, 8), "#e0c28a") + F(E(x + 1, -16, 1.8, 2.2), RED) for x in (-8, -4, 0)) + F(E(4, -21, 3, 4), ORANGE) + F(E(4, -20, 1.5, 2), YEL))
    out["alarm_clock"] = (hs(E(0, 2, 12, 12), RED) + F(E(0, 2, 9, 9), W) + hs(E(-9, -10, 4, 4), GOLD) + hs(E(9, -10, 4, 4), GOLD)
                          + "<path d='M0,2 L0,-4 M0,2 L4,4' stroke='%s' stroke-width='1.8'/>" % INK
                          + F(R(-9, 13, 3, 3), INK) + F(R(6, 13, 3, 3), INK))
    out["pinata"] = (hs(P([(-12, -2), (-6, -8), (8, -8), (13, -2), (11, 8), (-10, 8)]), "#ff6fb5") + F(R(-11, -3, 23, 3), YEL) + F(R(-11, 3, 22, 3), "#5fc8ff")
                     + hs(P([(-12, -2), (-18, -10), (-14, -12), (-8, -6)]), "#ff6fb5") + F(E(-15, -9, 0.9, 0.9), INK)
                     + F(R(-8, 8, 3, 6), "#e85d9a") + F(R(6, 8, 3, 6), "#e85d9a") + "<path d='M2,-8 L2,-16' stroke='%s' stroke-width='1'/>" % INK)
    out["snow_globe"] = (hs(R(-10, 8, 20, 6), BROWN) + hs(E(0, -3, 12, 12), "#9fd4ff") + F(E(-4, -7, 3, 4), "#e6f4ff")
                         + F(P([(0, -9), (5, 3), (-5, 3)]), "#2f9e5b") + F(R(-1, 3, 2, 3), BROWN)
                         + "".join(F(E(x, y, 1, 1), W) for x, y in ((-7, -2), (6, -6), (3, 5), (-3, -11), (8, 1))))
    out["music_box"] = (hs(R(-13, -2, 26, 14), "#7a2e4a") + hs(P([(-13, -2), (-9, -9), (9, -9), (13, -2)]), "#9a4060")
                        + F(R(-13, 3, 26, 2), GOLD) + F(R(13, 0, 3, 2), GOLD) + F(R(15, -2, 2, 6), GOLD)
                        + F(E(-5, -14, 2.4, 2), PURPLE) + F(R(-3.2, -21, 1.4, 7), PURPLE) + F(E(4, -17, 2.4, 2), PURPLE) + F(R(5.8, -24, 1.4, 7), PURPLE))
    # Brújula de sueños: la aguja señala un agujerito estrellado / Dream compass: the needle points at a starry little hole
    out["compass"] = (hs(E(0, 0, 13, 13), GOLD) + F(E(0, 0, 10, 10), CREAM)
                      + F(E(6, -6, 3.4, 2.4), "#0a0820") + F(E(6, -6, 0.9, 0.9), W)
                      + F(P([(-8, 8), (5, -5), (2, 1), (-1, -2)]), RED) + F(P([(-8, 8), (-1, -2), (2, 1)]), "#a8304a")
                      + F(E(0, 0, 1.8, 1.8), INK) + hs(R(-2, -17, 4, 4), GOLD))
    # Pala de playa clavada junto a un hoyo que da al cielo / Beach shovel stuck next to a hole that opens onto the sky
    out["beach_shovel"] = (F(E(-4, 12, 11, 4), "#0a0820") + F(E(-4, 12, 8, 2.6), "#2a2350") + F(E(-7, 12, 1, 1), W) + F(E(-1, 11.5, 0.8, 0.8), W)
                           + hs(R(8, -18, 3, 22), "#c98a52") + hs(R(5, -21, 9, 4), "#ff7a8a")
                           + hs("M3,3 L16,3 L16,10 Q16,17 9.5,18 Q3,17 3,10 Z", "#ff7a8a") + F(R(8, 5, 3, 7), "#ffb0b8"))
    for k, body in out.items():
        ms.add("ware_" + k, -16, -20, 32, 36, body, px=1.0, flat=True, outline=OUTLINE)


def fx(ms):
    """Piezas pequeñas del mundo que antes se dibujaban con rectángulos: el altavoz de Lil Key, la
    claqueta de los actores de D. Lynx, las teles del anuncio de Mr. Ad y los símbolos de los
    élites (modo daltónico). Van a la escala de los enemigos.
    Small world pieces that used to be drawn with rectangles: Lil Key's speaker, the clapperboard of
    D. Lynx's actors, the TVs of Mr. Ad's advert and the elite symbols (colourblind mode). They use
    the enemies' scale."""
    mix, dark, ellipse_d, star_d = ms.mix, ms.dark, ms.ellipse_d, ms.star_d

    def hs(d, base, sh=0.4, rim=0.5):
        i = ms.uid()
        return ("<defs><clipPath id='c%s'><path d='%s'/></clipPath></defs><path d='%s' fill='%s'/>"
                "<g clip-path='url(#c%s)'><path d='%s%s' transform='translate(-3,-3)' fill-rule='evenodd' fill='%s'/>"
                "<path d='%s%s' transform='translate(2,2)' fill-rule='evenodd' fill='%s'/></g>") % (
            i, d, d, base, i, ms.BIG, d, mix(base, dark(base, 0.6), sh), ms.BIG, d, mix(base, "#fbf8ff", rim * 0.6))

    def F(d, c):
        return "<path d='%s' fill='%s'/>" % (d, c)

    def R(x, y, w, h):
        return "M%g,%g H%g V%g H%g Z" % (x, y, x + w, y + h, x)

    E = ellipse_d
    # Altavoz (apoyo en el suelo en 0,0) / Speaker (resting on the ground at 0,0)
    b = hs(R(-14, -40, 28, 40), "#2a2b40")
    b += hs(E(0, -27, 10, 10), "#4a4f72") + F(E(0, -27, 6, 6), "#1a1b2a") + F(E(0, -27, 3, 3), "#ff6a8a")
    b += hs(E(0, -8, 5, 5), "#4a4f72") + F(E(0, -8, 2.5, 2.5), "#1a1b2a")
    b += F(R(-11, -37, 22, 2), "#ff6a8a")
    ms.add("fx_speaker", -16, -44, 32, 46, b, px=0.5, flat=True, outline="#140e26")
    # Claqueta (centro en 0,0) / Clapperboard (centre at 0,0)
    b = hs(R(-12, -4, 24, 16), "#2a2440")
    for k in range(4):
        b += F("M%g,-4 L%g,-4 L%g,0 L%g,0 Z" % (-12 + k * 6, -9 + k * 6, -12 + k * 6, -15 + k * 6), "#fbf8ff")
    b += hs("M-12,-5 L12,-11 L13,-7 L-11,-1 Z", "#2a2440")
    for k in range(4):
        b += F("M%g,%g L%g,%g L%g,%g L%g,%g Z" % (-9 + k * 6, -6 - k * 1.5, -6 + k * 6, -6.8 - k * 1.5, -8 + k * 6, -2.6 - k * 1.5, -11 + k * 6, -1.8 - k * 1.5), "#fbf8ff")
    b += F(R(-9, 3, 18, 1.5), "#8a86a8") + F(R(-9, 7, 12, 1.5), "#8a86a8")
    ms.add("fx_clapper", -14, -14, 28, 28, b, px=0.5, flat=True, outline="#140e26")
    # Tele pequeña de los que miran el anuncio / Small TV of those watching the advert
    b = hs(R(-11, -8, 22, 16), "#6a4a34") + F(R(-8, -5, 16, 10), "#ffc070") + F(R(-8, -5, 16, 2), "#fff0c0")
    b += "<path d='M-4,-8 L-8,-14 M4,-8 L8,-14' stroke='#2a2440' stroke-width='1.6'/>"
    ms.add("fx_tv_small", -13, -16, 26, 28, b, px=0.5, flat=True, outline="#140e26")
    # Tele grande del anuncio (base en 0,0; la pantalla queda en -120..120, -250..-80)
    # Big advert TV (base at 0,0; the screen sits in -120..120, -250..-80)
    b = hs(R(-132, -262, 264, 204), "#6a4a34")
    b += F(R(-122, -252, 244, 174), "#101828")
    b += hs(R(-60, -58, 120, 10), "#4a3424")
    b += "<path d='M-50,-58 L-74,0 M50,-58 L74,0' stroke='#4a3424' stroke-width='8'/>"
    b += "<path d='M-30,-262 L-70,-320 M30,-262 L70,-320' stroke='#2a2440' stroke-width='4'/>"
    b += hs(E(-70, -320, 6, 6), "#e85d75") + hs(E(70, -320, 6, 6), "#e85d75")
    for k in range(3):
        b += hs(E(108 - k * 18, -67, 4, 4), "#ffd27a")
    ms.add("fx_tv_big", -140, -330, 280, 334, b, px=0.5, flat=True, outline="#140e26")
    # Símbolos de los élites (centro en 0,0) / Elite symbols (centre at 0,0)
    ring = hs(E(0, 0, 13, 13), "#fbf8ff") + F(E(0, 0, 10, 10), "#2a2440")
    sym = {
        "split": "<path d='M-7,0 L7,0 M-3,-4 L-7,0 L-3,4 M3,-4 L7,0 L3,4' fill='none' stroke='#ff8a1f' stroke-width='2.6'/>",
        "puddle": F("M0,-8 Q6,0 5,3 Q4,7 0,7 Q-4,7 -5,3 Q-6,0 0,-8 Z", "#2fa8ff"),
        "haste": F("M4,-10 L-6,1 L-1,1 L-4,10 L7,-2 L2,-2 Z", "#c44dff"),
    }
    for k, s in sym.items():
        ms.add("elite_sym_" + k, -15, -15, 30, 30, ring + s, px=0.5, flat=True, outline="#140e26")


def weapon_icons(ms):
    """Las armas en grande para la pantalla de la segunda arma: el mismo dibujo que en la mano de
    Kroker, pero con más resolución (así no salen pixeladas a lo bestia al ampliarlas).
    The weapons drawn large for the second-weapon screen: the same drawing as in Kroker's hand,
    but at a higher resolution (so they don't come out crudely blocky when enlarged)."""
    scales = {"weapon_bat": 0.48, "weapon_pillow": 0.6, "weapon_book": 0.6, "weapon_tank": 0.6, "weapon_nozzle": 0.6,
              "weapon_teddy": 0.84, "weapon_ball": 0.81, "weapon_laptop": 0.8, "weapon_boot_r": 0.96, "weapon_boot_l": 0.96}
    for name, px in scales.items():
        sp = dict(ms.SPRITES[name])
        ms.add("wicon_" + name[len("weapon_"):], sp["x"], sp["y"], sp["w"], sp["h"], sp["body"], xf=sp["xf"], px=px,
               colors=sp["colors"], ghost=sp["ghost"], post=None, flat=sp["flat"], outline=sp["outline"])


def kroker_hires(ms):
    """Kroker y sus armas con el doble de resolución ("hk_"), para el plano astral, donde sale al
    lado de los personajes (que tienen más detalle) / Kroker and his weapons at twice the resolution
    ("hk_"), for the astral plane, where he stands next to the characters (who have more detail)"""
    for name in list(ms.SPRITES):
        if name.startswith("kroker_") or name.startswith("weapon_"):
            sp = ms.SPRITES[name]
            # La cara va pintada a mano: al doble, con píxeles de 2 / The face is hand-painted: at double size, with 2-pixel dots
            post = ms.face_painter(*sp["face"], k=2) if "face" in sp else sp["post"]
            ms.add("hk_" + name, sp["x"], sp["y"], sp["w"], sp["h"], sp["body"], xf=sp["xf"], px=sp["px"] * 2.0,
                   colors=sp["colors"], ghost=sp["ghost"], post=post, flat=sp["flat"], outline=sp["outline"])
