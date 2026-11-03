# El final (Hito 8): el protagonista sentado frente al ultimo monitor, como en
# cada guardado, y unas lineas escritas con SU letra. Es el destino de la puerta
# del monitor del nivel 5; al terminar lleva a ui/fin/fin_demo.tscn (creditos).
#
# Ramifica por Alma.ruta_actual() en el punto final (HITOS.md). El eje no se
# muestra: lo que cambia es lo de siempre, la letra, su color y la luz de la
# pantalla (CLAUDE.md §3.1). Y el juego sigue sin contestar la pregunta: cada
# ruta la deja mas cerca de un lado, ninguna la cierra.
#
# Los textos son BORRADORES escritos para que la demo tenga final. Son del
# equipo (CLAUDE.md §5): se cambian en el inspector de final.tscn, sin codigo.
extends Control

const RUTA_FIN: String = "res://ui/fin/fin_demo.tscn"
const FUENTES: Dictionary = {
	Alma.Ruta.HUMANO: "res://ui/diario/fuentes/wai_humana.fnt",
	Alma.Ruta.AMBIGUO: "res://ui/diario/fuentes/wai_hibrida.fnt",
	Alma.Ruta.MAQUINA: "res://ui/diario/fuentes/wai_maquina.fnt",
}
const COLORES: Dictionary = {
	Alma.Ruta.HUMANO: Color(0.93, 0.87, 0.75),
	Alma.Ruta.AMBIGUO: Color(0.80, 0.82, 0.80),
	Alma.Ruta.MAQUINA: Color(0.55, 0.95, 0.65),
}
## La luz de la pantalla: calida, neutra o fosforo.
const LUZ: Dictionary = {
	Alma.Ruta.HUMANO: Color(1.0, 0.72, 0.42, 0.6),
	Alma.Ruta.AMBIGUO: Color(0.6, 0.7, 0.62, 0.5),
	Alma.Ruta.MAQUINA: Color(0.42, 0.95, 0.55, 0.75),
}

@export_group("Textos (BORRADOR, ver docs/TEXTOS_PENDIENTES.md)")
@export var lineas_humano: PackedStringArray = [
	"Me senté frente a la última pantalla.",
	"No mostraba nada. Solo a alguien sentado, mirando.",
	"Me acordé del peso del tubo en las manos. De los que dejé pasar.",
	"Si esto que siento es un error de fábrica, lo quiero conservar.",
	"Me levanté. Afuera, la brasa seguía encendida.",
]
@export var lineas_ambiguo: PackedStringArray = [
	"Me senté frente a la última pantalla.",
	"Mostraba a alguien sentado. Se movía cuando yo me movía.",
	"Casi siempre.",
	"Esperé a que me dijera qué soy. No dijo nada.",
	"Sigo esperando.",
]
@export var lineas_maquina: PackedStringArray = [
	"Unidad en posición frente al terminal central.",
	"Imagen recibida: una unidad sentada. Coincidencia: total.",
	"Las vendas eran innecesarias. El dolor era una lectura.",
	"Nunca hubo nadie aquí dentro.",
	"Reanudando tarea.",
]
## Segundos por letra al teclear, y de pausa entre lineas.
@export var velocidad: float = 0.045
@export var pausa_linea: float = 1.6

@onready var figura: AnimatedSprite2D = $Escena/Figura
@onready var halo: Sprite2D = $Escena/Halo
@onready var pantalla: ColorRect = $Escena/Pantalla
@onready var texto: Label = $Texto

var _ruta: Alma.Ruta = Alma.Ruta.AMBIGUO
var _lineas: PackedStringArray = []
var _tiempo: float = 0.0
var _saltar: bool = false

func _ready() -> void:
	_ruta = Alma.ruta_actual()
	DirectorAudio.parar_musica()
	DirectorAudio.ambiente("crt_zumbido", -16.0)
	if figura.sprite_frames != null and figura.sprite_frames.has_animation(&"sentado"):
		figura.play(&"sentado")
	match _ruta:
		Alma.Ruta.HUMANO:
			_lineas = lineas_humano
		Alma.Ruta.MAQUINA:
			_lineas = lineas_maquina
		_:
			_lineas = lineas_ambiguo
	var fuente: Font = load(FUENTES[_ruta]) as Font
	if fuente != null:
		texto.add_theme_font_override("font", fuente)
		texto.add_theme_font_size_override("font_size", 8)
	texto.add_theme_color_override("font_color", COLORES[_ruta])
	halo.modulate = LUZ[_ruta]
	pantalla.color = (LUZ[_ruta] as Color).darkened(0.4)
	texto.text = ""
	_contar()

func _process(delta: float) -> void:
	_tiempo += delta
	var corte: float = 0.3 if fmod(_tiempo, 4.7) < 0.06 else 1.0
	halo.modulate.a = (LUZ[_ruta] as Color).a * (0.85 + 0.15 * sin(_tiempo * 2.0)) * corte

func _unhandled_input(evento: InputEvent) -> void:
	# Acelera, no salta: el final se lee entero.
	if evento.is_action_pressed("interactuar") or evento.is_action_pressed("atacar") \
			or evento.is_action_pressed("saltar"):
		_saltar = true

func _contar() -> void:
	await get_tree().create_timer(1.6).timeout
	for linea: String in _lineas:
		_saltar = false
		texto.text = ""
		for i: int in linea.length():
			texto.text = linea.substr(0, i + 1)
			if _ruta == Alma.Ruta.MAQUINA and randf() < 0.04:
				texto.text = texto.text.substr(0, i) + "#"
			if i % 3 == 0:
				DirectorAudio.efecto_variado("menu_mover", -24.0, 0.3)
			if not _saltar:
				await get_tree().create_timer(velocidad).timeout
		texto.text = linea
		await get_tree().create_timer(pausa_linea).timeout
	await get_tree().create_timer(1.0).timeout
	CargadorEscenas.cambiar_a(RUTA_FIN)
