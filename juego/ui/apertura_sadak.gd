# Apertura del juego: el Plano 1, la composicion de "Sadak in Search of the Waters
# of Oblivion" de John Martin (ARTE.md §2).
#
# Arranca como plano fijo no jugable durante unos segundos, con el titulo, y
# despues devuelve el control SIN CORTE: el jugador descubre que ya estaba jugando.
# Nada de "presione cualquier tecla".
#
# Truco para que no haya corte: no se cambia de camara. Se usa la del jugador con
# el zoom y el desplazamiento de la apertura, y se animan hasta los valores
# normales mientras se devuelve el control.
class_name AperturaSadak
extends CanvasLayer

signal control_devuelto

## Si se deja vacio, se busca el nodo del grupo "jugador".
@export var jugador: Jugador

@export_group("Tiempos")
## Segundos de plano fijo antes de devolver el control.
@export var duracion_plano: float = 4.0
## Cuanto tarda la camara en volver a su encuadre normal.
@export var duracion_retorno: float = 3.5
@export var aparicion_titulo: float = 1.5

@export_group("Encuadre de apertura")
## Zoom inicial. Mas bajo = se ve mas mundo, la figura se ve diminuta.
@export var zoom_apertura: Vector2 = Vector2(0.65, 0.65)
## Desplazamiento inicial de la camara: deja al personaje en el cuadrante inferior
## y abre cielo arriba, como en el cuadro.
@export var desplazamiento_apertura: Vector2 = Vector2(40.0, -70.0)

@onready var titulo: Label = $Titulo

var _camara: Camera2D = null
var _guion: Tween = null
var _zoom_normal: Vector2 = Vector2.ONE
var _desplazamiento_normal: Vector2 = Vector2.ZERO
var _propiedad: String = "offset"

func _ready() -> void:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador == null:
		push_warning("AperturaSadak: no hay jugador. La apertura se salta.")
		queue_free()
		return
	_camara = jugador.get_node_or_null("Camara") as Camera2D
	titulo.modulate.a = 0.0
	_comenzar()

func _comenzar() -> void:
	jugador.fijar_control(false)
	_zoom_normal = _camara.zoom if _camara != null else Vector2.ONE
	# offset_base y no offset: CamaraJugador escribe offset cada frame para la
	# sacudida, asi que un tween sobre offset se veria pisado en el acto.
	_propiedad = "offset_base" if _camara is CamaraJugador else "offset"
	if _camara != null:
		_desplazamiento_normal = _camara.get(_propiedad)
		_camara.zoom = zoom_apertura
		_camara.set(_propiedad, desplazamiento_apertura)

	_guion = create_tween()
	_guion.tween_property(titulo, "modulate:a", 1.0, aparicion_titulo)
	_guion.tween_interval(duracion_plano - aparicion_titulo)
	# El control vuelve AQUI, mientras la camara todavia se esta moviendo: por eso
	# no hay corte y el jugador no sabe en que momento empezo a jugar.
	_guion.tween_callback(_devolver_control)
	_guion.set_parallel(true)
	_guion.tween_property(titulo, "modulate:a", 0.0, duracion_retorno * 0.6)
	if _camara != null:
		_guion.tween_property(_camara, "zoom", _zoom_normal, duracion_retorno) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# La MISMA propiedad que se movio arriba. Antes aqui se animaba "offset",
		# que CamaraJugador pisa cada frame: offset_base se quedaba en el encuadre
		# de la apertura y la camara iba 70 px desplazada el nivel entero, con el
		# personaje pegado al borde de abajo.
		_guion.tween_property(_camara, _propiedad, _desplazamiento_normal, duracion_retorno) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _devolver_control() -> void:
	jugador.fijar_control(true)
	control_devuelto.emit()

## Corta la apertura en seco y deja la camara como estaba. La usa Nivel al
## retomar una partida: para entonces _ready() ya habia alejado la camara, y
## borrar el nodo sin mas la dejaba con el zoom de la apertura para siempre.
func cancelar() -> void:
	if _guion != null and _guion.is_valid():
		_guion.kill()
	if _camara != null:
		_camara.zoom = _zoom_normal
		_camara.set(_propiedad, _desplazamiento_normal)
	if jugador != null:
		jugador.fijar_control(true)
	queue_free()
