# Herramienta: comprueba el cartel de controles del nivel 1 y saca una foto del
# primer cuadro jugable. La foto queda en capturas/controles.png.
#
#   godot --path juego res://tools/prueba_controles.tscn
extends Node

const NIVEL_1: String = "res://levels/nivel_01/nivel_01.tscn"

var _fallos: int = 0

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	_correr.call_deferred()

func _correr() -> void:
	var nivel: Node = (load(NIVEL_1) as PackedScene).instantiate()
	get_tree().root.add_child(nivel)
	await get_tree().create_timer(0.3).timeout
	var cartel: CartelControles = nivel.get_node_or_null("CartelControles") as CartelControles
	_comprobar("el nivel 1 tiene el cartel", cartel != null)
	if cartel == null:
		get_tree().quit(1)
		return
	var todas: bool = true
	for i: int in CartelControles.FILAS.size():
		var tecla: String = cartel.tecla_de_fila(i)
		print("   %-14s %s" % [CartelControles.FILAS[i][1], tecla])
		if tecla.is_empty() or tecla.contains("?"):
			todas = false
	_comprobar("todas las filas tienen tecla", todas)

	# Foto y encuadre en el momento en que el jugador recupera el control.
	await get_tree().create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://../capturas/controles.png"))
	var placa: Control = cartel.get_node("Placa") as Control
	var rect: Rect2 = cartel.get_global_transform_with_canvas() * placa.get_rect()
	var cuadro: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_comprobar("el cartel se ve entero al empezar a jugar (%s)" % rect, cuadro.encloses(rect))
	_comprobar("la placa esta centrada en el cartel (%.0f)" % (placa.position.x + placa.size.x * 0.5),
		absf(placa.position.x + placa.size.x * 0.5) <= 1.0)

	# Remapear en el diario cambia el cartel al despausar.
	var original: Array[InputEvent] = InputMap.action_get_events("atacar")
	InputMap.action_erase_events("atacar")
	var nueva: InputEventKey = InputEventKey.new()
	nueva.physical_keycode = KEY_L
	InputMap.action_add_event("atacar", nueva)
	get_tree().paused = true
	await get_tree().process_frame
	get_tree().paused = false
	await get_tree().process_frame
	var fila_atacar: int = 5
	_comprobar("remapear cambia el cartel (atacar -> %s)" % cartel.tecla_de_fila(fila_atacar),
		cartel.tecla_de_fila(fila_atacar) == "L")
	InputMap.action_erase_events("atacar")
	for evento: InputEvent in original:
		InputMap.action_add_event("atacar", evento)

	# El audio tiene que cargarse tambien exportado (--main-pack).
	_comprobar("hay efectos de sonido cargados (%d)" % DirectorAudio._efectos.size(),
		DirectorAudio._efectos.size() >= 20)
	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

func _comprobar(texto: String, ok: bool) -> void:
	print("%s  %s" % ["PASA " if ok else "FALLA", texto])
	if not ok:
		_fallos += 1
