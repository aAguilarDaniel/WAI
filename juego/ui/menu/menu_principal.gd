# Menu principal. Es la escena de arranque del juego (project.godot, main_scene).
# Lo instancia el motor; el propio menu llama a CargadorEscenas para entrar al nivel.
#
# Antes el juego entraba directo al nivel: no habia menu, y pausar solo daba el
# diario. Un menu no es adorno aqui: es la primera imagen que ve alguien que
# nunca ha jugado esto, y es donde el juego dice de que va.
#
# Es DIEGETICO, como el diario (CLAUDE.md §3.3): no es una pantalla de titulo con
# botones encima de un fondo, es un monitor que arranca. El titulo se teclea, las
# opciones se encienden despues y el fondo es el mismo cielo y el mismo parallax
# del nivel, quietos, con el personaje mirando la brasa. La cita a TV Buddha
# empieza aqui: la primera cosa que ves es una pantalla.
#
# El nodo Subtitulo esta VACIO a proposito y se deja en el arbol por si algun dia
# hace falta una linea ahi. Llevaba la pregunta de CLAUDE.md §1 y se quito: esa
# pregunta se la tiene que hacer el jugador jugando, no dársela el juego escrita
# en la primera pantalla. Enunciarla la contesta.
extends Control

const RUTA_NIVEL: String = "res://levels/nivel_01/nivel_01.tscn"

## Capas del fondo: archivo, desplazamiento vertical, deriva en px/s.
## La deriva es lentisima a proposito: el menu tiene que respirar, no navegar.
const CAPAS: Array = [
	["capa_1_cielo", -46.0, 0.7],
	["capa_2_horizonte", -46.0, 1.4],
	["capa_3_torres", -46.0, 2.6],
	["capa_4_racks", -46.0, 4.4],
	["capa_5_cercano", -46.0, 6.6],
]

## El titulo se escribe letra a letra, como si lo teclease el propio monitor.
const TITULO: String = "WHO AM I"

@export var velocidad_tecleo: float = 0.14

@onready var fondo: Node2D = $Mundo/Fondo
@onready var figura: AnimatedSprite2D = $Mundo/Figura
@onready var titulo: Label = $Interfaz/Titulo
@onready var subtitulo: Label = $Interfaz/Subtitulo
@onready var opciones: VBoxContainer = $Interfaz/Opciones
@onready var jugar: Button = $Interfaz/Opciones/Jugar
@onready var continuar: Button = $Interfaz/Opciones/Continuar
@onready var salir: Button = $Interfaz/Opciones/Salir
@onready var pie: Label = $Interfaz/Pie

var _capas: Array[Sprite2D] = []
var _tiempo: float = 0.0

func _ready() -> void:
	_montar_fondo()
	titulo.text = ""
	subtitulo.modulate.a = 0.0
	opciones.modulate.a = 0.0
	pie.modulate.a = 0.0
	continuar.disabled = not Guardado.hay_partida()
	jugar.pressed.connect(_al_jugar)
	continuar.pressed.connect(_al_continuar)
	salir.pressed.connect(_al_salir)
	if figura.sprite_frames != null and figura.sprite_frames.has_animation(&"quieto"):
		figura.play(&"quieto")
	DirectorAudio.ambiente("ambiente", -16.0)
	# Atajo de desarrollo: entra al nivel sin esperar el arranque del monitor.
	#   godot --path juego -- --saltar-menu
	# Sirve para probar el nivel sin pasar por aqui veinte veces al dia, y es el
	# camino que usa la prueba de arranque para comprobar que el cambio de escena
	# funciona de verdad y no solo en teoria.
	if "--saltar-menu" in OS.get_cmdline_user_args():
		call_deferred("_al_jugar")
		return
	# El sonido de foco se conecta a mano en cada boton: focus_entered no sube
	# por el arbol, asi que un unico connect en el contenedor no oiria nada.
	for boton: Node in opciones.get_children():
		(boton as Button).focus_entered.connect(_al_mover)
		(boton as Button).mouse_entered.connect(_al_mover)
	_secuencia_de_arranque()

func _process(delta: float) -> void:
	_tiempo += delta
	for i: int in _capas.size():
		# Deriva infinita: la textura mide 768 px y el cuadro 384, asi que basta
		# con devolverla al origen cada 768 px para que no se vea el salto.
		var velocidad: float = float(CAPAS[i][2])
		_capas[i].position.x = -fmod(_tiempo * velocidad, 768.0)
	# La figura respira: sube y baja un pixel. Es lo unico vivo del cuadro.
	figura.position.y = 149.0 + (1.0 if fmod(_tiempo, 2.4) > 1.2 else 0.0)

func _montar_fondo() -> void:
	for datos: Array in CAPAS:
		var imagen: Sprite2D = Sprite2D.new()
		imagen.centered = false
		imagen.texture = load("res://art/placeholder/parallax/%s.png" % datos[0])
		imagen.position = Vector2(0.0, float(datos[1]))
		fondo.add_child(imagen)
		_capas.append(imagen)
		# Segunda copia pegada a la derecha: es lo que evita que la deriva deje
		# un hueco negro al llegar al borde de la textura.
		var copia: Sprite2D = Sprite2D.new()
		copia.centered = false
		copia.texture = imagen.texture
		copia.position = Vector2(768.0, 0.0)
		imagen.add_child(copia)

## Arranque del monitor: el titulo se teclea, luego el subtitulo, luego las
## opciones. Nada de "pulse una tecla": cuando termina ya estan ahi.
func _secuencia_de_arranque() -> void:
	var guion: Tween = create_tween()
	guion.tween_interval(0.35)
	for i: int in TITULO.length():
		guion.tween_callback(_escribir.bind(i + 1))
		guion.tween_interval(velocidad_tecleo)
	guion.tween_interval(0.3)
	guion.tween_property(subtitulo, "modulate:a", 1.0, 0.9)
	guion.tween_interval(0.15)
	guion.tween_property(opciones, "modulate:a", 1.0, 0.6)
	guion.tween_callback(jugar.grab_focus)
	guion.tween_property(pie, "modulate:a", 0.55, 0.6)

func _escribir(cuantas: int) -> void:
	titulo.text = TITULO.substr(0, cuantas)
	DirectorAudio.efecto_variado("menu_mover", -20.0, 0.25)

func _al_mover() -> void:
	DirectorAudio.efecto("menu_mover", -12.0)

# --- Opciones ---

func _al_jugar() -> void:
	DirectorAudio.efecto("menu_aceptar", -6.0)
	CargadorEscenas.continuar_partida = false
	Guardado.borrar()
	CargadorEscenas.cambiar_a(RUTA_NIVEL)

func _al_continuar() -> void:
	DirectorAudio.efecto("menu_aceptar", -6.0)
	CargadorEscenas.continuar_partida = true
	CargadorEscenas.cambiar_a(RUTA_NIVEL)

func _al_salir() -> void:
	DirectorAudio.efecto("menu_aceptar", -9.0)
	CargadorEscenas.fundir_y_salir()
