// Post-procesado VHS de pantalla completa (versión de prototipo).
// Grano animado, aberración cromática horizontal, scanlines y viñeta.
// Uniforms recomendados: grain 0.06, aberration 1.0 (sube a 3 en impactos),
// scanlines 0.08, vignette 0.7. Compatible con GL Compatibility.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;
uniform float aberration_px : hint_range(0.0, 4.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.7;
// Semilla del ruido; congelar TIME no es posible, así que se puede fijar para capturas.
uniform float noise_seed = 0.0;
uniform bool animate_noise = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 offset = vec2(SCREEN_PIXEL_SIZE.x * aberration_px, 0.0);
	float r = texture(screen_texture, SCREEN_UV + offset).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV - offset).b;
	vec3 color = vec3(r, g, b);

	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float time_seed = animate_noise ? floor(TIME * 24.0) : 0.0;
	float noise = hash(pixel + vec2(time_seed * 17.0 + noise_seed, time_seed * 31.0)) - 0.5;
	color += noise * grain_amount;

	float row = mod(pixel.y, 2.0);
	color *= 1.0 - scanline_strength * row;

	vec2 centered = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength * 2.0;
	color *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
