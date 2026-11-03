# Herramienta: prueba del camino secreto. Que se cuenten bien los enemigos, que
# los muertos sigan muertos, que un enemigo empujado al vacio cuente, que el
# monitor solo lleve al Reflejo si no queda nadie, y la pelea con el Reflejo.
#
#   godot --path juego res://tools/prueba_secreto.tscn
#
# Respalda user://partida.json y lo restaura al terminar.
extends Node

const NIVEL_1: String = "res://levels/nivel_01/nivel_01.tscn"
const NIVEL_7: String = "res://levels/nivel_07/nivel_07.tscn"
const SECRETO: String = "res://levels/secreto/nivel_secreto.tscn"
const FINAL: String = "res://ui/final/final.tscn"
## 9 + 6 + 9 + 9 + 13 + 9. Si cambian el numero de enemigos, cambia esto.
const TOTAL_ESPERADO: int = 55

var _fallos: int = 0
var _respaldo: String = ""
var _habia_partida: bool = false

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	_habia_partida = Guardado.hay_partida()
	if _habia_partida:
		_respaldo = FileAccess.get_file_as_string(Guardado.RUTA_PARTIDA)
	EstadoJuego.reiniciar()
	Alma.cargar(0.0)
	_montar(NIVEL_1)
	_correr.call_deferred()

func _correr() -> void:
	await _esperar(0.4)
	_comprobar("el registro cuenta %d enemigos en el juego (esperados %d)" % [
		RegistroEnemigos.total(), TOTAL_ESPERADO], RegistroEnemigos.total() == TOTAL_ESPERADO)
	await _prueba_muerto_sigue_muerto()
	await _prueba_vacio_mata()
	await _prueba_monitor_sin_secreto()
	await _prueba_monitor_con_secreto()
	await _prueba_reflejo()
	_restaurar_partida()
	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

func _prueba_muerto_sigue_muerto() -> void:
	var enemigo: EnemigoPatrulla = _nodo("Enemigos/Enemigo01") as EnemigoPatrulla
	enemigo.salud.matar(self)
	await _esperar(0.2)
	_comprobar("matar a un enemigo lo apunta en el registro (1/%d)" % RegistroEnemigos.total(),
		RegistroEnemigos.eliminados() == 1)
	CargadorEscenas.cambiar_a(NIVEL_1)
	await _esperar(1.4)
	_comprobar("al volver a cargar el nivel sigue muerto", _nodo("Enemigos/Enemigo01") == null)
	_comprobar("y los demas siguen ahi", _nodo("Enemigos/Enemigo02") != null)

## Un golpe puede empujar a un enemigo a un abismo. Antes caia para siempre.
func _prueba_vacio_mata() -> void:
	var enemigo: EnemigoPatrulla = _nodo("Enemigos/Enemigo02") as EnemigoPatrulla
	var zona: Area2D = _nodo("ZonaMortal") as Area2D
	enemigo.global_position = zona.global_position + Vector2(0.0, -50.0)
	await _esperar(1.0)
	_comprobar("un enemigo que cae al vacio muere y cuenta", RegistroEnemigos.eliminados() == 2)

func _prueba_monitor_sin_secreto() -> void:
	CargadorEscenas.cambiar_a(NIVEL_7)
	await _esperar_hasta(func() -> bool: return _escena() == NIVEL_7, 5.0)
	await _esperar(0.5)
	EstadoJuego.fijar_bandera(ArenaJefe.BANDERA, true)
	await _cruzar_monitor()
	_comprobar("sin matarlos a todos, el monitor lleva al final", _escena() == FINAL)

func _prueba_monitor_con_secreto() -> void:
	for ruta: String in RegistroEnemigos.NIVELES:
		for nombre: String in RegistroEnemigos._enemigos_de(ruta):
			EstadoJuego.fijar_bandera(RegistroEnemigos.clave(ruta, nombre), true)
	_comprobar("con todos marcados, el registro lo sabe", RegistroEnemigos.todos_eliminados())
	await _esperar(1.0)
	CargadorEscenas.cambiar_a(NIVEL_7)
	await _esperar_hasta(func() -> bool: return _escena() == NIVEL_7, 5.0)
	await _esperar(0.5)
	await _cruzar_monitor()
	_comprobar("matandolos a todos, el monitor lleva a la sala secreta", _escena() == SECRETO)

func _prueba_reflejo() -> void:
	_quitar_apertura()
	var jugador: Jugador = _jugador()
	var reflejo: Reflejo = _nodo("Arena/Reflejo") as Reflejo
	var entrada: Compuerta = _nodo("Arena/CompuertaEntrada") as Compuerta
	var puerta: PuertaNivel = _nodo("Arena/PuertaSalida") as PuertaNivel
	jugador.salud.fijar_invulnerable(true)
	_comprobar("el reflejo espera sentado", reflejo.esta_dormido())
	_comprobar("la pantalla no es una salida todavia", not puerta.monitoring)
	_poner(jugador, Vector2i(13, 15))
	await _sostener("mover_der", 1.5, func() -> bool: return not entrada.abierta)
	_comprobar("al entrar se cierra la compuerta", not entrada.abierta)
	await _esperar(4.2)
	var musica: AudioStream = DirectorAudio.sonando_musica()
	_comprobar("y suena la musica secreta", musica != null and musica.resource_path.ends_with("musica_secreta.wav"))
	_comprobar("y el reflejo se levanta", not reflejo.esta_dormido())

	# El disparo va a 18 px: por encima del agachado, contra el que esta de pie.
	jugador.salud.fijar_invulnerable(false)
	reflejo.salud.fijar_invulnerable(true)
	for agachado: bool in [true, false]:
		reflejo._cambiar(Reflejo.Modo.RECUPERA)
		await _esperar(0.2)
		for nodo: Node in get_tree().current_scene.get_children():
			if nodo is Proyectil or nodo is OndaChoque:
				nodo.queue_free()
		jugador.salud.revivir()
		_poner(jugador, Vector2i(15, 15))
		reflejo.global_position = Vector2(30 * 16, 15 * 16 - 1)
		reflejo._orientar(-1)
		if agachado:
			Input.action_press("agachar")
		await _esperar(0.15)
		var antes: int = jugador.salud.salud_actual
		reflejo._ataque = Reflejo.Ataque.DISPARO
		reflejo._cambiar(Reflejo.Modo.AVISO)
		await _esperar(2.4)
		Input.action_release("agachar")
		if agachado:
			_comprobar("agachado, su disparo pasa por encima (%d -> %d)" % [antes, jugador.salud.salud_actual],
				jugador.salud.salud_actual == antes)
		else:
			_comprobar("de pie, su disparo alcanza (%d -> %d)" % [antes, jugador.salud.salud_actual],
				jugador.salud.salud_actual < antes)
	reflejo.salud.fijar_invulnerable(false)

	reflejo.salud.aplicar_dano(12, Vector2.RIGHT, self)
	await _esperar(0.1)
	_comprobar("a la mitad pasa a la fase 2", reflejo.fase == 2)

	jugador.salud.matar(self)
	await _esperar(0.4)
	_comprobar("morir lo devuelve a la pantalla con la vida llena",
		reflejo.esta_dormido() and reflejo.salud.salud_actual == reflejo.salud.salud_maxima)
	_comprobar("y reabre la compuerta", entrada.abierta)

	jugador.salud.fijar_invulnerable(true)
	_poner(jugador, Vector2i(13, 15))
	await _sostener("mover_der", 1.5, func() -> bool: return not entrada.abierta)
	await _esperar(1.6)
	var entradas_antes: int = EstadoJuego.entradas.size()
	for i: int in 40:
		if not reflejo.salud.esta_vivo():
			break
		reflejo.salud.fijar_invulnerable(false)
		reflejo._esquivando = 0.0
		reflejo.salud.aplicar_dano(3, Vector2.RIGHT, self)
		await _esperar(0.2)
	await _esperar_hasta(func() -> bool: return puerta.monitoring, 8.0)
	_comprobar("al vencerlo, la pantalla se vuelve la salida", puerta.monitoring)
	_comprobar("y el diario escribe su entrada", EstadoJuego.entradas.size() == entradas_antes + 1)
	await _esperar(0.3)
	jugador.global_position = puerta.global_position + Vector2(-20.0, -1.0)
	await _sostener("mover_der", 3.0, func() -> bool: return _escena() == FINAL)
	await _esperar(2.4)
	var texto: Label = get_tree().current_scene.get_node_or_null("Texto") as Label
	_comprobar("y lleva al final secreto ('%s')" % (texto.text if texto != null else ""),
		_escena() == FINAL and texto != null and texto.text.begins_with("Lo mat"))

# ------------------------------------------------------------- Utilidades ----

func _cruzar_monitor() -> void:
	var jugador: Jugador = _jugador()
	_quitar_apertura()
	jugador.salud.fijar_invulnerable(true)
	jugador.global_position = Vector2(84 * 16, 15 * 16 - 1)
	await _sostener("mover_der", 4.0, func() -> bool: return _escena() != NIVEL_7)
	await _esperar(1.0)

func _montar(ruta: String) -> void:
	var nivel: Node = (load(ruta) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(nivel)
	get_tree().set_deferred("current_scene", nivel)

func _poner(jugador: Jugador, celda: Vector2i, dy: float = -1.0) -> void:
	jugador.global_position = Vector2(celda.x * 16 + 8, celda.y * 16 + dy)
	jugador.velocity = Vector2.ZERO

func _comprobar(texto: String, ok: bool) -> void:
	print("%s  %s" % ["PASA " if ok else "FALLA", texto])
	if not ok:
		_fallos += 1

func _escena() -> String:
	var actual: Node = get_tree().current_scene
	return actual.scene_file_path if actual != null else ""

func _jugador() -> Jugador:
	return get_tree().get_first_node_in_group("jugador") as Jugador

func _nodo(ruta: String) -> Node:
	return get_tree().current_scene.get_node_or_null(ruta)

func _quitar_apertura() -> void:
	for hijo: Node in get_tree().current_scene.get_children():
		if hijo is AperturaSadak:
			(hijo as AperturaSadak).cancelar()

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout

func _esperar_hasta(condicion: Callable, tope: float) -> void:
	var transcurrido: float = 0.0
	while transcurrido < tope and not condicion.call():
		await get_tree().physics_frame
		transcurrido += get_physics_process_delta_time()

func _sostener(accion: String, segundos: float, hasta: Callable = Callable()) -> void:
	Input.action_press(accion)
	var transcurrido: float = 0.0
	while transcurrido < segundos:
		if hasta.is_valid() and hasta.call():
			break
		await get_tree().physics_frame
		transcurrido += get_physics_process_delta_time()
	Input.action_release(accion)

func _restaurar_partida() -> void:
	if _habia_partida:
		var archivo: FileAccess = FileAccess.open(Guardado.RUTA_PARTIDA, FileAccess.WRITE)
		archivo.store_string(_respaldo)
		archivo.close()
	else:
		Guardado.borrar()
