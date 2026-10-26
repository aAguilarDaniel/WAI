# Estado Caer: fase de descenso. Aquí es donde el coyote time deja saltar igual.
extends Estado

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, _velocidad_tope())
	if jugador.permitir_ataque_aereo and transicion_atacar():
		return
	if jugador.hay_salto_pedido() and jugador.puede_saltar():
		maquina.cambiar_a("Saltar")
		return
	transicion_al_aterrizar()

func _velocidad_tope() -> float:
	return jugador.velocidad_correr if Input.is_action_pressed("correr") else jugador.velocidad_caminar
