# Estado Caminar: movimiento en suelo a velocidad normal.
extends Estado

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, jugador.velocidad_caminar)
	if transiciones_de_suelo():
		return
	if jugador.entrada_horizontal() == 0.0:
		maquina.cambiar_a("Quieto")
	elif Input.is_action_pressed("correr"):
		maquina.cambiar_a("Correr")
	elif Input.is_action_pressed("agachar"):
		maquina.cambiar_a("Agachado")
