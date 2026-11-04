# Cartel con los controles del juego, colocado en el mundo al principio del
# nivel 1 (tools/generar_nivel_01.gd). El jugador lo tiene delante desde el primer
# cuadro y lo deja atras al avanzar: no es una pantalla ni pausa nada.
#
# Las teclas se leen del InputMap (PistaContextual.nombre_de_accion), nunca se
# escriben a mano: si se remapean en el diario o se conecta un mando, cambian.
class_name CartelControles
extends Node2D

## [acciones, texto]. Varias acciones se muestran juntas ("A D").
const FILAS: Array = [
	[["mover_izq", "mover_der"], "Moverse"],
	[["saltar"], "Saltar"],
	[["correr"], "Correr"],
	[["agachar"], "Agacharse"],
	[["rodar"], "Rodar"],
	[["atacar"], "Atacar"],
	[["cambiar_arma"], "Cambiar arma"],
	[["curar"], "Curarse"],
	[["interactuar"], "Interactuar"],
	[["diario"], "Diario / pausa"],
]

@onready var rejilla: GridContainer = $Placa/Rejilla

var _teclas: Array[Label] = []

func _ready() -> void:
	for fila: Array in FILAS:
		var tecla: Label = _etiqueta(Color(1.0, 0.82, 0.48))
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tecla.custom_minimum_size.x = 48.0
		rejilla.add_child(tecla)
		_teclas.append(tecla)
		var texto: Label = _etiqueta(Color(0.93, 0.89, 0.8))
		texto.text = str(fila[1])
		rejilla.add_child(texto)
	refrescar()
	Input.joy_connection_changed.connect(_al_cambiar_mando)

## Vuelve a leer las teclas. Quien remapea lo hace en el diario, con el juego en
## pausa: al despausar ya estan las nuevas (ver _notification).
func refrescar() -> void:
	for i: int in _teclas.size():
		var nombres: PackedStringArray = []
		for accion: String in FILAS[i][0]:
			nombres.append(PistaContextual.nombre_de_accion(StringName(accion)))
		_teclas[i].text = " ".join(nombres)

## Texto de la tecla de una fila. Lo usa tools/prueba_controles.gd.
func tecla_de_fila(indice: int) -> String:
	return _teclas[indice].text

func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED and is_node_ready():
		refrescar()

func _al_cambiar_mando(_dispositivo: int, _conectado: bool) -> void:
	refrescar()

func _etiqueta(color: Color) -> Label:
	var etiqueta: Label = Label.new()
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", TAMANO)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta

## La bitmap 5x7: nitida a 384x216, y caben las diez filas en medio cuadro.
const FUENTE: Font = preload("res://ui/diario/fuentes/wai_base.fnt")
const TAMANO: int = 8
