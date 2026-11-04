# Herramienta: prueba de humo del tramo final (niveles 3, 4 y 5, el jefe y el
# final) y de los arreglos de esta sesion. Juega sola los momentos criticos y
# dice PASA o FALLA en cada uno.
#
#   godot --path juego res://tools/prueba_tramo_final.tscn
#
# NO con --headless: la TerminalCRT y las capturas necesitan renderizador.
# Respalda user://partida.json y lo restaura al terminar.
extends Node

const NIVEL_3: String = "res://levels/nivel_03/nivel_03.tscn"
const NIVEL_4: String = "res://levels/nivel_04/nivel_04.tscn"
const NIVEL_5: String = "res://levels/nivel_05/nivel_05.tscn"
const NIVEL_6: String = "res://levels/nivel_06/nivel_06.tscn"
const NIVEL_7: String = "res://levels/nivel_07/nivel_07.tscn"
const FINAL: String = "res://ui/final/final.tscn"
const TUBO: String = "res://systems/weapons/data/tubo_metal.tres"

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
	_montar(NIVEL_3)
	_correr.call_deferred()

func _correr() -> void:
	await _esperar(0.4)
	await _prueba_conducto()
	await _prueba_pasarelas_del_pozo()
	await _prueba_torreta_dispara()
	await _prueba_salida(Vector2i(171, 15), NIVEL_4, "la escotilla del nivel 3 lleva al nivel 4")
	await _prueba_fragil()
	await _prueba_torreta_muere_y_pesa()
	await _prueba_salida(Vector2i(163, 7), NIVEL_5, "la puerta de la cornisa lleva al nivel 5 (el archivo)")
	await _prueba_dron()
	await _prueba_salida(Vector2i(124, 15), NIVEL_6, "la salida del archivo lleva al nivel 6 (los hornos)")
	await _prueba_prensa()
	await _prueba_salida(Vector2i(140, 15), NIVEL_7, "la salida de los hornos lleva al nivel 7 (el relicario)")
	await _prueba_arena()
	await _prueba_rayo()
	await _prueba_muerte_en_arena()
	await _prueba_derrota()
	await _prueba_final()
	await _prueba_continuar_restaura_ruta()
	_restaurar_partida()
	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

# --------------------------------------------------------------- Nivel 3 ----

func _prueba_conducto() -> void:
	var jugador: Jugador = _jugador()
	_quitar_apertura()
	jugador.salud.fijar_invulnerable(true)
	_poner(jugador, Vector2i(46, 15))
	await _sostener("mover_der", 1.5)
	_comprobar("de pie no se entra al conducto (x=%d)" % int(jugador.global_position.x),
		jugador.global_position.x < 48 * 16)
	Input.action_press("agachar")
	await _sostener("mover_der", 6.0, func() -> bool: return jugador.global_position.x > 61 * 16)
	Input.action_release("agachar")
	_comprobar("agachado se cruza el conducto (x=%d)" % int(jugador.global_position.x),
		jugador.global_position.x > 60 * 16)

func _prueba_pasarelas_del_pozo() -> void:
	var jugador: Jugador = _jugador()
	var todas: bool = true
	for pasarela: Vector2i in [Vector2i(62, 13), Vector2i(68, 11), Vector2i(62, 9), Vector2i(68, 7)]:
		_poner(jugador, pasarela, -2.0)
		await _esperar(0.35)
		var fila: float = jugador.global_position.y / 16.0
		if not jugador.is_on_floor() or absf(fila - pasarela.y) > 0.2:
			todas = false
			print("   pasarela en la fila %d: el jugador acabo en la fila %.1f" % [pasarela.y, fila])
	_comprobar("las cuatro pasarelas del pozo sostienen al jugador", todas)
	# Del ultimo peldano a la galeria: un salto con avance.
	# Desde el borde del ultimo peldano, como lo haria cualquiera.
	_poner(jugador, Vector2i(70, 7))
	await _esperar(0.2)
	Input.action_press("mover_der")
	_evento("saltar", true)
	await _esperar(0.6)
	_evento("saltar", false)
	await _esperar(0.4)
	Input.action_release("mover_der")
	_comprobar("del pozo se sube a la galeria alta (fila %.1f)" % (jugador.global_position.y / 16.0),
		jugador.is_on_floor() and absf(jugador.global_position.y - 5 * 16) < 2.0)

func _prueba_torreta_dispara() -> void:
	var jugador: Jugador = _jugador()
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(false)
	_quitar_patrullas()
	# Junto a la segunda cobertura: la torreta del techo del tramo B lo ve.
	_poner(jugador, Vector2i(42, 15))
	var antes: int = jugador.salud.salud_actual
	await _esperar(3.0)
	_comprobar("la torreta del techo dispara y hace dano (%d -> %d)" % [antes, jugador.salud.salud_actual],
		jugador.salud.salud_actual < antes)
	jugador.salud.revivir()

# --------------------------------------------------------------- Nivel 4 ----

func _prueba_fragil() -> void:
	_quitar_apertura()
	var jugador: Jugador = _jugador()
	jugador.salud.fijar_invulnerable(true)
	var fragil: PlataformaFragil = _nodo("Peligros/Fragil01") as PlataformaFragil
	jugador.global_position = fragil.global_position + Vector2(0.0, -2.0)
	jugador.velocity = Vector2.ZERO
	await _esperar(0.25)
	_comprobar("la plataforma fragil aguanta al principio", jugador.is_on_floor())
	# Se mira mientras cae: al tocar los pinchos vuelve al borde enseguida.
	var mas_bajo: float = jugador.global_position.y
	var transcurrido: float = 0.0
	while transcurrido < 1.6:
		await get_tree().physics_frame
		transcurrido += get_physics_process_delta_time()
		mas_bajo = maxf(mas_bajo, jugador.global_position.y)
	_comprobar("y despues cede (cae hasta y=%d)" % int(mas_bajo),
		mas_bajo > fragil.global_position.y + 8.0)
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(true)
	await _esperar(2.0)
	jugador.global_position = fragil.global_position + Vector2(0.0, -2.0)
	jugador.velocity = Vector2.ZERO
	await _esperar(0.2)
	_comprobar("y vuelve a su sitio", jugador.is_on_floor())

func _prueba_torreta_muere_y_pesa() -> void:
	var jugador: Jugador = _jugador()
	jugador.arma.obtener(load(TUBO))
	jugador.arma.equipar(0)
	_quitar_patrullas()
	var torreta: Torreta = _nodo("Enemigos/Torreta01") as Torreta
	var alma_antes: float = Alma.valor()
	var muertos_antes: int = EstadoJuego.estadistica("enemigos_eliminados")
	jugador.global_position = torreta.global_position + Vector2(-14.0, -1.0)
	jugador.mira = 1
	for i: int in 4:
		await _pulsar("atacar", 0.1)
		await _esperar(0.5)
	_comprobar("la torreta se destruye a golpes",
		EstadoJuego.estadistica("enemigos_eliminados") == muertos_antes + 1)
	_comprobar("y matarla con el tubo empuja el eje hacia lo humano (%+.3f)" % (Alma.valor() - alma_antes),
		Alma.valor() > alma_antes)

# ----------------------------------------------------------- Niveles 5-6 ----

func _prueba_dron() -> void:
	_quitar_apertura()
	_quitar_patrullas()
	var jugador: Jugador = _jugador()
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(false)
	var dron: Dron = _nodo("Enemigos/Dron01") as Dron
	var antes: int = jugador.salud.salud_actual
	jugador.global_position = Vector2(dron.global_position.x, 15 * 16 - 1)
	jugador.velocity = Vector2.ZERO
	await _esperar(2.0)
	_comprobar("el dron cae en picado y hace dano (%d -> %d)" % [antes, jugador.salud.salud_actual],
		jugador.salud.salud_actual < antes)
	# Aturdido en el suelo es cuando se le pega.
	jugador.salud.fijar_invulnerable(true)
	var muertos: int = EstadoJuego.estadistica("enemigos_eliminados")
	for i: int in 30:
		if not is_instance_valid(dron) or not dron.salud.esta_vivo():
			break
		jugador.global_position = dron.global_position + Vector2(-14.0, 12.0)
		jugador.mira = 1
		await _pulsar("atacar", 0.08)
		await _esperar(0.3)
	_comprobar("el dron se puede derribar a golpes",
		EstadoJuego.estadistica("enemigos_eliminados") > muertos)

func _prueba_prensa() -> void:
	_quitar_apertura()
	var jugador: Jugador = _jugador()
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(false)
	var prensa: Prensa = _nodo("Peligros/Prensa01") as Prensa
	jugador.global_position = Vector2(prensa.global_position.x, 15 * 16 - 1)
	jugador.velocity = Vector2.ZERO
	var antes: int = jugador.salud.salud_actual
	# Un ciclo entero mide 3.4 s: asi seguro que baja al menos una vez.
	await _esperar(3.6)
	_comprobar("la prensa aplasta al que se queda debajo (%d -> %d)" % [antes, jugador.salud.salud_actual],
		jugador.salud.salud_actual < antes)
	jugador.salud.revivir()

# --------------------------------------------------------------- Nivel 7 ----

func _prueba_arena() -> void:
	_quitar_apertura()
	var jugador: Jugador = _jugador()
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(true)
	var jefe: Custodio = _nodo("Arena/Custodio") as Custodio
	var entrada: Compuerta = _nodo("Arena/CompuertaEntrada") as Compuerta
	_comprobar("el jefe duerme hasta que entras", jefe.esta_dormido())
	_poner(jugador, Vector2i(41, 15))
	await _sostener("mover_der", 1.2, func() -> bool: return not entrada.abierta)
	_comprobar("al entrar se cierra la compuerta", not entrada.abierta)
	_comprobar("la musica calla durante la intimidacion", DirectorAudio.sonando_musica() == null)
	await _esperar(3.8)
	var musica: AudioStream = DirectorAudio.sonando_musica()
	_comprobar("tras la pausa suena la musica del jefe",
		musica != null and musica.resource_path.ends_with("musica_jefe.wav"))
	var camara: Camera2D = jugador.get_node("Camara") as Camera2D
	_comprobar("la camara se encierra en la arena (%d-%d)" % [camara.limit_left, camara.limit_right],
		camara.limit_left == 40 * 16 and camara.limit_right == 64 * 16)
	jefe.salud.aplicar_dano(11, Vector2.RIGHT, self)
	await _esperar(0.1)
	_comprobar("a dos tercios pasa a la fase 2", jefe.fase == 2)
	await _esperar(2.2)
	jefe.salud.aplicar_dano(10, Vector2.RIGHT, self)
	await _esperar(0.1)
	_comprobar("a un tercio pasa a la fase 3", jefe.fase == 3)
	await _esperar(2.2)

## El rayo pasa por encima de quien se agacha y alcanza a quien sigue de pie.
func _prueba_rayo() -> void:
	var jugador: Jugador = _jugador()
	var jefe: Custodio = _nodo("Arena/Custodio") as Custodio
	jugador.salud.fijar_invulnerable(false)
	jefe.salud.fijar_invulnerable(true)
	for agachado: bool in [true, false]:
		jugador.salud.revivir()
		await _esperar(1.0)
		_poner(jugador, Vector2i(44, 15))
		jefe.global_position.x = 58 * 16
		# Lo que quede de un ataque anterior (ondas, chatarra) no cuenta aqui.
		jefe._limpiar_efimeros()
		for nodo: Node in get_tree().current_scene.get_children():
			if nodo is Proyectil:
				nodo.queue_free()
		jefe._cambiar(Custodio.Modo.ACECHO)
		await _esperar(0.1)
		jugador.salud.revivir()
		if agachado:
			Input.action_press("agachar")
		var antes: int = jugador.salud.salud_actual
		jefe._ataque = Custodio.Ataque.RAYO
		jefe._orientar(-1)
		jefe._cambiar(Custodio.Modo.AVISO)
		await _esperar_hasta(func() -> bool: return jefe._modo == Custodio.Modo.RECUPERA, 3.0)
		Input.action_release("agachar")
		if agachado:
			_comprobar("agachado, el rayo pasa por encima (%d -> %d)" % [antes, jugador.salud.salud_actual],
				jugador.salud.salud_actual == antes)
		else:
			_comprobar("de pie, el rayo alcanza (%d -> %d)" % [antes, jugador.salud.salud_actual],
				jugador.salud.salud_actual < antes)
	jefe.salud.fijar_invulnerable(false)

func _prueba_muerte_en_arena() -> void:
	var jugador: Jugador = _jugador()
	var jefe: Custodio = _nodo("Arena/Custodio") as Custodio
	var entrada: Compuerta = _nodo("Arena/CompuertaEntrada") as Compuerta
	jugador.salud.matar(self)
	await _esperar(0.3)
	_comprobar("morir en la arena duerme al jefe con la vida llena",
		jefe.esta_dormido() and jefe.salud.salud_actual == jefe.salud.salud_maxima and jefe.fase == 1)
	_comprobar("y reabre la compuerta", entrada.abierta)
	var camara: Camera2D = jugador.get_node("Camara") as Camera2D
	_comprobar("y suelta la camara", camara.limit_right > 64 * 16)

func _prueba_derrota() -> void:
	var jugador: Jugador = _jugador()
	var jefe: Custodio = _nodo("Arena/Custodio") as Custodio
	var salida: Compuerta = _nodo("Arena/CompuertaSalida") as Compuerta
	jugador.salud.fijar_invulnerable(true)
	_poner(jugador, Vector2i(41, 15))
	await _sostener("mover_der", 1.0)
	await _esperar(3.6)
	var entradas_antes: int = EstadoJuego.entradas.size()
	jefe.salud.fijar_invulnerable(false)
	# Golpes reales con el tubo, no aplicar_dano: asi tambien pasa por Alma.
	for i: int in 40:
		if not jefe.salud.esta_vivo():
			break
		jefe.salud.fijar_invulnerable(false)
		jefe.salud.aplicar_dano(3, Vector2.RIGHT, self)
		await _esperar(0.05)
	await _esperar_hasta(func() -> bool: return salida.abierta, 8.0)
	_comprobar("al derrotarlo se abre la salida", salida.abierta)
	_comprobar("y el diario escribe su entrada", EstadoJuego.entradas.size() == entradas_antes + 1)
	_comprobar("y queda marcado como derrotado", EstadoJuego.bandera(ArenaJefe.BANDERA))

func _prueba_final() -> void:
	await _esperar(1.4)
	var jugador: Jugador = _jugador()
	_poner(jugador, Vector2i(84, 15))
	await _sostener("mover_der", 4.0, func() -> bool: return _escena() == FINAL)
	await _esperar(3.5)
	_comprobar("el monitor lleva al final", _escena() == FINAL)
	var texto: Label = get_tree().current_scene.get_node_or_null("Texto") as Label
	_comprobar("el final escribe su primera linea", texto != null and not texto.text.is_empty())

## El arreglo de Nivel._enter_tree(): una partida guardada en ruta maquina tiene
## que retomarse con la paleta de la ruta maquina, el diario lleno y las vendas
## ya cogidas fuera del suelo.
func _prueba_continuar_restaura_ruta() -> void:
	await _esperar(0.5)
	EstadoJuego.reiniciar()
	EstadoJuego.agregar_entrada("prueba", "una entrada", "prueba")
	EstadoJuego.fijar_bandera(EstadoJuego.clave_recogido(NIVEL_3, "venda_15"), true)
	Alma.cargar(-0.6)
	Guardado.guardar("nivel_03_crt_01", {
		"salud": 5, "vendas": 2, "armas": ["tubo_metal"], "arma_equipada": "tubo_metal",
		"nivel": NIVEL_3,
	})
	EstadoJuego.reiniciar()
	Alma.cargar(0.0)
	CargadorEscenas.continuar_partida = true
	CargadorEscenas.cambiar_a(Guardado.nivel_guardado())
	await _esperar_hasta(func() -> bool: return _escena() == NIVEL_3, 6.0)
	await _esperar(0.6)
	var paleta: PaletaAlma = _nodo("PaletaAlma") as PaletaAlma
	var peso: float = float((paleta.lienzo.material as ShaderMaterial).get_shader_parameter("peso_maquina"))
	_comprobar("seguir donde estaba restaura la paleta de la ruta (peso_maquina=%.2f)" % peso,
		is_equal_approx(peso, 1.0))
	_comprobar("y las entradas del diario (%d)" % EstadoJuego.entradas.size(),
		EstadoJuego.entradas.size() == 1)
	_comprobar("y la venda ya cogida no vuelve a aparecer",
		_nodo("Recogibles/venda_15") == null)

# ------------------------------------------------------------- Utilidades ----

func _montar(ruta: String) -> void:
	var nivel: Node = (load(ruta) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(nivel)
	get_tree().set_deferred("current_scene", nivel)

func _prueba_salida(desde: Vector2i, destino: String, texto: String) -> void:
	var jugador: Jugador = _jugador()
	jugador.salud.fijar_invulnerable(true)
	_poner(jugador, desde)
	await _sostener("mover_der", 4.0, func() -> bool: return _escena() == destino)
	await _esperar(0.8)
	_comprobar(texto, _escena() == destino)

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

## Las pruebas de torreta no pueden dejar que un enemigo de patrulla haga el dano.
func _quitar_patrullas() -> void:
	for nodo: Node in get_tree().get_nodes_in_group("enemigos"):
		if nodo is EnemigoPatrulla:
			nodo.queue_free()

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

## Pulsa con un evento de verdad y no solo con Input.action_press: el salto se
## lee en _unhandled_input, y action_press no genera ningun evento.
func _pulsar(accion: String, segundos: float) -> void:
	_evento(accion, true)
	await _esperar(segundos)
	_evento(accion, false)

func _evento(accion: String, pulsada: bool) -> void:
	var evento: InputEventAction = InputEventAction.new()
	evento.action = accion
	evento.pressed = pulsada
	Input.parse_input_event(evento)

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
