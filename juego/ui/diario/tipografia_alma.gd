# La tipografía del diario es el medidor del eje del alma (CLAUDE.md §3.3, ARTE.md §6).
# Escucha umbral_cruzado y reconstruye el Theme del diario entero. No consulta a
# Alma cada frame y el jugador nunca recibe un aviso de que su ruta cambió:
# abre el diario en algún momento y su propia letra ya no es la misma.
class_name TipografiaAlma
extends Node

## Control al que se le aplica el tema. Todos sus hijos lo heredan.
@export var raiz: Control

@export_group("Fuentes")
## Manuscrita, trazo irregular. Si se deja vacía se usa un sustituto generado.
@export var fuente_humana: Font
## Híbrida: mezcla de manuscrita y mecanografiada.
@export var fuente_hibrida: Font
## Máquina de escribir, espaciado perfecto.
@export var fuente_maquina: Font
@export var tamano_fuente: int = 8

@export_group("Colores")
## Crema del papel del diario (ARTE.md §1, polo humano).
@export var color_humano: Color = Color(0.93, 0.87, 0.75)
@export var color_hibrido: Color = Color(0.80, 0.82, 0.80)
## Verde fósforo de CRT (polo máquina).
@export var color_maquina: Color = Color(0.55, 0.95, 0.65)

@export_group("Ruta máquina")
## En ruta máquina el texto se corrompe de vez en cuando.
@export var glitch_activo: bool = true
@export_range(0.0, 0.2, 0.005) var probabilidad_glitch: float = 0.02
## Palabras emotivas que la máquina "autocorrige". El contenido lo escriben
## ustedes: ver docs/TEXTOS_PENDIENTES.md. Formato { "palabra": "reemplazo" }.
@export var correcciones_automaticas: Dictionary = {}

const CARACTERES_GLITCH: String = "#%&/_+*<>=~^"

var _tema: Theme = null

func _ready() -> void:
	_tema = Theme.new()
	Alma.umbral_cruzado.connect(_al_cruzar_umbral)
	aplicar(Alma.ruta_actual())

func _al_cruzar_umbral(_anterior: Alma.Ruta, nueva: Alma.Ruta) -> void:
	aplicar(nueva)

## Reconstruye el tema para una ruta. Se puede llamar a mano para previsualizar.
func aplicar(ruta: Alma.Ruta) -> void:
	if raiz == null or _tema == null:
		return
	var fuente: Font = _fuente_de(ruta)
	var color: Color = _color_de(ruta)
	for tipo: String in ["Label", "Button", "RichTextLabel", "CheckButton", "OptionButton"]:
		_tema.set_font("font", tipo, fuente)
		_tema.set_font_size("font_size", tipo, tamano_fuente)
		_tema.set_color("font_color", tipo, color)
	# Las pestañas van aparte: TabContainer no usa "font_color", sino un color por
	# pestaña activa e inactiva. Sin esto la barra se queda en la fuente por
	# defecto y se ve enorme al lado del texto del cuaderno.
	_tema.set_font("font", "TabContainer", fuente)
	_tema.set_font_size("font_size", "TabContainer", tamano_fuente)
	_tema.set_color("font_selected_color", "TabContainer", color)
	_tema.set_color("font_unselected_color", "TabContainer", color * 0.6)
	raiz.theme = _tema

## Transforma un texto según la ruta. En ruta máquina corrige palabras emotivas
## y mete glitch ocasional; en las otras devuelve el texto tal cual.
func transformar(texto: String) -> String:
	if Alma.ruta_actual() != Alma.Ruta.MAQUINA:
		return texto
	var salida: String = texto
	for palabra: String in correcciones_automaticas:
		salida = salida.replace(palabra, str(correcciones_automaticas[palabra]))
	if not glitch_activo:
		return salida
	return _glitchear(salida)

func _glitchear(texto: String) -> String:
	var resultado: PackedStringArray = PackedStringArray()
	for i: int in texto.length():
		var c: String = texto[i]
		if c != " " and randf() < probabilidad_glitch:
			c = CARACTERES_GLITCH[randi() % CARACTERES_GLITCH.length()]
		resultado.append(c)
	return "".join(resultado)

func _fuente_de(ruta: Alma.Ruta) -> Font:
	match ruta:
		Alma.Ruta.HUMANO:
			return fuente_humana if fuente_humana != null else _sustituto(ruta)
		Alma.Ruta.MAQUINA:
			return fuente_maquina if fuente_maquina != null else _sustituto(ruta)
		_:
			return fuente_hibrida if fuente_hibrida != null else _sustituto(ruta)

func _color_de(ruta: Alma.Ruta) -> Color:
	match ruta:
		Alma.Ruta.HUMANO:
			return color_humano
		Alma.Ruta.MAQUINA:
			return color_maquina
		_:
			return color_hibrido

## Sustituto mientras no existan las fuentes bitmap reales. Deforma la fuente por
## defecto para que las tres rutas se distingan y el sistema se pueda probar.
## Al asignar las fuentes de verdad en el inspector, esto deja de usarse.
func _sustituto(ruta: Alma.Ruta) -> Font:
	var variacion: FontVariation = FontVariation.new()
	variacion.base_font = ThemeDB.fallback_font
	match ruta:
		Alma.Ruta.HUMANO:
			# Inclinada y algo más gruesa: se acerca a un trazo a mano.
			variacion.variation_embolden = 0.12
			variacion.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2.ZERO)
		Alma.Ruta.MAQUINA:
			# Espaciado perfecto y frío, como una máquina de escribir.
			variacion.spacing_glyph = 2
			variacion.spacing_space = 2
		_:
			variacion.spacing_glyph = 1
	return variacion
