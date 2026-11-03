shader_type canvas_item;
// Balanceo de una prenda en la hoja del protagonista (ver scenes/world/player/player.gd).
// Cada píxel se desplaza según su altura sobre los pies: nada por encima de `waist`
// y el desplazamiento completo (`sway`) en el bajo (`hem`). El mapa de normales se lee
// en el mismo sitio desplazado, así que la luz de la linterna sigue a la tela.

// Desplazamiento del bajo en píxeles (lo calcula el muelle del jugador).
uniform vec2 sway = vec2(0.0);
// Columnas y filas de la hoja, y tamaño de un fotograma en píxeles.
uniform vec2 frames = vec2(64.0, 8.0);
uniform vec2 frame_px = vec2(48.0, 68.0);
// Fila de píxeles de los pies dentro del fotograma.
uniform float feet_y = 62.0;
// Alturas (píxeles sobre los pies) donde empieza a moverse y donde se mueve del todo.
uniform float waist = 30.0;
uniform float hem = 12.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 cell = floor(UV * frames);
	vec2 local = (UV * frames - cell) * frame_px;
	float height = feet_y - local.y;
	float w = clamp((waist - height) / (waist - hem), 0.0, 1.0);
	// Sin subpíxeles: el desplazamiento se redondea para no emborronar el pixel art.
	vec2 src = floor(local) + 0.5 - round(sway * w * w);
	if (src.x < 0.0 || src.y < 0.0 || src.x > frame_px.x || src.y > frame_px.y) {
		COLOR = vec4(0.0);
	} else {
		vec2 suv = (cell + src / frame_px) / frames;
		COLOR = texture(TEXTURE, suv) * tint;
		NORMAL_MAP = texture(NORMAL_TEXTURE, suv).rgb;
	}
}
