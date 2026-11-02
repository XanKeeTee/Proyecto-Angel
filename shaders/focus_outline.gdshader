// Contorno del objeto enfocado (lo usa scripts/systems/interaction/focus_outline.gd).
// Pinta solo el borde exterior de la silueta del fotograma, sin luz (se ve en la oscuridad),
// con un color de hueso apagado. La intensidad la anima el script con `strength`.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.86, 0.82, 0.70, 1.0);
uniform float strength = 0.35;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float here = texture(TEXTURE, UV).a;
	float around = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float edge = (here < 0.5 && around > 0.5) ? 1.0 : 0.0;
	COLOR = vec4(outline_color.rgb, outline_color.a * edge * strength);
}
