# Herramienta temporal: abre el menu principal y lo fotografia en tres momentos.
extends Node

func _ready() -> void:
	get_window().size = Vector2i(384 * 3, 216 * 3)
	add_child(load("res://ui/menu/menu_principal.tscn").instantiate())
	for segundos: float in [1.0, 2.6, 4.5]:
		await get_tree().create_timer(segundos).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://../capturas/diag_menu_%.0f.png" % (segundos * 10.0))
		print("menu %.1f s" % segundos)
	get_tree().quit()
