"""Rampas de color de la muestra 2D: pocas tonalidades, desaturadas y sucias.

Cada rampa va de la sombra más oscura a la luz más clara. El blanco hueso es lo más claro de la
pantalla (guía estética); ninguna rampa llega al blanco puro ni al negro puro.
"""

from px2d import ramp

# --- piel ---
ramp("skin", ["#2b1f22", "#56444a", "#837068", "#a6958a", "#c1b3a2"])  # paciente: pálido, cetrino
ramp("scalp", ["#2a2224", "#4b3f3f", "#6f625c", "#8f8277", "#a89a8b"])  # rapado: piel con sombra de pelo
ramp("skin_grey", ["#14151c", "#272a35", "#41464f", "#5f6569", "#7d827f"])  # enfermero: gris azulado
ramp("vein", ["#141420", "#232236", "#363349"])
ramp("socket", ["#0d080b", "#1f1317", "#352227"])
ramp("lips", ["#2c1a1d", "#4a2b2d", "#6a4040"])

# --- tela ---
ramp("gown", ["#25272a", "#45474a", "#6b6c69", "#908e85", "#b1ad9f"])  # bata de paciente, hueso sucio
ramp("uniform", ["#262728", "#4b4b48", "#76746c", "#a29d8f", "#c4bead"])  # uniforme blanco de enfermería
ramp("mask_cloth", ["#1f2624", "#3a4642", "#5a6862", "#7d8a82"])  # mascarilla verde agua sucia
ramp("stain", ["#382f22", "#5a4c33", "#786945"])
ramp("dirt", ["#1d1713", "#352a22", "#4f4034"])

# --- sangre, carne, hueso ---
ramp("blood", ["#1c070a", "#430f16", "#6c2125", "#8c3631"])
ramp("flesh", ["#24090d", "#4f141a", "#7a2a29", "#9b4a3c", "#b06a52"])
ramp("bone", ["#3b352c", "#6a6152", "#978b76", "#bdb19a"])
ramp("thread", ["#0d0a0d", "#272024", "#3c3336"])

# --- materiales duros ---
ramp("metal", ["#17181b", "#34373b", "#5b5f63", "#8e9090", "#c1bfb4"])
ramp("rust", ["#26150f", "#4a2a1a", "#6e4428"])
ramp("porcelain", ["#3a3832", "#6e6a60", "#a19b8c", "#c9c2b0", "#ddd5c2"])
ramp("glass_dark", ["#0b0a0d", "#1a1418", "#2e2026", "#56464c"])
ramp("band", ["#363c40", "#737d80", "#adb3b0"])  # pulsera de plástico
ramp("tube", ["#2a302f", "#56625f", "#8a9893"])  # vía/goma traslúcida
ramp("tube_dark", ["#0f0b0e", "#2a1b22", "#4c3038"])  # tubo con líquido oscuro
ramp("paint", ["#1e2522", "#36423d", "#53615a", "#71807a", "#8d9a92"])  # taquilla verde gris
ramp("floor", ["#17171a", "#25252a", "#36363a", "#4a4947", "#5d5b56"])
ramp("tile", ["#1a1e1e", "#2c3332", "#424b49", "#5b6461", "#737b76"])
ramp("plaster", ["#1f1d1b", "#36322d", "#504a41", "#6c6456", "#887e6c"])
ramp("mold", ["#151a12", "#232c1c", "#36422a"])
