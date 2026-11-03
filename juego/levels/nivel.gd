# Raiz de un nivel jugable. Deriva los limites de la camara del tamano real del
# terreno y, si venimos de "Seguir donde estaba", aplica la partida guardada.
#
# Los limites se derivan porque PackedScene NO guarda los cambios hechos a nodos
# internos de una escena instanciada: ponerlos en la Camara del jugador desde la
# herramienta de generacion no sobrevive al guardado. Derivarlos en _ready()
# ademas se ajusta solo si agrandan el nivel en el editor.
class_name Nivel
extends Node2D

## Cuanto cielo se deja ver por encima del terreno.
@export var margen_superior: int = 420
## Cuanto se deja ver por debajo, antes de la ZonaMortal.
@export var margen_inferior: int = 120

## Desplazamiento de la camara respecto del jugador. Negativo = mas aire encima.
## En el exterior se sube para que el cielo mande y no medio cuadro de relleno de
## suelo; en el interior casi centrado, porque hay techo.
@export var encuadre_camara: Vector2 = Vector2(0.0, -40.0)

@export_group("Audio")
## Bucle de ambiente del nivel, por nombre de archivo en audio/.
@export var ambiente: String = "ambiente"
@export var volumen_ambiente: float = -13.0
## Cancion del nivel, en bucle encima del ambiente. Vacio = el nivel va sin
## musica (y corta la del nivel anterior si venia sonando).
@export var musica: AudioStream = null
@export var volumen_musica: float = -8.0

@onready var terreno: TileMapLayer = $Terreno

## En _enter_tree y no en _ready: los _ready() de los hijos corren antes, y tanto
## CamaraJugador (que copia offset a offset_base) como la apertura (que guarda el
## encuadre al que volver) tienen que encontrarse ya el valor del nivel.
func _enter_tree() -> void:
	var camara: Camera2D = get_node_or_null("Jugador/Camara") as Camera2D
	if camara != null:
		camara.offset = encuadre_camara

func _ready() -> void:
	# Efectos busca por este grupo el nodo del que colgar chispas y polvo: si
	# colgaran de quien los pide, un enemigo que muere se llevaria su propia
	# explosion por delante.
	add_to_group("nivel")
	DirectorAudio.ambiente(ambiente, volumen_ambiente)
	DirectorAudio.musica(musica, volumen_musica)
	_ajustar_limites_de_camara()
	if CargadorEscenas.continuar_partida:
		CargadorEscenas.continuar_partida = false
		_aplicar_partida_guardada()
	elif not CargadorEscenas.datos_en_transito.is_empty():
		_aplicar_transito()

func _ajustar_limites_de_camara() -> void:
	if terreno == null or terreno.tile_set == null:
		return
	var camara: Camera2D = _camara_del_jugador()
	if camara == null:
		return
	var rejilla: Rect2i = terreno.get_used_rect()
	var celda: Vector2i = terreno.tile_set.tile_size
	camara.limit_left = rejilla.position.x * celda.x
	camara.limit_right = rejilla.end.x * celda.x
	camara.limit_top = rejilla.position.y * celda.y - margen_superior
	camara.limit_bottom = rejilla.end.y * celda.y + margen_inferior

## Restaura salud, vendas, arsenal y posicion. Alma y EstadoJuego ya los aplica
## Guardado.cargar(); aqui solo va lo que es del jugador y del nivel.
func _aplicar_partida_guardada() -> void:
	var datos: Dictionary = Guardado.cargar()
	if datos.is_empty():
		return
	var jugador: Jugador = _jugador()
	if jugador == null:
		return

	var terminal: TerminalCRT = _terminal(str(datos.get("checkpoint_id", "")))
	if terminal != null:
		var sitio: Vector2 = terminal.global_position + terminal.sitio_del_jugador
		jugador.global_position = sitio
		jugador.punto_de_reaparicion = sitio
		# La apertura es la primera imagen del nivel: no tiene sentido repetirla
		# al retomar una partida a mitad de camino.
		_quitar_apertura(jugador)
	jugador.restaurar(datos)

## Recien llegado por una PuertaNivel: trae la salud, las vendas y las armas del
## nivel anterior. La apertura del nivel SI se ve: es la entrada al edificio.
func _aplicar_transito() -> void:
	var datos: Dictionary = CargadorEscenas.datos_en_transito
	CargadorEscenas.datos_en_transito = {}
	var jugador: Jugador = _jugador()
	if jugador != null:
		jugador.restaurar(datos)

func _quitar_apertura(jugador: Jugador) -> void:
	for hijo: Node in get_children():
		var apertura: AperturaSadak = hijo as AperturaSadak
		if apertura != null:
			apertura.cancelar()
	jugador.fijar_control(true)

func _jugador() -> Jugador:
	return get_tree().get_first_node_in_group("jugador") as Jugador

func _camara_del_jugador() -> Camera2D:
	var jugador: Jugador = _jugador()
	if jugador == null:
		return null
	return jugador.get_node_or_null("Camara") as Camera2D

func _terminal(id: String) -> TerminalCRT:
	if id.is_empty():
		return null
	var contenedor: Node = get_node_or_null("Terminales")
	if contenedor == null:
		return null
	for hijo: Node in contenedor.get_children():
		var terminal: TerminalCRT = hijo as TerminalCRT
		if terminal != null and terminal.checkpoint_id == id:
			return terminal
	return null
