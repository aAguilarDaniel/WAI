# Capa de post-proceso que inclina la paleta segun el eje del alma (ARTE.md §1).
# Se suscribe a Alma.umbral_cruzado y anima la transicion: el jugador no debe
# percibir un corte, solo notar con el tiempo que el mundo se ve distinto.
class_name PaletaAlma
extends CanvasLayer

## Segundos que tarda la paleta en llegar al nuevo polo. Lento a proposito.
@export var duracion_transicion: float = 3.0

@onready var lienzo: ColorRect = $Lienzo

var _material: ShaderMaterial = null
var _animacion: Tween = null

func _ready() -> void:
	_material = lienzo.material as ShaderMaterial
	Alma.umbral_cruzado.connect(_al_cruzar_umbral)
	aplicar(Alma.ruta_actual(), true)

func _al_cruzar_umbral(_anterior: Alma.Ruta, nueva: Alma.Ruta) -> void:
	aplicar(nueva, false)

## Lleva la paleta a la ruta indicada. Con inmediato=true salta sin animar
## (al cargar una partida, por ejemplo).
func aplicar(ruta: Alma.Ruta, inmediato: bool = false) -> void:
	if _material == null:
		return
	var destino_maquina: float = 1.0 if ruta == Alma.Ruta.MAQUINA else 0.0
	var destino_humano: float = 1.0 if ruta == Alma.Ruta.HUMANO else 0.0
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	if inmediato:
		_material.set_shader_parameter("peso_maquina", destino_maquina)
		_material.set_shader_parameter("peso_humano", destino_humano)
		return
	_animacion = create_tween()
	_animacion.set_parallel(true)
	_animacion.tween_method(_fijar_maquina,
		float(_material.get_shader_parameter("peso_maquina")),
		destino_maquina, duracion_transicion)
	_animacion.tween_method(_fijar_humano,
		float(_material.get_shader_parameter("peso_humano")),
		destino_humano, duracion_transicion)

func _fijar_maquina(valor: float) -> void:
	_material.set_shader_parameter("peso_maquina", valor)

func _fijar_humano(valor: float) -> void:
	_material.set_shader_parameter("peso_humano", valor)
