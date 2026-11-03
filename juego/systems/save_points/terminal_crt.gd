# Punto de guardado: un monitor CRT abandonado que devuelve la imagen del
# protagonista en circuito cerrado. Cita directa a TV Buddha de Nam June Paik
# (ARTE.md §4 y CLAUDE.md §3.4).
#
# NO es un menu con una animacion encima: es una escena de contemplacion. La
# camara se queda fija y lateral, no hay UI, no hay musica, y el jugador se va
# cuando quiere. El guardado ocurre de fondo, sin anunciarse.
#
# La duda es el punto: la imagen del CRT lleva un retardo y se corrompe a ratos,
# asi que el protagonista no puede saber si eso es un reflejo o una transmision.
class_name TerminalCRT
extends Area2D

signal escena_iniciada
signal escena_terminada

## Identificador del checkpoint en el archivo de guardado. Unico por terminal.
@export var checkpoint_id: String = "nivel_01_crt_01"

@export_group("Escena")
## Zoom de la camara del plano fijo. Mas alto = mas cerca.
@export var zoom_escena: Vector2 = Vector2(1.6, 1.6)
## Donde se sienta el jugador, relativo a la terminal.
@export var sitio_del_jugador: Vector2 = Vector2(-28.0, 0.0)
## Segundos que tarda la pantalla en encender.
@export var tiempo_encendido: float = 1.2

@export_group("Circuito cerrado")
## Frames de retardo de la imagen. 0 = en vivo. Unos pocos bastan para inquietar.
@export_range(0, 20, 1) var frames_de_retardo: int = 6
## Probabilidad por frame de que la imagen se desincronice sola.
@export_range(0.0, 0.1, 0.001) var probabilidad_glitch: float = 0.012
@export var duracion_glitch: float = 0.18

@export_group("Audio")
## Volumen del bus de musica mientras dura la escena. Casi silencio.
@export_range(0.0, 1.0, 0.05) var volumen_musica_en_escena: float = 0.0

@onready var pantalla: Sprite2D = $Pantalla
@onready var circuito: SubViewport = $Circuito
@onready var camara_circuito: Camera2D = $Circuito/CamaraCircuito
@onready var camara_escena: Camera2D = $CamaraEscena
@onready var zumbido: AudioStreamPlayer2D = $Zumbido

var activa: bool = false

var _jugador: Jugador = null
var _material: ShaderMaterial = null
var _volumen_musica_previo: float = 1.0
var _tiempo_glitch: float = 0.0
var _historial: Array[ImageTexture] = []
var _cursor_historial: int = 0
## Sin renderizador real (--headless) no se puede leer el viewport. Se detecta
## una vez y se cae a la textura en vivo, en vez de tirar un error por frame.
var _puede_capturar: bool = true

func _ready() -> void:
	_puede_capturar = DisplayServer.get_name() != "headless"
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_material = pantalla.material as ShaderMaterial
	# El SubViewport tiene que mirar el MISMO mundo 2D, no uno vacio propio.
	circuito.world_2d = get_viewport().world_2d
	# Apagado mientras nadie lo usa: renderizar un viewport de mas cuesta caro.
	circuito.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_apagar_pantalla()
	# Ademas de apagarla, se suelta la imagen. Si no, la terminal se queda con la
	# ultima foto del jugador guardada en memoria hasta que se vuelva a usar.
	pantalla.texture = null
	_historial.clear()
	_cursor_historial = 0

func _process(delta: float) -> void:
	if not activa:
		return
	_actualizar_circuito()
	_actualizar_glitch(delta)

func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("interactuar"):
		return
	if activa:
		get_viewport().set_input_as_handled()
		terminar()
	elif _jugador != null:
		get_viewport().set_input_as_handled()
		iniciar(_jugador)

# --- La escena ---

func iniciar(jugador: Jugador) -> void:
	if activa:
		return
	activa = true
	_jugador = jugador

	# Aqui reaparece si muere. Reemplaza al respaldo provisional del Hito 2.
	jugador.punto_de_reaparicion = global_position + sitio_del_jugador

	jugador.fijar_control(false)
	jugador.global_position = global_position + sitio_del_jugador
	jugador.velocity = Vector2.ZERO
	jugador.sentarse(true)

	# Plano fijo, lateral y quieto. La camara del jugador cede el paso.
	camara_escena.enabled = true
	camara_escena.make_current()

	circuito.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# La cámara del circuito nace apagada en la escena y hay que ENCENDERLA aquí.
	# Sin esto el SubViewport se renderiza sin cámara, o sea desde el origen del
	# mundo, y la pantalla mostraba el tile 0 del nivel en vez del protagonista.
	# La cita a TV Buddha depende entera de que se vea a sí mismo (ARTE.md §4):
	# sin la cámara encendida no había circuito cerrado, solo un monitor con
	# ruido verde. Está dentro del SubViewport, así que no puede robarle la
	# cámara al viewport principal.
	camara_circuito.enabled = true
	camara_circuito.make_current()
	camara_circuito.global_position = jugador.global_position + Vector2(0.0, -12.0)
	_historial.clear()
	_cursor_historial = 0

	_volumen_musica_previo = DirectorAudio.volumen("Musica")
	DirectorAudio.fijar_volumen("Musica", volumen_musica_en_escena)
	if zumbido.stream != null:
		zumbido.play()

	_encender_pantalla()
	_guardar()
	escena_iniciada.emit()

func terminar() -> void:
	if not activa:
		return
	activa = false
	circuito.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_apagar_pantalla()
	camara_circuito.enabled = false
	camara_escena.enabled = false
	DirectorAudio.fijar_volumen("Musica", _volumen_musica_previo)
	if zumbido.playing:
		zumbido.stop()
	if _jugador != null:
		_jugador.sentarse(false)
		_jugador.fijar_control(true)
		var camara: Camera2D = _jugador.get_node_or_null("Camara") as Camera2D
		if camara != null:
			camara.make_current()
	escena_terminada.emit()

# --- Circuito cerrado ---

## Mantiene el historial de imagenes y muestra una vieja. El retardo es lo que
## impide saber si la pantalla responde al jugador o va por su cuenta.
func _actualizar_circuito() -> void:
	var en_vivo: ViewportTexture = circuito.get_texture()
	if en_vivo == null:
		return
	if frames_de_retardo <= 0 or not _puede_capturar:
		pantalla.texture = en_vivo
		return
	var imagen: Image = en_vivo.get_image()
	if imagen == null or imagen.is_empty():
		return
	if _historial.size() <= frames_de_retardo:
		_historial.append(ImageTexture.create_from_image(imagen))
		pantalla.texture = _historial[0]
		return
	# Buffer circular: se reescribe la entrada mas vieja y se muestra la siguiente.
	_historial[_cursor_historial].update(imagen)
	_cursor_historial = (_cursor_historial + 1) % _historial.size()
	pantalla.texture = _historial[_cursor_historial]

## Deriva vertical ocasional. No coincide con nada que haga el jugador: por eso
## inquieta (ARTE.md §4).
func _actualizar_glitch(delta: float) -> void:
	if _material == null:
		return
	if _tiempo_glitch > 0.0:
		_tiempo_glitch -= delta
		if _tiempo_glitch <= 0.0:
			_material.set_shader_parameter("deriva", 0.0)
		return
	if randf() < probabilidad_glitch:
		_tiempo_glitch = duracion_glitch
		_material.set_shader_parameter("deriva", randf_range(-0.25, 0.25))

# --- Pantalla ---

func _encender_pantalla() -> void:
	if _material == null:
		return
	var animacion: Tween = create_tween()
	animacion.tween_method(_fijar_encendido, 0.0, 1.0, tiempo_encendido)

func _apagar_pantalla() -> void:
	_fijar_encendido(0.0)

func _fijar_encendido(valor: float) -> void:
	if _material != null:
		_material.set_shader_parameter("encendido", valor)

# --- Guardado ---

func _guardar() -> void:
	if _jugador == null:
		return
	var datos: Dictionary = _jugador.instantanea()
	# En que nivel esta la terminal: "Seguir donde estaba" tiene que abrir ESE
	# nivel, no siempre el primero.
	var nivel: Node = get_tree().get_first_node_in_group("nivel")
	if nivel != null:
		datos["nivel"] = nivel.scene_file_path
	Guardado.guardar(checkpoint_id, datos)

func _al_entrar(cuerpo: Node2D) -> void:
	var jugador: Jugador = cuerpo as Jugador
	if jugador != null:
		_jugador = jugador

func _al_salir(cuerpo: Node2D) -> void:
	if cuerpo == _jugador and not activa:
		_jugador = null
