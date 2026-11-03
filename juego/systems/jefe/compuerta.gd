# Compuerta de la arena del jefe: baja para cerrar y sube para abrir. La usa
# ArenaJefe; la instancia tools/generar_nivel_07.gd.
class_name Compuerta
extends StaticBody2D

@export var abierta_al_inicio: bool = true
## Cuanto sube al abrirse, en px. Igual al alto de la hoja.
@export var recorrido: float = 64.0

@onready var hoja: Node2D = $Hoja
@onready var forma: CollisionShape2D = $Forma

var abierta: bool = true

func _ready() -> void:
	_fijar(abierta_al_inicio, true)

func abrir(inmediato: bool = false) -> void:
	_fijar(true, inmediato)

func cerrar(inmediato: bool = false) -> void:
	_fijar(false, inmediato)

func _fijar(abrir_: bool, inmediato: bool) -> void:
	abierta = abrir_
	forma.set_deferred("disabled", abrir_)
	var destino: float = -recorrido if abrir_ else 0.0
	if inmediato:
		hoja.position.y = destino
		return
	DirectorAudio.efecto("puerta", -4.0, 0.7)
	if not abrir_:
		Impacto.sacudir(3.0, 0.25)
	var mover: Tween = create_tween()
	mover.tween_property(hoja, "position:y", destino, 0.35 if not abrir_ else 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if not abrir_ else Tween.EASE_OUT)
