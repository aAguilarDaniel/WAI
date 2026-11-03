# Objeto del mundo que se recoge al pasar por encima o al interactuar.
# Sirve para armas, para el diario y para las vendas: lo que entrega lo decide
# el inspector, no el código.
class_name Recogible
extends Area2D

enum Clase { ARMA, DIARIO, VENDA }

signal recogido(quien: Jugador)

@export var clase: Clase = Clase.ARMA
## Solo para clase ARMA.
@export var arma: ArmaData
## Solo para clase VENDA: cuántas entrega.
@export var cantidad: int = 1
## Si es false, hay que pulsar "interactuar" estando encima.
@export var automatico: bool = true
## Entrada que se escribe en el diario al recogerlo.
@export var titulo_entrada: String = ""
@export_multiline var texto_entrada: String = ""

@export_group("Aspecto")
## Una textura por clase. Se asigna en el inspector de recogible.tscn y todas las
## instancias del nivel la heredan.
@export var textura_arma: Texture2D
@export var textura_diario: Texture2D
@export var textura_venda: Texture2D

@onready var sprite: Sprite2D = $Sprite

var _jugador_encima: Jugador = null

func _ready() -> void:
	# Al retomar una partida el nivel se carga entero otra vez: sin esto las
	# vendas ya usadas volvian a estar en el suelo (vendas infinitas) y el
	# cuaderno repetia su entrada en el diario.
	if EstadoJuego.bandera(_clave()):
		queue_free()
		return
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_aplicar_textura()

## Sin esto los tres tipos de recogible se ven igual y no hay forma de saber qué
## hay en el suelo. Si la textura falta, deja la que traiga la escena.
func _aplicar_textura() -> void:
	var textura: Texture2D = null
	match clase:
		Clase.ARMA:
			textura = textura_arma
		Clase.DIARIO:
			textura = textura_diario
		Clase.VENDA:
			textura = textura_venda
	if textura != null:
		sprite.texture = textura

func _unhandled_input(evento: InputEvent) -> void:
	if automatico or _jugador_encima == null:
		return
	if evento.is_action_pressed("interactuar"):
		_entregar(_jugador_encima)

func _al_entrar(cuerpo: Node2D) -> void:
	var jugador: Jugador = cuerpo as Jugador
	if jugador == null:
		return
	_jugador_encima = jugador
	if automatico:
		_entregar(jugador)

func _al_salir(cuerpo: Node2D) -> void:
	if cuerpo == _jugador_encima:
		_jugador_encima = null

func _entregar(jugador: Jugador) -> void:
	match clase:
		Clase.ARMA:
			jugador.arma.obtener(arma)
			EstadoJuego.registrar_arma(arma)
		Clase.DIARIO:
			EstadoJuego.fijar_bandera(EstadoJuego.BANDERA_DIARIO, true)
		Clase.VENDA:
			jugador.recoger_venda(cantidad)
	if not titulo_entrada.is_empty():
		EstadoJuego.agregar_entrada(titulo_entrada, texto_entrada, "mundo")
	EstadoJuego.fijar_bandera(_clave(), true)
	DirectorAudio.efecto("recoger", -7.0)
	recogido.emit(jugador)
	queue_free()

func _clave() -> String:
	var nivel: String = owner.scene_file_path if owner != null else ""
	return EstadoJuego.clave_recogido(nivel, name)
