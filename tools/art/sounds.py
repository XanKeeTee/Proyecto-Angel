"""Efectos de sonido PROVISIONALES sintetizados en Python puro (sin dependencias).

Uso: python -I tools/art/sounds.py   (escribe WAV en assets/audio/sfx/)

Se sintetizan con modelos físicos sencillos en lugar de tonos puros, que suenan a juguete:
  - golpes y metal: ruido corto que excita un banco de resonadores (modos del objeto),
  - crujidos de puertas y camas: fricción a tirones (stick-slip) filtrada por resonancias,
  - motores: explosiones periódicas de ruido, no un tono,
  - ambiente: ruido grave de sala y un zumbido eléctrico muy bajo.
Siguen siendo provisionales: lo ideal es sustituirlos por grabaciones reales con el mismo nombre.
Mono, 22 050 Hz, 16 bits. Los *_loop están pensados para repetirse.
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

def n(seconds: float) -> int:
    return int(SR * seconds)


def silence(seconds: float) -> list[float]:
    return [0.0] * n(seconds)


def noise(seconds: float) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(n(seconds))]


def brown(seconds: float) -> list[float]:
    out, y = [], 0.0
    for _ in range(n(seconds)):
        y = (y + rng.uniform(-1, 1) * 0.08) * 0.995
        out.append(y)
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


def resonator(x: list[float], f: float, decay: float) -> list[float]:
    """Modo resonante: responde a la excitación y se apaga en `decay` segundos (aprox.)."""
    r = math.exp(-1.0 / (decay * SR))
    w = math.tau * f / SR
    a1, a2 = -2 * r * math.cos(w), r * r
    gain = (1 - r * r) * 0.5
    y1 = y2 = 0.0
    out = []
    for v in x:
        y = gain * v - a1 * y1 - a2 * y2
        y2, y1 = y1, y
        out.append(y)
    return out


def modes(x: list[float], partials: list[tuple[float, float, float]]) -> list[float]:
    """Banco de modos: (frecuencia, decaimiento, ganancia)."""
    total = [0.0] * len(x)
    for f, d, g in partials:
        for i, v in enumerate(resonator(x, f, d)):
            total[i] += v * g
    return total


def burst(seconds: float, decay: float) -> list[float]:
    return [rng.uniform(-1, 1) * math.exp(-(i / SR) / decay) for i in range(n(seconds))]


def pad(x: list[float], seconds: float) -> list[float]:
    return x + [0.0] * n(seconds)


def env(x: list[float], points: list[tuple[float, float]]) -> list[float]:
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
    length = max(n(start) + len(sig) for sig, _, start in parts)
    out = [0.0] * length
    for sig, gain, start in parts:
        o = n(start)
        for i, v in enumerate(sig):
            out[o + i] += v * gain
    return out


def room(x: list[float], size: float = 0.5, wet: float = 0.3, tail: float = 0.8) -> list[float]:
    """Reverberación de sala pequeña (peines en paralelo + filtro), discreta."""
    data = x + [0.0] * n(tail)
    acc = [0.0] * len(data)
    for delay, fb in ((0.0253, 0.74), (0.0291, 0.72), (0.0337, 0.70), (0.0389, 0.68)):
        d = int(SR * delay * (0.6 + size))
        buf = [0.0] * len(data)
        for i in range(len(data)):
            buf[i] = data[i] + (buf[i - d] * fb if i >= d else 0.0)
        for i in range(len(data)):
            acc[i] += buf[i]
    acc = lowpass(acc, 2500)
    return [a * (1 - wet) + b * wet * 0.25 for a, b in zip(data, acc)]


def friction(seconds: float, rate: float, jitter: float, partials: list[tuple[float, float, float]]) -> list[float]:
    """Crujido por fricción a tirones: impulsos irregulares que excitan resonancias."""
    x = [0.0] * n(seconds)
    t = 0.0
    while t < seconds:
        i = n(t)
        if i < len(x):
            x[i] += rng.uniform(0.5, 1.0) * (1 if rng.random() < 0.5 else -1)
        local = rate * (1 + jitter * math.sin(t * 7.3) + jitter * rng.uniform(-0.5, 0.5))
        t += 1.0 / max(5.0, local)
    return modes(x, partials)


def normalize(x: list[float], peak: float) -> list[float]:
    m = max(1e-6, max(abs(v) for v in x))
    return [v / m * peak for v in x]


def fade_edges(x: list[float], fade_in: float = 0.002, fade_out: float = 0.02) -> list[float]:
    a, b = n(fade_in), n(fade_out)
    out = list(x)
    for i in range(min(a, len(out))):
        out[i] *= i / max(1, a)
    for i in range(min(b, len(out))):
        out[-1 - i] *= i / max(1, b)
    return out


def loopable(x: list[float], fade: float = 0.6) -> list[float]:
    k = n(fade)
    body = x[:-k]
    for i in range(k):
        t = i / k
        body[i] = body[i] * t + x[len(x) - k + i] * (1 - t)
    return body


def save(name: str, x: list[float], peak: float) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = fade_edges(normalize(x, peak))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data))
    print("  ", f"{name}.wav", f"{len(x) / SR:.2f}s")


# --- piezas ----------------------------------------------------------------------------------

def metal_click(bright: float = 1.0) -> list[float]:
    return modes(burst(0.08, 0.0015), [(2100 * bright, 0.02, 1.0), (3650 * bright, 0.012, 0.6), (5300 * bright, 0.008, 0.4)])


def wood_knock() -> list[float]:
    return modes(burst(0.25, 0.003), [(185, 0.06, 1.0), (410, 0.04, 0.6), (870, 0.02, 0.35), (1500, 0.01, 0.2)])


def door_thud() -> list[float]:
    body = modes(burst(0.5, 0.006), [(78, 0.12, 1.0), (151, 0.09, 0.7), (290, 0.05, 0.4), (610, 0.02, 0.2)])
    return mix((body, 1.0, 0.0), (lowpass(burst(0.2, 0.03), 400), 0.3, 0.0))


def footstep(i: int) -> list[float]:
    # Planta del pie descalzo sobre baldosa: golpe sordo y un roce de piel.
    pat = lowpass(burst(0.09, 0.012 + i * 0.002), 520 + i * 40)
    skin = lowpass(highpass(burst(0.05, 0.006), 900), 3000)
    return mix((pat, 1.0, 0.0), (skin, 0.18, 0.008))


def bell_ring(seconds: float) -> list[float]:
    # Timbre antiguo: un martillo golpea dos campanas unas 20 veces por segundo.
    x = [0.0] * n(seconds)
    t, side = 0.0, 0
    while t < seconds:
        i = n(t)
        if i < len(x):
            x[i] += 1.0 if side == 0 else -0.9
        side ^= 1
        t += 1.0 / 21.0
    a = modes(x, [(1180, 0.25, 1.0), (2950, 0.12, 0.5), (4400, 0.06, 0.25)])
    b = modes(x, [(1330, 0.25, 1.0), (3300, 0.12, 0.45), (5100, 0.05, 0.2)])
    return [p + q for p, q in zip(a, b)]


def engine(seconds: float, rate: float, rough: float) -> list[float]:
    """Motor diésel: explosiones de ruido grave a `rate` por segundo."""
    x = [0.0] * n(seconds)
    t = 0.0
    while t < seconds:
        b = lowpass(burst(0.05, 0.012), 260)
        o = n(t)
        for j, v in enumerate(b):
            if o + j < len(x):
                x[o + j] += v * rng.uniform(0.7, 1.0)
        t += (1.0 / rate) * (1 + rng.uniform(-rough, rough))
    return mix((modes(x, [(55, 0.08, 1.0), (110, 0.05, 0.6), (220, 0.03, 0.3)]), 1.0, 0.0), (x, 0.6, 0.0))


# --- sonidos ----------------------------------------------------------------------------------

def build() -> None:
    print("Generando sonidos provisionales:")
    for i in range(4):
        save(f"step_{i + 1}", room(footstep(i), 0.3, 0.15, 0.25), 0.3)

    hinge = [(420, 0.03, 1.0), (930, 0.02, 0.7), (1750, 0.012, 0.4)]
    creak = env(friction(1.0, 70, 0.45, hinge), [(0, 0), (0.1, 1), (0.8, 0.7), (1.0, 0)])
    save("door_open", room(mix((metal_click(), 0.5, 0.0), (creak, 0.6, 0.06), (lowpass(noise(0.6), 250), 0.05, 0.1)), 0.5, 0.25), 0.5)
    save("door_close", room(mix((door_thud(), 1.0, 0.0), (metal_click(0.9), 0.4, 0.02)), 0.5, 0.3), 0.55)
    save("door_locked", room(mix(*[(metal_click(rng.uniform(0.8, 1.1)), rng.uniform(0.6, 1.0), t) for t in (0.0, 0.08, 0.21, 0.27, 0.42)],
                                 (door_thud(), 0.25, 0.0)), 0.4, 0.2), 0.5)
    save("unlock", room(mix((metal_click(1.1), 1.0, 0.0), (metal_click(0.8), 0.9, 0.17), (wood_knock(), 0.15, 0.17)), 0.4, 0.2), 0.45)
    rollers = [abs(math.sin(i / SR * math.tau * 23)) * 0.6 + 0.4 for i in range(n(0.45))]
    slide = [a * b for a, b in zip(lowpass(highpass(noise(0.45), 300), 1500), rollers)]
    slide = env(slide, [(0, 0), (0.05, 1), (0.35, 0.8), (0.45, 0)])
    save("drawer_open", room(mix((slide, 1.0, 0.0), (wood_knock(), 0.5, 0.42)), 0.3, 0.2), 0.4)
    save("drawer_close", room(mix((slide[::-1], 1.0, 0.0), (wood_knock(), 0.8, 0.43)), 0.3, 0.2), 0.4)
    # Chapa: muchos modos cortos y ruido, para que suene a golpe metálico y no a "boing".
    sheet = mix((modes(burst(0.6, 0.006), [(212, 0.06, 1.0), (347, 0.05, 0.8), (581, 0.04, 0.6), (933, 0.03, 0.5),
                                         (1377, 0.02, 0.4), (2050, 0.015, 0.3)]), 1.0, 0.0),
                (lowpass(burst(0.3, 0.02), 900), 0.25, 0.0))
    save("locker_open", room(mix((metal_click(), 0.6, 0.0), (env(friction(0.5, 110, 0.4, hinge), [(0, 0), (0.05, 1), (0.5, 0)]), 0.4, 0.05),
                                 (sheet, 0.5, 0.45)), 0.5, 0.3), 0.5)
    paper = mix(*[(highpass(burst(0.02, 0.003), 2000), rng.uniform(0.3, 1.0), rng.uniform(0, 0.45)) for _ in range(26)])
    save("paper", room(lowpass(paper, 6000), 0.3, 0.15), 0.3)
    cloth = [v * (0.5 + 0.5 * math.sin(i / SR * 30 + rng.random())) for i, v in enumerate(lowpass(highpass(noise(0.32), 400), 2500))]
    save("pickup", env(cloth, [(0, 0), (0.04, 1), (0.32, 0)]), 0.3)
    save("flashlight_click", mix((metal_click(1.4), 1.0, 0.0), (metal_click(1.2), 0.6, 0.035)), 0.35)
    save("battery", room(mix((metal_click(1.3), 1.0, 0.0), (metal_click(1.0), 1.0, 0.22)), 0.3, 0.15), 0.35)
    motor = [v * (0.7 + 0.3 * math.sin(i / SR * math.tau * 9)) for i, v in enumerate(lowpass(noise(1.2), 500))]
    save("tape_save", room(mix((metal_click(0.7), 1.0, 0.0), (env(motor, [(0, 0), (0.1, 1), (1.1, 1), (1.2, 0)]), 0.25, 0.05),
                               (metal_click(0.6), 1.0, 1.25)), 0.3, 0.2), 0.4)
    springs = [(310, 0.05, 1.0), (760, 0.03, 0.6), (1290, 0.02, 0.35), (2210, 0.01, 0.2)]
    creaks = mix(*[(env(friction(d, r, 0.5, springs), [(0, 0), (0.03, 1), (d - 0.05, 0.7), (d, 0)]), g, t)
                   for t, d, r, g in ((0.0, 0.35, 60, 1.0), (0.45, 0.25, 85, 0.7), (0.8, 0.4, 55, 0.9), (1.3, 0.2, 90, 0.5))])
    save("bed_creak", room(creaks, 0.5, 0.3, 0.6), 0.45)
    far = mix(*[(lowpass(footstep(i % 4), 380), rng.uniform(0.7, 1.0), 0.62 * i + rng.uniform(-0.03, 0.03)) for i in range(7)])
    save("steps_far", room(far, 0.9, 0.55, 1.6), 0.35)
    save("knock", room(mix((wood_knock(), 1.0, 0.0), (wood_knock(), 0.9, 0.31), (wood_knock(), 0.8, 0.58)), 0.7, 0.4, 1.0), 0.45)
    breath = noise(2.4)
    syllables = [max(0.0, math.sin(math.tau * 2.3 * i / SR)) ** 2 * (0.5 + 0.5 * math.sin(i / 4000)) for i in range(len(breath))]
    voiced = [a * b for a, b in zip(breath, syllables)]
    whisper = mix((modes(voiced, [(620, 0.004, 1.0), (1700, 0.003, 0.8), (2600, 0.002, 0.5)]), 1.0, 0.0), (lowpass(voiced, 3000), 0.3, 0.0))
    save("whisper", room(lowpass(whisper, 4000), 0.8, 0.5, 1.0), 0.25)
    clang = mix((modes(burst(1.5, 0.004), [(113, 0.45, 1.0), (167, 0.4, 0.8), (271, 0.35, 0.7), (389, 0.3, 0.6), (467, 0.25, 0.5),
                                         (633, 0.2, 0.45), (811, 0.15, 0.35), (1243, 0.1, 0.25), (1790, 0.07, 0.2)]), 1.0, 0.0),
                (lowpass(burst(0.6, 0.05), 500), 0.4, 0.0))
    save("metal_bang", room(lowpass(clang, 1800), 1.0, 0.6, 2.0), 0.45)
    drop = mix((modes(burst(0.05, 0.0008), [(1900, 0.012, 1.0), (2700, 0.008, 0.5)]), 1.0, 0.0), (lowpass(burst(0.03, 0.004), 2500), 0.2, 0.0))
    save("drip", room(drop, 0.7, 0.5, 0.9), 0.25)
    hum = [0.4 * math.sin(math.tau * 50 * i / SR) + 0.12 * math.sin(math.tau * 100 * i / SR) for i in range(n(4.6))]
    hum = mix((hum, 1.0, 0.0), (lowpass(noise(4.6), 900), 0.08, 0.0))
    save("hum_loop", loopable(lowpass(hum, 400)), 0.12)
    tone = lowpass(brown(12.6), 220)
    rumble = lowpass(noise(12.6), 60)
    air = lowpass(highpass(noise(12.6), 200), 700)
    air = [v * (0.4 + 0.6 * (0.5 + 0.5 * math.sin(math.tau * 0.07 * i / SR))) for i, v in enumerate(air)]
    save("ambience_loop", loopable(mix((tone, 1.0, 0.0), (rumble, 0.6, 0.0), (air, 0.08, 0.0))), 0.35)
    ring = env(bell_ring(1.6), [(0, 0), (0.01, 1), (1.5, 1), (1.6, 0.3)])
    save("phone_ring", room(mix((ring, 1.0, 0.0), (ring, 1.0, 3.6)), 0.4, 0.3, 1.0), 0.4)
    line = lowpass(highpass(noise(3.2), 300), 3400)
    crackle = [rng.uniform(-1, 1) if rng.random() < 0.004 else 0.0 for _ in range(n(3.2))]
    breathing = [v * (0.5 + 0.5 * math.sin(math.tau * 0.32 * i / SR)) ** 2 for i, v in enumerate(lowpass(highpass(noise(3.2), 300), 1200))]
    save("phone_static", mix((line, 0.25, 0.0), (crackle, 0.8, 0.0), (breathing, 0.9, 0.0)), 0.35)
    save("breaker", room(mix((door_thud(), 1.0, 0.0), (metal_click(0.6), 1.0, 0.0), (sheet, 0.2, 0.0)), 0.6, 0.35, 1.0), 0.55)
    starter = [v * (0.6 + 0.4 * math.sin(math.tau * 5.0 * i / SR)) for i, v in enumerate(lowpass(highpass(noise(3.0), 150), 700))]
    save("generator_start", room(mix((env(starter, [(0, 0), (0.2, 1), (2.8, 1), (3.0, 0)]), 0.5, 0.0), (engine(3.0, 5.5, 0.3), 0.7, 0.0),
                                     (engine(2.5, 24.0, 0.08), 0.9, 3.0)), 0.6, 0.3, 1.0), 0.5)
    save("generator_loop", loopable(engine(4.6, 24.0, 0.06)), 0.4)
    strike = burst(0.02, 0.0008)
    note = lambda f: modes(strike, [(f, 1.1, 1.0), (f * 2.0, 0.5, 0.25), (f * 3.9, 0.2, 0.1)])  # noqa: E731
    chime = mix((pad(note(659), 1.6), 1.0, 0.0), (pad(note(523), 1.6), 1.0, 0.55), (pad(note(392), 1.6), 1.0, 1.1))
    save("pa_chime", room(lowpass(chime, 3000), 1.0, 0.5, 1.6), 0.4)
    hiss = lowpass(highpass(noise(4.2), 400), 3000)
    pops = [rng.uniform(-1, 1) if rng.random() < 0.003 else 0.0 for _ in range(n(4.2))]
    save("pa_static", room(env(mix((hiss, 0.3, 0.0), (pops, 0.7, 0.0)), [(0, 0), (0.15, 1), (3.9, 1), (4.2, 0)]), 1.0, 0.5, 1.2), 0.3)
    beep = [math.sin(math.tau * 960 * i / SR) for i in range(n(0.09))]
    save("monitor_beep", lowpass(env(beep, [(0, 0), (0.008, 1), (0.08, 0.8), (0.09, 0)]), 2500), 0.1)
    scrape = env(friction(1.5, 45, 0.6, [(140, 0.05, 1.0), (330, 0.03, 0.6), (700, 0.015, 0.3)]), [(0, 0), (0.2, 1), (1.3, 0.8), (1.5, 0)])
    save("heavy_drag", room(mix((scrape, 1.0, 0.0), (lowpass(noise(1.5), 120), 0.3, 0.0)), 0.7, 0.4, 0.8), 0.45)
    shards = mix(*[(modes(burst(0.2, 0.0005), [(rng.uniform(3500, 7000), 0.03, 1.0), (rng.uniform(5000, 9000), 0.02, 0.5)]),
                    rng.uniform(0.3, 1.0), rng.uniform(0, 0.3)) for _ in range(12)])
    save("glass", room(shards, 0.4, 0.25), 0.3)
    rip = [v * (0.6 + 0.4 * rng.random()) for v in highpass(noise(0.45), 1200)]
    save("bandage", env(lowpass(rip, 5000), [(0, 0), (0.02, 1), (0.4, 0.6), (0.45, 0)]), 0.3)
    save("pills", room(mix(*[(modes(burst(0.04, 0.0006), [(rng.uniform(2500, 4500), 0.01, 1.0)]), rng.uniform(0.4, 1.0), rng.uniform(0, 0.35))
                             for _ in range(16)]), 0.3, 0.2), 0.3)
    buzz = [v * (1.0 if (i // n(0.03)) % 3 else 0.3) for i, v in enumerate(lowpass(highpass(noise(1.3), 80), 400))]
    hum100 = [0.5 * math.sin(math.tau * 100 * i / SR) for i in range(n(1.3))]
    save("fluorescent_on", room(mix((metal_click(1.2), 0.8, 0.0), (metal_click(1.0), 0.6, 0.12), (env(mix((buzz, 0.4, 0.0), (hum100, 0.5, 0.0)),
                                [(0, 0), (0.15, 0.3), (0.35, 1), (1.3, 0.7)]), 0.6, 0.1)), 0.5, 0.2), 0.3)


if __name__ == "__main__":
    build()
