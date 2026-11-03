# Pantalla de cierre de la demo. Llega aqui ui/final/final.tscn, despues del
# final por ruta.
#
# No es el final: ese es ui/final/. Esto solo cierra la rebanada vertical: el
# protagonista sentado frente a un monitor, como en cada guardado, las mismas
# estadisticas que el diario y los creditos con las referencias artisticas.
# El valor del eje NO aparece (CLAUDE.md §3.1).
extends Control

const RUTA_MENU: String = "res://ui/menu/menu_principal.tscn"
const TITULO: String = "FIN DE LA DEMO"

@onready var figura: AnimatedSprite2D = $Escena/Figura
@onready var pantalla: Sprite2D = $Escena/Halo
@onready var titulo: Label = $Interfaz/Titulo
@onready var datos: Label = $Interfaz/Datos
@onready var creditos: Label = $Interfaz/Creditos
@onready var volver: Button = $Interfaz/Volver

var _tiempo: float = 0.0

func _ready() -> void:
	DirectorAudio.ambiente("crt_zumbido", -18.0)
	DirectorAudio.parar_musica()
	if figura.sprite_frames != null and figura.sprite_frames.has_animation(&"sentado"):
		figura.play(&"sentado")
	titulo.text = ""
	datos.text = "\n".join([
		"Tiempo: %s" % EstadoJuego.tiempo_formateado(),
		"Veces que he caído: %d" % EstadoJuego.estadistica("muertes"),
		"A cuántos he eliminado: %d" % EstadoJuego.estadistica("enemigos_eliminados"),
	])
	for nodo: CanvasItem in [datos, creditos, volver]:
		nodo.modulate.a = 0.0
	volver.pressed.connect(_al_volver)
	_secuencia()

func _process(delta: float) -> void:
	_tiempo += delta
	# El monitor respira y a ratos se corta, igual que los CRT del juego.
	var corte: float = 0.25 if fmod(_tiempo, 5.3) < 0.07 else 1.0
	pantalla.modulate.a = (0.55 + sin(_tiempo * 2.1) * 0.08) * corte

func _secuencia() -> void:
	var guion: Tween = create_tween()
	guion.tween_interval(0.8)
	for i: int in TITULO.length():
		guion.tween_callback(_escribir.bind(i + 1))
		guion.tween_interval(0.09)
	guion.tween_interval(0.5)
	guion.tween_property(datos, "modulate:a", 1.0, 0.8)
	guion.tween_interval(0.4)
	guion.tween_property(creditos, "modulate:a", 0.75, 0.8)
	guion.tween_property(volver, "modulate:a", 1.0, 0.5)
	guion.tween_callback(volver.grab_focus)

func _escribir(cuantas: int) -> void:
	titulo.text = TITULO.substr(0, cuantas)
	DirectorAudio.efecto_variado("menu_mover", -20.0, 0.25)

func _al_volver() -> void:
	DirectorAudio.efecto("menu_aceptar", -6.0)
	CargadorEscenas.cambiar_a(RUTA_MENU)
