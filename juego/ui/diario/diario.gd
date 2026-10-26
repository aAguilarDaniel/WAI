# El diario: menú de pausa diegético, escrito por el protagonista (CLAUDE.md §3.3).
# Pestañas: Bitácora, Arsenal, Estadísticas y Ajustes.
#
# Antes de encontrarlo in-game, pausar solo muestra un menú mínimo sin estilo.
# La tipografía la cambia TipografiaAlma según el eje; el diario no consulta a Alma.
class_name Diario
extends CanvasLayer

signal abierto
signal cerrado

## Si se deja vacío, se busca el nodo del grupo "jugador".
@export var jugador: Jugador

@onready var raiz: Control = $Raiz
@onready var menu_minimo: Control = $Raiz/MenuMinimo
@onready var libro: Control = $Raiz/Libro
@onready var pestanas: TabContainer = $Raiz/Libro/Pestanas
@onready var lista_bitacora: VBoxContainer = $Raiz/Libro/Pestanas/Bitacora/Lista
@onready var lista_arsenal: VBoxContainer = $Raiz/Libro/Pestanas/Arsenal/Lista
@onready var lista_estadisticas: VBoxContainer = $Raiz/Libro/Pestanas/Estadisticas/Lista
@onready var tipografia: TipografiaAlma = $Tipografia

func _ready() -> void:
	# ALWAYS y no WHEN_PAUSED: con WHEN_PAUSED el diario no escucharía la tecla
	# mientras el juego corre, y entonces no habría forma de abrirlo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	tipografia.raiz = raiz
	# TipografiaAlma._ready() ya corrió (los hijos van antes que el padre) y salió
	# sin hacer nada porque todavía no tenía raiz. Sin esta llamada el diario se
	# queda con la fuente por defecto hasta que se cruce un umbral: al cargar una
	# partida que ya venía en ruta máquina, la letra no sería la que toca.
	tipografia.aplicar(Alma.ruta_actual())
	pestanas.set_tab_title(0, "Bitácora")
	pestanas.set_tab_title(1, "Arsenal")
	pestanas.set_tab_title(2, "Estadísticas")
	pestanas.set_tab_title(3, "Ajustes")
	EstadoJuego.entrada_agregada.connect(_al_agregar_entrada)

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("diario"):
		get_viewport().set_input_as_handled()
		alternar()

func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()

func abrir() -> void:
	get_tree().paused = true
	visible = true
	var tiene: bool = EstadoJuego.tiene_diario()
	libro.visible = tiene
	menu_minimo.visible = not tiene
	if tiene:
		refrescar()
	abierto.emit()

func cerrar() -> void:
	visible = false
	get_tree().paused = false
	cerrado.emit()

func refrescar() -> void:
	_refrescar_bitacora()
	_refrescar_arsenal()
	_refrescar_estadisticas()

# --- Contenido de las pestañas ---

func _refrescar_bitacora() -> void:
	_vaciar(lista_bitacora)
	if EstadoJuego.entradas.is_empty():
		_parrafo(lista_bitacora, "No he escrito nada todavía.")
		return
	for entrada: Dictionary in EstadoJuego.entradas:
		_parrafo(lista_bitacora, str(entrada.get("titulo", "")), true)
		_parrafo(lista_bitacora, str(entrada.get("texto", "")))
		_separador(lista_bitacora)

func _refrescar_arsenal() -> void:
	_vaciar(lista_arsenal)
	var arsenal: Array[ArmaData] = _arsenal_del_jugador()
	if arsenal.is_empty():
		_parrafo(lista_arsenal, "No llevo nada encima.")
		return
	var quien: Jugador = _jugador()
	var equipada: ArmaData = quien.arma.arma_actual() if quien != null else null
	for arma: ArmaData in arsenal:
		var marca: String = "> " if arma == equipada else "  "
		_parrafo(lista_arsenal, "%s%s (%s)" % [marca, arma.nombre, arma.nombre_tipo()], true)
		_parrafo(lista_arsenal, "dano %d - cadencia %.2fs" % [arma.dano, arma.cadencia])
		if not arma.texto_diario.is_empty():
			_parrafo(lista_arsenal, arma.texto_diario)
		_separador(lista_arsenal)

func _refrescar_estadisticas() -> void:
	_vaciar(lista_estadisticas)
	_parrafo(lista_estadisticas, "Tiempo: %s" % EstadoJuego.tiempo_formateado())
	_parrafo(lista_estadisticas, "Veces que he caído: %d" % EstadoJuego.estadistica("muertes"))
	_parrafo(lista_estadisticas, "A cuántos he eliminado: %d" % EstadoJuego.estadistica("enemigos_eliminados"))
	_parrafo(lista_estadisticas, "A cuántos he dejado pasar: %d" % EstadoJuego.estadistica("enemigos_evitados"))
	# El valor del eje NO se muestra: se comunica por la letra de estas mismas
	# líneas, por la paleta y por la voz narrativa (CLAUDE.md §3.1).

# --- Utilidades ---

func _al_agregar_entrada(_indice: int) -> void:
	if visible and libro.visible:
		_refrescar_bitacora()

func _jugador() -> Jugador:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	return jugador

func _arsenal_del_jugador() -> Array[ArmaData]:
	var quien: Jugador = _jugador()
	if quien == null or quien.arma == null:
		return []
	return quien.arma.arsenal

func _parrafo(contenedor: VBoxContainer, texto: String, destacado: bool = false) -> void:
	var etiqueta: Label = Label.new()
	etiqueta.text = tipografia.transformar(texto)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.modulate = Color(1.0, 1.0, 1.0, 1.0 if destacado else 0.78)
	contenedor.add_child(etiqueta)

func _separador(contenedor: VBoxContainer) -> void:
	contenedor.add_child(HSeparator.new())

func _vaciar(contenedor: VBoxContainer) -> void:
	for hijo: Node in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()
