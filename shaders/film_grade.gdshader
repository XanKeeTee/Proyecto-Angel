shader_type canvas_item;
// Etalonaje de pantalla completa (sustituye al filtro VHS agresivo):
// color desaturado y de baja saturación, sombras con contraste alto, grano de película fino,
// viñeta oscura y un tramado sutil que rompe las bandas de los degradados oscuros.
// Los fallos de cinta (`tracking`) siguen disponibles solo para los sustos y eventos.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Cuánto color se quita (0 = original, 1 = blanco y negro).
uniform float desaturation : hint_range(0.0, 1.0) = 0.38;
// Saturación del color que queda (1 = igual).
uniform float saturation : hint_range(0.0, 1.5) = 0.78;
// Virado general (zona, heridas…). Blanco = sin virado.
uniform vec3 tint : source_color = vec3(1.0);
// Color frío hacia el que tiran las sombras y cálido hacia el que tiran las luces (muy poco).
uniform vec3 shadow_tone : source_color = vec3(0.86, 0.9, 1.0);
uniform vec3 highlight_tone : source_color = vec3(1.0, 0.97, 0.9);
// Contraste de las sombras: hunde los tonos bajos sin quemar las luces.
uniform float shadow_contrast : hint_range(0.0, 1.0) = 0.22;
// Punto (luminancia) por debajo del cual se aplica el contraste de sombras.
uniform float shadow_pivot : hint_range(0.05, 0.6) = 0.16;
// Contraste general (1 = igual).
uniform float contrast : hint_range(0.5, 1.6) = 1.04;

uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;
// Tamaño del grano en píxeles de pantalla.
uniform float grain_size : hint_range(1.0, 3.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.85;
// Radio donde empieza la viñeta (0 = centro) y suavidad.
uniform float vignette_start : hint_range(0.0, 1.0) = 0.32;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;
// Tramado ordenado: niveles por canal (menos = más visible) y fuerza.
uniform float dither_levels : hint_range(8.0, 256.0) = 56.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.6;

// Efectos de evento (por defecto apagados).
uniform float aberration_px : hint_range(0.0, 4.0) = 0.0;
uniform float tracking : hint_range(0.0, 1.0) = 0.0;
uniform float gamma : hint_range(0.4, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tape_time = floor(TIME * 12.0);
	if (tracking > 0.0) {
		float band = floor(uv.y * 45.0);
		float tear = step(1.0 - tracking * 0.4, hash(vec2(band, tape_time)));
		uv.x += tear * (hash(vec2(tape_time, band * 3.1)) - 0.5) * 0.06 * tracking;
	}
	vec3 color;
	if (aberration_px + tracking > 0.001) {
		vec2 offset = vec2(SCREEN_PIXEL_SIZE.x * (aberration_px + tracking * 2.0), 0.0);
		color = vec3(texture(screen_texture, uv + offset).r, texture(screen_texture, uv).g,
				texture(screen_texture, uv - offset).b);
	} else {
		color = texture(screen_texture, uv).rgb;
	}

	// Color: desaturar, bajar saturación y virar.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), desaturation);
	color = mix(vec3(luma), color, saturation);
	color *= tint;
	// Tonos: sombras frías, luces apenas cálidas.
	color *= mix(shadow_tone, highlight_tone, smoothstep(0.08, 0.6, luma));

	// Contraste: general alrededor del gris medio y extra en las sombras.
	color = (color - 0.5) * contrast + 0.5;
	luma = dot(color, vec3(0.299, 0.587, 0.114));
	float low = clamp(luma / shadow_pivot, 0.0, 1.0);
	float crushed = pow(low, 1.0 + shadow_contrast * 1.6) * shadow_pivot;
	if (luma < shadow_pivot && luma > 0.0001) {
		color *= crushed / luma;
	}

	// Viñeta oscura y suave.
	vec2 centered = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float dist = length(centered) * 1.35;
	float vignette = 1.0 - smoothstep(vignette_start, vignette_start + vignette_softness, dist) * vignette_strength;
	color *= clamp(vignette, 0.0, 1.0);

	// Grano de película: monocromo, más visible en los medios tonos que en el negro.
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / grain_size);
	float t = floor(TIME * 24.0);
	float g = hash(pixel + vec2(t * 17.0, t * 31.0)) + hash(pixel * 1.7 + vec2(t * 7.0, 3.0)) - 1.0;
	luma = dot(color, vec3(0.299, 0.587, 0.114));
	color += g * grain_amount * (0.35 + 0.65 * smoothstep(0.02, 0.35, luma)) * (1.0 + tracking);

	// Tramado sutil: cuantiza con una matriz de Bayer para que los degradados oscuros no hagan bandas.
	vec2 screen_px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	color = floor(color * dither_levels + 0.5 + bayer4(screen_px) * dither_amount) / dither_levels;

	color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma));
	COLOR = vec4(color, 1.0);
}
