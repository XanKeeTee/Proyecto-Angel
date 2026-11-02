"""Genera `tools/audio/sound_manifest.json` (qué buscar en Freesound para cada sonido del juego).

El manifiesto es la fuente que lee `freesound.py`. Este script lo reescribe desde las tablas de
abajo y conserva los `pick` (ids elegidos) que ya tenga el manifiesto. Para afinar una búsqueda
se puede editar aquí y regenerar, o editar el JSON directamente (si se regenera, manda esto).

  python3 -I tools/audio/build_manifest.py
  python3 -I tools/audio/freesound.py check      # que no falte ni sobre nada

Campos de cada entrada (ver también `_doc` en el JSON):
  name        archivo en assets/audio/sfx/<name>.wav (o assets/audio/music/<name>.ogg si out=music)
  query, alt  búsqueda principal (concreta) y alternativas (más amplias)
  duration    [mín, máx] segundos del original en Freesound; ideal: duración preferida
  want/avoid  etiquetas o palabras del título que suman o restan (avoid resta mucho)
  level       volumen RMS objetivo en dBFS (más negativo = más bajo)
  max_len     recorte en segundos; fade_in/fade_out; pitch (semitonos); af (filtros de ffmpeg)
  loop        bucle sin costura (crossfade en s); stereo; slices (varios golpes de una grabación)
  out/format  "music" + "ogg" para la música
  reserved    está a propósito aunque el código aún no lo use (check no lo cuenta como sobrante)
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/audio/sound_manifest.json"

DOC = ("Qué buscar en Freesound para cada sonido del juego (lo genera tools/audio/build_manifest.py; "
       "lo usa tools/audio/freesound.py). name = archivo en assets/audio/sfx (o assets/audio/music si "
       "out=music, en OGG); query/alt = búsquedas (de concreta a amplia); duration = [mín, máx] s del "
       "original; ideal = duración preferida; want/avoid = etiquetas a favor/en contra; level = volumen "
       "RMS objetivo (dBFS); max_len/fade_in/fade_out/pitch/af = recorte, fundidos, tono y filtros "
       "ffmpeg; loop = bucle sin costura (crossfade s); slices = cortar varios golpes de una misma "
       "grabación; reserved = aún sin uso en el código, a propósito; pick = id elegido (se rellena solo).")

# Palabras que delatan voces, música o sonidos de juego sintéticos (en efectos).
NO_VOICE = ["voice", "talking", "speech", "people", "crowd"]
NO_OUTSIDE = ["traffic", "birds", "bird", "car", "street", "city", "rain", "thunder"]
NO_FAKE = ["cartoon", "synth", "synthesized", "8bit", "chiptune", "arcade", "glitch-music"]


def e(name: str, query: str, alt: list[str], duration: list[float], want: list[str], level: float,
      **kw) -> dict:
    entry = {"name": name, "query": query, "alt": alt, "duration": duration, "want": want, "level": level}
    avoid = kw.pop("avoid", [])
    entry["avoid"] = list(dict.fromkeys(avoid + NO_FAKE))
    entry.update(kw)
    return entry


# --- mundo: luz, máquinas, puertas, muebles ------------------------------------------------------
WORLD = [
    e("ambience_loop", "room tone quiet empty room",
      ["roomtone night interior quiet", "empty hall room tone", "air conditioning room tone quiet"],
      [30, 600], ["roomtone", "room-tone", "room", "tone", "quiet", "interior", "empty", "silence"], -40,
      avoid=NO_VOICE + NO_OUTSIDE + ["hum", "buzz", "footsteps", "wind", "music", "drone", "horror", "dark", "kids"],
      loop=True, max_len=45, crossfade=4.0, stereo=True, af="highpass=f=70,lowpass=f=7000", ideal=90,
      note="Tono de sala limpio y MUY bajo, sin sucesos ni zumbido: el aire de un edificio vacío."),
    e("hum_loop", "fluorescent light hum",
      ["fluorescent tube buzz", "neon light hum", "electrical hum light"],
      [5, 180], ["fluorescent", "hum", "buzz", "light", "tube", "ballast"], -32,
      avoid=NO_VOICE + ["guitar", "amp", "music", "flicker", "switch"], loop=True, max_len=14, crossfade=1.5,
      af="highpass=f=80", ideal=30,
      note="Zumbido continuo de un fluorescente (50/60 Hz con algo de agudo). Sin parpadeos ni clics."),
    e("generator_loop", "diesel generator running",
      ["generator engine idle loop", "industrial generator hum running", "old engine idling"],
      [8, 300], ["generator", "engine", "diesel", "running", "idle", "motor"], -24,
      avoid=NO_VOICE + ["car", "vehicle", "passing", "start", "starting", "rev", "motorcycle", "lawn"],
      loop=True, max_len=16, crossfade=1.5, ideal=40,
      note="Generador de gasóleo en marcha, constante, sin arranques ni aceleraciones."),
    e("generator_start", "diesel generator start",
      ["old engine starting sputter", "generator pull start", "engine start stall"],
      [2, 20], ["generator", "start", "starting", "engine", "diesel"], -18,
      avoid=["car", "vehicle", "motorcycle", "chainsaw"], max_len=7.0, fade_out=0.8,
      note="Motor que tose y arranca (tirón, petardeo, se estabiliza)."),
    e("fluorescent_on", "fluorescent light turning on",
      ["fluorescent tube start flicker", "neon light switch on flicker", "fluorescent ballast starting"],
      [1, 10], ["fluorescent", "flicker", "light", "tube", "neon"], -22,
      avoid=["guitar", "music"], max_len=4.0, fade_out=0.5,
      note="Tubos que arrancan: clics del cebador, parpadeo y zumbido que se asienta."),
    e("breaker", "circuit breaker switch",
      ["electrical panel lever switch heavy", "big switch clunk", "fuse box switch"],
      [0.2, 3], ["breaker", "switch", "electrical", "lever", "clunk"], -18, max_len=1.5,
      reserved=True, note="Palanca del cuadro eléctrico: clonc metálico grave. (Aún sin uso: cuadro del sótano.)"),
    e("door_open", "old door open creak",
      ["hospital door opening", "heavy door open squeak", "metal door opening"],
      [0.8, 5], ["door", "creak", "open", "opening", "squeak", "hinge"], -20,
      avoid=["car", "slam", "knock", "cabinet", "fridge"], max_len=2.8, fade_out=0.3,
      note="Puerta interior de hospital (madera con marco metálico) que se abre con un chirrido corto."),
    e("door_close", "door close latch",
      ["interior door shut click", "heavy door close", "door closing"],
      [0.4, 4], ["door", "close", "closing", "shut", "latch"], -19,
      avoid=["car", "slam", "fridge", "cabinet"], max_len=2.0, fade_out=0.3,
      note="Puerta que se cierra con el clic del pestillo, sin portazo."),
    e("door_locked", "locked door handle rattle",
      ["door knob jiggle locked", "door handle try locked", "rattle door handle"],
      [0.4, 4], ["locked", "handle", "rattle", "knob", "door"], -21, max_len=1.8,
      avoid=["knock", "car"], note="Manilla que baja y choca con la cerradura: está cerrada."),
    e("unlock", "key unlock door lock",
      ["key turn lock click", "key in lock unlock"], [0.3, 4], ["key", "unlock", "lock", "keys"], -22,
      max_len=1.6, reserved=True, note="Llave que entra y gira (aún sin uso: abrir con llave usa door_open)."),
    e("drawer_open", "metal drawer open",
      ["filing cabinet drawer open", "drawer slide open"], [0.3, 3], ["drawer", "open", "metal", "cabinet"], -22,
      max_len=1.4, avoid=["close", "slam"], note="Cajón metálico de archivador que se desliza al abrir."),
    e("drawer_close", "metal drawer close",
      ["filing cabinet drawer close", "drawer shut"], [0.3, 3], ["drawer", "close", "metal", "cabinet"], -21,
      max_len=1.2, avoid=["open"], note="Cajón metálico que se cierra con un golpe seco."),
    e("locker_open", "metal locker door open",
      ["steel cabinet door open creak", "gym locker open"], [0.4, 4], ["locker", "cabinet", "metal", "open"], -21,
      max_len=2.0, note="Taquilla de chapa: pestillo y puerta fina que vibra."),
    e("bed_creak", "hospital bed creak",
      ["metal bed springs creak", "old bed frame creak"], [0.5, 6], ["bed", "creak", "springs", "metal"], -22,
      max_len=2.6, fade_out=0.3, avoid=NO_VOICE + ["sex"], note="Somier metálico que cruje al moverse alguien."),
    e("heavy_drag", "heavy furniture drag floor",
      ["dragging metal cabinet floor", "drag heavy object concrete"], [0.8, 6], ["drag", "scrape", "furniture", "heavy"], -20,
      max_len=2.8, fade_out=0.3, note="Mueble pesado arrastrado un palmo sobre baldosa."),
    e("metal_bang", "metal bang reverb",
      ["elevator door bang", "heavy metal hit echo", "metal impact distant"], [0.5, 6], ["metal", "bang", "impact", "hit", "reverb"], -16,
      max_len=3.5, fade_out=0.7, avoid=["music", "drum"], note="Golpe metálico grande con cola (hueco del ascensor)."),
    e("knock", "knocking on wall",
      ["knock on door slow", "three knocks wood"], [0.5, 5], ["knock", "knocking", "wall", "door"], -22,
      max_len=2.5, note="Golpes de nudillos lentos, secos."),
    e("glass", "glass shards crunch",
      ["broken glass step", "small glass break"], [0.2, 3], ["glass", "shards", "broken", "crunch"], -22,
      max_len=1.5, note="Cristales rotos pisados o que caen, cortos."),
    e("drip", "single water drip",
      ["water drop puddle echo", "drip drop cave"], [0.1, 3], ["drip", "drop", "water", "droplet"], -26,
      max_len=1.2, avoid=["tap", "faucet", "rain"], note="Una sola gota en un charco, con algo de eco."),
    e("flashlight_click", "flashlight switch click",
      ["torch button click", "small switch click plastic"], [0.05, 2], ["flashlight", "torch", "click", "switch"], -20,
      max_len=0.4, note="Botón de linterna: clic de plástico corto."),
    e("monitor_beep", "heart monitor beep",
      ["ecg beep hospital", "patient monitor beep"], [0.1, 5], ["beep", "monitor", "ecg", "hospital", "heart"], -24,
      max_len=0.6, reserved=True, note="Un pitido de monitor de constantes (reservado para la Habitación 09)."),
    e("pa_chime", "announcement chime",
      ["pa system chime ding dong", "airport chime old", "intercom chime"], [0.8, 6], ["chime", "announcement", "pa", "ding"], -18,
      max_len=3.5, fade_out=0.6, avoid=NO_VOICE + ["doorbell"], note="Campanita de megafonía de dos o tres notas, antigua."),
    e("pa_static", "loudspeaker static",
      ["pa speaker static noise", "intercom static feedback", "radio static burst"], [1, 10], ["static", "speaker", "noise", "pa", "intercom"], -24,
      max_len=4.0, fade_out=0.5, avoid=NO_VOICE, note="Altavoces que se encienden: estática y zumbido."),
    e("phone_ring", "old telephone ring bell",
      ["rotary phone ringing", "vintage telephone ring"], [1, 10], ["telephone", "ring", "rotary", "phone", "bell", "vintage"], -18,
      max_len=4.0, avoid=["mobile", "cellphone", "ringtone", "smartphone"], note="Timbre de campana de teléfono de disco."),
    e("phone_static", "telephone line static",
      ["phone line noise interference", "telephone static breathing"], [1, 15], ["static", "telephone", "phone", "line", "noise"], -24,
      max_len=5.0, fade_out=0.6, avoid=["ringtone"], note="Línea muerta con estática (sin voz clara)."),
    e("tape_save", "cassette recorder record button",
      ["tape recorder button click mechanical", "cassette deck button press"], [0.3, 5], ["cassette", "tape", "button", "recorder"], -20,
      max_len=2.0, note="Botón de grabar de una grabadora de casete: clac mecánico y motor."),
    e("paper", "paper sheet handling",
      ["paper rustle short", "picking up paper"], [0.3, 3], ["paper", "sheet", "rustle", "handling"], -24,
      max_len=1.0, avoid=["crumple", "tear"], note="Una hoja que se coge o se gira."),
    e("pickup", "pick up small object foley",
      ["grab item foley", "cloth rustle grab"], [0.2, 2], ["foley", "pickup", "grab", "handling"], -24,
      max_len=0.7, note="Coger algo pequeño: roce de ropa y contacto."),
    e("pills", "pill bottle shake",
      ["pills rattle bottle", "medicine bottle rattle"], [0.3, 3], ["pills", "bottle", "rattle", "medicine"], -22,
      max_len=1.0, note="Bote de pastillas que se agita."),
    e("battery", "battery insert",
      ["batteries click into compartment", "aa battery handling"], [0.3, 4], ["battery", "batteries"], -22,
      max_len=1.4, note="Pilas que encajan (provisional de varios)."),
    e("bandage", "bandage wrap",
      ["medical tape tearing", "cloth wrap foley"], [0.5, 5], ["bandage", "tape", "cloth", "wrap"], -22,
      max_len=2.0, note="Venda que se desenrolla (provisional de varios)."),
    e("whisper", "whisper unintelligible",
      ["ghost whisper", "creepy whispering"], [0.6, 6], ["whisper", "whispering", "creepy"], -26,
      max_len=2.8, fade_out=0.5, avoid=["music", "asmr"], note="Susurro sin palabras claras."),
    e("steps_far", "distant footsteps corridor",
      ["footsteps hallway echo slow", "footsteps reverb walking"], [1.5, 10], ["footsteps", "corridor", "hallway", "echo"], -26,
      max_len=4.0, fade_out=0.6, avoid=["running", "heels", "snow", "gravel"], note="Pasos lentos lejos, con eco."),
]

# --- jugador: pisadas, cuerpo, levantarse, escaleras ---------------------------------------------
PLAYER = [
    e("step", "barefoot footsteps tile",
      ["bare feet walking hard floor", "barefoot walking"], [2, 40], ["barefoot", "footsteps", "feet", "tile"], -30,
      slices=["step_1", "step_2", "step_3", "step_4"], slice_len=0.32, min_gap=0.3,
      avoid=["running", "sand", "snow", "grass", "water", "heels"], note="Pies descalzos en baldosa: varios pasos en una toma."),
    e("step_soft", "slippers footsteps",
      ["soft shoes footsteps indoor", "sneakers walking indoor"], [2, 40], ["slippers", "footsteps", "shoes", "indoor"], -32,
      slices=["step_soft_1", "step_soft_2", "step_soft_3", "step_soft_4"], slice_len=0.32, min_gap=0.3,
      avoid=["running", "heels", "snow", "gravel"], note="Calzado blando en interior."),
    e("step_boot", "rubber boots footsteps",
      ["wellington boots walking", "boots footsteps concrete"], [2, 40], ["boots", "footsteps", "rubber", "wellies"], -26,
      slices=["step_boot_1", "step_boot_2", "step_boot_3", "step_boot_4"], slice_len=0.38, min_gap=0.3,
      avoid=["running", "snow", "mud", "gravel", "heels"], note="Botas de goma en suelo duro."),
    e("breath_wake_male", "male gasp inhale",
      ["man waking up breath", "sharp inhale breath male"], [0.5, 4], ["breath", "inhale", "gasp", "male"], -24,
      max_len=1.6, avoid=["female", "woman", "girl", "scream"], note="Inspiración brusca de quien se despierta."),
    e("pain_sigh_male", "male pain sigh",
      ["man exhale pain", "male sigh tired"], [0.6, 4], ["sigh", "pain", "male", "exhale"], -22,
      max_len=2.0, avoid=["female", "woman", "girl"], note="Suspiro de dolor contenido."),
    e("pain_groan_male", "male groan pain",
      ["man grunt effort pain", "male groan closed mouth"], [0.6, 4], ["groan", "pain", "male", "grunt"], -21,
      max_len=2.0, avoid=["female", "woman", "zombie", "monster"], note="Gruñido de dolor con la boca cerrada."),
    e("breath_strain_male", "male effort breathing",
      ["man straining breath", "effort grunt breathing"], [0.8, 5], ["effort", "breath", "male", "strain"], -23,
      max_len=2.2, avoid=["female", "woman", "running"],
      note="Respiración de esfuerzo entre dientes (al levantarse de la camilla)."),
    e("breath_run_male", "man out of breath panting",
      ["male heavy breathing after running", "exhausted panting man"], [1.5, 8], ["breathing", "panting", "male", "exhausted"], -23,
      max_len=3.0, fade_out=0.5, avoid=["female", "woman", "dog", "cough", "sex"],
      note="Jadeo de un hombre herido que se queda sin aliento tras correr un poco; se va calmando."),
    e("cloth_rustle", "bed sheet rustle",
      ["cotton fabric rustle", "blanket movement foley"], [0.4, 5], ["cloth", "rustle", "sheet", "fabric", "bed"], -26,
      max_len=1.2, note="Sábana que se mueve al incorporarse."),
    e("bare_feet_floor", "barefoot step tile",
      ["bare feet on floor", "foot touch floor barefoot"], [0.3, 4], ["barefoot", "step", "feet"], -26,
      max_len=1.0, note="Los pies desnudos tocan el suelo frío."),
    e("stairs_concrete", "footsteps concrete stairs",
      ["walking down stairs echo", "stairwell footsteps"], [1, 8], ["stairs", "footsteps", "concrete", "stairwell"], -24,
      max_len=2.0, reserved=True, note="Bajar o subir escalera de hormigón (reservado: el cambio de planta usa las pisadas)."),
]

# --- terror (scripts/systems/horror/) -------------------------------------------------------------
HORROR = [
    e("entity_breath", "slow raspy breathing",
      ["creepy breathing close", "heavy breath monster close", "wheezing breath"], [1, 8], ["breathing", "breath", "creepy", "raspy"], -24,
      max_len=3.0, avoid=["female", "running", "panting", "asthma"], note="Respiración lenta y ronca, muy cerca, sin voz."),
    e("entity_dissolve", "tv static burst",
      ["static noise burst short", "electric crackle short", "tape tear noise"], [0.3, 3], ["static", "noise", "crackle", "tv"], -22,
      max_len=0.8, fade_out=0.08, note="Ráfaga de estática que se corta en seco."),
    e("entity_whisper", "multiple whispers",
      ["whispering voices layered", "creepy whispers ear"], [0.6, 5], ["whisper", "whispers", "whispering"], -24,
      max_len=1.6, avoid=["asmr", "music"], note="Varios susurros superpuestos sin palabras."),
    e("scare_door_slam", "distant door slam",
      ["door slam corridor reverb", "door slam echo"], [0.8, 5], ["slam", "door", "distant", "reverb"], -18,
      max_len=2.5, avoid=["car", "truck"], note="Portazo lejano con cola de pasillo."),
    e("scare_fall", "metal tray falling floor",
      ["metal object falls floor bounce", "tray drop clatter"], [0.5, 4], ["tray", "fall", "metal", "clatter", "drop"], -19,
      max_len=2.0, note="Bandeja metálica que cae y rebota."),
    e("scare_glass", "glass jar break",
      ["glass bottle fall break", "small glass smash"], [0.4, 3], ["glass", "break", "smash", "shatter"], -20,
      max_len=1.2, avoid=["window"], note="Frasco que cae y se rompe."),
    e("scare_wall_knock", "knocking through wall muffled",
      ["muffled knock wall", "knock other side wall"], [0.6, 5], ["knock", "wall", "muffled"], -22,
      max_len=1.8, note="Tres golpes apagados al otro lado del tabique."),
    e("scare_steps_above", "footsteps upstairs ceiling",
      ["footsteps above floor creaking", "walking on floor above"], [2, 15], ["footsteps", "ceiling", "upstairs", "above", "creak"], -26,
      max_len=6.0, af="lowpass=f=1800", note="Pasos lentos en el piso de arriba, sin agudos."),
    e("scare_roll", "can rolling floor",
      ["small bottle rolling floor", "object rolling tile"], [1, 6], ["rolling", "roll", "can", "bottle"], -22,
      max_len=3.0, note="Bote o linterna que rueda y se para."),
    e("scare_wheelchair", "wheelchair squeak",
      ["wheelchair rolling", "squeaky wheel trolley"], [0.5, 5], ["wheelchair", "squeak", "wheel", "trolley"], -22,
      max_len=2.0, note="Silla de ruedas empujada un palmo, con chirrido."),
    e("scare_door_creak", "slow door creak",
      ["door hinge creak long", "creaking door open slow"], [1, 6], ["creak", "hinge", "door", "creaky"], -21,
      max_len=3.0, avoid=["slam"], note="Bisagra que chirría larga y lenta."),
    e("scare_breath", "exhale close breath",
      ["slow exhale behind", "breath out close"], [0.5, 4], ["breath", "exhale"], -24,
      max_len=1.6, avoid=["female", "woman"], note="Exhalación justo detrás."),
    e("scare_static_burst", "vhs static",
      ["tape static burst", "video noise static short"], [0.2, 3], ["static", "vhs", "tape", "noise"], -24,
      max_len=0.6, note="Ráfaga de estática de vídeo."),
    e("scare_drip", "water drips pipe echo",
      ["dripping water echo", "drips puddle reverb"], [0.8, 6], ["drip", "echo", "water", "dripping"], -24,
      max_len=2.2, avoid=["rain", "tap"], note="Dos a cuatro gotas con eco de tubería."),
]

# --- efectos de estado, título y música -----------------------------------------------------------
UI = [
    e("status_heartbeat", "single heartbeat",
      ["heartbeat low muffled", "heart beat thump"], [0.3, 4], ["heartbeat", "heart", "beat", "thump"], -20,
      max_len=0.7, avoid=["monitor", "beep", "fast", "running"], note="Un latido grave, amortiguado, sin clic inicial."),
    e("status_relief_breath", "relieved exhale male",
      ["long sigh relief", "man exhale relief"], [0.6, 4], ["exhale", "relief", "sigh"], -24,
      max_len=1.8, avoid=["female", "woman"], note="Exhalación larga de alivio."),
    e("ui_move", "vcr button click",
      ["remote control button click", "small button click"], [0.03, 1], ["click", "button", "vcr", "remote"], -24,
      max_len=0.12, note="Clic corto de botón de vídeo VHS."),
    e("ui_accept", "vcr play button",
      ["cassette deck button press", "tape player button mechanical"], [0.1, 2], ["button", "vcr", "cassette", "tape"], -22,
      max_len=0.35, note="Botón de vídeo más firme, con el clonc de la cinta."),
    e("ui_back", "soft click button",
      ["button click soft", "switch click quiet"], [0.03, 1], ["click", "button"], -26,
      max_len=0.12, pitch=-3, note="Clic suave, más grave que ui_move."),
    e("inv_category", "file folder divider click",
      ["metal tab click office", "cardboard divider flip"], [0.05, 2], ["click", "folder", "paper", "office"], -26,
      max_len=0.18, avoid=["beep", "electronic", "digital", "game"],
      note="Al cambiar de categoría en el inventario: clic seco de pestaña de archivador, sin pitido."),
    e("tape_rewind", "vhs rewind",
      ["video tape rewind", "cassette rewind stop"], [1, 8], ["rewind", "vhs", "tape", "cassette", "video"], -22,
      max_len=2.0, fade_out=0.15, note="Vídeo rebobinando con chasquido de parada."),
    e("title_ambience", "room tone night interior",
      ["empty building room tone", "quiet room tone hum"], [30, 600], ["roomtone", "room-tone", "room", "tone", "quiet", "interior"], -40,
      avoid=NO_VOICE + NO_OUTSIDE + ["footsteps", "music", "kids"], loop=True, max_len=40, crossfade=4.0, stereo=True,
      af="highpass=f=70,lowpass=f=7000", note="Bucle de fondo del título, muy bajo (la música va encima)."),
    e("title_tube_flicker", "fluorescent flicker buzz",
      ["fluorescent tube flicker", "neon flicker buzz short"], [0.3, 4], ["fluorescent", "flicker", "buzz", "neon"], -24,
      max_len=1.0, note="Chasquido y zumbido entrecortado de un tubo."),
]

# Música del menú: oscura, tensa, sin ritmo marcado; bucle largo. OGG en assets/audio/music/.
MUSIC_AVOID = ["beat", "drum", "drums", "rhythm", "percussion", "edm", "techno", "dubstep", "trap", "vocals",
               "voice", "singing", "lyrics", "pop", "rock", "guitar", "happy", "upbeat", "epic", "orchestral",
               "trailer", "jumpscare", "scream", "bass-drop", "8bit", "chiptune"]
MUSIC = [
    dict(name="music_menu_drone", query="dark ambient drone",
         alt=["horror drone loop", "dark atmosphere drone ominous", "eerie ambient drone"],
         duration=[60, 600], ideal=180,
         want=["dark", "ambient", "drone", "horror", "eerie", "ominous", "atmosphere", "dark-ambient", "loop"],
         avoid=MUSIC_AVOID, level=-26, loop=True, max_len=150, crossfade=8.0, stereo=True, out="music", format="ogg",
         af="highpass=f=28", quality=5,
         note="Dron oscuro y lento, con capas que respiran; nada de ritmo ni melodía clara."),
    dict(name="music_menu_piano", query="dark piano ambient",
         alt=["eerie piano reverb", "sad piano dark atmosphere", "horror piano slow"],
         duration=[45, 600], ideal=150,
         want=["piano", "dark", "eerie", "ambient", "reverb", "sad", "slow", "horror"],
         avoid=MUSIC_AVOID + ["jazz", "classical", "cheerful"], level=-27, loop=True, max_len=140, crossfade=8.0,
         stereo=True, out="music", format="ogg", af="highpass=f=28", quality=5,
         note="Piano lejano con mucha reverberación y notas sueltas, tensión sin resolver."),
    dict(name="music_menu_tension", query="suspense atmosphere horror",
         alt=["tension ambient dark", "suspense drone strings", "creepy ambience music"],
         duration=[60, 600], ideal=180,
         want=["suspense", "tension", "horror", "dark", "atmosphere", "creepy", "ambient", "strings"],
         avoid=MUSIC_AVOID, level=-26, loop=True, max_len=150, crossfade=8.0, stereo=True, out="music",
         format="ogg", af="highpass=f=28", quality=5,
         note="Atmósfera de suspense (cuerdas graves, texturas), sin golpes ni sustos."),
]

# --- combate (scenes/battle/, data/enemies/) ---------------------------------------------------------
NO_GAME = NO_FAKE + ["game", "punch", "kung-fu", "cartoon", "whoosh-designed"]
COMBAT = [
    e("combat_pipe_flesh", "body punch impact meat",
      ["hit flesh thud heavy", "meat hit stick"], [0.15, 2], ["flesh", "impact", "meat", "body", "thud"], -16,
      max_len=0.6, avoid=NO_GAME + ["metal", "kick"], note="Tubo de hierro contra carne: golpe sordo y húmedo, sin eco metálico."),
    e("combat_pipe_bone", "bone hit crack impact",
      ["hit bone thud crunch", "skull hit"], [0.15, 2], ["bone", "crack", "impact", "hit"], -15,
      max_len=0.5, avoid=NO_GAME, note="Tubo contra hueso: golpe seco con crujido corto."),
    e("combat_bone_break", "bone break snap",
      ["celery snap bone crack", "bone crunch break"], [0.2, 3], ["bone", "break", "snap", "crack", "crunch"], -14,
      max_len=0.8, avoid=NO_GAME + ["voice"], note="Hueso que se parte: chasquido grave tipo apio o madera húmeda, sin voz."),
    e("combat_amputation", "flesh tear gore squelch",
      ["meat tearing wet", "gore rip flesh"], [0.5, 4], ["gore", "flesh", "tear", "squelch", "wet", "rip"], -15,
      max_len=1.5, avoid=NO_GAME + ["sword", "swoosh"], note="Desgarro de carne y tendón con chapoteo; sin espada ni silbido."),
    e("combat_scalpel_slash", "knife slash flesh",
      ["blade cut cloth flesh", "knife stab slice"], [0.15, 2], ["knife", "slash", "cut", "blade", "slice"], -16,
      max_len=0.6, avoid=NO_GAME + ["sword", "katana"], note="Tajo fino y rápido sobre carne o tela con tintineo metálico."),
    e("combat_saw", "hand saw bone cutting",
      ["hacksaw cutting", "saw rasp short"], [0.5, 6], ["saw", "cutting", "hacksaw", "rasp"], -18,
      max_len=2.0, avoid=NO_GAME + ["chainsaw", "electric", "power"], note="Sierra de hueso manual: 2-3 pasadas ásperas."),
    e("combat_syringe", "syringe injection",
      ["needle syringe plunger", "injection medical foley"], [0.1, 3], ["syringe", "needle", "injection"], -20,
      max_len=0.6, avoid=NO_GAME, note="Aguja que entra, clic del émbolo y líquido."),
    e("combat_swing_miss", "heavy swing whoosh metal bar",
      ["stick swing air", "swing whoosh low"], [0.1, 2], ["swing", "whoosh", "swish"], -18,
      max_len=0.45, avoid=NO_FAKE + ["sword", "laser", "magic"], note="Barra pesada que corta el aire, grave y corta."),
    e("enfermero_breath", "wet raspy breathing mask",
      ["creature breathing slow wet", "heavy breathing through cloth"], [1.5, 10], ["breathing", "breath", "raspy", "wet"], -22,
      max_len=4.0, avoid=["female", "woman", "sex", "music"], note="Respiración húmeda y lenta a través de una mascarilla."),
    e("enfermero_growl", "muffled growl gutteral",
      ["monster growl low muffled", "zombie groan muffled"], [0.4, 4], ["growl", "groan", "guttural", "muffled"], -18,
      max_len=1.2, avoid=["dog", "lion", "bear", "cat", "music", "female"], note="Gruñido gutural ahogado, como con la boca cosida."),
    e("enfermero_scream", "muffled scream pain creature",
      ["distorted pain scream muffled", "zombie shriek"], [0.5, 4], ["scream", "shriek", "pain"], -16,
      max_len=1.5, avoid=["female", "woman", "girl", "child", "music", "laugh"], note="Chillido de dolor ahogado tras tela, agudo y quebrado."),
    e("enfermero_death", "body fall floor death groan",
      ["body drop thud", "corpse fall heavy"], [0.8, 5], ["body", "fall", "thud", "drop"], -16,
      max_len=2.5, avoid=NO_GAME + ["female"], note="Estertor y caída de un cuerpo pesado al suelo."),
    e("enfermero_drag_steps", "foot dragging floor limping",
      ["dragging foot footsteps", "limp footsteps drag"], [0.6, 8], ["drag", "dragging", "limp", "footsteps"], -20,
      max_len=1.6, avoid=NO_GAME + ["chain", "furniture"], note="Un paso y un pie arrastrado sobre linóleo."),
    e("combat_transition", "vhs tape glitch static",
      ["tape stop static burst", "vcr glitch noise"], [0.3, 4], ["vhs", "tape", "static", "glitch"], -18,
      max_len=1.0, avoid=["music"], note="Cinta VHS que salta: chirrido de cabezal y ráfaga de estática."),
    dict(name="music_combat_drone", query="industrial drone dark loop",
         alt=["machine drone ominous", "dark industrial ambience pulse"], duration=[30, 600], ideal=90,
         want=["industrial", "drone", "dark", "machine", "ominous", "loop"],
         avoid=MUSIC_AVOID, level=-24, loop=True, max_len=90, crossfade=6.0, stereo=True, out="music", format="ogg",
         af="highpass=f=30", quality=5,
         note="Drone industrial grave con un pulso lento de máquina, sin melodía; suena durante el combate."),
]

# --- paisaje sonoro del hospital (data/audio/hospital_soundscape.tres) -----------------------------
AMBIENT = [
    e("amb_vent_loop", "ventilation air duct hum",
      ["air vent blowing loop", "hvac ventilation room tone", "air conditioning duct noise"], [8, 300],
      ["ventilation", "vent", "air", "duct", "hvac", "fan"], -30,
      avoid=NO_VOICE + NO_OUTSIDE + ["wind", "music", "hairdryer"], loop=True, max_len=16, crossfade=2.0, ideal=40,
      af="highpass=f=60", note="Aire por un conducto: soplido sordo y continuo, sin golpeteos."),
    e("amb_drip_loop", "dripping tap water",
      ["faucet dripping loop", "water dripping sink", "slow drips"], [6, 200],
      ["drip", "dripping", "faucet", "tap", "water", "sink"], -30,
      avoid=["rain", "stream", "river", "pouring", "shower"], loop=True, max_len=14, crossfade=0.6, ideal=30,
      note="Grifo que gotea despacio en un lavabo de loza (gotas espaciadas, irregulares)."),
    e("amb_pipes_loop", "water pipes gurgling",
      ["pipes water flowing inside wall", "boiler room pipes ambience", "plumbing gurgle"], [8, 300],
      ["pipes", "pipe", "gurgle", "water", "plumbing", "boiler"], -30,
      avoid=NO_VOICE + ["toilet", "flush", "rain", "river", "shower"], loop=True, max_len=18, crossfade=2.0, ideal=40,
      af="lowpass=f=4000", note="Agua que se mueve por tuberías gruesas, gorgoteo lejano (la caldera está apagada)."),
    e("amb_fridge_loop", "refrigerator compressor hum",
      ["fridge hum loop", "freezer motor running", "cold room compressor"], [8, 300],
      ["fridge", "refrigerator", "compressor", "hum", "freezer"], -30,
      avoid=NO_VOICE + ["door", "open", "close", "ice", "music"], loop=True, max_len=14, crossfade=1.5, ideal=30,
      af="highpass=f=40", note="Motor de cámara frigorífica: zumbido grave constante con algo de vibración."),
    e("amb_electric_buzz", "electrical panel buzz",
      ["transformer hum buzz", "electric hum high voltage", "electrical cabinet hum"], [5, 200],
      ["electric", "electrical", "buzz", "hum", "transformer"], -32,
      avoid=NO_VOICE + ["guitar", "amp", "music", "spark", "zap"], loop=True, max_len=12, crossfade=1.2, ideal=25,
      note="Zumbido eléctrico seco de un cuadro con carga."),
    e("amb_creak_building", "building creak",
      ["house settling creak", "structure creaking old building"], [0.8, 8],
      ["creak", "creaking", "building", "house", "settling", "structure"], -24,
      avoid=["door", "footsteps", "chair", "bed", "ship", "boat", "rope"], max_len=3.0, fade_out=0.4,
      af="lowpass=f=6000", note="Crujido grave de la estructura del edificio, aislado."),
    e("amb_creak_wood", "wood creak single",
      ["wooden floor creak", "old wood creaking slow"], [0.5, 6], ["creak", "wood", "wooden", "creaking"], -25,
      avoid=["door", "footsteps", "chair", "ship", "boat"], max_len=2.5, fade_out=0.3,
      note="Una tabla o un marco de madera que cruje solo."),
    e("amb_creak_metal", "metal creak groan",
      ["metal stress groan", "steel structure creak", "metal pipe creak"], [0.8, 8],
      ["metal", "creak", "groan", "stress", "steel"], -24,
      avoid=["door", "gate", "swing", "ship", "music"], max_len=3.5, fade_out=0.5,
      note="Metal que se tensa y gime (vigas, conductos) en el sótano."),
    e("amb_pipe_knock", "pipe knocking water hammer",
      ["pipes banging", "radiator pipe knock", "metal pipe clank"], [0.4, 6],
      ["pipe", "pipes", "knock", "bang", "clank", "radiator", "hammer"], -22,
      avoid=["music", "drum", "door"], max_len=2.5, fade_out=0.4, af="lowpass=f=5000",
      note="Una tubería que golpea dentro de la pared (dos o tres golpes metálicos sordos)."),
    e("amb_water_pipes", "water running through pipes",
      ["water flowing in wall pipe", "plumbing water flow", "drain pipe water"], [1.5, 15],
      ["water", "pipe", "pipes", "plumbing", "flow", "drain"], -26,
      avoid=["toilet", "flush", "shower", "river", "rain", "tap"], max_len=5.0, fade_in=0.4, fade_out=1.0,
      af="lowpass=f=3500", note="Agua que corre un momento por una bajante, oída a través de la pared."),
    e("amb_wind_gust", "wind gust through window",
      ["wind whistle broken window", "wind gust interior", "draft wind howl short"], [1.5, 12],
      ["wind", "gust", "window", "draft", "whistle", "howl"], -26,
      avoid=["storm", "rain", "thunder", "microphone", "mic", "trees", "leaves"], max_len=5.0, fade_in=0.6, fade_out=1.2,
      note="Ráfaga de viento que silba por una ventana rota, desde dentro."),
    e("amb_monitor_far", "hospital monitor beeping",
      ["ecg monitor beeps", "heart monitor beeping distant", "patient monitor beep sequence"], [1.5, 15],
      ["monitor", "beep", "beeping", "ecg", "hospital", "heart"], -30,
      avoid=["flatline", "alarm", "music", "voice"], max_len=4.0, fade_in=0.3, fade_out=0.8,
      af="lowpass=f=2200,highpass=f=300", note="Tres o cuatro pitidos de monitor, lejanos (filtrados), en otra habitación."),
    e("amb_elevator_cables", "elevator cables creak",
      ["elevator shaft creak", "lift cable metal creak", "elevator shaft ambience"], [1, 12],
      ["elevator", "lift", "cable", "cables", "shaft", "creak"], -24,
      avoid=["ding", "music", "voice", "door"], max_len=4.0, fade_in=0.3, fade_out=0.8,
      note="Cables tensos que crujen en el hueco del ascensor, con algo de eco."),
    e("amb_paper_draft", "papers rustling wind",
      ["paper flutter draft", "loose papers moving breeze"], [0.8, 8],
      ["paper", "papers", "rustle", "flutter", "wind"], -28,
      avoid=["crumple", "tear", "book", "writing"], max_len=2.5, fade_in=0.2, fade_out=0.6,
      note="Hojas sueltas que se mueven con una corriente, sin manos."),
    e("amb_spark_crackle", "electrical spark crackle",
      ["electric arc crackle short", "sparking wire"], [0.3, 5],
      ["spark", "sparks", "electric", "crackle", "arc"], -26,
      avoid=["fire", "fireworks", "zap", "laser"], max_len=1.5, fade_out=0.2,
      note="Chisporroteo corto de un cable o un contacto."),
]

# --- paisaje sonoro, segunda capa: tonos de sala, aire del edificio y sueltos nuevos ---------------
# Grabaciones de campo reales: hospitales, sótanos y edificios vacíos o abandonados. Nada de
# ambientes «de terror» diseñados ni de sintetizadores: el miedo lo pone el juego, no el sonido.
# Los tonos de sala van secos (bus Ambiente); los sueltos pasan por el eco de la sala del jugador.
NO_DESIGNED = ["horror", "scary", "creepy", "spooky", "drone", "dark-ambient", "designed", "music", "pad", "game",
               "sci-fi", "scifi", "spaceship", "trailer"]
FIELD = ["field-recording", "fieldrecording", "field", "recording", "empty", "abandoned", "interior", "building"]
TONE_AVOID = NO_VOICE + NO_OUTSIDE + NO_DESIGNED + ["footsteps", "door", "kids", "children", "tv", "radio", "beep"]


def tone(name: str, query: str, alt: list[str], want: list[str], level: float, note: str, **kw) -> dict:
    """Tono de sala en bucle (va con el jugador, por el bus Ambiente): largo, estéreo, sin sucesos."""
    kw.setdefault("af", "highpass=f=45,lowpass=f=9000")
    avoid = TONE_AVOID + kw.pop("avoid", [])
    return e(name, query, alt, [20, 900], want + FIELD + ["roomtone", "room-tone", "ambience", "atmosphere"], level,
             avoid=avoid, loop=True, max_len=40, crossfade=4.0, stereo=True, ideal=120, note=note, **kw)


AMBIENT_ROOMS = [
    tone("amb_tone_ward", "empty hospital room ambience",
         ["hospital room tone night", "empty patient room roomtone", "quiet empty room interior building"],
         ["hospital", "room", "ward", "night", "quiet"], -40,
         note="Habitación de hospital vacía de noche: aire quieto y un murmullo lejano del edificio. Sin "
              "pitidos, voces ni pasos. Casi no debe oírse."),
    tone("amb_tone_corridor", "empty hospital corridor ambience",
         ["long corridor room tone", "empty hallway building ambience night", "hospital hallway roomtone"],
         ["hospital", "corridor", "hallway", "hall", "long", "night"], -39,
         note="Pasillo largo de hospital vacío: aire con algo de cola y un murmullo de ventilación o maquinaria "
              "al fondo. Sin anuncios, voces, carros ni pasos."),
    tone("amb_tone_tiled", "bathroom room tone",
         ["tiled bathroom ambience quiet", "public toilet empty ambience", "shower room roomtone"],
         ["bathroom", "toilet", "tiled", "tiles", "washroom", "quiet"], -40,
         avoid=["flush", "shower", "running", "hand-dryer", "dryer", "pee"],
         note="Baño alicatado vacío: tono brillante y reflectante, quizá un hilo de agua muy lejos. Sin cisterna, "
              "secamanos ni ducha."),
    tone("amb_tone_or", "operating room ambience empty",
         ["surgery room tone hospital", "clinic treatment room ambience quiet", "laboratory room tone hum"],
         ["operating", "surgery", "theatre", "hospital", "clinic", "laboratory", "sterile"], -40,
         avoid=["monitor", "surgeon", "drill", "saw", "dentist"],
         note="Quirófano o sala clínica vacía: aire frío y limpio con un zumbido técnico muy tenue. Sin pitidos "
              "de monitor, voces ni instrumental."),
    tone("amb_tone_hall", "empty lobby ambience large room",
         ["empty hall reverberant room tone", "large empty building interior ambience", "atrium room tone night"],
         ["lobby", "hall", "large", "atrium", "reception", "reverb", "night"], -39,
         avoid=["announcement", "crowd", "shop", "station", "airport", "mall"],
         note="Vestíbulo o recepción grande y vacía: aire amplio con cola, el edificio que respira. Sin gente, "
              "anuncios ni tiendas."),
    tone("amb_tone_archive", "quiet library room tone",
         ["archive room ambience quiet", "small office room tone night", "storage room quiet roomtone"],
         ["library", "archive", "office", "storage", "quiet", "room"], -42,
         avoid=["typing", "keyboard", "printer", "pages", "phone"],
         note="Archivo de papel: sala apagada y seca (madera, papel), casi silencio con un murmullo grave. Sin "
              "teclados, impresoras ni páginas."),
    tone("amb_tone_stairwell", "stairwell ambience concrete",
         ["staircase room tone reverb", "concrete stairwell air wind", "emergency stairs ambience building"],
         ["stairwell", "staircase", "stairs", "concrete", "reverb", "echo"], -38,
         avoid=["climbing", "walking", "running", "steps", "elevator"],
         note="Hueco de escalera de hormigón: aire que sube y baja, un silbido grave muy suave y mucha cola. Sin "
              "pasos ni puertas."),
    tone("amb_tone_basement", "basement room tone",
         ["cellar ambience low rumble", "underground concrete room tone", "underground parking ambience quiet"],
         ["basement", "cellar", "underground", "concrete", "rumble", "low", "bunker"], -37,
         avoid=["cars", "engine", "dripping", "water"],
         note="Sótano de hormigón grande: retumbo grave y constante de maquinaria lejana, aire cerrado. Sin "
              "coches, motores cerca ni goteos (los goteos van aparte)."),
    tone("amb_tone_morgue", "cold storage room ambience",
         ["cold room hum quiet", "walk-in freezer interior ambience", "mortuary room tone"],
         ["cold", "storage", "freezer", "room", "hum", "morgue", "mortuary"], -40,
         avoid=["ice", "kitchen", "restaurant"],
         note="Sala fría de azulejo y acero: siseo frío y zumbido muy bajo (la nevera grande va aparte). Sin "
              "puertas ni cocina."),
    tone("amb_building_hum", "building electrical hum distant",
         ["mains hum building ambience low", "distant machinery hum building", "large building hvac rumble distant"],
         ["hum", "mains", "electrical", "machinery", "distant", "building", "low"], -42,
         avoid=["guitar", "amp", "fluorescent"], af="highpass=f=35,lowpass=f=1800",
         note="Con corriente: el edificio vivo, un zumbido grave y lejano de red eléctrica y máquinas (filtrado). "
              "Muy bajo; que se note cuando se va la luz."),
    tone("amb_wind_building", "wind outside building interior",
         ["wind heard from inside house", "wind against windows interior muffled", "storm wind indoors muffled"],
         ["wind", "inside", "indoors", "interior", "muffled", "window", "house"], -40,
         avoid=["thunder", "microphone", "mic", "trees", "leaves", "chimes"], af="highpass=f=40,lowpass=f=2500",
         note="Viento fuera del edificio oído desde dentro: presión sorda que sube y baja, sin silbidos agudos ni "
              "lluvia. Sin corriente se oye más (nada lo tapa)."),
    tone("amb_pa_hum", "speaker hum hiss",
         ["pa system idle hum", "loudspeaker noise floor hiss", "amplifier hum hiss idle"],
         ["speaker", "hum", "hiss", "pa", "amplifier", "idle", "noise"], -46,
         avoid=["feedback", "guitar", "announcement", "crackle"], af="highpass=f=45,lowpass=f=6000",
         note="Los altavoces de megafonía del techo encendidos sin nadie al micro: siseo y zumbido de 50 Hz "
              "mínimos. En el límite de lo audible."),
]

AMBIENT_MORE = [
    e("amb_clock_tick", "wall clock ticking",
      ["clock tick tock loop", "old clock ticking close", "analog wall clock"], [5, 300],
      ["clock", "tick", "ticking", "tock", "wall", "analog"], -36,
      avoid=["alarm", "chime", "bell", "cuckoo", "music", "watch", "fast"], loop=True, max_len=12, crossfade=0.05,
      ideal=30, note="Reloj de pared analógico: tic-tac seco y regular, sin campanadas. Bucle exacto (sin un "
                     "fundido que borre un tic)."),
    e("amb_wind_window_loop", "wind whistling through window gap",
      ["wind whistle window loop", "draft through window crack", "wind howling window interior"], [8, 300],
      ["wind", "whistle", "window", "draft", "gap", "howl"], -36,
      avoid=["storm", "rain", "thunder", "microphone", "mic", "trees", "leaves", "chimes"], loop=True, max_len=20,
      crossfade=2.5, ideal=60,
      note="Silbido de viento por la rendija de una ventana rota, constante y suave (las ráfagas van aparte)."),
    e("amb_lamp_transformer", "transformer hum",
      ["electrical transformer buzz loop", "lamp ballast hum", "power supply hum close"], [5, 200],
      ["transformer", "hum", "ballast", "electric", "electrical", "buzz"], -36,
      avoid=NO_VOICE + ["guitar", "amp", "music", "spark", "zap", "fluorescent"], loop=True, max_len=12,
      crossfade=1.2, ideal=25, af="highpass=f=60",
      note="Transformador de la lámpara del quirófano con corriente: zumbido de 100 Hz con armónicos, constante."),
    e("amb_elevator_shaft", "elevator shaft ambience",
      ["lift shaft wind air", "elevator shaft room tone", "air moving in shaft hollow"], [8, 300],
      ["elevator", "lift", "shaft", "air", "wind", "hollow"], -36,
      avoid=["ding", "music", "voice", "door", "bell", "announcement"], loop=True, max_len=20, crossfade=2.5,
      ideal=60, af="highpass=f=35",
      note="Aire que corre por el hueco vacío del ascensor: soplido hueco y grave, algún roce metálico lejano."),
    e("amb_pump_loop", "water pump running",
      ["pump motor hum loop", "basement water pump", "circulation pump running"], [8, 300],
      ["pump", "motor", "water", "running", "basement", "hum"], -33,
      avoid=NO_VOICE + ["car", "fuel", "bicycle", "start", "stop"], loop=True, max_len=16, crossfade=1.5,
      ideal=40, note="Bomba de agua del sótano en marcha (con corriente): motor eléctrico grave y el agua dentro, "
                     "constante."),
    e("amb_drip_puddle_loop", "water dripping puddle echo",
      ["drips in basement echo", "dripping water concrete loop", "slow drips cave puddle"], [8, 300],
      ["drip", "dripping", "puddle", "echo", "basement", "concrete", "water"], -32,
      avoid=["rain", "stream", "river", "faucet", "tap", "sink", "shower", "music"], loop=True, max_len=18,
      crossfade=0.6, ideal=40,
      note="Gotas que caen de una tubería a un charco en suelo de hormigón, espaciadas e irregulares, con eco."),
    e("amb_concrete_groan", "concrete structure creak deep",
      ["building settling groan low", "deep structural creak", "heavy beam stress groan"], [0.8, 8],
      ["concrete", "structure", "creak", "groan", "deep", "settling", "beam"], -24,
      avoid=["door", "ship", "boat", "rope", "music", "monster"], max_len=3.5, fade_out=0.5, af="lowpass=f=4000",
      note="El hormigón y las vigas del sótano que se asientan: crujido grave y largo, sin chirrido agudo."),
    e("amb_drip_metal", "water drop on metal",
      ["drip on metal bucket", "drop hitting tin", "water droplet metal plate"], [0.1, 4],
      ["drip", "drop", "metal", "bucket", "tin", "water"], -26,
      avoid=["rain", "tap", "faucet", "music"], max_len=1.2,
      note="Una gota que cae sobre chapa o en un cubo metálico: tic metálico con algo de resonancia."),
    e("amb_door_far", "distant door closing building",
      ["door close far away echo", "door shut down the hall", "distant door slam soft reverb"], [0.6, 6],
      ["door", "distant", "far", "close", "closing", "echo", "hall"], -26,
      avoid=["car", "truck", "garage", "doorbell", "knock"], max_len=3.0, fade_out=0.6,
      note="Una puerta que se cierra lejos, en otra parte del edificio: golpe sordo con cola. No un portazo."),
    e("amb_door_swing_far", "door creaking slowly distant",
      ["old door swinging creak", "door moving in draft creak", "door hinge slow creak far"], [1, 8],
      ["door", "creak", "hinge", "swing", "slow", "distant"], -27,
      avoid=["slam", "car", "knock"], max_len=3.5, fade_in=0.2, fade_out=0.6, af="lowpass=f=5000",
      note="Una puerta que se mueve sola con la corriente, lejos: chirrido lento de bisagra, sin golpe."),
    e("amb_steps_distant", "footsteps distant hallway reverb",
      ["footsteps far corridor echo", "someone walking far away building", "slow footsteps hard floor distant"],
      [1.5, 12], ["footsteps", "distant", "far", "corridor", "hallway", "echo", "reverb", "walking"], -29,
      avoid=["running", "heels", "snow", "gravel", "grass", "stairs"], max_len=4.5, fade_in=0.4, fade_out=1.0,
      af="lowpass=f=3500",
      note="Tres a seis pasos lentos y lejanos en suelo duro, con eco; que no se sepa dónde. Sin tacones."),
    e("amb_settle_thump", "building thump distant",
      ["low thud in building", "heavy thump wall distant", "house settling thump"], [0.3, 5],
      ["thump", "thud", "bump", "building", "low", "distant", "wall"], -25,
      avoid=["kick", "drum", "bass", "music", "punch", "heart"], max_len=2.5, fade_out=0.6, af="lowpass=f=2500",
      note="Un golpe grave y sordo en algún sitio del edificio (algo pesado que se asienta), sin ataque seco."),
    e("amb_settle_crack", "plaster crack wall",
      ["wall cracking", "wood crack settling", "ceiling crack creak"], [0.2, 4],
      ["crack", "plaster", "wall", "settling", "ceiling", "creak"], -25,
      avoid=["whip", "gun", "ice", "bone", "knuckles", "fire", "fireworks"], max_len=1.8, fade_out=0.3,
      note="Un chasquido seco de yeso o madera de la estructura (cambio de temperatura). Corto."),
    e("amb_vent_rattle", "air vent grille rattle",
      ["vent cover rattling", "ventilation grate rattle", "metal grille vibrating draft"], [0.4, 6],
      ["vent", "grille", "grate", "rattle", "ventilation", "metal"], -26,
      avoid=["car", "engine", "music"], max_len=2.5, fade_out=0.4,
      note="La rejilla de ventilación que vibra y traquetea un momento con una corriente de aire."),
    e("amb_duct_pop", "metal duct popping",
      ["ductwork expansion pop", "hvac duct bang thermal", "sheet metal pop"], [0.2, 4],
      ["duct", "ductwork", "pop", "metal", "expansion", "hvac", "bang"], -25,
      avoid=["gun", "balloon", "cork", "music", "bubble"], max_len=1.8, fade_out=0.4,
      note="Un conducto de chapa que chasquea al dilatarse: «bong» metálico, hueco y corto, dentro del techo."),
    e("amb_ballast_tick", "fluorescent light ticking",
      ["fluorescent starter click", "neon tube tick buzz", "ballast click flicker"], [0.2, 5],
      ["fluorescent", "tick", "click", "starter", "ballast", "neon"], -30,
      avoid=["guitar", "music", "switch", "clock"], max_len=1.5, fade_out=0.2,
      note="Un tubo fluorescente que hace tic o chisporrotea un instante (cebador). Con corriente."),
    e("amb_window_rattle", "window rattling wind",
      ["window pane rattle", "loose window shaking", "window frame rattle gust"], [0.5, 8],
      ["window", "rattle", "pane", "glass", "frame", "wind", "shaking"], -26,
      avoid=["break", "smash", "rain", "thunder", "car"], max_len=3.0, fade_out=0.5,
      note="El cristal flojo de una ventana que tiembla en su marco con una ráfaga. Sin romperse."),
    e("amb_trolley_far", "hospital trolley wheels distant",
      ["squeaky trolley rolling far", "gurney wheels corridor", "cart wheels rolling hallway echo"], [1, 10],
      ["trolley", "gurney", "cart", "wheels", "rolling", "squeak", "hospital"], -28,
      avoid=["supermarket", "shopping", "luggage", "suitcase", "skate", "train"], max_len=4.0, fade_in=0.4,
      fade_out=1.0, af="lowpass=f=3500",
      note="Una camilla o un carro con una rueda que chirría, rodando lejos por un pasillo, y se para."),
    e("amb_glass_tinkle", "glass bottles rattling",
      ["glass vials clinking shelf", "bottles vibrating tinkle", "medicine bottles clink"], [0.3, 4],
      ["glass", "bottles", "vials", "clink", "tinkle", "rattle"], -28,
      avoid=["cheers", "toast", "break", "smash", "pour", "beer", "wine", "music"], max_len=1.6, fade_out=0.3,
      note="Frascos de cristal de un estante que tintinean un instante (vibración). Sin brindis ni roturas."),
    e("amb_relay_click", "electrical relay click",
      ["relay switching clack", "contactor click electrical panel", "industrial relay clunk"], [0.05, 3],
      ["relay", "click", "contactor", "switch", "electrical", "clack"], -26,
      avoid=["mouse", "keyboard", "pen", "camera", "music"], max_len=0.8,
      note="Un relé o contactor del cuadro eléctrico que salta: clac metálico seco. Con corriente."),
    e("amb_pipe_tick", "pipes ticking",
      ["heating pipe tick expansion", "metal pipe creaking ticking", "radiator ticking"], [0.5, 8],
      ["pipe", "pipes", "tick", "ticking", "expansion", "radiator", "heating"], -28,
      avoid=["clock", "music", "drum"], max_len=2.5, fade_out=0.4,
      note="Tictac irregular de una tubería metálica que se contrae: dos a cinco golpecitos."),
    e("amb_chain_rattle", "hanging chain rattle",
      ["chain swinging metal", "chains rattling slow", "chain hoist rattle"], [0.5, 6],
      ["chain", "chains", "rattle", "metal", "hanging", "swing"], -26,
      avoid=["bicycle", "dog", "prisoner", "music", "jail"], max_len=2.5, fade_out=0.5,
      note="Una cadena colgada (polipasto del taller) que se balancea y tintinea un poco, sin golpes fuertes."),
    e("amb_morgue_door_creak", "metal cabinet door creak",
      ["fridge door creak metal", "steel door creaking slowly", "metal hatch creak"], [0.6, 6],
      ["metal", "door", "creak", "steel", "cabinet", "hatch"], -25,
      avoid=["slam", "car", "gate"], max_len=2.8, fade_out=0.5,
      note="La puerta metálica de una cámara de la morgue que cede un poco y cruje sola."),
    e("amb_pa_crackle", "speaker crackle short",
      ["loudspeaker pop crackle", "pa system crackle", "intercom click static short"], [0.1, 4],
      ["speaker", "crackle", "pop", "pa", "intercom", "static"], -30,
      avoid=["voice", "announcement", "feedback", "music", "vinyl", "fire"], max_len=1.2, fade_out=0.2,
      note="Un chasquido de estática de los altavoces del techo (con corriente). Muy corto."),
    e("amb_rats_wall", "rats scratching inside wall",
      ["mice scurrying in walls", "rodent scratching ceiling", "rats running attic"], [1, 10],
      ["rats", "rat", "mice", "mouse", "rodent", "scratching", "wall", "scurry"], -29,
      avoid=["toy", "cat", "dog", "music"], max_len=3.5, fade_in=0.2, fade_out=0.6, af="lowpass=f=6000",
      note="Ratas o ratones que corretean y arañan dentro de la pared o del falso techo."),
    e("amb_pigeon_flutter", "pigeon wings flapping",
      ["pigeon flutter indoor", "bird wings flap building", "pigeons taking off"], [0.5, 6],
      ["pigeon", "pigeons", "wings", "flap", "flutter", "flapping"], -26,
      avoid=["coo", "song", "chirp", "tweet", "park", "city", "traffic", "music"], max_len=2.5, fade_out=0.5,
      note="Una paloma que aletea de golpe en el alféizar o en el hueco de la escalera. Sin arrullos ni ciudad."),
    e("amb_generator_cough", "engine sputter",
      ["generator misfire", "diesel engine stutter", "engine hiccup idle"], [0.4, 6],
      ["engine", "generator", "sputter", "misfire", "stutter", "diesel"], -22,
      avoid=["car", "start", "starting", "rev", "motorcycle", "lawn", "chainsaw"], max_len=2.5, fade_out=0.5,
      note="El generador que tose o falla un instante y sigue en marcha. Con corriente, en el sótano."),
    e("amb_debris_fall", "plaster debris falling",
      ["small debris falling floor", "dust and plaster crumbling", "ceiling debris fall"], [0.4, 6],
      ["debris", "plaster", "rubble", "falling", "crumble", "dust"], -27,
      avoid=["explosion", "demolition", "glass", "music"], max_len=2.2, fade_out=0.4,
      note="Trocitos de yeso que se desprenden del techo y caen al suelo, poca cosa."),
]

# --- objetos: usar, rasgar, fabricar --------------------------------------------------------------
ITEMS = [
    e("use_battery_insert", "batteries insert flashlight",
      ["battery compartment close click", "aa batteries handling"], [0.6, 4], ["battery", "batteries", "flashlight"], -22,
      max_len=2.0, note="Abrir la tapa, pilas que encajan y clic al cerrar."),
    e("use_bandage_apply", "bandage wrap",
      ["gauze unroll", "wrapping bandage arm"], [0.6, 5], ["bandage", "gauze", "wrap"], -22,
      max_len=2.0, note="Venda que se desenrolla y se ciñe."),
    e("use_pills_swallow", "pills bottle open",
      ["pill bottle cap open shake", "taking pills"], [0.6, 5], ["pills", "bottle", "cap", "medicine"], -22,
      max_len=2.0, avoid=["female"], note="Abrir el bote, sacar pastillas (y tragar)."),
    e("use_syringe_inject", "syringe",
      ["syringe cap plunger", "injection needle foley"], [0.3, 4], ["syringe", "needle", "injection"], -24,
      max_len=1.4, note="Capuchón de jeringuilla y émbolo."),
    e("use_tourniquet_tighten", "cloth twist tighten",
      ["tightening strap", "fabric pull tight"], [0.4, 4], ["cloth", "strap", "tighten", "fabric"], -24,
      max_len=1.4, note="Tela que se retuerce y se aprieta."),
    e("cloth_tear", "fabric tear",
      ["cloth rip", "tearing cotton"], [0.3, 3], ["tear", "rip", "fabric", "cloth"], -20,
      max_len=1.0, note="Tela de algodón que se rasga de un tirón."),
    e("craft_cloth", "cloth handling foley",
      ["fabric folding knot", "cloth movement"], [0.4, 4], ["cloth", "foley", "fabric"], -24,
      max_len=1.4, note="Manipular tiras de tela, hacer un nudo."),
    e("craft_combine", "small objects handling",
      ["foley handling items", "fiddling small objects"], [0.3, 3], ["foley", "handling"], -24,
      max_len=1.0, note="Juntar dos objetos pequeños."),
    e("craft_generic", "tinkering small metal parts",
      ["fiddling with tools", "small mechanism handling"], [0.3, 3], ["foley", "tinker", "metal", "tools"], -24,
      max_len=1.0, note="Trastear con piezas pequeñas."),
]

# --- custodia: inv_<material>_<acción> e inv_<acción> ----------------------------------------------
# Material -> (qué es en el juego, sustantivo para buscar, alternativa, etiquetas).
MATERIALS = {
    "metal_heavy": ("palanca, llave inglesa, tubo", "crowbar", "heavy metal tool", ["metal", "heavy", "iron", "crowbar", "wrench"]),
    "metal_small": ("bisturí, tijeras, piezas", "small metal object", "scissors metal", ["metal", "small", "scissors"]),
    "keys": ("llaves", "keys", "keychain", ["keys", "key", "keychain", "jingle"]),
    "cloth": ("ropa, tela, vendas", "clothes", "fabric cloth", ["cloth", "clothes", "fabric", "cotton"]),
    "paper": ("documentos, notas", "paper", "paper sheet", ["paper", "sheet"]),
    "plastic": ("cajas y objetos de plástico", "plastic box", "plastic object", ["plastic", "box"]),
    "glass": ("frascos, viales", "glass bottle", "glass vial", ["glass", "bottle", "vial", "jar"]),
    "pills": ("botes de pastillas", "pill bottle", "pills rattle", ["pills", "bottle", "rattle", "medicine"]),
    "battery": ("pilas", "batteries", "aa battery", ["battery", "batteries"]),
    "tool": ("linterna, destornillador", "flashlight", "screwdriver", ["flashlight", "torch", "screwdriver", "tool"]),
    "rubber": ("botas, guantes de goma", "rubber boots", "rubber gloves", ["rubber", "boots", "gloves", "boot"]),
    "ceramic": ("fusible cerámico, taza", "ceramic", "porcelain cup", ["ceramic", "porcelain", "cup"]),
}
# Acción -> (búsqueda, alternativa, duración máx. del recorte, nivel, qué es).
ACTIONS = {
    "pick": ("pick up", "grab", 0.5, -26, "cogerlo de la bandeja"),
    "place": ("put down table", "set down", 0.5, -26, "dejarlo en la bandeja"),
    "rotate": ("handling", "foley", 0.35, -29, "girarlo en la mano (suave)"),
    "equip": ("pocket", "put on", 0.6, -26, "equiparlo (ponérselo o guardarlo a mano)"),
    "unequip": ("take out", "take off", 0.6, -26, "quitárselo"),
    "drop": ("drop floor", "fall on floor", 0.9, -23, "tirarlo al suelo"),
}
WEARABLE = {"cloth": ("put on clothes", "take off clothes"), "rubber": ("put on boots", "take off boots")}


# --- elecciones revisadas a mano -----------------------------------------------------------------
# Ids de Freesound escogidos tras leer título, etiquetas, descripción, duración y licencia (solo CC0
# o CC BY). Mandan sobre lo que eligió `fetch` solo. Motivo entre paréntesis cuando sustituye a otro.
REVIEWED_PICKS = {
    # sin candidatos con la consulta original (demasiado concreta para el buscador)
    "bed_creak": 655947,             # muelles de cama que crujen
    "heavy_drag": 453347,            # pieza metálica pesada arrastrada por el suelo
    "breath_strain_male": 554928,    # jadeo de esfuerzo
    "breath_run_male": 467369,       # hombre jadeando tras correr (CC BY)
    "bare_feet_floor": 197402,       # pies descalzos en baldosa
    "amb_wind_gust": 67707,          # viento que silba en una ventana (CC BY)
    "amb_elevator_cables": 326487,   # viento y mecanismos en un hueco de ascensor
    "scare_fall": 438329,            # bandeja metálica que cae y repiquetea
    "scare_wall_knock": 795281,      # golpes en la pared desde la habitación de al lado
    "scare_steps_above": 210592,     # pasos del vecino de arriba, a través del techo
    "use_battery_insert": 765865,    # cambiar las pilas de un mando
    "inv_metal_heavy_pick": 452585,  # coger una palanca
    "inv_metal_heavy_place": 198299, # manipular una llave grifa (metal pesado)
    "inv_metal_heavy_equip": 198299,
    "inv_metal_heavy_unequip": 452585,
    "inv_metal_heavy_drop": 189221,  # palanca que cae
    "inv_plastic_place": 637747,     # teléfono de plástico dejado en la mesa
    # sustituyen a elecciones automáticas que no encajaban
    "generator_start": 434660,       # motor de tirón que tose y arranca (era un cortacésped que no arranca)
    "battery": 627837,               # manipular pilas (era un juguete electrónico sintético)
    "whisper": 198434,               # susurros ininteligibles (CC BY; el anterior decía una frase reconocible)
    "amb_vent_loop": 848969,         # rejilla de aire acondicionado (era un puente de nave con pitidos)
    "amb_pipe_knock": 104370,        # radiador de hierro golpeado (era un golpe de destrucción)
    "amb_spark_crackle": 849772,     # chispas de un cable (CC BY; era un efecto de robot)
    "scare_wheelchair": 559469,      # rueda pequeña oxidada (era un columpio)
    "scare_breath": 151920,          # exhalación de hombre (el anterior estaba mal valorado)
    "title_tube_flicker": 484157,    # fluorescente parpadeando (el anterior estaba mal valorado)
    "music_menu_drone": 631650,      # dron de terror lento (el anterior tenía golpes rítmicos)
    "use_syringe_inject": 458423,    # émbolo de jeringuilla (era un descorche)
    "use_pills_swallow": 272439,     # abrir un bote de pastillas
    "inv_glass_place": 610391,       # vaso sobre una mesa de madera (era agua agitándose)
    "inv_glass_unequip": 219841,     # manipular una botella (CC BY; era una botella rompiéndose)
    "inv_glass_drop": 594443,        # botella vacía que cae sin romperse (era una botella rompiéndose)
    "inv_plastic_equip": 513770,     # manipular plástico (era un efecto raro)
    "inv_plastic_unequip": 513770,   # (era un tambor)
    "inv_battery_pick": 627837,      # manipular pilas (era una llave de impacto)
    "inv_battery_place": 627837,     # (era un billete rasgado)
    "inv_battery_rotate": 627837,    # (era un juguete)
    "inv_battery_equip": 627837,
    "inv_battery_unequip": 627837,
    "inv_tool_drop": 533954,         # destornillador que cae (CC BY; era un clic de linterna)
    "inv_rubber_pick": 429404,       # sacar un guante de látex (eran pasos en hierba)
    "inv_rubber_place": 704921,      # guante de goma apretado
    "inv_rubber_equip": 266649,      # ponerse guantes (CC BY)
    "inv_rubber_unequip": 631973,    # quitarse guantes de látex médicos
    "inv_rubber_drop": 405112,       # bota que golpea el suelo
    "inv_ceramic_pick": 478580,      # coger y dejar una taza (el anterior se rompía)
    "inv_ceramic_drop": 495645,      # taza que golpea la madera (era una ficha de juego)
    "inv_paper_place": 432917,       # papel que cae sobre la mesa (CC BY; era dibujar con un boli)
    "inv_paper_drop": 486377,        # libreta que cae
    "inv_place": 873911,             # dejar un objeto en la encimera
    "inv_drop": 339363,              # objeto de madera que cae al suelo
    "inv_rotate": 798838,            # roce de tela al manipular (CC BY; era una bolsa de comida)
    "inv_equip": 416286,             # rebuscar en un bolsillo (era un efecto de juego)
    "inv_unequip": 798839,           # roce de tela (CC BY; era un motor de nave espacial)
}


def inventory() -> list[dict]:
    out: list[dict] = []
    for mat, (what, noun, alt_noun, tags) in MATERIALS.items():
        for act, (verb, alt_verb, length, level, desc) in ACTIONS.items():
            query, alt = f"{noun} {verb}", [f"{alt_noun} {verb}", f"{noun} {alt_verb}", f"{noun} foley"]
            if mat in WEARABLE and act in ("equip", "unequip"):
                query = WEARABLE[mat][0 if act == "equip" else 1]
            out.append(e(f"inv_{mat}_{act}", query, alt, [0.05, 4], tags + ["foley"], level,
                         max_len=length, fade_out=min(0.08, length * 0.25),
                         avoid=["music", "ambience", "voice"] + (["car", "door"] if mat == "keys" else []),
                         note=f"{what}: {desc}. Corto y seco, sin sala."))
    for act, (verb, alt_verb, length, level, desc) in ACTIONS.items():
        out.append(e(f"inv_{act}", f"item {verb} foley", [f"object {alt_verb}", "foley handling"], [0.05, 4],
                     ["foley", "handling"], level, max_len=length, fade_out=min(0.08, length * 0.25),
                     avoid=["music", "ambience", "voice"], note=f"Genérico para cualquier material: {desc}."))
    return out


# Búsquedas más amplias para los que no dieron ningún candidato en la primera pasada
# (consultas de 1-2 palabras y duraciones holgadas). Se aplican encima de la entrada original.
BROADER: dict[str, dict] = {
    "amb_tone_hall": {"query": "lobby ambience", "alt": ["hall room tone", "large room ambience"], "duration": [10, 600]},
    "amb_tone_morgue": {"query": "cold room ambience", "alt": ["refrigerator room hum", "basement room tone"], "duration": [10, 600]},
    "amb_concrete_groan": {"query": "building creak", "alt": ["structure creak", "wood creak low"], "duration": [0.5, 20]},
    "amb_drip_metal": {"query": "drip metal", "alt": ["water drop metal", "drip tin"], "duration": [0.2, 20]},
    "amb_door_far": {"query": "door close distant", "alt": ["door slam far", "door closing reverb"], "duration": [0.5, 15]},
    "amb_steps_distant": {"query": "footsteps distant", "alt": ["footsteps corridor", "footsteps echo"], "duration": [1, 30]},
    "amb_settle_thump": {"query": "thump wall", "alt": ["knock thud", "bump wood"], "duration": [0.2, 10]},
    "amb_vent_rattle": {"query": "vent rattle", "alt": ["metal rattle", "grate rattle"], "duration": [0.3, 20]},
    "amb_trolley_far": {"query": "trolley squeak", "alt": ["cart wheels", "squeaky wheel"], "duration": [0.5, 30]},
    "amb_pipe_tick": {"query": "pipe ticking", "alt": ["metal tick", "radiator ticking"], "duration": [0.2, 30]},
    "amb_rats_wall": {"query": "rats", "alt": ["mouse scratching", "rodent scratching"], "duration": [0.5, 60]},
    "combat_pipe_flesh": {"query": "punch body", "alt": ["hit meat", "body hit"], "duration": [0.1, 5]},
    "combat_saw": {"query": "hacksaw", "alt": ["saw cutting", "hand saw"], "duration": [0.3, 20]},
    "enfermero_breath": {"query": "monster breathing", "alt": ["creature breath", "heavy breathing"], "duration": [1, 30]},
    "enfermero_growl": {"query": "zombie growl", "alt": ["monster growl", "creature groan"], "duration": [0.3, 10]},
    "enfermero_scream": {"query": "zombie scream", "alt": ["monster scream", "creature shriek"], "duration": [0.3, 10]},
    "enfermero_drag_steps": {"query": "foot drag", "alt": ["dragging feet", "limping footsteps"], "duration": [0.5, 30]},
    "combat_transition": {"query": "vhs glitch", "alt": ["tape glitch", "static burst"], "duration": [0.2, 10]},
    "inv_category": {"query": "paper click", "alt": ["folder click", "cardboard tap"], "duration": [0.03, 5]},
}


def main() -> None:
    old = {}
    if MANIFEST.exists():
        old = {x["name"]: x for x in json.loads(MANIFEST.read_text(encoding="utf-8"))["sounds"]}
    entries = WORLD + PLAYER + AMBIENT + AMBIENT_ROOMS + AMBIENT_MORE + HORROR + COMBAT + UI + MUSIC + ITEMS + inventory()
    for x in entries:
        x.update(BROADER.get(x["name"], {}))
    names = [x["name"] for x in entries]
    assert len(names) == len(set(names)), "nombres repetidos"
    assert set(REVIEWED_PICKS) <= set(names), "REVIEWED_PICKS con nombres que no existen"
    for x in entries:
        # Un `pick` fijado a mano aquí (revisado) manda sobre el elegido automáticamente.
        if x["name"] in REVIEWED_PICKS:
            x["pick"] = REVIEWED_PICKS[x["name"]]
        elif "pick" not in x and old.get(x["name"], {}).get("pick"):
            x["pick"] = old[x["name"]]["pick"]
    MANIFEST.write_text(json.dumps({"_doc": DOC, "sounds": entries}, indent=1, ensure_ascii=False) + "\n",
                        encoding="utf-8")
    print(f"{len(entries)} entradas en {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
