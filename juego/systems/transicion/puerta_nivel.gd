# Paso de un nivel al siguiente: el portal del edificio al final del nivel 1 y el
# montacargas del final del nivel 2. La instancian las herramientas de generacion.
#
# Se cruza ANDANDO, sin pulsar nada: una puerta que pide una tecla es un menu, y
# este juego no pone UI encima del mundo (ARTE.md §4). El jugador se adentra en
# la oscuridad del portal y el fundido lo lleva dentro.
#
# Lo que el jugador lleva encima (salud, vendas, armas) viaja con el en
# CargadorEscenas: el nodo Jugador se destruye con la escena. Alma y EstadoJuego
# son autoloads y no necesitan viajar.
class_name PuertaNivel
extends Area2D

signal cruzada

## Escena a la que lleva.
@export_file("*.tscn") var destino: String = ""
## Cuanto avanza el jugador hacia dentro mientras funde a negro.
@export var paso_hacia_dentro: float = 14.0

var _usada: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                      # solo el jugador
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo: Node2D) -> void:
	var jugador: Jugador = cuerpo as Jugador
	if jugador == null or _usada or destino.is_empty():
		return
	_usada = true
	jugador.fijar_control(false)
	# Se adentra y se oscurece: la puerta se lo traga en vez de cortar.
	var adentro: Tween = jugador.create_tween().set_parallel(true)
	adentro.tween_property(jugador, "global_position:x",
		jugador.global_position.x + paso_hacia_dentro * float(jugador.mira), 0.5)
	adentro.tween_property(jugador.sprite, "modulate", Color(0.15, 0.15, 0.18), 0.5)
	DirectorAudio.efecto("puerta", -6.0)
	cruzada.emit()
	CargadorEscenas.ir_a_nivel(destino, jugador.instantanea())
