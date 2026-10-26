# Camara del jugador. Anade sacudida y adelanto sobre la Camera2D normal.
# Se suscribe a Impacto.sacudida_pedida. La usa actors/player/jugador.tscn.
#
# El encuadre propio va en offset_base y NO en offset: la sacudida escribe offset
# cada frame, asi que quien anime offset a mano (la AperturaSadak lo hacia) veria
# su tween pisado. Quien quiera mover el encuadre mueve offset_base.
class_name CamaraJugador
extends Camera2D

## Cuanto se adelanta la camara hacia donde mira el personaje, en pixeles. Es lo
## que hace que veas llegar lo que viene en vez de descubrirlo encima.
@export var adelanto: float = 26.0
## Segundos que tarda el adelanto en completarse. Lento a proposito: si siguiera
## al personaje de inmediato, el cuadro daria un tiron en cada cambio de sentido.
@export var suavizado_adelanto: float = 0.9
## Cuanto baja la camara al caer rapido, para que se vea donde vas a aterrizar.
@export var adelanto_caida: float = 18.0
@export var velocidad_caida_referencia: float = 300.0

## Encuadre propio, sin la sacudida. Muevan esto, no offset.
var offset_base: Vector2 = Vector2.ZERO

var _sacudida: float = 0.0
var _sacudida_duracion: float = 0.0
var _intensidad: float = 0.0
var _adelanto_actual: Vector2 = Vector2.ZERO
var _jugador: Jugador = null
var _semilla: float = 0.0

func _ready() -> void:
	offset_base = offset
	_jugador = get_parent() as Jugador
	Impacto.sacudida_pedida.connect(_al_pedir_sacudida)

func _process(delta: float) -> void:
	_actualizar_adelanto(delta)
	var sacudida: Vector2 = Vector2.ZERO
	if _sacudida > 0.0:
		_sacudida = maxf(0.0, _sacudida - delta / maxf(_sacudida_duracion, 0.001))
		_semilla += delta * 47.0
		# Ruido barato a proposito: dos senos desfasados dan una vibracion que no
		# se lee como patron y no cuesta una textura de ruido.
		var caida: float = _sacudida * _sacudida
		sacudida = Vector2(
			sin(_semilla * 3.1) * cos(_semilla * 1.7),
			sin(_semilla * 2.3 + 1.1)) * _intensidad * caida
	# Redondeo a pixel entero: con la camara a medio pixel, el snap del proyecto
	# hace vibrar el tilemap entero (project.godot, snap_2d_transforms).
	offset = (offset_base + _adelanto_actual + sacudida).round()

func _actualizar_adelanto(delta: float) -> void:
	if _jugador == null:
		return
	var objetivo: Vector2 = Vector2(float(_jugador.mira) * adelanto, 0.0)
	if _jugador.velocity.y > velocidad_caida_referencia * 0.5:
		objetivo.y = adelanto_caida * minf(
			_jugador.velocity.y / velocidad_caida_referencia, 1.0)
	var peso: float = 1.0 - exp(-delta / maxf(suavizado_adelanto, 0.001))
	_adelanto_actual = _adelanto_actual.lerp(objetivo, peso)

func _al_pedir_sacudida(intensidad: float, duracion: float) -> void:
	# Un golpe durante otra sacudida se queda con la mas fuerte, no las suma: si
	# no, tres golpes seguidos mandan la camara fuera del nivel.
	if intensidad < _intensidad * _sacudida:
		return
	_intensidad = intensidad
	_sacudida = 1.0
	_sacudida_duracion = duracion
