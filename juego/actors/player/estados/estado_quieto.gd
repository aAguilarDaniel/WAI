# Estado Quieto: de pie sin input. Punto de partida de la máquina de estados.
extends Estado

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.frenar(delta)
	if transiciones_de_suelo():
		return
	if Input.is_action_pressed("agachar"):
		maquina.cambiar_a("Agachado")
	elif jugador.entrada_horizontal() != 0.0:
		maquina.cambiar_a("Correr" if Input.is_action_pressed("correr") else "Caminar")
