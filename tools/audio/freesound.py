"""Sonidos y música de Freesound para La Novena Vigilia.

Busca, elige, descarga y prepara (recorte, filtro, fundidos, volumen, bucles, cortes) cada entrada
de `tools/audio/sound_manifest.json` y la deja con el nombre que ya usa el juego:
  - efectos y ambientes: `assets/audio/sfx/<nombre>.wav` (`Sfx.at(...)`, `Sfx.ui(...)`, paisaje sonoro);
  - música (`"out": "music"`): `assets/audio/music/<nombre>.ogg` (`MusicPlayer`).
Anota la autoría y la licencia de cada uno en `tools/audio/credits.json` y en
`docs/art/creditos-sonido.md`.

Solo se aceptan licencias que permiten uso comercial: CC0 y CC BY (con atribución).
Se descarga la vista previa de alta calidad (OGG ~192 kbps), que la API da con una clave normal
(la descarga del original exige OAuth2 y no hace falta para un juego pixelado).

Requisitos: Python 3 con numpy, ffmpeg (con libvorbis) y la variable de entorno FREESOUND_API_KEY
(clave gratuita: https://freesound.org/apiv2/apply). `check` no necesita nada de eso.

Uso:
  python3 -I tools/audio/freesound.py check                   # nombres del código sin entrada y al revés
  python3 -I tools/audio/freesound.py search door_open        # candidatos para revisar (prefijos)
  python3 -I tools/audio/freesound.py fetch                   # todos los del manifiesto
  python3 -I tools/audio/freesound.py fetch door_open step    # solo esos (prefijos)
  python3 -I tools/audio/freesound.py fetch --dry-run         # qué haría, sin descargar
  python3 -I tools/audio/freesound.py fetch --missing         # solo los que aún no tienen `pick`
  python3 -I tools/audio/freesound.py credits                 # regenera el documento de créditos

En el manifiesto, `pick` fija el id elegido (reproducible); si falta, se elige automáticamente
el mejor candidato y se escribe en el manifiesto para la próxima vez. Para cambiarlo: `search`,
escuchar en freesound.org/s/<id>/ y poner el id en `pick`.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from pathlib import Path

try:
    import numpy as np
except ImportError:  # `check` y `credits` funcionan sin numpy.
    np = None

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/audio/sound_manifest.json"
CREDITS = ROOT / "tools/audio/credits.json"
CREDITS_DOC = ROOT / "docs/art/creditos-sonido.md"
CREDITS_GAME = ROOT / "assets/audio/credits.txt"
OUT_DIRS = {"sfx": ROOT / "assets/audio/sfx", "music": ROOT / "assets/audio/music"}
CACHE = ROOT / "tools/audio/.cache"
API = "https://freesound.org/apiv2"
SR = 44100
FIELDS = "id,name,username,license,duration,channels,previews,avg_rating,num_ratings,num_downloads,tags,url"
LICENSES_OK = ("publicdomain/zero", "licenses/by/")
LICENSE_FILTER = 'license:("Creative Commons 0" OR "Attribution")'
## Etiquetas que restan siempre en los efectos (no en la música).
GLOBAL_AVOID = ("music", "song", "melody", "loop-music", "beat", "drum", "remix")
## La API admite 60 peticiones por minuto: una cada ~1,1 s como mucho.
MIN_REQUEST_GAP = 1.1
_last_request = 0.0


# --- API -----------------------------------------------------------------------------------------

def _key() -> str:
    key = os.environ.get("FREESOUND_API_KEY", "").strip()
    if not key:
        sys.exit("Falta FREESOUND_API_KEY (clave gratuita en https://freesound.org/apiv2/apply).")
    return key


def _get(url: str, params: dict | None = None, retries: int = 5) -> bytes:
    global _last_request
    if params is not None:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    delay = 3.0
    for attempt in range(retries):
        wait = MIN_REQUEST_GAP - (time.monotonic() - _last_request)
        if wait > 0:
            time.sleep(wait)
        _last_request = time.monotonic()
        req = urllib.request.Request(url, headers={"Authorization": "Token " + _key(),
                                                   "User-Agent": "LaNovenaVigilia-sfx/1.1"})
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 401:
                sys.exit("Freesound rechaza la clave (401). Revisa FREESOUND_API_KEY.")
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


def _query(query: str, lo: float, hi: float, page_size: int, licensed: bool) -> list[dict]:
    flt = f"duration:[{lo} TO {hi}]"
    if licensed:
        flt = f"{LICENSE_FILTER} {flt}"
    params = {"query": query, "filter": flt, "fields": FIELDS, "sort": "score", "page_size": page_size}
    key = query + str(lo) + str(hi) + ("L" if licensed else "")
    cache = CACHE / ("q_" + "".join(c if c.isalnum() else "_" for c in key) + ".json")
    if cache.exists():
        data = json.loads(cache.read_text(encoding="utf-8"))
    else:
        data = json.loads(_get(API + "/search/text/", params))
        CACHE.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(data), encoding="utf-8")
    return data.get("results", [])


def search(entry: dict, page_size: int = 40) -> list[dict]:
    """Candidatos para una entrada (todas sus consultas), ya filtrados por licencia y duración."""
    lo, hi = entry.get("duration", [0.0, 600.0])
    found: dict[int, dict] = {}
    for qi, query in enumerate([entry["query"]] + entry.get("alt", [])):
        results = _query(query, lo, hi, page_size, True)
        if not results:
            # Por si el nombre de las licencias cambia en la API: sin filtro y se filtra aquí.
            results = _query(query, lo, hi, page_size, False)
        for rank, s in enumerate(results):
            if not any(ok in s.get("license", "") for ok in LICENSES_OK):
                continue
            # Las consultas alternativas cuentan un poco menos que la principal.
            r = rank + qi * 4
            s["_rank"] = min(r, found.get(s["id"], {}).get("_rank", 999))
            found[s["id"]] = s
    return sorted(found.values(), key=lambda s: -score(entry, s))


def _words(s: dict) -> set[str]:
    """Etiquetas y palabras del título, en minúsculas (con y sin guiones)."""
    words = set()
    for t in s.get("tags", []):
        t = t.lower()
        words.add(t)
        words.update(p for p in re.split(r"[-_]", t) if p)
    words.update(w for w in re.split(r"[^a-z0-9]+", s.get("name", "").lower()) if w)
    return words


def is_music(entry: dict) -> bool:
    return entry.get("out") == "music"


def score(entry: dict, s: dict) -> float:
    """Puntuación de un candidato: relevancia, valoraciones, descargas, etiquetas y duración."""
    words = _words(s)
    pts = 30.0 - min(s.get("_rank", 30), 40)
    pts += (s.get("avg_rating") or 0.0) * min(s.get("num_ratings") or 0, 20) / 4.0
    pts += min(10.0, (s.get("num_downloads") or 0) ** 0.5 / 10.0)
    for t in entry.get("want", []):
        if t in words:
            pts += 6.0
    avoid = list(entry.get("avoid", []))
    if not is_music(entry):
        avoid += GLOBAL_AVOID
    for t in avoid:
        if t in words:
            pts -= 25.0
    lo, hi = entry.get("duration", [0.0, 600.0])
    ideal = entry.get("ideal", (lo + hi) / 2.0)
    pts -= abs(s.get("duration", ideal) - ideal) / max(0.5, hi - lo) * 6.0
    if entry.get("stereo") and s.get("channels", 2) < 2:
        pts -= 3.0
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

def decode(path: Path, channels: int, af: str = "") -> np.ndarray:
    """Audio en float32, forma (muestras, canales), a 44,1 kHz. `af`: filtros de ffmpeg opcionales."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path)]
    if af:
        cmd += ["-af", af]
    cmd += ["-f", "f32le", "-acodec", "pcm_f32le", "-ac", str(channels), "-ar", str(SR), "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
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
    """Bucle sin costura: el final se funde (a potencia constante) con el principio."""
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


def write_ogg(path: Path, a: np.ndarray, quality: float = 5.0) -> None:
    """OGG Vorbis (lo que importa Godot como AudioStreamOggVorbis, que hace bucle sin huecos)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(a.shape[1]), "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(quality), str(path)]
    subprocess.run(cmd, input=np.ascontiguousarray(a, dtype=np.float32).tobytes(), check=True)


def output_path(entry: dict, name: str) -> Path:
    ext = ".ogg" if entry.get("format", "ogg" if is_music(entry) else "wav") == "ogg" else ".wav"
    return OUT_DIRS[entry.get("out", "sfx")] / f"{name}{ext}"


def process(entry: dict, src: Path) -> dict[str, np.ndarray]:
    """Prepara el audio según el manifiesto. Devuelve nombre de archivo -> audio."""
    channels = 2 if entry.get("stereo") else 1
    a = decode(src, channels, entry.get("af", ""))
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
        if entry.get("trim", False):
            a = trim_silence(a)
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
        "Efectos y música de [Freesound](https://freesound.org), preparados con `tools/audio/freesound.py`",
        "(recorte, filtro, fundidos, volumen y bucles). Las licencias CC BY exigen esta atribución también",
        "en los créditos del juego.",
        "",
        "| Sonido en el juego | Original | Autor | Licencia |",
        "|---|---|---|---|",
    ]
    for name in sorted(credits):
        c = credits[name]
        lines.append(f"| `{name}` | [{c['title']}]({c['url']}) | {c['author']} | {license_name(c['license'])} |")
    CREDITS_DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")
    # Lo mismo, en texto llano, para la pantalla de créditos del juego (la lee title_screen.gd).
    seen: set = set()
    game: list[str] = []
    for name in sorted(credits, key=lambda n: credits[n]["author"].lower()):
        c = credits[name]
        if c["id"] in seen:
            continue
        seen.add(c["id"])
        game.append(f"«{c['title']}» — {c['author']} ({license_name(c['license'])})")
    CREDITS_GAME.write_text("\n".join(game) + "\n", encoding="utf-8")


def selected(m: dict, prefixes: list[str]) -> list[dict]:
    entries = m["sounds"]
    if not prefixes:
        return entries
    return [e for e in entries if any(e["name"].startswith(p) for p in prefixes)]


def outputs(entry: dict) -> list[str]:
    """Nombres de archivo (sin extensión) que produce una entrada."""
    return list(entry["slices"]) if entry.get("slices") else [entry["name"]]


def cmd_search(m: dict, prefixes: list[str]) -> None:
    for entry in selected(m, prefixes):
        pick = entry.get("pick")
        print(f"\n== {entry['name']}: {entry['query']}" + (f"   (elegido: #{pick})" if pick else ""))
        for s in search(entry)[:12]:
            mark = "*" if pick and int(pick) == s["id"] else " "
            print(f" {mark}{s['id']:>7}  {score(entry, s):6.1f}  {s['duration']:6.2f}s  {license_name(s['license']):10}"
                  f"  ★{s.get('avg_rating') or 0:.1f}({s.get('num_ratings') or 0})  {s['name'][:50]}  — {s['username']}")
            print(f"           https://freesound.org/s/{s['id']}/")


def cmd_fetch(m: dict, prefixes: list[str], dry_run: bool, only_missing: bool) -> None:
    credits = load_credits()
    changed = False
    failed: list[str] = []
    for entry in selected(m, prefixes):
        if only_missing and entry.get("pick"):
            continue
        try:
            if entry.get("pick"):
                s = sound_info(int(entry["pick"]))
            else:
                if dry_run and not os.environ.get("FREESOUND_API_KEY"):
                    print(f"  {entry['name']}: buscaría «{entry['query']}»")
                    continue
                candidates = search(entry)
                if not candidates:
                    print(f"  ¡{entry['name']}: sin candidatos! Revisa la consulta.")
                    failed.append(entry["name"])
                    continue
                s = candidates[0]
                entry["pick"] = s["id"]
                changed = True
                save_manifest(m)  # se guarda cada elección: si algo falla luego, no se repite la búsqueda
            print(f"  {entry['name']}: #{s['id']} «{s['name']}» de {s['username']} ({license_name(s['license'])})")
            if dry_run:
                continue
            for name, audio in process(entry, download(s)).items():
                path = output_path(entry, name)
                if path.suffix == ".ogg":
                    write_ogg(path, audio, entry.get("quality", 5.0))
                else:
                    write_wav(path, audio)
                credits[name] = {"id": s["id"], "title": s["name"], "author": s["username"],
                                 "license": s["license"], "url": s.get("url") or f"https://freesound.org/s/{s['id']}/"}
        except (urllib.error.URLError, subprocess.CalledProcessError, ValueError) as e:
            print(f"  ¡{entry['name']}: error {e}!")
            failed.append(entry["name"])
    if changed and not dry_run:
        save_manifest(m)
    if not dry_run:
        CREDITS.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        write_credits_doc(credits)
    if failed:
        print(f"\nSin resolver ({len(failed)}): {' '.join(failed)}")


# --- comprobación: qué nombres usa el juego ----------------------------------------------------

## Dónde se busca.
SCAN_DIRS = ("autoload", "scenes", "scripts", "data", "tools/levels", "tools/data")
## Llamadas cuyo texto literal es un nombre de sonido.
CALL_RE = re.compile(r"\b(?:Sfx\.(?:at|ui|stream)|sfx_at|play_named|EventActions\.sound|_play|_sound|_snd|"
                     r"_sound_at_place|MusicPlayer\.track)\(")
LITERAL_RE = re.compile(r'"([a-z][a-z0-9_]*)"')
NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
## Constantes con listas o diccionarios de sonidos (claves y valores).
CONST_RE = re.compile(r"^const\s+((?!\w*_NAMES\b)\w*(?:SOUND|SOUNDS|PROVISIONAL|TRACKS|MUSIC)\w*)\s*:[^=]*=\s*(.*)$")
## Claves de diccionario dentro de una llamada (`sounds["open"]`, `.get("take", …)`): no son sonidos.
KEY_RE = re.compile(r'\w\[\s*"[^"]*"\s*\]|\.get\(\s*"[^"]*"\s*,')
## Campos de recursos (.tres/.tscn) y del generador del mapa.
FIELD_RE = re.compile(r'^\s*(?:sound|use_sound|sounds?_\w+|bed_sound|music)\s*=\s*"([a-z][a-z0-9_]*)"', re.M)
PACKED_RE = re.compile(r"^\s*sounds\s*=\s*PackedStringArray\(([^)]*)\)", re.M)
STEP_RE = re.compile(r'step_sound\s*(?::\s*String\s*)?=\s*"([a-z][a-z0-9_]*)"|else\s+"(step[a-z_]*)"')
PATH_RE = re.compile(r"res://assets/audio/(?:sfx|music)/([a-z][a-z0-9_]*)\.(?:wav|ogg)")
SPEC_RE = re.compile(r'\[\s*"([a-z][a-z0-9_]*)"\s*,\s*-?[0-9.]+\s*\]')
OBJ_SOUND_RE = re.compile(r'"(?:open|close|locked|take)"\s*:\s*"([a-z][a-z0-9_]*)"')
## Acciones de ItemSounds que no generan `inv_<material>_<acción>` (tienen su propio nombre).
INV_SPECIAL_ACTIONS = ("tear", "craft", "use")
STEP_VARIANTS = 4


def _const_block(lines: list[str], i: int) -> str:
    """Texto de una constante que puede ocupar varias líneas (hasta cerrar corchetes y llaves)."""
    text = lines[i]
    depth = text.count("[") + text.count("{") + text.count("(") - text.count("]") - text.count("}") - text.count(")")
    j = i
    while depth > 0 and j + 1 < len(lines):
        j += 1
        text += "\n" + lines[j]
        depth += lines[j].count("[") + lines[j].count("{") + lines[j].count("(")
        depth -= lines[j].count("]") + lines[j].count("}") + lines[j].count(")")
    return text


def _gd_array(text: str, const: str) -> list[str]:
    m = re.search(r"const\s+" + const + r"\s*:[^=]*=\s*\[([^\]]*)\]", text, re.S)
    return LITERAL_RE.findall(m.group(1)) if m else []


def used_names(root: Path = ROOT) -> dict[str, set[str]]:
    """Nombres de sonido que usa el juego -> archivos donde aparecen."""
    used: dict[str, set[str]] = {}

    def add(name: str, where: Path) -> None:
        if NAME_RE.match(name):
            used.setdefault(name, set()).add(str(where.relative_to(root)))

    step_prefixes: set[str] = set()
    for d in SCAN_DIRS:
        base = root / d
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if path.suffix not in (".gd", ".tres", ".tscn") or "/." in "/" + str(path.relative_to(root)):
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for name in PATH_RE.findall(text):
                add(name, path)
            for m in STEP_RE.finditer(text):
                step_prefixes.add(m.group(1) or m.group(2))
            if path.suffix == ".gd":
                lines = text.splitlines()
                for i, line in enumerate(lines):
                    if line.lstrip().startswith("#"):
                        continue
                    code = line
                    c = CONST_RE.match(code.strip())
                    if c:
                        for name in LITERAL_RE.findall(_const_block(lines, i)):
                            add(name, path)
                        continue
                    for call in CALL_RE.finditer(code):
                        # Literales dentro de los paréntesis de la llamada (y listas como [..].pick_random()).
                        rest = code[call.end():]
                        depth, end = 1, len(rest)
                        for k, ch in enumerate(rest):
                            depth += ch == "("
                            depth -= ch == ")"
                            if depth == 0:
                                end = k
                                break
                        for name in LITERAL_RE.findall(KEY_RE.sub("", rest[:end])):
                            add(name, path)
                if path.name == "build_hospital.gd":
                    for name in OBJ_SOUND_RE.findall(text):
                        add(name, path)
            else:
                for name in FIELD_RE.findall(text):
                    add(name, path)
                for group in PACKED_RE.findall(text):
                    for name in LITERAL_RE.findall(group):
                        add(name, path)
                # Sonidos por fotograma de las animaciones del jugador (levantarse de la camilla…).
                if '"sounds": {' in text:
                    for block in re.findall(r'"sounds": \{([^}]*)\}', text):
                        for name in SPEC_RE.findall(block):
                            add(name, path)
    # Pisadas: prefijo + _1.._4.
    player = root / "scenes/world/player/player.gd"
    for prefix in sorted(p for p in step_prefixes if p):
        for i in range(1, STEP_VARIANTS + 1):
            add(f"{prefix}_{i}", player)
    # Custodia: inv_<material>_<acción> e inv_<acción>.
    item_def = root / "scripts/core/items/item_def.gd"
    item_sounds = root / "scripts/systems/inventory/item_sounds.gd"
    if item_def.exists() and item_sounds.exists():
        materials = [m for m in _gd_array(item_def.read_text(encoding="utf-8"), "SOUND_MATERIAL_NAMES") if m]
        actions = [a for a in _gd_array(item_sounds.read_text(encoding="utf-8"), "ACTION_NAMES")
                   if a not in INV_SPECIAL_ACTIONS]
        for a in actions:
            add(f"inv_{a}", item_sounds)
            for mat in materials:
                add(f"inv_{mat}_{a}", item_sounds)
    return used


def check(m: dict, root: Path = ROOT) -> tuple[list[str], list[str], list[str]]:
    """(usados sin entrada, entradas que no usa nadie, entradas reservadas sin uso)."""
    used = used_names(root)
    provided: dict[str, dict] = {}
    for entry in m["sounds"]:
        for name in outputs(entry):
            provided[name] = entry
    missing = sorted(n for n in used if n not in provided)
    unused = sorted(n for n, e in provided.items() if n not in used and not e.get("reserved"))
    reserved = sorted(n for n, e in provided.items() if n not in used and e.get("reserved"))
    return missing, unused, reserved


def cmd_check(m: dict) -> int:
    used = used_names()
    missing, unused, reserved = check(m)
    entries = len(m["sounds"])
    files = sum(len(outputs(e)) for e in m["sounds"])
    print(f"Manifiesto: {entries} entradas ({files} archivos). Nombres usados en el código: {len(used)}.")
    if missing:
        print(f"\nUsados en el código SIN entrada en el manifiesto ({len(missing)}):")
        for n in missing:
            print(f"  {n:28}  {', '.join(sorted(used[n]))}")
    if unused:
        print(f"\nEn el manifiesto pero sin uso en el código ({len(unused)}):")
        for n in unused:
            print(f"  {n}")
    if reserved:
        print(f"\nReservados (en el manifiesto a propósito, aún sin uso): {' '.join(reserved)}")
    if not missing and not unused:
        print("Todo cubierto.")
    return 1 if missing or unused else 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("search", "fetch", "credits", "check"):
        print(__doc__)
        return 0
    m = load_manifest()
    args = [a for a in argv[1:] if not a.startswith("--")]
    if argv[0] == "check":
        return cmd_check(m)
    if argv[0] in ("search", "fetch") and np is None and "--dry-run" not in argv:
        sys.exit("Falta numpy (pip install numpy).")
    if argv[0] == "search":
        cmd_search(m, args)
    elif argv[0] == "fetch":
        cmd_fetch(m, args, "--dry-run" in argv, "--missing" in argv)
    else:
        write_credits_doc(load_credits())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
