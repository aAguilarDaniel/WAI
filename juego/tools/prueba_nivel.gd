# Herramienta: recorre el nivel 1 solo, de principio a fin, y avisa de donde se
# atasca. Es la unica forma de comprobar que el nivel es transitable sin jugarlo
# doce veces a mano cada vez que se mueve una plataforma.
#
# El piloto es tonto a proposito: anda a la derecha, salta cuando el suelo se
# acaba o hay un escalon delante, corre si el hueco es ancho, pega si tiene un
# enemigo cerca y rueda si lo tiene encima. Si un humano no podria pasar por ahi
# con esas cinco reglas, el tramo esta mal disenado.
#
# Se corre con:
#   godot --path juego res://tools/prueba_nivel.tscn
#
# NO con --headless: sin renderizador la TerminalCRT no puede leer su SubViewport.
extends Node

const RUTA_NIVEL: String = "res://levels/nivel_01/nivel_01.tscn"
## Tile a partir del cual se considera terminado el nivel.
const META: int = 205
## Segundos sin avanzar antes de dar el tramo por atascado.
const PACIENCIA: float = 9.0
## Tope duro, por si el piloto entra en un bucle.
const TIEMPO_MAXIMO: float = 260.0

var _nivel: Node = null
var _jugador: Jugador = null
var _terreno: TileMapLayer = null
var _mejor_tile: int = 0
var _sin_avanzar: float = 0.0
var _transcurrido: float = 0.0
var _sostenidas: Dictionary = {}
var _proxima_captura: int = 0
var _muertes: int = 0
## Tile del frame anterior. El atasco se mide contra ESTE y no contra la mejor
## marca: despues de morir, no superar la mejor marca es lo normal, no un atasco.
var _ultimo_tile: int = -1
var _posicion_previa: Vector2 = Vector2.ZERO

func _ready() -> void:
	get_window().size = Vector2i(384 * 3, 216 * 3)
	_nivel = load(RUTA_NIVEL).instantiate()
	add_child(_nivel)
	await get_tree().process_frame
	# La apertura quita el control cuatro segundos: para la prueba estorba.
	var apertura: Node = _nivel.get_node_or_null("AperturaSadak")
	if apertura != null:
		apertura.queue_free()
	_jugador = _nivel.get_node_or_null("Jugador") as Jugador
	_terreno = _nivel.get_node_or_null("Terreno") as TileMapLayer
	if _jugador == null or _terreno == null:
		printerr("PRUEBA: el nivel no tiene Jugador o Terreno.")
		get_tree().quit(1)
		return
	_jugador.fijar_control(true)
	# Morir reinicia la paciencia: tras reaparecer, el piloto tarda en volver a
	# superar su mejor marca y el arnes lo daba por atascado sin estarlo.
	_jugador.salud.murio.connect(func(_f: Node) -> void:
		_muertes += 1
		# Cuando llega esta senal el jugador ya reaparecio: se usa la posicion del
		# frame anterior, que es donde murio de verdad.
		print("  muerte %d en el tile %d, fila %d" % [_muertes,
			int(floor(_posicion_previa.x / 16.0)), int(floor(_posicion_previa.y / 16.0))])
		_sin_avanzar = 0.0
		_ultimo_tile = -1)
	print("PRUEBA: arranca en el tile %d, meta en el %d" % [_tile_actual(), META])

func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	_transcurrido += delta
	_posicion_previa = _jugador.global_position
	_soltar_vencidas(delta)
	_pilotar()
	_vigilar(delta)

# --- El piloto ---

func _pilotar() -> void:
	_pulsar("mover_der", 0.1)
	var tile: int = _tile_actual()
	var fila: int = _fila_actual()

	# Correr si lo que viene es un hueco ancho. Se mira con dos tiles de
	# antelacion: arrancar a correr en el mismo canto llega tarde.
	var hueco: int = maxi(_hueco_delante(tile, fila), _hueco_delante(tile + 1, fila))
	if hueco >= 3:
		_pulsar("correr", 0.8)

	# Saltar: se acaba el suelo JUSTO delante, hay un escalon, o hay pared.
	# Solo el tile siguiente: la anticipacion de dos tiles de arriba es para
	# decidir si corre. Usada tambien para saltar, el piloto despegaba un tile
	# antes del borde (64 px de vuelo en vez de 32) y caia siempre en el abismo
	# del tile 45, justo despues del primer CRT.
	if _jugador.is_on_floor():
		var hueco_inmediato: bool = _hueco_delante(tile, fila) > 0 and _cerca_del_borde()
		if hueco_inmediato or _escalon_delante(tile, fila) or _jugador.is_on_wall():
			_pulsar("saltar", 0.40)

	var enemigo: EnemigoPatrulla = _enemigo_cercano()
	if enemigo == null:
		return
	var distancia: float = absf(enemigo.global_position.x - _jugador.global_position.x)
	# Rodar cuando se le echa encima: es la esquiva del patron.
	if distancia < 24.0 and _jugador.puede_rodar():
		_pulsar("rodar", 0.1)
	elif distancia < 34.0 and _jugador.puede_atacar():
		_pulsar("atacar", 0.1)

## True en la ultima mitad del tile: saltar desde el principio del tile pierde
## 8 px de los 44 que da un salto andando.
func _cerca_del_borde() -> bool:
	return fmod(_jugador.global_position.x, 16.0) >= 8.0

## Cuantos tiles de vacio hay justo delante, mirando 5 columnas.
func _hueco_delante(tile: int, fila: int) -> int:
	var vacios: int = 0
	for i: int in range(1, 6):
		if _hay_suelo(tile + i, fila):
			break
		vacios += 1
	return vacios

## True si la columna siguiente tiene el suelo mas alto y hay sitio para subirse.
##
## La comprobacion del hueco de encima no es un detalle: en los dos pasillos con
## techo bajo, el techo esta a la altura a la que miraba esta funcion, asi que el
## piloto lo tomaba por un escalon y se pasaba el pasillo entero saltando.
func _escalon_delante(tile: int, fila: int) -> bool:
	for dy: int in range(1, 3):
		if _solido(tile + 1, fila - dy) and not _solido(tile + 1, fila - dy - 1):
			return true
	return false

## Hay suelo en esa columna, entre la fila actual y 4 por debajo.
func _hay_suelo(tile: int, fila: int) -> bool:
	for dy: int in range(0, 5):
		if _solido(tile, fila + dy):
			return true
	return false

func _solido(x: int, y: int) -> bool:
	return _terreno.get_cell_source_id(Vector2i(x, y)) != -1

func _enemigo_cercano() -> EnemigoPatrulla:
	var contenedor: Node = _nivel.get_node_or_null("Enemigos")
	if contenedor == null:
		return null
	var mejor: EnemigoPatrulla = null
	var mejor_dist: float = 60.0
	for hijo: Node in contenedor.get_children():
		var enemigo: EnemigoPatrulla = hijo as EnemigoPatrulla
		if enemigo == null:
			continue
		var d: float = enemigo.global_position.distance_to(_jugador.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = enemigo
	return mejor

# --- Vigilancia ---

func _vigilar(delta: float) -> void:
	var tile: int = _tile_actual()
	_mejor_tile = maxi(_mejor_tile, tile)
	if tile != _ultimo_tile:
		_ultimo_tile = tile
		_sin_avanzar = 0.0
	else:
		_sin_avanzar += delta

	if tile >= _proxima_captura:
		_proxima_captura = tile + 24
		_capturar(tile)

	if tile >= META:
		_terminar("COMPLETADO", 0)
	elif _sin_avanzar > PACIENCIA:
		_terminar("ATASCADO en el tile %d (mejor marca %d)" % [tile, _mejor_tile], 1)
	elif _transcurrido > TIEMPO_MAXIMO:
		_terminar("TIEMPO AGOTADO en el tile %d" % _mejor_tile, 1)

func _terminar(motivo: String, codigo: int) -> void:
	set_physics_process(false)
	# Foto del sitio exacto donde se quedo: sin ella hay que adivinar el tramo.
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../capturas/prueba_final.png")
	print("PRUEBA: %s" % motivo)
	print("  posicion: %s  fila %d  suelo=%s  pared=%s  techo=%s  vel=%s" % [
		_jugador.global_position, _fila_actual(), _jugador.is_on_floor(),
		_jugador.is_on_wall(), _jugador.is_on_ceiling(), _jugador.velocity])
	print("  fisica=%s  estado=%s  terminal_activa=%s" % [
		_jugador.is_physics_processing(), _jugador.maquina.nombre_actual(),
		_terminal_activa()])
	print("  tiempo: %.1f s   muertes: %d   arsenal: %d   alma: %+.2f (%s)" % [
		_transcurrido, _muertes, _jugador.arma.arsenal.size(),
		Alma.valor(), Alma.nombre_ruta(Alma.ruta_actual())])
	print("  diario: %s   enemigos eliminados: %d" % [
		EstadoJuego.tiene_diario(), EstadoJuego.estadistica("enemigos_eliminados")])
	get_tree().quit(codigo)

## Que TerminalCRT esta en medio de su escena, si hay alguna. Diagnostico: una
## terminal activa quita el control al jugador y lo deja clavado.
func _terminal_activa() -> String:
	var contenedor: Node = _nivel.get_node_or_null("Terminales")
	if contenedor == null:
		return "sin contenedor"
	for hijo: Node in contenedor.get_children():
		var terminal: TerminalCRT = hijo as TerminalCRT
		if terminal != null and terminal.activa:
			return terminal.name
	return "ninguna"

func _capturar(tile: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://../capturas/prueba_%03d.png" % tile)

# --- Entrada simulada ---

## Mantiene una accion pulsada unos segundos.
##
## Se inyecta con parse_input_event() y NO con Input.action_press(): el salto,
## el interactuar y el cambio de arma se leen en _unhandled_input(), y
## action_press solo cambia el estado que se consulta por sondeo, sin generar
## ningun evento. Con action_press el piloto no saltaria nunca. Es la misma
## trampa que ya documenta tools/captura.gd.
func _pulsar(accion: String, segundos: float) -> void:
	if not _sostenidas.has(accion):
		_evento(accion, true)
	_sostenidas[accion] = maxf(float(_sostenidas.get(accion, 0.0)), segundos)

func _soltar_vencidas(delta: float) -> void:
	for accion: String in _sostenidas.keys():
		var resto: float = float(_sostenidas[accion]) - delta
		if resto <= 0.0:
			_evento(accion, false)
			_sostenidas.erase(accion)
		else:
			_sostenidas[accion] = resto

func _evento(accion: String, pulsada: bool) -> void:
	var evento: InputEventAction = InputEventAction.new()
	evento.action = accion
	evento.pressed = pulsada
	Input.parse_input_event(evento)

func _tile_actual() -> int:
	return int(floor(_jugador.global_position.x / 16.0))

func _fila_actual() -> int:
	return int(floor(_jugador.global_position.y / 16.0))
