# Indicador de depuración del eje del alma. Se abre y cierra con F3.
# TEMPORAL: docs/HITOS.md manda eliminarlo en el Hito 8. El jugador NUNCA debe
# ver el eje como número (CLAUDE.md §3.1); esto existe solo para desarrollarlo.
extends Label

func _ready() -> void:
	visible = false
	Alma.valor_cambiado.connect(_al_cambiar_valor)
	Alma.umbral_cruzado.connect(_al_cruzar_umbral)
	_refrescar()

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("debug_alma"):
		visible = not visible
		_refrescar()

func _al_cambiar_valor(_valor: float) -> void:
	_refrescar()

func _al_cruzar_umbral(anterior: Alma.Ruta, nuevo: Alma.Ruta) -> void:
	print("[Alma] umbral cruzado: %s -> %s" % [Alma.nombre_ruta(anterior), Alma.nombre_ruta(nuevo)])
	_refrescar()

func _refrescar() -> void:
	if not visible:
		return
	text = "alma %+.3f [%s]" % [Alma.valor(), Alma.nombre_ruta(Alma.ruta_actual())]
