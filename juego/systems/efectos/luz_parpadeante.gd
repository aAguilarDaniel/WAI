# Luz de escenario: farolas, neones, leds de racks y lamparas colgantes.
# La coloca tools/constructor_nivel.gd sobre un Sprite2D aditivo (brillo.png).
#
# Tres caracteres de luz, porque una luz quieta en un mundo muerto se lee como
# decorado pegado, y una que tiembla se lee como algo que todavia funciona a duras
# penas (ARTE.md §2: "una instalacion todavia encendida").
class_name LuzParpadeante
extends Sprite2D

enum Modo {
	RESPIRAR,   ## Sube y baja despacio. Lamparas, el ojo del roseton.
	PARPADEAR,  ## Encendida casi siempre, con cortes cortos. Neones.
	AVERIADA,   ## Apagada a ratos largos y vuelve a trompicones. Farolas rotas.
}

@export var modo: Modo = Modo.RESPIRAR
@export var color: Color = Color(1.0, 0.72, 0.36)
## Opacidad base del halo.
@export_range(0.0, 1.0, 0.01) var intensidad: float = 0.55
## Cuanto respira, en fraccion de la intensidad.
@export_range(0.0, 1.0, 0.01) var amplitud: float = 0.18
@export var velocidad: float = 1.0
## Probabilidad por segundo de un corte (PARPADEAR y AVERIADA).
@export var cortes_por_segundo: float = 0.6

var _tiempo: float = 0.0
var _apagada: float = 0.0
var _tartamudeo: float = 0.0

func _ready() -> void:
	# Desfase por posicion: si todas las luces respiraran a la vez el nivel se
	# leeria como un solo circuito y no como restos sueltos.
	_tiempo = fmod(absf(global_position.x) * 0.071 + absf(global_position.y) * 0.013, TAU)
	_aplicar(intensidad)

func _process(delta: float) -> void:
	_tiempo += delta * velocidad
	var respiro: float = 1.0 + sin(_tiempo) * amplitud + sin(_tiempo * 2.7) * amplitud * 0.3
	var valor: float = intensidad * respiro
	match modo:
		Modo.PARPADEAR:
			valor *= _corte(delta, 0.04, 0.14)
		Modo.AVERIADA:
			valor *= _corte(delta, 0.4, 2.2)
	_aplicar(valor)

## 1.0 encendida, ~0 apagada. Al volver de un corte largo tartamudea un poco.
func _corte(delta: float, minimo: float, maximo: float) -> float:
	if _apagada > 0.0:
		_apagada -= delta
		if _apagada <= 0.0:
			_tartamudeo = 0.25
		return 0.05
	if _tartamudeo > 0.0:
		_tartamudeo -= delta
		return 1.0 if fmod(_tartamudeo, 0.08) > 0.04 else 0.2
	if randf() < cortes_por_segundo * delta:
		_apagada = randf_range(minimo, maximo)
	return 1.0

func _aplicar(valor: float) -> void:
	modulate = Color(color.r, color.g, color.b, clampf(valor, 0.0, 1.0))
