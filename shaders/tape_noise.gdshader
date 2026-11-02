// Nieve de cinta: la «lluvia de estática» del título y el ruido de las transiciones.
// - amount: 0 nada; ~0.15 lluvia suave sobre la imagen; 1 pantalla llena de nieve (cambio de cinta).
// - streaks: rayas blancas horizontales que cruzan de vez en cuando (cabezales sucios).
// - roll: banda clara que sube despacio por la pantalla, como un vertical mal ajustado.
// Se dibuja encima de la imagen y debajo del filtro VHS. Compatible con GL Compatibility.
shader_type canvas_item;
render_mode unshaded;

uniform float amount : hint_range(0.0, 1.0) = 0.15;
uniform float streaks : hint_range(0.0, 1.0) = 0.3;
uniform float roll : hint_range(0.0, 1.0) = 0.25;
uniform vec3 snow_color : source_color = vec3(0.91, 0.88, 0.83);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(SCREEN_UV * size);
	float frame = floor(TIME * 24.0);
	// Nieve: píxeles sueltos, más densos cuanto más ruido.
	float n = hash(px + vec2(frame * 13.1, frame * 7.7));
	float snow = step(1.0 - amount * 0.45, n) * (0.35 + 0.65 * hash(px.yx + frame));
	// Con mucho ruido, la pantalla entera es gris granulado.
	float gray = amount * amount * (0.25 + 0.5 * n);
	// Rayas horizontales cortas.
	float row = floor(px.y);
	float streak_on = step(1.0 - streaks * 0.012, hash(vec2(row, frame)));
	float streak_x = hash(vec2(frame, row * 1.3)) * size.x;
	float streak_len = 20.0 + 90.0 * hash(vec2(row, frame * 3.0));
	float streak = streak_on * step(streak_x, px.x) * step(px.x, streak_x + streak_len);
	// Banda que sube.
	float band_y = fract(-TIME * 0.06) * (size.y + 60.0) - 30.0;
	float band = roll * 0.08 * exp(-pow((px.y - band_y) / 10.0, 2.0));
	float alpha = clamp(snow * 0.55 + gray + streak * 0.5 + band, 0.0, 1.0);
	COLOR = vec4(snow_color * (0.6 + 0.4 * n), alpha);
}
