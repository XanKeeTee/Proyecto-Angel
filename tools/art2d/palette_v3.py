"""Rampas de la tercera muestra (color continuo; la paleta cerrada se saca de ellas al reducir)."""

from vec import palette, ramp

ramp("skin", ["#170d12", "#33202a", "#553a3d", "#7a5951", "#9c7a69", "#b99a83", "#d2b89e", "#e4d1b8"])
ramp("bruise", ["#140c1a", "#2a1c33", "#43304a", "#5c4558", "#755b62"])
ramp("scalp", ["#161115", "#2e2428", "#4a3b3b", "#665450", "#826d63", "#9b8574", "#b09a86"])
ramp("gown", ["#11141a", "#232b34", "#3b4652", "#58646e", "#77838a", "#97a1a2", "#b5bcb8", "#cdd1c8"])
ramp("brief", ["#0a0b0f", "#15171e", "#23262f", "#343843"])
ramp("blood", ["#0f0306", "#26080d", "#430f15", "#64191b", "#862a24", "#a54232", "#c26a50"])
ramp("dry", ["#120808", "#24100f", "#3a1a16", "#53281f", "#6a3a2a"])
ramp("flesh", ["#1a070b", "#3e1118", "#682026", "#913b37", "#b4604f", "#cf8a70", "#e3b296"])
ramp("thread", ["#050306", "#120d11", "#211a1d", "#352c2c"])
ramp("dirt", ["#0e0a08", "#211a14", "#382c22", "#524232", "#6a5843"])
ramp("band", ["#1f2529", "#414d51", "#6b7a79", "#9aa6a1", "#c6ccc4", "#e4e6dc"])
ramp("tape", ["#36322b", "#655f50", "#958d78", "#bdb49d", "#d8cfb6"])
ramp("tube", ["#121817", "#2a3533", "#485956", "#6e827a", "#9cb0a5", "#cfdccf"])
ramp("iron", ["#0a0909", "#1b1817", "#302b29", "#4a423b", "#665b50", "#857766", "#a3927b", "#c0ad93"])
ramp("rust", ["#150a06", "#301710", "#512817", "#743f21", "#935b33", "#ad7a4f"])
# enfermero
ramp("nskin", ["#090a10", "#141720", "#22262f", "#343941", "#4a5056", "#62686b", "#7d827f", "#999c94", "#b5b6ab"])
ramp("nbruise", ["#100b17", "#211729", "#35233d", "#48324d", "#5a4459"])
ramp("uniform", ["#121210", "#262521", "#403d36", "#5f5b50", "#827c6c", "#a59d89", "#c4bba5", "#dbd3bd", "#ebe5d2"])
ramp("porcelain", ["#211f1c", "#45413a", "#6f695d", "#9a9282", "#bfb6a3", "#d9d1bd", "#ece6d4", "#f7f2e3"])
ramp("mask_cloth", ["#0a100e", "#17221e", "#283932", "#3e5249", "#576c62", "#73887c", "#91a497"])
ramp("metal", ["#08090b", "#171a1e", "#2b3036", "#454b51", "#666c6f", "#8d918f", "#b8b9b1", "#e2e1d6", "#fbfaf2"])
ramp("glass", ["#101416", "#232b2e", "#3d4846", "#606e68", "#8c9a8f", "#c4cfc3", "#eef3ea"])
ramp("liquid", ["#040205", "#0e060b", "#1b0b14", "#2d121e", "#45192a", "#652839"])
ramp("bone", ["#231e17", "#463e31", "#6d624d", "#958a6d", "#b9ad8f", "#d6cbad", "#eae0c7"])
ramp("vein", ["#080816", "#121128", "#1f1d38", "#2d2a49"])
ramp("nail", ["#080607", "#1a1513", "#30291f", "#4b4333"])
ramp("eye", ["#0a0806", "#2a201a", "#5a4c3c", "#9a8a6e", "#d4c6a4", "#f2ead2"])

HERO = palette(["skin", "bruise", "scalp", "gown", "brief", "blood", "dry", "flesh", "thread", "dirt", "band", "tape",
                "tube", "iron", "rust"], 12)
NURSE = palette(["nskin", "nbruise", "uniform", "porcelain", "mask_cloth", "metal", "glass", "liquid", "bone", "vein",
                 "nail", "eye", "blood", "dry", "flesh", "thread", "rust", "tape"], 12)
