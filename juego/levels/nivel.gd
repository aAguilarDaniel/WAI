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

@onready var terreno: TileMapLayer = $Terreno

func _ready() -> void:
	# Efectos busca por este grupo el nodo del que colgar chispas y polvo: si
	# colgaran de quien los pide, un enemigo que muere se llevaria su propia
	# explosion por delante.
	add_to_group("nivel")
	DirectorAudio.ambiente("ambiente", -13.0)
	_ajustar_limites_de_camara()
	if CargadorEscenas.continuar_partida:
		CargadorEscenas.continuar_partida = false
		_aplicar_partida_guardada()

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
		# La apertura de Sadak es la primera imagen del juego: no tiene sentido
		# repetirla al retomar una partida a mitad del nivel.
		var apertura: Node = get_node_or_null("AperturaSadak")
		if apertura != null:
			apertura.queue_free()
			jugador.fijar_control(true)

	jugador.vendas = int(datos.get("vendas", jugador.vendas))
	jugador.vendas_cambiadas.emit(jugador.vendas)
	var salud_guardada: int = int(datos.get("salud", 0))
	if salud_guardada > 0:
		jugador.salud.salud_actual = mini(salud_guardada, jugador.salud.salud_maxima)
		jugador.salud.salud_cambiada.emit(jugador.salud.salud_actual,
			jugador.salud.salud_maxima)

	_restaurar_arsenal(jugador, datos)

## Vuelve a meter en el arsenal las armas que ya tenia, por id. Se recorre la
## carpeta y no una lista escrita a mano: agregar un .tres nuevo sigue sin
## obligar a tocar codigo (CLAUDE.md §3.2).
func _restaurar_arsenal(jugador: Jugador, datos: Dictionary) -> void:
	var ids: Array = datos.get("armas", [])
	if ids.is_empty():
		return
	var todas: Array[ArmaData] = ComponenteArma.cargar_carpeta(jugador.arma.carpeta_armas)
	var equipada: String = str(datos.get("arma_equipada", ""))
	for arma: ArmaData in todas:
		if ids.has(arma.id):
			jugador.arma.obtener(arma)
	for i: int in jugador.arma.arsenal.size():
		if jugador.arma.arsenal[i].id == equipada:
			jugador.arma.equipar(i)
			return

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
