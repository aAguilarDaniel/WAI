# Sensacion de golpe: congelacion de imagen y sacudida de camara. Autoload "Impacto".
#
# Existe porque el golpe no se sentia: la hitbox restaba salud, el enemigo se
# tenia de rojo y ya. En un juego de accion lo que vende el impacto no es el
# numero de dano, son los tres o cuatro frames en que el mundo se para.
#
# No conoce a nadie: emite señales y quien quiera se suscribe. La camara del
# jugador escucha sacudida_pedida; la congelacion la aplica este nodo sobre
# Engine.time_scale, que es global por definicion.
extends Node

## Alguien pide sacudir la camara. La escucha actors/player/camara_jugador.gd.
signal sacudida_pedida(intensidad: float, duracion: float)

## Segundos de congelacion de un golpe normal. Por encima de ~0.08 s deja de
## leerse como impacto y empieza a leerse como que el juego va a tirones.
const CONGELACION_GOLPE: float = 0.045
const CONGELACION_MUERTE: float = 0.10

var _congelacion_restante: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _process(_delta: float) -> void:
	# delta ya viene escalado por time_scale, asi que se descuenta tiempo real.
	_congelacion_restante -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	if _congelacion_restante <= 0.0:
		Engine.time_scale = 1.0
		set_process(false)

## Un golpe conectado: congela unos frames y sacude la camara.
## fuerza va de 0.0 a 1.0; por encima se acota.
func golpe(fuerza: float = 0.5, congelar: bool = true) -> void:
	var f: float = clampf(fuerza, 0.0, 1.0)
	sacudida_pedida.emit(1.4 + f * 3.6, 0.10 + f * 0.14)
	if congelar:
		_congelar(CONGELACION_GOLPE * (0.6 + f * 0.8))

## Una muerte: se para mas y sacude mas. Es el unico remate que tiene el combate.
func muerte(fuerza: float = 1.0) -> void:
	var f: float = clampf(fuerza, 0.0, 1.0)
	sacudida_pedida.emit(3.0 + f * 3.0, 0.20 + f * 0.16)
	_congelar(CONGELACION_MUERTE * (0.7 + f * 0.6))

## Solo sacudida, sin congelar: aterrizajes, el CRT, sustos de fondo.
func sacudir(intensidad: float, duracion: float) -> void:
	sacudida_pedida.emit(intensidad, duracion)

func _congelar(segundos: float) -> void:
	# Nunca se acumula: un golpe durante una congelacion la alarga, no la suma.
	_congelacion_restante = maxf(_congelacion_restante, segundos)
	Engine.time_scale = 0.04
	set_process(true)
