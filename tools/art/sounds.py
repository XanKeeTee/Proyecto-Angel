"""Efectos de sonido PROVISIONALES sintetizados en Python puro (sin dependencias).

Uso: python -I tools/art/sounds.py   (escribe WAV en assets/audio/sfx/)

No sustituyen a un diseño de sonido real: sirven para que el prólogo tenga capa sonora
mientras tanto. Todos son mono, 22 050 Hz, 16 bits. Los *_loop están pensados para repetirse.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/sfx"
rng = random.Random(909)


# --- utilidades -----------------------------------------------------------------------------

def silence(seconds: float) -> list[float]:
    return [0.0] * int(SR * seconds)


def noise(seconds: float) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(int(SR * seconds))]


def sine(freq: float, seconds: float, phase: float = 0.0) -> list[float]:
    return [math.sin(phase + math.tau * freq * i / SR) for i in range(int(SR * seconds))]


def sweep(f0: float, f1: float, seconds: float, shape: str = "sine") -> list[float]:
    out, ph = [], 0.0
    n = int(SR * seconds)
    for i in range(n):
        f = f0 + (f1 - f0) * i / max(1, n - 1)
        ph += math.tau * f / SR
        if shape == "saw":
            out.append(((ph / math.tau) % 1.0) * 2 - 1)
        else:
            out.append(math.sin(ph))
    return out


def lowpass(x: list[float], cutoff: float) -> list[float]:
    a = 1 - math.exp(-math.tau * cutoff / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x: list[float], cutoff: float) -> list[float]:
    low = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, low)]


def bandpass(x: list[float], f: float, q: float = 4.0) -> list[float]:
    w = math.tau * f / SR
    alpha = math.sin(w) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for v in x:
        y = (b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, y
        out.append(y)
    return out


def env_decay(x: list[float], decay: float, attack: float = 0.002) -> list[float]:
    out = []
    for i, v in enumerate(x):
        t = i / SR
        a = min(1.0, t / attack) if attack > 0 else 1.0
        out.append(v * a * math.exp(-t / decay))
    return out


def env_shape(x: list[float], points: list[tuple[float, float]]) -> list[float]:
    """Envolvente por puntos (tiempo, ganancia), lineal entre ellos."""
    out = []
    for i, v in enumerate(x):
        t = i / SR
        g = points[-1][1]
        for (t0, g0), (t1, g1) in zip(points, points[1:]):
            if t0 <= t <= t1:
                g = g0 + (g1 - g0) * (t - t0) / max(1e-6, t1 - t0)
                break
        out.append(v * g)
    return out


def mix(*parts: tuple[list[float], float, float]) -> list[float]:
    """Mezcla (señal, ganancia, inicio en segundos)."""
    length = max(int(start * SR) + len(sig) for sig, _, start in parts)
    out = [0.0] * length
    for sig, gain, start in parts:
        o = int(start * SR)
        for i, v in enumerate(sig):
            out[o + i] += v * gain
    return out


def reverb(x: list[float], room: float = 0.6, tail: float = 1.2) -> list[float]:
    out = x + [0.0] * int(SR * tail)
    for delay, fb in ((0.0297, 0.7), (0.0371, 0.68), (0.0411, 0.66), (0.0437, 0.64)):
        d = int(SR * delay)
        buf = [0.0] * len(out)
        for i in range(len(out)):
            buf[i] = (out[i] if i < len(x) else 0.0) + (buf[i - d] * fb * room if i >= d else 0.0)
        out = [a + b * 0.25 for a, b in zip(out, buf)]
    return out


def normalize(x: list[float], peak: float = 0.85) -> list[float]:
    m = max(1e-6, max(abs(v) for v in x))
    return [v / m * peak for v in x]


def loopable(x: list[float], fade: float = 0.5) -> list[float]:
    n = int(SR * fade)
    body = x[:-n]
    for i in range(n):
        t = i / n
        body[i] = body[i] * t + x[len(x) - n + i] * (1 - t)
    return body


def save(name: str, x: list[float], peak: float = 0.85) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = normalize(x, peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data))
    print("  ", f"{name}.wav", f"{len(x) / SR:.2f}s")


# --- sonidos --------------------------------------------------------------------------------

def footstep(i: int) -> list[float]:
    thump = env_decay(lowpass(noise(0.12), 380 + i * 30), 0.025)
    slap = env_decay(bandpass(noise(0.05), 1800 + i * 200, 2.0), 0.008)
    return mix((thump, 1.0, 0.0), (slap, 0.35, 0.004))


def creak(seconds: float, f0: float, f1: float) -> list[float]:
    base = sweep(f0, f1, seconds, "saw")
    trem = [0.6 + 0.4 * math.sin(math.tau * 23 * i / SR + math.sin(i / 900)) for i in range(len(base))]
    s = [a * b for a, b in zip(base, trem)]
    s = bandpass(s, (f0 + f1) * 1.4, 2.5)
    return env_shape(s, [(0, 0), (0.08, 1), (seconds - 0.2, 0.8), (seconds, 0)])


def click(freq: float = 2600.0, decay: float = 0.006) -> list[float]:
    return env_decay(bandpass(noise(0.04), freq, 6.0), decay)


def thud(freq: float = 70.0, decay: float = 0.18) -> list[float]:
    return env_decay(mix((sine(freq, 0.6), 1.0, 0.0), (lowpass(noise(0.6), 300), 0.6, 0.0)), decay)


def build() -> None:
    print("Generando sonidos provisionales:")
    for i in range(4):
        save(f"step_{i + 1}", footstep(i), 0.5)
    save("door_open", mix((click(1800), 0.8, 0.0), (creak(1.1, 160, 240), 0.7, 0.05)), 0.7)
    save("door_close", mix((thud(65, 0.15), 1.0, 0.0), (click(2200), 0.5, 0.02)), 0.75)
    save("door_locked", mix(*[(click(2400 + rng.uniform(-400, 400), 0.01), 1.0, t) for t in (0.0, 0.09, 0.2, 0.27, 0.41)],
                            (thud(110, 0.05), 0.4, 0.0)), 0.7)
    save("unlock", mix((click(2000, 0.01), 1.0, 0.0), (click(1500, 0.015), 1.0, 0.18), (thud(140, 0.04), 0.4, 0.18)), 0.7)
    slide = env_shape(bandpass(noise(0.45), 900, 1.5), [(0, 0), (0.05, 1), (0.35, 0.7), (0.45, 0)])
    save("drawer_open", mix((slide, 1.0, 0.0), (thud(120, 0.04), 0.5, 0.4)), 0.6)
    save("drawer_close", mix((slide[::-1], 1.0, 0.0), (thud(100, 0.06), 0.9, 0.42)), 0.6)
    metal = mix(*[(env_decay(sine(f, 1.5), d), g, 0.0) for f, d, g in ((523, 0.4, 0.5), (787, 0.3, 0.4), (1233, 0.2, 0.3), (1911, 0.1, 0.2))])
    save("locker_open", mix((creak(0.6, 300, 420), 0.6, 0.0), (metal, 0.6, 0.55), (thud(90, 0.08), 0.6, 0.55)), 0.7)
    paper = mix(*[(env_decay(highpass(noise(0.03), 2500), 0.01), rng.uniform(0.4, 1.0), rng.uniform(0, 0.4)) for _ in range(18)])
    save("paper", paper, 0.5)
    save("pickup", env_shape(bandpass(noise(0.3), 1400, 1.2), [(0, 0), (0.05, 1), (0.3, 0)]), 0.5)
    save("flashlight_click", mix((click(3200, 0.004), 1.0, 0.0), (click(2400, 0.005), 0.7, 0.03)), 0.6)
    save("battery", mix((click(2800, 0.006), 1.0, 0.0), (click(2600, 0.006), 1.0, 0.25), (thud(200, 0.03), 0.4, 0.25)), 0.6)
    motor = [math.sin(math.tau * 118 * i / SR) * 0.5 + rng.uniform(-0.2, 0.2) for i in range(int(SR * 1.2))]
    save("tape_save", mix((click(2000), 1.0, 0.0), (env_shape(lowpass(motor, 900), [(0, 0), (0.1, 1), (1.1, 1), (1.2, 0)]), 0.6, 0.05),
                          (click(1700), 1.0, 1.25)), 0.6)
    chirps = mix(*[(env_shape(bandpass(sweep(f, f * 1.3, 0.18, "saw"), f * 1.8, 5.0), [(0, 0), (0.03, 1), (0.18, 0)]), 1.0, t)
                   for t, f in ((0.0, 520), (0.32, 610), (0.55, 480), (0.9, 640), (1.2, 560))])
    save("bed_creak", reverb(chirps, 0.4, 0.5), 0.6)
    steps = mix(*[(lowpass(footstep(i % 4), 500), 1.0, 0.6 * i) for i in range(6)])
    save("steps_far", reverb(steps, 0.7, 1.5), 0.45)
    save("knock", reverb(mix(*[(thud(140, 0.05), 1.0, t) for t in (0.0, 0.32, 0.6)]), 0.6, 1.0), 0.6)
    breath = noise(2.2)
    syll = [abs(math.sin(math.tau * 2.6 * i / SR)) ** 3 * (0.5 + 0.5 * math.sin(i / 3000)) for i in range(len(breath))]
    save("whisper", reverb(bandpass([a * b for a, b in zip(breath, syll)], 2200, 1.0), 0.5, 0.8), 0.35)
    save("metal_bang", reverb(mix((metal, 1.0, 0.0), (thud(60, 0.1), 0.8, 0.0)), 0.7, 2.0), 0.6)
    save("drip", reverb(env_decay(sweep(900, 2100, 0.06), 0.03), 0.6, 0.8), 0.4)
    hum = [sum(math.sin(math.tau * 50 * k * i / SR) / k for k in (1, 2, 3, 5)) + rng.uniform(-0.05, 0.05)
           for i in range(int(SR * 4.5))]
    save("hum_loop", loopable(lowpass(hum, 600)), 0.4)
    drone = [0.5 * math.sin(math.tau * 41 * i / SR) + 0.35 * math.sin(math.tau * 55.3 * i / SR)
             + 0.25 * math.sin(math.tau * 61.7 * i / SR + math.sin(i / 20000)) for i in range(int(SR * 12.5))]
    wind = lowpass(noise(12.5), 180)
    wind = [w * (0.6 + 0.4 * math.sin(math.tau * 0.08 * i / SR)) for i, w in enumerate(wind)]
    save("ambience_loop", loopable(mix((drone, 0.7, 0.0), (wind, 1.6, 0.0))), 0.5)
    ring = [math.sin(math.tau * 425 * i / SR) * (0.5 + 0.5 * math.sin(math.tau * 20 * i / SR)) for i in range(int(SR * 1.2))]
    ring = env_shape(mix((ring, 1.0, 0.0), ([v * 0.4 for v in sine(1100, 1.2)], 0.3, 0.0)), [(0, 0), (0.02, 1), (1.15, 1), (1.2, 0)])
    save("phone_ring", mix((ring, 1.0, 0.0), (ring, 1.0, 2.2)), 0.6)
    static = bandpass(noise(3.0), 1800, 0.7)
    breathing = [b * (0.5 + 0.5 * math.sin(math.tau * 0.35 * i / SR)) for i, b in enumerate(lowpass(noise(3.0), 500))]
    save("phone_static", mix((static, 0.5, 0.0), (breathing, 1.2, 0.0)), 0.5)
    save("breaker", mix((thud(80, 0.12), 1.0, 0.0), (click(1500, 0.02), 0.8, 0.0), (metal, 0.25, 0.0)), 0.8)
    crank = [math.sin(math.tau * 32 * i / SR) * (0.5 + 0.5 * math.sin(math.tau * (6 + 10 * i / (SR * 3)) * i / SR))
             for i in range(int(SR * 3.5))]
    engine = [sum(math.sin(math.tau * f * i / SR) / (j + 1) for j, f in enumerate((30, 60, 90, 120))) for i in range(int(SR * 2.0))]
    save("generator_start", mix((lowpass(crank, 400), 1.0, 0.0), (env_shape(engine, [(0, 0), (0.6, 1), (2.0, 1)]), 0.8, 3.0)), 0.75)
    save("generator_loop", loopable(lowpass([e + rng.uniform(-0.1, 0.1) for e in engine * 3], 500)), 0.55)
    chime = mix(*[(env_decay(mix((sine(f, 1.4), 1.0, 0.0), (sine(f * 2.01, 1.4), 0.3, 0.0)), 0.6), 1.0, t)
                  for t, f in ((0.0, 659), (0.45, 523), (0.9, 392))])
    save("pa_chime", reverb(chime, 0.7, 1.5), 0.6)
    save("pa_static", reverb(mix((bandpass(noise(4.0), 1500, 0.8), 0.6, 0.0),
                                 (env_shape(bandpass(noise(4.0), 700, 3.0), [(0, 0), (0.3, 1), (3.6, 1), (4.0, 0)]), 0.8, 0.0)), 0.6, 1.0), 0.5)
    save("monitor_beep", env_shape(sine(1000, 0.12), [(0, 0), (0.005, 1), (0.1, 1), (0.12, 0)]), 0.35)
    save("heavy_drag", env_shape(lowpass(noise(1.6), 260), [(0, 0), (0.2, 1), (1.3, 0.8), (1.6, 0)]), 0.6)
    save("glass", mix(*[(env_decay(sine(rng.uniform(3000, 6000), 0.3), 0.05), rng.uniform(0.3, 1.0), rng.uniform(0, 0.25))
                        for _ in range(10)]), 0.4)
    save("bandage", env_shape(highpass(noise(0.5), 1500), [(0, 0), (0.02, 1), (0.45, 0.6), (0.5, 0)]), 0.45)
    save("pills", mix(*[(env_decay(bandpass(noise(0.03), 3500, 5), 0.01), rng.uniform(0.4, 1.0), rng.uniform(0, 0.35))
                        for _ in range(14)]), 0.45)
    ping = env_decay(sine(2400, 0.4), 0.08)
    buzz = env_shape([math.sin(math.tau * 100 * i / SR) for i in range(int(SR * 1.2))], [(0, 0), (0.1, 1), (0.2, 0.2), (0.35, 1), (1.2, 0.6)])
    save("fluorescent_on", mix((ping, 0.6, 0.0), (lowpass(buzz, 900), 0.7, 0.05)), 0.5)


if __name__ == "__main__":
    build()
