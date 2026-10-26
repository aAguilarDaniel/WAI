// Shader de la pantalla del CRT de las terminales de guardado (ARTE.md §4):
// scanlines, curvatura de barril leve, bloom verde, ruido y deriva vertical.
// Se aplica al Sprite2D "Pantalla" de systems/save_points/terminal_crt.tscn,
// que muestra la textura del SubViewport en circuito cerrado.
shader_type canvas_item;

// Curvatura del tubo. Muy poca: si se pasa, deja de leerse la imagen.
uniform float curvatura : hint_range(0.0, 0.5) = 0.10;
uniform float intensidad_scanline : hint_range(0.0, 1.0) = 0.35;
// Cuantas lineas. A 216 px de alto, valores altos las vuelven ruido.
uniform float densidad_scanline : hint_range(20.0, 400.0) = 120.0;
uniform float ruido : hint_range(0.0, 0.5) = 0.06;
uniform float bloom : hint_range(0.0, 1.0) = 0.25;
uniform float aberracion : hint_range(0.0, 0.02) = 0.0025;
// Verde de fosforo del polo maquina (ARTE.md §1).
uniform vec3 tinte_fosforo = vec3(0.62, 1.0, 0.72);
// Desplazamiento vertical. El script lo anima a saltos para la deriva ocasional.
uniform float deriva : hint_range(-1.0, 1.0) = 0.0;
// Brillo general. El script lo baja al encender y apagar la pantalla.
uniform float encendido : hint_range(0.0, 1.0) = 1.0;

float azar(vec2 semilla) {
	return fract(sin(dot(semilla, vec2(12.9898, 78.233))) * 43758.5453);
}

// Deforma las coordenadas hacia afuera para simular el vidrio del tubo.
vec2 curvar(vec2 uv, float k) {
	vec2 centrado = uv * 2.0 - 1.0;
	float radio = dot(centrado, centrado);
	centrado *= 1.0 + k * radio;
	return centrado * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curvar(UV, curvatura);

	// Fuera del tubo no hay imagen. Opaco mientras la pantalla este encendida,
	// para que la curvatura de barril recorte contra negro y no contra el nivel.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, encendido);
	} else {
		uv.y = fract(uv.y + deriva);

		// Aberracion cromatica: separa los canales unos pixeles.
		float rojo = texture(TEXTURE, uv + vec2(aberracion, 0.0)).r;
		vec3 centro = texture(TEXTURE, uv).rgb;
		float azul = texture(TEXTURE, uv - vec2(aberracion, 0.0)).b;
		vec3 color = vec3(rojo, centro.g, azul);

		color *= tinte_fosforo;

		float linea = sin(uv.y * densidad_scanline * 3.14159265);
		color *= 1.0 - intensidad_scanline * (0.5 + 0.5 * linea);

		// Bloom barato: lo brillante se vuelve mas brillante.
		color += bloom * color * color;

		color += (azar(uv + vec2(TIME * 0.37, TIME * 0.61)) - 0.5) * ruido;

		// El alfa acompana a "encendido". Con alfa fijo en 1.0, apagar la
		// pantalla no la apagaba: la dejaba en negro opaco, y despues de usar
		// una terminal quedaba un rectangulo negro clavado en el nivel.
		COLOR = vec4(color * encendido, encendido);
	}
}
