// La entidad: una sombra más negra que el negro que apenas se intuye.
// La textura (tools/art/entity.py) es un mapa de datos, no una imagen:
//   A = densidad (núcleo 1, halo tenue alrededor), G = hilos de humo, R = los dos puntos de los ojos.
// - haze: el fondo de detrás (y del halo) se desplaza y ondula, como aire caliente. Es lo primero que
//   aparece y lo último que se va: con la figura casi borrada, solo queda eso.
// - fade: 0 nada → 1 entera. Se condensa por manchas de ruido (no un fundido limpio).
// - presence: cuánto negro pinta (baja al mirarla de frente; ver Stalker.set_gaze).
// - dissolve: 0 entera → 1 deshecha; se rompe hacia arriba en humo con motas de estática apagadas.
// - tear: desgarro horizontal por filas (cinta que salta).
// - eyes: brillo de los ojos (0 apagados; Stalker los enciende a ratos y nunca del todo).
// Sin luz (unshaded): la linterna no la «ilumina», la recorta. Compatible con GL Compatibility.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float haze : hint_range(0.0, 1.0) = 1.0;
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float tear : hint_range(0.0, 1.0) = 0.0;
uniform float eyes : hint_range(0.0, 1.0) = 0.0;
// Desplazamiento máximo del fondo (píxeles de pantalla).
uniform float haze_px = 1.6;
// Ondulación del humo (píxeles de la textura; más fuerte abajo).
uniform float waver_px = 1.2;
// Cuánto oscurece el halo lo que tiene detrás (0..1).
uniform float aura_dark = 0.35;
uniform vec4 smoke_color : source_color = vec4(0.13, 0.125, 0.15, 1.0);
uniform vec4 eye_color : source_color = vec4(0.62, 0.6, 0.55, 1.0);
uniform vec4 static_color : source_color = vec4(0.42, 0.44, 0.47, 1.0);
// Tamaño de un fotograma de la hoja (para trabajar en píxeles del fotograma).
uniform vec2 frame_px = vec2(72.0, 136.0);

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

	// El humo ondula y sube: el borde se lee desplazado hacia arriba con el tiempo.
	vec2 uv = UV;
	float flow = vnoise(vec2(local.x * 0.21, local.y * 0.11 + TIME * 2.4));
	uv.x += (flow - 0.5) * 2.0 * waver_px * (0.4 + low) * TEXTURE_PIXEL_SIZE.x;
	uv.y += vnoise(vec2(local.x * 0.3 + 7.0, local.y * 0.2 + TIME * 3.0)) * 1.5 * TEXTURE_PIXEL_SIZE.y;
	// Desgarro: algunas filas saltan de lado.
	float band = floor(local.y / 3.0);
	float jump = step(1.0 - tear * 0.6, hash(vec2(band, row_time)));
	uv.x += jump * (hash(vec2(row_time, band)) - 0.5) * 12.0 * tear * TEXTURE_PIXEL_SIZE.x;
	vec4 data = texture(TEXTURE, uv);
	float density = data.a;
	float halo = smoothstep(0.0, 0.2, density);

	// Bordes que humean: el borde se come a sí mismo con ruido que asciende.
	float edge = 1.0 - smoothstep(0.5, 0.95, density);
	float rise = vnoise(vec2(local.x * 0.32, local.y * 0.22 + TIME * 5.5));
	density = max(0.0, density - edge * rise * 0.55);

	// Condensación por manchas.
	float nr = vnoise(local * 0.17 + vec2(3.1, 7.7)) * 0.7 + hash(local) * 0.3;
	float shown = smoothstep(nr * 0.55, nr * 0.55 + 0.45, fade);
	density *= shown;

	// Disolución hacia arriba, con motas de estática apagadas en el borde.
	float flecks = 0.0;
	if (dissolve > 0.0) {
		float nd = vnoise(vec2(local.x * 0.2, local.y * 0.2 + TIME * 9.0)) * 0.75 + hash(local) * 0.25;
		nd = nd * 0.85 + low * 0.15;  // abajo se va antes: se lo lleva hacia arriba
		float cut = dissolve * 1.15;
		if (nd < cut - 0.02) {
			density = 0.0;
		} else if (nd < cut + 0.08 && density > 0.1) {
			float sparkle = hash(local + vec2(floor(TIME * 24.0)));
			flecks = step(0.72, sparkle) * (1.0 - dissolve * 0.6);
		}
		halo *= 1.0 - dissolve;
	}

	// El fondo de detrás tiembla dentro del halo (y se oscurece un poco).
	float hz = halo * haze;
	vec2 off = vec2(sin(local.y * 0.55 + TIME * 4.2) + (flow - 0.5) * 1.5,
			cos(local.x * 0.45 + TIME * 3.4) * 0.5) * haze_px * hz;
	vec3 bg = texture(screen_tex, SCREEN_UV + off * SCREEN_PIXEL_SIZE).rgb;
	bg *= 1.0 - aura_dark * hz;

	// Negro tramado: núcleo macizo, borde y presencia baja en trama de 4×4 (nunca alfa suave).
	float amount = density * presence;
	float cover = step(bayer4(local), amount * 1.04);
	vec3 col = mix(bg, vec3(0.0), cover);

	// Hilos de humo: apenas más claros que el negro (lo único que se ve en la oscuridad total).
	// Los de la hoja y los que el propio borde suelta al subir.
	float rising = smoothstep(0.55, 0.85, vnoise(vec2(local.x * 0.5, local.y * 0.16 + TIME * 6.0)));
	float edge_smoke = smoothstep(0.06, 0.25, data.a) * (1.0 - smoothstep(0.45, 0.75, data.a)) * rising;
	float wisp_live = max(data.g, edge_smoke) * shown * (1.0 - dissolve) * mix(0.6, 1.0, presence);
	// Grano que centellea (no trama fija): parece humo, no una rejilla.
	float wisp = step(hash(local + vec2(floor(TIME * 10.0) * 7.31, 0.0)), wisp_live * 0.5);
	col = mix(col, smoke_color.rgb, wisp * 0.8);

	// Ojos: dos puntos tenues que aparecen a ratos.
	float eye = data.r * eyes * shown * (1.0 - dissolve);
	col = mix(col, eye_color.rgb, eye);

	col = mix(col, static_color.rgb * (0.5 + 0.5 * hash(local + TIME)), flecks);
	float alpha = max(max(step(0.01, hz), cover), max(max(wisp, step(0.05, eye)), flecks));
	COLOR = vec4(col, alpha * modulate.a);
}
