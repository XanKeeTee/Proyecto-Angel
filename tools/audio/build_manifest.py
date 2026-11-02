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


def main() -> None:
    old = {}
    if MANIFEST.exists():
        old = {x["name"]: x for x in json.loads(MANIFEST.read_text(encoding="utf-8"))["sounds"]}
    entries = WORLD + PLAYER + AMBIENT + HORROR + UI + MUSIC + ITEMS + inventory()
    names = [x["name"] for x in entries]
    assert len(names) == len(set(names)), "nombres repetidos"
    for x in entries:
        if old.get(x["name"], {}).get("pick"):
            x["pick"] = old[x["name"]]["pick"]
    MANIFEST.write_text(json.dumps({"_doc": DOC, "sounds": entries}, indent=1, ensure_ascii=False) + "\n",
                        encoding="utf-8")
    print(f"{len(entries)} entradas en {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
