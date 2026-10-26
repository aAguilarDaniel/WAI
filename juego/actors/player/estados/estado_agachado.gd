# Estado Agachado: caja de colisión reducida y velocidad baja.
# No se levanta si hay techo encima: se queda agachado hasta que haya hueco.
extends Estado

func entrar() -> void:
	jugador.ajustar_forma(true)

func salir() -> void:
	jugador.ajustar_forma(false)

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, jugador.velocidad_agachado)
	if transiciones_de_suelo():
		return
	if not Input.is_action_pressed("agachar") and not jugador.hay_techo_encima():
		maquina.cambiar_a("Quieto")
