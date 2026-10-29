"""Genera la música y los efectos de Dreamed por síntesis (sin muestras externas).
Generates Dreamed's music and sound effects by synthesis (no external samples).

Uso / Usage:  python3 tools/make_audio.py
Escribe los .wav (efectos) y .ogg (música) en assets/audio/. Necesita numpy, scipy y ffmpeg.
Writes .wav (effects) and .ogg (music) to assets/audio/. Needs numpy, scipy and ffmpeg.

Para que no suene "enlatado" se usan instrumentos de modelado físico en vez de ondas
puras: una cuerda pulsada (arpa), barras de kalimba y marimba que resuenan al golpearlas
y pads de dientes de sierra con coro. Cada voz va en estéreo con su propia posición, las
notas llevan pequeñas variaciones de tiempo y fuerza, como si las tocara alguien, y todo
pasa por una reverberación de sala por convolución.
To avoid a "canned" sound it uses physically modelled instruments instead of pure waves:
a plucked string (harp), kalimba and marimba bars that ring when struck, and chorused
sawtooth pads. Every voice is stereo with its own position, notes vary slightly in timing
and strength as if someone played them, and everything goes through a convolution room reverb.
"""
import shutil
import subprocess
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, lfilter, sosfilt

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RNG = np.random.default_rng(23)


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def noise(dur: float) -> np.ndarray:
    return RNG.normal(0, 1, int(dur * SR))


def lp(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos"), x, axis=0)


def hp(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, cutoff, "high", fs=SR, output="sos"), x, axis=0)


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos"), x, axis=0)


def env_ar(n: int, attack: float, release: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.clip((dur - t) / max(release, 1e-4), 0, 1)


# --- Instrumentos de modelado físico / Physically modelled instruments -------

def pluck(freq: float, dur: float = 3.0, amp: float = 0.4, bright: float = 0.5, damp: float = 0.996) -> np.ndarray:
    """Cuerda pulsada (Karplus-Strong): arpa suave / Plucked string (Karplus-Strong): soft harp.
    bright: 0 = muy apagada, 1 = brillante. damp: cuánto tarda en apagarse."""
    n = int(dur * SR)
    # Se calcula un poco más agudo y se reajusta para afinar exacto / Rendered slightly sharp, then resampled to exact pitch
    period = SR / freq - 0.5
    N = int(np.floor(period))
    exc = RNG.uniform(-1, 1, N)
    exc = lp(exc, 600 + 5000 * bright)
    # Posición de pulsación: quita armónicos como un dedo real / Pluck position: removes harmonics like a real finger
    k = max(1, int(N * 0.18))
    exc = exc - np.roll(exc, k) * 0.6
    x = np.zeros(n + N + 2)
    x[:N] = exc
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -damp * 0.5
    a[N + 1] = -damp * 0.5
    y = lfilter([1.0], a, x)
    ratio = period / N
    idx = np.arange(n) / ratio
    y = np.interp(idx, np.arange(len(y)), y)
    y = hp(y, 40)
    return y / (np.max(np.abs(y)) or 1) * amp * env_ar(n, 0.001, 0.05)


def bar(freq: float, dur: float = 2.0, amp: float = 0.4, kind: str = "kalimba", hardness: float = 0.5) -> np.ndarray:
    """Barra que resuena al golpearla (síntesis modal) / A bar that rings when struck (modal synthesis).
    kind: "kalimba" (lengüeta metálica suave), "marimba" (madera) o "wood" (golpe seco)."""
    modes = {
        "kalimba": [(1.0, 1.0, 1.8), (5.4, 0.12, 0.35), (12.6, 0.03, 0.12)],
        "marimba": [(1.0, 1.0, 0.9), (3.93, 0.25, 0.25), (9.24, 0.06, 0.08)],
        "wood": [(1.0, 1.0, 0.12), (2.57, 0.5, 0.06), (4.21, 0.3, 0.04), (6.1, 0.15, 0.03)],
    }[kind]
    n = int(dur * SR)
    # Golpe del mazo: un pulso corto, más corto cuanto más duro / Mallet strike: a short pulse, shorter when harder
    plen = max(8, int(SR * (0.004 - 0.003 * hardness)))
    exc = np.zeros(n)
    exc[:plen] = np.hanning(plen * 2)[plen:][::-1] * np.hanning(plen * 2)[:plen]
    exc[:plen] += RNG.normal(0, 0.05, plen)
    out = np.zeros(n)
    for ratio, gain, t60 in modes:
        f = freq * ratio
        if f > SR * 0.4:
            continue
        r = np.exp(-6.91 / (t60 * SR))
        w = 2 * np.pi * f / SR
        out += gain * lfilter([1 - r], [1, -2 * r * np.cos(w), r * r], exc)
    return out / (np.max(np.abs(out)) or 1) * amp


def saw_pad(freqs: list[float], dur: float, amp: float = 0.1, attack: float = 1.5, release: float = 2.0,
            cutoff: float = 1600.0) -> np.ndarray:
    """Pad de dientes de sierra con coro, en estéreo / Chorused sawtooth pad, stereo."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for f in freqs:
        kmax = int(min(40, 6000 / f))
        for ch, det in ((0, -0.004), (1, 0.0045)):
            for d2 in (0.0, 0.0017):
                ph = RNG.uniform(0, 2 * np.pi)
                vib = 1 + 0.0015 * np.sin(2 * np.pi * (0.3 + RNG.uniform(0, 0.3)) * t + ph)
                phase = 2 * np.pi * f * (1 + det + d2) * np.cumsum(vib) / SR
                wave = np.zeros(n)
                for k in range(1, kmax + 1):
                    wave += np.sin(k * phase) / k
                out[:, ch] += wave
    out = lp(out, cutoff, 4)
    out *= env_ar(n, attack, release)[:, None] * (1 + 0.08 * np.sin(2 * np.pi * 0.11 * t))[:, None]
    return out / (len(freqs) * 2.5) * amp


def breath(dur: float, lo: float, hi: float, amp: float = 0.5) -> np.ndarray:
    """Aire filtrado: soplos, telas, viento / Filtered air: puffs, cloth, wind."""
    return bp(noise(dur), lo, hi, 2) * amp


def sweep_noise(dur: float, f0: float, f1: float, q: float = 2.0, amp: float = 0.6) -> np.ndarray:
    """Ruido con un filtro que se desliza (zumbidos de aire) / Noise through a sliding filter (air swooshes)."""
    n = int(dur * SR)
    x = noise(dur)
    out = np.zeros(n)
    block = 256
    zi = None
    for i in range(0, n, block):
        f = f0 * (f1 / f0) ** (i / n)
        bw = f / q
        sos = butter(1, [max(30, f - bw / 2), min(SR * 0.45, f + bw / 2)], "band", fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = sosfilt(sos, x[i:i + block], zi=zi)
    return out * np.sin(np.pi * np.arange(n) / n) ** 1.5 * amp * 3


def thump(freq: float = 80.0, dur: float = 0.4, amp: float = 0.8, drop: float = 6.0) -> np.ndarray:
    """Golpe grave, como una tela pesada o un bombo de fieltro / Low thump, like heavy cloth or a felt drum."""
    t = t_axis(dur)
    f = freq * (1 + 1.2 * np.exp(-t * drop * 3))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * drop)
    click = lp(noise(dur), 1500) * np.exp(-t * 60) * 0.3
    return (body + click) * np.clip(t / 0.002, 0, 1) * amp


def vowel(dur: float, f_start: float, f_end: float, amp: float = 0.4) -> np.ndarray:
    """Un 'aaah' soplado con formantes, para bostezos y gemidos / A breathy formant 'aaah' for yawns and groans."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = f_start + (f_end - f_start) * t / dur
    src = np.zeros(n)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    for k in range(1, 30):
        src += np.sin(k * phase) / k
    src = src * 0.5 + noise(dur) * 0.4
    out = bp(src, 600, 1000) * 1.0 + bp(src, 1100, 1500) * 0.5 + bp(src, 2300, 2900) * 0.15
    return out * np.sin(np.pi * t / dur) ** 1.3 * amp


# --- Mezcla en estéreo / Stereo mixing ----------------------------------------

_IR_CACHE: dict = {}


def _impulse(size: float, seed: int) -> np.ndarray:
    """Respuesta de una sala: reflexiones tempranas y una cola que se oscurece.
    A room's response: early reflections and a tail that darkens."""
    key = (size, seed)
    if key not in _IR_CACHE:
        rng = np.random.default_rng(seed)
        dur = 2.0 * size
        t = t_axis(dur)
        ir = np.zeros_like(t)
        for _ in range(18):
            d = rng.uniform(0.005, 0.08) * size
            ir[int(d * SR)] += rng.uniform(0.15, 0.45) * rng.choice([-1, 1]) * np.exp(-d * 20)
        tail = rng.normal(0, 1, len(t)) * np.exp(-t * 3.6 / size)
        k = np.clip(t / dur, 0, 1)
        tail = lp(tail, 5000) * (1 - k) + lp(tail, 1800) * k
        ir += tail * 0.09
        ir = np.concatenate([np.zeros(int(0.012 * SR)), ir])
        _IR_CACHE[key] = ir / np.sqrt(np.sum(ir ** 2))
    return _IR_CACHE[key]


def stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """Coloca un sonido mono a la izquierda (-1) o la derecha (+1) / Places a mono sound left (-1) or right (+1)."""
    if x.ndim == 2:
        return x
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1) * 1.414


def reverb(x: np.ndarray, mix: float = 0.3, size: float = 1.0, tail: bool = True) -> np.ndarray:
    x = stereo(x)
    n = len(x) + (int(1.2 * size * SR) if tail else 0)
    out = np.zeros((n, 2))
    out[: len(x)] += x * (1 - mix * 0.6)
    for ch, seed in ((0, 3), (1, 7)):
        wet = fftconvolve(x[:, ch], _impulse(size, seed))[:n]
        out[: len(wet), ch] += wet * mix
    if tail:
        k = int(0.3 * size * SR)
        out[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
    return out


def mix(*sigs: np.ndarray) -> np.ndarray:
    n = max(len(x) for x in sigs)
    out = np.zeros((n, 2))
    for x in sigs:
        out[: len(x)] += stereo(x)
    return out


def place(buf: np.ndarray, sig: np.ndarray, at: float, pan: float = 0.0, human: bool = True) -> None:
    """Pone un sonido en el compás. human: pequeñas variaciones como un músico / Small human variations."""
    if human:
        at += RNG.normal(0, 0.008)
        sig = sig * RNG.uniform(0.85, 1.05)
    sig = stereo(sig, pan)
    i = max(0, int(at * SR))
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def save(name: str, x: np.ndarray, peak: float = 0.6, room: float = 0.18, size: float = 0.6) -> None:
    if room > 0:
        x = reverb(x, room, size)
    x = stereo(x)
    x = hp(x, 35)
    # Saturación muy suave para que el sonido "pegue" / Very gentle saturation to glue the sound
    m = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / m * 1.2) / np.tanh(1.2)
    fade = min(len(x) // 4, int(SR * 0.006))
    x[:fade] *= np.linspace(0, 1, fade)[:, None]
    if not name.startswith("music") and name != "vacuum":
        x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    wav = OUT / f"{name}.wav"
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    if name.startswith("music") and shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "7",
            str(OUT / f"{name}.ogg")], check=True)
        wav.unlink()
        print(f"{name}.ogg  {len(x) / SR:.1f}s")
    else:
        print(f"{name}.wav  {len(x) / SR:.1f}s")


def loop_render(build, length: float, reverb_mix: float, size: float = 1.4) -> np.ndarray:
    """Dibuja dos vueltas y se queda con la segunda para que el bucle empalme.
    Renders two passes and keeps the second, so the loop joins seamlessly."""
    buf = np.zeros((int(length * 2 * SR) + SR * 6, 2))
    build(buf, 0.0)
    build(buf, length)
    wet = reverb(buf, reverb_mix, size, tail=False)
    n = int(length * SR)
    return wet[n: 2 * n].copy()


# --- Música / Music ----------------------------------------------------------

def _arp(buf, chord, start, beat, beats, amp=0.12, pan_spread=0.6):
    """Arpegio de arpa que sube y baja / Harp arpeggio going up and down."""
    order = chord + chord[-2:0:-1]
    for b in range(int(beats * 2)):
        n = order[b % len(order)]
        pan = -pan_spread + 2 * pan_spread * ((b % len(order)) / max(1, len(order) - 1))
        place(buf, pluck(midi(n), 2.5, amp, 0.35), start + b * beat / 2, pan)


def menu_theme() -> np.ndarray:
    """Nana de arpa y kalimba en Re mayor / Harp and kalimba lullaby in D major."""
    beat = 60.0 / 66
    bar_len = beat * 4
    chords = [[50, 57, 62, 66], [47, 54, 59, 62], [43, 50, 55, 59], [45, 52, 57, 61]]
    melody = [(0, 0, 74, 2), (0, 2, 73, 1), (0, 3, 71, 1), (1, 0, 69, 3), (2, 0, 71, 2), (2, 2, 74, 2),
              (3, 0, 73, 4), (4, 0, 78, 2), (4, 2, 76, 1), (4, 3, 74, 1), (5, 0, 71, 3), (6, 0, 69, 2),
              (6, 2, 71, 1), (6, 3, 73, 1), (7, 0, 74, 4)]
    bars = 8

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 2.0, 0.09, 1.2, 2.0, 1300), s, human=False)
            place(buf, pluck(midi(ch[0] - 12), 4.0, 0.3, 0.2, 0.998), s)
            _arp(buf, ch, s, beat, 4, 0.07)
        for bi, b, n, _ in melody:
            place(buf, bar(midi(n), 2.5, 0.22, "kalimba", 0.3), off + bi * bar_len + b * beat, 0.15)

    return loop_render(build, bar_len * bars, 0.35)


def dream_theme() -> np.ndarray:
    """Más lenta y un poco rara: marimba, arpa y un acorde que se tuerce / Slower and a little strange."""
    beat = 60.0 / 58
    bar_len = beat * 4
    chords = [[50, 57, 62, 64], [47, 54, 59, 62], [46, 53, 58, 62], [45, 52, 57, 61]]
    melody = [(0, 0, 69, 3), (0, 3, 67, 1), (1, 0, 66, 4), (2, 0, 65, 2), (2, 2, 62, 2), (3, 0, 64, 4),
              (4, 0, 69, 2), (4, 2, 71, 2), (5, 0, 67, 4), (6, 0, 65, 3), (6, 3, 62, 1), (7, 0, 61, 4)]
    bars = 8

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 2.4, 0.1, 2.0, 2.4, 1100), s, human=False)
            place(buf, pluck(midi(ch[0] - 12), 4.0, 0.3, 0.15, 0.998), s)
            for b, idx in ((0.5, 1), (1.5, 2), (2.5, 3), (3.5, 2)):
                place(buf, bar(midi(ch[idx] + 12), 1.6, 0.07, "marimba", 0.3), s + b * beat, -0.4 + 0.25 * idx)
        for bi, b, n, _ in melody:
            place(buf, pluck(midi(n), 3.0, 0.2, 0.45), off + bi * bar_len + b * beat, 0.1)

    return loop_render(build, bar_len * bars, 0.45, 1.6)


def astral_theme() -> np.ndarray:
    """Acordes suspendidos que flotan, con kalimba lejana / Floating suspended chords with a distant kalimba."""
    beat = 60.0 / 52
    bar_len = beat * 4
    chords = [[43, 55, 62, 67, 69], [40, 52, 59, 64, 66], [36, 48, 55, 62, 64], [38, 50, 57, 62, 64]]
    bars = 8

    def build(buf, off):
        for i in range(bars):
            ch = chords[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar_len + 3.0, 0.11, 2.5, 3.0, 1200), s, human=False)
            place(buf, pluck(midi(ch[0]), 4.0, 0.22, 0.15, 0.998), s)
            for b, idx in ((1.0, 3), (2.5, 4), (3.25, 2)):
                place(buf, bar(midi(ch[idx] + 12), 2.5, 0.09, "kalimba", 0.2), s + b * beat, RNG.uniform(-0.6, 0.6))

    return loop_render(build, bar_len * bars, 0.55, 1.8)


def boss_theme() -> np.ndarray:
    """Jefe: pulso grave de tambor de fieltro y marimba inquieta / Boss: low felt-drum pulse and uneasy marimba."""
    beat = 60.0 / 96
    bar_len = beat * 4
    roots = [38, 38, 34, 36]
    bars = 8

    def build(buf, off):
        for i in range(bars):
            r = roots[i % 4]
            s = off + i * bar_len
            place(buf, saw_pad([midi(r + 12), midi(r + 15), midi(r + 19)], bar_len + 1.2, 0.1, 0.5, 1.2, 900), s, human=False)
            for b in range(4):
                place(buf, thump(52, 0.6, 0.45, 5.0), s + b * beat)
                place(buf, pluck(midi(r - 12 + 12), beat * 1.2, 0.22, 0.25, 0.99), s + b * beat)
            for b in (0.5, 1.5, 2.75, 3.5):
                place(buf, bar(midi(r + 24 + (3 if (i + int(b)) % 2 else 0)), 0.9, 0.11, "marimba", 0.5), s + b * beat,
                      -0.5 if b < 2 else 0.5)
        for k, n in enumerate([62, 61, 58, 57, 62, 65, 64, 61]):
            place(buf, pluck(midi(n), 3.0, 0.15, 0.4), off + k * bar_len + beat * 0.5, 0.2)

    return loop_render(build, bar_len * bars, 0.3)


# --- Efectos / Sound effects -------------------------------------------------

def sfx_hover():
    return bar(midi(69), 0.6, 0.35, "kalimba", 0.2)


def sfx_click():
    return mix(bar(midi(69), 0.7, 0.4, "kalimba", 0.4), np.pad(bar(midi(76), 0.7, 0.3, "kalimba", 0.4), (int(SR * 0.05), 0)))


def sfx_swing():
    return lp(sweep_noise(0.26, 350, 1300, 1.8, 0.5), 4500)


def sfx_pillow():
    return mix(thump(70, 0.4, 0.8, 9), breath(0.25, 200, 900, 1.2) * env_ar(int(0.25 * SR), 0.005, 0.2))


def sfx_zap():
    """Magia del libro: arpa rápida hacia arriba y un soplo / Book magic: quick upward harp and a breeze."""
    x = np.zeros((int(SR * 1.2), 2))
    for i, n in enumerate([62, 66, 69, 74]):
        place(x, pluck(midi(n), 1.0, 0.25, 0.5), i * 0.035, -0.3 + i * 0.2, human=False)
    return mix(x, sweep_noise(0.45, 300, 1200, 2.0, 0.25))


def sfx_vacuum():
    """Zumbido de motor y aire, en bucle de 2 s / Motor and air hum, 2 s loop."""
    dur = 2.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = np.zeros(n)
    for k, g in ((1, 0.3), (2, 0.15), (3, 0.08), (5, 0.03)):
        base += g * np.sin(2 * np.pi * 110 * k * t)
    air = bp(noise(dur + 0.2), 250, 1400)[: n] * 0.9
    x = base + air
    # Fundido cruzado del final con el principio para que el bucle no haga clic / Crossfade so the loop doesn't click
    k = int(0.1 * SR)
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return stereo(x[:-k])


def sfx_spawn():
    """Un fantasma que aparece: un acorde al revés que crece / A ghost appearing: a reversed swelling chord."""
    x = mix(*[pluck(midi(n), 1.2, 0.3, 0.3) for n in (55, 62, 67)])
    return mix(x[::-1] * 0.6, sweep_noise(1.0, 200, 700, 2.0, 0.2))


def sfx_hit():
    return bar(RNG.uniform(260, 320), 0.3, 0.6, "wood", 0.7)


def sfx_foox_die():
    x = np.zeros((int(SR * 1.6), 2))
    for i, n in enumerate([74, 69, 66, 62]):
        place(x, pluck(midi(n), 1.2, 0.25, 0.4), i * 0.07, 0.3 - i * 0.2, human=False)
    return mix(x, sweep_noise(0.7, 900, 300, 2.0, 0.2))


def sfx_hurt():
    return mix(thump(90, 0.35, 0.7, 10), vowel(0.3, 260, 200, 0.35))


def sfx_pickup():
    x = np.zeros((int(SR * 2.0), 2))
    for i, n in enumerate([62, 66, 69, 74, 78]):
        place(x, pluck(midi(n), 1.6, 0.28, 0.5), i * 0.07, -0.5 + i * 0.25, human=False)
    return x


def sfx_chime():
    return mix(bar(midi(74), 1.2, 0.35, "kalimba", 0.3), np.pad(bar(midi(81), 1.2, 0.25, "kalimba", 0.3), (int(SR * 0.08), 0)))


def sfx_blanket():
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    rustle = breath(0.8, 700, 3000, 0.6)
    gate = np.clip(np.convolve(RNG.random(n) > 0.9993, np.hanning(900), "same"), 0, 1) * 0.7 + 0.3
    return rustle * gate * np.sin(np.pi * t / 0.8)


def sfx_yawn():
    return vowel(1.3, 230, 150, 0.6)


def sfx_land():
    return mix(thump(60, 0.35, 0.9, 10), bar(180, 0.25, 0.25, "wood", 0.4))


def sfx_win():
    x = np.zeros((int(SR * 4.0), 2))
    for i, n in enumerate([62, 66, 69, 73, 74, 78, 81]):
        place(x, pluck(midi(n), 2.8, 0.26, 0.5), i * 0.12, -0.6 + i * 0.2, human=False)
    place(x, saw_pad([midi(n) for n in (50, 57, 62, 66)], 3.8, 0.12, 0.3, 2.0, 1500), 0, human=False)
    return x


def sfx_lose():
    x = np.zeros((int(SR * 4.0), 2))
    for i, n in enumerate([74, 70, 69, 65, 62]):
        place(x, pluck(midi(n), 2.8, 0.25, 0.35), i * 0.28, 0.5 - i * 0.25, human=False)
    place(x, saw_pad([midi(n) for n in (50, 53, 57, 62)], 3.8, 0.11, 0.5, 2.2, 900), 0.1, human=False)
    return x


def sfx_glitch():
    """Una nota de kalimba que tartamudea / A stuttering kalimba note."""
    note = bar(midi(RNG.choice([62, 65, 69])), 0.5, 0.4, "kalimba", 0.6)
    x = np.zeros(int(SR * 0.4))
    seg = int(SR * 0.035)
    for i in range(0, len(x) - seg, seg):
        if RNG.random() < 0.7:
            j = RNG.integers(0, seg * 3)
            x[i:i + seg] = note[j:j + seg] * np.hanning(seg)
    return x


def sfx_ricochet():
    return mix(bar(RNG.uniform(380, 450), 0.3, 0.5, "wood", 0.8), pluck(110, 0.4, 0.2, 0.3, 0.98))


def sfx_kick():
    return mix(thump(85, 0.35, 0.9, 9), breath(0.08, 600, 2500, 0.8) * env_ar(int(0.08 * SR), 0.001, 0.07))


def sfx_astral():
    x = np.zeros((int(SR * 3.0), 2))
    for i, n in enumerate([62, 66, 69, 74, 78, 81, 86]):
        place(x, pluck(midi(n), 2.2, 0.22, 0.45), i * 0.08, -0.6 + i * 0.2, human=False)
    return mix(x, sweep_noise(2.0, 200, 1500, 2.0, 0.22))


def sfx_crack():
    """La habitación se resquebraja: chasquidos de madera y un crujido / The room cracks: wood snaps and a creak."""
    x = np.zeros((int(SR * 1.3), 2))
    at = 0.0
    for i in range(6):
        place(x, bar(RNG.uniform(500, 900), 0.15, 0.4, "wood", 1.0), at, RNG.uniform(-0.5, 0.5), human=False)
        at += RNG.uniform(0.03, 0.12)
    creak = vowel(0.9, 70, 55, 0.3)
    return mix(x, np.pad(creak, (int(SR * 0.2), 0)), thump(55, 0.5, 0.5, 6))


def sfx_shoot():
    """Goma del tirachinas / Slingshot rubber."""
    return mix(pluck(150, 0.35, 0.5, 0.2, 0.97), lp(sweep_noise(0.15, 450, 1200, 1.8, 0.3), 4000))


def sfx_bone():
    x = np.zeros((int(SR * 0.8), 2))
    at = 0.0
    for i in range(7):
        place(x, bar(RNG.uniform(600, 1100), 0.2, 0.35, "wood", 0.9), at, RNG.uniform(-0.6, 0.6), human=False)
        at += RNG.uniform(0.03, 0.08)
    return x


def sfx_revive():
    x = mix(*[pluck(midi(n), 1.4, 0.3, 0.3) for n in (43, 50, 55)])
    return mix(x[::-1] * 0.7, vowel(1.0, 90, 120, 0.35))


def sfx_stomp():
    rumble = lp(noise(1.2), 160, 4) * np.exp(-np.arange(int(1.2 * SR)) / SR * 3) * 2.5
    return mix(thump(45, 1.0, 1.0, 3.5), rumble, bar(120, 0.4, 0.4, "wood", 0.6))


def sfx_boss_wake():
    x = np.zeros((int(SR * 3.0), 2))
    place(x, vowel(2.4, 60, 90, 0.5), 0, human=False)
    for i in range(4):
        place(x, thump(55, 0.6, 0.6, 5), 0.3 + i * 0.45, human=False)
        place(x, bar(RNG.uniform(140, 220), 0.4, 0.3, "wood", 0.5), 0.35 + i * 0.45, RNG.uniform(-0.5, 0.5), human=False)
    return x


def sfx_throw():
    return lp(sweep_noise(0.32, 280, 1000, 1.8, 0.5), 4500)


def sfx_act_clear():
    x = np.zeros((int(SR * 5.5), 2))
    for i, n in enumerate([62, 66, 69, 74, 78, 81, 86]):
        place(x, pluck(midi(n), 3.5, 0.26, 0.5), i * 0.16, -0.6 + i * 0.2, human=False)
    for i, n in enumerate([74, 78, 81]):
        place(x, bar(midi(n), 2.5, 0.18, "kalimba", 0.3), 1.4 + i * 0.3, 0.3, human=False)
    place(x, saw_pad([midi(n) for n in (38, 50, 57, 62, 66)], 5.2, 0.13, 0.6, 2.5, 1400), 0, human=False)
    return x


# --- Personajes del plano astral: un tema corto para cada uno ------------------------
# --- Astral plane characters: a short motif for each one ------------------------------

def giver_svinho():
    # Samba alegre: cuerda pulsada sincopada y un golpe de bombo / Cheerful samba: syncopated pluck and a kick
    x = np.zeros((int(SR * 2.4), 2))
    for i, (n, at) in enumerate([(67, 0.0), (71, 0.15), (74, 0.3), (71, 0.52), (76, 0.67), (74, 0.9)]):
        place(x, pluck(midi(n), 1.4, 0.3, 0.6), at, -0.4 + i * 0.16)
    for at in (0.0, 0.52):
        place(x, thump(70, 0.3, 0.35, 8), at, 0.0, human=False)
    return x


def giver_stolk():
    # Grave y chulesco: marimba baja y un golpe sordo / Low and cocky: deep marimba and a dull thud
    x = np.zeros((int(SR * 2.4), 2))
    for i, (n, at) in enumerate([(43, 0.0), (43, 0.25), (46, 0.5), (41, 0.85)]):
        place(x, bar(midi(n), 1.6, 0.42, "marimba", 0.5), at, -0.2 + i * 0.12)
    place(x, thump(55, 0.5, 0.5, 5), 0.85, 0.0, human=False)
    return x


def giver_silly():
    # Pitidos glitch de ordenador con un eco que tartamudea / Glitchy computer bleeps with a stuttering echo
    x = np.zeros((int(SR * 2.0), 2))
    for i, n in enumerate([67, 74, 71, 79, 76]):
        at = i * 0.09 + (0.04 if i % 2 else 0.0)
        place(x, bar(midi(n), 0.35, 0.22, "kalimba", 0.8), at, -0.7 + i * 0.35, human=False)
        place(x, bar(midi(n + 12), 0.2, 0.08, "kalimba", 0.9), at + 0.5, 0.7 - i * 0.35, human=False)
    return mix(x, lp(sweep_noise(0.4, 2000, 600, 3.0, 0.15), 4500))


def giver_doc():
    # Tranquilo, como un estetoscopio: kalimba suave y un pad cálido / Calm, like a stethoscope: soft kalimba and a warm pad
    x = np.zeros((int(SR * 2.8), 2))
    for i, n in enumerate([72, 76, 79, 84]):
        place(x, bar(midi(n), 1.8, 0.22, "kalimba", 0.3), i * 0.22, -0.3 + i * 0.2)
    place(x, saw_pad([midi(n) for n in (48, 55, 60, 64)], 2.6, 0.08, 0.4, 1.4, 1200), 0.0, human=False)
    return x


if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:])   # p. ej. "giver_svinho giver_doc" para rehacer solo esos / e.g. to remake only those
    if not only:
        save("music_menu", menu_theme(), 0.55, room=0)
        save("music_dream1", dream_theme(), 0.55, room=0)
        save("music_astral", astral_theme(), 0.55, room=0)
        save("music_boss", boss_theme(), 0.55, room=0)
    for name, fn, peak, room in [
        ("ui_hover", sfx_hover, 0.25, 0.12), ("ui_click", sfx_click, 0.35, 0.12), ("swing", sfx_swing, 0.45, 0.1),
        ("pillow", sfx_pillow, 0.55, 0.12), ("zap", sfx_zap, 0.45, 0.25), ("vacuum", sfx_vacuum, 0.3, 0.0),
        ("spawn", sfx_spawn, 0.35, 0.3), ("hit", sfx_hit, 0.4, 0.1), ("foox_die", sfx_foox_die, 0.4, 0.3),
        ("hurt", sfx_hurt, 0.55, 0.12), ("pickup", sfx_pickup, 0.45, 0.3), ("chime", sfx_chime, 0.35, 0.25),
        ("blanket", sfx_blanket, 0.35, 0.1), ("yawn", sfx_yawn, 0.4, 0.2), ("land", sfx_land, 0.5, 0.15),
        ("win", sfx_win, 0.5, 0.35), ("lose", sfx_lose, 0.5, 0.35), ("glitch", sfx_glitch, 0.35, 0.1),
        ("ricochet", sfx_ricochet, 0.4, 0.15), ("kick", sfx_kick, 0.5, 0.12), ("astral", sfx_astral, 0.45, 0.4),
        ("crack", sfx_crack, 0.5, 0.25), ("shoot", sfx_shoot, 0.4, 0.12), ("bone", sfx_bone, 0.4, 0.15),
        ("revive", sfx_revive, 0.45, 0.3), ("stomp", sfx_stomp, 0.6, 0.25), ("boss_wake", sfx_boss_wake, 0.55, 0.35),
        ("throw", sfx_throw, 0.4, 0.1), ("act_clear", sfx_act_clear, 0.5, 0.4),
        ("giver_svinho", giver_svinho, 0.45, 0.3), ("giver_stolk", giver_stolk, 0.5, 0.3),
        ("giver_silly", giver_silly, 0.35, 0.25), ("giver_doc", giver_doc, 0.4, 0.35),
    ]:
        if not only or name in only:
            save(name, fn(), peak, room)
