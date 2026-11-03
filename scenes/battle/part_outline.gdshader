// Contorno de una parte del cuerpo señalada (capa del enemigo o máscara de la lámina): pinta
// `line_color` en los píxeles transparentes que tocan algo opaco y, dentro, un velo del mismo color
// (`fill`, 0 = nada). Sirve igual para hojas con fotogramas (las celdas tienen margen vacío).
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.85, 0.2, 0.15, 1.0);
uniform float width = 1.0;
uniform float fill = 0.0;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float n = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			n = max(n, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * width).a);
		}
	}
	float edge = (1.0 - step(0.5, a)) * step(0.5, n);
	vec4 inside = vec4(line_color.rgb, line_color.a * fill * step(0.5, a));
	COLOR = mix(inside, line_color, edge);
}
