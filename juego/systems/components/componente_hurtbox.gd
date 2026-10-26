# Área vulnerable: recibe golpes y se los pasa a su ComponenteSalud.
# No sabe quién la golpeó ni por qué. Solo traduce contacto en daño.
class_name ComponenteHurtbox
extends Area2D

## Se asigna en el inspector. Si se deja vacío, se usa el ComponenteSalud
## hermano: la convención del proyecto es que ambos cuelguen de la misma entidad.
@export var salud: ComponenteSalud

func _ready() -> void:
	# Es detectada, no detecta: por eso monitoring false y monitorable true.
	monitoring = false
	monitorable = true
	if salud == null:
		salud = ComponenteSalud.buscar_en_hermanos(self)

## La llama la hitbox que la tocó. Devuelve true si el golpe entró.
func recibir(dano: int, direccion: Vector2, fuente: Node) -> bool:
	if salud == null:
		push_error("ComponenteHurtbox en %s: falta asignar 'salud'." % get_path())
		return false
	return salud.aplicar_dano(dano, direccion, fuente)
