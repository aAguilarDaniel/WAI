# Dron: un ojo de camara con aspas. Enemigo de los niveles 5 y 6. Lo instancian
# tools/generar_nivel_05.gd y _06.gd.
#
# La amenaza que faltaba: desde ARRIBA. Mismo idioma que el resto: flota, te ve,
# se coloca encima y APUNTA (ojo rojo, 0.6 s), FIJA el punto y cae en picado en
# linea recta. Al llegar se queda ATURDIDO (sin morder) y vuelve a su sitio. Se
# esquiva apartandose en el ultimo momento; se castiga mientras esta aturdido.
class_name Dron
extends Node2D

enum Modo { FLOTAR, APUNTAR, PICADO, ATURDIDO, REGRESO }

@export var alcance: float = 120.0
## Altura sobre el jugador a la que se coloca para apuntar.
@export var altura_acecho: float = 56.0
@export var tiempo_apuntar: float = 0.65
@export var velocidad_picado: float = 210.0
@export var velocidad_vuelo: float = 70.0
@export var aturdimiento: float = 0.9

@onready var salud: ComponenteSalud = $Salud
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var contacto: ComponenteHitbox = $HitboxContacto
@onready var hurtbox: Area2D = $Hurtbox
@onready var brillo: Sprite2D = $Brillo

var _modo: Modo = Modo.FLOTAR
var _origen: Vector2 = Vector2.ZERO
var _reloj: float = 0.0
var _objetivo: Vector2 = Vector2.ZERO
var _jugador: Jugador = null
var _fase: float = 0.0

func _ready() -> void:
	if RegistroEnemigos.esta_eliminado(self):
		queue_free()
		return
	add_to_group("enemigos")
	_origen = global_position
	_fase = fmod(absf(_origen.x) * 0.07, TAU)
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.invulnerabilidad_terminada.connect(func() -> void: sprite.modulate = Color.WHITE)
	salud.murio.connect(_al_morir)
	_cambiar(Modo.FLOTAR)

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	_reloj -= delta
	_fase += delta
	match _modo:
		Modo.FLOTAR:
			global_position = global_position.move_toward(
				_origen + Vector2(sin(_fase * 0.9) * 10.0, sin(_fase * 2.1) * 3.0), 30.0 * delta)
			if _ve_al_jugador():
				_cambiar(Modo.APUNTAR)
		Modo.APUNTAR:
			if _jugador != null:
				var encima: Vector2 = _jugador.global_position + Vector2(0.0, -altura_acecho)
				global_position = global_position.move_toward(encima, velocidad_vuelo * delta)
				# El ultimo cuarto del aviso ya no te sigue: ahi se esquiva.
				if _reloj > tiempo_apuntar * 0.25:
					_objetivo = _jugador.global_position + Vector2(0.0, -10.0)
			if _reloj <= 0.0:
				_cambiar(Modo.PICADO)
		Modo.PICADO:
			global_position = global_position.move_toward(_objetivo, velocidad_picado * delta)
			if global_position.distance_to(_objetivo) < 1.0 or _reloj <= 0.0:
				_cambiar(Modo.ATURDIDO)
		Modo.ATURDIDO:
			if _reloj <= 0.0:
				_cambiar(Modo.REGRESO)
		Modo.REGRESO:
			global_position = global_position.move_toward(_origen, velocidad_vuelo * delta)
			if global_position.distance_to(_origen) < 2.0:
				_cambiar(Modo.FLOTAR)

func _cambiar(nuevo: Modo) -> void:
	_modo = nuevo
	contacto.monitoring = nuevo == Modo.PICADO or nuevo == Modo.APUNTAR
	match nuevo:
		Modo.FLOTAR, Modo.REGRESO:
			sprite.play(&"flotar")
			brillo.modulate = Color(0.42, 0.95, 0.55, 0.25)
		Modo.APUNTAR:
			_reloj = tiempo_apuntar
			sprite.play(&"apuntar")
			brillo.modulate = Color(1.0, 0.4, 0.32, 0.85)
			DirectorAudio.efecto_variado("zumbido_dron", -10.0, 0.1)
		Modo.PICADO:
			# Tope por si el punto queda dentro de una pared.
			_reloj = 1.2
			sprite.play(&"picado")
		Modo.ATURDIDO:
			_reloj = aturdimiento
			sprite.play(&"aturdido")
			brillo.modulate = Color(0.3, 0.3, 0.3, 0.2)
			Efectos.polvo(self, global_position + Vector2(0.0, 6.0), 0.4)

func _ve_al_jugador() -> bool:
	if _jugador == null or not _jugador.salud.esta_vivo():
		return false
	var hasta: Vector2 = _jugador.global_position + Vector2(0.0, -12.0)
	if global_position.distance_to(hasta) > alcance:
		return false
	var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, hasta, 1)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	sprite.modulate = Color(2.4, 1.6, 1.6)
	global_position += direccion.normalized() * 6.0
	Efectos.chispas(self, global_position, direccion)
	Impacto.golpe(0.35)
	DirectorAudio.efecto_variado("golpe", -6.0)
	if _modo == Modo.APUNTAR:
		_cambiar(Modo.ATURDIDO)

func _al_morir(_fuente: Node) -> void:
	EstadoJuego.sumar("enemigos_eliminados")
	RegistroEnemigos.marcar(self)
	set_physics_process(false)
	contacto.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	Efectos.restos(self, global_position)
	Impacto.muerte(0.6)
	DirectorAudio.efecto_variado("rotura", -5.0)
	sprite.stop()
	var caida: Tween = create_tween()
	caida.tween_property(self, "position:y", position.y + 40.0, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	caida.parallel().tween_property(sprite, "rotation", 2.4, 0.5)
	caida.parallel().tween_property(brillo, "modulate:a", 0.0, 0.3)
	caida.tween_property(sprite, "modulate:a", 0.0, 0.4)
	caida.tween_callback(queue_free)
