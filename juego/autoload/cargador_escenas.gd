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

var _velo: ColorRect = null
var _cambiando: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
