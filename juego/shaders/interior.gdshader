// Fondo del interior del edificio (nivel 2). Hace el papel del cielo del nivel 1:
// una CanvasLayer de pantalla completa por debajo de todo, asi que nunca deja
// ver el color de fondo de Godot por mucho que suba o baje la camara.
//
// Usa los mismos uniforms que cielo.gdshader para poder reutilizar ui/cielo.gd.
//
// Lo que pinta: la oscuridad de una nave enorme, una bruma calida en el suelo
// y haces de luz de la brasa entrando en diagonal por los ventanales altos
// (ARTE.md §3: una sola fuente de luz, alta y lejana).
shader_type canvas_item;
render_mode unshaded;

uniform float desplazamiento_y = 0.0;
uniform float desplazamiento_x = 0.0;
uniform float alto_viewport = 216.0;

uniform vec3 color_boveda : source_color = vec3(0.047, 0.039, 0.063);
uniform vec3 color_medio : source_color = vec3(0.118, 0.094, 0.133);
uniform vec3 color_suelo : source_color = vec3(0.176, 0.125, 0.141);
uniform vec3 color_haz : source_color = vec3(0.86, 0.52, 0.27);
// Intensidad de los haces. Bajo: son polvo iluminado, no focos.
uniform float fuerza_haz : hint_range(0.0, 0.5) = 0.13;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ruido_suave(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ruido(celda), ruido(celda + vec2(1.0, 0.0)), f.x),
		mix(ruido(celda + vec2(0.0, 1.0)), ruido(celda + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float y = UV.y + desplazamiento_y / alto_viewport * 0.4;
	float x = UV.x + desplazamiento_x;

	vec3 color = mix(color_boveda, color_medio, smoothstep(0.0, 0.6, y));
	color = mix(color, color_suelo, smoothstep(0.55, 1.15, y));

	// Haces diagonales: bandas que caen de arriba a la izquierda. Su anchura
	// respira muy despacio, como si pasara humo por delante de los ventanales.
	float diagonal = x * 2.6 + y * 1.1;
	float bandas = sin(diagonal * 6.2831853 * 0.9) * 0.5 + 0.5;
	bandas = smoothstep(0.78 + sin(TIME * 0.21) * 0.04, 1.0, bandas);
	float humo = ruido_suave(vec2(diagonal * 3.0 - TIME * 0.05, y * 4.0 + TIME * 0.03));
	float caida = smoothstep(1.1, 0.05, y);
	color += color_haz * bandas * fuerza_haz * caida * (0.55 + humo * 0.6);

	// Polvo suspendido en la bruma del suelo.
	float polvo = ruido_suave(vec2(x * 30.0 + TIME * 0.4, y * 22.0 - TIME * 0.2));
	color += color_haz * 0.035 * smoothstep(0.6, 1.0, polvo) * smoothstep(0.4, 1.0, y);

	COLOR = vec4(color, 1.0);
}
