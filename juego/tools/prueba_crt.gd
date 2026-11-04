# Herramienta: entra andando en un CRT, se sienta con E y comprueba que la imagen
# encaja en el hueco del monitor. Deja la foto en capturas/crt.png.
#
#   godot --path juego res://tools/prueba_crt.tscn
#
# NO con --headless: sin renderizador no hay imagen. Respalda user://partida.json.
extends Node

const NIVEL_1: String = "res://levels/nivel_01/nivel_01.tscn"
const RESPALDO: String = "user://partida.respaldo_prueba_crt.json"
## El hueco de la pantalla en crt_cuerpo.png, relativo a la terminal.
const HUECO: Rect2 = Rect2(-12.0, -26.0, 24.0, 17.0)

var _fallos: int = 0

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	if Guardado.hay_partida():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(Guardado.RUTA_PARTIDA),
			ProjectSettings.globalize_path(RESPALDO))
	_correr.call_deferred()

func _correr() -> void:
	var nivel: Node = (load(NIVEL_1) as PackedScene).instantiate()
	get_tree().root.add_child(nivel)
	await _esperar(0.2)
	for hijo: Node in nivel.get_children():
		if hijo is AperturaSadak:
			(hijo as AperturaSadak).cancelar()
	var jugador: Jugador = nivel.get_node("Jugador") as Jugador
	var terminal: TerminalCRT = nivel.get_node("Terminales/Terminal01") as TerminalCRT
	jugador.global_position = terminal.global_position + Vector2(-60.0, -1.0)
	Input.action_press("mover_der")
	while jugador.global_position.x < terminal.global_position.x - 20.0:
		await get_tree().physics_frame
	Input.action_release("mover_der")
	await _esperar(0.2)
	await _pulsar_interactuar()
	await _esperar(2.0)
	_comprobar("E sienta al jugador en el CRT", terminal.activa)

	var pantalla: Sprite2D = terminal.pantalla
	var textura: Texture2D = pantalla.texture
	_comprobar("la pantalla tiene imagen", textura != null)
	var tam: Vector2 = textura.get_size() * pantalla.scale if textura != null else Vector2.ZERO
	var rect: Rect2 = Rect2(pantalla.position, tam)
	_comprobar("la imagen encaja justo en el hueco del monitor (%s)" % rect, rect.is_equal_approx(HUECO))
	var cuerpo: Sprite2D = terminal.get_node("Cuerpo") as Sprite2D
	_comprobar("la carcasa contiene la imagen", cuerpo.get_rect().size.x >= rect.size.x
		and rect.position.y + rect.size.y <= 0.0)
	var cuerpo_jugador: float = jugador.global_position.x + 6.0
	_comprobar("la imagen no tapa al jugador sentado",
		cuerpo_jugador <= terminal.global_position.x + rect.position.x)

	# El personaje cabe en el encuadre: la camara va centrada en su torso.
	var camara: Camera2D = terminal.camara_circuito
	var medio_alto: float = float(terminal.circuito.size.y) / camara.zoom.y * 0.5
	_comprobar("el encuadre del circuito abarca al personaje entero (%.1f px de 12)" % medio_alto,
		medio_alto >= 12.0)
	terminal.circuito.get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://../capturas/crt_circuito.png"))

	# Lo que se VE en la pantalla: fondo claro de fosforo y una figura oscura encima.
	await RenderingServer.frame_post_draw
	var cuadro: Image = get_viewport().get_texture().get_image()
	var origen: Vector2 = get_viewport().get_canvas_transform() * pantalla.global_position
	var escala: float = terminal.camara_escena.zoom.x
	var claros: int = 0
	var oscuros: int = 0
	var total: int = 0
	for dx: int in int(24.0 * escala):
		for dy: int in int(17.0 * escala):
			var v: float = cuadro.get_pixel(int(origen.x) + dx, int(origen.y) + dy).v
			total += 1
			if v > 0.22:
				claros += 1
			elif v < 0.14:
				oscuros += 1
	print("   en pantalla: %d claros, %d oscuros de %d px" % [claros, oscuros, total])
	_comprobar("la pantalla brilla (no es negra)", claros > total / 4)
	_comprobar("y se recorta una figura oscura", oscuros > total / 20)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://../capturas/crt.png"))

	await _pulsar_interactuar()
	await _esperar(0.3)
	_comprobar("E lo levanta", not terminal.activa)
	var x_antes: float = jugador.global_position.x
	Input.action_press("mover_izq")
	await _esperar(0.3)
	Input.action_release("mover_izq")
	_comprobar("y vuelve a moverse", jugador.global_position.x < x_antes - 5.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://../capturas/crt_apagado.png"))

	Guardado.borrar()
	if FileAccess.file_exists(RESPALDO):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(RESPALDO),
			ProjectSettings.globalize_path(Guardado.RUTA_PARTIDA))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO))
	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

func _pulsar_interactuar() -> void:
	for pulsada: bool in [true, false]:
		var evento: InputEventAction = InputEventAction.new()
		evento.action = "interactuar"
		evento.pressed = pulsada
		Input.parse_input_event(evento)
		await get_tree().process_frame

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout

func _comprobar(texto: String, ok: bool) -> void:
	print("%s  %s" % ["PASA " if ok else "FALLA", texto])
	if not ok:
		_fallos += 1
