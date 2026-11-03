"""Paleta de la cuarta muestra (tinta y color plano): 2-4 tonos por material, de sombra profunda a luz."""

from ink import hexrgb


def _r(*hs: str):
    return [hexrgb(h) for h in hs]


PAL = {
    # enfermero
    "nskin": _r("#191c23", "#323840", "#565d5d", "#838880"),
    "uniform": _r("#2b2923", "#5b5749", "#958e7a", "#c4bca5"),
    "porcelain": _r("#47433a", "#8b8474", "#cbc3ae", "#ebe4d1"),
    "mask_cloth": _r("#1c2824", "#35473e", "#576c60", "#7c8f81"),
    "metal": _r("#1c1f23", "#3d4349", "#7a8080", "#c6c7bd"),
    "glass": _r("#2f3937", "#6e7d76", "#b7c3b9"),
    "liquid": _r("#0b0408", "#250d16", "#481a27"),
    "bone": _r("#6b614d", "#ada283", "#dad0b4"),
    "flesh": _r("#3b1117", "#6f262a", "#a25248", "#c27a64"),
    "eye": _r("#29201a", "#a99d82", "#e6dec6"),
    "nail": _r("#1b1614", "#3a3029"),
    "vein": _r("#1c1a32", "#2c2a48"),
    "rust": _r("#47230f", "#764224", "#9a6438"),
    # comunes
    "blood": _r("#2b090e", "#5a131a", "#8a2923"),
    "dry": _r("#33130f", "#55261d", "#6e3a2a"),
    "rim": _r("#5e0f17", "#7c1a20"),
    "thread": _r("#171114",),
    # protagonista
    "skin": _r("#2c1c21", "#5a423e", "#8c6f5c", "#b4977d"),
    "scalp": _r("#2f2627", "#5c4d47", "#85725f", "#a28e78"),
    "gown": _r("#1e262e", "#3b4853", "#68757e", "#9aa4a2"),
    "brief": _r("#15171e", "#292d36"),
    "iron": _r("#1c1816", "#3b332e", "#655849", "#8f7e66"),
    "band": _r("#56625f", "#a2aba5", "#dcdfd4"),
    "tape": _r("#857e6a", "#c3baa0"),
    "tube": _r("#3d4b48", "#7d918a"),
    "dirt": _r("#291f18", "#46382a"),
}
