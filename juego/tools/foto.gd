# Herramienta: saca fotos de un nivel en varias columnas de tiles, sin jugarlo.
# Sirve para revisar el arte de cualquier tramo sin tener que llegar andando.
#
#   godot --path juego res://tools/foto.tscn -- --nivel=res://levels/nivel_02/nivel_02.tscn --tiles=10,40,80
#   opcionales: --fila=N (si no, el jugador se posa en el suelo de esa columna)
#               --salida=ruta/carpeta  (por defecto ../capturas)
#               --prefijo=n2
#
# NO usar --headless: sin renderizador no hay imagen que guardar.
extends Node

const ESPERA_POR_FOTO: float = 1.4

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	var args: Dictionary = _leer_argumentos()
	var ruta_nivel: String = str(args.get("nivel", "res://levels/nivel_01/nivel_01.tscn"))
	var salida: String = str(args.get("salida", ProjectSettings.globalize_path("res://../capturas")))
	var prefijo: String = str(args.get("prefijo", "foto"))
	var fila: int = int(args.get("fila", -1))
	var tiles: PackedStringArray = str(args.get("tiles", "5")).split(",")

	var nivel: Node = (load(ruta_nivel) as PackedScene).instantiate()
	# La apertura se quita ANTES de entrar al arbol: en su _ready() ya cambia el
	# zoom y el encuadre de la camara, y quitarla despues deja el plano torcido.
	for nombre: String in ["AperturaSadak", "Entrada"]:
		var apertura: Node = nivel.get_node_or_null(nombre)
		if apertura != null:
			nivel.remove_child(apertura)
			apertura.free()
	add_child(nivel)
	await get_tree().process_frame
	var jugador: Jugador = nivel.get_node_or_null("Jugador") as Jugador
	if jugador == null:
		# Una pantalla sin jugador (menu, fin de la demo): una sola foto.
		await get_tree().create_timer(5.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(salida.path_join(prefijo + ".png"))
		get_tree().quit()
		return
	jugador.fijar_control(true)
	# Los enemigos no deben matar al jugador mientras posa.
	jugador.salud.fijar_invulnerable(true)

	for texto: String in tiles:
		var tile: int = int(texto)
		var y: float = float(fila) * 16.0 if fila >= 0 else _suelo_de(nivel, tile)
		jugador.global_position = Vector2(tile * 16 + 8, y - 1.0)
		jugador.velocity = Vector2.ZERO
		await get_tree().create_timer(ESPERA_POR_FOTO).timeout
		await RenderingServer.frame_post_draw
		var archivo: String = salida.path_join("%s_%03d.png" % [prefijo, tile])
		get_viewport().get_texture().get_image().save_png(archivo)
		print("foto: ", archivo)
	get_tree().quit()

## La superficie mas baja de la columna con dos celdas de aire encima. Basta para
## posar al jugador en el suelo sin calcular el perfil del nivel.
func _suelo_de(nivel: Node, tile: int) -> float:
	var terreno: TileMapLayer = nivel.get_node_or_null("Terreno") as TileMapLayer
	if terreno == null:
		return 0.0
	var rejilla: Rect2i = terreno.get_used_rect()
	for y: int in range(rejilla.end.y - 1, rejilla.position.y - 1, -1):
		var aqui: bool = terreno.get_cell_source_id(Vector2i(tile, y)) != -1
		var arriba: bool = terreno.get_cell_source_id(Vector2i(tile, y - 1)) != -1
		var arriba2: bool = terreno.get_cell_source_id(Vector2i(tile, y - 2)) != -1
		if aqui and not arriba and not arriba2:
			return float(y) * 16.0
	return float(rejilla.position.y) * 16.0

func _leer_argumentos() -> Dictionary:
	var resultado: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var partes: PackedStringArray = arg.substr(2).split("=", true, 1)
			resultado[partes[0]] = partes[1]
	return resultado
