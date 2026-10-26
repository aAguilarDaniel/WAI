# Máquina de estados del jugador. Guarda el estado activo y ejecuta las transiciones.
# Los estados son sus nodos hijos; se registran solos al inicializar.
class_name MaquinaEstados
extends Node

## La emite en cada transición. La escucha la etiqueta de depuración del jugador.
signal estado_cambiado(nombre_anterior: String, nombre_nuevo: String)

## Estado con el que arranca. Se elige en el inspector.
@export var estado_inicial: NodePath

var estado_actual: Estado = null

var _estados: Dictionary = {}

## La llama el jugador en su _ready(). Inyecta las dependencias en cada estado.
func inicializar(duenio: Jugador) -> void:
	for hijo: Node in get_children():
		if hijo is Estado:
			var estado: Estado = hijo
			estado.jugador = duenio
			estado.maquina = self
			_estados[hijo.name] = estado
	if estado_inicial.is_empty():
		push_error("MaquinaEstados: falta asignar estado_inicial en el inspector.")
		return
	estado_actual = get_node(estado_inicial) as Estado
	estado_actual.entrar()
	estado_cambiado.emit("", estado_actual.name)

## Cambia de estado por nombre de nodo. Ej: maquina.cambiar_a("Saltar")
func cambiar_a(nombre: String) -> void:
	if not _estados.has(nombre):
		push_error("MaquinaEstados: no existe el estado '%s'." % nombre)
		return
	var anterior: String = estado_actual.name if estado_actual != null else ""
	if estado_actual != null:
		estado_actual.salir()
	estado_actual = _estados[nombre]
	estado_actual.entrar()
	estado_cambiado.emit(anterior, estado_actual.name)

func procesar_fisica(delta: float) -> void:
	if estado_actual != null:
		estado_actual.procesar_fisica(delta)

func nombre_actual() -> String:
	return estado_actual.name if estado_actual != null else "-"
