# Clase base de todos los estados del jugador. La usan los scripts de estados/.
# No se instancia sola: cada estado concreto la extiende y sobrescribe lo que necesita.
class_name Estado
extends Node

## Referencias que inyecta MaquinaEstados.inicializar(). Nunca buscar con get_node.
var jugador: Jugador
var maquina: MaquinaEstados

## Se llama una vez al entrar en el estado.
func entrar() -> void:
	pass

## Se llama una vez al salir del estado.
func salir() -> void:
	pass

## Se llama cada frame de física mientras el estado está activo.
func procesar_fisica(_delta: float) -> void:
	pass

## Transiciones que comparten todos los estados con los pies en el suelo.
## Devuelve true si hubo transición: el estado debe cortar su lógica ahí.
func transiciones_de_suelo() -> bool:
	if jugador.hay_salto_pedido() and jugador.puede_saltar():
		maquina.cambiar_a("Saltar")
		return true
	if Input.is_action_just_pressed("rodar") and jugador.puede_rodar():
		maquina.cambiar_a("Rodar")
		return true
	if transicion_atacar():
		return true
	if not jugador.is_on_floor():
		maquina.cambiar_a("Caer")
		return true
	return false

## Ataque. Los estados de aire la llaman solo si permitir_ataque_aereo está activo.
func transicion_atacar() -> bool:
	if not Input.is_action_just_pressed("atacar") or not jugador.puede_atacar():
		return false
	maquina.cambiar_a("Atacar")
	return true

## Velocidad de caida a partir de la cual el aterrizaje levanta polvo y sacude
## la camara. Por debajo, caerse un escalon no deberia hacer ruido visual.
const CAIDA_CON_PESO: float = 190.0

## Transiciones que comparten los estados en el aire al tocar suelo.
func transicion_al_aterrizar() -> bool:
	if not jugador.is_on_floor():
		return false
	_aterrizaje_con_peso()
	if jugador.entrada_horizontal() != 0.0:
		maquina.cambiar_a("Correr" if Input.is_action_pressed("correr") else "Caminar")
	else:
		maquina.cambiar_a("Quieto")
	return true

## Polvo y sacudida al aterrizar, proporcionales a lo que se ha caido.
## Va en la clase base para que valga igual para Saltar, Caer y Rodar: es la
## fisica del aterrizaje, no algo particular de un estado.
func _aterrizaje_con_peso() -> void:
	var caida: float = jugador.velocity.y
	if caida < CAIDA_CON_PESO:
		return
	var fuerza: float = clampf((caida - CAIDA_CON_PESO) / 220.0, 0.0, 1.0)
	Efectos.polvo(jugador, jugador.global_position, 0.6 + fuerza)
	DirectorAudio.efecto_variado("aterrizar", -14.0 + fuerza * 8.0)
	if fuerza > 0.25:
		Impacto.sacudir(0.8 + fuerza * 2.2, 0.10 + fuerza * 0.06)
