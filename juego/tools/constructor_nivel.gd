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
