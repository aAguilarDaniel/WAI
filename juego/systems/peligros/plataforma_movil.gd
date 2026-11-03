# Montacargas: plataforma que va y vuelve entre dos puntos, con pausa en cada
# extremo. Lo instancia tools/generar_nivel_02.gd (el pozo y la galeria).
#
# Se mueve en _physics_process y no con un Tween: un AnimatableBody2D tiene que
# moverse al ritmo de la fisica o el jugador que va encima resbala un frame por
# cada paso. La colision es de un solo sentido: se puede subir saltando desde
# abajo, que es lo que uno espera de una plataforma de rejilla.
class_name PlataformaMovil
extends AnimatableBody2D

## Desplazamiento desde la posicion inicial hasta el otro extremo, en px.
@export var recorrido: Vector2 = Vector2(0.0, -112.0)
## Segundos de un extremo al otro.
@export var duracion: float = 2.6
## Segundos parada en cada extremo. Es el tiempo para subirse.
@export var pausa: float = 1.0
## Adelanto en el ciclo, en segundos.
@export var desfase: float = 0.0
## Largo de los cables que la sostienen. 0 = sin cables.
@export var largo_cable: float = 420.0

@onready var cable_izq: Line2D = $CableIzq
@onready var cable_der: Line2D = $CableDer

var _origen: Vector2 = Vector2.ZERO
var _tiempo: float = 0.0

func _ready() -> void:
	_origen = position
	_tiempo = desfase
	sync_to_physics = true
	for cable: Line2D in [cable_izq, cable_der]:
		cable.visible = largo_cable > 0.0
		cable.points = PackedVector2Array([Vector2(cable.points[0].x, 0.0),
			Vector2(cable.points[0].x, -largo_cable)])

func _physics_process(delta: float) -> void:
	_tiempo += delta
	position = _origen + recorrido * _avance(_tiempo)

## 0 en el origen, 1 en el otro extremo, con pausa en ambos y frenada suave.
func _avance(t: float) -> float:
	var tramo: float = duracion + pausa
	var f: float = fposmod(t, tramo * 2.0)
	if f < pausa:
		return 0.0
	if f < tramo:
		return smoothstep(0.0, 1.0, (f - pausa) / duracion)
	if f < tramo + pausa:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (f - tramo - pausa) / duracion)
