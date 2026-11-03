# Área que hace daño. Se activa y desactiva desde fuera: el estado de ataque la
# enciende en los frames en que el golpe es real. Para el daño por contacto de un
# enemigo, se deja siempre activa con activa_al_inicio.
class_name ComponenteHitbox
extends Area2D

## Se emite solo cuando el golpe entró de verdad (el objetivo no era invulnerable).
signal golpeo(objetivo: ComponenteHurtbox)
## Se emite si este golpe fue el que lo mató. De aquí sale el peso del eje del alma,
## pero la hitbox no sabe que Alma existe: solo informa.
signal mato(objetivo: ComponenteHurtbox)

@export var dano: int = 1
@export var activa_al_inicio: bool = false
## A quién se le atribuye el golpe. En el Hito 3 será el arma equipada.
## Si se deja vacío, se atribuye al dueño de la escena.
@export var fuente: Node
## Vuelve a intentar el golpe cada frame contra lo que siga tocando. Para el
## dano por contacto: area_entered solo salta al ENTRAR, asi que un jugador que
## se quedaba dentro del enemigo (tras rodar a traves, por ejemplo) dejaba de
## recibir dano en cuanto acababan sus i-frames. Los i-frames de ComponenteSalud
## siguen siendo los que marcan el ritmo.
@export var dano_continuo: bool = false

## Busca la ComponenteHitbox que cuelga de la misma entidad que 'nodo'.
## La usa ComponenteArma cuando no se le asignó la hitbox a mano.
static func buscar_en_hermanos(nodo: Node) -> ComponenteHitbox:
	var padre: Node = nodo.get_parent()
	if padre == null:
		return null
	for hijo: Node in padre.get_children():
		if hijo is ComponenteHitbox:
			return hijo
	return null

func _ready() -> void:
	monitoring = activa_al_inicio
	monitorable = false
	area_entered.connect(_al_tocar_area)

func _physics_process(_delta: float) -> void:
	if not dano_continuo or not monitoring:
		return
	for area: Area2D in get_overlapping_areas():
		_al_tocar_area(area)

func activar() -> void:
	monitoring = true

func desactivar() -> void:
	monitoring = false

func _al_tocar_area(area: Area2D) -> void:
	var objetivo: ComponenteHurtbox = area as ComponenteHurtbox
	if objetivo == null:
		return
	var direccion: Vector2 = (objetivo.global_position - global_position).normalized()
	if direccion == Vector2.ZERO:
		direccion = Vector2.RIGHT
	var atribuido: Node = fuente if fuente != null else owner
	if not objetivo.recibir(dano, direccion, atribuido):
		return
	golpeo.emit(objetivo)
	if objetivo.salud != null and not objetivo.salud.esta_vivo():
		mato.emit(objetivo)
