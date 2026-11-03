# Torreta: un monitor atornillado al suelo o al techo que dispara. Enemigo del
# nivel 3 en adelante. Lo instancian tools/generar_nivel_03.gd y _04.gd.
#
# Habla el mismo idioma que el enemigo de patrulla y el arco: AVISO, GOLPE,
# VENTANA. Al verte apunta (la pantalla se pone roja y una linea fina marca la
# trayectoria), FIJA la direccion un instante antes de disparar -por eso se
# esquiva moviendose o rodando en el ultimo momento- y luego recarga.
# Es el ensayo del jefe: aprender a leer un disparo antes de que llegue.
class_name Torreta
extends Node2D

enum Modo { REPOSO, APUNTAR, RECARGA }

## Distancia a la que te detecta, en px.
@export var alcance: float = 170.0
## Segundos apuntando antes de disparar. Es la telegrafia: nunca bajar de ~0.5.
@export var tiempo_apuntar: float = 0.8
## Los ultimos segundos del apuntado la direccion ya no te sigue. Es lo que
## hace que moverse o rodar en el momento justo sirva de algo.
@export var tiempo_fijado: float = 0.25
@export var tiempo_recarga: float = 1.5
@export var velocidad_proyectil: float = 120.0
@export var vida_proyectil: float = 2.4
@export var dano: int = 1
## Colgada del techo: se voltea y dispara hacia abajo.
@export var colgada: bool = false
@export var escena_proyectil: PackedScene = preload("res://systems/weapons/proyectil_enemigo.tscn")

@onready var salud: ComponenteSalud = $Salud
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var mira: Line2D = $Mira
@onready var brillo: Sprite2D = $Brillo
@onready var hurtbox: Area2D = $Hurtbox

var _modo: Modo = Modo.REPOSO
var _reloj: float = 0.0
var _direccion: Vector2 = Vector2.LEFT
var _jugador: Jugador = null

func _ready() -> void:
	if RegistroEnemigos.esta_eliminado(self):
		queue_free()
		return
	add_to_group("enemigos")
	if colgada:
		sprite.flip_v = true
		sprite.position.y = -sprite.position.y
		hurtbox.position.y = -hurtbox.position.y
		brillo.position.y = -brillo.position.y
	mira.visible = false
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.invulnerabilidad_terminada.connect(func() -> void: sprite.modulate = Color.WHITE)
	salud.murio.connect(_al_morir)
	_cambiar(Modo.REPOSO)

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	_reloj -= delta
	match _modo:
		Modo.REPOSO:
			if _ve_al_jugador():
				_cambiar(Modo.APUNTAR)
		Modo.APUNTAR:
			if _reloj > tiempo_fijado and _jugador != null:
				_direccion = (_pecho_jugador() - _boca()).normalized()
			mira.points = PackedVector2Array([_boca() - global_position,
				_boca() - global_position + _direccion * alcance])
			# La linea parpadea mas rapido cuanto menos falta: se lee la cuenta atras.
			mira.default_color.a = 0.25 + 0.55 * float(int(_reloj * (30.0 if _reloj < tiempo_fijado else 10.0)) % 2)
			if _reloj <= 0.0:
				_disparar()
				_cambiar(Modo.RECARGA)
		Modo.RECARGA:
			if _reloj <= 0.0:
				_cambiar(Modo.APUNTAR if _ve_al_jugador() else Modo.REPOSO)

func _cambiar(nuevo: Modo) -> void:
	_modo = nuevo
	match nuevo:
		Modo.REPOSO:
			mira.visible = false
			sprite.play(&"reposo")
			brillo.modulate = Color(0.42, 0.95, 0.55, 0.15)
		Modo.APUNTAR:
			_reloj = tiempo_apuntar
			mira.visible = true
			sprite.play(&"apuntar")
			brillo.modulate = Color(1.0, 0.4, 0.32, 0.8)
			DirectorAudio.efecto_variado("aviso_arco", -14.0, 0.2)
		Modo.RECARGA:
			_reloj = tiempo_recarga
			mira.visible = false
			sprite.play(&"reposo")
			brillo.modulate = Color(0.42, 0.95, 0.55, 0.15)

## Lo ve si esta cerca y no hay pared en medio.
func _ve_al_jugador() -> bool:
	if _jugador == null or not _jugador.salud.esta_vivo():
		return false
	var hasta: Vector2 = _pecho_jugador()
	if _boca().distance_to(hasta) > alcance:
		return false
	var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		_boca(), hasta, 1)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func _boca() -> Vector2:
	return global_position + Vector2(0.0, 10.0 if colgada else -10.0)

func _pecho_jugador() -> Vector2:
	return _jugador.global_position + Vector2(0.0, -12.0)

func _disparar() -> void:
	var proyectil: Proyectil = escena_proyectil.instantiate() as Proyectil
	var nivel: Node = get_tree().get_first_node_in_group("nivel")
	(nivel if nivel != null else get_parent()).add_child(proyectil)
	proyectil.global_position = _boca() + _direccion * 6.0
	proyectil.configurar(_direccion, velocidad_proyectil, dano, vida_proyectil, self)
	Efectos.chispas(self, _boca(), _direccion, Color(1.0, 0.45, 0.35))
	DirectorAudio.efecto_variado("disparo_torreta", -8.0, 0.1)

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	sprite.modulate = Color(2.4, 1.6, 1.6)
	Efectos.chispas(self, global_position + Vector2(0.0, 8.0 if colgada else -8.0), direccion)
	Impacto.golpe(0.4)
	DirectorAudio.efecto_variado("golpe", -6.0)

func _al_morir(_fuente: Node) -> void:
	EstadoJuego.sumar("enemigos_eliminados")
	RegistroEnemigos.marcar(self)
	set_physics_process(false)
	mira.visible = false
	hurtbox.set_deferred("monitorable", false)
	Efectos.restos(self, global_position + Vector2(0.0, 8.0 if colgada else -8.0))
	Impacto.muerte(0.6)
	DirectorAudio.efecto_variado("rotura", -5.0)
	sprite.stop()
	var final: Tween = create_tween()
	final.tween_property(sprite, "modulate", Color(0.4, 0.36, 0.4), 0.15)
	final.parallel().tween_property(brillo, "modulate:a", 0.0, 0.3)
	final.tween_interval(0.6)
	final.tween_property(sprite, "modulate:a", 0.0, 0.5)
	final.tween_callback(queue_free)
