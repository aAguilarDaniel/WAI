# Estado Correr: igual que Caminar pero con la velocidad tope alta.
extends Estado

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, jugador.velocidad_correr)
	if transiciones_de_suelo():
		return
	if jugador.entrada_horizontal() == 0.0:
		maquina.cambiar_a("Quieto")
	elif not Input.is_action_pressed("correr"):
		maquina.cambiar_a("Caminar")
