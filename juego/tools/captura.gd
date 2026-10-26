# Herramienta: modo captura para el trailer. Monta el nivel en un estado concreto
# y lo deja filmable sin tener que jugarlo.
#
# Existe porque los dos planos que mejor cuentan el juego -- el cambio de paleta y
# el de tipografia -- hoy no se pueden alcanzar jugando: hacen falta 14 muertes
# para cruzar un umbral y nivel_01 tiene 12 enemigos (ver alma.gd y el README).
#
# Se corre con:
#   godot --path juego res://tools/captura.tscn -- --listar
#   godot --path juego res://tools/captura.tscn -- --plano=crt
#
# Y para grabar a fichero, con el Movie Maker de Godot:
#   godot --path juego --write-movie ../capturas/crt.avi res://tools/captura.tscn -- --plano=crt
#
# NO uses --headless para filmar: sin renderizador real la TerminalCRT no puede
# leer su SubViewport y el retardo de la imagen se cae a "en vivo"
# (terminal_crt.gd, _puede_capturar). El plano del CRT saldria mal y sin aviso.
extends Node

const RUTA_NIVEL: String = "res://levels/nivel_01/nivel_01.tscn"

## Plano que se monta al abrir la escena desde el editor con F6, donde no hay
## argumentos de linea de comandos.
@export var plano_por_defecto: String = "crt"

## Plano en curso. Lo necesita _process() para el pulso de ataque.
var _plano: Plano = null
var _reloj_ataque: float = 0.0
var _reloj_rodar: float = 0.0
var _reloj_plano: float = 0.0
var _interactuo: bool = false
var _terminal: TerminalCRT = null
var _jugador: Jugador = null
var _terreno: TileMapLayer = null
## Acciones sostenidas: accion -> segundos que le quedan pulsada.
var _sostenidas: Dictionary = {}


## Un plano del guion de rodaje: todo lo que hace falta para montar un estado.
class Plano extends RefCounted:
	var nombre: String = ""
	var resumen: String = ""
	## Valor del eje al arrancar. Se aplica ANTES de montar el nivel, asi que la
	## paleta y la tipografia ya nacen en esa ruta, sin transicion visible.
	var alma: float = 0.0
	## Si no es NAN, el eje salta a este valor a los alma_en segundos. Es lo que
	## permite filmar la TRANSICION de paleta, que es el mecanismo central del juego.
	var alma_final: float = NAN
	var alma_en: float = 2.0
	## id del .tres a equipar. "" deja la que el arsenal ponga por defecto.
	var arma: String = ""
	## Columna de tiles donde plantar al jugador. -1 = no moverlo.
	var jugador_tile: int = -1
	## Terminal a activar, por nombre de nodo. "" = ninguna.
	var terminal: String = ""
	## Dejar correr la apertura Sadak. Si es false se borra ANTES de que arranque.
	var apertura: bool = false
	## Camina solo mientras dura el plano: -1 izquierda, 0 quieto, 1 derecha.
	var caminar: int = 0
	## Abre el diario en pausa. Requiere la bandera "diario_obtenido", que se
	## siembra sola con las estadisticas de abajo.
	var diario: bool = false
	## Pestana del diario: 0 Bitacora, 1 Arsenal, 2 Estadisticas, 3 Ajustes.
	## Para el trailer se usa la 2: es la unica cuyo texto ya esta escrito y no
	## depende de docs/TEXTOS_PENDIENTES.md.
	var pestana: int = 2
	## Cifras que enseña la pestana de Estadisticas. Son atrezo de rodaje, no
	## contenido narrativo: el diario las lee de EstadoJuego como en una partida real.
	var estadisticas: Dictionary = {}
	## Segundos entre golpes automaticos. 0 = no atacar.
	var atacar_cada: float = 0.0
	## Segundos entre esquivas automaticas. 0 = no rodar. El rodar dura 0.30 s y
	## tiene 0.50 s de enfriamiento: por debajo de 0.9 s la mitad se descartan.
	var rodar_cada: float = 0.0
	## Corre en vez de caminar. Hace falta para cruzar los abismos: a 70 px/s el
	## salto se queda corto sobre un hueco de 3 tiles, a 115 px/s sobra.
	var correr: bool = false
	## Salta solo cuando hace falta: al borde de un abismo y contra un escalon.
	var saltar_en_abismos: bool = false
	## Camina hasta la terminal y la activa el mismo, en vez de aparecer sentado.
	## Se dispara por CERCANIA y no por tiempo: cronometrarlo fallaba, porque a
	## 70 px/s se pasaba de largo antes de que saltara el temporizador.
	var acercarse: bool = false
	## Nodos del nivel a ocultar durante el plano, por ruta relativa a la raiz.
	## Hoy hace falta para Parallax/Capa6PrimerPlano: su placeholder son bloques
	## negros opacos que caen justo encima del encuadre de la TerminalCRT.
	var ocultar: Array = []
	## Texto de cartela a pantalla completa. Si no esta vacio el plano NO monta el
	## nivel: solo enseña el texto sobre negro, con la letra de la ruta actual.
	## Asi las cartelas del trailer usan la misma tipografia que el diario.
	var cartela: String = ""
	## Acercamiento de camara. 1.0 es el encuadre de juego.
	##
	## El protagonista mide 24 px en un cuadro de 384x216: perfecto para el
	## paisaje sublime de ARTE.md §3, e ilegible para ENSENAR una mecanica. Los
	## planos de paisaje se quedan en 1.0 y los de accion suben a 1.6-2.0, que es
	## lo que hace que se vea que rueda, salta o dispara. Es lenguaje de trailer,
	## no un cambio de juego: nada de esto toca la camara real.
	var zoom: float = 1.0
	## Segundos de rodaje. Al terminar el proceso se cierra solo, que es lo que
	## --write-movie necesita para cerrar el fichero.
	var duracion: float = 8.0

	func _init(datos: Dictionary) -> void:
		for clave: String in datos:
			set(clave, datos[clave])


# El guion del teaser, en orden de montaje.
#
# Devuelve Array a secas y no Array[Plano]: GDScript no admite clases internas
# como tipo de elemento de un array tipado. Las variables de bucle si van tipadas.
func _planos() -> Array:
	return [
		Plano.new({
			"nombre": "sadak",
			"resumen": "Plano 1. Apertura de John Martin: figura diminuta, cielo incandescente, el titulo entra y el control vuelve sin corte.",
			"apertura": true,
			"duracion": 11.0,
		}),
		Plano.new({
			"nombre": "caminata",
			"correr": true,
			"saltar_en_abismos": true,
			"resumen": "Desplazamiento lateral. Es el plano que ensena el parallax de 6 capas moviendose.",
			"jugador_tile": 40,
			"caminar": 1,
			"duracion": 10.0,
		}),
		Plano.new({
			"nombre": "crt",
			"resumen": "TV Buddha. Se acerca caminando, pulsa E, se sienta y la pantalla le devuelve su imagen con retardo.",
			"jugador_tile": 2,
			"caminar": 1,
			"terminal": "Terminal01",
			"acercarse": true,
			"saltar_en_abismos": true,
			"duracion": 14.0,
		}),
		Plano.new({
			"nombre": "deriva",
			"correr": true,
			"saltar_en_abismos": true,
			"resumen": "El mecanismo del juego en un plano: el mundo empieza humano y se vuelve maquina. La paleta tarda 3 s en cruzar.",
			"alma": 0.5,
			"alma_final": -0.5,
			"alma_en": 3.0,
			"jugador_tile": 40,
			"caminar": 1,
			"duracion": 12.0,
		}),
		Plano.new({
			"nombre": "humano",
			"correr": true,
			"saltar_en_abismos": true,
			"resumen": "El mundo asentado en ruta humana: grano, cianes apagados, luces calidas.",
			"alma": 0.6,
			"arma": "tubo_metal",
			"jugador_tile": 40,
			"caminar": 1,
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "cartela",
			"resumen": "Cartela sobre negro con la letra de la ruta. El texto se pasa con --cartela=\"...\".",
			"cartela": "[CARTELA - texto pendiente, ver docs/TEXTOS_PENDIENTES.md]",
			"duracion": 4.0,
		}),
		Plano.new({
			"nombre": "cartela_final",
			"resumen": "La pregunta que sostiene el juego, citada de CLAUDE.md §1. Cierra el teaser.",
			"cartela": "¿soy humano o soy una máquina más?",
			"duracion": 5.0,
		}),
		Plano.new({
			"nombre": "diario_humano",
			"resumen": "El diario abierto en ruta humana. Pestana de Estadisticas: texto en primera persona, letra manuscrita.",
			"alma": 0.6,
			"diario": true,
			"estadisticas": {"tiempo_seg": 754, "muertes": 3, "enemigos_eliminados": 0, "enemigos_evitados": 19},
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "diario_maquina",
			"resumen": "El MISMO diario en ruta maquina. Misma pestana, misma partida: solo cambia la letra, y el texto se corrompe.",
			"alma": -0.6,
			"diario": true,
			"estadisticas": {"tiempo_seg": 754, "muertes": 3, "enemigos_eliminados": 0, "enemigos_evitados": 19},
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "combate",
			"zoom": 1.8,
			"resumen": "Un latido de accion: avanza y golpea. Le da pulso al teaser sin convertirlo en trailer de gameplay.",
			"arma": "tubo_metal",
			"jugador_tile": 22,
			"caminar": 1,
			"atacar_cada": 0.9,
			"duracion": 10.0,
		}),
		Plano.new({
			"nombre": "rodar",
			"zoom": 1.9,
			"resumen": "La esquiva. Se tira, da la voltereta y se levanta, y cruza a los enemigos de los tiles 26 y 34 sin recibir un golpe (i-frames).",
			"arma": "tubo_metal",
			"jugador_tile": 20,
			"caminar": 1,
			"correr": true,
			"rodar_cada": 1.1,
			"saltar_en_abismos": true,
			"duracion": 9.0,
		}),
		Plano.new({
			"nombre": "salto",
			"zoom": 1.5,
			"resumen": "Plataformeo. Arranca antes del abismo ancho del tile 96 y encadena los dos huecos siguientes. Es el plano del feel.",
			"jugador_tile": 90,
			"caminar": 1,
			"correr": true,
			"saltar_en_abismos": true,
			"duracion": 9.0,
		}),
		Plano.new({
			"nombre": "pistola",
			"zoom": 1.7,
			"resumen": "Arma de fuego, polo humano: proyectil ambar y recto. Cruza al enemigo del tile 60.",
			"alma": 0.5,
			"arma": "pistola_reciclada",
			"jugador_tile": 54,
			"caminar": 1,
			"atacar_cada": 0.55,
			"saltar_en_abismos": true,
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "plasma",
			"zoom": 1.7,
			"resumen": "Polo maquina: la lanza de plasma escupe gotas cianes. Mismo gesto que la pistola, lectura opuesta.",
			"alma": -0.35,
			"arma": "lanza_plasma",
			"jugador_tile": 101,
			"caminar": 1,
			"atacar_cada": 0.8,
			"saltar_en_abismos": true,
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "radiacion",
			"zoom": 1.7,
			"resumen": "El emisor de radiacion, el arma que mas empuja a maquina: masa magenta, lenta y sucia. Enemigos en 158 y 170.",
			"alma": -0.6,
			"arma": "emisor_radiacion",
			"jugador_tile": 152,
			"caminar": 1,
			"atacar_cada": 1.0,
			"saltar_en_abismos": true,
			"duracion": 8.0,
		}),
		Plano.new({
			"nombre": "maquina",
			"correr": true,
			"saltar_en_abismos": true,
			"resumen": "El mundo asentado en ruta maquina: aberracion cromatica, scanlines, tinte frio.",
			"alma": -0.6,
			"arma": "emisor_radiacion",
			"jugador_tile": 40,
			"caminar": 1,
			"duracion": 8.0,
		}),
	]


func _ready() -> void:
	var opciones: Dictionary = _leer_argumentos()

	if opciones.has("listar"):
		_imprimir_guion()
		get_tree().quit()
		return

	var pedido: String = String(opciones.get("plano", plano_por_defecto))
	var plano: Plano = _buscar(pedido)
	if plano == null:
		push_error("Modo captura: no existe el plano '%s'." % pedido)
		_imprimir_guion()
		get_tree().quit(1)
		return

	if opciones.has("duracion"):
		plano.duracion = float(opciones["duracion"])
	if opciones.has("cartela"):
		plano.cartela = String(opciones["cartela"])

	await _rodar(plano)


# ---------- Rodaje ----------

func _rodar(plano: Plano) -> void:
	print("\n[captura] plano '%s' -- %.1f s" % [plano.nombre, plano.duracion])
	print("[captura] %s" % plano.resumen)

	# El eje se fija ANTES de montar el nivel: PaletaAlma y TipografiaAlma leen
	# Alma.ruta_actual() en su _ready() y aplican el look sin animarlo. Si se
	# hiciera despues, los primeros 3 s del plano serian la transicion.
	Alma.forzar(plano.alma)
	_sembrar_progreso(plano)

	_plano = plano

	if plano.cartela != "":
		_mostrar_cartela(plano)
		await get_tree().create_timer(plano.duracion).timeout
		print("[captura] plano '%s' terminado" % plano.nombre)
		get_tree().quit()
		return

	var raiz: Node2D = _montar_nivel(plano)
	# Dos frames: uno para que corran los _ready() del nivel, otro para que la
	# camara del jugador ya tenga los limites que Nivel._ready() le deriva.
	await get_tree().process_frame
	await get_tree().process_frame

	var jugador: Jugador = raiz.get_node_or_null("Jugador") as Jugador
	if jugador == null:
		push_error("Modo captura: el nivel no tiene nodo Jugador.")
		get_tree().quit(1)
		return

	_jugador = jugador
	_terreno = raiz.get_node_or_null("Terreno") as TileMapLayer
	_limpiar_pantalla(jugador)
	_encuadrar(jugador, plano)
	_ocultar_nodos(raiz, plano)
	_colocar(jugador, raiz, plano)
	_equipar(jugador, plano)

	if plano.diario:
		_abrir_diario(raiz, plano)
	elif plano.terminal != "" and not plano.acercarse:
		_sentar_en_terminal(jugador, raiz, plano)
	else:
		if plano.terminal != "":
			_terminal = raiz.get_node_or_null("Terminales/%s" % plano.terminal) as TerminalCRT
		if plano.caminar != 0:
			Input.action_press("mover_der" if plano.caminar > 0 else "mover_izq")
			if plano.correr:
				Input.action_press("correr")

	if not is_nan(plano.alma_final):
		_programar_deriva(plano)

	await get_tree().create_timer(plano.duracion).timeout
	print("[captura] plano '%s' terminado" % plano.nombre)
	get_tree().quit()


## Instancia el nivel y lo retoca ANTES de anadirlo al arbol. Lo que se toca aqui
## es lo que los _ready() leen: una vez dentro del arbol ya es tarde.
func _montar_nivel(plano: Plano) -> Node2D:
	var escena: PackedScene = load(RUTA_NIVEL) as PackedScene
	var raiz: Node2D = escena.instantiate() as Node2D

	var jugador: Node = raiz.get_node_or_null("Jugador")
	if jugador != null:
		# Quita la etiqueta de depuracion de encima del personaje. Hay que ponerlo
		# antes del _ready(), que es quien la muestra.
		jugador.set("mostrar_estado", false)

	if not plano.apertura:
		# Se borra antes de entrar al arbol: si se dejara, su _ready() quitaria el
		# control al jugador y animaria la camara en mitad del plano.
		var apertura: Node = raiz.get_node_or_null("AperturaSadak")
		if apertura != null:
			raiz.remove_child(apertura)
			apertura.queue_free()

	add_child(raiz)
	return raiz


## Apaga nodos que estorban al encuadre. Se hace por plano y no borrando la capa
## del nivel: cuando el arte definitivo exista, basta con vaciar esta lista.
func _ocultar_nodos(raiz: Node2D, plano: Plano) -> void:
	for camino: String in plano.ocultar:
		var nodo: CanvasItem = raiz.get_node_or_null(camino) as CanvasItem
		if nodo == null:
			push_warning("Modo captura: no se pudo ocultar '%s'." % camino)
			continue
		nodo.visible = false


## Acerca la camara del jugador. La apertura Sadak anima su propio zoom, asi que
## los planos con apertura se quedan como esten: pisarlo romperia el plano 1.
func _encuadrar(jugador: Jugador, plano: Plano) -> void:
	if is_equal_approx(plano.zoom, 1.0) or plano.apertura:
		return
	var camara: Camera2D = jugador.get_node_or_null("Camara") as Camera2D
	if camara == null:
		push_warning("Modo captura: el jugador no tiene Camara.")
		return
	camara.zoom = Vector2(plano.zoom, plano.zoom)


## Un trailer no lleva HUD ni indicadores de depuracion encima.
func _limpiar_pantalla(jugador: Jugador) -> void:
	var hud: CanvasLayer = jugador.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	if jugador.etiqueta_estado != null:
		jugador.etiqueta_estado.visible = false


func _colocar(jugador: Jugador, raiz: Node2D, plano: Plano) -> void:
	if plano.jugador_tile < 0:
		return
	var terreno: TileMapLayer = raiz.get_node_or_null("Terreno") as TileMapLayer
	var altura: float = _altura_del_suelo(terreno, plano.jugador_tile)
	if is_nan(altura):
		push_warning("Modo captura: la columna %d no tiene suelo; no se mueve al jugador."
			% plano.jugador_tile)
		return
	var celda: int = terreno.tile_set.tile_size.x
	jugador.global_position = Vector2(plano.jugador_tile * celda + celda * 0.5, altura)
	jugador.velocity = Vector2.ZERO


## Y del borde superior del primer tile solido de la columna. El origen del
## jugador esta en los pies, asi que ese valor se le puede asignar directo.
func _altura_del_suelo(terreno: TileMapLayer, tile_x: int) -> float:
	if terreno == null or terreno.tile_set == null:
		return NAN
	var rejilla: Rect2i = terreno.get_used_rect()
	if tile_x < rejilla.position.x or tile_x >= rejilla.end.x:
		return NAN
	for tile_y: int in range(rejilla.position.y, rejilla.end.y):
		if terreno.get_cell_source_id(Vector2i(tile_x, tile_y)) != -1:
			return float(tile_y * terreno.tile_set.tile_size.y)
	return NAN


func _equipar(jugador: Jugador, plano: Plano) -> void:
	if plano.arma == "":
		return
	for i: int in jugador.arma.arsenal.size():
		if jugador.arma.arsenal[i].id == plano.arma:
			jugador.arma.equipar(i)
			return
	push_warning("Modo captura: no hay ningun arma con id '%s'." % plano.arma)


## Arranca la escena del CRT sin esperar a que el jugador camine hasta ella y
## pulse E. La terminal ya se encarga de sentarlo y de fijar su propia camara.
func _sentar_en_terminal(jugador: Jugador, raiz: Node2D, plano: Plano) -> void:
	var terminal: TerminalCRT = raiz.get_node_or_null(
		"Terminales/%s" % plano.terminal) as TerminalCRT
	if terminal == null:
		push_error("Modo captura: no existe la terminal '%s'." % plano.terminal)
		return
	terminal.iniciar(jugador)


## Cruza el eje en mitad del plano. Aqui SI se quiere la transicion animada de
## 3 s de PaletaAlma: es justo lo que el plano tiene que ensenar.
func _programar_deriva(plano: Plano) -> void:
	var reloj: SceneTreeTimer = get_tree().create_timer(plano.alma_en)
	reloj.timeout.connect(_al_derivar.bind(plano.alma_final))


func _al_derivar(valor: float) -> void:
	print("[captura] el eje cruza a %.2f" % valor)
	Alma.forzar(valor)


## Cartela a pantalla completa con la tipografia del diario. Monta un
## TipografiaAlma suelto: su _ready() lee Alma.ruta_actual() y aplica el tema,
## asi que la cartela sale en la misma letra que tendria el cuaderno.
func _mostrar_cartela(plano: Plano) -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	add_child(capa)

	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.04, 0.04, 0.047)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)

	var texto: Label = Label.new()
	texto.text = plano.cartela
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Margen lateral para que el texto no toque el borde del cuadro de 384 px.
	texto.offset_left = 40.0
	texto.offset_right = -40.0
	fondo.add_child(texto)

	# raiz se asigna ANTES de entrar al arbol: si no, _ready() sale sin aplicar
	# nada. Es el mismo fallo que tenia el diario (ui/diario/diario.gd).
	var tipo: TipografiaAlma = TipografiaAlma.new()
	tipo.raiz = fondo
	capa.add_child(tipo)


## Conduce al jugador durante el plano: golpes, saltos e interaccion.
##
## Las acciones se inyectan con parse_input_event() y NO con Input.action_press():
## el salto y el interactuar se leen en _unhandled_input(), y action_press solo
## cambia el estado que se consulta por sondeo, sin generar ningun evento. Con
## action_press el personaje no saltaria nunca y la terminal no se activaria.
func _process(delta: float) -> void:
	_soltar_vencidas(delta)

	if _plano == null:
		return
	_reloj_plano += delta

	# El movimiento se reafirma cada frame: al morir y reaparecer, el jugador
	# perdia el estado de la accion y se quedaba clavado en el punto de respawn.
	if _plano.caminar != 0 and not _plano.diario and not _interactuo:
		Input.action_press("mover_der" if _plano.caminar > 0 else "mover_izq")
		if _plano.correr:
			Input.action_press("correr")

	if _plano.atacar_cada > 0.0:
		_reloj_ataque -= delta
		if _reloj_ataque <= 0.0:
			_reloj_ataque = _plano.atacar_cada
			_pulsar("atacar", 0.05)

	if _plano.rodar_cada > 0.0:
		_reloj_rodar -= delta
		if _reloj_rodar <= 0.0:
			_reloj_rodar = _plano.rodar_cada
			_pulsar("rodar", 0.05)

	if _plano.saltar_en_abismos:
		_saltar_si_hay_abismo()

	if _terminal != null and not _interactuo and _jugador != null \
			and absf(_jugador.global_position.x - _terminal.global_position.x) < 20.0:
		_interactuo = true
		# Suelta el paso antes de pulsar E: si no, sigue "andando" mientras se sienta.
		Input.action_release("mover_der")
		Input.action_release("mover_izq")
		Input.action_release("correr")
		_pulsar("interactuar", 0.05)


func _soltar_vencidas(delta: float) -> void:
	for accion: String in _sostenidas.keys():
		var restante: float = float(_sostenidas[accion]) - delta
		if restante <= 0.0:
			_evento(accion, false)
			_sostenidas.erase(accion)
		else:
			_sostenidas[accion] = restante


func _evento(accion: String, pulsada: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = accion
	ev.pressed = pulsada
	Input.parse_input_event(ev)


## Pulsa una accion y la MANTIENE los segundos indicados.
##
## El salto hay que sostenerlo: el jugador tiene salto de altura variable y
## cortar_salto() multiplica el ascenso por factor_corte_salto (0.45) en cuanto
## se suelta. Pulsando y soltando en el mismo frame saltaba a media altura y no
## cruzaba el abismo.
func _pulsar(accion: String, segundos: float) -> void:
	if _sostenidas.has(accion):
		return
	_evento(accion, true)
	_sostenidas[accion] = segundos


## Salta cuando el camino se acaba: un abismo delante, o un escalon contra el
## que se ha quedado clavado. Mira UN tile por delante, no dos, para despegar
## justo en el canto; desde mas atras el salto se queda corto.
func _saltar_si_hay_abismo() -> void:
	if _jugador == null or _terreno == null or not _jugador.is_on_floor():
		return
	if _jugador.velocity.y < 0.0:
		return
	# Escalon: el terreno del nivel tiene desniveles de 16 px que lo frenan en seco.
	if _jugador.is_on_wall():
		_pulsar("saltar", 0.40)
		return
	var celda: int = _terreno.tile_set.tile_size.x
	var tile_x: int = int(floor(_jugador.global_position.x / float(celda)))
	var dir: int = 1 if _plano.caminar >= 0 else -1
	if is_nan(_altura_del_suelo(_terreno, tile_x + dir)):
		# tiempo_subida del jugador es 0.35 s: se sostiene un poco mas para que
		# el salto salga a altura completa.
		_pulsar("saltar", 0.40)


## Deja EstadoJuego como si se llevara un rato jugando. Las cifras son atrezo de
## rodaje: el diario las lee de la misma API que en una partida de verdad.
func _sembrar_progreso(plano: Plano) -> void:
	if plano.estadisticas.is_empty():
		return
	EstadoJuego.cargar({
		# Sin esta bandera el diario abre el menu minimo en vez del cuaderno.
		"flags": {EstadoJuego.BANDERA_DIARIO: true},
		"armas": [],
		"estadisticas": plano.estadisticas,
	})


## Abre el diario y lo deja en la pestana pedida. El diario pausa el arbol, pero
## el temporizador de fin de plano sigue corriendo: create_timer ignora la pausa.
func _abrir_diario(raiz: Node2D, plano: Plano) -> void:
	var diario: Diario = raiz.get_node_or_null("Diario") as Diario
	if diario == null:
		push_error("Modo captura: el nivel no tiene nodo Diario.")
		return
	diario.abrir()
	if diario.pestanas != null:
		diario.pestanas.current_tab = plano.pestana


# ---------- Linea de comandos ----------

## Lee los argumentos de despues del "--". Acepta "--clave=valor" y "--bandera".
func _leer_argumentos() -> Dictionary:
	var opciones: Dictionary = {}
	for bruto: String in OS.get_cmdline_user_args():
		var arg: String = bruto.lstrip("-")
		if arg.contains("="):
			var partes: PackedStringArray = arg.split("=", true, 1)
			opciones[partes[0]] = partes[1]
		else:
			opciones[arg] = true
	return opciones


func _buscar(nombre: String) -> Plano:
	for plano: Plano in _planos():
		if plano.nombre == nombre:
			return plano
	return null


func _imprimir_guion() -> void:
	print("\nPlanos disponibles (godot --path juego res://tools/captura.tscn -- --plano=NOMBRE):\n")
	for plano: Plano in _planos():
		print("  %-10s %4.1f s  %s" % [plano.nombre, plano.duracion, plano.resumen])
	print("")
