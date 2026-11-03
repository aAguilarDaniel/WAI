# Herramienta: prueba de humo del paso entre niveles y de las mecanicas nuevas
# del nivel 2. Juega sola los momentos criticos y dice PASA o FALLA en cada uno.
#
#   godot --path juego res://tools/prueba_nivel_02.tscn
#
# NO con --headless: la TerminalCRT necesita renderizador.
#
# La partida guardada del usuario (user://partida.json) se respalda al empezar y
# se restaura al terminar: la prueba de "Seguir donde estaba" escribe encima.
extends Node

const NIVEL_1: String = "res://levels/nivel_01/nivel_01.tscn"
const NIVEL_2: String = "res://levels/nivel_02/nivel_02.tscn"
const FIN: String = "res://ui/fin/fin_demo.tscn"

var _fallos: int = 0
var _respaldo: String = ""
var _habia_partida: bool = false

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	_habia_partida = Guardado.hay_partida()
	if _habia_partida:
		_respaldo = FileAccess.get_file_as_string(Guardado.RUTA_PARTIDA)
	# La prueba no puede ser la escena actual: cambiar de escena la borraria.
	# Monta el nivel 1 como escena actual y se queda colgada de la raiz.
	var nivel: Node = (load(NIVEL_1) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(nivel)
	get_tree().set_deferred("current_scene", nivel)
	_correr.call_deferred()

func _correr() -> void:
	await _esperar(0.3)
	await _prueba_portal()
	await _prueba_montacargas()
	await _prueba_plataforma_foso()
	await _prueba_arco()
	await _prueba_salida()
	await _prueba_continuar()
	_restaurar_partida()
	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

# --------------------------------------------------------------- Pruebas ----

func _prueba_portal() -> void:
	var jugador: Jugador = _jugador()
	_quitar_apertura()
	jugador.arma.obtener(load("res://systems/weapons/data/tubo_metal.tres"))
	jugador.vendas = 3
	jugador.global_position = Vector2(205 * 16, 5 * 16 - 1)
	await _sostener("mover_der", 3.5, func() -> bool: return _escena() == NIVEL_2)
	await _esperar(0.6)
	var nuevo: Jugador = _jugador()
	var ids: Array = nuevo.instantanea().get("armas", []) if nuevo != null else []
	_comprobar("el portal del edificio lleva al nivel 2", _escena() == NIVEL_2)
	_comprobar("el jugador conserva el tubo al cruzar", ids.has("tubo_metal"))
	_comprobar("el jugador conserva las vendas al cruzar", nuevo != null and nuevo.vendas == 3)

func _prueba_montacargas() -> void:
	_quitar_apertura()
	var jugador: Jugador = _jugador()
	var montacargas: Node2D = _nodo("Peligros/Montacargas01") as Node2D
	await _esperar_hasta(func() -> bool: return montacargas.position.y >= 239.5, 8.0)
	jugador.global_position = Vector2(montacargas.position.x, montacargas.position.y - 1.0)
	jugador.velocity = Vector2.ZERO
	await _esperar_hasta(func() -> bool: return montacargas.position.y <= 112.5, 8.0)
	await _esperar(0.1)
	_comprobar("el montacargas sube al jugador a la galeria (y=%d)" % int(jugador.global_position.y),
		jugador.global_position.y <= 114.0)
	await _sostener("mover_der", 0.8)
	_comprobar("se baja del montacargas a la galeria (x=%d)" % int(jugador.global_position.x),
		jugador.global_position.x > 1460.0 and jugador.global_position.y <= 114.0)

func _prueba_plataforma_foso() -> void:
	var jugador: Jugador = _jugador()
	var plataforma: Node2D = _nodo("Peligros/Montacargas02") as Node2D
	await _esperar_hasta(func() -> bool: return plataforma.position.x <= 1688.5, 8.0)
	jugador.global_position = Vector2(plataforma.position.x, 111.0)
	jugador.velocity = Vector2.ZERO
	await _esperar_hasta(func() -> bool: return plataforma.position.x >= 1751.5, 8.0)
	await _esperar(0.1)
	_comprobar("la plataforma cruza al jugador sobre el foso (x=%d)" % int(jugador.global_position.x),
		jugador.global_position.x > 1730.0 and jugador.global_position.y <= 114.0)
	await _sostener("mover_der", 0.6)
	_comprobar("llega al otro lado del foso", jugador.global_position.x > 1776.0
		and jugador.global_position.y <= 114.0)

func _prueba_arco() -> void:
	var jugador: Jugador = _jugador()
	var arco: Node2D = _nodo("Peligros/Arco01") as Node2D
	jugador.salud.revivir()
	jugador.salud.fijar_invulnerable(false)
	jugador.global_position = arco.global_position + Vector2(0.0, -1.0)
	var antes: int = jugador.salud.salud_actual
	await _esperar(3.4)
	_comprobar("el arco hace dano cuando descarga (%d -> %d)" % [antes, jugador.salud.salud_actual],
		jugador.salud.salud_actual < antes)
	jugador.salud.revivir()

func _prueba_salida() -> void:
	var jugador: Jugador = _jugador()
	jugador.salud.fijar_invulnerable(true)
	jugador.global_position = Vector2(184 * 16, 15 * 16 - 1)
	await _sostener("mover_der", 3.5, func() -> bool: return _escena() == FIN)
	_comprobar("el ascensor del santuario lleva al fin de la demo", _escena() == FIN)

func _prueba_continuar() -> void:
	# CargadorEscenas ignora un cambio pedido mientras el fundido anterior sigue
	# en curso (a proposito: dos cambios encadenados dejaban la escena a medias).
	await _esperar(1.2)
	Guardado.guardar("nivel_02_crt_02", {
		"salud": 4, "vendas": 1, "armas": ["tubo_metal"], "arma_equipada": "tubo_metal",
		"nivel": NIVEL_2,
	})
	_comprobar("la partida recuerda el nivel 2", Guardado.nivel_guardado() == NIVEL_2)
	CargadorEscenas.continuar_partida = true
	CargadorEscenas.cambiar_a(Guardado.nivel_guardado())
	await _esperar_hasta(func() -> bool: return _escena() == NIVEL_2, 5.0)
	await _esperar(0.8)
	var jugador: Jugador = _jugador()
	if jugador == null:
		_comprobar("seguir donde estaba abre el nivel 2", false)
		return
	var camara: Camera2D = jugador.get_node("Camara") as Camera2D
	_comprobar("seguir donde estaba abre el nivel 2 en el CRT 2 (x=%d)" % int(jugador.global_position.x),
		absf(jugador.global_position.x - (95 * 16 - 28)) < 4.0)
	_comprobar("la camara no se queda con el zoom de la entrada (zoom=%.2f)" % camara.zoom.x,
		is_equal_approx(camara.zoom.x, 1.0))
	_comprobar("restaura salud y vendas", jugador.salud.salud_actual == 4 and jugador.vendas == 1)

# ------------------------------------------------------------- Utilidades ----

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

## Mantiene pulsada una accion hasta que pase el tiempo o se cumpla la condicion.
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
