# Arena del Custodio: cierra la puerta al entrar, despierta al jefe, pone su
# musica y, al derrotarlo, escribe la entrada del diario y abre la salida.
# La instancia tools/generar_nivel_05.gd; el jefe no sabe nada de puertas.
#
# Si el jugador muere dentro, el jefe vuelve a dormirse con la vida llena y la
# puerta se reabre: reaparece en el CRT de antes de la arena y vuelve a entrar.
class_name ArenaJefe
extends Node2D

const BANDERA: String = "jefe_custodio_derrotado"

## Musica del combate. Suena solo despues de la pausa de intimidacion.
@export var musica: AudioStream
@export var volumen_musica: float = -6.0
## Bordes horizontales a los que se encierra la camara durante el combate (x y
## ancho; el resto no se usa). La arena mide un cuadro: se ve entera, jefe y
## jugador a la vez, como en Hollow Knight.
@export var limite_camara: Rect2 = Rect2()

@export_group("Entrada del diario al derrotarlo")
## Una por ruta (HITOS.md, Hito 7). BORRADOR: ver docs/TEXTOS_PENDIENTES.md.
@export var titulo_entrada: String = "El Custodio"
@export_multiline var entrada_humana: String = ""
@export_multiline var entrada_ambigua: String = ""
@export_multiline var entrada_maquina: String = ""

@onready var jefe: Custodio = $Custodio
@onready var entrada: Compuerta = $CompuertaEntrada
@onready var salida: Compuerta = $CompuertaSalida
@onready var disparador: Area2D = $Disparador

var _combate: bool = false
var _camara: Camera2D = null
var _limites_previos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	disparador.body_entered.connect(_al_entrar)
	jefe.desperto.connect(_al_despertar)
	jefe.derrotado.connect(_al_derrotar)
	salida.cerrar(true)
	if EstadoJuego.bandera(BANDERA):
		# Ya estaba derrotado (partida retomada): la arena es solo un paso.
		jefe.queue_free()
		salida.abrir(true)
		disparador.set_deferred("monitoring", false)
		return
	var jugador: Jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador != null:
		jugador.salud.murio.connect(_al_morir_jugador)

func _al_entrar(cuerpo: Node2D) -> void:
	if _combate or not (cuerpo is Jugador) or not is_instance_valid(jefe):
		return
	if not jefe.esta_dormido():
		return
	_combate = true
	entrada.cerrar()
	_encerrar_camara(cuerpo as Jugador)
	# La pausa de intimidacion va en silencio: sin la cancion del nivel anterior,
	# solo el ambiente. La musica entra cuando el jefe da el primer paso.
	DirectorAudio.parar_musica()
	jefe.despertar()

func _al_despertar() -> void:
	DirectorAudio.musica(musica, volumen_musica)

func _al_derrotar() -> void:
	_combate = false
	DirectorAudio.parar_musica()
	EstadoJuego.fijar_bandera(BANDERA, true)
	var texto: String = entrada_ambigua
	match Alma.ruta_actual():
		Alma.Ruta.HUMANO:
			texto = entrada_humana
		Alma.Ruta.MAQUINA:
			texto = entrada_maquina
	if not texto.is_empty():
		EstadoJuego.agregar_entrada(titulo_entrada, texto, "jefe")
	salida.abrir()
	_soltar_camara()

## Muerte dentro de la arena: el intento siguiente empieza limpio. Diferido
## porque murio se emite en plena fisica y el jugador todavia se esta moviendo.
func _al_morir_jugador(_fuente: Node) -> void:
	if not _combate:
		return
	_combate = false
	call_deferred("_reiniciar")

func _reiniciar() -> void:
	DirectorAudio.parar_musica()
	if is_instance_valid(jefe):
		jefe.reiniciar()
	entrada.abrir(true)
	_soltar_camara()

func _encerrar_camara(jugador: Jugador) -> void:
	if limite_camara.size.x <= 0.0:
		return
	_camara = jugador.get_node_or_null("Camara") as Camera2D
	if _camara == null:
		return
	_limites_previos = Vector2i(_camara.limit_left, _camara.limit_right)
	_camara.limit_left = int(limite_camara.position.x)
	_camara.limit_right = int(limite_camara.position.x + limite_camara.size.x)

func _soltar_camara() -> void:
	if _camara == null or not is_instance_valid(_camara):
		return
	_camara.limit_left = _limites_previos.x
	_camara.limit_right = _limites_previos.y
	_camara = null
