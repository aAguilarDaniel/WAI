// Cielo del nivel: el ultimo fondo de todo. Va en una CanvasLayer de pantalla
// completa por DEBAJO del parallax, asi que cubre el cuadro entero pase lo que
// pase con la camara.
//
// Existe porque la capa 1 del parallax era una textura de 216 px de alto sobre
// una camara que recorre ~730 px de mundo: por encima y por debajo de esa banda
// se veia el color de fondo de Godot, dos franjas grises que se comian el cuadro.
//
// Pinta lo que pide ARTE.md §3: una sola fuente de luz al fondo y baja
// (la hendidura incandescente) y todo lo demas apagandose hacia arriba.
shader_type canvas_item;
render_mode unshaded;

// Desplazamiento en pixeles de mundo. Lo escribe ui/cielo.gd desde la camara con
// un factor muy bajo: el cielo se mueve, pero apenas.
uniform float desplazamiento_y = 0.0;
uniform float desplazamiento_x = 0.0;
// Alto del viewport en pixeles. Sin esto la banda de brasa se estira al cambiar
// de resolucion y deja de coincidir con el horizonte del parallax.
uniform float alto_viewport = 216.0;

uniform vec3 color_cenit : source_color = vec3(0.043, 0.031, 0.063);
uniform vec3 color_medio : source_color = vec3(0.227, 0.125, 0.149);
uniform vec3 color_brasa : source_color = vec3(0.769, 0.463, 0.165);
uniform vec3 color_nucleo : source_color = vec3(0.988, 0.792, 0.404);
uniform vec3 color_bruma : source_color = vec3(0.102, 0.071, 0.102);

// Donde cae la hendidura, en fraccion del alto de pantalla.
uniform float horizonte : hint_range(0.0, 1.0) = 0.62;
uniform float grosor_brasa : hint_range(0.02, 0.5) = 0.13;
// Cuanto respira la luz. Es lo unico animado del cielo: si se moviera mas,
// dejaria de leerse como una instalacion lejana y pareceria fuego.
uniform float pulso : hint_range(0.0, 0.3) = 0.055;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ruido_suave(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ruido(celda);
	float b = ruido(celda + vec2(1.0, 0.0));
	float c = ruido(celda + vec2(0.0, 1.0));
	float d = ruido(celda + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float y = UV.y + desplazamiento_y / alto_viewport;
	float x = UV.x + desplazamiento_x;

	// Ondulacion del horizonte. Periodo entero para que no se vea la costura.
	float onda = sin(x * 6.2831853) * 0.012 + sin(x * 18.849556) * 0.005;
	float h = horizonte + onda;

	vec3 color;
	if (y < h - grosor_brasa) {
		// Cupula: del negro violaceo del cenit al granate del horizonte.
		float t = clamp(y / max(h - grosor_brasa, 0.001), 0.0, 1.0);
		color = mix(color_cenit, color_medio, pow(t, 1.4));
	} else if (y < h) {
		// La hendidura. Sube de golpe: es la unica luz del cuadro.
		float t = (y - (h - grosor_brasa)) / grosor_brasa;
		color = mix(color_medio, color_brasa, pow(t, 2.2));
		color = mix(color, color_nucleo, pow(t, 7.0));
	} else {
		// Por debajo del horizonte se apaga en bruma: ahi va el terreno.
		float t = clamp((y - h) / 0.34, 0.0, 1.0);
		color = mix(color_nucleo * 0.85, color_bruma, pow(t, 0.55));
	}

	// Polvo suspendido, muy lento y muy tenue. Rompe la franja plana del
	// degradado, que es lo que delata un cielo hecho por codigo.
	float nube = ruido_suave(vec2(x * 5.0 + TIME * 0.012, y * 9.0)) * 0.5
		+ ruido_suave(vec2(x * 11.0 - TIME * 0.02, y * 17.0)) * 0.5;
	float velo = smoothstep(0.15, 0.95, 1.0 - abs(y - h + 0.10) * 3.2);
	color = mix(color, color * (0.86 + nube * 0.34), velo * 0.55);

	// El pulso: la instalacion del fondo sigue encendida y respira.
	float respiracion = 1.0 + sin(TIME * 0.55) * pulso + sin(TIME * 0.23) * pulso * 0.6;
	float cerca_brasa = smoothstep(0.30, 0.0, abs(y - h + grosor_brasa * 0.5));
	color *= mix(1.0, respiracion, cerca_brasa);

	COLOR = vec4(color, 1.0);
}
