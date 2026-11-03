"""Rampas de la quinta muestra (pinceladas, cerca de Fear & Hunger): 5-8 tonos sucios por material."""

from brush import build_palette, ramp

ramp("nskin", ["#0d0c0f", "#1f1f25", "#33343a", "#4a4c50", "#63666a", "#7e8082", "#9b9c99", "#b8b7b0"])
ramp("uniform", ["#141210", "#2a2620", "#433d33", "#625a4b", "#857b66", "#a69a82", "#c2b69c", "#d9cfb6"])
ramp("porcelain", ["#2a2722", "#4b463e", "#706a5d", "#968f7e", "#bab2a0", "#d6cfbc", "#ebe5d3", "#f7f2e3"])
ramp("mask_cloth", ["#0e1412", "#1b2622", "#2b3a34", "#3e5047", "#55675d", "#6f8176"])
ramp("metal", ["#0d0e10", "#1e2125", "#363a3f", "#555a5e", "#7a7e7e", "#a3a59f", "#ccccc3", "#eeeee6"])
ramp("blood", ["#120406", "#2a080d", "#460f14", "#651a1b", "#842a24", "#a5402f"])
ramp("dry", ["#140807", "#281210", "#3d1d17", "#55291f", "#6c3a2a"])
ramp("flesh", ["#1e080b", "#43121a", "#6d2228", "#93403a", "#b56552", "#cd8b70"])
ramp("glass", ["#141a1a", "#2c3634", "#4c5955", "#73817a", "#a3b0a5", "#d8e0d4"])
ramp("liquid", ["#050206", "#12070c", "#220d16", "#361421", "#521f2e"])
ramp("bone", ["#2e281f", "#544b3c", "#7c705a", "#a4977b", "#c9bc9e", "#e3d8bd"])
ramp("rust", ["#1c0d07", "#3a1c0e", "#5e3018", "#814a27", "#a06a3f"])
ramp("vein", ["#14142a", "#24223e", "#34304f"])
ramp("eye", ["#1a1410", "#5a4c3c", "#a69a80", "#e3dac2"])
ramp("nail", ["#0e0b0a", "#241e19", "#3d342b"])
ramp("rim", ["#3a0a10", "#5e1018", "#7c1c22"])
ramp("ink", ["#120c0c"])
# protagonista
ramp("skin", ["#140c0e", "#2b1c1e", "#463130", "#644a43", "#86675a", "#a68571", "#c2a28a", "#d9bea5"])
ramp("scalp", ["#130e0f", "#2a2122", "#433635", "#5f4f4a", "#7d6b61", "#9a8778", "#b2a08e"])
ramp("gown", ["#0e1216", "#1b232b", "#2c3843", "#41505c", "#5a6a74", "#76858b", "#94a0a1", "#b2bab6"])
ramp("brief", ["#0a0b0e", "#16181e", "#24272f", "#33373f"])
ramp("iron", ["#0c0a09", "#1d1916", "#302a25", "#493f36", "#655849", "#82735f", "#a08f77"])
ramp("band", ["#3c4446", "#6d7978", "#a2aba5", "#d4d8cf"])
ramp("tape", ["#615b4c", "#8f8771", "#bcb299"])
ramp("tube", ["#29322f", "#4f5f5a", "#7c8f88"])
ramp("dirt", ["#171210", "#2b221a", "#43372a"])

NURSE = build_palette(["nskin", "uniform", "porcelain", "mask_cloth", "metal", "blood", "dry", "flesh", "glass", "liquid",
                       "bone", "rust", "vein", "eye", "nail", "rim", "ink"])
HERO = build_palette(["skin", "scalp", "gown", "brief", "iron", "band", "tape", "tube", "dirt", "blood", "dry", "flesh",
                      "rim", "ink", "vein"])
