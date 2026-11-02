"""Sonidos de Freesound para La Novena Vigilia.

Busca, elige, descarga y prepara (recorte, fundidos, volumen, bucles, cortes) cada sonido de
`tools/audio/sound_manifest.json` y lo deja en `assets/audio/sfx/<nombre>.wav`, con el mismo
nombre que ya usa el juego (`Sfx.at(...)`). Anota la autoría y la licencia de cada uno en
`tools/audio/credits.json` y en `docs/art/creditos-sonido.md`.

Solo se aceptan licencias que permiten uso comercial: CC0 y CC BY (con atribución).
Se descarga la vista previa de alta calidad (OGG ~192 kbps), que la API da con una clave normal
(la descarga del original exige OAuth2 y no hace falta para efectos de un juego pixelado).

Requisitos: Python 3 con numpy, ffmpeg y la variable de entorno FREESOUND_API_KEY
(clave gratuita: https://freesound.org/apiv2/apply).

Uso:
  python3 -I tools/audio/freesound.py search door_open        # candidatos para revisar
  python3 -I tools/audio/freesound.py fetch                   # todos los del manifiesto
  python3 -I tools/audio/freesound.py fetch door_open step    # solo esos (prefijos)
  python3 -I tools/audio/freesound.py fetch --dry-run         # qué haría, sin descargar
  python3 -I tools/audio/freesound.py credits                 # regenera el documento de créditos

En el manifiesto, `pick` fija el id elegido (reproducible); si falta, se elige automáticamente
el mejor candidato y se escribe en el manifiesto para la próxima vez.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/audio/sound_manifest.json"
CREDITS = ROOT / "tools/audio/credits.json"
CREDITS_DOC = ROOT / "docs/art/creditos-sonido.md"
OUT_DIR = ROOT / "assets/audio/sfx"
CACHE = ROOT / "tools/audio/.cache"
API = "https://freesound.org/apiv2"
SR = 44100
FIELDS = "id,name,username,license,duration,channels,previews,avg_rating,num_ratings,num_downloads,tags,url"
LICENSES_OK = ("publicdomain/zero", "licenses/by/")
LICENSE_FILTER = 'license:("Creative Commons 0" OR "Attribution")'


# --- API -----------------------------------------------------------------------------------------

def _key() -> str:
    key = os.environ.get("FREESOUND_API_KEY", "").strip()
    if not key:
        sys.exit("Falta FREESOUND_API_KEY (clave gratuita en https://freesound.org/apiv2/apply).")
    return key


def _get(url: str, params: dict | None = None, retries: int = 4) -> bytes:
    if params is not None:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    delay = 2.0
    for attempt in range(retries):
        req = urllib.request.Request(url, headers={"Authorization": "Token " + _key(),
                                                   "User-Agent": "LaNovenaVigilia-sfx/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            raise
        except urllib.error.URLError:
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            raise
    raise RuntimeError("sin respuesta: " + url)


def search(entry: dict, page_size: int = 30) -> list[dict]:
    """Candidatos para una entrada (todas sus consultas), ya filtrados por licencia y duración."""
    lo, hi = entry.get("duration", [0.0, 600.0])
    found: dict[int, dict] = {}
    for query in [entry["query"]] + entry.get("alt", []):
        params = {
            "query": query,
            "filter": f"{LICENSE_FILTER} duration:[{lo} TO {hi}]",
            "fields": FIELDS,
            "sort": "score",
            "page_size": page_size,
        }
        cache = CACHE / ("q_" + "".join(c if c.isalnum() else "_" for c in query + str(lo) + str(hi)) + ".json")
        if cache.exists():
            data = json.loads(cache.read_text(encoding="utf-8"))
        else:
            data = json.loads(_get(API + "/search/text/", params))
            CACHE.mkdir(parents=True, exist_ok=True)
            cache.write_text(json.dumps(data), encoding="utf-8")
        for rank, s in enumerate(data.get("results", [])):
            if not any(ok in s.get("license", "") for ok in LICENSES_OK):
                continue
            s["_rank"] = min(rank, found.get(s["id"], {}).get("_rank", 999))
            found[s["id"]] = s
    return sorted(found.values(), key=lambda s: -score(entry, s))


def score(entry: dict, s: dict) -> float:
    """Puntuación de un candidato: relevancia, valoraciones, descargas, etiquetas y duración."""
    tags = {t.lower() for t in s.get("tags", [])}
    name = s.get("name", "").lower()
    pts = 30.0 - s.get("_rank", 30)
    pts += (s.get("avg_rating") or 0.0) * min(s.get("num_ratings") or 0, 20) / 4.0
    pts += min(10.0, (s.get("num_downloads") or 0) ** 0.5 / 10.0)
    for t in entry.get("want", []):
        if t in tags or t in name:
            pts += 6.0
    for t in entry.get("avoid", []) + ["music", "song", "melody", "loop-music", "beat"]:
        if t in tags or t in name:
            pts -= 25.0
    lo, hi = entry.get("duration", [0.0, 600.0])
    ideal = entry.get("ideal", (lo + hi) / 2.0)
    pts -= abs(s.get("duration", ideal) - ideal) / max(0.5, hi - lo) * 6.0
    return pts


def preview_url(s: dict) -> str:
    p = s.get("previews", {})
    return p.get("preview-hq-ogg") or p.get("preview-hq-mp3") or p.get("preview-lq-ogg")


def sound_info(sound_id: int) -> dict:
    cache = CACHE / f"s_{sound_id}.json"
    if cache.exists():
        return json.loads(cache.read_text(encoding="utf-8"))
    data = json.loads(_get(f"{API}/sounds/{sound_id}/", {"fields": FIELDS}))
    CACHE.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(data), encoding="utf-8")
    return data


def download(s: dict) -> Path:
    url = preview_url(s)
    path = CACHE / f"a_{s['id']}{Path(urllib.parse.urlparse(url).path).suffix}"
    if not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_bytes(_get(url))
    return path


# --- audio ---------------------------------------------------------------------------------------

def decode(path: Path, channels: int) -> np.ndarray:
    """Audio en float32, forma (muestras, canales), a 44,1 kHz."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le",
                          "-ac", str(channels), "-ar", str(SR), "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-9))


def envelope(a: np.ndarray, win: float = 0.01) -> np.ndarray:
    mono = np.abs(a).max(axis=1)
    n = max(1, int(SR * win))
    pad = (-len(mono)) % n
    return np.pad(mono, (0, pad)).reshape(-1, n).max(axis=1)


def trim_silence(a: np.ndarray, threshold_db: float = -48.0) -> np.ndarray:
    env = envelope(a)
    peak = env.max() if len(env) else 0.0
    if peak <= 0:
        return a
    on = np.where(env > peak * 10 ** (threshold_db / 20.0))[0]
    if len(on) == 0:
        return a
    n = int(SR * 0.01)
    start = max(0, on[0] * n - int(SR * 0.005))
    end = min(len(a), (on[-1] + 1) * n + int(SR * 0.04))
    return a[start:end]


def fade(a: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    a = a.copy()
    fi, fo = min(len(a), int(SR * fade_in)), min(len(a), int(SR * fade_out))
    if fi > 0:
        a[:fi] *= np.linspace(0.0, 1.0, fi)[:, None]
    if fo > 0:
        a[-fo:] *= (np.linspace(1.0, 0.0, fo) ** 2)[:, None]
    return a


def loudness(a: np.ndarray, target_db: float) -> np.ndarray:
    """Ajusta el nivel RMS de la parte activa al objetivo (dBFS) y limita los picos a -1 dBFS."""
    env = envelope(a, 0.05)
    active = env[env > env.max() * 0.1] if len(env) else env
    rms = float(np.sqrt(np.mean(np.square(a)))) if len(active) == 0 else float(np.sqrt(np.mean(np.square(active)))) * 0.7
    gain = 10 ** ((target_db - db(rms)) / 20.0)
    a = a * gain
    peak = float(np.abs(a).max()) if len(a) else 0.0
    ceiling = 10 ** (-1.0 / 20.0)
    if peak > ceiling:
        a = np.tanh(a / ceiling * 0.9) * ceiling / np.tanh(0.9)  # limitador suave
    return a


def make_loop(a: np.ndarray, crossfade: float) -> np.ndarray:
    """Bucle sin costura: el final se funde con el principio."""
    n = min(int(SR * crossfade), len(a) // 3)
    if n <= 0:
        return a
    head, body, tail = a[:n], a[n:-n], a[-n:]
    t = np.linspace(0.0, 1.0, n)[:, None]
    blend = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([body, blend])


def onsets(a: np.ndarray, count: int, min_gap: float) -> list[int]:
    """Los `count` golpes más claros (inicio en muestras), separados al menos `min_gap` s."""
    env = envelope(a, 0.005)
    rise = np.maximum(0.0, np.diff(env, prepend=0.0))
    order = np.argsort(-rise)
    picked: list[int] = []
    gap = int(min_gap / 0.005)
    for i in order:
        if rise[i] <= 0:
            break
        if all(abs(int(i) - p) >= gap for p in picked):
            picked.append(int(i))
        if len(picked) >= count:
            break
    return sorted(p * int(SR * 0.005) for p in picked)


def write_wav(path: Path, a: np.ndarray) -> None:
    pcm = (np.clip(a, -1.0, 1.0) * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(a.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def process(entry: dict, src: Path) -> dict[str, np.ndarray]:
    """Prepara el audio según el manifiesto. Devuelve nombre de archivo -> audio."""
    channels = 2 if entry.get("stereo") else 1
    a = decode(src, channels)
    if "start" in entry or "end" in entry:
        a = a[int(SR * entry.get("start", 0.0)):int(SR * entry["end"]) if "end" in entry else None]
    target = entry.get("level", -20.0)
    if entry.get("slices"):
        out: dict[str, np.ndarray] = {}
        names = entry["slices"]
        length = entry.get("slice_len", 0.35)
        for name, start in zip(names, onsets(a, len(names), entry.get("min_gap", 0.25))):
            piece = a[max(0, start - int(SR * 0.008)):start + int(SR * length)]
            piece = fade(trim_silence(piece), 0.002, min(0.08, length * 0.3))
            out[name] = loudness(piece, target)
        return out
    if entry.get("loop"):
        a = a[: int(SR * entry.get("max_len", 30.0))]
        a = loudness(make_loop(a, entry.get("crossfade", 1.5)), target)
        return {entry["name"]: a}
    if entry.get("trim", True):
        a = trim_silence(a)
    if "max_len" in entry and len(a) > SR * entry["max_len"]:
        a = a[: int(SR * entry["max_len"])]
    a = fade(a, entry.get("fade_in", 0.003), entry.get("fade_out", 0.05))
    if entry.get("pitch"):
        # Cambio de tono sencillo por remuestreo (también cambia la duración).
        factor = 2 ** (entry["pitch"] / 12.0)
        idx = np.arange(0, len(a) - 1, factor)
        a = np.stack([np.interp(idx, np.arange(len(a)), a[:, c]) for c in range(a.shape[1])], axis=1)
    return {entry["name"]: loudness(a, target)}


# --- manifiesto y créditos ------------------------------------------------------------------------

def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def save_manifest(m: dict) -> None:
    MANIFEST.write_text(json.dumps(m, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


def load_credits() -> dict:
    return json.loads(CREDITS.read_text(encoding="utf-8")) if CREDITS.exists() else {}


def license_name(url: str) -> str:
    if "publicdomain/zero" in url:
        return "CC0 1.0"
    if "licenses/by/" in url:
        version = url.rstrip("/").split("/")[-1]
        return f"CC BY {version}"
    return url


def write_credits_doc(credits: dict) -> None:
    lines = [
        "# Créditos de sonido",
        "",
        "Efectos de [Freesound](https://freesound.org), preparados con `tools/audio/freesound.py`",
        "(recorte, fundidos, volumen y bucles). Las licencias CC BY exigen esta atribución también",
        "en los créditos del juego.",
        "",
        "| Sonido en el juego | Original | Autor | Licencia |",
        "|---|---|---|---|",
    ]
    for name in sorted(credits):
        c = credits[name]
        lines.append(f"| `{name}` | [{c['title']}]({c['url']}) | {c['author']} | {license_name(c['license'])} |")
    CREDITS_DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")


def selected(m: dict, prefixes: list[str]) -> list[dict]:
    entries = m["sounds"]
    if not prefixes:
        return entries
    return [e for e in entries if any(e["name"].startswith(p) for p in prefixes)]


def cmd_search(m: dict, prefixes: list[str]) -> None:
    for entry in selected(m, prefixes):
        print(f"\n== {entry['name']}: {entry['query']}")
        for s in search(entry)[:12]:
            print(f"  {s['id']:>7}  {score(entry, s):6.1f}  {s['duration']:6.2f}s  {license_name(s['license']):10}"
                  f"  ★{s.get('avg_rating') or 0:.1f}({s.get('num_ratings') or 0})  {s['name'][:50]}  — {s['username']}")


def cmd_fetch(m: dict, prefixes: list[str], dry_run: bool) -> None:
    credits = load_credits()
    changed = False
    for entry in selected(m, prefixes):
        if entry.get("pick"):
            s = sound_info(int(entry["pick"]))
        else:
            if dry_run and not os.environ.get("FREESOUND_API_KEY"):
                print(f"  {entry['name']}: buscaría «{entry['query']}»")
                continue
            candidates = search(entry)
            if not candidates:
                print(f"  ¡{entry['name']}: sin candidatos! Revisa la consulta.")
                continue
            s = candidates[0]
            entry["pick"] = s["id"]
            changed = True
        print(f"  {entry['name']}: #{s['id']} «{s['name']}» de {s['username']} ({license_name(s['license'])})")
        if dry_run:
            continue
        for name, audio in process(entry, download(s)).items():
            write_wav(OUT_DIR / f"{name}.wav", audio)
            credits[name] = {"id": s["id"], "title": s["name"], "author": s["username"],
                             "license": s["license"], "url": s.get("url") or f"https://freesound.org/s/{s['id']}/"}
    if changed and not dry_run:
        save_manifest(m)
    if not dry_run:
        CREDITS.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        write_credits_doc(credits)


def main(argv: list[str]) -> None:
    if not argv or argv[0] not in ("search", "fetch", "credits"):
        print(__doc__)
        return
    m = load_manifest()
    args = [a for a in argv[1:] if not a.startswith("--")]
    if argv[0] == "search":
        cmd_search(m, args)
    elif argv[0] == "fetch":
        cmd_fetch(m, args, "--dry-run" in argv)
    else:
        write_credits_doc(load_credits())


if __name__ == "__main__":
    main(sys.argv[1:])
