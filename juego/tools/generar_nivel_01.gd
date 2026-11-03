# Herramienta: genera la escena del nivel 1 completa.
#
# Se corre con:
#   godot --headless --path juego res://tools/generar_nivel_01.tscn
#
# Va como ESCENA y no como --script a proposito: con --script sobre un SceneTree
# los autoloads no se instancian, y las escenas del juego los necesitan para
# compilar (EstadoJuego, Alma...).
#
# Lo comun a todos los niveles (tileset, parallax, luces, guardado) esta en
# tools/constructor_nivel.gd. Aqui solo va lo que es de ESTE nivel: las tablas.
#
# El nivel es una SECUENCIA DE LECCIONES escrita a mano en las tablas de abajo.
# Cada una introduce UNA cosa, y la introduce con la forma del terreno en vez de
# con un cartel:
#
#   1. Un pasillo plano sin nada que pueda matarte     -> caminar
#   2. Un escalon que no se sube andando               -> saltar
#   3. Un CRT encendido, lo unico con luz del cuadro   -> interactuar y guardar
#   4. Un abismo justo despues del CRT                 -> saltar comprometido, y
#                                                         de paso descubrir para
#                                                         que servia el checkpoint
#   5. Un tubo de metal tirado en el camino            -> recoger un arma
#   6. Un enemigo en un pasillo con techo bajo         -> atacar (no se puede saltar)
#   7. El cuaderno de campo                            -> el diario
#   8. Dos enemigos con una ruta alta por encima       -> que evitarlos tambien vale
#   9. Un hueco que un salto andando no cubre          -> correr
#  10. Un pasillo bajo con un enemigo que embiste      -> rodar
#  11. Las armas de maquina, arriba y fuera del camino -> que la ruta es tuya
#  12. El edificio, con el portal como unica luz verde -> entrar (nivel 2)
#
# Las PistaContextual solo aparecen si el jugador se queda parado sin resolverlo.
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_01/nivel_01.tscn"
const RUTA_SIGUIENTE: String = "res://levels/nivel_02/nivel_02.tscn"
const PROPS: String = "res://art/placeholder/props/"

## 216 tiles de recorrido mas 2 de muro detras del edificio.
const ANCHO_TILES: int = 218
## Hasta que fila baja el relleno de tierra por debajo de la superficie.
const FONDO_TILES: int = 16
## Fila del suelo mas bajo que se usa. Solo para leer las tablas de abajo.
const SUELO_BASE: int = 9

# ---------------------------------------------------------------------------
# EL NIVEL, EN TABLAS
# ---------------------------------------------------------------------------

## Perfil del suelo: [tile donde empieza el tramo, fila del suelo].
## El suelo se mantiene en esa fila hasta el tramo siguiente. Fila mas baja =
## mas alto en pantalla. El nivel arranca abajo y termina arriba, frente al
## edificio: es la subida de Sadak (ARTE.md §2) convertida en recorrido.
const PERFIL: Array = [
	[0, 9], [17, 8], [26, 7], [48, 7], [75, 7], [83, 8], [87, 9], [91, 10],
	[101, 10], [115, 9], [119, 8], [137, 8], [149, 9], [152, 10], [157, 11],
	[161, 11], [177, 10], [180, 9], [183, 8], [186, 7], [189, 6], [193, 5],
]

## Abismos: [desde, hasta) en tiles.
##
## Estan MEDIDOS contra el salto del jugador, no puestos a ojo. Con altura_salto
## 48, tiempo_subida 0.35 y multiplicador_caida 1.6 son 0.63 s en el aire:
## andando (70 px/s) alcanza 44 px, corriendo (115 px/s) alcanza 72 px.
##
##   2 tiles (32 px) -> se cruza andando. El primero, la leccion de saltar.
##   3 tiles (48 px) -> NO se cruza andando y SI corriendo. La leccion de correr.
##
## 4 tiles (64 px) dejaba 8 px de margen incluso corriendo. Se probó con
## tools/prueba_nivel.tscn y no pasaba: por eso ya no hay ninguno.
const ABISMOS: Array = [[45, 47], [97, 100], [154, 157], [173, 176]]

## Plataformas sueltas: [x, fila, largo]. Las de 104 y 108 son la ruta alta que
## permite saltarse a dos enemigos sin pelear: es el argumento del juego puesto
## en el terreno (CLAUDE.md §1, "evitar el combate tambien cuenta como humano").
## Ninguna esta a mas de 2 tiles (32 px) de la superficie desde la que se salta.
const PLATAFORMAS: Array = [
	[104, 8, 4], [108, 6, 4],   # ruta alta: dos peldanos PEGADOS, de 2 tiles cada uno
	[141, 6, 4],                # pedestal de la lanza de plasma
	[165, 9, 4],                # pedestal del emisor de radiacion
	[196, 3, 3],
]

## Techos: [desde, hasta, fila_inferior]. Se rellena hacia arriba desde esa fila.
## Con la fila 4 el personaje pasa de pie pero no puede saltar: es lo que
## convierte el pasillo en una leccion de atacar y de rodar.
const TECHOS: Array = [[61, 75, 4], [125, 137, 4]]

## Muros que cierran el nivel por los extremos: [desde, hasta, fila_superior].
## El de la derecha queda DETRAS del edificio: el portal se cruza antes.
const MUROS: Array = [[0, 3, 0], [216, ANCHO_TILES, 0]]

## Terminales CRT: [tile, id de checkpoint].
const TERMINALES: Array = [
	[34, "nivel_01_crt_01"], [120, "nivel_01_crt_02"], [201, "nivel_01_crt_03"],
]

## Enemigos: [tile, direccion inicial]. Nueve, y todos DESPUES del arma.
## El primero esta solo y encerrado: es donde se aprende a pegar sin morir.
const ENEMIGOS: Array = [
	[68, -1],                       # 6. pasillo cerrado: hay que pelear
	[88, 1],                        # 8. abierto, con ruta alta por encima
	[106, -1], [112, 1],            # 8. los dos que se pueden evitar
	[131, -1],                      # 10. pasillo bajo: hay que rodar
	[151, 1], [159, -1],            # 11. el descenso
	[184, -1], [190, 1],            # 12. la ultima subida
]

## Armas del mundo: [tile, id, fila (-1 = apoyada en el suelo)].
## El tubo esta EN el camino; el plasma y la radiacion, arriba y fuera de el.
const ARMAS: Array = [
	[52, "tubo_metal", -1],
	[143, "lanza_plasma", 6],
	[167, "emisor_radiacion", 9],
]

## Vendas: [tile]. Despues de cada tramo de combate, nunca antes.
const VENDAS: Array = [93, 122, 165, 194]

## Pistas contextuales: [tile, accion]. Red de seguridad, no tutorial.
const PISTAS: Array = [
	[18, "saltar"], [34, "interactuar"], [64, "atacar"], [79, "diario"],
	[95, "correr"], [127, "rodar"],
]

## Donde empieza el jugador.
const INICIO: int = 5

## El edificio: tile del borde izquierdo de la fachada (224 px = 14 tiles). El
## portal queda en el centro, tile 209. Se cruza andando.
const EDIFICIO: int = 202
const PORTAL: int = 209

## Objetos de escenario: [tile, archivo en art/placeholder/props, volteado].
## Detras del jugador y del terreno de juego, nunca en los pasillos de techo bajo.
## Son lo que le da escala al cuadro: sin ellos el suelo era una losa sin nada
## con que comparar al personaje.
const DECORACION: Array = [
	[8, "farola", false], [13, "chatarra", false], [22, "barril", false],
	[29, "valla", false], [40, "poste", false], [50, "servidor_caido", false],
	[57, "farola", true], [81, "chatarra", true], [86, "cartel", false],
	[92, "barril", false], [116, "farola", false], [123, "valla", true],
	[139, "poste", false], [147, "servidor_caido", true], [162, "chatarra", false],
	[170, "cartel", false], [181, "farola", true], [192, "valla", false],
	[199, "barril", false],
]

# ---------------------------------------------------------------------------

func _ready() -> void:
	var conjunto: TileSet = C.crear_tileset()
	_crear_nivel(conjunto)
	get_tree().quit()

func _crear_nivel(conjunto: TileSet) -> void:
	var raiz: Node2D = C.raiz("Nivel01")
	raiz.set("encuadre_camara", Vector2(0.0, -40.0))
	var alturas: PackedInt32Array = _perfil_del_terreno()

	# El cielo va en su propia CanvasLayer por debajo de todo: la capa 1 del
	# parallax no cubria el recorrido vertical de la camara (CLAUDE.md §7, bug 1).
	C.fondo(raiz, "Cielo", "res://shaders/cielo.gdshader")
	# Escalas bajas = lejos. La 6 va por delante del jugador (z positivo).
	C.parallax(raiz, [
		["Capa1Bruma", "res://art/placeholder/parallax/capa_1_cielo.png", 0.03, -50],
		["Capa2Horizonte", "res://art/placeholder/parallax/capa_2_horizonte.png", 0.12, -40],
		["Capa3Torres", "res://art/placeholder/parallax/capa_3_torres.png", 0.26, -30],
		["Capa4Racks", "res://art/placeholder/parallax/capa_4_racks.png", 0.44, -20],
		["Capa5Cercano", "res://art/placeholder/parallax/capa_5_cercano.png", 0.66, -10],
		["Capa6PrimerPlano", "res://art/placeholder/parallax/capa_6_primer_plano.png", 1.28, 20],
	])
	_agregar_fosos(raiz, alturas)
	_agregar_edificio(raiz, alturas)
	_agregar_decoracion(raiz, alturas)
	_agregar_terreno(C.terreno(raiz, conjunto), alturas)
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, FONDO_TILES * 16.0 + 150.0)

	# Los limites de camara NO se ponen aqui: PackedScene no guarda los cambios a
	# nodos internos de una instancia. Los deriva Nivel._ready() del terreno.
	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO * 16, alturas[INICIO] * 16))

	_agregar_terminales(raiz, alturas)
	_agregar_enemigos(raiz, alturas)
	_agregar_recogibles(raiz, alturas)
	_agregar_pistas(raiz, alturas)
	var puerta: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"PortalEdificio", Vector2(PORTAL * 16, alturas[PORTAL] * 16))
	puerta.set("destino", RUTA_SIGUIENTE)

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(1.0, 0.86, 0.66, 0.20))
	C.paleta(raiz)
	C.apertura(raiz, "AperturaSadak", "WHO AM I", Vector2(0.65, 0.65),
		Vector2(40.0, -70.0), 4.0)

	C.guardar(raiz, RUTA_NIVEL)
	print("  ancho: %d tiles (%d px)  enemigos: %d  terminales: %d  objetos: %d" % [
		ANCHO_TILES, ANCHO_TILES * 16, ENEMIGOS.size(), TERMINALES.size(),
		DECORACION.size()])

## Convierte la tabla PERFIL en una altura por columna. -1 es abismo.
func _perfil_del_terreno() -> PackedInt32Array:
	var alturas: PackedInt32Array = PackedInt32Array()
	alturas.resize(ANCHO_TILES)
	var altura: int = SUELO_BASE
	var siguiente: int = 0
	for x: int in ANCHO_TILES:
		while siguiente < PERFIL.size() and int(PERFIL[siguiente][0]) <= x:
			altura = int(PERFIL[siguiente][1])
			siguiente += 1
		alturas[x] = altura
	for hueco: Array in ABISMOS:
		for x: int in range(int(hueco[0]), int(hueco[1])):
			if x < ANCHO_TILES:
				alturas[x] = -1
	return alturas

## El suelo tiene estratos: costra con ceja, dos filas de escombro (a veces con un
## tubo o una placa base enterrada), relleno y, abajo del todo, casi negro. Antes
## era la misma celda repetida hasta el fondo y se leia como una losa.
func _agregar_terreno(capa: TileMapLayer, alturas: PackedInt32Array) -> void:
	for x: int in ANCHO_TILES:
		var superficie: int = alturas[x]
		if superficie < 0:
			continue
		var tapa: Vector2i = C.EXT_SUPERFICIE
		if C.azar(x, superficie, 1) < 0.12:
			tapa = C.EXT_SUPERFICIE_ZANJA
		capa.set_cell(Vector2i(x, superficie), 0, tapa)
		for y: int in range(superficie + 1, FONDO_TILES):
			capa.set_cell(Vector2i(x, y), 0, _celda_por_profundidad(x, y, y - superficie))
	for plataforma: Array in PLATAFORMAS:
		for i: int in int(plataforma[2]):
			capa.set_cell(Vector2i(int(plataforma[0]) + i, int(plataforma[1])), 0, C.EXT_VIGA)
	# Techos: la fila de abajo lleva un tubo, para que el borde del pasillo se lea
	# como una superficie y no como una mancha.
	for techo: Array in TECHOS:
		var fila: int = int(techo[2])
		for x: int in range(int(techo[0]), int(techo[1])):
			capa.set_cell(Vector2i(x, fila), 0, C.EXT_SOLIDA_TUBO)
			for y: int in range(fila - 5, fila):
				capa.set_cell(Vector2i(x, y), 0, C.EXT_SOLIDA)
	for muro: Array in MUROS:
		for x: int in range(int(muro[0]), int(muro[1])):
			if x < 0 or x >= ANCHO_TILES:
				continue
			var tope: int = alturas[x] if alturas[x] >= 0 else FONDO_TILES
			for y: int in range(int(muro[2]) - 6, tope):
				capa.set_cell(Vector2i(x, y), 0, C.EXT_SOLIDA)

func _celda_por_profundidad(x: int, y: int, profundidad: int) -> Vector2i:
	if profundidad <= 2:
		# Los tubos van en tramos de 6 columnas: un tubo de un solo tile se leia
		# como un ladrillo suelto, no como una tuberia enterrada.
		if profundidad == 2 and C.azar(x / 6, y, 2) < 0.22:
			return C.EXT_SOLIDA_TUBO
		if C.azar(x, y, 3) < 0.025:
			return C.EXT_SOLIDA_PLACA
		return C.EXT_SOLIDA
	if profundidad <= 5:
		return C.EXT_RELLENO
	return C.EXT_PROFUNDO

## Los fosos tapan el hueco de los abismos por detras. Sin ellos se ve el
## parallax a traves y el vacio no se lee como profundidad: se lee como ventana.
func _agregar_fosos(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = C.contenedor(raiz, "Fosos")
	var textura: Texture2D = load("res://art/placeholder/foso.png")
	for i: int in ABISMOS.size():
		var desde: int = int(ABISMOS[i][0])
		var hasta: int = int(ABISMOS[i][1])
		var borde: int = alturas[maxi(desde - 1, 0)]
		var ancho: float = float(hasta - desde) * 16.0
		var imagen: Sprite2D = Sprite2D.new()
		imagen.name = "Foso%02d" % (i + 1)
		imagen.texture = textura
		imagen.centered = false
		imagen.z_index = -6
		# El foso mide 96 px de ancho: se estira si el hueco es mas ancho.
		imagen.scale = Vector2(maxf(1.0, ancho / 96.0), 1.0)
		imagen.position = Vector2(float(desde) * 16.0, float(borde) * 16.0)
		contenedor.add_child(imagen)

## La fachada va detras del terreno (su umbral se apoya en el suelo) y lleva dos
## luces: el ojo de fosforo del roseton y el resplandor verde del portal. Es lo
## unico verde del final del nivel: dice "por aqui" sin escribir nada.
func _agregar_edificio(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var nodo: Node2D = C.contenedor(raiz, "Edificio")
	var pie: Vector2 = Vector2(EDIFICIO * 16 + 112, alturas[PORTAL] * 16 + 2)
	C.objeto(nodo, "res://art/placeholder/edificio_fachada.png", pie, -4)
	var fosforo: Color = Color(0.42, 0.86, 0.52)
	C.luz(nodo, pie + Vector2(0.0, -214.0), fosforo, Vector2(1.3, 1.3), 0, 0.35, "grande")
	C.luz(nodo, pie + Vector2(0.0, -22.0), fosforo, Vector2(0.8, 1.1), 0, 0.5, "grande")
	C.luz(nodo, pie + Vector2(0.0, -352.0), Color(1.0, 0.3, 0.2), Vector2(0.3, 0.3), 1, 0.8)

## Objetos y sus luces. Las luces se encajan a mano contra cada PNG: si se
## redibuja un objeto, puede hacer falta mover su luz aqui.
func _agregar_decoracion(raiz: Node2D, alturas: PackedInt32Array) -> void:
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

func _agregar_terminales(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = C.contenedor(raiz, "Terminales")
	for i: int in TERMINALES.size():
		var x: int = int(TERMINALES[i][0])
		var nodo: Node = C.instanciar("res://systems/save_points/terminal_crt.tscn",
			contenedor, "Terminal%02d" % (i + 1), Vector2(x * 16, alturas[x] * 16))
		nodo.set("checkpoint_id", str(TERMINALES[i][1]))

func _agregar_enemigos(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = C.contenedor(raiz, "Enemigos")
	for i: int in ENEMIGOS.size():
		var x: int = int(ENEMIGOS[i][0])
		if alturas[x] < 0:
			continue
		var nodo: Node = C.instanciar("res://actors/enemies/enemigo_patrulla.tscn",
			contenedor, "Enemigo%02d" % (i + 1), Vector2(x * 16, alturas[x] * 16))
		nodo.set("direccion_inicial", int(ENEMIGOS[i][1]))

func _agregar_recogibles(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = C.contenedor(raiz, "Recogibles")

	# El diario NO esta al inicio: aparece a los pocos minutos (CLAUDE.md §3.3),
	# despues de la primera pelea, que es cuando ya hay algo que anotar.
	var cuaderno: Node = C.instanciar("res://systems/pickups/recogible.tscn", contenedor,
		"CuadernoDeCampo", Vector2(78 * 16, alturas[78] * 16))
	cuaderno.set("clase", 1)
	cuaderno.set("titulo_entrada", "Un cuaderno")
	cuaderno.set("texto_entrada",
		"[PENDIENTE] Escribir en primera persona. Ver docs/TEXTOS_PENDIENTES.md")

	for datos: Array in ARMAS:
		var x: int = int(datos[0])
		var fila: int = int(datos[2])
		var y: int = alturas[x] if fila < 0 else fila
		var nodo: Node = C.instanciar("res://systems/pickups/recogible.tscn", contenedor,
			"Arma_%s" % datos[1], Vector2(x * 16, y * 16))
		nodo.set("clase", 0)
		nodo.set("arma", load("res://systems/weapons/data/%s.tres" % datos[1]))

	for x: int in VENDAS:
		var nodo: Node = C.instanciar("res://systems/pickups/recogible.tscn", contenedor,
			"Vendas_%d" % x, Vector2(x * 16, alturas[x] * 16))
		nodo.set("clase", 2)
		nodo.set("cantidad", 1)

func _agregar_pistas(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = C.contenedor(raiz, "Pistas")
	for datos: Array in PISTAS:
		var x: int = int(datos[0])
		var nodo: Node = C.instanciar("res://systems/pista_contextual.tscn", contenedor,
			"Pista_%s" % datos[1], Vector2(x * 16, alturas[x] * 16))
		nodo.set("accion", StringName(str(datos[1])))
