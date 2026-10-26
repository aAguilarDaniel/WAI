# Herramienta temporal: abre el diario en las tres rutas y fotografia dos
# pestanas de cada una, para revisar la tipografia sin jugar hasta cruzar un umbral.
extends Node

const RUTAS: Array = [
	["humano", 0.6], ["ambiguo", 0.0], ["maquina", -0.6],
]

func _ready() -> void:
	get_window().size = Vector2i(384 * 3, 216 * 3)
	var nivel: Node = load("res://levels/nivel_01/nivel_01.tscn").instantiate()
	add_child(nivel)
	await get_tree().process_frame
	var apertura: Node = nivel.get_node_or_null("AperturaSadak")
	if apertura: apertura.queue_free()
	var jugador: Jugador = nivel.get_node_or_null("Jugador") as Jugador
	# Atrezo: sin arsenal ni entradas, la pestana Arsenal sale vacia.
	jugador.arma.arsenal = ComponenteArma.cargar_carpeta(jugador.arma.carpeta_armas)
	jugador.arma.equipar(0)
	EstadoJuego.fijar_bandera(EstadoJuego.BANDERA_DIARIO, true)
	EstadoJuego.agregar_entrada("Un cuaderno",
		"Estaba en el suelo, entre dos placas. Las hojas siguen limpias. Alguien lo dejó aquí y no volvió.", "mundo")
	EstadoJuego.estadisticas["muertes"] = 3
	EstadoJuego.estadisticas["enemigos_evitados"] = 19
	var diario: Diario = nivel.get_node_or_null("Diario") as Diario
	for datos: Array in RUTAS:
		Alma.forzar(float(datos[1]))
		await get_tree().create_timer(0.4).timeout
		for pestana: int in [0, 1]:
			diario.abrir()
			diario.pestanas.current_tab = pestana
			await get_tree().create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"res://../capturas/diag_diario_%s_%d.png" % [datos[0], pestana])
			diario.cerrar()
			await get_tree().process_frame
		print("diario %s" % datos[0])
	get_tree().quit()
