# Pista contextual: una tecla que aparece SOLO si el jugador se queda atascado.
# La coloca tools/generar_nivel_01.gd donde el nivel introduce una mecanica nueva.
#
# El nivel esta disenado para ensenar sin texto: un escalon que no se sube
# andando ensena a saltar, un pasillo con techo bajo y un enemigo encima ensena a
# rodar. Esto es solo la red de seguridad: si alguien lleva unos segundos dentro
# de la zona sin haber usado nunca esa accion, se le ensena la tecla y se calla.
#
# No dice los controles al empezar y no se repite: en cuanto el jugador usa la
# accion una vez, ninguna pista de esa accion vuelve a aparecer en la partida.
class_name PistaContextual
extends Area2D

## Accion del InputMap que ensena. El nombre de la tecla se lee del InputMap, no
## se escribe a mano: si cambian el mapeo, la pista cambia sola.
@export var accion: StringName = &"saltar"
## Segundos dentro de la zona sin usar la accion antes de rendirse y ensenarla.
@export var retardo: float = 4.0
## Altura sobre el nodo a la que flota la pista.
@export var altura: float = 34.0

## Acciones que el jugador ya demostro conocer. Es de clase a proposito: la pista
## del salto del tile 20 y la del tile 96 son la misma leccion.
static var aprendidas: Dictionary = {}

@onready var marca: Node2D = $Marca
@onready var etiqueta: Label = $Marca/Fondo/Tecla

var _dentro: bool = false
var _espera: float = 0.0
var _mostrando: bool = false
var _animacion: Tween = null
var _fase: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                      # solo el jugador
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	marca.position = Vector2(0.0, -altura)
	marca.modulate.a = 0.0
	marca.visible = false
	etiqueta.text = _nombre_de_la_tecla()
	set_process(false)

func _process(delta: float) -> void:
	if aprendidas.get(accion, false):
		_ocultar()
		set_process(false)
		return
	# Usar la accion en cualquier parte del nivel cuenta como aprendida.
	if Input.is_action_just_pressed(accion):
		aprendidas[accion] = true
		_ocultar()
		return
	if not _dentro:
		return
	_espera += delta
	if _espera >= retardo and not _mostrando:
		_mostrar()
	if _mostrando:
		# Flotacion lenta. Un cartel quieto sobre un fondo quieto desaparece.
		_fase += delta * 2.2
		marca.position.y = -altura + sin(_fase) * 1.5

func _al_entrar(cuerpo: Node2D) -> void:
	if cuerpo is not Jugador or aprendidas.get(accion, false):
		return
	_dentro = true
	_espera = 0.0
	set_process(true)

func _al_salir(cuerpo: Node2D) -> void:
	if cuerpo is not Jugador:
		return
	_dentro = false
	_espera = 0.0
	_ocultar()

func _mostrar() -> void:
	_mostrando = true
	marca.visible = true
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	_animacion = create_tween()
	_animacion.tween_property(marca, "modulate:a", 1.0, 0.45)

func _ocultar() -> void:
	if not _mostrando:
		return
	_mostrando = false
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	_animacion = create_tween()
	_animacion.tween_property(marca, "modulate:a", 0.0, 0.25)
	_animacion.tween_callback(func() -> void: marca.visible = false)

## Nombre corto de la tecla de la accion, leido del InputMap. Si hay un mando
## conectado se prefiere el boton, que es lo que la persona tiene en la mano.
func _nombre_de_la_tecla() -> String:
	var eventos: Array[InputEvent] = InputMap.action_get_events(accion)
	if not Input.get_connected_joypads().is_empty():
		for evento: InputEvent in eventos:
			var boton: InputEventJoypadButton = evento as InputEventJoypadButton
			if boton != null:
				return _nombre_de_boton(boton.button_index)
	for evento: InputEvent in eventos:
		var tecla: InputEventKey = evento as InputEventKey
		if tecla == null:
			continue
		var codigo: Key = tecla.keycode
		if tecla.physical_keycode != KEY_NONE:
			codigo = DisplayServer.keyboard_get_keycode_from_physical(tecla.physical_keycode)
		return _abreviar(OS.get_keycode_string(codigo))
	return "?"

## Los nombres largos no caben en la placa a 384x216. Solo estos se traducen.
func _abreviar(nombre: String) -> String:
	match nombre:
		"Space":
			return "ESPACIO"
		"Shift":
			return "SHIFT"
		"Ctrl":
			return "CTRL"
		"Tab":
			return "TAB"
		_:
			return nombre.to_upper()

func _nombre_de_boton(indice: int) -> String:
	match indice:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		_:
			return "BTN"
