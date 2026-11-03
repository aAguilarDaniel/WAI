# Estado Rodar: impulso de duración fija en la dirección de la mirada, con una
# ventana de invulnerabilidad en el medio (esquiva tipo Dark Souls).
# Durante el rodar no se controla la dirección: es un compromiso, no un movimiento libre.
extends Estado

var _t: float = 0.0
var _invulnerable: bool = false

func entrar() -> void:
	_t = 0.0
	_invulnerable = false
	jugador.velocity.x = jugador.mira * jugador.velocidad_rodar

func salir() -> void:
	_fijar_invulnerable(false)
	jugador.iniciar_enfriamiento_rodar()

func procesar_fisica(delta: float) -> void:
	jugador.aplicar_gravedad(delta)
	jugador.velocity.x = jugador.mira * jugador.velocidad_rodar
	_t += delta
	_actualizar_ventana_iframes()
	if _t < jugador.duracion_rodar:
		return
	if jugador.is_on_floor():
		maquina.cambiar_a("Quieto")
	else:
		maquina.cambiar_a("Caer")

## Enciende y apaga la esquiva. La ventana no cubre todo el rodar a propósito.
func _actualizar_ventana_iframes() -> void:
	if not jugador.rodar_da_invulnerabilidad:
		return
	var inicio: float = jugador.rodar_iframes_inicio
	var fin: float = inicio + jugador.rodar_iframes_duracion
	var dentro: bool = _t >= inicio and _t < fin
	if dentro != _invulnerable:
		_fijar_invulnerable(dentro)

func _fijar_invulnerable(activo: bool) -> void:
	if _invulnerable == activo:
		return
	_invulnerable = activo
	jugador.salud.fijar_invulnerable(activo)
	if not jugador.rodar_mostrar_iframes:
		return
	if activo:
		jugador.sprite.modulate = jugador.color_iframes
	else:
		# NO se restaura el tinte de antes de rodar: si era el rojo del golpe y la
		# gracia se acabo a mitad de la voltereta, el personaje se quedaba rojo
		# hasta el siguiente golpe. Se mira como esta la salud AHORA.
		jugador.sprite.modulate = jugador.tinte_herido if jugador.salud.en_gracia_por_golpe() \
			else Color.WHITE
