"""Genera la música y los efectos de Dreamed por síntesis (sin muestras externas).
Generates Dreamed's music and sound effects by synthesis (no external samples).

Uso / Usage:  python3 tools/make_audio.py
Escribe los .wav en assets/audio/. Necesita numpy y scipy.
Writes the .wav files to assets/audio/. Needs numpy and scipy.

Estilo: cálido y grave, como un sueño lento. Piano eléctrico suave, mazos de fieltro,
pads cálidos y golpes sordos. Nada de campanitas ni agudos: todo se filtra por debajo
de ~2,5 kHz para que nunca sea estridente.
Style: warm and low, like a slow dream. Soft electric piano, felt mallets, warm pads
and muffled thumps. No chimes and no highs: everything is filtered below ~2.5 kHz so
it is never shrill.
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RNG = np.random.default_rng(11)
TOP = 2400.0   # ningún sonido pasa de aquí / nothing goes above this


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def noise(dur: float) -> np.ndarray:
    return RNG.normal(0, 1, int(dur * SR))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def soft_env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-decay * t)


# --- Instrumentos / Instruments ----------------------------------------------

def epiano(freq: float, dur: float = 2.5, amp: float = 0.3) -> np.ndarray:
    """Piano eléctrico suave (tipo Rhodes apagado) / Soft, muted electric piano (Rhodes-like)."""
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * t) * 0.6 * np.exp(-4 * t)          # FM breve al inicio / brief FM bite
    body = np.sin(2 * np.pi * freq * t + mod)
    if freq * 2 < TOP:
        body += 0.18 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-3 * t)
    trem = 1.0 + 0.06 * np.sin(2 * np.pi * 4.2 * t)
    return body * trem * soft_env(t, 0.012, 1.6) * amp


def mallet(freq: float, dur: float = 1.2, amp: float = 0.3) -> np.ndarray:
    """Mazo de fieltro sobre madera, grave y redondo / Felt mallet on wood, low and round."""
    t = t_axis(dur)
    out = np.sin(2 * np.pi * freq * t) * np.exp(-5 * t)
    if freq * 3.9 < TOP:
        out += 0.12 * np.sin(2 * np.pi * freq * 3.9 * t) * np.exp(-14 * t)
    return out * np.minimum(1.0, t / 0.006) * amp


def pad(freqs: list[float], dur: float, amp: float = 0.08, attack: float = 1.5, release: float = 2.0) -> np.ndarray:
    """Pad cálido de ondas triangulares desafinadas / Warm pad of detuned triangle waves."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.003, 0.0, 0.0035):
            ph = RNG.uniform(0, 2 * np.pi)
            out += (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * f * (1 + det) * t + ph))
    env = np.minimum(1.0, t / attack) * np.clip((dur - t) / release, 0, 1)
    breathe = 1.0 + 0.1 * np.sin(2 * np.pi * 0.17 * t)
    return lowpass(lowpass(out, 1100), 1100) * env * breathe * amp / len(freqs)


def bass(freq: float, dur: float, amp: float = 0.2) -> np.ndarray:
    t = t_axis(dur)
    return np.sin(2 * np.pi * freq * t) * soft_env(t, 0.05, 0.9) * amp


def thump(freq: float = 90.0, dur: float = 0.4, amp: float = 0.8, drop: float = 6.0) -> np.ndarray:
    """Golpe sordo / Muffled thump."""
    t = t_axis(dur)
    f = freq * (1 + 0.8 * np.exp(-t * drop))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * soft_env(t, 0.003, 9.0) * amp


def puff(dur: float = 0.3, cutoff: float = 700.0, amp: float = 1.0) -> np.ndarray:
    """Soplo de aire apagado / Muffled puff of air."""
    t = t_axis(dur)
    return lowpass(lowpass(noise(dur), cutoff), cutoff) * np.sin(np.pi * t / dur) ** 1.5 * amp * 3


def glide(f0: float, f1: float, dur: float, amp: float = 0.3) -> np.ndarray:
    """Tono que se desliza, suave como un 'uuuh' / Gliding tone, soft like an 'oooh'."""
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.2 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return tone * np.sin(np.pi * t / dur) ** 1.2 * amp


# --- Mezcla / Mixing ---------------------------------------------------------

def reverb(x: np.ndarray, mix: float = 0.35, size: float = 1.0) -> np.ndarray:
    """Reverberación Schroeder oscura / Dark Schroeder reverb."""
    combs = [0.0297, 0.0371, 0.0411, 0.0437, 0.0503, 0.0571]
    wet = np.zeros_like(x)
    src = lowpass(x, 1800)
    for d in combs:
        n = int(d * size * SR)
        a = np.zeros(n + 1)
        a[0] = 1.0
        a[n] = -0.84
        wet += lfilter([1.0], a, src)
    wet /= len(combs)
    for d, g in [(0.005, 0.7), (0.0017, 0.7)]:
        n = int(d * SR)
        b = np.zeros(n + 1)
        a = np.zeros(n + 1)
        b[0], b[n] = -g, 1.0
        a[0], a[n] = 1.0, -g
        wet = lfilter(b, a, wet)
    return x * (1 - mix) + lowpass(wet, 1500) * mix


def mix(*sigs: np.ndarray) -> np.ndarray:
    """Suma sonidos de distinta duración / Adds sounds of different lengths."""
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[: len(x)] += x
    return out


def place(buf: np.ndarray, sig: np.ndarray, at: float) -> None:
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def save(name: str, x: np.ndarray, peak: float = 0.6, cutoff: float = TOP) -> None:
    x = lowpass(lowpass(lowpass(x, cutoff), cutoff), cutoff)
    # Quita el "clic" del principio y del final / Removes clicks at both ends
    fade = min(len(x) // 4, int(SR * 0.01))
    x[:fade] *= np.linspace(0, 1, fade)
    if not name.startswith("music") and name != "vacuum":
        x[-fade:] *= np.linspace(1, 0, fade)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{name}.wav  {len(x) / SR:.1f}s")


def loop_render(build, length: float, reverb_mix: float, size: float = 1.3) -> np.ndarray:
    """Dibuja dos vueltas y se queda con la segunda para que el bucle empalme.
    Renders two passes and keeps the second, so the loop joins seamlessly."""
    buf = np.zeros(int(length * 2 * SR) + SR * 4)
    build(buf, 0.0)
    build(buf, length)
    wet = reverb(buf, reverb_mix, size)
    n = int(length * SR)
    return wet[n: 2 * n]


# --- Música / Music ----------------------------------------------------------
# Todo en un registro medio-grave; la melodía nunca pasa de Do5.
# Everything in a low-mid register; the melody never goes above C5.

def menu_theme() -> np.ndarray:
    """Nana lenta de piano eléctrico en Re mayor / Slow electric piano lullaby in D major."""
    beat = 60.0 / 64
    bar = beat * 4
    chords = [[38, 54, 57, 61, 64], [35, 50, 54, 57, 62], [31, 50, 55, 59, 62], [33, 49, 52, 57, 64]]
    melody = [(0, 0, 69, 2), (0, 2, 66, 2), (1, 0, 62, 3), (1, 3, 64, 1), (2, 0, 66, 2), (2, 2, 67, 2),
              (3, 0, 64, 4), (4, 0, 69, 2), (4, 2, 71, 2), (5, 0, 69, 3), (5, 3, 66, 1), (6, 0, 67, 2),
              (6, 2, 64, 2), (7, 0, 62, 4)]
    bars = 8

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars):
            ch = chords[i % 4]
            start = off + i * bar
            place(buf, pad([midi(n) for n in ch[1:]], bar + 1.8, 0.13), start)
            place(buf, bass(midi(ch[0]), bar, 0.22), start)
            for b in range(4):
                place(buf, epiano(midi(ch[1 + b % 4]), 1.6, 0.06), start + b * beat + 0.02)
        for bi, b, n, _ in melody:
            place(buf, epiano(midi(n), 3.0, 0.24), off + bi * bar + b * beat)

    return loop_render(build, bar * bars, 0.4)


def dream_theme() -> np.ndarray:
    """Más lenta, con un acorde que se tuerce / Slower, with a chord that bends."""
    beat = 60.0 / 56
    bar = beat * 4
    chords = [[38, 50, 57, 62, 64], [35, 47, 54, 59, 62], [34, 46, 53, 58, 62], [33, 45, 52, 57, 61]]
    melody = [(0, 0, 69, 3), (0, 3, 67, 1), (1, 0, 66, 4), (2, 0, 65, 2), (2, 2, 62, 2), (3, 0, 64, 4),
              (4, 0, 69, 2), (4, 2, 71, 2), (5, 0, 67, 4), (6, 0, 65, 3), (6, 3, 62, 1), (7, 0, 61, 4)]
    bars = 8

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars):
            ch = chords[i % 4]
            start = off + i * bar
            place(buf, pad([midi(n) for n in ch[1:]], bar + 2.0, 0.14, 2.0), start)
            place(buf, bass(midi(ch[0]), bar, 0.2), start)
            for b in (0, 2.5):
                place(buf, mallet(midi(ch[2 + int(b) % 3]), 1.4, 0.07), start + b * beat)
        for bi, b, n, _ in melody:
            place(buf, epiano(midi(n), 3.4, 0.22), off + bi * bar + b * beat)

    return loop_render(build, bar * bars, 0.5, 1.5)


def astral_theme() -> np.ndarray:
    """Acordes suspendidos que flotan / Floating suspended chords."""
    beat = 60.0 / 50
    bar = beat * 4
    chords = [[43, 55, 62, 67, 69], [40, 52, 59, 64, 66], [36, 48, 55, 62, 64], [38, 50, 57, 62, 64]]
    bars = 8

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars):
            ch = chords[i % 4]
            start = off + i * bar
            place(buf, pad([midi(n) for n in ch[1:]], bar + 2.5, 0.16, 2.5, 2.5), start)
            place(buf, bass(midi(ch[0]), bar * 0.9, 0.16), start)
            place(buf, epiano(midi(ch[3]), 3.0, 0.12), start + beat)
            place(buf, epiano(midi(ch[4]), 3.0, 0.1), start + beat * 2.5)

    return loop_render(build, bar * bars, 0.6, 1.7)


def boss_theme() -> np.ndarray:
    """Jefe: pulso grave y lento, inquietante pero no agresivo / Boss: slow low pulse, uneasy but not harsh."""
    beat = 60.0 / 92
    bar = beat * 4
    roots = [38, 38, 34, 36]
    bars = 8

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars):
            r = roots[i % 4]
            start = off + i * bar
            place(buf, pad([midi(r + 12), midi(r + 15), midi(r + 19)], bar + 1.0, 0.12, 0.6, 1.0), start)
            for b in range(4):
                place(buf, thump(55, 0.5, 0.35, 4.0), start + b * beat)
                place(buf, bass(midi(r), beat * 0.9, 0.18), start + b * beat)
            for b in (1.5, 3.5):
                place(buf, mallet(midi(r + 24 + (3 if i % 2 else 0)), 0.8, 0.12), start + b * beat)
        for k, n in enumerate([62, 61, 58, 57, 62, 65, 64, 61]):
            place(buf, epiano(midi(n), 2.6, 0.13), off + k * bar)

    return loop_render(build, bar * bars, 0.35)


# --- Efectos / Sound effects -------------------------------------------------

def sfx_hover():
    return mallet(midi(55), 0.25, 0.3)


def sfx_click():
    x = np.zeros(int(SR * 0.6))
    place(x, mallet(midi(57), 0.5, 0.35), 0)
    place(x, mallet(midi(62), 0.5, 0.3), 0.06)
    return reverb(x, 0.25)


def sfx_swing():
    return reverb(np.pad(puff(0.25, 600, 0.8), (0, SR // 6)), 0.15)


def sfx_pillow():
    x = mix(thump(80, 0.35, 0.8, 8), puff(0.3, 500, 0.9))
    return reverb(x, 0.2)


def sfx_zap():
    """Rayo: un 'fum' tonal que baja, sin chisporroteo / Lightning: a falling tonal 'whum', no crackle."""
    x = mix(glide(520, 180, 0.4, 0.5), puff(0.3, 900, 0.4))
    return reverb(x, 0.3)


def sfx_vacuum():
    t = t_axis(1.0)
    hum = np.sin(2 * np.pi * 90 * t) * 0.3 + np.sin(2 * np.pi * 180 * t) * 0.08
    air = lowpass(lowpass(np.tile(noise(0.25), 4)[: len(t)], 350), 350) * 3.0
    return (hum + air) * (1.0 + 0.15 * np.sin(2 * np.pi * 2 * t))


def sfx_spawn():
    return reverb(mix(glide(140, 260, 0.9, 0.4), puff(0.9, 400, 0.3)), 0.45)


def sfx_hit():
    return thump(150, 0.18, 0.6, 10)


def sfx_foox_die():
    x = np.zeros(int(SR * 1.0))
    for i, n in enumerate([62, 57, 54]):
        place(x, epiano(midi(n), 0.8, 0.25), i * 0.08)
    return reverb(mix(x, puff(0.5, 500, 0.3)), 0.4)


def sfx_hurt():
    return reverb(mix(glide(240, 120, 0.35, 0.6), thump(70, 0.3, 0.5)), 0.2)


def sfx_pickup():
    x = np.zeros(int(SR * 1.4))
    for i, n in enumerate([50, 54, 57, 62]):
        place(x, epiano(midi(n), 1.0, 0.3), i * 0.09)
    return reverb(x, 0.4)


def sfx_chime():
    x = np.zeros(int(SR * 1.0))
    place(x, epiano(midi(62), 0.9, 0.3), 0)
    place(x, epiano(midi(66), 0.9, 0.22), 0.07)
    return reverb(x, 0.4)


def sfx_blanket():
    t = t_axis(0.7)
    return puff(0.7, 900, 0.5) * (1.0 + 0.5 * np.sin(2 * np.pi * 8 * t))


def sfx_yawn():
    return reverb(mix(lowpass(glide(220, 160, 1.2, 0.4), 900), puff(1.2, 500, 0.3)), 0.3)


def sfx_land():
    return mix(thump(70, 0.3, 0.8, 8), puff(0.2, 400, 0.4))


def sfx_win():
    x = np.zeros(int(SR * 3.5))
    for i, n in enumerate([50, 54, 57, 61, 62, 66]):
        place(x, epiano(midi(n), 2.5, 0.28), i * 0.15)
    place(x, pad([midi(n) for n in [50, 54, 57, 61]], 3.4, 0.16, 0.4, 1.8), 0)
    return reverb(x, 0.45)


def sfx_lose():
    x = np.zeros(int(SR * 3.5))
    for i, n in enumerate([62, 58, 57, 53, 50]):
        place(x, epiano(midi(n), 2.5, 0.26), i * 0.3)
    place(x, pad([midi(n) for n in [38, 45, 50, 53]], 3.4, 0.15, 0.5, 2.0), 0.2)
    return reverb(x, 0.5)


def sfx_glitch():
    """Glitch: notas graves que tartamudean / Glitch: stuttering low notes."""
    x = np.zeros(int(SR * 0.35))
    for i in range(6):
        if RNG.random() < 0.75:
            place(x, mallet(midi(RNG.choice([43, 46, 50, 53])), 0.06, 0.35), i * 0.05)
    return x


def sfx_ricochet():
    return mix(glide(300, 200, 0.18, 0.5), thump(120, 0.15, 0.4))


def sfx_kick():
    return mix(thump(100, 0.35, 0.9, 7), puff(0.15, 700, 0.5))


def sfx_astral():
    x = np.zeros(int(SR * 2.4))
    for i, n in enumerate([50, 54, 57, 62, 66, 69]):
        place(x, epiano(midi(n), 1.8, 0.22), i * 0.1)
    place(x, puff(2.0, 600, 0.35), 0)
    return reverb(x, 0.55, 1.6)


def sfx_crack():
    """Algo se resquebraja en la habitación / Something cracks in the room."""
    x = np.zeros(int(SR * 1.0))
    for i in range(5):
        place(x, thump(RNG.uniform(70, 130), 0.2, 0.5, 12), i * RNG.uniform(0.04, 0.09))
    return reverb(mix(x, puff(0.6, 300, 0.4)), 0.35)


def sfx_shoot():
    """Tirachinas: goma que suelta / Slingshot: rubber snapping."""
    return mix(glide(260, 120, 0.12, 0.5), puff(0.15, 800, 0.4))


def sfx_bone():
    """Huesos que caen / Bones clattering down."""
    x = np.zeros(int(SR * 0.7))
    for i in range(7):
        place(x, mallet(midi(RNG.choice([52, 55, 57, 59])), 0.12, 0.3), i * RNG.uniform(0.04, 0.08))
    return reverb(x, 0.25)


def sfx_revive():
    return reverb(mix(glide(110, 260, 0.9, 0.5), puff(0.9, 400, 0.4)), 0.4)


def sfx_stomp():
    """Aplastón de la cama / The bed's stomp."""
    return reverb(mix(thump(48, 0.9, 1.0, 3.0), puff(0.6, 300, 0.7)), 0.35, 1.4)


def sfx_boss_wake():
    x = np.zeros(int(SR * 2.5))
    place(x, glide(70, 140, 2.0, 0.6), 0)
    for i in range(4):
        place(x, thump(60, 0.5, 0.6, 5), 0.3 + i * 0.45)
    return reverb(x, 0.45, 1.5)


def sfx_throw():
    return mix(puff(0.3, 700, 0.6), glide(200, 150, 0.25, 0.25))


def sfx_act_clear():
    x = np.zeros(int(SR * 5.0))
    for i, n in enumerate([50, 54, 57, 62, 66, 69, 74]):
        place(x, epiano(midi(n), 3.0, 0.26), i * 0.18)
    place(x, pad([midi(n) for n in [38, 50, 54, 57, 62]], 4.8, 0.18, 0.6, 2.5), 0)
    return reverb(x, 0.5, 1.5)


if __name__ == "__main__":
    save("music_menu", menu_theme(), 0.55)
    save("music_dream1", dream_theme(), 0.55)
    save("music_astral", astral_theme(), 0.55)
    save("music_boss", boss_theme(), 0.55)
    for name, fn, peak in [
        ("ui_hover", sfx_hover, 0.25), ("ui_click", sfx_click, 0.35), ("swing", sfx_swing, 0.45),
        ("pillow", sfx_pillow, 0.55), ("zap", sfx_zap, 0.45), ("vacuum", sfx_vacuum, 0.3),
        ("spawn", sfx_spawn, 0.35), ("hit", sfx_hit, 0.4), ("foox_die", sfx_foox_die, 0.4),
        ("hurt", sfx_hurt, 0.55), ("pickup", sfx_pickup, 0.45), ("chime", sfx_chime, 0.35),
        ("blanket", sfx_blanket, 0.35), ("yawn", sfx_yawn, 0.4), ("land", sfx_land, 0.5),
        ("win", sfx_win, 0.5), ("lose", sfx_lose, 0.5), ("glitch", sfx_glitch, 0.35),
        ("ricochet", sfx_ricochet, 0.4), ("kick", sfx_kick, 0.5), ("astral", sfx_astral, 0.45),
        ("crack", sfx_crack, 0.5), ("shoot", sfx_shoot, 0.4), ("bone", sfx_bone, 0.4),
        ("revive", sfx_revive, 0.45), ("stomp", sfx_stomp, 0.6), ("boss_wake", sfx_boss_wake, 0.55),
        ("throw", sfx_throw, 0.4), ("act_clear", sfx_act_clear, 0.5),
    ]:
        save(name, fn(), peak)
