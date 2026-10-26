# Fabrica de efectos de un solo uso: chispas, polvo y restos.
# La usan enemigo_patrulla.gd, jugador.gd y los estados de salto y aterrizaje.
#
# Es una clase de funciones estaticas, no un autoload: no guarda estado, no hay
# nada que inicializar y asi no ocupa un hueco en la lista de autoloads.
#
# Cada efecto se cuelga del NIVEL y no de quien lo pide: colgado de un enemigo
# que acaba de morir se liberaria en el mismo frame y no se veria. Es el mismo
# error que tenian los proyectiles (CLAUDE.md §7).
class_name Efectos
extends RefCounted

const CHISPAS: PackedScene = preload("res://systems/efectos/chispas.tscn")
const POLVO: PackedScene = preload("res://systems/efectos/polvo.tscn")
const RESTOS: PackedScene = preload("res://systems/efectos/restos.tscn")

## Impacto de un golpe. La direccion inclina el chorro de chispas hacia donde
## viajaba el golpe, que es lo que hace legible de quien a quien fue.
static func chispas(origen: Node, posicion: Vector2, direccion: Vector2 = Vector2.RIGHT,
		color: Color = Color(1.0, 0.72, 0.33)) -> void:
	var nodo: CPUParticles2D = _soltar(CHISPAS, origen, posicion) as CPUParticles2D
	if nodo == null:
		return
	nodo.direction = direccion.normalized()
	nodo.color = color
	nodo.emitting = true

## Polvo de aterrizaje, de salto o de derrape. Sale hacia arriba y a los lados.
static func polvo(origen: Node, posicion: Vector2, cantidad: float = 1.0) -> void:
	var nodo: CPUParticles2D = _soltar(POLVO, origen, posicion) as CPUParticles2D
	if nodo == null:
		return
	nodo.amount = maxi(2, int(nodo.amount * clampf(cantidad, 0.2, 2.0)))
	nodo.emitting = true

## Lo que queda de una maquina rota: chatarra oscura que cae y un fogonazo verde
## de tubo reventado. Es el remate que le faltaba al combate.
static func restos(origen: Node, posicion: Vector2) -> void:
	var nodo: CPUParticles2D = _soltar(RESTOS, origen, posicion) as CPUParticles2D
	if nodo != null:
		nodo.emitting = true
	chispas(origen, posicion, Vector2.UP, Color(0.42, 0.86, 0.52))

## Busca el nivel al que colgar el efecto. Si no hay ninguno cae en la escena
## actual: un efecto nunca debe reventar la partida por no encontrar padre.
static func _soltar(escena: PackedScene, origen: Node, posicion: Vector2) -> Node2D:
	if origen == null or not origen.is_inside_tree():
		return null
	var padre: Node = origen.get_tree().get_first_node_in_group("nivel")
	if padre == null:
		padre = origen.get_tree().current_scene
	if padre == null:
		return null
	var nodo: Node2D = escena.instantiate() as Node2D
	padre.add_child(nodo)
	nodo.global_position = posicion
	return nodo
