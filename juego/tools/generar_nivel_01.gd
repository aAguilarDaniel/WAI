# Herramienta: genera el TileSet y la escena del nivel 1 completa.
#
# Se corre con:
#   godot --headless --path juego res://tools/generar_nivel_01.tscn
#
# Va como ESCENA y no como --script a proposito: con --script sobre un SceneTree
# los autoloads no se instancian, y las escenas del juego los necesitan para
# compilar (EstadoJuego, Alma...).
#
# ANTES generaba el terreno por senos y repartia 12 enemigos cada 20 tiles. Eso
# da un nivel, no un PRIMER nivel: no habia orden de aprendizaje, no habia sitio
# donde equivocarse gratis y los enemigos aparecian antes que el arma.
#
# Ahora el nivel es una SECUENCIA DE LECCIONES escrita a mano en las tablas de
# abajo. Cada una introduce UNA cosa, y la introduce con la forma del terreno en
# vez de con un cartel:
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
#   9. Un hueco que un salto andando no cubre        -> correr
#  10. Un pasillo bajo con un enemigo que embiste      -> rodar
#  11. Las armas de maquina, arriba y fuera del camino -> que la ruta es tuya
#  12. Un mirador alto sobre la brasa                  -> cerrar
#
# Las PistaContextual solo aparecen si el jugador se queda parado sin resolverlo.
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const RUTA_TILESET: String = "res://levels/nivel_01/tileset_caja.tres"
const RUTA_NIVEL: String = "res://levels/nivel_01/nivel_01.tscn"

const ANCHO_TILES: int = 216
## Hasta que fila baja el relleno de tierra por debajo de la superficie.
const FONDO_TILES: int = 16
## Fila del suelo mas bajo que se usa. Solo para leer las tablas de abajo.
const SUELO_BASE: int = 9

# ---------------------------------------------------------------------------
# EL NIVEL, EN TABLAS
# ---------------------------------------------------------------------------

## Perfil del suelo: [tile donde empieza el tramo, fila del suelo].
## El suelo se mantiene en esa fila hasta el tramo siguiente. Fila mas baja =
## mas alto en pantalla. El nivel arranca abajo y termina arriba, mirando la
## brasa: es la subida de Sadak (ARTE.md §2) convertida en recorrido.
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
##   3 tiles (48 px) -> NO se cruza andando y SI corriendo. La leccion de correr,
##                      y falla por solo 4 px: lo justo para que se entienda que
##                      lo que falta es velocidad, no puntería.
##
## 4 tiles (64 px) dejaba 8 px de margen incluso corriendo. Se probó con
## tools/prueba_nivel.tscn y no pasaba: por eso ya no hay ninguno.
const ABISMOS: Array = [[45, 47], [97, 100], [154, 157], [173, 176]]

## Plataformas sueltas: [x, fila, largo]. Las de 104 y 110 son la ruta alta que
## permite saltarse a dos enemigos sin pelear: es el argumento del juego puesto
## en el terreno (CLAUDE.md §1, "evitar el combate tambien cuenta como humano").
## Ninguna esta a mas de 2 tiles (32 px) de la superficie desde la que se salta. El
## salto sube 48 px, o sea 3 tiles justos, pero para posarse encima hay que
## rebasar el canto: a 3 tiles se llega raspando y a 4 no se llega. Estaban a 4 y
## a 5, asi que el plasma, la radiacion y la ruta alta eran inalcanzables.
const PLATAFORMAS: Array = [
	[104, 8, 4], [108, 6, 4],   # ruta alta: dos peldanos PEGADOS, de 2 tiles cada uno
	[141, 6, 4],                # pedestal de la lanza de plasma
	[165, 9, 4],                # pedestal del emisor de radiacion
	[196, 3, 3],
]

## Techos: [desde, hasta, fila_inferior]. Se rellena hacia arriba desde esa fila.
## Con la fila 4 el personaje pasa de pie pero no puede saltar: es lo que
## convierte el pasillo en una leccion de atacar y de rodar, en vez de en un
## sitio por el que pasar botando.
const TECHOS: Array = [[61, 75, 4], [125, 137, 4]]

## Muros que cierran el nivel por los extremos: [desde, hasta, fila_superior].
const MUROS: Array = [[0, 3, 0], [212, ANCHO_TILES, 0]]

## Terminales CRT: [tile, id de checkpoint].
const TERMINALES: Array = [
	[34, "nivel_01_crt_01"], [120, "nivel_01_crt_02"], [201, "nivel_01_crt_03"],
]

## Enemigos: [tile, direccion inicial]. Nueve, no doce, y todos DESPUES del arma.
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
## Llevarselas cuesta una desviacion: eso las convierte en una decision.
## La fila del arma es la MISMA que la de su plataforma, igual que las del suelo
## van en la fila de la superficie: asi se apoyan encima y no flotan un tile por
## encima del pedestal.
const ARMAS: Array = [
	[52, "tubo_metal", -1],
	[143, "lanza_plasma", 6],
	[167, "emisor_radiacion", 9],
]

## Vendas: [tile]. Despues de cada tramo de combate, nunca antes.
const VENDAS: Array = [93, 122, 165, 194]

## Pistas contextuales: [tile, accion]. Red de seguridad, no tutorial: solo
## aparecen si el jugador lleva unos segundos ahi sin usar nunca esa accion.
const PISTAS: Array = [
	[18, "saltar"], [34, "interactuar"], [64, "atacar"], [79, "diario"],
	[95, "correr"], [127, "rodar"],
]

## Donde empieza el jugador.
const INICIO: int = 5

# ---------------------------------------------------------------------------

func _ready() -> void:
	var conjunto: TileSet = _crear_tileset()
	var error: int = ResourceSaver.save(conjunto, RUTA_TILESET)
	print("  tileset guardado (ok=%s): %s" % [error == OK, RUTA_TILESET])
	_crear_nivel(conjunto)
	get_tree().quit()

# ---------- TileSet ----------

func _crear_tileset() -> TileSet:
	var conjunto: TileSet = TileSet.new()
	conjunto.tile_size = Vector2i(16, 16)
	conjunto.add_physics_layer(0)
	conjunto.set_physics_layer_collision_layer(0, 1)   # capa "mundo"
	conjunto.set_physics_layer_collision_mask(0, 0)

	var fuente: TileSetAtlasSource = TileSetAtlasSource.new()
	fuente.texture = load("res://art/placeholder/tileset_caja.png")
	fuente.texture_region_size = Vector2i(16, 16)
	# La fuente se registra ANTES de crear los tiles: cada TileData le pregunta a
	# su TileSet cuantas capas de fisica hay, y si todavia no pertenece a ninguno
	# no encuentra la capa 0.
	conjunto.add_source(fuente, 0)

	var cuadrado: PackedVector2Array = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	for indice: int in 4:
		var coordenada: Vector2i = Vector2i(indice, 0)
		fuente.create_tile(coordenada)
		# La celda 2 es relleno decorativo: sin colision, para el interior.
		if indice == 2:
			continue
		var datos: TileData = fuente.get_tile_data(coordenada, 0)
		datos.add_collision_polygon(0)
		datos.set_collision_polygon_points(0, 0, cuadrado)

	return conjunto

# ---------- Nivel ----------

func _crear_nivel(conjunto: TileSet) -> void:
	var raiz: Node2D = Node2D.new()
	raiz.name = "Nivel01"
	raiz.set_script(load("res://levels/nivel.gd"))

	var alturas: PackedInt32Array = _perfil_del_terreno()

	_agregar_cielo(raiz)
	_agregar_parallax(raiz)
	_agregar_fosos(raiz, alturas)
	_agregar_terreno(raiz, conjunto, alturas)
	_agregar_zona_mortal(raiz)

	# Los limites de camara NO se ponen aqui: PackedScene no guarda los cambios a
	# nodos internos de una instancia. Los deriva Nivel._ready() del terreno.
	_instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO * 16, alturas[INICIO] * 16))

	_agregar_terminales(raiz, alturas)
	_agregar_enemigos(raiz, alturas)
	_agregar_recogibles(raiz, alturas)
	_agregar_pistas(raiz, alturas)

	_instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	_agregar_polvo(raiz)
	_agregar_paleta(raiz)
	_agregar_apertura(raiz)

	_asignar_duenio(raiz, raiz)

	var empaquetada: PackedScene = PackedScene.new()
	var error: int = empaquetada.pack(raiz)
	if error != OK:
		printerr("  no se pudo empaquetar el nivel: %d" % error)
		return
	error = ResourceSaver.save(empaquetada, RUTA_NIVEL)
	print("  nivel guardado (ok=%s): %s" % [error == OK, RUTA_NIVEL])
	print("  ancho: %d tiles (%d px)  enemigos: %d  terminales: %d  pistas: %d" % [
		ANCHO_TILES, ANCHO_TILES * 16, ENEMIGOS.size(), TERMINALES.size(), PISTAS.size()])
	# El arbol se construyo fuera del SceneTree: hay que liberarlo a mano o Godot
	# se queja de nodos filtrados al salir.
	raiz.free()

## Convierte la tabla PERFIL en una altura por columna. -1 es abismo.
## Deterministico por definicion: es una tabla, no una funcion de ruido.
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

func _agregar_terreno(raiz: Node2D, conjunto: TileSet, alturas: PackedInt32Array) -> void:
	var capa: TileMapLayer = TileMapLayer.new()
	capa.name = "Terreno"
	capa.tile_set = conjunto
	raiz.add_child(capa)
	for x: int in ANCHO_TILES:
		var superficie: int = alturas[x]
		if superficie < 0:
			continue
		capa.set_cell(Vector2i(x, superficie), 0, Vector2i(1, 0))   # con ceja
		for y: int in range(superficie + 1, FONDO_TILES):
			var celda: Vector2i = Vector2i(0, 0) if y < superficie + 3 else Vector2i(2, 0)
			capa.set_cell(Vector2i(x, y), 0, celda)
	for plataforma: Array in PLATAFORMAS:
		for i: int in int(plataforma[2]):
			capa.set_cell(Vector2i(int(plataforma[0]) + i, int(plataforma[1])), 0, Vector2i(3, 0))
	# Techos: la fila de abajo lleva ceja igual que el suelo, para que el borde
	# del pasillo se lea. Sin eso el techo es una mancha y no una superficie.
	for techo: Array in TECHOS:
		var fila: int = int(techo[2])
		for x: int in range(int(techo[0]), int(techo[1])):
			capa.set_cell(Vector2i(x, fila), 0, Vector2i(1, 0))
			for y: int in range(fila - 5, fila):
				capa.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	for muro: Array in MUROS:
		for x: int in range(int(muro[0]), int(muro[1])):
			if x < 0 or x >= ANCHO_TILES:
				continue
			var tope: int = alturas[x] if alturas[x] >= 0 else FONDO_TILES
			for y: int in range(int(muro[2]) - 6, tope):
				capa.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

func _agregar_zona_mortal(raiz: Node2D) -> void:
	var zona: Area2D = Area2D.new()
	zona.name = "ZonaMortal"
	zona.set_script(load("res://systems/zona_mortal.gd"))
	zona.collision_layer = 0
	zona.collision_mask = 2
	zona.position = Vector2(ANCHO_TILES * 16 * 0.5, FONDO_TILES * 16 + 150)
	var forma: CollisionShape2D = CollisionShape2D.new()
	forma.name = "Forma"
	var rectangulo: RectangleShape2D = RectangleShape2D.new()
	rectangulo.size = Vector2(ANCHO_TILES * 16 + 400, 60)
	forma.shape = rectangulo
	zona.add_child(forma)
	raiz.add_child(zona)

## Los fosos tapan el hueco de los abismos por detras. Sin ellos se ve el
## parallax a traves y el vacio no se lee como profundidad: se lee como ventana.
func _agregar_fosos(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Fosos"
	raiz.add_child(contenedor)
	var textura: Texture2D = load("res://art/placeholder/foso.png")
	for i: int in ABISMOS.size():
		var hueco: Array = ABISMOS[i]
		var desde: int = int(hueco[0])
		var hasta: int = int(hueco[1])
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

# ---------- Fondo ----------

## El cielo va en su propia CanvasLayer por debajo de todo. Cubre la pantalla
## entera pase lo que pase con la camara, que es justo lo que la capa 1 del
## parallax no podia hacer: dejaba dos franjas grises arriba y abajo.
func _agregar_cielo(raiz: Node2D) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "Cielo"
	capa.layer = -100
	capa.set_script(load("res://ui/cielo.gd"))
	var lienzo: ColorRect = ColorRect.new()
	lienzo.name = "Lienzo"
	lienzo.anchor_right = 1.0
	lienzo.anchor_bottom = 1.0
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/cielo.gdshader")
	lienzo.material = material
	capa.add_child(lienzo)
	raiz.add_child(capa)

func _agregar_parallax(raiz: Node2D) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Parallax"
	raiz.add_child(contenedor)
	# nombre, archivo, escala de scroll, z_index.
	# Escalas bajas = lejos. La 6 va por delante del jugador (z positivo).
	# La capa 1 ya no es el cielo: el cielo es el CanvasLayer de arriba. Aqui es
	# la bruma mas lejana, con transparencia, para que el degradado se vea detras.
	var capas: Array = [
		["Capa1Bruma", "capa_1_cielo", 0.03, -50],
		["Capa2Horizonte", "capa_2_horizonte", 0.12, -40],
		["Capa3Torres", "capa_3_torres", 0.26, -30],
		["Capa4Racks", "capa_4_racks", 0.44, -20],
		["Capa5Cercano", "capa_5_cercano", 0.66, -10],
		["Capa6PrimerPlano", "capa_6_primer_plano", 1.28, 20],
	]
	for datos: Array in capas:
		var capa: Parallax2D = Parallax2D.new()
		capa.name = str(datos[0])
		# Sin desplazamiento vertical: las capas se apoyan en el borde de abajo de
		# la pantalla y no se mueven de ahi. Con 0.22 subian y bajaban con la
		# camara, y el canto inferior de los bloques de la capa 5 acababa por
		# encima del suelo: se veian como cuadrados negros flotando.
		capa.scroll_scale = Vector2(float(datos[2]), 0.0)
		capa.repeat_size = Vector2(768, 0)
		capa.repeat_times = 10
		contenedor.add_child(capa)
		var imagen: Sprite2D = Sprite2D.new()
		imagen.name = "Imagen"
		imagen.centered = false
		imagen.texture = load("res://art/placeholder/parallax/%s.png" % datos[1])
		imagen.z_index = int(datos[3])
		# Pegada al borde inferior del cuadro (216 px de alto): lo que quede por
		# debajo lo tapa el terreno, que siempre llega al fondo de la pantalla.
		imagen.position = Vector2(0, 0)
		capa.add_child(imagen)

## Polvo en suspension delante del mundo y detras de la UI. Va en pantalla y no
## en el mundo a proposito: son motas cerca del objetivo, no objetos del nivel.
## Es lo que le quita al cuadro la sensacion de aire limpio y vacio.
func _agregar_polvo(raiz: Node2D) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "PolvoAmbiente"
	capa.layer = 3
	var motas: CPUParticles2D = CPUParticles2D.new()
	motas.name = "Motas"
	motas.amount = 34
	motas.lifetime = 9.0
	motas.preprocess = 9.0
	motas.randomness = 1.0
	motas.lifetime_randomness = 0.6
	motas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motas.emission_rect_extents = Vector2(230.0, 130.0)
	motas.position = Vector2(192.0, 108.0)
	motas.direction = Vector2(-1.0, -0.35)
	motas.spread = 42.0
	motas.gravity = Vector2(-1.0, 2.5)
	motas.initial_velocity_min = 2.0
	motas.initial_velocity_max = 9.0
	motas.scale_amount_min = 1.0
	motas.scale_amount_max = 1.0
	motas.color = Color(1.0, 0.86, 0.66, 0.20)
	motas.material = load("res://art/materiales/aditivo.tres")
	capa.add_child(motas)
	raiz.add_child(capa)

# ---------- Contenido ----------

func _agregar_terminales(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Terminales"
	raiz.add_child(contenedor)
	for i: int in TERMINALES.size():
		var x: int = int(TERMINALES[i][0])
		var nodo: Node = _instanciar("res://systems/save_points/terminal_crt.tscn",
			contenedor, "Terminal%02d" % (i + 1), Vector2(x * 16, alturas[x] * 16))
		nodo.set("checkpoint_id", str(TERMINALES[i][1]))

func _agregar_enemigos(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Enemigos"
	raiz.add_child(contenedor)
	for i: int in ENEMIGOS.size():
		var x: int = int(ENEMIGOS[i][0])
		if alturas[x] < 0:
			continue
		var nodo: Node = _instanciar("res://actors/enemies/enemigo_patrulla.tscn",
			contenedor, "Enemigo%02d" % (i + 1), Vector2(x * 16, alturas[x] * 16))
		nodo.set("direccion_inicial", int(ENEMIGOS[i][1]))

func _agregar_recogibles(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Recogibles"
	raiz.add_child(contenedor)

	# El diario NO esta al inicio: aparece a los pocos minutos (CLAUDE.md §3.3),
	# despues de la primera pelea, que es cuando ya hay algo que anotar.
	var cuaderno: Node = _instanciar("res://systems/pickups/recogible.tscn", contenedor,
		"CuadernoDeCampo", Vector2(78 * 16, alturas[78] * 16))
	cuaderno.set("clase", 1)
	cuaderno.set("titulo_entrada", "Un cuaderno")
	cuaderno.set("texto_entrada",
		"[PENDIENTE] Escribir en primera persona. Ver docs/TEXTOS_PENDIENTES.md")

	for datos: Array in ARMAS:
		var x: int = int(datos[0])
		var fila: int = int(datos[2])
		var y: int = alturas[x] if fila < 0 else fila
		var nodo: Node = _instanciar("res://systems/pickups/recogible.tscn", contenedor,
			"Arma_%s" % datos[1], Vector2(x * 16, y * 16))
		nodo.set("clase", 0)
		nodo.set("arma", load("res://systems/weapons/data/%s.tres" % datos[1]))

	for x: int in VENDAS:
		var nodo: Node = _instanciar("res://systems/pickups/recogible.tscn", contenedor,
			"Vendas_%d" % x, Vector2(x * 16, alturas[x] * 16))
		nodo.set("clase", 2)
		nodo.set("cantidad", 1)

func _agregar_pistas(raiz: Node2D, alturas: PackedInt32Array) -> void:
	var contenedor: Node2D = Node2D.new()
	contenedor.name = "Pistas"
	raiz.add_child(contenedor)
	for datos: Array in PISTAS:
		var x: int = int(datos[0])
		var nodo: Node = _instanciar("res://systems/pista_contextual.tscn", contenedor,
			"Pista_%s" % datos[1], Vector2(x * 16, alturas[x] * 16))
		nodo.set("accion", StringName(str(datos[1])))

func _agregar_paleta(raiz: Node2D) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "PaletaAlma"
	capa.layer = 5
	capa.set_script(load("res://ui/paleta_alma.gd"))
	var lienzo: ColorRect = ColorRect.new()
	lienzo.name = "Lienzo"
	lienzo.anchor_right = 1.0
	lienzo.anchor_bottom = 1.0
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/paleta_alma.gdshader")
	lienzo.material = material
	capa.add_child(lienzo)
	raiz.add_child(capa)

func _agregar_apertura(raiz: Node2D) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "AperturaSadak"
	capa.layer = 8
	capa.set_script(load("res://ui/apertura_sadak.gd"))
	var titulo: Label = Label.new()
	titulo.name = "Titulo"
	titulo.text = "WHO AM I"
	titulo.anchor_left = 0.5
	titulo.anchor_right = 0.5
	titulo.offset_left = -100.0
	titulo.offset_right = 100.0
	titulo.offset_top = 48.0
	titulo.offset_bottom = 76.0
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 24 = dos veces el alto de linea de la fuente bitmap. Con scaling_mode en
	# entero, x2 sale nitido; cualquier otro numero interpola y se ve sucio.
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.87, 0.62))
	capa.add_child(titulo)
	raiz.add_child(capa)

# ---------- Utilidades ----------

func _instanciar(ruta: String, padre: Node, nombre: String, posicion: Vector2) -> Node:
	var escena: PackedScene = load(ruta)
	var nodo: Node = escena.instantiate()
	nodo.name = nombre
	if nodo is Node2D:
		(nodo as Node2D).position = posicion
	padre.add_child(nodo)
	return nodo

## Sin owner, PackedScene descarta los nodos. Las instancias de otras escenas se
## marcan pero NO sus hijos internos: asi se guardan como instancia, no expandidas.
func _asignar_duenio(nodo: Node, duenio: Node) -> void:
	for hijo: Node in nodo.get_children():
		hijo.owner = duenio
		if hijo.scene_file_path.is_empty():
			_asignar_duenio(hijo, duenio)
