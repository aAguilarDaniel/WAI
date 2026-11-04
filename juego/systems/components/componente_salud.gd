# Puntos de vida, invulnerabilidad temporal y muerte. Se enchufa a cualquier
# entidad (jugador, enemigo, jefe) por composición: no hereda de nada compartido.
class_name ComponenteSalud
extends Node

signal salud_cambiada(actual: int, maxima: int)
## direccion apunta del atacante hacia la víctima: sirve para el retroceso.
signal recibio_dano(cantidad: int, direccion: Vector2)
## fuente es quien dio el golpe mortal. En el Hito 3, de aquí sale el peso_hum del arma.
signal murio(fuente: Node)
signal invulnerabilidad_terminada

@export var salud_maxima: int = 6
## Segundos de gracia tras un golpe. Durante ellos no se puede volver a recibir daño.
@export var duracion_invulnerabilidad: float = 0.8

var salud_actual: int = 0

var _invulnerable_restante: float = 0.0
var _invulnerable_externo: bool = false

## Busca el ComponenteSalud que cuelga de la misma entidad que 'nodo'.
## Lo usan hurtbox y HUD cuando no se les asignó la referencia a mano.
static func buscar_en_hermanos(nodo: Node) -> ComponenteSalud:
	var padre: Node = nodo.get_parent()
	if padre == null:
		return null
	for hijo: Node in padre.get_children():
		if hijo is ComponenteSalud:
			return hijo
	return null

func _ready() -> void:
	salud_actual = salud_maxima
	salud_cambiada.emit(salud_actual, salud_maxima)

func _process(delta: float) -> void:
	if _invulnerable_restante <= 0.0:
		return
	_invulnerable_restante -= delta
	if _invulnerable_restante <= 0.0:
		invulnerabilidad_terminada.emit()

## True solo durante la gracia tras un golpe, sin contar la del rodar.
func en_gracia_por_golpe() -> bool:
	return _invulnerable_restante > 0.0

func es_invulnerable() -> bool:
	return _invulnerable_restante > 0.0 or _invulnerable_externo

## Invulnerabilidad controlada desde fuera, independiente de los i-frames por golpe.
## La usa la esquiva del rodar; más adelante también la escena de la TerminalCRT.
func fijar_invulnerable(activo: bool) -> void:
	_invulnerable_externo = activo

func esta_vivo() -> bool:
	return salud_actual > 0

## Devuelve true solo si el golpe entró de verdad. La hitbox lo usa para no
## reproducir efectos cuando el objetivo era invulnerable.
func aplicar_dano(cantidad: int, direccion: Vector2, fuente: Node) -> bool:
	if not esta_vivo() or es_invulnerable() or cantidad <= 0:
		return false
	salud_actual = maxi(0, salud_actual - cantidad)
	salud_cambiada.emit(salud_actual, salud_maxima)
	if salud_actual == 0:
		murio.emit(fuente)
	else:
		_invulnerable_restante = duracion_invulnerabilidad
		recibio_dano.emit(cantidad, direccion)
	return true

## Golpe que ignora la invulnerabilidad: los pinchos duelen aunque se caiga
## rodando o recien golpeado. Si no, caer con i-frames saldria gratis.
func herir_ignorando_gracia(cantidad: int, direccion: Vector2, fuente: Node) -> void:
	_invulnerable_restante = 0.0
	_invulnerable_externo = false
	aplicar_dano(cantidad, direccion, fuente)

## Muerte que ignora la invulnerabilidad. La usa la ZonaMortal: caerse al vacio
## mata aunque estes en i-frames o esquivando.
func matar(fuente: Node) -> void:
	if not esta_vivo():
		return
	_invulnerable_restante = 0.0
	_invulnerable_externo = false
	salud_actual = 0
	salud_cambiada.emit(salud_actual, salud_maxima)
	murio.emit(fuente)

func curar(cantidad: int) -> void:
	if not esta_vivo() or cantidad <= 0:
		return
	salud_actual = mini(salud_maxima, salud_actual + cantidad)
	salud_cambiada.emit(salud_actual, salud_maxima)

## Restaura la vida al máximo. La usa la reaparición.
func revivir() -> void:
	salud_actual = salud_maxima
	_invulnerable_restante = 0.0
	salud_cambiada.emit(salud_actual, salud_maxima)
