# Herramienta: comprueba los pozos con pinchos y saca una foto cayendo en uno
# (capturas/pinchos.png).
#
#   godot --path juego res://tools/prueba_pinchos.tscn
extends Node

const NIVEL_1: String = "res://levels/nivel_01/nivel_01.tscn"
const CUANTOS: Dictionary = {
	"res://levels/nivel_01/nivel_01.tscn": 4,
	"res://levels/nivel_02/nivel_02.tscn": 1,
	"res://levels/nivel_04/nivel_04.tscn": 3,
}

var _fallos: int = 0

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	EstadoJuego.reiniciar()
	_correr.call_deferred()

func _correr() -> void:
	for ruta: String in CUANTOS:
		var escena: Node = (load(ruta) as PackedScene).instantiate()
		var total: int = 0
		for hijo: Node in escena.get_node("Peligros").get_children():
			if hijo is Pinchos:
				total += 1
		escena.free()
		_comprobar("%s tiene %d pozos con pinchos" % [ruta.get_file(), total], total == int(CUANTOS[ruta]))

	var nivel: Node = (load(NIVEL_1) as PackedScene).instantiate()
	get_tree().root.add_child(nivel)
	await _esperar(0.2)
	for hijo: Node in nivel.get_children():
		if hijo is AperturaSadak:
			(hijo as AperturaSadak).cancelar()
	var jugador: Jugador = nivel.get_node("Jugador") as Jugador
	var camara: Camera2D = jugador.get_node("Camara") as Camera2D
	var terreno: TileMapLayer = nivel.get_node("Terreno") as TileMapLayer
	_comprobar("la camara no baja de donde acaba el terreno (%d)" % camara.limit_bottom,
		camara.limit_bottom == terreno.get_used_rect().end.y * 16)

	# Pisa tierra firme junto al primer abismo (45-46) y se tira dentro.
	var borde: Vector2 = Vector2(44 * 16 + 8, 7 * 16 - 1)
	jugador.global_position = borde
	await _esperar(0.3)
	_comprobar("recuerda el suelo firme", jugador.ultimo_suelo_seguro.distance_to(borde) < 3.0)
	var antes: int = jugador.salud.salud_actual
	var muertes: int = EstadoJuego.estadistica("muertes")
	# Cae desde el borde, como en el juego, y se mira justo antes de tocar.
	jugador.global_position = Vector2(46 * 16, 7 * 16)
	jugador.velocity = Vector2.ZERO
	var pinchos: Pinchos = nivel.get_node("Peligros/Pinchos01") as Pinchos
	await _esperar_hasta(func() -> bool: return jugador.global_position.y > pinchos.global_position.y - 26.0, 2.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://../capturas/pinchos.png"))
	var en_pantalla: Vector2 = get_viewport().get_canvas_transform() * pinchos.global_position
	_comprobar("los pinchos se ven antes de tocarlos (base en y=%d de 216)" % int(en_pantalla.y),
		en_pantalla.y <= 216.0)
	await _esperar(1.0)
	_comprobar("los pinchos quitan 2 corazones (%d -> %d)" % [antes, jugador.salud.salud_actual],
		jugador.salud.salud_actual == antes - 2)
	_comprobar("no cuenta como muerte", EstadoJuego.estadistica("muertes") == muertes)
	_comprobar("vuelve al suelo firme (%s)" % jugador.global_position,
		jugador.global_position.distance_to(borde) < 12.0 and jugador.is_on_floor())

	# Rodar no libra: las paredes aguantan y duele igual. Cae en diagonal.
	await _esperar(1.0)
	antes = jugador.salud.salud_actual
	jugador.salud.fijar_invulnerable(true)
	jugador.global_position = Vector2(46 * 16, 7 * 16)
	jugador.velocity = Vector2(160.0, 0.0)
	# Se suelta antes de tocar fondo: seguir pulsando al volver lo tiraria otra vez.
	Input.action_press("mover_der")
	await _esperar(0.2)
	Input.action_release("mover_der")
	await _esperar(1.0)
	jugador.salud.fijar_invulnerable(false)
	_comprobar("la pared del pozo no se atraviesa y duele aun con i-frames (%d -> %d)" % [
		antes, jugador.salud.salud_actual], jugador.salud.salud_actual == antes - 2)

	# Sin corazones suficientes es una muerte normal.
	await _esperar(1.0)
	jugador.salud.salud_actual = 2
	jugador.global_position = Vector2(46 * 16, 7 * 16)
	await _esperar(1.0)
	_comprobar("con 2 corazones o menos mata y reaparece",
		EstadoJuego.estadistica("muertes") == muertes + 1
		and jugador.global_position.distance_to(jugador.punto_de_reaparicion) < 40.0
		and jugador.salud.salud_actual == jugador.salud.salud_maxima)

	# Un enemigo que cae tambien muere: si no, el secreto seria imposible.
	var enemigo: EnemigoPatrulla = nivel.get_node("Enemigos/Enemigo01") as EnemigoPatrulla
	enemigo.global_position = Vector2(46 * 16, 8 * 16)
	await _esperar(1.0)
	_comprobar("los pinchos matan a un enemigo y cuenta en el registro", RegistroEnemigos.eliminados() == 1)

	print("")
	print("RESULTADO: %s (%d fallos)" % ["TODO PASA" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)

func _esperar_hasta(condicion: Callable, tope: float) -> void:
	var transcurrido: float = 0.0
	while transcurrido < tope and not condicion.call():
		await get_tree().physics_frame
		transcurrido += get_physics_process_delta_time()

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout

func _comprobar(texto: String, ok: bool) -> void:
	print("%s  %s" % ["PASA " if ok else "FALLA", texto])
	if not ok:
		_fallos += 1
