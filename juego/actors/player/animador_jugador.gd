# Reproduce la animacion que le toca al estado activo del jugador. Cuelga del
# Jugador, que lo arranca con inicializar() al final de su _ready().
class_name AnimadorJugador
extends Node

var _jugador: Jugador = null
var _sprite: AnimatedSprite2D = null

## Mientras esta sentado frente a un CRT la maquina de estados se queda en Quieto
## y no emite nada, asi que la postura hay que sostenerla desde aqui.
var _sentado: bool = false

## La llama el jugador en su _ready(). Se suscribe al cambio de estado en vez de
## preguntar el estado cada frame (CLAUDE.md 4: senales sobre sondeo).
func inicializar(duenio: Jugador) -> void:
	_jugador = duenio
	_sprite = duenio.sprite
	duenio.maquina.estado_cambiado.connect(_al_cambiar_estado)
	_reproducir(duenio.maquina.nombre_actual())

func _process(_delta: float) -> void:
	_acompasar_al_paso()

## Caminar y correr se acompasan a la velocidad real. Sin esto los pies patinan
## cada vez que acelera, frena o pierde velocidad en el aire.
func _acompasar_al_paso() -> void:
	if _sentado or _sprite == null or _jugador == null:
		return
	var anim: StringName = _sprite.animation
	if anim != &"caminar" and anim != &"correr":
		return
	var tope: float = _jugador.velocidad_correr if anim == &"correr" \
		else _jugador.velocidad_caminar
	_sprite.speed_scale = clampf(absf(_jugador.velocity.x) / maxf(tope, 1.0), 0.4, 1.6)

func _al_cambiar_estado(_anterior: String, nuevo: String) -> void:
	if _sentado:
		return
	_reproducir(nuevo)

## Postura de TV Buddha (ARTE.md 4). La usa Jugador.sentarse().
func sentar() -> void:
	if _sprite == null:
		return
	_sentado = true
	_sprite.speed_scale = 1.0
	_sprite.play(&"sentado")

## Devuelve el sprite al estado que la maquina tenga ahora mismo.
func sincronizar() -> void:
	_sentado = false
	if _jugador != null:
		_reproducir(_jugador.maquina.nombre_actual())

## El nombre de la animacion es el del nodo de estado en minusculas. Es la unica
## regla, y por eso no hay ni un caso especial: anadir un estado con su animacion
## del mismo nombre ya funciona. Si la animacion no existe, deja la que hubiera:
## un estado sin dibujar no debe dejar al personaje invisible.
func _reproducir(estado: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var nombre: StringName = StringName(estado.to_lower())
	if not _sprite.sprite_frames.has_animation(nombre):
		return
	_sprite.speed_scale = _escala(estado, nombre)
	_sprite.play(nombre)

## Cuanto hay que acelerar la animacion para que entre EXACTA en lo que dura el
## estado. Es lo que hace que la voltereta termine justo cuando el personaje
## recupera el control, y que el golpe no siga moviendose despues de acabar.
func _escala(estado: String, nombre: StringName) -> float:
	var duracion: float = _duracion_estado(estado)
	if duracion <= 0.0:
		return 1.0
	var cuadros: int = _sprite.sprite_frames.get_frame_count(nombre)
	var fps: float = _sprite.sprite_frames.get_animation_speed(nombre)
	var natural: float = float(cuadros) / maxf(fps, 0.001)
	return natural / duracion

## Segundos que dura el estado, preguntandoselos al jugador. No se copian aqui:
## si maniana cambian duracion_rodar en el inspector, la animacion se ajusta sola.
## 0.0 significa "dura lo que dure": la animacion va a su velocidad natural.
func _duracion_estado(estado: String) -> float:
	match estado:
		"Rodar":
			return _jugador.duracion_rodar
		"Atacar":
			return _jugador.duracion_total_ataque()
		"Herido":
			return _jugador.duracion_aturdimiento
	return 0.0
