# Herramienta: genera el nivel 4, la cornisa. Se sale de los conductos por una
# escotilla a la azotea de la catedral y se vuelve a ver la brasa del nivel 1,
# ahora desde arriba.
#
#   godot --headless --path juego res://tools/generar_nivel_04.tscn
#
# Exterior: se describe por su PERFIL de suelo, como el nivel 1. Lo nuevo:
#
#   A. Salida a la azotea, un CRT                    -> el cielo otra vez
#   B. Un abismo con una plataforma que cede          -> no quedarse quieto
#   C. Enemigo y torreta en el llano                  -> lo aprendido
#   D. Tres plataformas que ceden en escalera         -> encadenar sin pararse
#   E. CRT, enemigo y torreta en alto                 -> respirar y volver a pelear
#   F. Bajada, dos enemigos y torreta                 -> evitar tambien vale
#   G. Otro abismo, la subida y el ultimo CRT         -> guardar antes del jefe
#   H. La puerta del relicario                        -> nivel 5
#
# Regla de los abismos (CLAUDE.md §7): huecos de 2 tiles entre apoyos, que se
# cruzan andando. Las plataformas frágiles miden 2 tiles y se pisan a la misma
# altura o un tile mas arriba.
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_04/nivel_04.tscn"
const RUTA_SIGUIENTE: String = "res://levels/nivel_05/nivel_05.tscn"  # el archivo
const PROPS: String = "res://art/placeholder/props/"

const ANCHO_TILES: int = 172
const FONDO_TILES: int = 16

## [tile donde empieza el tramo, fila del suelo]
const PERFIL: Array = [
	[0, 9], [41, 8], [45, 7], [86, 8], [89, 9], [141, 8], [144, 7],
]

## [desde, hasta) en tiles: sin suelo.
const ABISMOS: Array = [
	[15, 21],            # B: 2 + fragil(2) + 2
	[51, 63],            # D: 2 + f + 2 + f + 2 + f(pegada al borde)
	[116, 122],          # G
]

## [tile izquierdo, fila de la cara de arriba]
const FRAGILES: Array = [
	[17, 9],
	[53, 7], [57, 6], [61, 6],
	[118, 9],
]

const TERMINALES: Array = [
	[7, 9, "nivel_04_crt_01"], [66, 7, "nivel_04_crt_02"], [148, 7, "nivel_04_crt_03"],
]

const ENEMIGOS: Array = [
	[32, 9, -1], [74, 7, 1], [100, 9, -1], [108, 9, 1], [136, 9, -1],
]

## Torretas en el suelo: [tile, fila del suelo, colgada]
const TORRETAS: Array = [
	[39, 9, false], [84, 7, false], [112, 9, false], [130, 9, false],
]

const RECOGIBLES: Array = [
	[25, 9, "venda", 1], [96, 9, "venda", 1], [146, 7, "venda", 1],
]

const DECORACION: Array = [
	[4, "valla", false], [11, "farola", false], [27, "chatarra", false],
	[36, "poste", false], [47, "farola", true], [69, "cartel", false],
	[79, "barril", false], [93, "servidor_caido", false], [104, "valla", true],
	[125, "farola", false], [139, "chatarra", true], [152, "poste", false],
	[158, "farola", true],
]

const INICIO: int = 3
const PUERTA: int = 166

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var alturas: PackedInt32Array = _perfil()
	var raiz: Node2D = C.raiz("Nivel04")
	raiz.set("encuadre_camara", Vector2(0.0, -40.0))
	# Fuera vuelve el silencio del nivel 1: solo viento. La musica del jefe tiene
	# que llegar a un oido descansado.
	raiz.set("ambiente", "ambiente")
	raiz.set("volumen_ambiente", -11.0)

	C.fondo(raiz, "Cielo", "res://shaders/cielo.gdshader")
	C.parallax(raiz, [
		["Capa1Bruma", "res://art/placeholder/parallax/capa_1_cielo.png", 0.03, -50],
		["Capa2Horizonte", "res://art/placeholder/parallax/capa_2_horizonte.png", 0.10, -40],
		["Capa3Torres", "res://art/placeholder/parallax/capa_3_torres.png", 0.20, -30],
		["Capa4Racks", "res://art/placeholder/parallax/capa_4_racks.png", 0.36, -20],
		["Capa6PrimerPlano", "res://art/placeholder/parallax/capa_6_primer_plano.png", 1.28, 20],
	])
	_fosos(raiz, alturas)
	_decoracion(raiz, alturas)
	_terreno(C.terreno(raiz, conjunto), alturas)
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, FONDO_TILES * 16.0 + 150.0)

	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO * 16, alturas[INICIO] * 16))
	var peligros: Node2D = C.contenedor(raiz, "Peligros")
	var fragiles: Array = []
	for datos: Array in FRAGILES:
		fragiles.append([int(datos[0]) * 16 + 16, int(datos[1]) * 16])
	C.plataformas_fragiles(peligros, fragiles)
	C.terminales(raiz, TERMINALES)
	var enemigos: Node2D = C.contenedor(raiz, "Enemigos")
	C.enemigos(enemigos, ENEMIGOS)
	C.torretas(enemigos, TORRETAS)
	C.recogibles(raiz, RECOGIBLES)

	var puerta: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"PuertaRelicario", Vector2(PUERTA * 16 + 8, alturas[PUERTA] * 16))
	puerta.set("destino", RUTA_SIGUIENTE)

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(1.0, 0.86, 0.66, 0.20))
	C.paleta(raiz)
	C.apertura(raiz, "Entrada", "", Vector2(0.7, 0.7), Vector2(60.0, -60.0), 3.0)

	C.guardar(raiz, RUTA_NIVEL)
	print("  nivel 4: %d tiles  enemigos: %d  torretas: %d  fragiles: %d" % [
		ANCHO_TILES, ENEMIGOS.size(), TORRETAS.size(), FRAGILES.size()])
	get_tree().quit()

func _perfil() -> PackedInt32Array:
	var alturas: PackedInt32Array = PackedInt32Array()
	alturas.resize(ANCHO_TILES)
	var altura: int = 9
	var siguiente: int = 0
	for x: int in ANCHO_TILES:
		while siguiente < PERFIL.size() and int(PERFIL[siguiente][0]) <= x:
			altura = int(PERFIL[siguiente][1])
			siguiente += 1
		alturas[x] = altura
	for hueco: Array in ABISMOS:
		for x: int in range(int(hueco[0]), int(hueco[1])):
			alturas[x] = -1
	return alturas

func _terreno(capa: TileMapLayer, alturas: PackedInt32Array) -> void:
	for x: int in ANCHO_TILES:
		var superficie: int = alturas[x]
		if superficie < 0:
			continue
		var tapa: Vector2i = C.EXT_SUPERFICIE_ZANJA if C.azar(x, superficie, 7) < 0.12 \
			else C.EXT_SUPERFICIE
		capa.set_cell(Vector2i(x, superficie), 0, tapa)
		for y: int in range(superficie + 1, FONDO_TILES):
			var profundidad: int = y - superficie
			var celda: Vector2i = C.EXT_SOLIDA
			if profundidad == 2 and C.azar(x / 6, y, 2) < 0.22:
				celda = C.EXT_SOLIDA_TUBO
			elif profundidad > 5:
				celda = C.EXT_PROFUNDO
			elif profundidad > 2:
				celda = C.EXT_RELLENO
			capa.set_cell(Vector2i(x, y), 0, celda)
	# Muro al final, detras de la puerta: no hay nada mas alla.
	for x: int in range(ANCHO_TILES - 2, ANCHO_TILES):
		for y: int in range(alturas[x] - 8, alturas[x]):
			capa.set_cell(Vector2i(x, y), 0, C.EXT_SOLIDA)

func _fosos(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Fosos")
	var textura: Texture2D = load("res://art/placeholder/foso.png")
	for i: int in ABISMOS.size():
		var desde: int = int(ABISMOS[i][0])
		var ancho: float = float(int(ABISMOS[i][1]) - desde) * 16.0
		var imagen: Sprite2D = Sprite2D.new()
		imagen.name = "Foso%02d" % (i + 1)
		imagen.texture = textura
		imagen.centered = false
		imagen.z_index = -6
		imagen.scale = Vector2(maxf(1.0, ancho / 96.0), 1.0)
		imagen.position = Vector2(desde * 16.0, alturas[maxi(desde - 1, 0)] * 16.0)
		nodo.add_child(imagen)

func _decoracion(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Decoracion")
	var ambar: Color = Color(1.0, 0.72, 0.36)
	var cian: Color = Color(0.47, 0.91, 0.96)
	var fosforo: Color = Color(0.42, 0.86, 0.52)
	for datos: Array in DECORACION:
		var x: int = int(datos[0])
		if alturas[x] < 0:
			continue
		var nombre: String = str(datos[1])
		var volteado: bool = bool(datos[2])
		var lado: float = -1.0 if volteado else 1.0
		var pie: Vector2 = Vector2(x * 16 + 8, alturas[x] * 16)
		C.objeto(nodo, PROPS + nombre + ".png", pie, -3, volteado)
		match nombre:
			"farola":
				C.luz(nodo, pie + Vector2(3.0 * lado, -38.0), ambar, Vector2(0.9, 0.9), 2, 0.5, "grande")
			"cartel":
				C.luz(nodo, pie + Vector2(-7.0, -22.0), cian, Vector2(0.8, 0.6), 1, 0.4, "grande")
			"servidor_caido":
				C.luz(nodo, pie + Vector2(-9.0 * lado, -7.0), fosforo, Vector2(0.25, 0.25), 1, 0.8)
	# La puerta del relicario: la compuerta (abierta) y una luz roja. Es lo
	# unico rojo del nivel: el color del jefe, antes de verlo.
	var pie_puerta: Vector2 = Vector2(PUERTA * 16 + 8, alturas[PUERTA] * 16)
	C.objeto(nodo, PROPS + "ascensor.png", pie_puerta, -3)
	C.luz(nodo, pie_puerta + Vector2(0.0, -48.0), Color(1.0, 0.35, 0.3), Vector2(0.9, 0.9), 0, 0.6, "grande")
