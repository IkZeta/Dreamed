"""Temas propios de cada personaje del plano astral y los instrumentos nuevos que usan.
Cada tema intenta sonar a quien es: Svinho a bossa y a estadio, Stolk a gimnasio y a chulería,
Silly a chiptune y teclado, Doc a consulta tranquila con su pitido de monitor, Mr. Ad a anuncio
de juguetes medio roto, el Pinche a cocina con prisa (tarantela), Charo a vals de abuela que teje,
Magnus a jazz de despacho con caja registradora, SuperK a fanfarria de héroe y Lil Key a dembow.
Además, los "giver_*" (lo que suena al hablar con ellos) son el arranque de su tema: un leitmotiv.

Each astral-plane character's own theme and the new instruments they use. Each theme tries to
sound like who they are: Svinho bossa and stadium, Stolk gym and swagger, Silly chiptune and
keyboard, Doc a calm clinic with its monitor beep, Mr. Ad a half-broken toy advert, the Kitchen Boy
a kitchen in a hurry (tarantella), Charo a knitting grandma's waltz, Magnus office jazz with a cash
register, SuperK a hero's fanfare and Lil Key dembow. The "giver_*" sounds (heard when talking to
them) are the opening of their theme: a leitmotif.

Lo usa tools/make_audio.py / Used by tools/make_audio.py
"""
import numpy as np

import make_audio as A
from make_audio import SR, midi, t_axis, noise, lp, hp, bp, env_ar, pluck, bar, saw_pad, breath, thump, place, mix, loop_render, vowel

RNG = np.random.default_rng(77)


# --- Instrumentos nuevos / New instruments -------------------------------------------

def fm_ep(freq: float, dur: float = 2.0, amp: float = 0.3, bright: float = 0.5) -> np.ndarray:
    """Piano eléctrico de FM (tipo Rhodes) / FM electric piano (Rhodes-like)."""
    t = t_axis(dur)
    idx = (1.2 + 2.2 * bright) * np.exp(-t * 3.0) + 0.25
    car = np.sin(2 * np.pi * freq * t + np.sin(2 * np.pi * freq * t) * idx)
    tine = np.sin(2 * np.pi * freq * 13.9 * t) * np.exp(-t * 45) * 0.12 * bright
    e = np.exp(-t * (1.0 + freq / 1100))
    return (car * e + tine) * env_ar(len(t), 0.002, 0.08) * amp


def pulse(freq: float, dur: float, amp: float = 0.2, duty: float = 0.5, decay: float = 5.0, cutoff: float = 4500) -> np.ndarray:
    """Onda cuadrada de consola antigua / Old console square wave."""
    t = t_axis(dur)
    w = np.where((freq * t) % 1.0 < duty, 1.0, -1.0)
    return lp(w, cutoff) * np.exp(-t * decay) * env_ar(len(t), 0.002, 0.02) * amp


def reed(freqs: list, dur: float, amp: float = 0.1, attack: float = 0.04, release: float = 0.15, trem: float = 5.5,
         cutoff: float = 2600) -> np.ndarray:
    """Acordeón: lengüetas desafinadas un pelín, con trémolo / Accordion: slightly detuned reeds, with tremolo."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    for f in freqs:
        for det in (-0.003, 0.0035):
            ph = (f * (1 + det) * t) % 1.0
            out += np.where(ph < 0.42, 1.0, -1.0) * 0.6 + (2 * ph - 1) * 0.4
    out = lp(out, cutoff, 3) * (1 + 0.15 * np.sin(2 * np.pi * trem * t))
    return out / max(1, len(freqs) * 2) * env_ar(len(t), attack, release) * amp


def brass(freqs: list, dur: float, amp: float = 0.15, attack: float = 0.06, release: float = 0.2, peak: float = 3200,
          mute: bool = False) -> np.ndarray:
    """Metal: sierra con un filtro que se abre al soplar / Brass: a saw with a filter that opens as it's blown."""
    t = t_axis(dur)
    x = np.zeros(len(t))
    for f in freqs:
        vib = 1 + 0.003 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
        ph = np.cumsum(f * vib) / SR % 1.0
        x += 2 * ph - 1
    x /= max(1, len(freqs))
    fe = np.clip(t / attack, 0, 1) * (0.55 + 0.45 * np.exp(-t * 4))
    y = lp(x, 500) * (1 - fe) + lp(x, peak) * fe
    if mute:
        y = bp(y, 600, 2600) * 1.6
    return y * env_ar(len(t), attack * 0.6, release) * amp


def whistle(freq: float, dur: float, amp: float = 0.2, vib: float = 5.5) -> np.ndarray:
    """Silbido o flauta: seno con vibrato que entra tarde y un poco de aire / Whistle or flute: a sine with late vibrato and some air."""
    t = t_axis(dur)
    v = 1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    tone = np.sin(2 * np.pi * np.cumsum(freq * v) / SR)
    air = bp(noise(dur), freq * 0.8, freq * 1.3) * 0.15
    return (tone + air) * env_ar(len(t), 0.03, 0.12) * amp


def kick(amp: float = 0.5, f: float = 55.0, drop: float = 8.0) -> np.ndarray:
    return thump(f, 0.45, amp, drop)


def snare(amp: float = 0.25, dur: float = 0.22, tone: float = 190.0) -> np.ndarray:
    t = t_axis(dur)
    return (bp(noise(dur), 1500, 7500) * np.exp(-t * 18) + np.sin(2 * np.pi * tone * t) * np.exp(-t * 30) * 0.6) * amp


def hat(amp: float = 0.08, open_: bool = False) -> np.ndarray:
    dur = 0.35 if open_ else 0.07
    t = t_axis(dur)
    return hp(noise(dur), 7000) * np.exp(-t * (12 if open_ else 65)) * amp


def clap(amp: float = 0.22) -> np.ndarray:
    dur = 0.25
    t = t_axis(dur)
    x = bp(noise(dur), 900, 3200)
    e = np.zeros(len(t))
    for d in (0.0, 0.011, 0.022):
        e += np.exp(-np.clip(t - d, 0, None) * 90) * (t >= d)
    e += np.exp(-t * 14) * 0.4
    return x * e * amp


def shaker(amp: float = 0.05) -> np.ndarray:
    dur = 0.08
    return bp(noise(dur), 4000, 10000) * np.hanning(int(dur * SR)) * amp


def rim(amp: float = 0.15) -> np.ndarray:
    return bar(1750, 0.06, amp, "wood", 1.0)


def timpani(freq: float, amp: float = 0.4) -> np.ndarray:
    t = t_axis(1.4)
    return thump(freq, 1.4, amp, 2.0) + lp(noise(1.4), 400) * np.exp(-t * 9) * amp * 0.25


def sub808(freq: float, dur: float, amp: float = 0.4, glide: float = 0.0) -> np.ndarray:
    """Bajo 808: seno grave que se apaga despacio, con un deslizamiento opcional / 808 bass: a low sine fading slowly, with an optional glide."""
    t = t_axis(dur)
    f = freq * (2 ** (glide / 12 * np.exp(-t * 18)))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR)
    y = np.tanh(y * 1.6) / np.tanh(1.6)
    return y * np.exp(-t * 1.6) * env_ar(len(t), 0.004, 0.06) * amp


def metal(freq: float, dur: float = 0.8, amp: float = 0.2) -> np.ndarray:
    """Golpe metálico: cazo, pesa del gimnasio / A metallic hit: a pan, a gym weight."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    for r, g, d in ((1.0, 1.0, 5), (2.31, 0.6, 7), (3.67, 0.4, 9), (5.13, 0.25, 12), (7.2, 0.15, 16)):
        out += np.sin(2 * np.pi * freq * r * t) * g * np.exp(-t * d)
    return out * env_ar(len(t), 0.001, 0.05) * amp / 2.4


def glock(freq: float, dur: float = 1.4, amp: float = 0.2) -> np.ndarray:
    """Glockenspiel / caja de música / Glockenspiel / music box."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    for r, g, d in ((1.0, 1.0, 2.2), (2.76, 0.35, 5.0), (5.4, 0.15, 9.0), (8.93, 0.06, 14.0)):
        if freq * r < SR * 0.45:
            out += np.sin(2 * np.pi * freq * r * t) * g * np.exp(-t * d)
    return out * env_ar(len(t), 0.001, 0.05) * amp


def bitcrush(x: np.ndarray, bits: int = 5, down: int = 3) -> np.ndarray:
    y = np.repeat(x[::down], down, axis=0)[: len(x)]
    q = 2 ** bits
    return np.round(y * q) / q


def crowd(dur: float, amp: float = 0.08) -> np.ndarray:
    """Murmullo de estadio que crece y baja / A stadium murmur that swells and falls."""
    t = t_axis(dur)
    x = bp(noise(dur), 300, 1800) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t + RNG.uniform(0, 6)))
    return x * np.sin(np.pi * t / dur) ** 1.5 * amp


def _strum(buf, notes, at, amp, pan=0.0, spread=0.012, bright=0.45, dur=1.4, up=False):
    order = notes[::-1] if up else notes
    for k, n in enumerate(order):
        place(buf, pluck(midi(n), dur, amp, bright), at + k * spread, pan - 0.15 + 0.1 * k)


# --- Temas / Themes ---------------------------------------------------------------

def svinho_theme() -> np.ndarray:
    """Svinho: bossa nova en Fa con guitarra de nailon, surdo, shaker y clave, una melodía silbada
    y, en la segunda vuelta, un murmullo de estadio y el silbato del árbitro.
    Svinho: F-major bossa nova with nylon guitar, surdo, shaker and clave, a whistled tune and, on
    the second pass, a stadium murmur and the referee's whistle."""
    beat = 60.0 / 120
    bar_len = beat * 4
    chords = [[41, 57, 60, 64], [43, 58, 62, 65], [36, 58, 62, 64], [41, 57, 60, 64],
              [46, 57, 62, 65], [45, 55, 60, 64], [38, 57, 60, 65], [36, 58, 62, 64]]
    mel_a = [(0, 0.5, 72), (0, 1.5, 74), (0, 2, 76), (0, 3.5, 77), (1, 0, 76), (1, 1, 74), (1, 2.5, 70), (2, 0, 72),
             (2, 1.5, 70), (2, 2, 69), (3, 0, 72), (4, 0.5, 74), (4, 1.5, 77), (4, 2, 81), (5, 0, 79), (5, 1.5, 76),
             (5, 2, 72), (6, 0, 74), (6, 1.5, 72), (6, 2, 69), (7, 0, 70), (7, 2, 67)]
    clave = [0, 3, 6, 10, 12]   # en semicorcheas sobre dos compases / in sixteenths over two bars
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            # Bajo: raíz y quinta, con anticipación / Bass: root and fifth, with an anticipation
            place(buf, pluck(midi(ch[0] - 12), 1.2, 0.28, 0.2, 0.995), s, -0.05)
            place(buf, pluck(midi(ch[0] - 5), 1.0, 0.22, 0.2, 0.995), s + 2 * beat, -0.05)
            place(buf, pluck(midi(ch[0] - 12), 0.6, 0.16, 0.2, 0.99), s + 3.5 * beat, -0.05)
            # Guitarra de bossa / Bossa guitar
            pat = [0.0, 1.5, 2.5] if i % 2 == 0 else [0.5, 1.5, 3.0]
            for b in pat:
                _strum(buf, ch[1:], s + b * beat, 0.07, -0.25, 0.01, 0.35, 1.0)
            # Percusión / Percussion
            place(buf, thump(58, 0.5, 0.22, 4.0), s + beat, 0.0)
            place(buf, thump(52, 0.6, 0.3, 3.5), s + 3 * beat, 0.0)
            for k in range(16):
                place(buf, shaker(0.035 if k % 4 else 0.055), s + k * beat / 4, 0.45)
            for c in clave:
                bi, k = divmod(c, 16)
                if bi == i % 2:
                    place(buf, rim(0.09), s + k * beat / 4, -0.4)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in mel_a:
                place(buf, whistle(midi(n + (12 if second and bi >= 4 else 0)), beat * 1.1, 0.16), base + bi * bar_len + b * beat, 0.1)
        # Estadio y silbato en la segunda vuelta / Stadium and whistle on the second pass
        place(buf, crowd(8 * bar_len, 0.05), off + 8 * bar_len, 0.0, human=False)
        for k in range(3):
            place(buf, whistle(2900, 0.12 if k < 2 else 0.45, 0.07, 14.0), off + 15 * bar_len + 2 * beat + k * 0.2, 0.3, human=False)

    return loop_render(build, bar_len * bars, 0.25)


def stolk_theme() -> np.ndarray:
    """Stolk: chulería de patio. Medio tiempo pesado en Mi menor: bombo y caja gordos, un bajo
    saturado que hace el riff, acordes de metal a golpes y el clonc de una pesa en cada compás.
    Stolk: schoolyard swagger. A heavy half-time groove in E minor: fat kick and snare, a gritty
    bass doing the riff, punchy brass chords and the clank of a weight every bar."""
    beat = 60.0 / 86
    bar_len = beat * 4
    riff = [(0, 40), (0.75, 40), (1.5, 43), (2.0, 45), (2.75, 46), (3.0, 45), (3.5, 43)]
    riff_b = [(0, 36), (0.75, 36), (1.5, 40), (2.0, 43), (2.75, 42), (3.0, 40), (3.5, 38)]
    bars = 16

    def bass_note(n, dur):
        t = t_axis(dur)
        ph = (midi(n) * t) % 1.0
        x = np.tanh((2 * ph - 1) * 3.0)
        return lp(x, 520) * np.exp(-t * 2.5) * env_ar(len(t), 0.004, 0.05) * 0.32

    def build(buf, off):
        for i in range(bars):
            s = off + i * bar_len
            rf = riff if (i // 4) % 2 == 0 else riff_b
            for b, n in rf:
                place(buf, bass_note(n, beat * 0.7), s + b * beat, -0.05)
            place(buf, kick(0.5, 52), s, 0.0)
            place(buf, kick(0.4, 52), s + 1.75 * beat, 0.0)
            place(buf, kick(0.35, 52), s + 2.5 * beat, 0.0)
            for b in (1, 3):
                place(buf, snare(0.28), s + b * beat, 0.05)
                place(buf, clap(0.12), s + b * beat + 0.005, -0.1)
            for k in range(8):
                place(buf, hat(0.05 if k % 2 else 0.07), s + k * beat / 2, 0.4)
            # Acordes de metal a golpes (quinta y octava) / Punchy brass power chords
            root = rf[0][1] + 12
            if i % 2 == 0:
                place(buf, brass([midi(root), midi(root + 7), midi(root + 12)], beat * 0.6, 0.12, 0.02, 0.1), s, -0.3)
                place(buf, brass([midi(root + 3), midi(root + 10)], beat * 0.4, 0.09, 0.02, 0.1), s + 2.75 * beat, 0.3)
            # La pesa del gimnasio / The gym weight
            place(buf, metal(180, 0.9, 0.12), s + 3.5 * beat, 0.5)
        # Melodía chulesca de metal en la segunda mitad / A cocky brass line in the second half
        for bi, b, n in [(8, 0, 64), (8, 1.5, 67), (8, 2, 69), (9, 0, 70), (9, 1, 69), (9, 2, 67), (10, 0, 64),
                         (12, 0, 67), (12, 1.5, 69), (12, 2, 71), (13, 0, 74), (13, 1, 71), (13, 2, 69), (14, 0, 67), (14, 2, 64)]:
            place(buf, brass([midi(n)], beat * 0.9, 0.11, 0.03, 0.15, 2400), off + bi * bar_len + b * beat, 0.15)

    return loop_render(build, bar_len * bars, 0.18)


def silly_theme() -> np.ndarray:
    """Silly: chiptune de hacker en La menor. Arpegios de onda cuadrada en semicorcheas, bajo y
    batería de 8 bits, un teclado que no para y tartamudeos de glitch al final de cada frase.
    Silly: hacker chiptune in A minor. Sixteenth-note square-wave arpeggios, 8-bit bass and drums,
    a keyboard that never stops and glitch stutters at the end of each phrase."""
    beat = 60.0 / 140
    bar_len = beat * 4
    chords = [[45, 57, 60, 64], [41, 57, 60, 65], [36, 55, 60, 64], [43, 55, 59, 62]]
    lead = [(0, 0, 76), (0, 1, 79), (0, 1.5, 81), (0, 3, 79), (1, 0, 77), (1, 1, 76), (1, 2, 72), (2, 0, 76),
            (2, 1.5, 74), (2, 2, 72), (3, 0, 71), (3, 2, 74), (4, 0, 76), (4, 1, 79), (4, 1.5, 84), (4, 3, 83),
            (5, 0, 81), (5, 1, 77), (5, 2, 81), (6, 0, 79), (6, 1, 76), (6, 2, 72), (7, 0, 74), (7, 2, 71)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            for k in range(16):
                n = ch[1 + k % 3] + (12 if k % 6 >= 3 else 0)
                place(buf, bitcrush(pulse(midi(n), beat / 4, 0.05, 0.25, 14)), s + k * beat / 4, -0.35 + 0.05 * (k % 8), human=False)
            for k in range(8):
                place(buf, bitcrush(pulse(midi(ch[0] - 12 + (12 if k % 2 else 0)), beat / 2, 0.13, 0.5, 6, 1800)), s + k * beat / 2, 0.0, human=False)
            for b in (0, 2):
                place(buf, bitcrush(kick(0.4, 60, 11)), s + b * beat, 0.0, human=False)
            for b in (1, 3):
                place(buf, bitcrush(snare(0.2, 0.15)), s + b * beat, 0.05, human=False)
            # El teclado de Silly hace de charles / Silly's keyboard plays the hi-hats
            for k in range(8):
                place(buf, bar(RNG.uniform(2400, 3200), 0.04, 0.03, "wood", 1.0), s + k * beat / 2 + beat / 4, 0.5)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in lead:
                place(buf, pulse(midi(n + (12 if second else 0)), beat * 0.9, 0.07 if second else 0.09, 0.125 if second else 0.25, 3.0, 5000),
                      base + bi * bar_len + b * beat, 0.15, human=False)
        # Glitch: el último pulso de cada frase se repite / Glitch: the last beat of each phrase repeats
        n = int(beat * SR / 4)
        for p in (7, 15):
            at = int((off + (p + 1) * bar_len - beat) * SR)
            if at + n * 4 < len(buf):
                seg = buf[at: at + n].copy()
                for r in range(1, 4):
                    buf[at + r * n: at + (r + 1) * n] = seg * (0.9 - r * 0.15)

    return loop_render(build, bar_len * bars, 0.15)


def doc_theme() -> np.ndarray:
    """Doc: una consulta tranquila en La mayor. Piano eléctrico suave, un latido que hace de
    bombo, el pitido del monitor (afinado) y una melodía de caja de música que tranquiliza.
    Doc: a calm clinic in A major. A soft electric piano, a heartbeat as the kick, the (in-tune)
    monitor beep and a reassuring music-box melody."""
    beat = 60.0 / 76
    bar_len = beat * 4
    chords = [[45, 61, 64, 68], [42, 57, 61, 64], [38, 57, 61, 66], [40, 56, 59, 64],
              [45, 61, 64, 68], [49, 56, 61, 64], [38, 57, 62, 66], [40, 56, 59, 62]]
    melody = [(0, 0, 76), (0, 1, 80), (0, 2, 81), (1, 0, 80), (1, 2, 76), (2, 0, 78), (2, 2, 74), (3, 0, 76),
              (4, 0, 81), (4, 1, 80), (4, 2, 78), (5, 0, 76), (5, 2, 73), (6, 0, 74), (6, 1, 76), (6, 2, 78), (7, 0, 76)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            for b in (0.0, 2.0):
                for k, n in enumerate(ch[1:]):
                    place(buf, fm_ep(midi(n), 2.4, 0.07, 0.35), s + b * beat + k * 0.01, -0.3 + k * 0.25)
            place(buf, pluck(midi(ch[0] - 12), 3.0, 0.2, 0.15, 0.998), s, 0.0)
            # Latido: lub-dub / Heartbeat: lub-dub
            place(buf, thump(48, 0.35, 0.3, 7.0), s, 0.0)
            place(buf, thump(44, 0.3, 0.2, 8.0), s + 0.28, 0.0)
            # Pitido del monitor (La, en la nota) / Monitor beep (an A, in tune)
            place(buf, np.sin(2 * np.pi * 1760 * t_axis(0.09)) * env_ar(int(0.09 * SR), 0.004, 0.03) * 0.04, s + 2 * beat, 0.5, human=False)
            for k in range(8):
                place(buf, shaker(0.02), s + k * beat / 2 + beat / 4, -0.4)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in melody:
                place(buf, glock(midi(n + (0 if not second else -12)), 2.0, 0.12 if not second else 0.09), base + bi * bar_len + b * beat, 0.1)
                if second:
                    place(buf, fm_ep(midi(n), 1.6, 0.06, 0.6), base + bi * bar_len + b * beat, -0.1)

    return loop_render(build, bar_len * bars, 0.4, 1.6)


def ad_theme() -> np.ndarray:
    """Mr. Ad: jingle de anuncio de juguetes en Do mayor, con ukelele, palmas, glockenspiel y un
    "din-don"... pero el robot está medio roto: alguna nota se desafina y la tele chisporrotea.
    Mr. Ad: a toy-advert jingle in C major, with ukulele, claps, glockenspiel and a "ding-dong"...
    but the robot is half broken: a note goes out of tune here and there and the TV crackles."""
    beat = 60.0 / 124
    bar_len = beat * 4
    chords = [[36, 64, 67, 72], [41, 65, 69, 72], [43, 62, 67, 71], [36, 64, 67, 72],
              [45, 64, 69, 72], [41, 65, 69, 72], [38, 62, 65, 69], [43, 62, 65, 71]]
    melody = [(0, 0, 79), (0, 0.5, 76), (0, 1, 79), (0, 2, 84), (1, 0, 81), (1, 1, 77), (1, 2, 81), (2, 0, 79),
              (2, 0.5, 77), (2, 1, 74), (2, 2, 71), (3, 0, 72), (4, 0, 76), (4, 0.5, 79), (4, 1, 84), (4, 2, 88),
              (5, 0, 86), (5, 1, 84), (5, 2, 81), (6, 0, 77), (6, 1, 81), (6, 2, 79), (7, 0, 74), (7, 2, 79)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            for b in range(4):
                place(buf, pluck(midi(ch[0] - 12 + (7 if b % 2 else 0)), beat * 0.8, 0.22, 0.4, 0.99), s + b * beat, 0.0)
                place(buf, kick(0.22, 62, 10), s + b * beat, 0.0)
            # Ukelele a contratiempo / Offbeat ukulele
            for b in (0.5, 1.5, 2.5, 3.5):
                _strum(buf, ch[1:], s + b * beat, 0.06, 0.25, 0.008, 0.75, 0.6)
            for b in (1, 3):
                place(buf, clap(0.14), s + b * beat, -0.15)
            for k in range(8):
                place(buf, hat(0.035), s + k * beat / 2, 0.45)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for idx, (bi, b, n) in enumerate(melody):
                f = midi(n)
                # Robot medio roto: de vez en cuando una nota sale desafinada / Half-broken robot: now and then a note comes out of tune
                if second and idx % 7 == 3:
                    f *= 2 ** (-0.6 / 12)
                place(buf, glock(f, 1.0, 0.13), base + bi * bar_len + b * beat, 0.15)
        # "Din-don" al final de cada frase y un chisporroteo de tele / "Ding-dong" at each phrase end and a TV crackle
        for p in (3, 7, 11, 15):
            place(buf, glock(midi(88), 1.2, 0.08), off + p * bar_len + 2 * beat, -0.3, human=False)
            place(buf, glock(midi(84), 1.6, 0.08), off + p * bar_len + 2.5 * beat, -0.3, human=False)
        place(buf, hp(noise(0.25), 3000) * 0.025, off + 7 * bar_len + 3.5 * beat, 0.4, human=False)

    return loop_render(build, bar_len * bars, 0.2)


def pinche_theme() -> np.ndarray:
    """El Pinche: tarantela de cocina con prisa, en Re menor y 6/8. Acordeón que hace "um-pa-pa",
    pandereta, cazos que suenan, el cuchillo picando y, debajo, el chisporroteo de la sartén.
    The Kitchen Boy: a hurried kitchen tarantella in D minor, 6/8. An "oom-pa-pa" accordion,
    tambourine, clanking pans, the knife chopping and, underneath, the frying pan sizzling."""
    e = 60.0 / 400           # una corchea / one eighth note
    bar_len = e * 6
    chords = [[38, 62, 65, 69], [45, 61, 64, 67], [38, 62, 65, 69], [43, 62, 67, 70],
              [38, 62, 65, 69], [43, 62, 67, 70], [45, 61, 64, 67], [38, 62, 65, 69]]
    melody = [69, 70, 69, 67, 65, 64, 65, 69, 74, 72, 70, 69, 67, 69, 70, 67, 64, 61, 62, 65, 69, 70, 69, 67,
              69, 74, 77, 76, 74, 72, 70, 74, 79, 77, 76, 74, 73, 76, 79, 76, 73, 69, 74, 69, 65, 62, 62, 62]
    bars = 32

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            for k in range(6):
                at = s + k * e
                if k in (0, 3):
                    place(buf, reed([midi(ch[0] - (0 if k == 0 else -7))], e * 1.4, 0.16, 0.01, 0.06, 6.0, 1600), at, -0.1)
                else:
                    place(buf, reed([midi(n) for n in ch[1:]], e * 0.8, 0.09, 0.01, 0.05), at, 0.2)
                place(buf, shaker(0.04 if k % 3 else 0.06), at, 0.45)
            if i % 2 == 0:
                place(buf, metal(RNG.choice([420, 520, 610]), 0.6, 0.06), s, -0.5)
            # Cuchillo picando / Knife chopping
            for k in (1, 2, 4, 5):
                place(buf, bar(2000, 0.04, 0.025, "wood", 1.0), s + k * e + e * 0.5, 0.55)
        # Melodía de acordeón: normal, una octava arriba, con mandolina y otra vez arriba con la segunda voz
        # Accordion tune: as is, an octave up, with mandolin, and up again with a second voice
        for rep in range(4):
            base = off + rep * 8 * bar_len
            for k, n in enumerate(melody):
                up = 12 if rep in (1, 3) else 0
                place(buf, reed([midi(n + up)], e * 1.1, 0.11, 0.005, 0.04, 6.5, 3200), base + k * e, 0.05)
                if rep == 2:
                    place(buf, pluck(midi(n + 12), 0.25, 0.06, 0.8, 0.99), base + k * e, -0.3)
                    place(buf, pluck(midi(n + 12), 0.25, 0.04, 0.8, 0.99), base + k * e + e / 2, -0.3)
                if rep == 3:
                    place(buf, reed([midi(n + 8)], e * 1.1, 0.06, 0.005, 0.04, 6.5, 2600), base + k * e, -0.2)
        # Sartén / Frying pan
        sizzle = hp(noise(bars * bar_len), 3500) * 0.008
        sizzle *= (0.7 + 0.3 * np.abs(np.sin(np.arange(len(sizzle)) / SR * 9)))
        place(buf, sizzle, off, 0.6, human=False)

    return loop_render(build, bar_len * bars, 0.22)


def charo_theme() -> np.ndarray:
    """Charo: vals de abuela en Fa mayor. Acordeón suave de fondo, guitarra que hace el vals, una
    caja de música y el clic-clic de las agujas de punto.
    Charo: a grandma's waltz in F major. A soft accordion behind, a guitar playing the waltz, a
    music box and the click-click of knitting needles."""
    beat = 60.0 / 100
    bar_len = beat * 3
    chords = [[41, 60, 65, 69], [36, 58, 64, 67], [36, 58, 64, 67], [41, 60, 65, 69],
              [46, 62, 65, 70], [41, 60, 65, 69], [36, 58, 64, 67], [41, 60, 65, 69]]
    melody = [(0, 0, 77), (0, 2, 76), (1, 0, 74), (1, 2, 72), (2, 0, 70), (3, 0, 72), (3, 2, 77), (4, 0, 74),
              (4, 1, 77), (4, 2, 82), (5, 0, 81), (6, 0, 79), (6, 1, 76), (6, 2, 72), (7, 0, 77)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            place(buf, reed([midi(n) for n in ch[1:]], bar_len + 0.2, 0.05, 0.25, 0.4, 4.5, 1700), s, -0.2, human=False)
            place(buf, pluck(midi(ch[0] - 12), 2.0, 0.26, 0.2, 0.997), s, 0.0)
            for b in (1, 2):
                _strum(buf, ch[1:], s + b * beat, 0.045, 0.2, 0.01, 0.3, 1.0)
            # Agujas de punto / Knitting needles
            for b in (0.5, 1.5, 2.5):
                place(buf, bar(RNG.uniform(3000, 3400), 0.03, 0.02, "wood", 1.0), s + b * beat, 0.5)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in melody:
                place(buf, glock(midi(n + (12 if not second else 0)), 1.6, 0.09), base + bi * bar_len + b * beat, 0.1)
                if second:
                    place(buf, reed([midi(n)], beat * 1.5, 0.07, 0.05, 0.2, 5.0, 2400), base + bi * bar_len + b * beat, -0.05)

    return loop_render(build, bar_len * bars, 0.38, 1.5)


def magnus_theme() -> np.ndarray:
    """Magnus: jazz de despacho en Si bemol, con swing. Contrabajo que camina, platillo y
    escobillas, piano eléctrico al estilo Charleston, una trompeta con sordina y, al final de la
    vuelta, la caja registradora.
    Magnus: office jazz in B flat, swung. A walking double bass, ride and brushes, Charleston
    electric-piano comping, a muted trumpet and, at the end of the loop, the cash register."""
    beat = 60.0 / 132
    bar_len = beat * 4
    sw = beat * 2 / 3        # corchea con swing / swung eighth
    chords = [[46, 62, 65, 69], [43, 58, 62, 65], [36, 58, 63, 67], [41, 57, 63, 67],
              [46, 62, 65, 69], [39, 58, 62, 67], [36, 58, 63, 67], [41, 57, 63, 67]]
    walks = [[46, 50, 53, 55], [43, 46, 50, 48], [48, 51, 55, 53], [41, 45, 48, 44],
             [46, 50, 53, 51], [39, 43, 46, 44], [48, 46, 45, 43], [41, 43, 45, 47]]
    melody = [(0, 0, 74), (0, 1 + 2 / 3, 72), (0, 2, 70), (1, 0, 74), (1, 1, 77), (1, 2, 75), (2, 0, 72),
              (2, 2 + 2 / 3, 70), (3, 0, 67), (3, 2, 69), (4, 0, 70), (4, 1, 74), (4, 2, 77), (5, 0, 79), (5, 1 + 2 / 3, 77),
              (5, 2, 75), (6, 0, 72), (6, 1, 75), (6, 2, 74), (7, 0, 70)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            for b in range(4):
                place(buf, pluck(midi(walks[i % 8][b] - 12), beat * 1.2, 0.28, 0.2, 0.994), s + b * beat, -0.1)
                place(buf, hat(0.05, True), s + b * beat, 0.4)
            for b in (1, 3):
                place(buf, hat(0.035, True), s + b * beat + sw, 0.4)
                place(buf, lp(breath(beat * 0.6, 1800, 6500, 0.05), 6000) * env_ar(int(beat * 0.6 * SR), 0.03, 0.3), s + b * beat, 0.2)
            for b in (0.0, 1.0 + 2 / 3):
                for k, n in enumerate(ch[1:]):
                    place(buf, fm_ep(midi(n), beat * 1.4, 0.06, 0.4), s + b * beat + k * 0.008, -0.35 + k * 0.2)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in melody:
                place(buf, brass([midi(n + (12 if second and bi >= 4 else 0))], beat * 0.9, 0.12, 0.04, 0.12, 2600, True),
                      base + bi * bar_len + b * beat, 0.15)
        # Caja registradora: "ka-ching" / Cash register: "ka-ching"
        at = off + 15 * bar_len + 3 * beat
        place(buf, bar(1200, 0.1, 0.05, "wood", 0.9), at, 0.4, human=False)
        place(buf, glock(midi(96), 1.5, 0.07), at + 0.08, 0.4, human=False)
        place(buf, glock(midi(91), 1.5, 0.05), at + 0.1, 0.4, human=False)

    return loop_render(build, bar_len * bars, 0.3)


def superk_theme() -> np.ndarray:
    """SuperK: fanfarria de héroe en Si bemol mayor. Cuerdas en corcheas que empujan, timbales,
    redobles de caja al final de las frases, acordes de metal que se abren y una melodía que sube.
    SuperK: a hero's fanfare in B-flat major. Driving eighth-note strings, timpani, snare rolls at
    phrase ends, swelling brass chords and a rising melody."""
    beat = 60.0 / 108
    bar_len = beat * 4
    chords = [[46, 58, 62, 65], [42, 57, 61, 66], [39, 55, 58, 63], [41, 57, 60, 65],
              [46, 58, 62, 65], [43, 58, 62, 67], [39, 58, 63, 67], [41, 57, 60, 65]]
    melody = [(0, 0, 65, 1), (0, 1, 70, 1), (0, 2, 72, 1), (0, 3, 74, 1), (1, 0, 77, 3), (1, 3, 74, 1), (2, 0, 75, 1.5),
              (2, 1.5, 74, 0.5), (2, 2, 72, 2), (3, 0, 77, 4), (4, 0, 74, 1), (4, 1, 77, 1), (4, 2, 82, 2), (5, 0, 81, 1.5),
              (5, 1.5, 79, 0.5), (5, 2, 77, 2), (6, 0, 79, 1), (6, 1, 75, 1), (6, 2, 72, 2), (7, 0, 70, 4)]
    bars = 16

    def strings_note(n, dur, amp):
        return saw_pad([midi(n)], dur, amp, 0.01, 0.06, 2600)

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            for k in range(8):
                place(buf, strings_note(ch[0] + (12 if k % 2 else 0), beat * 0.45, 0.35), s + k * beat / 2, -0.2, human=False)
            place(buf, brass([midi(n) for n in ch[1:]], bar_len * 0.95, 0.07, 0.35, 0.4, 2200), s, 0.25, human=False)
            place(buf, timpani(midi(ch[0]), 0.3), s, 0.0)
            place(buf, timpani(midi(ch[0] - 5), 0.2), s + 2 * beat, 0.0)
            place(buf, snare(0.12), s + beat, 0.1)
            place(buf, snare(0.12), s + 3 * beat, 0.1)
            if i % 4 == 3:
                for k in range(8):
                    place(buf, snare(0.06 + 0.012 * k, 0.1), s + 2 * beat + k * beat / 4, 0.1, human=False)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n, d in melody:
                place(buf, brass([midi(n + (12 if second else 0))], beat * d * 0.95, 0.15, 0.05, 0.25, 3400),
                      base + bi * bar_len + b * beat, 0.05)
                if second:
                    place(buf, brass([midi(n)], beat * d * 0.95, 0.09, 0.05, 0.25, 2600), base + bi * bar_len + b * beat, -0.15)

    return loop_render(build, bar_len * bars, 0.32, 1.6)


def lilkey_theme() -> np.ndarray:
    """Lil Key: dembow en La menor. Bombo en cada tiempo, la caja del dembow, shaker, un 808 que
    se desliza, un sinte de pulsos con eco y, en la segunda mitad, un "¡eh!" de coro.
    Lil Key: dembow in A minor. A kick on every beat, the dembow snare, shaker, a sliding 808, a
    plucky synth with an echo and, in the second half, an "eh!" vocal chop."""
    beat = 60.0 / 112
    bar_len = beat * 4
    chords = [[45, 57, 60, 64], [41, 57, 60, 65], [36, 55, 60, 64], [43, 55, 59, 62]]
    hook = [(0, 0, 76), (0, 0.75, 76), (0, 1.5, 74), (0, 2.5, 72), (0, 3, 74), (1, 0, 72), (1, 0.75, 69), (1, 1.5, 72),
            (2, 0, 72), (2, 0.75, 72), (2, 1.5, 71), (2, 2.5, 67), (2, 3, 71), (3, 0, 69), (3, 1.5, 64)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            for b in range(4):
                place(buf, kick(0.42, 56, 9), s + b * beat, 0.0, human=False)
            for k in (3, 6, 11, 14):
                place(buf, snare(0.17, 0.14, 230), s + k * beat / 4, 0.05, human=False)
                place(buf, rim(0.06), s + k * beat / 4, -0.2, human=False)
            for k in range(8):
                place(buf, shaker(0.05 if k % 2 else 0.03), s + k * beat / 2, 0.4)
            place(buf, sub808(midi(ch[0] - 12), bar_len * 0.95, 0.32, 5.0 if i % 4 == 0 else 0.0), s, 0.0, human=False)
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 0.3, 0.03, 0.2, 0.4, 1500), s, 0.0, human=False)
        for rep in range(4):
            base = off + rep * 4 * bar_len
            for bi, b, n in hook:
                at = base + bi * bar_len + b * beat
                p = pulse(midi(n + (12 if rep % 2 else 0)), beat * 0.6, 0.08, 0.3, 7, 3800)
                place(buf, p, at, -0.15, human=False)
                place(buf, p * 0.35, at + beat * 0.75, 0.35, human=False)   # eco / echo
        # "¡Eh!" de coro en la segunda mitad / An "eh!" vocal chop in the second half
        for bi in (8, 10, 12, 14):
            place(buf, vowel(0.22, 330, 300, 0.12), off + bi * bar_len + 3 * beat, 0.0, human=False)

    return loop_render(build, bar_len * bars, 0.2)


THEMES = {
    "music_svinho": (svinho_theme, 0.48), "music_stolk": (stolk_theme, 0.55), "music_silly": (silly_theme, 0.5),
    "music_doc": (doc_theme, 0.5), "music_ad": (ad_theme, 0.55), "music_pinche": (pinche_theme, 0.55),
    "music_charo": (charo_theme, 0.5), "music_magnus": (magnus_theme, 0.55), "music_superk": (superk_theme, 0.55),
    "music_lilkey": (lilkey_theme, 0.55),
}


# --- Leitmotivs: lo que suena al hablar con cada uno / What plays when you talk to each one ---

def _motif(fn_notes, length: float) -> np.ndarray:
    x = np.zeros((int(SR * length), 2))
    fn_notes(x)
    return x


def giver_svinho():
    def f(x):
        for at, n in ((0.0, 72), (0.18, 74), (0.27, 76), (0.55, 77), (0.72, 76)):
            place(x, whistle(midi(n), 0.3, 0.3), at, 0.1)
        for at in (0.0, 0.36, 0.55):
            _strum(x, [57, 60, 64], at, 0.1, -0.2, 0.01, 0.35, 1.0)
        place(x, thump(52, 0.6, 0.3, 3.5), 0.55, 0.0)
    return _motif(f, 2.0)


def giver_stolk():
    def f(x):
        for at, n in ((0.0, 40), (0.26, 40), (0.52, 43), (0.7, 45)):
            t = t_axis(0.3)
            ph = (midi(n) * t) % 1.0
            place(x, lp(np.tanh((2 * ph - 1) * 3.0), 520) * np.exp(-t * 3) * 0.5, at, 0.0)
        place(x, kick(0.6, 52), 0.0, 0.0)
        place(x, snare(0.35), 0.52, 0.0)
        place(x, metal(180, 1.0, 0.2), 0.9, 0.4)
    return _motif(f, 2.0)


def giver_silly():
    def f(x):
        for k, n in enumerate([76, 79, 81, 84, 81, 88]):
            place(x, bitcrush(pulse(midi(n), 0.12, 0.2, 0.25, 8)), k * 0.07, -0.3 + k * 0.12, human=False)
        for k in range(5):
            place(x, bar(RNG.uniform(2400, 3200), 0.04, 0.08, "wood", 1.0), 0.5 + k * 0.06, 0.4)
    return _motif(f, 1.4)


def giver_doc():
    def f(x):
        place(x, thump(48, 0.35, 0.5, 7.0), 0.0, 0.0)
        place(x, thump(44, 0.3, 0.35, 8.0), 0.28, 0.0)
        place(x, np.sin(2 * np.pi * 1760 * t_axis(0.1)) * env_ar(int(0.1 * SR), 0.004, 0.03) * 0.15, 0.6, 0.3, human=False)
        for k, n in enumerate([76, 80, 81]):
            place(x, glock(midi(n), 1.8, 0.25), 0.7 + k * 0.22, 0.1)
    return _motif(f, 2.4)


def giver_ad():
    def f(x):
        for k, n in enumerate([79, 76, 79, 84]):
            place(x, glock(midi(n), 1.0, 0.25), k * 0.13, 0.1)
        place(x, glock(midi(88) * 2 ** (-0.5 / 12), 1.2, 0.18), 0.65, -0.2)
        place(x, glock(midi(84), 1.6, 0.18), 0.85, -0.2)
        place(x, hp(noise(0.15), 3000) * 0.06, 1.05, 0.4, human=False)
    return _motif(f, 2.2)


def giver_pinche():
    def f(x):
        e = 60.0 / 400
        for k, n in enumerate([69, 70, 69, 67, 65, 64]):
            place(x, reed([midi(n)], e * 1.1, 0.25, 0.005, 0.04, 6.5, 3200), k * e, 0.05)
        place(x, metal(520, 0.7, 0.15), 0.0, -0.4)
        place(x, metal(610, 0.7, 0.12), 0.9, 0.4)
    return _motif(f, 1.8)


def giver_charo():
    def f(x):
        for k, (at, n) in enumerate([(0.0, 77), (0.6, 76), (0.9, 74), (1.2, 72)]):
            place(x, glock(midi(n + 12), 1.8, 0.22), at, 0.1)
        place(x, reed([midi(65), midi(69), midi(72)], 1.8, 0.12, 0.2, 0.4, 4.5, 1700), 0.0, -0.2, human=False)
        for at in (0.3, 0.45, 0.75):
            place(x, bar(3200, 0.03, 0.05, "wood", 1.0), at, 0.5)
    return _motif(f, 2.4)


def giver_magnus():
    def f(x):
        for k, (at, n) in enumerate([(0.0, 74), (0.3, 72), (0.45, 70), (0.75, 74)]):
            place(x, brass([midi(n)], 0.35, 0.25, 0.04, 0.12, 2600, True), at, 0.15)
        place(x, bar(1200, 0.1, 0.12, "wood", 0.9), 1.15, 0.4, human=False)
        place(x, glock(midi(96), 1.5, 0.15), 1.23, 0.4, human=False)
    return _motif(f, 2.6)


def giver_superk():
    def f(x):
        for at, n, d in ((0.0, 65, 0.2), (0.2, 70, 0.2), (0.4, 72, 0.2), (0.6, 74, 0.2), (0.8, 77, 0.9)):
            place(x, brass([midi(n)], d, 0.3, 0.04, 0.2, 3400), at, 0.05)
        place(x, timpani(midi(46), 0.45), 0.8, 0.0)
    return _motif(f, 2.4)


def giver_lilkey():
    def f(x):
        b = 60.0 / 112
        for k in range(4):
            place(x, kick(0.5, 56, 9), k * b, 0.0, human=False)
        for k in (3, 6, 11, 14):
            place(x, snare(0.22, 0.14, 230), k * b / 4, 0.05, human=False)
        place(x, sub808(midi(33), 1.8, 0.45, 5.0), 0.0, 0.0, human=False)
        for at, n in ((0.0, 76), (0.4, 76), (0.8, 74), (1.34, 72)):
            place(x, pulse(midi(n), 0.3, 0.18, 0.3, 7, 3800), at, -0.15, human=False)
        place(x, vowel(0.22, 330, 300, 0.25), 1.6, 0.0, human=False)
    return _motif(f, 2.4)


GIVERS = {"giver_svinho": giver_svinho, "giver_stolk": giver_stolk, "giver_silly": giver_silly, "giver_doc": giver_doc,
          "giver_ad": giver_ad, "giver_pinche": giver_pinche, "giver_charo": giver_charo, "giver_magnus": giver_magnus,
          "giver_superk": giver_superk, "giver_lilkey": giver_lilkey}


def render(only: set, save) -> None:
    for name, (fn, peak) in MUSIC.items():
        if not only or name in only:
            save(name, fn(), peak, room=0)
    for name, (fn, peak, room) in SFX.items():
        if not only or name in only:
            save(name, fn(), peak, room)
    for name, (fn, peak) in THEMES.items():
        if not only or name in only:
            save(name, fn(), peak, room=0)
    for name, fn in GIVERS.items():
        if not only or name in only:
            save(name, fn(), 0.42, 0.3)


# --- Música mejorada del resto del juego / Improved music for the rest of the game -------------

def menu_theme() -> np.ndarray:
    """Menú: nana de arpa y kalimba en Re mayor, ahora con una segunda parte con cuerdas suaves y
    una contramelodía de caja de música.
    Menu: a harp and kalimba lullaby in D major, now with a second part with soft strings and a
    music-box countermelody."""
    beat = 60.0 / 66
    bar_len = beat * 4
    chords = [[50, 57, 62, 66], [47, 54, 59, 62], [43, 50, 55, 59], [45, 52, 57, 61],
              [43, 55, 59, 62], [45, 57, 61, 64], [47, 54, 59, 62], [45, 52, 57, 61]]
    mel_a = [(0, 0, 74, 2), (0, 2, 73, 1), (0, 3, 71, 1), (1, 0, 69, 3), (2, 0, 71, 2), (2, 2, 74, 2),
             (3, 0, 73, 4), (4, 0, 78, 2), (4, 2, 76, 1), (4, 3, 74, 1), (5, 0, 71, 3), (6, 0, 69, 2),
             (6, 2, 71, 1), (6, 3, 73, 1), (7, 0, 74, 4)]
    mel_b = [(0, 0, 79, 2), (0, 2, 78, 2), (1, 0, 76, 3), (1, 3, 73, 1), (2, 0, 74, 2), (2, 2, 78, 2),
             (3, 0, 76, 4), (4, 0, 74, 1), (4, 1, 76, 1), (4, 2, 78, 2), (5, 0, 81, 3), (6, 0, 78, 2), (6, 2, 76, 2), (7, 0, 74, 4)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4] if i < 8 else chords[4 + i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 2.0, 0.09, 1.2, 2.0, 1300), s, human=False)
            place(buf, pluck(midi(ch[0] - 12), 4.0, 0.3, 0.2, 0.998), s)
            A._arp(buf, ch, s, beat, 4, 0.06)
            if i >= 8:
                place(buf, saw_pad([midi(ch[1] + 12), midi(ch[2] + 12)], bar_len + 1.0, 0.05, 1.8, 1.5, 2400), s, 0.0, human=False)
        for bi, b, n, _ in mel_a:
            place(buf, bar(midi(n), 2.5, 0.22, "kalimba", 0.3), off + bi * bar_len + b * beat, 0.15)
        for bi, b, n, _ in mel_b:
            place(buf, bar(midi(n), 2.5, 0.2, "kalimba", 0.3), off + (bi + 8) * bar_len + b * beat, 0.15)
            place(buf, glock(midi(n + 12), 1.4, 0.05), off + (bi + 8) * bar_len + b * beat + beat * 0.5, -0.4)

    return loop_render(build, bar_len * bars, 0.35)


def dream_theme() -> np.ndarray:
    """Acto 1, el cuarto: lenta y un poco rara, con un acorde que se tuerce. Marimba, arpa, una
    caja de música lejana y escobillas muy suaves en la segunda parte.
    Act 1, the bedroom: slow and a little strange, with a chord that bends. Marimba, harp, a distant
    music box and very soft brushes in the second part."""
    beat = 60.0 / 58
    bar_len = beat * 4
    chords = [[50, 57, 62, 64], [47, 54, 59, 62], [46, 53, 58, 62], [45, 52, 57, 61]]
    mel_a = [(0, 0, 69), (0, 3, 67), (1, 0, 66), (2, 0, 65), (2, 2, 62), (3, 0, 64),
             (4, 0, 69), (4, 2, 71), (5, 0, 67), (6, 0, 65), (6, 3, 62), (7, 0, 61)]
    mel_b = [(0, 0, 74), (0, 2, 73), (1, 0, 71), (1, 2, 69), (2, 0, 70), (2, 2, 69), (3, 0, 67),
             (4, 0, 69), (4, 1, 71), (4, 2, 74), (5, 0, 73), (6, 0, 70), (6, 2, 67), (7, 0, 69)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 2.4, 0.1, 2.0, 2.4, 1100), s, human=False)
            place(buf, pluck(midi(ch[0] - 12), 4.0, 0.3, 0.15, 0.998), s)
            for b, idx in ((0.5, 1), (1.5, 2), (2.5, 3), (3.5, 2)):
                place(buf, bar(midi(ch[idx] + 12), 1.6, 0.07, "marimba", 0.3), s + b * beat, -0.4 + 0.25 * idx)
            if i >= 8:
                for b in range(4):
                    place(buf, lp(breath(beat * 0.8, 1800, 6500, 0.03), 6000) * env_ar(int(beat * 0.8 * SR), 0.05, 0.4), s + b * beat, 0.3)
                place(buf, thump(60, 0.4, 0.1, 6.0), s, 0.0)
        for bi, b, n in mel_a:
            place(buf, pluck(midi(n), 3.0, 0.2, 0.45), off + bi * bar_len + b * beat, 0.1)
        for bi, b, n in mel_b:
            place(buf, glock(midi(n), 2.2, 0.1), off + (bi + 8) * bar_len + b * beat, 0.1)
            place(buf, pluck(midi(n - 12), 3.0, 0.12, 0.4), off + (bi + 8) * bar_len + b * beat, -0.2)

    return loop_render(build, bar_len * bars, 0.45, 1.6)


def astral_theme() -> np.ndarray:
    """Plano astral: acordes suspendidos que flotan, kalimba lejana, un coro de "aaah" muy suave y
    destellos de campanitas.
    Astral plane: floating suspended chords, a distant kalimba, a very soft "aaah" choir and
    glimmers of little bells."""
    beat = 60.0 / 52
    bar_len = beat * 4
    chords = [[43, 55, 62, 67, 69], [40, 52, 59, 64, 66], [36, 48, 55, 62, 64], [38, 50, 57, 62, 64]]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 3.0, 0.11, 2.5, 3.0, 1200), s, human=False)
            place(buf, pluck(midi(ch[0]), 4.0, 0.22, 0.15, 0.998), s)
            for b, idx in ((1.0, 3), (2.5, 4), (3.25, 2)):
                place(buf, bar(midi(ch[idx] + 12), 2.5, 0.09, "kalimba", 0.2), s + b * beat, RNG.uniform(-0.6, 0.6))
            if i >= 8 and i % 2 == 0:
                place(buf, vowel(bar_len * 1.8, midi(ch[2]), midi(ch[2]), 0.05), s, -0.3, human=False)
                place(buf, vowel(bar_len * 1.8, midi(ch[3]), midi(ch[3]), 0.04), s + 0.3, 0.3, human=False)
            for k in range(3):
                place(buf, glock(midi(ch[1 + k] + 24), 2.0, 0.025), s + RNG.uniform(0, bar_len), RNG.uniform(-0.8, 0.8))

    return loop_render(build, bar_len * bars, 0.55, 1.8)


def boss_theme() -> np.ndarray:
    """Jefe del Acto 1: los muebles despiertan. Pulso de tambor de fieltro, bombo y caja, acordes
    de metal que avisan y marimba inquieta.
    Act 1 boss: the furniture wakes. A felt-drum pulse, kick and snare, warning brass chords and an
    uneasy marimba."""
    beat = 60.0 / 100
    bar_len = beat * 4
    roots = [38, 38, 34, 36, 38, 41, 34, 33]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            r = roots[i % 8]
            s = off + i * bar_len
            place(buf, saw_pad([midi(r + 12), midi(r + 15), midi(r + 19)], bar_len + 1.2, 0.09, 0.5, 1.2, 900), s, human=False)
            for b in range(4):
                place(buf, kick(0.35, 50, 7), s + b * beat, 0.0)
                place(buf, pluck(midi(r - 12 + 12), beat * 1.2, 0.22, 0.25, 0.99), s + b * beat)
            for b in (1, 3):
                place(buf, snare(0.16), s + b * beat, 0.1)
            for k in range(8):
                place(buf, hat(0.03), s + k * beat / 2 + beat / 4, 0.4)
            for b in (0.5, 1.5, 2.75, 3.5):
                place(buf, bar(midi(r + 24 + (3 if (i + int(b)) % 2 else 0)), 0.9, 0.11, "marimba", 0.5), s + b * beat,
                      -0.5 if b < 2 else 0.5)
            if i % 4 == 0:
                place(buf, brass([midi(r + 12), midi(r + 15), midi(r + 18)], beat * 1.5, 0.1, 0.1, 0.4, 2000), s, -0.2)
        for k, n in enumerate([62, 61, 58, 57, 62, 65, 64, 61, 62, 65, 69, 68, 65, 62, 61, 57]):
            place(buf, pluck(midi(n), 3.0, 0.15, 0.4), off + k * bar_len + beat * 0.5, 0.2)

    return loop_render(build, bar_len * bars, 0.3)


def school_theme() -> np.ndarray:
    """Acto 3, el pasillo del cole: un xilófono y una flauta dulce de clase de música, un piano de
    juguete, palmadas y el din-don del timbre... pero el acorde se tuerce, como si el pasillo no
    acabara nunca.
    Act 3, the school hallway: a xylophone and a music-class recorder, a toy piano, claps and the
    ding-dong of the bell... but the chord bends, as if the hallway never ended."""
    beat = 60.0 / 104
    bar_len = beat * 4
    chords = [[43, 59, 62, 67], [40, 59, 64, 67], [36, 60, 64, 67], [38, 57, 62, 66],
              [43, 59, 62, 67], [39, 58, 63, 67], [36, 60, 63, 67], [38, 57, 62, 66]]
    melody = [(0, 0, 74), (0, 1, 71), (0, 2, 67), (0, 3, 71), (1, 0, 72), (1, 2, 76), (2, 0, 74), (2, 1, 72), (2, 2, 71),
              (3, 0, 69), (4, 0, 74), (4, 1, 79), (4, 2, 78), (5, 0, 75), (5, 2, 70), (6, 0, 72), (6, 1, 70), (6, 2, 67), (7, 0, 69)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 1.0, 0.05, 0.6, 1.0, 1300), s, human=False)
            for b in range(4):
                place(buf, pluck(midi(ch[0] - 12 + (7 if b % 2 else 0)), beat * 0.9, 0.22, 0.3, 0.99), s + b * beat)
            for k in range(8):
                n = ch[1 + k % 3] + 12
                place(buf, bar(midi(n), 0.35, 0.05, "marimba", 0.8), s + k * beat / 2, -0.35 + 0.1 * (k % 4))
            place(buf, rim(0.07), s + beat, 0.3)
            place(buf, rim(0.07), s + 3 * beat, 0.3)
            if i >= 8:
                place(buf, clap(0.08), s + 3 * beat, -0.2)
                place(buf, kick(0.18, 60, 10), s, 0.0)
                place(buf, kick(0.14, 60, 10), s + 2 * beat, 0.0)
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n in melody:
                if second:
                    place(buf, glock(midi(n + 12), 1.0, 0.07), base + bi * bar_len + b * beat, 0.3)
                place(buf, whistle(midi(n), beat * 0.95, 0.12, 4.5), base + bi * bar_len + b * beat, -0.05)
        # El timbre al final de la vuelta / The bell at the end of the loop
        for k, n in enumerate([79, 76, 72, 79]):
            place(buf, glock(midi(n), 1.8, 0.07), off + 15 * bar_len + k * beat * 0.5, 0.0, human=False)

    return loop_render(build, bar_len * bars, 0.3)


def ufo_theme() -> np.ndarray:
    """El Ovni: ciencia ficción de los 50. Un theremin que se desliza, arpegios burbujeantes,
    pulso de bombo, acordes misteriosos y pitidos de radar.
    The UFO: 1950s sci-fi. A gliding theremin, bubbly arpeggios, a kick pulse, mysterious chords
    and radar blips."""
    beat = 60.0 / 112
    bar_len = beat * 4
    roots = [40, 40, 36, 38, 40, 43, 36, 35]
    melody = [(0, 0, 76, 2), (0, 2, 79, 2), (1, 0, 78, 3), (1, 3, 75, 1), (2, 0, 72, 2), (2, 2, 76, 2), (3, 0, 74, 4),
              (4, 0, 76, 1), (4, 1, 83, 3), (5, 0, 82, 2), (5, 2, 79, 2), (6, 0, 77, 2), (6, 2, 72, 2), (7, 0, 71, 4)]
    bars = 16

    def theremin(n0, n1, dur, amp):
        t = t_axis(dur)
        k = np.clip(t / 0.18, 0, 1)
        f = midi(n0) * (2 ** ((n1 - n0) / 12 * k)) * (1 + 0.012 * np.sin(2 * np.pi * 6.0 * t))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ar(len(t), 0.06, 0.25) * amp

    def build(buf, off):
        for i in range(bars):
            r = roots[i % 8]
            s = off + i * bar_len
            place(buf, saw_pad([midi(r + 12), midi(r + 15), midi(r + 19), midi(r + 22)], bar_len + 1.0, 0.06, 0.8, 1.0, 1100), s, human=False)
            for b in range(4):
                place(buf, kick(0.3, 50, 8), s + b * beat, 0.0)
            for k in range(16):
                n = r + 24 + [0, 7, 12, 15, 19, 15, 12, 7][k % 8]
                place(buf, pulse(midi(n), beat / 4, 0.03, 0.5, 18, 2500), s + k * beat / 4, -0.5 + (k % 8) * 0.12, human=False)
            place(buf, np.sin(2 * np.pi * 2200 * t_axis(0.06)) * np.exp(-t_axis(0.06) * 40) * 0.03, s + 2.5 * beat, 0.6, human=False)
            for b in (1, 3):
                place(buf, snare(0.1, 0.18), s + b * beat, 0.1)
        prev = 76
        for second in (False, True):
            base = off + (8 * bar_len if second else 0.0)
            for bi, b, n, d in melody:
                place(buf, theremin(prev, n + (12 if second else 0), beat * d, 0.13), base + bi * bar_len + b * beat, 0.1, human=False)
                prev = n + (12 if second else 0)

    return loop_render(build, bar_len * bars, 0.35, 1.6)


def city_theme() -> np.ndarray:
    """Acto 4, la Metrópolis: paseo por una ciudad grande, alegre y con prisa. Bajo que camina,
    arpa a contratiempo, marimba, una kalimba que canta y ahora una batería suave y metales.
    Act 4, the Metropolis: a stroll through a big city, cheerful and busy. Walking bass, offbeat
    harp, marimba, a singing kalimba and now a soft drum kit and brass."""
    beat = 60.0 / 104
    bar_len = beat * 4
    chords = [[43, 55, 59, 62], [40, 55, 59, 64], [36, 55, 60, 64], [38, 54, 57, 62],
              [43, 55, 59, 62], [40, 55, 59, 64], [36, 52, 55, 60], [38, 54, 57, 62]]
    melody = [(0, 0, 74), (0, 1, 76), (0, 1.5, 74), (0, 2, 71), (1, 0, 72), (1, 1.5, 71), (1, 2, 67),
              (2, 0, 69), (2, 1, 71), (2, 2, 72), (3, 0, 74), (3, 2, 69), (4, 0, 79), (4, 1, 78), (4, 1.5, 76),
              (4, 2, 74), (5, 0, 76), (5, 2, 71), (6, 0, 72), (6, 1, 74), (6, 2, 76), (7, 0, 74)]
    bars = 16

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 8]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 1.2, 0.05, 0.6, 1.2, 1200), s, human=False)
            for b in range(4):
                n = ch[0] - 12 + [0, 7, 12, 7][b]
                place(buf, pluck(midi(n), beat * 1.1, 0.22, 0.25, 0.99), s + b * beat)
                place(buf, kick(0.22, 60, 9), s + b * beat if b % 2 == 0 else s + b * beat + beat * 0.5, 0.0)
            for b in (1, 3):
                place(buf, snare(0.12, 0.18), s + b * beat, 0.1)
            for k in range(8):
                place(buf, hat(0.035 if k % 2 else 0.05), s + k * beat / 2, 0.4)
            for b in (0.5, 1.5, 2.5, 3.5):
                for k, n in enumerate(ch[1:]):
                    place(buf, pluck(midi(n + 12), 0.6, 0.03, 0.4), s + b * beat + k * 0.01, -0.4 + k * 0.4)
            for k in range(8):
                n = ch[1 + k % 3] + 12
                place(buf, bar(midi(n), 0.4, 0.04, "marimba", 0.5), s + k * beat / 2, 0.4 - 0.1 * k)
        for bi, b, n in melody:
            place(buf, bar(midi(n), 1.4, 0.15, "kalimba", 0.4), off + bi * bar_len + b * beat, 0.05)
            place(buf, brass([midi(n)], beat * 0.7, 0.08, 0.04, 0.15, 2600), off + (bi + 8) * bar_len + b * beat, 0.1)
            place(buf, bar(midi(n + 12), 1.0, 0.05, "kalimba", 0.4), off + (bi + 8) * bar_len + b * beat, -0.3)

    return loop_render(build, bar_len * bars, 0.28)


MUSIC = {"music_menu": (menu_theme, 0.55), "music_dream1": (dream_theme, 0.55), "music_astral": (astral_theme, 0.55),
         "music_boss": (boss_theme, 0.55), "music_school": (school_theme, 0.55), "music_ufo": (ufo_theme, 0.55),
         "music_city": (city_theme, 0.55)}


# --- Efectos mejorados / Improved sound effects ------------------------------------------

def sfx_hit():
    """Golpe con cuerpo: madera, un golpe sordo y un chasquido / A hit with body: wood, a thud and a snap."""
    return mix(bar(RNG.uniform(260, 320), 0.3, 0.45, "wood", 0.7), thump(110, 0.18, 0.35, 14),
               hp(noise(0.04), 2500) * np.exp(-t_axis(0.04) * 90) * 0.25)


def sfx_swing():
    """Zumbido de aire que pasa de un lado a otro / A swish of air passing from one side to the other."""
    x = A.sweep_noise(0.24, 300, 1800, 2.2, 0.5)
    n = len(x)
    pan = np.linspace(-0.6, 0.6, n)
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1) * 1.3


def sfx_hurt():
    """Golpe que duele, un "uf" y un pequeño crujido / A painful thump, an "oof" and a little crunch."""
    return mix(thump(85, 0.35, 0.65, 10), vowel(0.28, 280, 190, 0.32), bp(noise(0.08), 800, 3000) * np.exp(-t_axis(0.08) * 50) * 0.2)


def sfx_pickup():
    """Trozo de estrella: arpegio de campanitas con un destello / Star shard: a bell arpeggio with a sparkle."""
    x = np.zeros((int(SR * 1.6), 2))
    for i, n in enumerate([74, 78, 81, 86]):
        place(x, glock(midi(n), 1.2, 0.22), i * 0.045, -0.4 + i * 0.27, human=False)
    place(x, hp(noise(0.2), 8000) * np.exp(-t_axis(0.2) * 20) * 0.08, 0.15, 0.3, human=False)
    return x


def sfx_hover():
    return glock(midi(81), 0.4, 0.15)


def sfx_click():
    return mix(glock(midi(76), 0.6, 0.25), np.pad(glock(midi(83), 0.6, 0.2), (int(SR * 0.04), 0)), thump(160, 0.06, 0.12, 20))


def sfx_foox_die():
    """Un fantasma que se deshace: campanitas que bajan y un soplo / A ghost dissolving: falling bells and a puff."""
    x = np.zeros((int(SR * 1.4), 2))
    for i, n in enumerate([81, 76, 72, 69]):
        place(x, glock(midi(n), 1.0, 0.18), i * 0.06, 0.3 - i * 0.2, human=False)
    return mix(x, A.sweep_noise(0.6, 1200, 300, 2.0, 0.2))


def sfx_win():
    """Sueño superado: arpa que sube, metales y campanas / Dream cleared: a rising harp, brass and bells."""
    x = np.zeros((int(SR * 4.0), 2))
    for i, n in enumerate([62, 66, 69, 73, 74, 78, 81]):
        place(x, pluck(midi(n), 2.8, 0.22, 0.5), i * 0.1, -0.6 + i * 0.2, human=False)
    place(x, brass([midi(62), midi(66), midi(69), midi(74)], 2.4, 0.12, 0.2, 1.2, 2600), 0.6, 0.0, human=False)
    for i, n in enumerate([86, 90, 93]):
        place(x, glock(midi(n), 2.0, 0.08), 0.7 + i * 0.08, 0.4, human=False)
    place(x, saw_pad([midi(n) for n in (50, 57, 62, 66)], 3.8, 0.1, 0.3, 2.0, 1500), 0, human=False)
    return x


def sfx_lose():
    x = np.zeros((int(SR * 4.0), 2))
    for i, n in enumerate([74, 70, 69, 65, 62]):
        place(x, pluck(midi(n), 2.8, 0.22, 0.35), i * 0.28, 0.5 - i * 0.25, human=False)
    place(x, saw_pad([midi(n) for n in (50, 53, 57, 62)], 3.8, 0.11, 0.5, 2.2, 900), 0.1, human=False)
    place(x, brass([midi(50), midi(53)], 2.5, 0.07, 0.4, 1.4, 1200, True), 1.0, 0.0, human=False)
    return x


def sfx_chime():
    return mix(glock(midi(86), 1.4, 0.3), np.pad(glock(midi(93), 1.4, 0.22), (int(SR * 0.08), 0)), bar(midi(74), 1.2, 0.15, "kalimba", 0.3))


SFX = {"hit": (sfx_hit, 0.4, 0.1), "swing": (sfx_swing, 0.42, 0.1), "hurt": (sfx_hurt, 0.52, 0.12),
       "pickup": (sfx_pickup, 0.4, 0.3), "ui_hover": (sfx_hover, 0.22, 0.12), "ui_click": (sfx_click, 0.32, 0.12),
       "foox_die": (sfx_foox_die, 0.38, 0.3), "win": (sfx_win, 0.5, 0.35), "lose": (sfx_lose, 0.5, 0.35),
       "chime": (sfx_chime, 0.35, 0.25)}

OVERRIDES = set(MUSIC) | set(SFX)
