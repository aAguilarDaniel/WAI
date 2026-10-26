# Estado Atacar: golpe melee en tres fases. La hitbox solo existe en la fase
# activa, no durante toda la animación. Eso es lo que hace legible el combate.
extends Estado

enum Fase { ANTICIPACION, ACTIVO, RECUPERACION }

var _t: float = 0.0
var _fase: Fase = Fase.ANTICIPACION

func entrar() -> void:
	_t = 0.0
	_fase = Fase.ANTICIPACION
	jugador.orientar_hitbox()

func salir() -> void:
	jugador.arma.terminar_golpe()
	jugador.hitbox_ataque.desactivar()
	jugador.iniciar_enfriamiento_ataque()

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.mover_horizontal(delta, jugador.velocidad_caminar * jugador.factor_velocidad_atacando)
	_t += delta
	_avanzar_fases()
	if _t < jugador.duracion_total_ataque():
		return
	if jugador.is_on_floor():
		maquina.cambiar_a("Quieto")
	else:
		maquina.cambiar_a("Caer")

## Empuje hacia atrás al disparar. Las armas pesadas se sienten en las manos.
func _aplicar_retroceso() -> void:
	var equipada: ArmaData = jugador.arma.arma_actual()
	if equipada == null or is_zero_approx(equipada.retroceso):
		return
	jugador.velocity.x -= jugador.mira * equipada.retroceso

func _avanzar_fases() -> void:
	var fin_anticipacion: float = jugador.anticipacion_ataque
	var fin_activo: float = fin_anticipacion + jugador.duracion_golpe
	if _fase == Fase.ANTICIPACION and _t >= fin_anticipacion:
		_fase = Fase.ACTIVO
		# El arma decide si esto es un golpe melee o un disparo.
		if jugador.arma.arma_actual() != null:
			jugador.arma.ejecutar_golpe(jugador.mira)
		else:
			jugador.hitbox_ataque.activar()
		_aplicar_retroceso()
	elif _fase == Fase.ACTIVO and _t >= fin_activo:
		_fase = Fase.RECUPERACION
		jugador.arma.terminar_golpe()
		jugador.hitbox_ataque.desactivar()
