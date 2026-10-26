# Herramienta temporal: planta al jugador en la zona de una pista contextual y
# espera sin tocar nada, para comprobar que la placa de la tecla sale y se lee.
extends Node

func _ready() -> void:
	get_window().size = Vector2i(384 * 3, 216 * 3)
	var nivel: Node = load("res://levels/nivel_01/nivel_01.tscn").instantiate()
	add_child(nivel)
	await get_tree().process_frame
	var apertura: Node = nivel.get_node_or_null("AperturaSadak")
	if apertura: apertura.queue_free()
	var jugador: Jugador = nivel.get_node_or_null("Jugador") as Jugador
	jugador.fijar_control(true)
	jugador.global_position = Vector2(18 * 16, 7 * 16)
	# 4 s de retardo + margen. No se pulsa nada: de eso va la prueba.
	# 4 s de retardo de la pista + el fundido de entrada, mas margen. No se pulsa
	# nada en toda la prueba: de eso va justamente.
	await get_tree().create_timer(6.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../capturas/diag_pista.png")
	print("pista capturada")
	get_tree().quit()
