# Cambios de escena con fundido. Autoload global "CargadorEscenas".
# No guarda progreso: eso es responsabilidad de Guardado.
#
# El fundido va en una CanvasLayer propia por encima de todo (layer 100), asi que
# tapa tambien al diario (layer 10) y al post-proceso (layer 5). Se crea una sola
# vez y se reutiliza: instanciarlo en cada cambio dejaba un frame en blanco.
extends Node

signal transicion_iniciada(ruta_destino: String)
signal transicion_terminada(ruta_destino: String)

## Segundos de cada mitad del fundido.
const DURACION: float = 0.45

## Si al entrar en el nivel hay que aplicar la partida guardada. Lo pone en true
## el menu principal al pulsar Continuar y lo consume levels/nivel.gd.
var continuar_partida: bool = false

## Lo que el jugador llevaba encima al cruzar una PuertaNivel (salud, vendas,
## armas). Lo deja ir_a_nivel() y lo consume levels/nivel.gd al entrar.
var datos_en_transito: Dictionary = {}

var _velo: ColorRect = null
var _cambiando: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_encajar_ventana()
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "Fundido"
	capa.layer = 100
	add_child(capa)
	_velo = ColorRect.new()
	_velo.name = "Velo"
	_velo.color = Color(0.02, 0.015, 0.025, 1.0)
	_velo.anchor_right = 1.0
	_velo.anchor_bottom = 1.0
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.modulate.a = 0.0
	_velo.visible = false
	capa.add_child(_velo)

## project.godot pide 1920x1080 (x5). En una pantalla mas pequena esa ventana se
## sale por los bordes: se baja al mayor multiplo entero que quepa, para que los
## pixeles sigan siendo cuadrados. Si cabe, no toca nada.
func _encajar_ventana() -> void:
	var ventana: Window = get_window()
	if DisplayServer.get_name() == "headless" or ventana.mode != Window.MODE_WINDOWED:
		return
	var pantalla: Rect2i = DisplayServer.screen_get_usable_rect(ventana.current_screen)
	if pantalla.size.x >= ventana.size.x and pantalla.size.y >= ventana.size.y:
		return
	var base: Vector2i = ventana.content_scale_size
	var escala: int = maxi(1, mini(pantalla.size.x / base.x, pantalla.size.y / base.y))
	ventana.size = base * escala
	ventana.position = pantalla.position + (pantalla.size - ventana.size) / 2

## Funde a negro, cambia de escena y vuelve. Ignora llamadas mientras hay una
## transicion en curso: dos cambios encadenados dejaban la escena a medias.
func cambiar_a(ruta: String) -> void:
	if _cambiando:
		return
	_cambiando = true
	transicion_iniciada.emit(ruta)
	await _fundir(1.0)
	# Se despausa antes de cambiar: si se sale al menu desde el diario, la escena
	# nueva naceria pausada y no responderia a nada.
	get_tree().paused = false
	Engine.time_scale = 1.0
	var error: int = get_tree().change_scene_to_file(ruta)
	if error != OK:
		push_error("CargadorEscenas: no se pudo cargar %s (error %d)" % [ruta, error])
	# Un frame para que la escena nueva construya su arbol antes de destapar.
	await get_tree().process_frame
	await _fundir(0.0)
	_cambiando = false
	transicion_terminada.emit(ruta)

## Cambia al nivel siguiente llevando lo que el jugador tenia encima. Lo llama
## PuertaNivel; el nivel de destino lo aplica en su _ready().
func ir_a_nivel(ruta: String, datos_jugador: Dictionary) -> void:
	if _cambiando:
		return
	datos_en_transito = datos_jugador.duplicate(true)
	continuar_partida = false
	cambiar_a(ruta)

## Funde a negro y cierra el juego.
func fundir_y_salir() -> void:
	await _fundir(1.0)
	get_tree().quit()

func _fundir(destino: float) -> void:
	_velo.visible = true
	var animacion: Tween = create_tween()
	animacion.tween_property(_velo, "modulate:a", destino, DURACION)
	await animacion.finished
	_velo.visible = destino > 0.01
