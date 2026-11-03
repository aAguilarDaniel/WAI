# El Custodio: el jefe del final de la demo (Hito 7). Lo instancia el nivel 5 y
# lo dirige ArenaJefe, que decide cuando despierta y que pasa al derrotarlo.
#
# Habla el MISMO idioma que todo lo demas del juego: AVISO, GOLPE, VENTANA. Cada
# ataque se anuncia (se echa atras con los brazos en alto, la pantalla se pone
# roja o una marca aparece en el suelo), golpea, y deja una ventana en la que no
# muerde y pegarle sale gratis. No hay barra de vida (referente: Hollow Knight):
# el dano se lee en el cuerpo, que se agrieta en cada cambio de fase.
#
#   Fase 1 (100-66 %)  ZARPAZO de cerca, PISOTON con ondas por el suelo -> saltar
#   Fase 2 (66-33 %)   + LLUVIA de chatarra en sitios marcados           -> moverse
#   Fase 3 (33-0 %)    + RAYO a la altura del pecho                      -> agacharse o rodar
#
# Composicion, no herencia (CLAUDE.md §4): usa los mismos ComponenteSalud,
# Hurtbox e Hitbox que el jugador y el enemigo de patrulla.
class_name Custodio
extends CharacterBody2D

signal desperto
signal fase_cambiada(fase: int)
signal derrotado

enum Modo { DORMIDO, DESPERTAR, ACECHO, AVISO, GOLPE, RECUPERA, TRANSICION, MUERTO }
enum Ataque { ZARPAZO, PISOTON, LLUVIA, RAYO }

@export_group("Arena")
## Bordes de la arena en coordenadas globales. Los pone ArenaJefe.
@export var limite_izq: float = 0.0
@export var limite_der: float = 480.0
## Altura (global) desde la que cae la chatarra.
@export var techo_y: float = 0.0

@export_group("Ritmo")
@export var velocidad_andar: Array[float] = [30.0, 38.0, 48.0]
## Segundos acechando antes de elegir ataque, por fase.
@export var espera_acecho: Array[float] = [1.1, 0.85, 0.65]
## Distancia por debajo de la cual prefiere el zarpazo.
@export var distancia_zarpazo: float = 72.0
## Fraccion de salud a la que pasa a la fase 2 y a la 3.
@export var umbral_fase_2: float = 0.66
@export var umbral_fase_3: float = 0.33
## Segundos de la pausa de intimidacion la primera vez. Las siguientes (tras
## morir) se acorta: repetirla entera cada intento castiga mas que la muerte.
@export var duracion_despertar: float = 3.2
@export var duracion_despertar_corta: float = 1.0

@export_group("Ataques")
@export var dano_golpe: int = 2
@export var velocidad_onda: Array[float] = [130.0, 150.0, 185.0]
@export var piezas_lluvia: Array[int] = [0, 4, 6]
@export var velocidad_chatarra: float = 210.0
## Altura del rayo sobre el suelo. Por encima de los 14 px del jugador agachado
## y por debajo de los 24 de pie: agacharse lo esquiva.
@export var altura_rayo: float = 20.0

@export_group("Escenas")
@export var escena_onda: PackedScene = preload("res://actors/bosses/onda_choque.tscn")
@export var escena_chatarra: PackedScene = preload("res://systems/weapons/proyectil_enemigo.tscn")

@onready var salud: ComponenteSalud = $Salud
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var nucleo: Sprite2D = $Nucleo
@onready var hurtbox: Area2D = $Hurtbox
@onready var contacto: ComponenteHitbox = $HitboxContacto
@onready var zarpazo: ComponenteHitbox = $HitboxZarpazo
@onready var rayo: ComponenteHitbox = $HitboxRayo
@onready var forma_rayo: CollisionShape2D = $HitboxRayo/Forma
@onready var linea_rayo: Line2D = $LineaRayo

## Duraciones [aviso, golpe, recupera] por ataque. La fase 3 recorta el aviso un
## 25 %, nunca por debajo de 0.4 s: menos que eso ya no es telegrafia.
const TIEMPOS: Dictionary = {
	Ataque.ZARPAZO: [0.62, 0.24, 0.95],
	Ataque.PISOTON: [0.75, 0.30, 0.80],
	Ataque.LLUVIA: [0.95, 0.40, 0.55],
	Ataque.RAYO: [0.95, 0.55, 1.15],
}

var fase: int = 1
var _modo: Modo = Modo.DORMIDO
var _ataque: Ataque = Ataque.ZARPAZO
var _ultimo: Array[Ataque] = []
var _reloj: float = 0.0
var _mira: int = -1
var _gravedad: float = 900.0
var _origen: Vector2 = Vector2.ZERO
var _jugador: Jugador = null
var _marcas: Array[float] = []
var _efimeros: Array[Node] = []
var _veces_despertado: int = 0

func _ready() -> void:
	_origen = global_position
	salud.salud_cambiada.connect(_al_cambiar_salud)
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.murio.connect(_al_morir)
	for golpe: ComponenteHitbox in [zarpazo, rayo]:
		golpe.dano = dano_golpe
	_preparar_dormido()

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	velocity.y += _gravedad * delta
	_reloj -= delta
	match _modo:
		Modo.DESPERTAR:
			if _reloj <= 0.0:
				_cambiar(Modo.ACECHO)
				desperto.emit()
		Modo.ACECHO:
			_acechar()
		Modo.AVISO:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_animar_aviso()
			if _reloj <= 0.0:
				_cambiar(Modo.GOLPE)
		Modo.GOLPE:
			if _ataque != Ataque.ZARPAZO:
				velocity.x = 0.0
			if _reloj <= 0.0:
				_cambiar(Modo.RECUPERA)
		Modo.RECUPERA, Modo.TRANSICION:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _reloj <= 0.0:
				_cambiar(Modo.ACECHO)
		_:
			velocity.x = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, limite_izq + 20.0, limite_der - 20.0)

# ------------------------------------------------------------ API arena ----

## La pausa de intimidacion antes de moverse (HITOS.md, Hito 7). La musica la
## arranca la arena al recibir `desperto`, no antes: el silencio es parte de ella.
func despertar() -> void:
	if _modo != Modo.DORMIDO:
		return
	_veces_despertado += 1
	_cambiar(Modo.DESPERTAR)
	_reloj = duracion_despertar if _veces_despertado == 1 else duracion_despertar_corta
	var guion: Tween = create_tween()
	guion.tween_property(sprite, "modulate", Color.WHITE, 0.6)
	guion.parallel().tween_property(nucleo, "modulate:a", 0.9, 0.6)
	guion.tween_callback(func() -> void:
		Impacto.sacudir(4.0, 0.9)
		DirectorAudio.efecto("rugido", -2.0)
		Efectos.chispas(self, global_position + Vector2(0.0, -64.0), Vector2.UP, Color(0.6, 1.0, 0.7)))

## Vuelve a dormir donde empezo, con la salud llena. La usa la arena cuando el
## jugador muere: el intento siguiente empieza limpio.
func reiniciar() -> void:
	_limpiar_efimeros()
	global_position = _origen
	velocity = Vector2.ZERO
	salud.revivir()
	salud.fijar_invulnerable(false)
	fase = 1
	_ultimo.clear()
	_preparar_dormido()

func esta_dormido() -> bool:
	return _modo == Modo.DORMIDO

# ---------------------------------------------------------------- modos ----

func _preparar_dormido() -> void:
	_modo = Modo.DORMIDO
	_mira = -1
	sprite.flip_h = true
	sprite.play(&"aturdido")
	sprite.modulate = Color(0.45, 0.42, 0.5)
	sprite.rotation = 0.0
	nucleo.modulate.a = 0.0
	_apagar_golpes()
	contacto.monitoring = false
	linea_rayo.visible = false

func _cambiar(nuevo: Modo) -> void:
	_modo = nuevo
	_apagar_golpes()
	contacto.monitoring = nuevo in [Modo.ACECHO, Modo.AVISO, Modo.GOLPE]
	var tiempos: Array = TIEMPOS[_ataque]
	match nuevo:
		Modo.DESPERTAR:
			sprite.play(&"preparar")
		Modo.ACECHO:
			_reloj = espera_acecho[fase - 1]
			sprite.play(_anim_quieto())
			sprite.rotation = 0.0
		Modo.AVISO:
			_reloj = maxf(0.4, float(tiempos[0]) * (0.75 if fase == 3 else 1.0))
			_entrar_aviso()
		Modo.GOLPE:
			_reloj = float(tiempos[1])
			_entrar_golpe()
		Modo.RECUPERA:
			_reloj = float(tiempos[2])
			sprite.play(&"aturdido")
			linea_rayo.visible = false
			nucleo.modulate = Color(1.0, 0.5, 0.4, 0.4)
		Modo.TRANSICION:
			_reloj = 1.9
			sprite.play(&"aturdido")

func _acechar() -> void:
	if _jugador == null:
		return
	var hacia: float = _jugador.global_position.x - global_position.x
	_orientar(1 if hacia > 0.0 else -1)
	if absf(hacia) > distancia_zarpazo * 0.8:
		velocity.x = _mira * velocity_andar_actual()
		if sprite.animation != &"andar":
			sprite.play(&"andar")
	else:
		velocity.x = 0.0
		if sprite.animation != _anim_quieto():
			sprite.play(_anim_quieto())
	if _reloj <= 0.0:
		_ataque = _elegir_ataque(absf(hacia))
		_ultimo.append(_ataque)
		if _ultimo.size() > 2:
			_ultimo.pop_front()
		_cambiar(Modo.AVISO)

func velocity_andar_actual() -> float:
	return velocidad_andar[fase - 1]

## De cerca, zarpazo; de lejos, lo que la fase permita. Nunca tres veces seguidas
## lo mismo: un patron que se repite se aprende en vez de leerse.
func _elegir_ataque(distancia: float) -> Ataque:
	var opciones: Array[Ataque] = []
	if distancia < distancia_zarpazo:
		opciones.append(Ataque.ZARPAZO)
		opciones.append(Ataque.ZARPAZO)
	opciones.append(Ataque.PISOTON)
	if fase >= 2:
		opciones.append(Ataque.LLUVIA)
	if fase >= 3:
		opciones.append(Ataque.RAYO)
		opciones.append(Ataque.RAYO)
	if _ultimo.size() == 2 and _ultimo[0] == _ultimo[1]:
		var repetido: Ataque = _ultimo[0]
		var sin_repetir: Array[Ataque] = []
		for opcion: Ataque in opciones:
			if opcion != repetido:
				sin_repetir.append(opcion)
		if not sin_repetir.is_empty():
			opciones = sin_repetir
	return opciones[randi() % opciones.size()]

# --------------------------------------------------------------- avisos ----

func _entrar_aviso() -> void:
	nucleo.modulate = Color(1.0, 0.35, 0.3, 0.95)
	match _ataque:
		Ataque.ZARPAZO, Ataque.PISOTON:
			sprite.play(&"preparar")
			DirectorAudio.efecto_variado("aviso_arco", -6.0, 0.1)
		Ataque.LLUVIA:
			sprite.play(&"preparar")
			_marcar_lluvia()
			DirectorAudio.efecto("rugido", -10.0, 1.3)
		Ataque.RAYO:
			sprite.play(&"rayo")
			_preparar_rayo()
			DirectorAudio.efecto("rayo_carga", -4.0)

func _animar_aviso() -> void:
	# Se echa atras: es lo que se lee a 384 px de ancho aunque no se vea la cara.
	var t: float = 1.0 - clampf(_reloj / 0.6, 0.0, 1.0)
	sprite.rotation = -0.10 * _mira * t
	if _ataque == Ataque.RAYO:
		linea_rayo.default_color.a = 0.2 + 0.5 * float(int(_reloj * 18.0) % 2)
	if _ataque == Ataque.ZARPAZO and _jugador != null:
		_orientar(1 if _jugador.global_position.x > global_position.x else -1)

# --------------------------------------------------------------- golpes ----

func _entrar_golpe() -> void:
	sprite.rotation = 0.12 * _mira
	match _ataque:
		Ataque.ZARPAZO:
			sprite.play(&"golpe")
			zarpazo.position.x = 30.0 * _mira
			zarpazo.activar()
			velocity.x = 150.0 * _mira
			Impacto.sacudir(2.0, 0.15)
			DirectorAudio.efecto_variado("golpe", -2.0, 0.1)
		Ataque.PISOTON:
			sprite.play(&"golpe")
			_pisotear()
		Ataque.LLUVIA:
			sprite.play(&"golpe")
			_soltar_chatarra()
		Ataque.RAYO:
			_disparar_rayo()

func _apagar_golpes() -> void:
	zarpazo.desactivar()
	rayo.desactivar()

func _pisotear() -> void:
	Impacto.sacudir(5.0, 0.35)
	DirectorAudio.efecto("pisoton", -2.0)
	Efectos.polvo(self, global_position, 1.6)
	var suelo: Vector2 = global_position
	for direccion: int in [-1, 1]:
		var onda: OndaChoque = escena_onda.instantiate() as OndaChoque
		_colgar_del_nivel(onda)
		onda.global_position = suelo + Vector2(direccion * 26.0, 0.0)
		onda.lanzar(direccion, velocidad_onda[fase - 1], limite_izq, limite_der, dano_golpe - 1)

func _marcar_lluvia() -> void:
	_marcas.clear()
	if _jugador == null:
		return
	var cuantas: int = piezas_lluvia[fase - 1]
	# Una cae SIEMPRE donde esta el jugador: si no, quedarse quieto seria la respuesta.
	var centro: float = _jugador.global_position.x
	_marcas.append(centro)
	var intentos: int = 0
	while _marcas.size() < cuantas and intentos < 40:
		intentos += 1
		var x: float = clampf(centro + randf_range(-130.0, 130.0), limite_izq + 12.0, limite_der - 12.0)
		var lejos: bool = true
		for otra: float in _marcas:
			if absf(otra - x) < 30.0:
				lejos = false
		if lejos:
			_marcas.append(x)
	for x: float in _marcas:
		var marca: Line2D = Line2D.new()
		marca.width = 2.0
		marca.default_color = Color(1.0, 0.35, 0.3, 0.85)
		marca.points = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0)])
		marca.z_index = 3
		_colgar_del_nivel(marca)
		marca.global_position = Vector2(x, global_position.y - 1.0)
		var parpadeo: Tween = marca.create_tween().set_loops()
		parpadeo.tween_property(marca, "modulate:a", 0.25, 0.12)
		parpadeo.tween_property(marca, "modulate:a", 1.0, 0.12)
		_efimeros.append(marca)

func _soltar_chatarra() -> void:
	Impacto.sacudir(2.5, 0.3)
	DirectorAudio.efecto_variado("derrumbe", -4.0, 0.1)
	_limpiar_efimeros()
	for x: float in _marcas:
		var pieza: Proyectil = escena_chatarra.instantiate() as Proyectil
		_colgar_del_nivel(pieza)
		pieza.global_position = Vector2(x, techo_y + 6.0)
		var caida: float = global_position.y - techo_y
		pieza.configurar(Vector2.DOWN, velocidad_chatarra, 1,
			caida / velocidad_chatarra + 0.3, self)
		pieza.scale = Vector2(1.6, 1.6)

func _preparar_rayo() -> void:
	var y: float = -altura_rayo
	var fin: float = (limite_der if _mira > 0 else limite_izq) - global_position.x
	linea_rayo.points = PackedVector2Array([Vector2(_mira * 14.0, y), Vector2(fin, y)])
	linea_rayo.width = 1.0
	linea_rayo.default_color = Color(0.7, 1.0, 0.75, 0.5)
	linea_rayo.visible = true

func _disparar_rayo() -> void:
	var y: float = -altura_rayo
	var fin: float = (limite_der if _mira > 0 else limite_izq) - global_position.x
	var caja: RectangleShape2D = RectangleShape2D.new()
	caja.size = Vector2(absf(fin), 6.0)
	forma_rayo.shape = caja
	forma_rayo.position = Vector2(fin * 0.5, y)
	rayo.activar()
	linea_rayo.width = 5.0
	linea_rayo.default_color = Color(0.85, 1.0, 0.9, 1.0)
	Impacto.sacudir(3.0, 0.5)
	DirectorAudio.efecto("rayo", -3.0)

# ------------------------------------------------------------ dano/fases ----

func _al_cambiar_salud(actual: int, maxima: int) -> void:
	if _modo == Modo.DORMIDO or _modo == Modo.MUERTO or actual <= 0:
		return
	var fraccion: float = float(actual) / float(maxima)
	var nueva: int = 1
	if fraccion <= umbral_fase_3:
		nueva = 3
	elif fraccion <= umbral_fase_2:
		nueva = 2
	if nueva > fase:
		fase = nueva
		_transicion()

## Cambio de fase: se tambalea, ruge y se agrieta. Invulnerable mientras: si no,
## la fase nueva se la saltaria un jugador con el arma de radiacion.
func _transicion() -> void:
	_limpiar_efimeros()
	_cambiar(Modo.TRANSICION)
	salud.fijar_invulnerable(true)
	fase_cambiada.emit(fase)
	Impacto.muerte(0.7)
	DirectorAudio.efecto("rugido", 0.0, 0.85)
	Efectos.restos(self, global_position + Vector2(0.0, -58.0))
	var fin: Tween = create_tween()
	fin.tween_interval(1.5)
	fin.tween_callback(func() -> void:
		salud.fijar_invulnerable(false)
		Impacto.sacudir(3.0, 0.4))

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	sprite.modulate = Color(2.0, 1.5, 1.5)
	var vuelta: Tween = create_tween()
	vuelta.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	Efectos.chispas(self, global_position + Vector2(0.0, -34.0), direccion)
	Impacto.golpe(0.35)
	DirectorAudio.efecto_variado("golpe", -5.0)

func _al_morir(_fuente: Node) -> void:
	_cambiar(Modo.MUERTO)
	_limpiar_efimeros()
	contacto.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	linea_rayo.visible = false
	sprite.play(&"aturdido")
	EstadoJuego.sumar("enemigos_eliminados")
	Impacto.muerte(1.0)
	DirectorAudio.efecto("rugido", 0.0, 0.6)
	# Se apaga por partes: el monitor primero, luego se dobla y se queda en el
	# suelo. El cuerpo se queda en la arena; es lo ultimo que se ve al salir.
	var final: Tween = create_tween()
	for i: int in 5:
		final.tween_callback(func() -> void:
			Efectos.chispas(self, global_position + Vector2(randf_range(-12, 12), randf_range(-60, -20)),
				Vector2.UP, Color(0.6, 1.0, 0.7))
			Impacto.sacudir(2.0, 0.2)
			DirectorAudio.efecto_variado("rotura", -6.0))
		final.tween_interval(0.35)
	final.tween_property(sprite, "rotation", 1.35 * -_mira, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	final.parallel().tween_property(sprite, "position:y", sprite.position.y + 16.0, 0.7)
	final.parallel().tween_property(nucleo, "modulate:a", 0.0, 0.7)
	final.tween_callback(func() -> void:
		Impacto.sacudir(6.0, 0.5)
		DirectorAudio.efecto("pisoton", 0.0, 0.8)
		Efectos.polvo(self, global_position + Vector2(-_mira * 30.0, 0.0), 2.0))
	final.tween_property(sprite, "modulate", Color(0.35, 0.32, 0.36), 1.2)
	final.tween_callback(derrotado.emit)

# ------------------------------------------------------------- utilidad ----

func _orientar(lado: int) -> void:
	_mira = lado
	# Los frames miran a la derecha.
	sprite.flip_h = lado < 0

func _anim_quieto() -> StringName:
	return [&"quieto", &"quieto_f2", &"quieto_f3"][fase - 1]

## Ondas, marcas y chatarra cuelgan del nivel: si colgaran del jefe se moverian
## con el y la onda no se separaria nunca de sus pies.
func _colgar_del_nivel(nodo: Node) -> void:
	var nivel: Node = get_tree().get_first_node_in_group("nivel")
	(nivel if nivel != null else get_parent()).add_child(nodo)

func _limpiar_efimeros() -> void:
	for nodo: Node in _efimeros:
		if is_instance_valid(nodo):
			nodo.queue_free()
	_efimeros.clear()
	for onda: Node in get_tree().get_nodes_in_group("onda_choque"):
		onda.queue_free()
