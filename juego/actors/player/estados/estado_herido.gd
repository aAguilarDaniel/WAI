# Estado Herido: retroceso corto y aturdimiento. No mata al jugador de por sí;
# de la muerte se encarga la señal murio del ComponenteSalud.
extends Estado

var _restante: float = 0.0

func entrar() -> void:
	_restante = jugador.duracion_aturdimiento
	var empuje: float = -signf(jugador.direccion_ultimo_golpe.x)
	if empuje == 0.0:
		empuje = -jugador.mira
	jugador.velocity = Vector2(empuje * jugador.retroceso_x, -jugador.retroceso_y)

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	# Sin control durante el aturdimiento: el golpe se siente porque interrumpe.
	jugador.velocity.x = move_toward(jugador.velocity.x, 0.0, jugador.frenado_retroceso * delta)
	_restante -= delta
	if _restante > 0.0:
		return
	if jugador.is_on_floor():
		maquina.cambiar_a("Quieto")
	else:
		maquina.cambiar_a("Caer")
