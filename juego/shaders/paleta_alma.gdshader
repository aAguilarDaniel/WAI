// Post-proceso de pantalla completa. Hace dos cosas a la vez:
//
// 1. El GRADO BASE, que no depende del eje y esta siempre puesto: vineta, grano
//    de pelicula, un bloom calido sobre la brasa del fondo y una aberracion
//    cromatica minima. Es lo que separa "un tilemap con sprites encima" de una
//    imagen; sin esto el cuadro se ve plano por muy bien dibujado que este.
// 2. La INCLINACION DE PALETA segun el eje del alma (ARTE.md §1). En ruta
//    maquina sube la aberracion, las scanlines y el contraste; en ruta humana
//    sube el grano, baja la saturacion de los cianes y calienta las luces.
//
// Lo maneja ui/paleta_alma.gd, que se suscribe a Alma.umbral_cruzado y anima los
// dos pesos con un Tween: el cambio nunca es un corte.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;

// Los dos pesos son excluyentes en la practica, pero se animan por separado para
// que la transicion pase por el estado neutro en vez de saltar de un polo al otro.
uniform float peso_maquina : hint_range(0.0, 1.0) = 0.0;
uniform float peso_humano : hint_range(0.0, 1.0) = 0.0;

// --- Grado base (siempre activo) ---
uniform float vineta_fuerza : hint_range(0.0, 1.5) = 0.62;
uniform float vineta_radio : hint_range(0.2, 1.2) = 0.82;
uniform float grano_base : hint_range(0.0, 0.2) = 0.035;
uniform float bloom_fuerza : hint_range(0.0, 1.5) = 0.55;
uniform float bloom_umbral : hint_range(0.0, 1.0) = 0.42;
uniform float aberracion_base : hint_range(0.0, 0.01) = 0.0008;
// Levanta los negros para que no sean un agujero. Un negro puro en pixel art a
// contraluz se traga la silueta del personaje, que es lo mas oscuro del cuadro.
uniform vec3 elevacion_negros : source_color = vec3(0.035, 0.026, 0.043);

// --- Inclinacion por el eje ---
uniform float aberracion_max : hint_range(0.0, 0.02) = 0.004;
uniform float scanlines_max : hint_range(0.0, 1.0) = 0.22;
uniform float contraste_max : hint_range(0.0, 1.0) = 0.30;
uniform float grano_max : hint_range(0.0, 0.5) = 0.07;
uniform float desaturacion_max : hint_range(0.0, 1.0) = 0.22;
uniform float lineas_pantalla : hint_range(50.0, 400.0) = 216.0;

uniform vec3 tinte_calido : source_color = vec3(1.0, 0.93, 0.82);
uniform vec3 tinte_frio : source_color = vec3(0.82, 0.94, 1.0);

float azar(vec2 semilla) {
	return fract(sin(dot(semilla, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// La aberracion nunca es cero: un pelo de desvio en los canales laterales da
	// sensacion de tubo sin que llegue a leerse como efecto.
	float aberracion = aberracion_base + aberracion_max * peso_maquina;
	vec3 color = vec3(
		texture(pantalla, uv + vec2(aberracion, 0.0)).r,
		texture(pantalla, uv).g,
		texture(pantalla, uv - vec2(aberracion, 0.0)).b);

	// --- Bloom: solo lo que ya brilla contagia a su alrededor ---
	// Seis muestras en cruz. Es un desenfoque pobre a proposito: con
	// gl_compatibility y un cuadro de 384x216 no hace falta mas, y de paso
	// conserva el pixel en vez de emborronarlo.
	vec2 paso = vec2(0.0045, 0.008);
	vec3 halo = vec3(0.0);
	halo += texture(pantalla, uv + vec2(paso.x, 0.0)).rgb;
	halo += texture(pantalla, uv - vec2(paso.x, 0.0)).rgb;
	halo += texture(pantalla, uv + vec2(0.0, paso.y)).rgb;
	halo += texture(pantalla, uv - vec2(0.0, paso.y)).rgb;
	halo += texture(pantalla, uv + paso * 1.6).rgb;
	halo += texture(pantalla, uv - paso * 1.6).rgb;
	halo /= 6.0;
	float brillo = max(max(halo.r, halo.g), halo.b);
	float exceso = max(brillo - bloom_umbral, 0.0) / max(1.0 - bloom_umbral, 0.001);
	color += halo * exceso * bloom_fuerza;

	// --- Polo maquina: frio, duro, electronico ---
	vec3 con_contraste = (color - 0.5) * (1.0 + contraste_max) + 0.5;
	color = mix(color, con_contraste, peso_maquina);
	float linea = 0.5 + 0.5 * sin(uv.y * lineas_pantalla * 3.14159265);
	color *= 1.0 - scanlines_max * peso_maquina * linea;
	color *= mix(vec3(1.0), tinte_frio, peso_maquina);

	// --- Polo humano: calido, sucio, organico ---
	float gris = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, mix(color, vec3(gris), desaturacion_max), peso_humano);
	color *= mix(vec3(1.0), tinte_calido, peso_humano);

	// --- Vineta: cierra el cuadro y empuja la mirada al centro ---
	vec2 centrado = (uv - 0.5) * vec2(1.0, 0.62);
	float distancia = length(centrado) / vineta_radio;
	float vineta = 1.0 - vineta_fuerza * pow(clamp(distancia, 0.0, 1.0), 2.4);
	color *= vineta;

	// --- Elevacion de negros: nada del cuadro es negro absoluto ---
	color = elevacion_negros + color * (1.0 - elevacion_negros);

	// --- Grano: lo ultimo, para que caiga tambien sobre la vineta ---
	float grano = grano_base + grano_max * peso_humano;
	color += (azar(uv + vec2(TIME * 0.13, TIME * 0.29)) - 0.5) * grano;

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
