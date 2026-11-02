// Entidad de humo: aparición tramada, ondulación del humo y disolución en estática.
// - fade: 0 invisible → 1 entera; aparece y se va por tramado (Bayer 4×4), nunca con alfa suave.
// - dissolve: 0 entera → 1 deshecha; el borde que se come la figura chisporrotea como nieve de TV.
// - tear: desgarro horizontal por filas (como una cinta que salta) mientras se deshace.
// Sin luz (unshaded): la figura es casi negra y se lee como un hueco en lo iluminado.
// Compatible con GL Compatibility.
shader_type canvas_item;
render_mode unshaded;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float tear : hint_range(0.0, 1.0) = 0.0;
// Ondulación del humo, en píxeles de la textura (más fuerte abajo).
uniform float waver_px = 1.0;
uniform vec4 edge_color : source_color = vec4(0.82, 0.86, 0.92, 1.0);
uniform vec4 edge_color_b : source_color = vec4(0.37, 0.72, 0.69, 1.0);
// Tamaño de un fotograma de la hoja (para trabajar en píxeles del fotograma).
uniform vec2 frame_px = vec2(64.0, 112.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

void fragment() {
	vec2 tex_px = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * tex_px);
	vec2 local = mod(px, frame_px);
	float low = clamp(local.y / frame_px.y, 0.0, 1.0);
	float row_time = floor(TIME * 14.0);
	vec2 uv = UV;
	// El humo ondula: más en la parte baja.
	uv.x += sin(local.y * 0.35 + TIME * 3.1) * waver_px * low * low * TEXTURE_PIXEL_SIZE.x;
	// Desgarro: algunas filas saltan de lado.
	float band = floor(local.y / 3.0);
	float jump = step(1.0 - tear * 0.6, hash(vec2(band, row_time)));
	uv.x += jump * (hash(vec2(row_time, band)) - 0.5) * 10.0 * tear * TEXTURE_PIXEL_SIZE.x;
	vec4 color = texture(TEXTURE, uv);

	// Disolución: ruido en píxeles del fotograma; arriba aguanta un poco más.
	float n = vnoise(local * 0.23) * 0.7 + hash(local) * 0.3;
	n = n * 0.85 + (1.0 - low) * 0.15;
	float cut = dissolve * 1.15;
	if (n < cut - 0.02) {
		color.a = 0.0;
	} else if (n < cut + 0.09 && dissolve > 0.0 && color.a > 0.0) {
		// Borde de estática: blanco hueso o cian de monitor, parpadeando a 24 imágenes/s.
		float sparkle = hash(local + vec2(floor(TIME * 24.0)));
		color.rgb = mix(edge_color.rgb, edge_color_b.rgb, step(0.8, sparkle)) * (0.55 + 0.45 * sparkle);
		color.a = step(0.35, sparkle);
	}
	// Aparición tramada.
	if (bayer4(local) > fade) {
		color.a = 0.0;
	}
	COLOR = color * modulate;
}
