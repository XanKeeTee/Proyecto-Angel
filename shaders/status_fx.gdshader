// Efectos de pantalla según el estado del personaje (overlay de estado, debajo de la interfaz).
// - hurt: Cuerpo bajo. Viñeta granate que late con el corazón (pulse) y algo de desaturación.
// - bleed: sangrado. Regueros que bajan del borde superior y manchas en los laterales, con
//   pequeñas pérdidas de color (drain) cada vez que se pierde Cuerpo.
// - unease: Mente baja. Eco muy leve de la imagen en los bordes, como una cinta grabada encima.
// - heal: cura con venda (0→1 durante la onda). Onda cálida que sale del centro y un respiro de luz.
// - calm: analgésico o sedante. Suavizado breve y colores templados.
// Todo en píxeles de la vista (640×360), con tramado: nada de degradados limpios.
// Compatible con GL Compatibility.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float bleed : hint_range(0.0, 1.0) = 0.0;
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform float unease : hint_range(0.0, 1.0) = 0.0;
uniform float heal : hint_range(0.0, 1.0) = 0.0;
uniform float heal_strength : hint_range(0.0, 1.0) = 0.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
// Granate / carne de la guía estética.
uniform vec3 blood_dark : source_color = vec3(0.165, 0.039, 0.055);
uniform vec3 blood : source_color = vec3(0.353, 0.086, 0.125);
uniform vec3 blood_light : source_color = vec3(0.557, 0.227, 0.208);
uniform vec3 warm : source_color = vec3(1.0, 0.74, 0.46);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

// Cuánto cubre la sangre este píxel (0..1) y si es el borde húmedo (brillo).
vec2 blood_cover(vec2 px, vec2 size) {
	float cover = 0.0;
	float shine = 0.0;
	// Regueros desde arriba: columnas de 2-3 px, pocas, de largo distinto, con gota en la punta.
	float col = floor(px.x / 4.0);
	float h = hash(vec2(col, 7.0));
	if (h > 0.8) {
		float lx = mod(px.x, 4.0);
		float width = 2.0 + step(0.92, h);
		float len = (0.03 + 0.2 * hash(vec2(col, 13.0))) * size.y * bleed;
		len *= 0.8 + 0.2 * sin(TIME * 0.4 + h * 40.0);
		// Más gruesos arriba, se afinan al bajar.
		float taper = width - step(len * 0.6, px.y);
		if (px.y < len && lx < taper) {
			cover = 1.0;
		}
		vec2 tip = vec2(col * 4.0 + width * 0.5 - 0.5, len);
		if (length((px - tip) * vec2(1.0, 0.8)) < 1.8 + step(0.92, h) * 0.6) {
			cover = 1.0;
			shine = step(px.x, tip.x - 0.5) * step(px.y, tip.y - 0.5);
		}
	}
	// Mancha a lo largo del borde superior.
	float top = (6.0 + 10.0 * vnoise(vec2(px.x * 0.06, 1.0))) * bleed;
	if (px.y < top) {
		cover = max(cover, 1.0);
	} else if (px.y < top + 3.0 && bayer4(px) < 0.5) {
		cover = max(cover, 0.6);
	}
	// Manchas en los laterales: salpicadura irregular.
	float side = min(px.x, size.x - px.x);
	float blot = vnoise(px * vec2(0.09, 0.05)) * 0.6 + vnoise(px * 0.25) * 0.4;
	float reach = (10.0 + 26.0 * vnoise(vec2(px.y * 0.03, px.x < size.x * 0.5 ? 3.0 : 9.0))) * bleed;
	if (side < reach * blot * 1.4 && blot > 0.42) {
		cover = max(cover, step(bayer4(px), 0.85));
	}
	return vec2(cover, shine);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(SCREEN_UV * size);
	vec2 uv = SCREEN_UV;
	vec2 centered = (uv - 0.5) * vec2(size.x / size.y, 1.0);
	float r = length(centered);

	vec3 color = texture(screen_texture, uv).rgb;
	// Calmante: suavizado de cinco tomas.
	if (calm > 0.0) {
		vec2 o = SCREEN_PIXEL_SIZE * (1.0 + calm * 1.5);
		vec3 soft = color * 0.4;
		soft += texture(screen_texture, uv + vec2(o.x, 0.0)).rgb * 0.15;
		soft += texture(screen_texture, uv - vec2(o.x, 0.0)).rgb * 0.15;
		soft += texture(screen_texture, uv + vec2(0.0, o.y)).rgb * 0.15;
		soft += texture(screen_texture, uv - vec2(0.0, o.y)).rgb * 0.15;
		color = mix(color, soft, calm);
	}
	// Mente baja: eco de la imagen que se desliza despacio, solo hacia los bordes.
	if (unease > 0.0) {
		vec2 drift = vec2(sin(TIME * 0.37), cos(TIME * 0.29)) * 6.0 * SCREEN_PIXEL_SIZE;
		vec3 echo = texture(screen_texture, uv + drift).rgb;
		float edge = smoothstep(0.35, 0.95, r);
		color = mix(color, max(color, echo * vec3(0.8, 0.85, 1.0)), unease * edge * 0.35);
	}

	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	float desat = hurt * 0.35 + drain * 0.55 + calm * 0.12;
	color = mix(color, vec3(gray), clamp(desat, 0.0, 1.0));

	// Herida: viñeta granate que late. Se cuantiza en bandas tramadas.
	float inner = 0.62 - hurt * 0.2 - pulse * hurt * 0.06;
	float vig = clamp((r - inner) / 0.5, 0.0, 1.0);
	vig = floor(vig * 6.0 + bayer4(px)) / 6.0;
	float vig_amount = vig * hurt * (0.55 + 0.45 * pulse);
	color = mix(color, color * blood_light * 1.6, vig_amount * 0.5);
	color = mix(color, blood_dark, vig_amount * 0.7);
	// En la oscuridad la viñeta oscura no se vería: a cada latido el borde se enciende en granate.
	color += blood * vig * hurt * pulse * 0.45;

	// Sangrado: regueros y manchas (debajo de la interfaz, nunca en el centro).
	if (bleed > 0.0) {
		vec2 b = blood_cover(px, size);
		if (b.x > 0.0) {
			vec3 stain = mix(blood_dark, blood, 0.7 + 0.3 * pulse);
			stain = mix(stain, blood_light, b.y * 0.6);
			color = mix(color, stain, b.x * (0.75 + 0.2 * pulse));
		}
		// Latido: el borde se oscurece un instante a cada golpe.
		color *= 1.0 - pulse * bleed * 0.12 * smoothstep(0.4, 0.9, r);
	}

	// Cura: onda cálida y ancha que sale del centro, y un respiro de luz que se apaga.
	if (heal_strength > 0.0) {
		float ring = heal * 1.2;
		float band = 1.0 - clamp(abs(r - ring) / 0.16, 0.0, 1.0);
		band = band * band;
		float dithered = step(bayer4(px), band * 1.3);
		color += warm * (0.05 + 0.1 * dithered) * band * heal_strength;
		color = mix(color, color * warm * 1.25, 0.25 * heal_strength * (1.0 - heal));
	}
	COLOR = vec4(color, 1.0);
}
