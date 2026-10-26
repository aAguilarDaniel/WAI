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
	var zoom_normal: Vector2 = _camara.zoom if _camara != null else Vector2.ONE
	# offset_base y no offset: CamaraJugador escribe offset cada frame para la
	# sacudida, asi que un tween sobre offset se veria pisado en el acto.
	var propiedad: String = "offset_base" if _camara is CamaraJugador else "offset"
	var desplazamiento_normal: Vector2 = Vector2.ZERO
	if _camara != null:
		desplazamiento_normal = _camara.get(propiedad)
		_camara.zoom = zoom_apertura
		_camara.set(propiedad, desplazamiento_apertura)

	var guion: Tween = create_tween()
	guion.tween_property(titulo, "modulate:a", 1.0, aparicion_titulo)
	guion.tween_interval(duracion_plano - aparicion_titulo)
	# El control vuelve AQUI, mientras la camara todavia se esta moviendo: por eso
	# no hay corte y el jugador no sabe en que momento empezo a jugar.
	guion.tween_callback(_devolver_control)
	guion.set_parallel(true)
	guion.tween_property(titulo, "modulate:a", 0.0, duracion_retorno * 0.6)
	if _camara != null:
		guion.tween_property(_camara, "zoom", zoom_normal, duracion_retorno) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		guion.tween_property(_camara, "offset", desplazamiento_normal, duracion_retorno) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _devolver_control() -> void:
	jugador.fijar_control(true)
	control_devuelto.emit()
