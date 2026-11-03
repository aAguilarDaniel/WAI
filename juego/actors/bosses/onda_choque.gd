# Onda que el pisoton del Custodio manda por el suelo, una a cada lado. La
# instancia Custodio._pisotear(). Se salta: es baja (10 px) y va recta.
class_name OndaChoque
extends Node2D

@onready var hitbox: ComponenteHitbox = $Hitbox
@onready var brillo: Sprite2D = $Brillo

var _dir: int = 1
var _velocidad: float = 140.0
var _min_x: float = 0.0
var _max_x: float = 0.0

func _ready() -> void:
	add_to_group("onda_choque")

func lanzar(direccion: int, velocidad: float, min_x: float, max_x: float, dano: int) -> void:
	_dir = direccion
	_velocidad = velocidad
	_min_x = min_x
	_max_x = max_x
	hitbox.dano = maxi(1, dano)
	scale.x = float(direccion)

func _physics_process(delta: float) -> void:
	position.x += _dir * _velocidad * delta
	brillo.scale.y = 0.35 + 0.08 * sin(position.x * 0.4)
	if global_position.x < _min_x + 6.0 or global_position.x > _max_x - 6.0:
		queue_free()
