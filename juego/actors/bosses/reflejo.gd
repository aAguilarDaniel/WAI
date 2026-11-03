# El Reflejo: el jefe secreto. Solo aparece si no queda un enemigo vivo en todo
# el juego (RegistroEnemigos): el ultimo monitor, en vez del final, muestra al
# protagonista... y lo que hay en la pantalla sale. Lo instancia
# tools/generar_nivel_secreto.gd y lo dirige ArenaJefe.
#
# Es la cita a TV Buddha (CLAUDE.md §3.4) llevada al extremo: despues de haber
# matado a todos, lo unico que queda por matar es la propia imagen.
#
# Usa los MISMOS frames que el protagonista, tenidos de negro: si redibujan al
# protagonista, su reflejo cambia con el. Y pelea con sus mismas acciones, cada
# una con su aviso, como todo lo demas del juego:
#
#   TAJO     destello en la mano (0.4 s), golpe corto              -> rodar o apartarse
#   RUEDA    se agacha (0.35 s) y rueda hacia ti, hace dano        -> saltarlo o rodar a traves
#   DISPARO  mira roja (0.5 s), a 18 px del suelo: por encima del    -> agacharse
#            jugador agachado (14 px), por debajo de su cabeza (24)
#   SALTO    (fase 2) cae donde estabas y suelta dos ondas         -> saltar la onda
#   y a veces ESQUIVA tu golpe rodando, como harias tu.
class_name Reflejo
extends CharacterBody2D

signal desperto
signal fase_cambiada(fase: int)
signal derrotado

enum Modo { DORMIDO, DESPERTAR, ACECHO, AVISO, GOLPE, RECUPERA, TRANSICION, MUERTO }
enum Ataque { TAJO, RUEDA, DISPARO, SALTO }

@export_group("Arena")
@export var limite_izq: float = 0.0
@export var limite_der: float = 384.0

@export_group("Ritmo")
@export var velocidad: Array[float] = [72.0, 100.0]
@export var espera_acecho: Array[float] = [0.8, 0.5]
@export var umbral_fase_2: float = 0.5
## Probabilidad de esquivar rodando un golpe que llega, por fase.
@export var prob_esquiva: Array[float] = [0.3, 0.5]
@export var enfriamiento_esquiva: float = 2.2
@export var duracion_despertar: float = 3.6
@export var duracion_despertar_corta: float = 1.0

@export_group("Escenas")
@export var escena_disparo: PackedScene = preload("res://systems/weapons/proyectil_enemigo.tscn")
@export var escena_onda: PackedScene = preload("res://actors/bosses/onda_choque.tscn")

@onready var salud: ComponenteSalud = $Salud
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var ojos: Sprite2D = $Ojos
@onready var destello: Sprite2D = $Destello
@onready var hurtbox: Area2D = $Hurtbox
@onready var contacto: ComponenteHitbox = $HitboxContacto
@onready var tajo: ComponenteHitbox = $HitboxTajo
@onready var mira: Line2D = $Mira

## Negro, con un pelo de azul para que no sea un agujero en la imagen.
const TINTE: Color = Color(0.07, 0.07, 0.11, 1.0)

const TIEMPOS: Dictionary = {
	Ataque.TAJO: [0.42, 0.14, 0.5],
	Ataque.RUEDA: [0.38, 0.5, 0.55],
	Ataque.DISPARO: [0.55, 0.3, 0.6],
	Ataque.SALTO: [0.45, 0.7, 0.6],
}

var fase: int = 1
var _modo: Modo = Modo.DORMIDO
var _ataque: Ataque = Ataque.TAJO
var _ultimo: Ataque = Ataque.TAJO
var _reloj: float = 0.0
var _mira: int = -1
var _origen: Vector2 = Vector2.ZERO
var _jugador: Jugador = null
var _esquiva_lista: float = 0.0
var _esquivando: float = 0.0
var _estela: float = 0.0
var _veces_despertado: int = 0

func _ready() -> void:
	_origen = global_position
	salud.salud_cambiada.connect(_al_cambiar_salud)
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.murio.connect(_al_morir)
	_preparar_dormido()

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	velocity.y = minf(velocity.y + 900.0 * delta, 320.0)
	_reloj -= delta
	_esquiva_lista -= delta
	if _esquivando > 0.0:
		_esquivando -= delta
		velocity.x = -_mira * 150.0
		if _esquivando <= 0.0:
			salud.fijar_invulnerable(false)
			sprite.play(&"quieto")
	else:
		match _modo:
			Modo.DESPERTAR:
				if _reloj <= 0.0:
					_cambiar(Modo.ACECHO)
					desperto.emit()
			Modo.ACECHO:
				_acechar()
				_intentar_esquivar()
			Modo.AVISO:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
				if _ataque == Ataque.DISPARO:
					mira.default_color.a = 0.3 + 0.5 * float(int(_reloj * 16.0) % 2)
				if _reloj <= 0.0:
					_cambiar(Modo.GOLPE)
			Modo.GOLPE:
				_golpe_en_curso()
				if _reloj <= 0.0:
					_cambiar(Modo.RECUPERA)
			Modo.RECUPERA, Modo.TRANSICION:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
				if _reloj <= 0.0:
					_cambiar(Modo.ACECHO)
			_:
				velocity.x = 0.0
	var en_aire: bool = not is_on_floor()
	move_and_slide()
	if en_aire and is_on_floor() and _modo == Modo.GOLPE and _ataque == Ataque.SALTO:
		_aterrizar()
	global_position.x = clampf(global_position.x, limite_izq + 10.0, limite_der - 10.0)
	_dejar_estela(delta)

# ------------------------------------------------------------ API arena ----

func despertar() -> void:
	if _modo != Modo.DORMIDO:
		return
	_veces_despertado += 1
	_cambiar(Modo.DESPERTAR)
	_reloj = duracion_despertar if _veces_despertado == 1 else duracion_despertar_corta
	var guion: Tween = create_tween()
	# Sale de la pantalla: aparece donde estaba su imagen y se hace solido.
	guion.tween_property(sprite, "modulate:a", 1.0, _reloj * 0.6)
	guion.parallel().tween_property(ojos, "modulate:a", 1.0, _reloj * 0.6)
	guion.tween_callback(func() -> void:
		Impacto.sacudir(3.0, 0.6)
		DirectorAudio.efecto("rugido", -4.0, 1.6)
		sprite.play(&"quieto"))

func reiniciar() -> void:
	for onda: Node in get_tree().get_nodes_in_group("onda_choque"):
		onda.queue_free()
	global_position = _origen
	velocity = Vector2.ZERO
	salud.revivir()
	salud.fijar_invulnerable(false)
	_esquivando = 0.0
	fase = 1
	_preparar_dormido()

func esta_dormido() -> bool:
	return _modo == Modo.DORMIDO

# ---------------------------------------------------------------- modos ----

func _preparar_dormido() -> void:
	_modo = Modo.DORMIDO
	# Dormido es solo una imagen: una figura sentada, medio transparente, delante
	# de la pantalla. Como el protagonista en cada CRT.
	sprite.modulate = Color(TINTE.lightened(0.25), 0.4)
	ojos.modulate.a = 0.0
	sprite.play(&"sentado")
	sprite.rotation = 0.0
	_orientar(-1)
	_apagar()

func _apagar() -> void:
	tajo.desactivar()
	contacto.monitoring = false
	mira.visible = false
	destello.visible = false

func _cambiar(nuevo: Modo) -> void:
	_modo = nuevo
	_apagar()
	var tiempos: Array = TIEMPOS[_ataque]
	match nuevo:
		Modo.ACECHO:
			_reloj = espera_acecho[fase - 1]
		Modo.AVISO:
			_reloj = float(tiempos[0])
			_entrar_aviso()
		Modo.GOLPE:
			_reloj = float(tiempos[1])
			_entrar_golpe()
		Modo.RECUPERA:
			_reloj = float(tiempos[2])
			sprite.play(&"quieto")
		Modo.TRANSICION:
			_reloj = 1.4
			sprite.play(&"herido")

func _acechar() -> void:
	if _jugador == null:
		return
	var hacia: float = _jugador.global_position.x - global_position.x
	_orientar(1 if hacia > 0.0 else -1)
	# Mantiene una distancia media: ni encima ni lejos. Como lo haria el jugador.
	var distancia: float = absf(hacia)
	if distancia > 70.0:
		velocity.x = _mira * velocidad[fase - 1]
		sprite.play(&"correr" if fase == 2 else &"caminar")
	elif distancia < 30.0:
		velocity.x = -_mira * velocidad[fase - 1] * 0.6
		sprite.play(&"caminar")
	else:
		velocity.x = 0.0
		sprite.play(&"quieto")
	if _reloj <= 0.0 and is_on_floor():
		_ataque = _elegir(distancia)
		_ultimo = _ataque
		_cambiar(Modo.AVISO)

func _elegir(distancia: float) -> Ataque:
	var opciones: Array[Ataque] = []
	if distancia < 44.0:
		opciones.append_array([Ataque.TAJO, Ataque.TAJO])
	opciones.append(Ataque.RUEDA)
	opciones.append(Ataque.DISPARO)
	if fase == 2:
		opciones.append_array([Ataque.SALTO, Ataque.DISPARO])
	var sin_repetir: Array[Ataque] = []
	for opcion: Ataque in opciones:
		if opcion != _ultimo:
			sin_repetir.append(opcion)
	if not sin_repetir.is_empty():
		opciones = sin_repetir
	return opciones[randi() % opciones.size()]

## Si el jugador esta atacando de cerca, a veces rueda hacia atras. Es lo que
## haria el jugador; con enfriamiento para que no sea intocable.
func _intentar_esquivar() -> void:
	if _jugador == null or _esquiva_lista > 0.0 or not is_on_floor():
		return
	if _jugador.maquina.nombre_actual() != "Atacar":
		return
	if absf(_jugador.global_position.x - global_position.x) > 34.0:
		return
	_esquiva_lista = enfriamiento_esquiva
	if randf() >= prob_esquiva[fase - 1]:
		return
	_esquivando = 0.3
	salud.fijar_invulnerable(true)
	sprite.play(&"rodar")
	DirectorAudio.efecto_variado("salto", -10.0, 0.2)

# --------------------------------------------------------------- avisos ----

func _entrar_aviso() -> void:
	velocity.x = 0.0
	match _ataque:
		Ataque.TAJO:
			sprite.play(&"atacar")
			sprite.pause()
			destello.visible = true
			destello.position = Vector2(_mira * 10.0, -14.0)
			DirectorAudio.efecto_variado("aviso_arco", -10.0, 0.2)
		Ataque.RUEDA, Ataque.SALTO:
			sprite.play(&"agachado")
			destello.visible = true
			destello.position = Vector2(0.0, -10.0)
		Ataque.DISPARO:
			sprite.play(&"atacar")
			sprite.pause()
			mira.visible = true
			mira.points = PackedVector2Array([Vector2(_mira * 8.0, -18.0),
				Vector2(_mira * 400.0, -18.0)])
			DirectorAudio.efecto_variado("aviso_arco", -12.0, 0.1)

func _entrar_golpe() -> void:
	match _ataque:
		Ataque.TAJO:
			sprite.play(&"atacar")
			tajo.position.x = 16.0 * _mira
			tajo.activar()
			velocity.x = 60.0 * _mira
			DirectorAudio.efecto_variado("golpe", -4.0, 0.15)
		Ataque.RUEDA:
			sprite.play(&"rodar")
			contacto.monitoring = true
			DirectorAudio.efecto_variado("salto", -8.0, 0.2)
		Ataque.DISPARO:
			_disparar()
		Ataque.SALTO:
			sprite.play(&"saltar")
			var hacia: float = (_jugador.global_position.x - global_position.x) if _jugador != null else 0.0
			velocity = Vector2(clampf(hacia / 0.7, -160.0, 160.0), -300.0)
			_reloj = 1.5

func _golpe_en_curso() -> void:
	if _ataque == Ataque.RUEDA:
		velocity.x = _mira * 170.0

func _disparar() -> void:
	# Sin ternario: `[a] if x else [b]` devuelve un Array sin tipo y asignarlo a
	# Array[float] falla en tiempo de ejecucion. El reflejo no disparaba nunca.
	var angulos: Array[float] = [0.0]
	if fase == 2:
		angulos = [-0.12, 0.0, 0.12]
	for angulo: float in angulos:
		var bala: Proyectil = escena_disparo.instantiate() as Proyectil
		var nivel: Node = get_tree().get_first_node_in_group("nivel")
		(nivel if nivel != null else get_parent()).add_child(bala)
		bala.global_position = global_position + Vector2(_mira * 10.0, -18.0)
		bala.configurar(Vector2(_mira, 0.0).rotated(angulo * _mira), 150.0, 1, 2.5, self)
	DirectorAudio.efecto_variado("disparo_torreta", -6.0, 0.1)

func _aterrizar() -> void:
	_reloj = 0.0
	sprite.play(&"quieto")
	Impacto.sacudir(3.0, 0.25)
	DirectorAudio.efecto("pisoton", -8.0, 1.4)
	for lado: int in [-1, 1]:
		var onda: OndaChoque = escena_onda.instantiate() as OndaChoque
		var nivel: Node = get_tree().get_first_node_in_group("nivel")
		(nivel if nivel != null else get_parent()).add_child(onda)
		onda.global_position = global_position + Vector2(lado * 12.0, 0.0)
		onda.lanzar(lado, 140.0, limite_izq, limite_der, 1)

# ------------------------------------------------------------ dano/fases ----

func _al_cambiar_salud(actual: int, maxima: int) -> void:
	if fase == 1 and actual > 0 and float(actual) / float(maxima) <= umbral_fase_2:
		fase = 2
		_cambiar(Modo.TRANSICION)
		salud.fijar_invulnerable(true)
		fase_cambiada.emit(fase)
		Impacto.muerte(0.6)
		DirectorAudio.efecto("rugido", -2.0, 1.4)
		# En la fase 2 los ojos pasan a rojo: ya no imita, ataca.
		var cambio: Tween = create_tween()
		cambio.tween_property(ojos, "modulate", Color(1.0, 0.3, 0.25, 1.0), 0.6)
		cambio.tween_interval(0.8)
		cambio.tween_callback(func() -> void: salud.fijar_invulnerable(false))

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	sprite.modulate = Color(0.9, 0.9, 1.0)
	var vuelta: Tween = create_tween()
	vuelta.tween_property(sprite, "modulate", TINTE, 0.15)
	velocity.x = signf(direccion.x) * 60.0
	Efectos.chispas(self, global_position + Vector2(0.0, -12.0), direccion, Color(0.6, 0.7, 1.0))
	Impacto.golpe(0.4)
	DirectorAudio.efecto_variado("dano", -6.0, 0.15)

func _al_morir(_fuente: Node) -> void:
	_modo = Modo.MUERTO
	_apagar()
	_esquivando = 0.0
	hurtbox.set_deferred("monitorable", false)
	EstadoJuego.sumar("enemigos_eliminados")
	Impacto.muerte(1.0)
	# No explota: se sienta. Como el protagonista en cada CRT. Y se apaga.
	var final: Tween = create_tween()
	for i: int in 6:
		final.tween_callback(func() -> void:
			sprite.modulate = Color(0.85, 0.9, 1.0) if i % 2 == 0 else TINTE
			DirectorAudio.efecto_variado("menu_mover", -10.0, 0.4))
		final.tween_interval(0.12)
	final.tween_callback(func() -> void:
		sprite.modulate = TINTE
		sprite.play(&"sentado"))
	final.tween_interval(1.2)
	final.tween_property(ojos, "modulate:a", 0.0, 0.8)
	final.tween_property(sprite, "modulate:a", 0.0, 1.6)
	final.tween_callback(derrotado.emit)

# ------------------------------------------------------------- utilidad ----

func _orientar(lado: int) -> void:
	_mira = lado
	sprite.flip_h = lado < 0
	ojos.position.x = 2.0 * lado

## En la fase 2 deja copias que se desvanecen: se mueve mas rapido de lo que
## la imagen alcanza a seguir.
func _dejar_estela(delta: float) -> void:
	if fase < 2 or _modo == Modo.MUERTO or _modo == Modo.DORMIDO:
		return
	_estela -= delta
	if _estela > 0.0 or absf(velocity.x) < 40.0:
		return
	_estela = 0.07
	var copia: Sprite2D = Sprite2D.new()
	copia.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	copia.flip_h = sprite.flip_h
	copia.modulate = Color(0.3, 0.35, 0.6, 0.45)
	copia.global_position = sprite.global_position
	var nivel: Node = get_tree().get_first_node_in_group("nivel")
	(nivel if nivel != null else get_parent()).add_child(copia)
	var desvanecer: Tween = copia.create_tween()
	desvanecer.tween_property(copia, "modulate:a", 0.0, 0.3)
	desvanecer.tween_callback(copia.queue_free)
