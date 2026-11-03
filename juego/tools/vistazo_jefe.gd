# Herramienta: fotos del jefe en la arena (cada fase y el aviso del rayo) y del
# final en las tres rutas, sin jugar hasta alli. Deja las capturas en capturas/.
#
#   godot --path juego res://tools/vistazo_jefe.tscn
extends Node

const NIVEL_5: String = "res://levels/nivel_07/nivel_07.tscn"
const FINAL: String = "res://ui/final/final.tscn"

func _ready() -> void:
	get_window().size = Vector2i(384 * 2, 216 * 2)
	_correr.call_deferred()

func _correr() -> void:
	var nivel: Node = (load(NIVEL_5) as PackedScene).instantiate()
	get_tree().root.add_child(nivel)
	await _esperar(0.2)
	for hijo: Node in nivel.get_children():
		if hijo is AperturaSadak:
			(hijo as AperturaSadak).cancelar()
	var jugador: Jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	var jefe: Custodio = nivel.get_node("Arena/Custodio") as Custodio
	jugador.salud.fijar_invulnerable(true)
	# Entra andando: el disparador de la arena solo salta al cruzarlo.
	jugador.global_position = Vector2(41 * 16, 15 * 16 - 1)
	Input.action_press("mover_der")
	await _esperar(0.9)
	Input.action_release("mover_der")
	await _esperar(3.8)
	await _foto("jefe_fase1")
	jefe.salud.aplicar_dano(11, Vector2.RIGHT, self)
	await _esperar(2.4)
	await _foto("jefe_fase2")
	jefe.salud.aplicar_dano(10, Vector2.RIGHT, self)
	await _esperar(2.0)
	jefe._ataque = Custodio.Ataque.RAYO
	jefe._orientar(-1)
	jefe._cambiar(Custodio.Modo.AVISO)
	Input.action_press("agachar")
	await _esperar(0.5)
	await _foto("jefe_rayo_aviso")
	await _esperar(0.55)
	await _foto("jefe_rayo")
	Input.action_release("agachar")
	nivel.queue_free()
	for valor: float in [0.6, 0.0, -0.6]:
		Alma.cargar(valor)
		var final: Node = (load(FINAL) as PackedScene).instantiate()
		get_tree().root.add_child(final)
		await _esperar(7.0)
		await _foto("final_%s" % Alma.nombre_ruta(Alma.ruta_actual()))
		final.queue_free()
	get_tree().quit()

func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var ruta: String = ProjectSettings.globalize_path("res://../capturas/%s.png" % nombre)
	get_viewport().get_texture().get_image().save_png(ruta)
	print("foto: ", ruta)

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
