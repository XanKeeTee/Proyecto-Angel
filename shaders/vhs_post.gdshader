// Post-procesado VHS de pantalla completa (versión de prototipo).
// Grano animado, aberración cromática horizontal, scanlines, viñeta,
// tracking (bandas desplazadas en eventos) y virado de color por zona.
// Uniforms recomendados: grain 0.06, aberration 1.0 (sube a 3 en impactos),
// scanlines 0.08, vignette 0.7, tracking 0 (solo en eventos), tint blanco.
// Compatible con GL Compatibility.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;
uniform float aberration_px : hint_range(0.0, 4.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.7;
// Semilla del ruido; congelar TIME no es posible, así que se puede fijar para capturas.
uniform float noise_seed = 0.0;
uniform bool animate_noise = true;
// 0 = imagen estable; 1 = cinta muy dañada. Subirlo solo durante eventos.
uniform float tracking : hint_range(0.0, 1.0) = 0.0;
// Virado de color de la zona (multiplica la imagen).
uniform vec3 tint : source_color = vec3(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tape_time = floor(TIME * 12.0);
	float tear = 0.0;
	if (tracking > 0.0) {
		// Bandas horizontales que saltan de lado, como una cinta mal alineada.
		float band = floor(uv.y * 45.0);
		tear = step(1.0 - tracking * 0.4, hash(vec2(band, tape_time)));
		uv.x += tear * (hash(vec2(tape_time, band * 3.1)) - 0.5) * 0.08 * tracking;
		uv.x += sin(uv.y * 40.0 + TIME * 7.0) * 0.002 * tracking;
	}

	vec2 offset = vec2(SCREEN_PIXEL_SIZE.x * (aberration_px + tracking * 3.0), 0.0);
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	vec3 color = vec3(r, g, b) * tint;

	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float time_seed = animate_noise ? floor(TIME * 24.0) : 0.0;
	float noise = hash(pixel + vec2(time_seed * 17.0 + noise_seed, time_seed * 31.0)) - 0.5;
	color += noise * (grain_amount + tracking * 0.25 + tear * 0.2);

	float row = mod(pixel.y, 2.0);
	color *= 1.0 - scanline_strength * row;

	vec2 centered = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength * 2.0;
	color *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
