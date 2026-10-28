"""Genera la música y los efectos de Dreamed por síntesis (sin muestras externas).
Generates Dreamed's music and sound effects by synthesis (no external samples).

Uso / Usage:  python3 tools/make_audio.py
Escribe los .wav en assets/audio/. Necesita numpy y scipy.
Writes the .wav files to assets/audio/. Needs numpy and scipy.

Estilo: cajita de música, campanitas de celesta y pads suaves con mucha reverberación.
Style: music box, celesta-like chimes and soft pads with plenty of reverb.
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RNG = np.random.default_rng(7)


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


# --- Instrumentos / Instruments ----------------------------------------------

def music_box(freq: float, dur: float = 2.5, amp: float = 0.3, wobble: float = 0.0) -> np.ndarray:
    """Nota de cajita de música: parciales inarmónicos que se apagan rápido.
    Music box note: inharmonic partials that decay quickly."""
    t = t_axis(dur)
    vib = 1.0 + wobble * np.sin(2 * np.pi * 4.5 * t) * np.minimum(1.0, t * 2)
    out = np.zeros_like(t)
    for ratio, gain, decay in [(1.0, 1.0, 2.2), (2.0, 0.28, 3.5), (3.98, 0.12, 6.0), (5.43, 0.07, 9.0), (8.1, 0.03, 14.0)]:
        out += gain * np.sin(2 * np.pi * freq * ratio * np.cumsum(vib) / SR) * np.exp(-decay * t)
    attack = np.minimum(1.0, t / 0.004)
    click = RNG.normal(0, 1, len(t)) * np.exp(-t * 900) * 0.05
    return (out * attack + click) * amp


def bell(freq: float, dur: float = 1.5, amp: float = 0.3) -> np.ndarray:
    t = t_axis(dur)
    out = (np.sin(2 * np.pi * freq * t) * np.exp(-3 * t)
           + 0.4 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-5 * t)
           + 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-8 * t))
    return out * np.minimum(1.0, t / 0.003) * amp


def pad(freqs: list[float], dur: float, amp: float = 0.08, attack: float = 1.2, release: float = 1.6) -> np.ndarray:
    """Acorde suave y ancho con voces ligeramente desafinadas / Soft, wide chord with slightly detuned voices."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.0018, 0.0, 0.0021):
            ph = RNG.uniform(0, 2 * np.pi)
            out += np.sin(2 * np.pi * f * (1 + det) * t + ph)
            out += 0.25 * np.sin(2 * np.pi * f * 2 * (1 + det) * t + ph)
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (dur - t) / release).clip(0, 1)
    trem = 1.0 + 0.12 * np.sin(2 * np.pi * 0.23 * t)
    return out * env * trem * amp / len(freqs)


def soft_bass(freq: float, dur: float, amp: float = 0.18) -> np.ndarray:
    t = t_axis(dur)
    env = np.minimum(1.0, t / 0.08) * np.exp(-1.2 * t)
    return (np.sin(2 * np.pi * freq * t) + 0.2 * np.sin(2 * np.pi * freq * 2 * t)) * env * amp


def noise(dur: float) -> np.ndarray:
    return RNG.normal(0, 1, int(dur * SR))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def reverb(x: np.ndarray, mix: float = 0.35, size: float = 1.0) -> np.ndarray:
    """Reverberación Schroeder sencilla / Simple Schroeder reverb."""
    combs = [0.0297, 0.0371, 0.0411, 0.0437, 0.0503, 0.0571]
    wet = np.zeros_like(x)
    for i, d in enumerate(combs):
        n = int(d * size * SR)
        a = np.zeros(n + 1)
        a[0] = 1.0
        a[n] = -0.86
        wet += lfilter([1.0], a, lowpass(x, 5500) if i % 2 else x)
    wet /= len(combs)
    for d, g in [(0.005, 0.7), (0.0017, 0.7)]:
        n = int(d * SR)
        b = np.zeros(n + 1)
        a = np.zeros(n + 1)
        b[0], b[n] = -g, 1.0
        a[0], a[n] = 1.0, -g
        wet = lfilter(b, a, wet)
    return x * (1 - mix) + wet * mix


def place(buf: np.ndarray, sig: np.ndarray, at: float) -> None:
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def save(name: str, x: np.ndarray, peak: float = 0.7) -> None:
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{name}.wav  {len(x) / SR:.1f}s")


def loop_render(build, length: float, reverb_mix: float, size: float = 1.3) -> np.ndarray:
    """Dibuja dos vueltas y se queda con la segunda para que el bucle empalme sin cortes.
    Renders two passes and keeps the second, so the loop joins seamlessly."""
    buf = np.zeros(int(length * 2 * SR) + SR * 4)
    build(buf, 0.0)
    build(buf, length)
    wet = reverb(buf, reverb_mix, size)
    n = int(length * SR)
    return wet[n: 2 * n]


# --- Música / Music ----------------------------------------------------------

# Re mayor. Acordes en notas MIDI / D major. Chords as MIDI notes.
CHORDS_MENU = [
    [50, 57, 61, 64, 66],   # Dmaj7(9)
    [47, 54, 57, 62, 66],   # Bm7
    [43, 50, 54, 59, 62],   # Gmaj7
    [45, 52, 57, 59, 64],   # Asus2
    [42, 50, 54, 57, 61],   # D/F#
    [40, 47, 54, 57, 62],   # Em9
    [43, 50, 54, 59, 66],   # Gmaj7
    [45, 52, 57, 61, 64],   # A
]

# Melodía de nana en 3/4: (compás, tiempo, nota, duración en tiempos)
# Lullaby melody in 3/4: (bar, beat, note, length in beats)
MELODY_MENU = [
    (0, 0, 74, 2), (0, 2, 76, 1), (1, 0, 78, 2), (1, 2, 76, 1),
    (2, 0, 74, 3), (3, 0, 71, 2), (3, 2, 73, 1),
    (4, 0, 74, 2), (4, 2, 78, 1), (5, 0, 81, 2), (5, 2, 79, 1),
    (6, 0, 78, 3), (7, 0, 76, 3),
    (8, 0, 78, 2), (8, 2, 79, 1), (9, 0, 81, 2), (9, 2, 78, 1),
    (10, 0, 74, 3), (11, 0, 76, 2), (11, 2, 71, 1),
    (12, 0, 73, 2), (12, 2, 74, 1), (13, 0, 76, 2), (13, 2, 74, 1),
    (14, 0, 71, 3), (15, 0, 69, 2), (15, 2, 73, 1),
]


def menu_theme() -> np.ndarray:
    bpm = 66.0
    beat = 60.0 / bpm
    bar = beat * 3
    bars = 16
    length = bar * bars

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars // 2):
            chord = CHORDS_MENU[i % len(CHORDS_MENU)]
            start = off + i * 2 * bar
            place(buf, pad([midi(n) for n in chord[1:]], 2 * bar + 1.4, 0.10), start)
            place(buf, soft_bass(midi(chord[0] - 12 + 12), 2 * bar, 0.16), start)
            # Arpegio de campanitas, muy suave / Very soft chime arpeggio
            for b in range(6):
                n = chord[1 + (b % 4)] + 12
                place(buf, music_box(midi(n), 1.8, 0.05), start + b * beat)
        for bar_i, b, n, length_beats in MELODY_MENU:
            place(buf, music_box(midi(n), 3.0, 0.32), off + bar_i * bar + b * beat)

    return loop_render(build, length, 0.42)


CHORDS_DREAM = [
    [50, 57, 62, 64, 68],   # D lidio (sol#) / D lydian (G#)
    [47, 54, 59, 62, 66],   # Bm(add11)
    [43, 50, 55, 59, 62],   # G
    [46, 53, 58, 62, 65],   # Bb (un giro extraño) / Bb (an odd turn)
]

MELODY_DREAM = [
    (0, 0, 81, 3), (0, 3, 80, 1), (1, 0, 76, 4), (2, 2, 74, 2),
    (3, 0, 77, 4), (4, 0, 81, 2), (4, 2, 83, 2), (5, 0, 80, 4),
    (6, 0, 78, 2), (6, 2, 74, 2), (7, 0, 77, 3), (7, 3, 74, 1),
]


def dream_theme() -> np.ndarray:
    """Más lenta y un poco más rara: notas que tiemblan y un giro armónico inesperado.
    Slower and a little stranger: wavering notes and an unexpected harmonic turn."""
    bpm = 58.0
    beat = 60.0 / bpm
    bar = beat * 4
    bars = 8
    length = bar * bars

    def build(buf: np.ndarray, off: float) -> None:
        for i in range(bars // 2):
            chord = CHORDS_DREAM[i % len(CHORDS_DREAM)]
            start = off + i * 2 * bar
            place(buf, pad([midi(n) for n in chord[1:]], 2 * bar + 1.6, 0.11, attack=1.8), start)
            place(buf, soft_bass(midi(chord[0]), 2 * bar, 0.14), start)
            for b in range(8):
                if b % 2 == 0:
                    n = chord[1 + (b // 2) % 4] + 24
                    place(buf, bell(midi(n), 1.6, 0.035), start + b * beat + 0.5 * beat)
        for bar_i, b, n, _ in MELODY_DREAM:
            place(buf, music_box(midi(n), 3.4, 0.26, wobble=0.004), off + bar_i * bar + b * beat)
        # Destellos aleatorios en lo alto / Random sparkles up high
        for k in range(14):
            at = off + RNG.uniform(0, length)
            place(buf, bell(midi(RNG.choice([86, 88, 90, 93])), 1.2, 0.02), at)

    return loop_render(build, length, 0.5, 1.5)


# --- Efectos / Sound effects -------------------------------------------------

def sfx_hover() -> np.ndarray:
    return reverb(np.pad(bell(midi(88), 0.4, 0.25), (0, SR // 4)), 0.3)


def sfx_click() -> np.ndarray:
    x = np.zeros(int(SR * 1.0))
    place(x, music_box(midi(81), 0.8, 0.4), 0.0)
    place(x, music_box(midi(88), 0.8, 0.35), 0.07)
    return reverb(x, 0.35)


def sfx_whoosh(dur: float = 0.32, lo: float = 400, hi: float = 2400) -> np.ndarray:
    t = t_axis(dur)
    n = noise(dur)
    # Barrido de filtro hacia arriba / Rising filter sweep
    out = np.zeros_like(n)
    y = 0.0
    for i in range(len(n)):
        fc = lo + (hi - lo) * (i / len(n))
        a = np.exp(-2 * np.pi * fc / SR)
        y = (1 - a) * n[i] + a * y
        out[i] = y
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return highpass(out, 200) * env


def sfx_swing() -> np.ndarray:
    return reverb(np.pad(lowpass(sfx_whoosh(0.28, 400, 2200), 3000), (0, SR // 4)), 0.2)


def sfx_pillow() -> np.ndarray:
    t = t_axis(0.45)
    thump = np.sin(2 * np.pi * (110 * np.exp(-t * 6)) * t) * np.exp(-t * 14) * 0.9
    puff = lowpass(noise(0.45), 900) * np.exp(-t * 9) * 2.0
    return reverb(thump + puff, 0.25)


def sfx_zap() -> np.ndarray:
    dur = 0.5
    t = t_axis(dur)
    x = np.zeros_like(t)
    for _ in range(14):
        at = RNG.uniform(0, 0.25)
        place(x, bell(RNG.uniform(1800, 4200), 0.2, 0.25), at)
    crackle = lowpass(highpass(noise(dur), 2500), 6000) * (RNG.random(len(t)) > 0.97) * np.exp(-t * 7) * 0.5
    rise = np.sin(2 * np.pi * (600 + 1400 * t) * t) * np.exp(-t * 6) * 0.25
    return reverb(x + crackle + rise, 0.35)


def sfx_vacuum() -> np.ndarray:
    """Zumbido suave en bucle / Soft looping hum (1 s, wraps cleanly)."""
    dur = 1.0
    t = t_axis(dur)
    hum = (np.sin(2 * np.pi * 120 * t) * 0.3 + np.sin(2 * np.pi * 240 * t) * 0.12
           + np.sin(2 * np.pi * 361 * t) * 0.05)
    air = lowpass(lowpass(np.tile(noise(0.25), 4)[: len(t)], 700), 700) * 3.0
    wob = 1.0 + 0.2 * np.sin(2 * np.pi * 3 * t)
    return (hum + air) * wob


def sfx_spawn() -> np.ndarray:
    dur = 1.1
    t = t_axis(dur)
    f = 330 + 260 * t / dur
    tone = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.02 * np.sin(2 * np.pi * 6 * t))) / SR)
    env = np.sin(np.pi * t / dur) ** 2
    air = lowpass(noise(dur), 1200) * env * 0.6
    return reverb(tone * env * 0.5 + air, 0.5, 1.4)


def sfx_hit() -> np.ndarray:
    return reverb(np.pad(music_box(midi(76 + RNG.integers(0, 3)), 0.35, 0.5), (0, SR // 5)), 0.2)


def sfx_foox_die() -> np.ndarray:
    x = np.zeros(int(SR * 1.4))
    for i, n in enumerate([88, 85, 81, 76]):
        place(x, bell(midi(n), 0.9, 0.3), i * 0.07)
    return reverb(x, 0.45)


def sfx_hurt() -> np.ndarray:
    t = t_axis(0.5)
    f = 220 * np.exp(-t * 1.5)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    return reverb(lowpass(tone + 0.2 * noise(0.5) * np.exp(-t * 20), 1800), 0.3)


def sfx_pickup() -> np.ndarray:
    x = np.zeros(int(SR * 1.8))
    for i, n in enumerate([74, 78, 81, 86, 90]):
        place(x, music_box(midi(n), 1.2, 0.35), i * 0.08)
    return reverb(x, 0.45)


def sfx_chime() -> np.ndarray:
    x = np.zeros(int(SR * 1.4))
    place(x, bell(midi(86), 1.0, 0.3), 0)
    place(x, bell(midi(93), 1.0, 0.2), 0.06)
    return reverb(x, 0.45)


def sfx_blanket() -> np.ndarray:
    t = t_axis(0.7)
    rustle = lowpass(noise(0.7), 2500) * (np.sin(np.pi * t / 0.7) ** 2)
    rustle *= 1.0 + 0.6 * np.sin(2 * np.pi * 9 * t)
    return reverb(rustle * 0.5, 0.2)


def sfx_yawn() -> np.ndarray:
    """Un 'bostezo' tonal suave, no una voz / A soft tonal 'yawn', not a voice."""
    dur = 1.3
    t = t_axis(dur)
    f = 300 + 120 * np.sin(np.pi * t / dur) - 80 * t / dur
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    env = np.sin(np.pi * t / dur) ** 1.5
    breath = lowpass(noise(dur), 900) * env * 0.5
    return reverb(lowpass(tone * env * 0.4, 1600) + breath, 0.35)


def sfx_land() -> np.ndarray:
    t = t_axis(0.35)
    return reverb(np.sin(2 * np.pi * (140 * np.exp(-t * 8)) * t) * np.exp(-t * 18) + lowpass(noise(0.35), 600) * np.exp(-t * 25), 0.2)


def sfx_win() -> np.ndarray:
    x = np.zeros(int(SR * 4.0))
    for i, n in enumerate([62, 66, 69, 73, 76, 78, 81, 85]):
        place(x, music_box(midi(n), 2.5, 0.35), i * 0.16)
    place(x, pad([midi(n) for n in [62, 66, 69, 73]], 3.6, 0.15, 0.4, 1.8), 0.0)
    return reverb(x, 0.5, 1.4)


def sfx_lose() -> np.ndarray:
    x = np.zeros(int(SR * 4.0))
    for i, n in enumerate([81, 77, 74, 72, 69, 65]):
        place(x, music_box(midi(n), 2.5, 0.3, wobble=0.006), i * 0.28)
    place(x, pad([midi(n) for n in [50, 57, 62, 65]], 3.6, 0.13, 0.5, 2.0), 0.2)
    return reverb(x, 0.55, 1.5)


if __name__ == "__main__":
    save("music_menu", menu_theme(), 0.6)
    save("music_dream1", dream_theme(), 0.6)
    for name, fn, peak in [
        ("ui_hover", sfx_hover, 0.25), ("ui_click", sfx_click, 0.45), ("swing", sfx_swing, 0.5),
        ("pillow", sfx_pillow, 0.6), ("zap", sfx_zap, 0.5), ("vacuum", sfx_vacuum, 0.35),
        ("spawn", sfx_spawn, 0.4), ("hit", sfx_hit, 0.35), ("foox_die", sfx_foox_die, 0.45),
        ("hurt", sfx_hurt, 0.6), ("pickup", sfx_pickup, 0.5), ("chime", sfx_chime, 0.4),
        ("blanket", sfx_blanket, 0.4), ("yawn", sfx_yawn, 0.4), ("land", sfx_land, 0.5),
        ("win", sfx_win, 0.6), ("lose", sfx_lose, 0.55),
    ]:
        save(name, fn(), peak)
