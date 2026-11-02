"""Pruebas de tools/audio/freesound.py (sin red ni clave).

  python3 -I tools/audio/test_freesound.py

- El manifiesto cubre todos los nombres de sonido que usa el código y no sobra ninguno.
- El buscador de nombres encuentra los usos típicos (llamadas, constantes, datos, pisadas, custodia).
- La puntuación penaliza lo que se pide evitar y no confunde palabras («car» no es «scary»).
- El proceso de audio (bucle, OGG de música) funciona con un archivo local, si hay numpy y ffmpeg.
"""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("freesound", HERE / "freesound.py")
fs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fs)


class ManifestTest(unittest.TestCase):
    def test_manifest_sin_huecos(self) -> None:
        m = fs.load_manifest()
        missing, unused, _reserved = fs.check(m)
        self.assertEqual(missing, [], "nombres usados en el código sin entrada en el manifiesto")
        self.assertEqual(unused, [], "entradas del manifiesto que no usa nadie (márcalas reserved si es a propósito)")

    def test_nombres_unicos_y_campos(self) -> None:
        m = fs.load_manifest()
        files = [n for e in m["sounds"] for n in fs.outputs(e)]
        self.assertEqual(len(files), len(set(files)), "archivos repetidos")
        for e in m["sounds"]:
            self.assertTrue(e.get("query"), e["name"])
            lo, hi = e.get("duration", [0, 600])
            self.assertLess(lo, hi, e["name"])
            self.assertIn(e.get("out", "sfx"), fs.OUT_DIRS, e["name"])

    def test_musica_del_menu_en_ogg(self) -> None:
        m = fs.load_manifest()
        music = [e for e in m["sounds"] if fs.is_music(e)]
        self.assertGreaterEqual(len(music), 2)
        for e in music:
            self.assertEqual(fs.output_path(e, e["name"]).suffix, ".ogg")
            self.assertTrue(e.get("loop"), e["name"])

    def test_encuentra_los_usos(self) -> None:
        used = fs.used_names()
        for name in ["flashlight_click",      # Sfx.at(self, "…")
                     "ui_move",               # const SOUND_MOVE
                     "entity_breath",         # _play("…") y FALLBACK_SOUNDS
                     "scare_door_slam",       # sounds = PackedStringArray(...) en data/horror
                     "use_bandage_apply",     # use_sound en data/items
                     "craft_cloth",           # sound = "…" en data/recipes
                     "step_boot_3",           # step_sound + _1.._4
                     "inv_keys_drop",         # inv_<material>_<acción>
                     "inv_rotate",            # inv_<acción>
                     "breath_wake_male",      # sonidos de la animación de levantarse
                     "drawer_open",           # sonidos de los muebles en el generador del mapa
                     "amb_vent_loop",         # paisaje sonoro (data/audio)
                     "music_menu_drone"]:     # MENU_TRACKS del título
            self.assertIn(name, used, name)
        for wrong in ["open", "close", "take", "metal_heavy", "keys"]:
            self.assertNotIn(wrong, used, wrong)


class ScoreTest(unittest.TestCase):
    def test_avoid_por_palabras(self) -> None:
        entry = {"query": "x", "duration": [1, 3], "want": ["door"], "avoid": ["car"]}
        base = {"duration": 2, "_rank": 0, "tags": ["door"], "name": "scary door"}
        car = dict(base, tags=["door", "car"])
        self.assertGreater(fs.score(entry, base), fs.score(entry, car) + 20, "«car» en las etiquetas resta")
        self.assertEqual(fs.score(entry, base), fs.score(entry, dict(base, name="old door")), "«scary» no es «car»")
        self.assertGreater(fs.score(entry, base), fs.score(entry, dict(base, tags=[], name="hinge")) + 5, "want suma")

    def test_la_musica_no_se_penaliza_por_ser_musica(self) -> None:
        sfx = {"query": "x", "duration": [60, 600]}
        music = dict(sfx, out="music")
        s = {"duration": 120, "_rank": 0, "tags": ["music", "drone"], "name": "dark drone"}
        self.assertGreater(fs.score(music, s), fs.score(sfx, s) + 20)


@unittest.skipIf(fs.np is None or shutil.which("ffmpeg") is None, "sin numpy o ffmpeg")
class AudioTest(unittest.TestCase):
    def _source(self, tmp: Path, seconds: float) -> Path:
        src = tmp / "src.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i",
                        f"anoisesrc=d={seconds}:c=pink:a=0.2", "-ac", "2", str(src)], check=True)
        return src

    def test_bucle_y_ogg(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            src = self._source(tmp, 30.0)
            entry = {"name": "music_test", "loop": True, "max_len": 20, "crossfade": 4.0, "stereo": True,
                     "level": -26, "out": "music", "af": "highpass=f=30"}
            out = fs.process(entry, src)["music_test"]
            self.assertEqual(out.shape[1], 2)
            self.assertAlmostEqual(len(out) / fs.SR, 16.0, delta=0.05)  # 20 s menos el fundido cruzado
            ogg = tmp / "music_test.ogg"
            fs.write_ogg(ogg, out)
            back = fs.decode(ogg, 2)
            self.assertAlmostEqual(len(back) / fs.SR, len(out) / fs.SR, delta=0.1)

    def test_efecto_recortado(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            src = self._source(Path(d), 3.0)
            out = fs.process({"name": "x", "max_len": 1.0, "level": -20}, src)["x"]
            self.assertLessEqual(len(out) / fs.SR, 1.0 + 1e-3)
            self.assertEqual(out.shape[1], 1)

    def test_nivel_de_un_golpe_corto(self) -> None:
        # Regresión: el nivel se medía sobre la envolvente de picos y los golpes cortos (pisadas,
        # clics) quedaban 10-25 dB por debajo del objetivo.
        if fs.np is None:
            self.skipTest("sin numpy")
        np = fs.np
        rng = np.random.default_rng(1)
        t = np.arange(int(fs.SR * 0.3)) / fs.SR
        hit = (rng.standard_normal(len(t)) * np.exp(-t * 40.0) * 0.5)[:, None]
        out = fs.loudness(hit, -26.0)
        self.assertAlmostEqual(fs.db(fs.active_rms(out)), -26.0, delta=1.0)
        self.assertLessEqual(float(np.abs(out).max()), 10 ** (-1.0 / 20.0) + 1e-6)


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False, verbosity=1).result.wasSuccessful() else 1)
