# Cielo del nivel: CanvasLayer de pantalla completa que va por DEBAJO de todo.
# Lo instancia tools/generar_nivel_01.gd.
#
# La capa 1 del parallax era una textura de 216 px de alto sobre una camara que
# recorre unos 730 px de mundo: por arriba y por abajo se veia el color de fondo
# de Godot, dos franjas grises. Un CanvasLayer no puede quedarse corto nunca.
class_name Cielo
extends CanvasLayer

## Cuanto se mueve el cielo respecto de la camara. Muy bajo a proposito: es lo
## que esta MAS lejos de todo, asi que casi no se desplaza (ARTE.md §3).
@export var factor_parallax: Vector2 = Vector2(0.006, 0.05)

@onready var lienzo: ColorRect = $Lienzo

var _material: ShaderMaterial = null
var _camara: Camera2D = null

func _ready() -> void:
	_material = lienzo.material as ShaderMaterial
	# El cielo se dibuja aunque el juego este en pausa: si no, con el diario
	# abierto se congelaria y el corte se notaria.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("alto_viewport",
		float(get_viewport().get_visible_rect().size.y))
	var camara: Camera2D = _camara_actual()
	if camara == null:
		return
	var centro: Vector2 = camara.get_screen_center_position()
	_material.set_shader_parameter("desplazamiento_y", centro.y * factor_parallax.y)
	_material.set_shader_parameter("desplazamiento_x", centro.x * factor_parallax.x * 0.01)

## La camara puede cambiar (la del CRT, la de captura): se le pregunta al
## viewport en vez de guardarse una al arrancar.
func _camara_actual() -> Camera2D:
	if _camara != null and is_instance_valid(_camara) and _camara.is_current():
		return _camara
	_camara = get_viewport().get_camera_2d()
	return _camara
