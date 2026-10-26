# Estado Saltar: la fase de ascenso. Termina al empezar a bajar o al soltar el botón.
extends Estado

func entrar() -> void:
	jugador.ejecutar_salto()
	# El polvo del impulso es lo que hace que el salto tenga origen. Sin el, el
	# personaje parece que se despega del suelo en vez de empujar contra el.
	Efectos.polvo(jugador, jugador.global_position, 0.5)
	DirectorAudio.efecto_variado("salto", -8.0)

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, _velocidad_tope())
	if jugador.permitir_ataque_aereo and transicion_atacar():
		return
	if Input.is_action_just_released("saltar"):
		jugador.cortar_salto()
	if jugador.velocity.y >= 0.0:
		maquina.cambiar_a("Caer")
	elif transicion_al_aterrizar():
		return

func _velocidad_tope() -> float:
	return jugador.velocidad_correr if Input.is_action_pressed("correr") else jugador.velocidad_caminar
