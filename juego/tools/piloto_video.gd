# Herramienta: juega la demo desde el menu hasta derrotar al Custodio, para grabarla
# con el Movie Maker. Pulsa acciones reales del InputMap: nunca mueve al jugador a
# mano, asi que lo que se ve es lo que el juego permite. Lo graba
# herramientas/grabar_jugabilidad.py.
#
#   godot --path juego --fixed-fps 60 --disable-vsync res://tools/piloto_video.tscn   (ensayo)
#
# Si se queda sin corazones y sin vendas se le rellenan para no cortar la toma: lo
# cuenta en RESCATES al terminar. Respalda user://partida.json en disco y lo restaura.
extends Node

const MENU: String = "res://ui/menu/menu_principal.tscn"
const PACIENCIA: float = 25.0
const TOPE: float = 1500.0
const RUTA_RESPALDO: String = "user://partida.respaldo_piloto.json"

var _ruta: Array[Dictionary] = []
var _paso: int = 0
var _escena_ruta: String = ""
var _jugador: Jugador = null
var _pulsos: Dictionary = {}
var _quiere: Dictionary = {}
var _reloj_paso: float = 0.0
var _estancado: float = 0.0
var _traza: bool = false
var _marca_avance: Vector2 = Vector2.ZERO
var _total: float = 0.0
var _pos_previa: Vector2 = Vector2.ZERO
var _rescates: int = 0
var _caidas: int = 0
var _arma_deseada: String = ""
var _espera_arma: float = 0.0
var _ignorados: Dictionary = {}
var _pelea_con: Node = null
var _pelea_t: float = 0.0
var _saltando: bool = false
var _inicio_nivel: float = 0.0
var _fin: float = -1.0
var _menu_listo: float = 7.0
var _jefe: Custodio = null
var _pelea_jefe_desde: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El respaldo va a disco: en memoria se perdia si cerraban el piloto a medias,
	# porque DESPERTAR borra la partida. Si quedo uno de una corrida cortada, ese es
	# el bueno y se restaura primero.
	_restaurar_respaldo_pendiente()
	if Guardado.hay_partida():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(Guardado.RUTA_PARTIDA),
			ProjectSettings.globalize_path(RUTA_RESPALDO))
	# Para ensayar un tramo sin jugar los anteriores:  -- --desde=res://levels/... --traza
	var inicio: String = MENU
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--desde="):
			inicio = arg.trim_prefix("--desde=")
		elif arg == "--traza":
			_traza = true
	var escena: Node = (load(inicio) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(escena)
	get_tree().set_deferred("current_scene", escena)

func _physics_process(delta: float) -> void:
	_total += delta
	_quiere = {}
	if _total > TOPE:
		_terminar("TIEMPO AGOTADO", 1)
		return
	var escena: String = _escena()
	if escena == MENU:
		_menu_listo -= delta
		if _menu_listo <= 0.0:
			_menu_listo = 9999.0
			(get_tree().current_scene.get_node("Interfaz/Opciones/Jugar") as Button).pressed.emit()
		return
	if not escena.begins_with("res://levels/"):
		return
	if escena != _escena_ruta:
		_entrar_en_nivel(escena)
		return
	if _jugador != null and is_instance_valid(_jugador):
		_conducir(delta)
	_aplicar(delta)

func _entrar_en_nivel(escena: String) -> void:
	_soltar_todo()
	_escena_ruta = escena
	_paso = 0
	_reloj_paso = 0.0
	_estancado = 0.0
	_ignorados = {}
	_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	_ruta = _ruta_de(escena)
	_jefe = get_tree().current_scene.get_node_or_null("Arena/Custodio") as Custodio
	_inicio_nivel = _total
	print("[%6.1f s] entra en %s (salud %d, vendas %d, arsenal %d, alma %+.2f, eliminados %d)" % [
		_total, escena.get_file(), _jugador.salud.salud_actual, _jugador.vendas,
		_jugador.arma.arsenal.size(), Alma.valor(), EstadoJuego.estadistica("enemigos_eliminados")])

# ---------------------------------------------------------------- rutas ----

func _ir(tile: int, extra: Dictionary = {}) -> Dictionary:
	var paso: Dictionary = {"a": "ir", "t": tile}
	paso.merge(extra)
	return paso

func _saltar_a(tile: int, fila: int) -> Dictionary:
	return {"a": "saltar_a", "t": tile, "fila": fila}

func _crt(tile: int) -> Dictionary:
	return {"a": "crt", "t": tile}

func _arma(id: String) -> Dictionary:
	return {"a": "arma", "id": id}

func _esperar_que(cond: Callable) -> Dictionary:
	return {"a": "esperar", "cond": cond}

func _nodo(ruta: String) -> Node:
	return get_tree().current_scene.get_node_or_null(ruta)

## Pasa un arco o una prensa: espera delante hasta que sea seguro y cruza corriendo.
func _cruzar_arco(nombre: String, tile: int) -> Array[Dictionary]:
	var arco: ArcoElectrico = _nodo("Peligros/" + nombre) as ArcoElectrico
	return [_ir(tile - 3), _esperar_que(func() -> bool:
		return arco._fase == ArcoElectrico.Fase.APAGADO and arco._reloj > 0.9),
		_ir(tile + 2, {"correr": true})]

func _cruzar_prensa(nombre: String, tile: int) -> Array[Dictionary]:
	var prensa: Prensa = _nodo("Peligros/" + nombre) as Prensa
	return [_ir(tile - 2), _esperar_que(func() -> bool:
		return prensa._fase == Prensa.Fase.SUBIENDO or prensa._fase == Prensa.Fase.ABAJO \
			or (prensa._fase == Prensa.Fase.ARRIBA and prensa._reloj > 0.7)),
		_ir(tile + 2, {"correr": true})]

func _ruta_de(escena: String) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	match escena.get_file():
		"nivel_01.tscn":
			r = [_ir(34), _crt(34), _arma("tubo_metal"), _ir(81), {"a": "diario"}, _ir(143, {"fila_alta": true}), {"a": "salir"}]
		"nivel_02.tscn":
			var mc: Node2D = _nodo("Peligros/Montacargas01") as Node2D
			var fp: Node2D = _nodo("Peligros/Montacargas02") as Node2D
			r = [_ir(21), _arma("pistola_reciclada"), _ir(56)]
			r.append_array(_cruzar_arco("Arco01", 62))
			r.append_array(_cruzar_arco("Arco02", 69))
			r.append_array(_cruzar_arco("Arco03", 75))
			r.append_array([_ir(85),
				_esperar_que(func() -> bool: return mc.position.y >= 238.0),
				_ir(89, {"sin_pelea": true}),
				_esperar_que(func() -> bool: return mc.position.y <= 113.0),
				_ir(102),
				_esperar_que(func() -> bool: return fp.position.x <= 1690.0),
				_ir(105, {"sin_pelea": true}),
				_esperar_que(func() -> bool: return fp.position.x >= 1750.0),
				_ir(112, {"sin_pelea": true}), _ir(164)])
			r.append_array(_cruzar_arco("Arco04", 167))
			r.append({"a": "salir"})
		"nivel_03.tscn":
			r = [_arma("lanza_plasma"), _ir(46), {"a": "agachado", "t": 60},
				_saltar_a(63, 13), _saltar_a(68, 11), _saltar_a(63, 9), _saltar_a(69, 7),
				_saltar_a(73, 5), _ir(87)]
			r.append_array(_cruzar_arco("Arco01", 90))
			r.append_array([_ir(150), _crt(156), {"a": "salir"}])
		"nivel_04.tscn":
			r = [_arma("tubo_metal"), _ir(14), _saltar_a(18, 9), _saltar_a(21, 9), _ir(50),
				_saltar_a(54, 7), _saltar_a(58, 6), _saltar_a(62, 6), _saltar_a(64, 7), _ir(115),
				_saltar_a(119, 9), _saltar_a(122, 9), _ir(147), {"a": "salir"}]
		"nivel_05.tscn":
			r = [_arma("pistola_reciclada"), {"a": "salir"}]
		"nivel_06.tscn":
			r = [_arma("emisor_radiacion"), _ir(20)]
			r.append_array(_cruzar_prensa("Prensa01", 24))
			r.append_array(_cruzar_prensa("Prensa02", 30))
			r.append_array(_cruzar_prensa("Prensa03", 36))
			r.append_array([_ir(92)])
			r.append_array(_cruzar_prensa("Prensa04", 96))
			r.append_array(_cruzar_prensa("Prensa05", 101))
			r.append_array(_cruzar_prensa("Prensa06", 106))
			r.append_array(_cruzar_prensa("Prensa07", 111))
			r.append({"a": "salir"})
		"nivel_07.tscn":
			r = [_ir(16), _crt(22), _ir(47, {"sin_pelea": true}), {"a": "jefe"}]
	return r

# ------------------------------------------------------------ conduccion ----

func _conducir(delta: float) -> void:
	var pos: Vector2 = _jugador.global_position
	# Los pinchos lo devuelven al borde: la ruta retrocede hasta ese tile.
	if pos.distance_to(_pos_previa) > 48.0 and _reloj_paso > 0.05:
		_caidas += 1
		print("   caida %d en %s, paso %d %s, vuelve al tile %d" % [_caidas, _escena_ruta.get_file(),
			_paso, str(_ruta[mini(_paso, _ruta.size() - 1)]), int(pos.x / 16.0)])
		if _caidas > 12:
			_terminar("DEMASIADAS CAIDAS", 1)
			return
		var tile_actual: int = int(pos.x / 16.0)
		for i: int in _ruta.size():
			if _ruta[i].has("t") and int(_ruta[i]["t"]) > tile_actual:
				_paso = i
				break
		_reloj_paso = 0.0
	_pos_previa = pos
	if _traza and _paso < _ruta.size() and str(_ruta[_paso]["a"]) == "saltar_a":
		print("   %.2f paso %d x=%.1f y=%.1f v=%s suelo=%s estado=%s salto=%s" % [_total, _paso, pos.x, pos.y,
			_jugador.velocity.round(), _jugador.is_on_floor(), _jugador.maquina.nombre_actual(), Input.is_action_pressed("saltar")])
	if _paso >= _ruta.size():
		return
	var paso: Dictionary = _ruta[_paso]
	# Sin fisica puede estar en la apertura (toca esperar) o sentado en un CRT. Ahi
	# hay que seguir: si no, nunca pulsaba E y se quedaba sentado para siempre.
	if not _jugador.is_physics_processing() and str(paso["a"]) != "crt":
		return
	_reloj_paso += delta
	if not _jugador.is_physics_processing():
		_hacer(paso, delta)
		return
	_cuidarse()
	_gestionar_arma(delta)
	var con_pelea: bool = not paso.get("sin_pelea", false) and str(paso["a"]) in ["ir", "salir", "esperar", "crt"]
	if con_pelea and _pelear(delta):
		return
	if _hacer(paso, delta):
		_paso += 1
		_reloj_paso = 0.0
		_estancado = 0.0
		return
	# Atascado es no moverse, no tardar: un tramo largo con peleas puede durar mucho.
	_estancado += delta
	if pos.distance_to(_marca_avance) > 16.0:
		_marca_avance = pos
		_estancado = 0.0
	if _estancado > PACIENCIA and str(paso["a"]) != "jefe":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://../capturas/piloto_atasco.png"))
		_terminar("ATASCADO en %s paso %d %s (tile %d fila %d)" % [
			_escena_ruta.get_file(), _paso, str(paso.get("a")), int(pos.x / 16.0), _fila()], 1)

func _hacer(paso: Dictionary, delta: float) -> bool:
	match str(paso["a"]):
		"ir":
			return _andar_hasta(int(paso["t"]), paso.get("correr", false))
		"salir":
			_avanzar(1, false)
			return false
		"esperar":
			return bool((paso["cond"] as Callable).call())
		"arma":
			_arma_deseada = str(paso["id"])
			return true
		"agachado":
			_querer("agachar")
			_querer("mover_der")
			return _jugador.global_position.x >= int(paso["t"]) * 16 + 4
		"saltar_a":
			return _hacer_salto(int(paso["t"]), int(paso["fila"]))
		"crt":
			return _hacer_crt(int(paso["t"]))
		"diario":
			return _hacer_diario()
		"jefe":
			return _pelear_jefe(delta)
	return true

func _andar_hasta(tile: int, correr: bool) -> bool:
	var meta: float = tile * 16 + 8.0
	var dif: float = meta - _jugador.global_position.x
	if absf(dif) <= 6.0:
		return true
	_avanzar(1 if dif > 0.0 else -1, correr)
	return false

## Anda en una direccion con las reglas del piloto del nivel 1.
func _avanzar(dir: int, correr: bool) -> void:
	_querer("mover_der" if dir > 0 else "mover_izq")
	var tile: int = int(floor(_jugador.global_position.x / 16.0))
	var fila: int = _fila()
	var hueco_cerca: int = _hueco(tile, fila, dir)
	var hueco_lejos: int = maxi(hueco_cerca, _hueco(tile + dir, fila, dir))
	if correr or hueco_lejos >= 3:
		_querer("correr")
	if _jugador.is_on_floor():
		var mitad: float = fmod(_jugador.global_position.x, 16.0)
		var al_borde: bool = hueco_cerca > 0 and (mitad >= 8.0 if dir > 0 else mitad < 8.0)
		if al_borde or _escalon(tile, fila, dir) or _jugador.is_on_wall():
			_pulsar("saltar", 0.4)

func _hueco(tile: int, fila: int, dir: int) -> int:
	var vacios: int = 0
	for i: int in range(1, 6):
		if _hay_suelo(tile + dir * i, fila):
			break
		vacios += 1
	return vacios

func _hay_suelo(tile: int, fila: int) -> bool:
	for dy: int in range(0, 5):
		if _solido(tile, fila + dy):
			return true
	return false

func _escalon(tile: int, fila: int, dir: int) -> bool:
	for dy: int in range(1, 3):
		if _solido(tile + dir, fila - dy) and not _solido(tile + dir, fila - dy - 1):
			return true
	return false

func _solido(x: int, y: int) -> bool:
	var terreno: TileMapLayer = get_tree().current_scene.get_node("Terreno") as TileMapLayer
	var atlas: Vector2i = terreno.get_cell_atlas_coords(Vector2i(x, y))
	return terreno.get_cell_source_id(Vector2i(x, y)) != -1 and atlas != ConstructorNivel.INT_PASARELA

func _fila() -> int:
	return int(floor(_jugador.global_position.y / 16.0))

## Salta hacia una plataforma: se acerca, salta y frena en el aire sobre el centro.
func _hacer_salto(tile: int, fila_suelo: int) -> bool:
	var meta: float = tile * 16 + 8.0
	var dif: float = meta - _jugador.global_position.x
	var suelo: bool = _jugador.is_on_floor()
	# Solo ha llegado si esta CERCA de la meta: el punto de partida puede estar a la
	# misma altura que el destino (cruzar un abismo llano).
	if suelo and absf(_jugador.global_position.y - fila_suelo * 16) < 3.0 and absf(dif) < 24.0:
		_saltando = false
		return true
	if suelo and not _fragiles_listas(meta):
		return false
	if absf(dif) > 3.0:
		_querer("mover_der" if dif > 0.0 else "mover_izq")
		_querer("correr")
	if suelo and absf(dif) < 76.0 and _fragiles_listas(meta):
		_pulsar("saltar", 0.45)
	return false

## Una plataforma fragil tarda en volver. Desde tierra firme se espera a verla,
## como haria cualquiera; subido en otra no, porque esa tambien se esta cayendo.
func _fragiles_listas(meta: float) -> bool:
	var peligros: Node = _nodo("Peligros")
	if peligros == null:
		return true
	var x: float = _jugador.global_position.x
	var sobre_fragil: bool = false
	var en_camino: bool = true
	for hijo: Node in peligros.get_children():
		var fragil: PlataformaFragil = hijo as PlataformaFragil
		if fragil == null:
			continue
		var fx: float = fragil.global_position.x
		if absf(fx - x) <= 22.0 and absf(fragil.global_position.y - _jugador.global_position.y) < 4.0:
			sobre_fragil = true
		elif fx >= minf(x, meta) - 16.0 and fx <= maxf(x, meta) + 16.0 \
				and fragil._fase != PlataformaFragil.Fase.FIRME:
			en_camino = false
	return sobre_fragil or en_camino

func _hacer_crt(tile: int) -> bool:
	var meta: float = tile * 16 - 14.0
	var terminal: TerminalCRT = _terminal_en(tile)
	if terminal == null:
		return true
	if not terminal.activa and _reloj_paso < 30.0 and not _paso_crt_hecho(terminal):
		var dif: float = meta - _jugador.global_position.x
		if absf(dif) > 6.0:
			_avanzar(1 if dif > 0.0 else -1, false)
			return false
		if _jugador.is_on_floor() and terminal._jugador != null and not _pulsos.has("interactuar"):
			_pulsar("interactuar", 0.1)
			_reloj_paso = 0.0
		return false
	if terminal.activa:
		terminal.set_meta("vista", true)
		if _reloj_paso > 3.5 and not _pulsos.has("interactuar"):
			_pulsar("interactuar", 0.1)
		return false
	return true

func _paso_crt_hecho(terminal: TerminalCRT) -> bool:
	return terminal.has_meta("vista")

func _terminal_en(tile: int) -> TerminalCRT:
	for hijo: Node in get_tree().current_scene.get_node("Terminales").get_children():
		if absf((hijo as Node2D).global_position.x - tile * 16) < 8.0:
			return hijo as TerminalCRT
	return null

func _hacer_diario() -> bool:
	var diario: Diario = _nodo("Diario") as Diario
	# Se abre por Estadisticas: la Bitacora todavia tiene textos [PENDIENTE].
	if _reloj_paso < 0.2:
		return false
	if not diario.visible and _reloj_paso < 1.0:
		diario.pestanas.current_tab = 2
		_pulsar("diario", 0.1)
		_reloj_paso = 1.0
		return false
	if _reloj_paso > 4.0 and diario.visible and not _pulsos.has("diario"):
		_pulsar("diario", 0.1)
	return _reloj_paso > 4.0 and not diario.visible

# --------------------------------------------------------------- combate ----

func _cuidarse() -> void:
	var salud: ComponenteSalud = _jugador.salud
	if salud.salud_actual <= 3 and _jugador.vendas > 0 and not _pulsos.has("curar"):
		_pulsar("curar", 0.1)
	elif salud.salud_actual <= 2 and _jugador.vendas == 0:
		salud.curar(3)
		_rescates += 1

func _gestionar_arma(delta: float) -> void:
	_espera_arma -= delta
	var actual: ArmaData = _jugador.arma.arma_actual()
	if actual == null or _arma_deseada.is_empty() or actual.id == _arma_deseada or _espera_arma > 0.0:
		return
	var tiene: bool = false
	for arma: ArmaData in _jugador.arma.arsenal:
		tiene = tiene or arma.id == _arma_deseada
	if tiene:
		_pulsar("cambiar_arma", 0.05)
		_espera_arma = 0.25

func _pelear(delta: float) -> bool:
	var actual: ArmaData = _jugador.arma.arma_actual()
	if actual == null:
		return false
	var alcance: float = 120.0 if actual.es_a_distancia else 30.0
	var mas_cerca: Node2D = null
	var mejor: float = 90.0 if actual.es_a_distancia else 64.0
	for nodo: Node in get_tree().get_nodes_in_group("enemigos"):
		var enemigo: Node2D = nodo as Node2D
		var salud: ComponenteSalud = enemigo.get_node_or_null("Salud") as ComponenteSalud
		if salud == null or not salud.esta_vivo() or _ignorados.has(enemigo):
			continue
		var dx: float = absf(enemigo.global_position.x - _jugador.global_position.x)
		var dy: float = absf(enemigo.global_position.y - _jugador.global_position.y)
		if dx < mejor and dy < 22.0:
			mejor = dx
			mas_cerca = enemigo
	if mas_cerca == null:
		_pelea_con = null
		return false
	if mas_cerca != _pelea_con:
		_pelea_con = mas_cerca
		_pelea_t = 0.0
	_pelea_t += delta
	if _pelea_t > 9.0:
		_ignorados[mas_cerca] = true
		return false
	var dif: float = mas_cerca.global_position.x - _jugador.global_position.x
	var lado: int = 1 if dif > 0.0 else -1
	var patrulla: EnemigoPatrulla = mas_cerca as EnemigoPatrulla
	if patrulla != null and patrulla._modo == EnemigoPatrulla.Modo.EMBESTIDA and absf(dif) < 34.0 \
			and _jugador.puede_rodar():
		_querer("mover_der" if lado > 0 else "mover_izq")
		_pulsar("rodar", 0.08)
		return true
	if absf(dif) > alcance:
		# Con la logica de andar: si el enemigo esta un escalon mas arriba hay que saltar.
		_avanzar(lado, false)
	elif _jugador.mira != lado:
		_querer("mover_der" if lado > 0 else "mover_izq")
	if absf(dif) <= alcance and _jugador.mira == lado and _jugador.puede_atacar() and not _pulsos.has("atacar"):
		_pulsar("atacar", 0.06)
	return true

func _pelear_jefe(_delta: float) -> bool:
	if _fin < 0.0 and not is_instance_valid(_jefe):
		return true
	_arma_preferida_jefe()
	if _jefe._modo == Custodio.Modo.MUERTO:
		if _fin < 0.0:
			_fin = _total
			print("[%6.1f s] el Custodio cae (fase %d, pelea de %.1f s)" % [_total, _jefe.fase, _total - _pelea_jefe_desde])
		if _total - _fin > 9.0:
			_terminar("COMPLETADO", 0)
		return false
	if _jefe._modo == Custodio.Modo.DORMIDO:
		_querer("mover_der")
		return false
	if _jefe._modo == Custodio.Modo.DESPERTAR:
		_pelea_jefe_desde = _total
		return false
	var dif: float = _jefe.global_position.x - _jugador.global_position.x
	var lado: int = 1 if dif > 0.0 else -1
	var dist: float = absf(dif)
	var ataque: Custodio.Ataque = _jefe._ataque
	var avisando: bool = _jefe._modo == Custodio.Modo.AVISO or _jefe._modo == Custodio.Modo.GOLPE
	# Rayo: agacharse y aguantar.
	if avisando and ataque == Custodio.Ataque.RAYO:
		_querer("agachar")
		return false
	# Ondas: saltar la que llega.
	for onda: Node in get_tree().get_nodes_in_group("onda_choque"):
		var dx: float = absf((onda as Node2D).global_position.x - _jugador.global_position.x)
		if dx < 34.0 and _jugador.is_on_floor():
			_pulsar("saltar", 0.45)
	# Chatarra: apartarse de la marca que tiene encima.
	if avisando and ataque == Custodio.Ataque.LLUVIA:
		for marca: float in _jefe._marcas:
			if absf(marca - _jugador.global_position.x) < 20.0:
				var huida: int = 1 if marca < _jugador.global_position.x else -1
				if _jugador.global_position.x < _jefe.limite_izq + 40.0:
					huida = 1
				elif _jugador.global_position.x > _jefe.limite_der - 40.0:
					huida = -1
				_querer("mover_der" if huida > 0 else "mover_izq")
				_querer("correr")
				return false
	# Zarpazo o demasiado cerca: rodar atravesandolo.
	if dist < 46.0 and _jugador.puede_rodar() and _jefe._modo != Custodio.Modo.RECUPERA:
		_querer("mover_der" if lado > 0 else "mover_izq")
		_pulsar("rodar", 0.08)
		return false
	# Distancia media y a disparar. Durante la recuperacion, sin miedo.
	if dist > 110.0 or _jugador.mira != lado:
		_querer("mover_der" if lado > 0 else "mover_izq")
	elif dist < 60.0 and _jefe._modo != Custodio.Modo.RECUPERA:
		_querer("mover_izq" if lado > 0 else "mover_der")
	if _jugador.mira == lado and _jugador.puede_atacar() and not _pulsos.has("atacar"):
		_pulsar("atacar", 0.06)
	return false

func _arma_preferida_jefe() -> void:
	# La pistola primero: con la radiacion el jefe cae antes de enseñar sus fases.
	for id: String in ["pistola_reciclada", "lanza_plasma", "emisor_radiacion", "tubo_metal"]:
		for arma: ArmaData in _jugador.arma.arsenal:
			if arma.id == id:
				_arma_deseada = id
				return

# --------------------------------------------------------------- entrada ----

func _querer(accion: String) -> void:
	_quiere[accion] = true

func _pulsar(accion: String, segundos: float) -> void:
	_pulsos[accion] = maxf(float(_pulsos.get(accion, 0.0)), segundos)

func _aplicar(delta: float) -> void:
	for accion: String in _pulsos.keys():
		_quiere[accion] = true
		_pulsos[accion] = float(_pulsos[accion]) - delta
		if float(_pulsos[accion]) <= 0.0:
			_pulsos.erase(accion)
	for accion: String in ["mover_izq", "mover_der", "agachar", "saltar", "correr", "rodar",
			"atacar", "curar", "interactuar", "diario", "cambiar_arma"]:
		var quiere: bool = _quiere.has(accion)
		if quiere != Input.is_action_pressed(accion):
			var evento: InputEventAction = InputEventAction.new()
			evento.action = accion
			evento.pressed = quiere
			Input.parse_input_event(evento)

func _soltar_todo() -> void:
	_pulsos = {}
	_quiere = {}
	_aplicar(0.0)

func _escena() -> String:
	var actual: Node = get_tree().current_scene
	return actual.scene_file_path if actual != null else ""

func _terminar(motivo: String, codigo: int) -> void:
	print("[%6.1f s] %s" % [_total, motivo])
	print("RESCATES: %d  CAIDAS: %d  muertes: %d  eliminados: %d  alma: %+.2f" % [
		_rescates, _caidas, EstadoJuego.estadistica("muertes"),
		EstadoJuego.estadistica("enemigos_eliminados"), Alma.valor()])
	Guardado.borrar()
	_restaurar_respaldo_pendiente()
	set_physics_process(false)
	get_tree().quit(codigo)

func _restaurar_respaldo_pendiente() -> void:
	if not FileAccess.file_exists(RUTA_RESPALDO):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(RUTA_RESPALDO),
		ProjectSettings.globalize_path(Guardado.RUTA_PARTIDA))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_RESPALDO))
