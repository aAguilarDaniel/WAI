# Piezas comunes de las herramientas que generan niveles (generar_nivel_01.gd y
# generar_nivel_02.gd). Solo se usa desde tools/: el juego no lo carga nunca.
#
# Existe para que cada generador sea SOLO la descripcion de su nivel (las tablas)
# y no otra copia de como se monta un parallax, se instancia una terminal o se
# guarda un PackedScene. Antes todo eso vivia dentro de generar_nivel_01.gd, y un
# segundo nivel lo habria duplicado entero.
class_name ConstructorNivel
extends RefCounted

const TAM: int = 16
const RUTA_TILESET: String = "res://levels/comun/tileset_mundo.tres"
const TEXTURA_TILESET: String = "res://art/placeholder/tileset_mundo.png"
const BRILLO: String = "res://art/placeholder/efectos/brillo.png"
const BRILLO_GRANDE: String = "res://art/placeholder/efectos/brillo_grande.png"
const CONO: String = "res://art/placeholder/efectos/cono.png"
const ADITIVO: String = "res://art/materiales/aditivo.tres"
const SCRIPT_LUZ: String = "res://systems/efectos/luz_parpadeante.gd"

# --- Celdas del atlas (art/placeholder/tileset_mundo.png, 8x2) ---
# Fila 0, exterior.
const EXT_SOLIDA: Vector2i = Vector2i(0, 0)
const EXT_SUPERFICIE: Vector2i = Vector2i(1, 0)
const EXT_RELLENO: Vector2i = Vector2i(2, 0)
const EXT_VIGA: Vector2i = Vector2i(3, 0)
const EXT_PROFUNDO: Vector2i = Vector2i(4, 0)
const EXT_SUPERFICIE_ZANJA: Vector2i = Vector2i(5, 0)
const EXT_SOLIDA_TUBO: Vector2i = Vector2i(6, 0)
const EXT_SOLIDA_PLACA: Vector2i = Vector2i(7, 0)
# Fila 1, interior.
const INT_SUELO: Vector2i = Vector2i(0, 1)
const INT_MURO: Vector2i = Vector2i(1, 1)
const INT_MURO_REJILLA: Vector2i = Vector2i(2, 1)
const INT_PASARELA: Vector2i = Vector2i(3, 1)
const INT_TECHO: Vector2i = Vector2i(4, 1)
const INT_RELLENO: Vector2i = Vector2i(5, 1)
const INT_SUELO_FRANJAS: Vector2i = Vector2i(6, 1)
const INT_BLOQUE: Vector2i = Vector2i(7, 1)

## Celdas sin colision: solo van rodeadas de solidas, en el interior de la masa.
const SIN_COLISION: Array[Vector2i] = [EXT_RELLENO, EXT_PROFUNDO, INT_RELLENO]
## Celdas que se atraviesan desde abajo. Solo colisionan los 4 px de arriba.
const UN_SENTIDO: Array[Vector2i] = [INT_PASARELA]

# ---------------------------------------------------------------- TileSet ----

## Crea y guarda el TileSet compartido por todos los niveles.
static func crear_tileset() -> TileSet:
	var conjunto: TileSet = TileSet.new()
	conjunto.tile_size = Vector2i(TAM, TAM)
	conjunto.add_physics_layer(0)
	conjunto.set_physics_layer_collision_layer(0, 1)   # capa "mundo"
	conjunto.set_physics_layer_collision_mask(0, 0)

	var fuente: TileSetAtlasSource = TileSetAtlasSource.new()
	fuente.texture = load(TEXTURA_TILESET)
	fuente.texture_region_size = Vector2i(TAM, TAM)
	# La fuente se registra ANTES de crear los tiles: cada TileData le pregunta a
	# su TileSet cuantas capas de fisica hay, y si todavia no pertenece a ninguno
	# no encuentra la capa 0 (CLAUDE.md §7).
	conjunto.add_source(fuente, 0)

	var medio: float = TAM * 0.5
	var cuadrado: PackedVector2Array = PackedVector2Array([
		Vector2(-medio, -medio), Vector2(medio, -medio),
		Vector2(medio, medio), Vector2(-medio, medio)])
	var tapa: PackedVector2Array = PackedVector2Array([
		Vector2(-medio, -medio), Vector2(medio, -medio),
		Vector2(medio, -medio + 4.0), Vector2(-medio, -medio + 4.0)])

	for fila: int in 2:
		for columna: int in 8:
			var celda: Vector2i = Vector2i(columna, fila)
			fuente.create_tile(celda)
			if SIN_COLISION.has(celda):
				continue
			var datos: TileData = fuente.get_tile_data(celda, 0)
			datos.add_collision_polygon(0)
			if UN_SENTIDO.has(celda):
				datos.set_collision_polygon_points(0, 0, tapa)
				datos.set_collision_polygon_one_way(0, 0, true)
			else:
				datos.set_collision_polygon_points(0, 0, cuadrado)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		RUTA_TILESET.get_base_dir()))
	var error: int = ResourceSaver.save(conjunto, RUTA_TILESET)
	print("  tileset guardado (ok=%s): %s" % [error == OK, RUTA_TILESET])
	return load(RUTA_TILESET) as TileSet

# --------------------------------------------------------------- Esqueleto ----

static func raiz(nombre: String) -> Node2D:
	var nodo: Node2D = Node2D.new()
	nodo.name = nombre
	nodo.set_script(load("res://levels/nivel.gd"))
	return nodo

static func contenedor(padre: Node, nombre: String) -> Node2D:
	var nodo: Node2D = Node2D.new()
	nodo.name = nombre
	padre.add_child(nodo)
	return nodo

static func terreno(padre: Node, conjunto: TileSet) -> TileMapLayer:
	var capa: TileMapLayer = TileMapLayer.new()
	capa.name = "Terreno"
	capa.tile_set = conjunto
	padre.add_child(capa)
	return capa

static func instanciar(ruta: String, padre: Node, nombre: String, posicion: Vector2) -> Node:
	var escena: PackedScene = load(ruta)
	var nodo: Node = escena.instantiate()
	nodo.name = nombre
	if nodo is Node2D:
		(nodo as Node2D).position = posicion
	padre.add_child(nodo)
	return nodo

## Caerse al vacio mata. Una franja que cubre todo el ancho, por debajo.
static func zona_mortal(padre: Node, ancho_px: float, y: float) -> void:
	var zona: Area2D = Area2D.new()
	zona.name = "ZonaMortal"
	zona.set_script(load("res://systems/zona_mortal.gd"))
	zona.collision_layer = 0
	zona.collision_mask = 2
	zona.position = Vector2(ancho_px * 0.5, y)
	var forma: CollisionShape2D = CollisionShape2D.new()
	forma.name = "Forma"
	var rectangulo: RectangleShape2D = RectangleShape2D.new()
	rectangulo.size = Vector2(ancho_px + 400.0, 60.0)
	forma.shape = rectangulo
	zona.add_child(forma)
	padre.add_child(zona)

# ------------------------------------------------------------------ Fondo ----

## Fondo de pantalla completa por debajo de todo (cielo o interior). Va en una
## CanvasLayer para que ningun movimiento de camara lo deje corto.
static func fondo(padre: Node, nombre: String, ruta_shader: String,
		parametros: Dictionary = {}) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = nombre
	capa.layer = -100
	capa.set_script(load("res://ui/cielo.gd"))
	var lienzo: ColorRect = ColorRect.new()
	lienzo.name = "Lienzo"
	lienzo.anchor_right = 1.0
	lienzo.anchor_bottom = 1.0
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(ruta_shader)
	for clave: String in parametros:
		material.set_shader_parameter(clave, parametros[clave])
	lienzo.material = material
	capa.add_child(lienzo)
	padre.add_child(capa)

## capas: [[nombre, ruta_png, scroll_x, z_index], ...]. Todas de 768 px de ancho
## y repetidas. Sin desplazamiento vertical: con el, el canto de abajo de las
## capas cercanas acababa por encima del suelo (CLAUDE.md §7, bug 6).
static func parallax(padre: Node, capas: Array) -> void:
	var nodo: Node2D = contenedor(padre, "Parallax")
	for datos: Array in capas:
		var capa: Parallax2D = Parallax2D.new()
		capa.name = str(datos[0])
		capa.scroll_scale = Vector2(float(datos[2]), 0.0)
		capa.repeat_size = Vector2(768, 0)
		capa.repeat_times = 10
		nodo.add_child(capa)
		var imagen: Sprite2D = Sprite2D.new()
		imagen.name = "Imagen"
		imagen.centered = false
		imagen.texture = load(str(datos[1]))
		imagen.z_index = int(datos[3])
		capa.add_child(imagen)

## Motas en suspension delante del mundo y detras de la UI.
static func polvo(padre: Node, color: Color, cantidad: int = 34) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "PolvoAmbiente"
	capa.layer = 3
	var motas: CPUParticles2D = CPUParticles2D.new()
	motas.name = "Motas"
	motas.amount = cantidad
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
	motas.color = color
	motas.material = load(ADITIVO)
	capa.add_child(motas)
	padre.add_child(capa)

static func paleta(padre: Node) -> void:
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
	padre.add_child(capa)

## Plano fijo de entrada que devuelve el control sin corte (ui/apertura_sadak.gd).
## titulo vacio = sin texto, solo el encuadre.
static func apertura(padre: Node, nombre: String, titulo: String, zoom: Vector2,
		desplazamiento: Vector2, duracion: float) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = nombre
	capa.layer = 8
	capa.set_script(load("res://ui/apertura_sadak.gd"))
	capa.set("zoom_apertura", zoom)
	capa.set("desplazamiento_apertura", desplazamiento)
	capa.set("duracion_plano", duracion)
	capa.set("aparicion_titulo", minf(1.5, duracion * 0.5))
	var etiqueta: Label = Label.new()
	etiqueta.name = "Titulo"
	etiqueta.text = titulo
	etiqueta.anchor_left = 0.5
	etiqueta.anchor_right = 0.5
	etiqueta.offset_left = -100.0
	etiqueta.offset_right = 100.0
	etiqueta.offset_top = 48.0
	etiqueta.offset_bottom = 76.0
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 24 = dos veces el alto de linea de la fuente bitmap: x2 sale nitido.
	etiqueta.add_theme_font_size_override("font_size", 24)
	etiqueta.add_theme_color_override("font_color", Color(1.0, 0.87, 0.62))
	capa.add_child(etiqueta)
	padre.add_child(capa)

# ---------------------------------------------------------- Decoracion ----

## Objeto de escenario apoyado por su base en `pie` (centro inferior).
static func objeto(padre: Node, ruta_png: String, pie: Vector2, z: int = -3,
		volteado: bool = false) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(ruta_png)
	sprite.centered = false
	var tam: Vector2 = sprite.texture.get_size()
	sprite.position = (pie - Vector2(tam.x * 0.5, tam.y)).round()
	sprite.z_index = z
	sprite.flip_h = volteado
	sprite.name = "%s_%d" % [ruta_png.get_file().get_basename(), int(pie.x)]
	padre.add_child(sprite)
	return sprite

## Halo de luz aditivo. modo: 0 respirar, 1 parpadear, 2 averiada
## (LuzParpadeante.Modo). textura: "brillo", "grande" o "cono".
static func luz(padre: Node, centro: Vector2, color: Color, escala: Vector2,
		modo: int = 0, intensidad: float = 0.55, textura: String = "brillo") -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	var rutas: Dictionary = {"brillo": BRILLO, "grande": BRILLO_GRANDE, "cono": CONO}
	sprite.texture = load(str(rutas.get(textura, BRILLO)))
	sprite.material = load(ADITIVO)
	sprite.position = centro
	sprite.scale = escala
	sprite.z_index = 1 if textura == "cono" else -2
	sprite.set_script(load(SCRIPT_LUZ))
	sprite.set("modo", modo)
	sprite.set("color", color)
	sprite.set("intensidad", intensidad)
	sprite.name = "Luz_%d_%d" % [int(centro.x), int(centro.y)]
	padre.add_child(sprite)
	return sprite

# ---------------------------------------------------------------- Guardar ----

## Sin owner, PackedScene descarta los nodos. Las instancias de otras escenas se
## marcan pero NO sus hijos internos: asi se guardan como instancia, no expandidas.
static func asignar_duenio(nodo: Node, duenio: Node) -> void:
	for hijo: Node in nodo.get_children():
		hijo.owner = duenio
		if hijo.scene_file_path.is_empty():
			asignar_duenio(hijo, duenio)

## Empaqueta y guarda. Libera el arbol: se construyo fuera del SceneTree y Godot
## se queja de nodos filtrados al salir si no.
static func guardar(raiz_nivel: Node, ruta: String) -> bool:
	asignar_duenio(raiz_nivel, raiz_nivel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
	var empaquetada: PackedScene = PackedScene.new()
	var error: int = empaquetada.pack(raiz_nivel)
	if error != OK:
		printerr("  no se pudo empaquetar %s: %d" % [ruta, error])
		raiz_nivel.free()
		return false
	error = ResourceSaver.save(empaquetada, ruta)
	print("  nivel guardado (ok=%s): %s" % [error == OK, ruta])
	raiz_nivel.free()
	return error == OK

## Variacion determinista por columna y fila: la misma entrada da siempre la
## misma celda, asi regenerar el nivel no cambia su aspecto.
static func azar(x: int, y: int, semilla: int = 0) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (semilla * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000) / 1000.0

# ------------------------------------------------------------ Interiores ----
# Lo comun de los niveles que se describen por HUECOS excavados en un macizo
# (2, 3 y 5). Antes vivia solo en generar_nivel_02.gd.

## Rellena `capa` con un macizo de ancho x alto del que se excavan `huecos`
## ([x0, y0, x1, y1) en tiles). Cada celda maciza elige su aspecto por sus
## vecinas. bloques: macizos dentro del aire; franjas: [x0, x1, fila] de suelo
## de peligro; pasarelas: [x0, x1, fila] de un solo sentido.
static func excavar(capa: TileMapLayer, ancho: int, alto: int, huecos: Array,
		bloques: Array = [], franjas: Array = [], pasarelas: Array = []) -> void:
	var macizo: Dictionary = {}
	for x: int in ancho:
		for y: int in alto:
			macizo[Vector2i(x, y)] = true
	for hueco: Array in huecos:
		for x: int in range(int(hueco[0]), int(hueco[2])):
			for y: int in range(int(hueco[1]), int(hueco[3])):
				macizo.erase(Vector2i(x, y))
	for bloque: Array in bloques:
		for x: int in range(int(bloque[0]), int(bloque[2])):
			for y: int in range(int(bloque[1]), int(bloque[3])):
				capa.set_cell(Vector2i(x, y), 0, INT_BLOQUE)
	var con_franja: Dictionary = {}
	for tramo: Array in franjas:
		for x: int in range(int(tramo[0]), int(tramo[1])):
			con_franja[Vector2i(x, int(tramo[2]))] = true
	for celda: Vector2i in macizo:
		capa.set_cell(celda, 0, _aspecto_interior(celda, macizo, con_franja, ancho, alto))
	for pasarela: Array in pasarelas:
		for x: int in range(int(pasarela[0]), int(pasarela[1])):
			capa.set_cell(Vector2i(x, int(pasarela[2])), 0, INT_PASARELA)

static func _aspecto_interior(celda: Vector2i, macizo: Dictionary, franjas: Dictionary,
		ancho: int, alto: int) -> Vector2i:
	var arriba: bool = macizo.has(celda + Vector2i.UP) or celda.y == 0
	var abajo: bool = macizo.has(celda + Vector2i.DOWN) or celda.y == alto - 1
	if not arriba:
		return INT_SUELO_FRANJAS if franjas.has(celda) else INT_SUELO
	if not abajo:
		return INT_TECHO
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			var vecina: Vector2i = celda + Vector2i(dx, dy)
			var dentro: bool = vecina.x >= 0 and vecina.x < ancho and vecina.y >= 0 and vecina.y < alto
			if dentro and not macizo.has(vecina):
				return INT_MURO_REJILLA if azar(celda.x, celda.y, 5) < 0.15 else INT_MURO
	return INT_RELLENO

## Las mismas luces que el nivel 2 pone a cada objeto de interior.
static func decoracion_interior(raiz: Node, decoracion: Array, lamparas: Array) -> Node2D:
	var nodo: Node2D = contenedor(raiz, "Decoracion")
	var ambar: Color = Color(1.0, 0.72, 0.36)
	var fosforo: Color = Color(0.42, 0.86, 0.52)
	var brasa: Color = Color(1.0, 0.55, 0.28)
	for datos: Array in decoracion:
		var pie: Vector2 = Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16)
		var nombre: String = str(datos[2])
		var volteado: bool = bool(datos[3])
		objeto(nodo, "res://art/placeholder/props/" + nombre + ".png", pie, int(datos[4]), volteado)
		match nombre:
			"ventanal":
				luz(nodo, pie + Vector2(0.0, -56.0), brasa, Vector2(1.1, 1.8), 0, 0.22, "grande")
			"rack":
				luz(nodo, pie + Vector2(6.0, -30.0), fosforo, Vector2(0.18, 0.18), 1, 0.9)
			"consola":
				luz(nodo, pie + Vector2(-2.0 if volteado else 2.0, -16.0), fosforo,
					Vector2(0.45, 0.35), 1, 0.45)
			"muro_monitores":
				luz(nodo, pie + Vector2(0.0, -36.0), fosforo, Vector2(2.4, 1.6), 0, 0.32, "grande")
	for lampara: Array in lamparas:
		var techo: Vector2 = Vector2(int(lampara[0]) * 16 + 8, int(lampara[1]) * 16)
		objeto(nodo, "res://art/placeholder/props/lampara.png", techo + Vector2(0.0, 40.0), -2)
		luz(nodo, techo + Vector2(0.0, 37.0), ambar, Vector2(0.55, 0.55), 2, 0.55)
		luz(nodo, techo + Vector2(0.0, 37.0 + 48.0), ambar, Vector2(1.4, 1.5), 2, 0.16, "cono")
	return nodo

# ------------------------------------------------------------- Contenido ----
# Tablas en tiles: [tile, fila del suelo (o del techo), ...]. Comun a 3, 4 y 5.

static func terminales(raiz: Node, tabla: Array) -> void:
	var nodo: Node2D = contenedor(raiz, "Terminales")
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		var terminal: Node = instanciar("res://systems/save_points/terminal_crt.tscn", nodo,
			"Terminal%02d" % (i + 1), Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		terminal.set("checkpoint_id", str(datos[2]))

## [tile, fila del suelo, direccion]
static func enemigos(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		var enemigo: Node = instanciar("res://actors/enemies/enemigo_patrulla.tscn", padre,
			"Enemigo%02d" % (i + 1), Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		enemigo.set("direccion_inicial", int(datos[2]))

## [tile, fila, colgada]. Colgada: la fila es la PRIMERA de aire bajo el techo.
static func torretas(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		var torreta: Node = instanciar("res://actors/enemies/torreta.tscn", padre,
			"Torreta%02d" % (i + 1), Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16))
		torreta.set("colgada", bool(datos[2]))

## [tile, fila del suelo, "venda"|"arma", cantidad|id]
static func recogibles(raiz: Node, tabla: Array) -> void:
	var nodo: Node2D = contenedor(raiz, "Recogibles")
	for datos: Array in tabla:
		var recogible: Node = instanciar("res://systems/pickups/recogible.tscn", nodo,
			"%s_%d" % [datos[2], int(datos[0])], Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		if str(datos[2]) == "arma":
			recogible.set("clase", 0)
			recogible.set("arma", load("res://systems/weapons/data/%s.tres" % datos[3]))
		else:
			recogible.set("clase", 2)
			recogible.set("cantidad", int(datos[3]))

## [tile, fila del suelo, accion]
static func pistas(raiz: Node, tabla: Array) -> void:
	var nodo: Node2D = contenedor(raiz, "Pistas")
	for datos: Array in tabla:
		var pista: Node = instanciar("res://systems/pista_contextual.tscn", nodo,
			"Pista_%s_%d" % [datos[2], int(datos[0])], Vector2(int(datos[0]) * 16, int(datos[1]) * 16))
		pista.set("accion", StringName(str(datos[2])))

## [x px del centro, y px de la cara de arriba]
static func plataformas_fragiles(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		instanciar("res://systems/peligros/plataforma_fragil.tscn", padre,
			"Fragil%02d" % (i + 1), Vector2(float(datos[0]), float(datos[1])))

## [tile, fila del suelo, filas de alto, desfase]
static func arcos(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		var arco: Node = instanciar("res://systems/peligros/arco_electrico.tscn", padre,
			"Arco%02d" % (i + 1), Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16))
		arco.set("altura", float(int(datos[2]) * 16))
		arco.set("desfase", float(datos[3]))

## [tile, fila en la que flota]. El dron se coloca en el centro de esa celda.
static func drones(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		instanciar("res://actors/enemies/dron.tscn", padre, "Dron%02d" % (i + 1),
			Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16 + 8))

## [tile, fila del techo (la primera de aire), filas hasta el suelo, desfase]
static func prensas(padre: Node2D, tabla: Array) -> void:
	for i: int in tabla.size():
		var datos: Array = tabla[i]
		var prensa: Node = instanciar("res://systems/peligros/prensa.tscn", padre,
			"Prensa%02d" % (i + 1), Vector2(int(datos[0]) * 16 + 8, int(datos[1]) * 16))
		prensa.set("recorrido", float(int(datos[2]) * 16))
		prensa.set("desfase", float(datos[3]))
