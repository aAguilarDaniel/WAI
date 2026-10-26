# Enemigo basico: una maquina de mantenimiento con un monitor donde iria la cara.
# Patrulla su plataforma, te ve, se prepara y embiste. Usa los mismos componentes
# que el jugador (composicion, CLAUDE.md §4). Lo instancia el nivel.
#
# ANTES no atacaba: caminaba hacia ti y hacia dano por contacto. Eso no es un
# enemigo, es un obstaculo movil, y no se podia aprender nada de el. Ahora tiene
# el patron predecible que pide el referente de Castlevania (CLAUDE.md §7):
#
#   PATRULLA -> te ve -> ALERTA (se para, enciende la pantalla, 0.5 s)
#            -> PERSECUCION (camina hacia ti)
#            -> de cerca: ANTICIPACION (se echa atras, 0.45 s)  <- aqui se esquiva
#            -> EMBESTIDA (rapido y recto, no gira)
#            -> ATURDIDO (0.9 s parado y sin morder)             <- aqui se castiga
#
# Esas dos ventanas son el combate entero: la anticipacion te dice cuando rodar y
# el aturdimiento es cuando pegar sale gratis. Sin ellas no hay ritmo que aprender.
class_name EnemigoPatrulla
extends CharacterBody2D

enum Modo { PATRULLA, ALERTA, PERSECUCION, ANTICIPACION, EMBESTIDA, ATURDIDO }

@export_group("Movimiento")
@export var velocidad_patrulla: float = 26.0
@export var velocidad_persecucion: float = 52.0
@export var velocidad_embestida: float = 170.0
@export var gravedad: float = 900.0
## 1 arranca hacia la derecha, -1 hacia la izquierda.
@export var direccion_inicial: int = 1
## Si esta activo, gira al llegar al borde en vez de tirarse al vacio.
@export var evitar_caidas: bool = true

@export_group("Patron de ataque")
## Se para y enciende la pantalla al verte. Es el aviso de que ya te vio.
@export var tiempo_alerta: float = 0.5
## A que distancia horizontal se prepara para embestir.
@export var distancia_embestida: float = 46.0
## Cuanto dura el aviso antes de embestir. Esto es lo que se esquiva: por debajo
## de ~0.3 s deja de ser esquivable y pasa a ser injusto.
@export var anticipacion: float = 0.45
@export var duracion_embestida: float = 0.42
## Parado y vulnerable despues de embestir. Es la ventana para pegarle.
@export var aturdimiento: float = 0.9
## Segundos antes de poder preparar otra embestida.
@export var enfriamiento_embestida: float = 0.7

@export_group("Aspecto")
## Se enciende en ALERTA y late en ANTICIPACION. Refuerza con luz lo que la
## animacion ya cuenta con la pantalla: a 20 px de alto hace falta el refuerzo.
@export var color_ojo_calmado: Color = Color(0.24, 0.5, 0.32, 0.0)
@export var color_ojo_alerta: Color = Color(0.42, 0.95, 0.55, 0.85)
@export var color_ojo_furia: Color = Color(1.0, 0.4, 0.32, 0.95)

@onready var salud: ComponenteSalud = $Salud
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var detector_suelo: RayCast2D = $DetectorSuelo
@onready var detector_pared: RayCast2D = $DetectorPared
@onready var vision: Area2D = $Vision
@onready var contacto: ComponenteHitbox = $HitboxContacto
@onready var brillo: Sprite2D = $Brillo

var _dir: int = 1
var _modo: Modo = Modo.PATRULLA
var _objetivo: Node2D = null
var _reloj: float = 0.0
var _enfriamiento: float = 0.0
var _dir_embestida: int = 1
var _fase_brillo: float = 0.0

func _ready() -> void:
	add_to_group("enemigos")
	_dir = 1 if direccion_inicial >= 0 else -1
	_orientar()
	_animar()
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.invulnerabilidad_terminada.connect(_al_terminar_invulnerabilidad)
	salud.murio.connect(_al_morir)
	vision.body_entered.connect(_al_entrar_en_vision)
	vision.body_exited.connect(_al_salir_de_vision)
	brillo.modulate = color_ojo_calmado
	# Desfase por posicion: si todos los enemigos del nivel latieran a la vez se
	# leerian como un solo sistema y no como maquinas sueltas.
	_fase_brillo = fmod(absf(global_position.x) * 0.13, TAU)

func _physics_process(delta: float) -> void:
	_enfriamiento = maxf(0.0, _enfriamiento - delta)
	_reloj = maxf(0.0, _reloj - delta)
	velocity.y += gravedad * delta
	match _modo:
		Modo.PATRULLA:
			_hacer_patrulla(delta)
		Modo.ALERTA:
			_hacer_alerta(delta)
		Modo.PERSECUCION:
			_hacer_persecucion()
		Modo.ANTICIPACION:
			_hacer_anticipacion()
		Modo.EMBESTIDA:
			_hacer_embestida()
		Modo.ATURDIDO:
			_hacer_aturdido(delta)
	move_and_slide()
	_actualizar_brillo(delta)

# --- Los seis modos ---

func _hacer_patrulla(_delta: float) -> void:
	velocity.x = _dir * velocidad_patrulla
	if is_on_floor() and _debe_girar():
		_dir = -_dir
		_orientar()

func _hacer_alerta(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if _reloj <= 0.0:
		_cambiar(Modo.PERSECUCION)

func _hacer_persecucion() -> void:
	if not is_instance_valid(_objetivo):
		_cambiar(Modo.PATRULLA)
		return
	var hacia: float = _objetivo.global_position.x - global_position.x
	if absf(hacia) > 2.0:
		_dir = 1 if hacia > 0.0 else -1
		_orientar()
	velocity.x = _dir * velocidad_persecucion
	# No se tira al vacio persiguiendo: se queda al borde esperando.
	if is_on_floor() and evitar_caidas and not detector_suelo.is_colliding():
		velocity.x = 0.0
		return
	if absf(hacia) <= distancia_embestida and _enfriamiento <= 0.0:
		_cambiar(Modo.ANTICIPACION)

func _hacer_anticipacion() -> void:
	# Se echa hacia atras. El retroceso es lo que hace legible el aviso: la
	# pantalla encendida sola no se ve a 20 px de alto.
	velocity.x = -_dir * 18.0
	if _reloj <= 0.0:
		_dir_embestida = _dir
		_cambiar(Modo.EMBESTIDA)

func _hacer_embestida() -> void:
	# Recto y sin girar: una embestida que te sigue no se puede esquivar.
	velocity.x = _dir_embestida * velocidad_embestida
	if _reloj <= 0.0 or is_on_wall():
		_cambiar(Modo.ATURDIDO)

func _hacer_aturdido(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if _reloj <= 0.0:
		_enfriamiento = enfriamiento_embestida
		_cambiar(Modo.PERSECUCION if is_instance_valid(_objetivo) else Modo.PATRULLA)

func _cambiar(nuevo: Modo) -> void:
	if _modo == nuevo:
		return
	_modo = nuevo
	match nuevo:
		Modo.ALERTA:
			_reloj = tiempo_alerta
		Modo.ANTICIPACION:
			_reloj = anticipacion
		Modo.EMBESTIDA:
			_reloj = duracion_embestida
			Efectos.polvo(self, global_position, 0.8)
			DirectorAudio.efecto_variado("salto", -13.0, 0.2)
		Modo.ATURDIDO:
			_reloj = aturdimiento
	# El contacto solo muerde cuando esta en marcha. Aturdido no hace dano: si lo
	# hiciera, castigarlo seria imposible y la ventana no serviria de nada.
	contacto.monitoring = nuevo != Modo.ATURDIDO
	_animar()

# --- Percepcion ---

func _debe_girar() -> bool:
	if is_on_wall():
		return true
	return evitar_caidas and not detector_suelo.is_colliding()

func _orientar() -> void:
	sprite.flip_h = _dir < 0
	detector_suelo.position.x = _dir * 8.0
	detector_pared.target_position.x = _dir * 10.0

func _al_entrar_en_vision(cuerpo: Node2D) -> void:
	if cuerpo is not Jugador:
		return
	_objetivo = cuerpo
	if _modo == Modo.PATRULLA:
		_cambiar(Modo.ALERTA)

func _al_salir_de_vision(cuerpo: Node2D) -> void:
	if cuerpo != _objetivo:
		return
	_objetivo = null
	if _modo == Modo.PERSECUCION or _modo == Modo.ALERTA:
		_cambiar(Modo.PATRULLA)

# --- Aspecto ---

## Cambia de animacion solo al cambiar de modo, no cada frame.
func _animar() -> void:
	if sprite.sprite_frames == null:
		return
	var nombre: StringName = &"caminar"
	if _modo != Modo.PATRULLA:
		nombre = &"alerta"
	if _modo == Modo.ATURDIDO:
		nombre = &"quieto"
	if sprite.sprite_frames.has_animation(nombre):
		sprite.play(nombre)
	# Inclinacion: la unica forma de que la embestida se lea como embestida sin
	# dibujar frames nuevos. Se anima, no se salta.
	var inclinacion: float = 0.0
	if _modo == Modo.ANTICIPACION:
		inclinacion = 0.16 * float(_dir)
	elif _modo == Modo.EMBESTIDA:
		inclinacion = -0.20 * float(_dir_embestida)
	elif _modo == Modo.ATURDIDO:
		inclinacion = 0.28 * float(_dir)
	var giro: Tween = create_tween()
	giro.tween_property(sprite, "rotation", inclinacion, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _actualizar_brillo(delta: float) -> void:
	_fase_brillo += delta * (14.0 if _modo == Modo.ANTICIPACION else 2.4)
	var objetivo: Color = color_ojo_calmado
	if _modo == Modo.ALERTA or _modo == Modo.PERSECUCION:
		objetivo = color_ojo_alerta
	elif _modo == Modo.ANTICIPACION or _modo == Modo.EMBESTIDA:
		objetivo = color_ojo_furia
	var pulso: float = 0.82 + 0.18 * sin(_fase_brillo)
	objetivo.a *= pulso
	brillo.modulate = brillo.modulate.lerp(objetivo, minf(delta * 9.0, 1.0))
	brillo.scale = Vector2.ONE * (1.0 + 0.25 * objetivo.a)

# --- Dano y muerte ---

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	sprite.modulate = Color(2.4, 1.6, 1.6)
	velocity.x = signf(direccion.x) * 70.0
	velocity.y = -60.0
	Efectos.chispas(self, global_position + Vector2(0.0, -10.0), direccion)
	Impacto.golpe(0.45)
	DirectorAudio.efecto_variado("golpe", -6.0)
	# Un golpe recibido en plena preparacion la cancela: castigar la anticipacion
	# tiene que servir de algo o el patron no se puede jugar.
	if _modo == Modo.ANTICIPACION:
		_cambiar(Modo.ATURDIDO)
	elif _modo == Modo.PATRULLA:
		_cambiar(Modo.ALERTA)

func _al_terminar_invulnerabilidad() -> void:
	sprite.modulate = Color.WHITE

func _al_morir(_fuente: Node) -> void:
	# El peso del eje ya lo aplico ComponenteArma: aqui solo se lleva la cuenta.
	EstadoJuego.sumar("enemigos_eliminados")
	Efectos.restos(self, global_position + Vector2(0.0, -10.0))
	Impacto.muerte(0.8)
	DirectorAudio.efecto_variado("rotura", -5.0)
	queue_free()
