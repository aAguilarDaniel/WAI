# Herramienta: genera la escena del nivel 2, el interior del edificio en el que
# termina el nivel 1.
#
# Se corre con:
#   godot --headless --path juego res://tools/generar_nivel_02.tscn
#
# El nivel 1 se describe por su PERFIL de suelo porque es un exterior. Este es un
# interior, y se describe al reves: todo es macizo y las tablas dicen que HUECOS
# se excavan. Despues, cada celda maciza elige su aspecto sola segun lo que tiene
# alrededor (suelo si hay aire encima, techo si hay aire debajo, muro o relleno
# si no). Asi las tablas son solo forma, como las del nivel 1.
#
# Es una catedral de servidores (ARTE.md §3). La secuencia, igual que en el
# nivel 1, introduce UNA cosa por tramo:
#
#   A. Vestibulo alto, ventanales, un CRT y la pistola  -> respirar, el arma que faltaba
#   B. Pasillo de servidores con dos enemigos           -> lo aprendido, sin ayuda
#   C. Pasillo de arcos electricos                      -> leer un aviso y esperar
#   D. El pozo del montacargas                          -> subir con la maquina
#   E. Galeria alta: CRT, foso con plataforma movil y   -> esperar el momento, y otra
#      dos enemigos con una pasarela por encima            vez: evitar tambien vale
#   F. La gran sala: caida, coberturas, ultimo CRT      -> todo junto
#   G. Pasaje de un arco y el santuario de monitores    -> el final de la demo
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_02/nivel_02.tscn"
const RUTA_FIN: String = "res://ui/fin/fin_demo.tscn"
const PROPS: String = "res://art/placeholder/props/"
const INTERIOR: String = "res://art/placeholder/interior/"
## Cancion del nivel en bucle (el bucle lo da su .import, loop=true).
const MUSICA: String = "res://audio/musica/bruh_150.mp3"

const ANCHO_TILES: int = 192
const ALTO_TILES: int = 20

# ---------------------------------------------------------------------------
# EL NIVEL, EN TABLAS
# ---------------------------------------------------------------------------

## Aire: [x0, y0, x1, y1) en tiles. Todo lo demas es macizo.
## La fila y1 es la del suelo de ese hueco. Con 4 filas de aire (64 px) se pasa
## de pie pero un salto choca con el techo: es lo que hace que los arcos no se
## puedan saltar.
const HUECOS: Array = [
	[2, 4, 26, 15],      # A. vestibulo: 11 filas de alto
	[26, 10, 56, 15],    # B. pasillo de servidores: 5 filas
	[56, 11, 80, 15],    # C. pasillo de arcos: 4 filas
	[80, 1, 91, 15],     # D. pozo del montacargas
	[91, 2, 132, 7],     # E. galeria alta, suelo en la fila 7
	[104, 7, 111, 20],   # E. el foso de la galeria, abierto hasta abajo
	[132, 2, 163, 15],   # F. la gran sala
	[163, 11, 171, 15],  # G. pasaje del ultimo arco
	[171, 4, 190, 15],   # G. santuario
]

## Bloques de rack macizos dentro del aire: [x0, y0, x1, y1). Escalones y
## coberturas. Ninguno a mas de 2 tiles de la superficie desde la que se sube.
const BLOQUES: Array = [
	[40, 14, 41, 15],    # B. un escalon en mitad del pasillo
	[147, 13, 149, 15],  # F. cobertura de 2 de alto: y peldano hacia la pasarela
	[20, 14, 22, 15],    # A. pedestal de la pistola
]

## Pasarelas de rejilla, de un solo sentido: [x0, x1, fila].
## La de la galeria es la ruta por encima de los dos enemigos (2 tiles sobre el
## suelo). La de la gran sala sale del bloque de cobertura.
const PASARELAS: Array = [
	[113, 128, 5],
	[149, 158, 11],
]

## Suelo con franjas de peligro: [x0, x1, fila]. Debajo de los arcos y en el
## borde del foso. Avisa del peligro con el lenguaje del propio edificio.
const FRANJAS: Array = [
	[60, 64, 15], [67, 71, 15], [73, 77, 15], [102, 104, 7], [111, 113, 7],
	[165, 169, 15],
]

## Arcos electricos: [tile, fila del suelo, filas de alto, desfase en s].
## Los tres del pasillo C van desfasados para que haya que pasar uno, esperar
## entre dos y volver a leer el aviso: no se cruza el pasillo de una carrera.
const ARCOS: Array = [
	[62, 15, 4, 0.0], [69, 15, 4, 0.95], [75, 15, 4, 1.9],
	[167, 15, 4, 0.4],
]

## Plataformas moviles: [x px del centro, y px de la cara de arriba, recorrido,
## duracion, pausa, largo de cable].
## El montacargas del pozo sube del suelo (fila 15) al de la galeria (fila 7).
## La del foso va de borde a borde: sus extremos quedan a ras de los dos cantos.
const PLATAFORMAS_MOVILES: Array = [
	[1432, 240, Vector2(0, -128), 2.4, 1.4, 260.0],
	[1688, 112, Vector2(64, 0), 1.8, 1.0, 96.0],
]

## Terminales CRT: [tile, fila del suelo, id].
const TERMINALES: Array = [
	[12, 15, "nivel_02_crt_01"], [95, 7, "nivel_02_crt_02"], [160, 15, "nivel_02_crt_03"],
]

## Enemigos: [tile, fila del suelo, direccion].
const ENEMIGOS: Array = [
	[34, 15, -1], [47, 15, 1],      # B
	[117, 7, -1], [124, 7, 1],      # E, bajo la pasarela
	[141, 15, 1], [155, 15, -1],    # F
]

## Recogibles: [tile, fila del suelo, clase, id de arma o cantidad].
## La pistola es la unica arma del juego que el nivel 1 no tenia: con ella el
## arsenal queda en dos armas de cada bando (CLAUDE.md §6).
const RECOGIBLES: Array = [
	[21, 14, "arma", "pistola_reciclada"],
	[53, 15, "venda", 1],
	[98, 7, "venda", 1],
	[155, 11, "venda", 1],
	[175, 15, "venda", 1],
]

const INICIO: Vector2i = Vector2i(4, 15)
const SALIDA: Vector2i = Vector2i(186, 15)

## Objetos de escenario: [tile, fila del pie, archivo, volteado, z].
const DECORACION: Array = [
	# A. vestibulo
	[7, 13, "ventanal", false, -5], [18, 13, "ventanal", false, -5],
	[24, 15, "consola", true, -3], [3, 15, "rack", false, -3],
	# B. servidores
	[28, 15, "rack", false, -3], [30, 15, "rack", false, -3], [37, 15, "rack", false, -3],
	[44, 15, "rack", false, -3], [50, 15, "rack", false, -3], [52, 15, "consola", false, -3],
	# C. arcos
	[58, 14, "tuberia", false, -3], [71, 14, "tuberia", false, -3],
	# D. pozo
	[83, 9, "ventanal", false, -5],
	# E. galeria
	[93, 7, "rack", false, -3], [99, 7, "consola", false, -3], [114, 7, "rack", false, -3],
	[121, 7, "rack", false, -3], [129, 7, "consola", true, -3],
	# F. gran sala
	[138, 12, "ventanal", false, -5], [151, 12, "ventanal", false, -5],
	[135, 15, "rack", false, -3], [143, 15, "consola", false, -3], [159, 15, "rack", true, -3],
	# G. santuario
	[179, 15, "muro_monitores", false, -4], [173, 15, "rack", false, -3],
]

## Lamparas colgantes: [tile, fila del techo (la primera de aire)].
const LAMPARAS: Array = [
	[6, 4], [14, 4], [22, 4], [32, 10], [42, 10], [53, 10], [85, 1],
	[97, 2], [119, 2], [127, 2], [137, 2], [146, 2], [157, 2], [176, 4], [184, 4],
]

# ---------------------------------------------------------------------------

func _ready() -> void:
	var conjunto: TileSet = C.crear_tileset()
	_crear_nivel(conjunto)
	get_tree().quit()

func _crear_nivel(conjunto: TileSet) -> void:
	var raiz: Node2D = C.raiz("Nivel02")
	# Interior: no hay cielo que dejar ver por encima del techo.
	raiz.set("margen_superior", 0)
	raiz.set("margen_inferior", 24)
	raiz.set("encuadre_camara", Vector2(0.0, -14.0))
	raiz.set("ambiente", "ambiente_interior")
	raiz.set("volumen_ambiente", -12.0)
	raiz.set("musica", load(MUSICA))

	C.fondo(raiz, "FondoInterior", "res://shaders/interior.gdshader")
	C.parallax(raiz, [
		["CapaNave", INTERIOR + "capa_i1_nave.png", 0.12, -50],
		["CapaRacks", INTERIOR + "capa_i2_racks.png", 0.32, -40],
		["CapaColumnas", INTERIOR + "capa_i3_columnas.png", 0.58, -30],
		["CapaCables", INTERIOR + "capa_i4_cables.png", 1.25, 20],
	])
	_agregar_decoracion(raiz)
	_agregar_terreno(C.terreno(raiz, conjunto))
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, ALTO_TILES * 16.0 + 40.0)

	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO.x * 16, INICIO.y * 16))
	_agregar_peligros(raiz)
	_agregar_terminales(raiz)
	_agregar_enemigos(raiz)
	_agregar_recogibles(raiz)
	var salida: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"Ascensor", Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16))
	salida.set("destino", RUTA_FIN)

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(1.0, 0.8, 0.6, 0.14), 26)
	C.paleta(raiz)
	# Entrada: plano abierto de la nave, sin titulo. Es el mismo truco que la
	# apertura de Sadak: el control vuelve mientras la camara todavia se acerca.
	C.apertura(raiz, "Entrada", "", Vector2(0.7, 0.7), Vector2(70.0, -30.0), 2.6)

	C.guardar(raiz, RUTA_NIVEL)
	print("  ancho: %d tiles  enemigos: %d  arcos: %d  terminales: %d" % [
		ANCHO_TILES, ENEMIGOS.size(), ARCOS.size(), TERMINALES.size()])

# ---------------------------------------------------------------- Terreno ----

func _agregar_terreno(capa: TileMapLayer) -> void:
	var macizo: Dictionary = {}
	for x: int in ANCHO_TILES:
		for y: int in ALTO_TILES:
			macizo[Vector2i(x, y)] = true
	for hueco: Array in HUECOS:
		for x: int in range(int(hueco[0]), int(hueco[2])):
			for y: int in range(int(hueco[1]), int(hueco[3])):
				macizo.erase(Vector2i(x, y))
	for bloque: Array in BLOQUES:
		for x: int in range(int(bloque[0]), int(bloque[2])):
			for y: int in range(int(bloque[1]), int(bloque[3])):
				capa.set_cell(Vector2i(x, y), 0, C.INT_BLOQUE)
	var franjas: Dictionary = {}
	for tramo: Array in FRANJAS:
		for x: int in range(int(tramo[0]), int(tramo[1])):
			franjas[Vector2i(x, int(tramo[2]))] = true

	for celda: Vector2i in macizo:
		capa.set_cell(celda, 0, _aspecto(celda, macizo, franjas))
	for pasarela: Array in PASARELAS:
		for x: int in range(int(pasarela[0]), int(pasarela[1])):
			capa.set_cell(Vector2i(x, int(pasarela[2])), 0, C.INT_PASARELA)

## Cada celda maciza elige su aspecto por lo que tiene alrededor.
func _aspecto(celda: Vector2i, macizo: Dictionary, franjas: Dictionary) -> Vector2i:
	var arriba: bool = macizo.has(celda + Vector2i.UP) or celda.y == 0
	var abajo: bool = macizo.has(celda + Vector2i.DOWN) or celda.y == ALTO_TILES - 1
	if not arriba:
		return C.INT_SUELO_FRANJAS if franjas.has(celda) else C.INT_SUELO
	if not abajo:
		return C.INT_TECHO
	# Lejos de cualquier hueco: relleno oscuro sin colision.
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			var vecina: Vector2i = celda + Vector2i(dx, dy)
			var dentro: bool = vecina.x >= 0 and vecina.x < ANCHO_TILES \
				and vecina.y >= 0 and vecina.y < ALTO_TILES
			if dentro and not macizo.has(vecina):
				return C.INT_MURO_REJILLA if C.azar(celda.x, celda.y, 5) < 0.15 \
					else C.INT_MURO
	return C.INT_RELLENO

# -------------------------------------------------------------- Contenido ----

func _agregar_decoracion(raiz: Node2D) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Decoracion")
	var ambar: Color = Color(1.0, 0.72, 0.36)
	var fosforo: Color = Color(0.42, 0.86, 0.52)
	var brasa: Color = Color(1.0, 0.55, 0.28)
	for datos: Array in DECORACION:
		var pie: Vector2 = Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16)
		var nombre: String = str(datos[2])
		var volteado: bool = bool(datos[3])
		C.objeto(nodo, PROPS + nombre + ".png", pie, int(datos[4]), volteado)
		match nombre:
			"ventanal":
				# La brasa de fuera entra por el cristal roto.
				C.luz(nodo, pie + Vector2(0.0, -56.0), brasa, Vector2(1.1, 1.8), 0, 0.22, "grande")
			"rack":
				C.luz(nodo, pie + Vector2(6.0, -30.0), fosforo, Vector2(0.18, 0.18), 1, 0.9)
			"consola":
				C.luz(nodo, pie + Vector2(-2.0 if volteado else 2.0, -16.0), fosforo,
					Vector2(0.45, 0.35), 1, 0.45)
			"muro_monitores":
				C.luz(nodo, pie + Vector2(0.0, -36.0), fosforo, Vector2(2.4, 1.6), 0, 0.32, "grande")
	for lampara: Array in LAMPARAS:
		var techo: Vector2 = Vector2(int(lampara[0]) * 16 + 8, int(lampara[1]) * 16)
		C.objeto(nodo, PROPS + "lampara.png", techo + Vector2(0.0, 40.0), -2)
		C.luz(nodo, techo + Vector2(0.0, 37.0), ambar, Vector2(0.55, 0.55), 2, 0.55)
		C.luz(nodo, techo + Vector2(0.0, 37.0 + 48.0), ambar, Vector2(1.4, 1.5), 2, 0.16, "cono")
	var ascensor: Vector2 = Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16)
	C.objeto(nodo, PROPS + "ascensor.png", ascensor, -3)
	C.luz(nodo, ascensor + Vector2(0.0, -56.0), fosforo, Vector2(0.4, 0.3), 0, 0.8)

func _agregar_peligros(raiz: Node2D) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Peligros")
	for i: int in ARCOS.size():
		var datos: Array = ARCOS[i]
		var arco: Node = C.instanciar("res://systems/peligros/arco_electrico.tscn", nodo,
			"Arco%02d" % (i + 1), Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16))
		arco.set("altura", float(int(datos[2]) * 16))
		arco.set("desfase", float(datos[3]))
	for i: int in PLATAFORMAS_MOVILES.size():
		var datos: Array = PLATAFORMAS_MOVILES[i]
		var plataforma: Node = C.instanciar("res://systems/peligros/plataforma_movil.tscn",
			nodo, "Montacargas%02d" % (i + 1), Vector2(float(datos[0]), float(datos[1])))
		plataforma.set("recorrido", datos[2])
		plataforma.set("duracion", float(datos[3]))
		plataforma.set("pausa", float(datos[4]))
		plataforma.set("largo_cable", float(datos[5]))

func _agregar_terminales(raiz: Node2D) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Terminales")
	for i: int in TERMINALES.size():
		var datos: Array = TERMINALES[i]
		var terminal: Node = C.instanciar("res://systems/save_points/terminal_crt.tscn", nodo,
			"Terminal%02d" % (i + 1), Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		terminal.set("checkpoint_id", str(datos[2]))

func _agregar_enemigos(raiz: Node2D) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Enemigos")
	for i: int in ENEMIGOS.size():
		var datos: Array = ENEMIGOS[i]
		var enemigo: Node = C.instanciar("res://actors/enemies/enemigo_patrulla.tscn", nodo,
			"Enemigo%02d" % (i + 1), Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		enemigo.set("direccion_inicial", int(datos[2]))

func _agregar_recogibles(raiz: Node2D) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Recogibles")
	for datos: Array in RECOGIBLES:
		var posicion: Vector2 = Vector2(int(datos[0]) * 16, int(datos[1]) * 16)
		var recogible: Node = C.instanciar("res://systems/pickups/recogible.tscn", nodo,
			"%s_%d" % [datos[2], int(datos[0])], posicion)
		if str(datos[2]) == "arma":
			recogible.set("clase", 0)
			recogible.set("arma", load("res://systems/weapons/data/%s.tres" % datos[3]))
		else:
			recogible.set("clase", 2)
			recogible.set("cantidad", int(datos[3]))
