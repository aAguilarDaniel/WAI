# Proyectil genérico. Lo instancia ComponenteArma con los datos del arma, así que
# el mismo nodo sirve para la pistola, el plasma y la radiación.
class_name Proyectil
extends Node2D

## Se emite si este proyectil dio el golpe mortal. La escucha el arma que lo disparó.
signal mato(objetivo: ComponenteHurtbox)

@onready var hitbox: ComponenteHitbox = $Hitbox

var _direccion: Vector2 = Vector2.RIGHT
var _velocidad: float = 220.0
var _restante: float = 1.2

## La llama ComponenteArma justo después de instanciarlo.
func configurar(direccion: Vector2, velocidad: float, dano: int, vida: float, fuente: Node) -> void:
	_direccion = direccion.normalized()
	_velocidad = velocidad
	_restante = vida
	hitbox.dano = dano
	hitbox.fuente = fuente
	# Horizontal: se voltea (los sprites miran a la derecha). Cualquier otra
	# direccion (la torreta apunta en diagonal, la chatarra del jefe cae) se rota.
	if absf(_direccion.y) < 0.01:
		scale.x = signf(_direccion.x) if _direccion.x != 0.0 else 1.0
	else:
		rotation = _direccion.angle()

func _ready() -> void:
	hitbox.mato.connect(_al_matar)
	hitbox.golpeo.connect(_al_golpear)
	# La capa 1 (mundo) está en la máscara: así el proyectil muere contra las paredes.
	hitbox.body_entered.connect(_al_tocar_mundo)

func _physics_process(delta: float) -> void:
	position += _direccion * _velocidad * delta
	_restante -= delta
	if _restante <= 0.0:
		queue_free()

func _al_golpear(_objetivo: ComponenteHurtbox) -> void:
	queue_free()

func _al_matar(objetivo: ComponenteHurtbox) -> void:
	mato.emit(objetivo)

func _al_tocar_mundo(_cuerpo: Node2D) -> void:
	queue_free()
