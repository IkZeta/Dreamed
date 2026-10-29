shader_type canvas_item;
// Apagón: oscuridad con huecos de luz (Kroker y, si está encendida, la chimenea).
// Blackout: darkness with holes of light (Kroker and, if lit, the fireplace).

uniform vec4 dark_color : source_color = vec4(0.02, 0.01, 0.08, 0.92);
uniform float fade = 1.0;
uniform vec2 light0 = vec2(0.0);
uniform float radius0 = 300.0;
uniform vec2 light1 = vec2(0.0);
uniform float radius1 = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

// 0 en el centro de la luz y 1 fuera / 0 at the light's centre, 1 outside
float hole(vec2 c, float r) {
	if (r <= 0.0) {
		return 1.0;
	}
	float d = clamp(distance(world_pos, c) / r, 0.0, 1.0);
	return d < 0.55 ? mix(0.0, 0.27, d / 0.55) : mix(0.27, 1.0, (d - 0.55) / 0.45);
}

void fragment() {
	float k = min(hole(light0, radius0), hole(light1, radius1));
	COLOR = vec4(dark_color.rgb, dark_color.a * fade * k);
}
