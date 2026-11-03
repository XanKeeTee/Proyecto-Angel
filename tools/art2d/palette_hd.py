"""Rampas de la segunda muestra (alta resolución): 6-7 colores clave interpolados a 12-14 tonos.

Las sombras tiran a frío y violáceo y las luces a cálido sucio (guía estética). Nada llega al
blanco ni al negro puros.
"""

from paint import ramp

# piel del paciente: pálida, cetrina, con sombras moradas
ramp("skin", ["#1a1015", "#38232a", "#5a3f40", "#7e5d55", "#9f7d6a", "#bc9c82", "#d3b99c"], 14)
ramp("skin_bruise", ["#170f1c", "#2c1f33", "#46324a", "#5e4757", "#76595f", "#8d6d6a"], 12)
ramp("scalp", ["#17121a", "#2f2529", "#4b3d3c", "#685650", "#857062", "#9e8875", "#b29d87"], 14)
ramp("lips", ["#1c0e12", "#3a1d22", "#5a3233", "#774a46", "#8f6157"], 10)
ramp("eye", ["#07050a", "#1a1216", "#3a2c2c", "#6b5d55", "#a59a88", "#cfc4ae"], 12)
ramp("gown", ["#14171c", "#283039", "#424d58", "#626d77", "#848e94", "#a5acab", "#c1c4ba"], 14)
ramp("brief", ["#0b0c10", "#171920", "#262932", "#373b46", "#4a4f5b"], 10)
ramp("blood", ["#120407", "#2b0a10", "#4b1218", "#6c1f1f", "#8c3329", "#a64c3a"], 12)
ramp("flesh", ["#1a070a", "#3f1119", "#6a2027", "#913d38", "#b36150", "#cc8a71", "#e0b096"], 14)
ramp("thread", ["#060408", "#141016", "#241e22", "#38302f"], 8)
ramp("dirt", ["#100c0a", "#251d17", "#3d3126", "#574735", "#6e5c45"], 10)
ramp("band", ["#22282c", "#465256", "#71807f", "#a0aba6", "#c9cfc7", "#e2e4da"], 12)
ramp("tube", ["#141a19", "#2c3836", "#4b5c58", "#71857e", "#9db1a6", "#c8d6cc"], 12)
ramp("tape", ["#3a362f", "#6a6556", "#99927e", "#c0b8a1", "#d8d0b8"], 10)

# enfermero
ramp("nskin", ["#0b0c12", "#181a23", "#282c36", "#3c414a", "#52585e", "#6a7073", "#858a87", "#a2a49c"], 16)
ramp("nskin_bruise", ["#120d1a", "#24192c", "#382540", "#4b3550", "#5d475c"], 12)
ramp("uniform", ["#151513", "#2c2a26", "#48453d", "#686457", "#8b8573", "#ada592", "#c9c1ab", "#ddd5c0"], 16)
ramp("porcelain", ["#24221f", "#4a463f", "#757063", "#a09887", "#c4bba7", "#ddd5c1", "#eee8d6", "#f8f3e4"], 16)
ramp("mask_cloth", ["#0c1210", "#1a2622", "#2c3e37", "#43584f", "#5d7369", "#7a8f83", "#98aa9c"], 14)
ramp("metal", ["#0b0c0e", "#1c1f24", "#33383e", "#50565c", "#737879", "#9a9d99", "#c6c6bd", "#eceade"], 16)
ramp("rust", ["#170b07", "#33190f", "#542a17", "#774222", "#955d34", "#ad7a4e"], 12)
ramp("liquid", ["#050307", "#10070d", "#1e0c16", "#311420", "#4a1f2c", "#6b3341"], 12)
ramp("glass", ["#14181a", "#2a3235", "#47534f", "#6d7b73", "#9aa79b", "#d2dacd"], 12)
ramp("bone", ["#26211a", "#4a4234", "#716650", "#998c70", "#bdb092", "#d8ccaf", "#ebe2c9"], 14)
ramp("vein", ["#0a0a16", "#16152a", "#25223c", "#363250"], 8)
ramp("nail", ["#0a0708", "#1f1a17", "#3a332c", "#57503f"], 8)

# protagonista en combate: tubo de hierro
ramp("iron", ["#0c0b0b", "#1e1b1a", "#363130", "#514942", "#6e6458", "#8b8070", "#a99c86"], 14)

# escenario
ramp("paint", ["#0e1312", "#1b2422", "#2c3a36", "#40524c", "#577068", "#708a80", "#8aa197"], 14)
ramp("plaster", ["#121110", "#24211e", "#38332d", "#4f483e", "#675e50", "#7f7462", "#968a74"], 14)
ramp("tile", ["#0f1213", "#1b2122", "#2a3233", "#3b4646", "#4f5b5a", "#64706d", "#7b8682"], 14)
ramp("lino", ["#0e0f10", "#1a1c1d", "#282b2b", "#383b39", "#4a4c48", "#5c5d56"], 12)
ramp("grout", ["#07080a", "#121315", "#1d1e1f", "#2a2a29"], 8)
ramp("mold", ["#0d110b", "#1a2214", "#29341f", "#3a4529"], 8)
ramp("stain", ["#1d160e", "#352818", "#4f3d24", "#6a5432"], 8)
ramp("mattress", ["#16181a", "#2b2f31", "#454a4a", "#636864", "#848780", "#a3a59a"], 12)
ramp("fluo", ["#3c4a44", "#6f857b", "#a9c2b4", "#d9eadf", "#f2fbf3"], 10)
ramp("dark", ["#020203", "#060608", "#0b0b0e", "#111115", "#18181d"], 8)
ramp("paper", ["#2a251c", "#4f4636", "#7a6d55", "#a29478", "#c4b698", "#ddd0b2"], 12)
ramp("ink", ["#070608", "#141214", "#221e20"], 6)
