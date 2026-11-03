# Herramienta: genera el nivel 7, el relicario (era el 5 antes de los hornos y el archivo). La antesala, la arena del
# Custodio y la sala del monitor donde termina el juego.
#
#   godot --headless --path juego res://tools/generar_nivel_07.tscn
#
#   A. Antesala: CRT y dos vendas            -> prepararse (y saber que viene algo)
#   B. Pasillo                               -> el silencio antes
#   C. La arena: 24 tiles, un cuadro exacto  -> el jefe (Hito 7)
#   D. Sala del monitor                      -> el final (Hito 8)
#
# La arena mide 384 px de ancho a proposito: durante el combate la camara se
# encierra en ella (ArenaJefe) y se ve entera, jefe y jugador a la vez.
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_07/nivel_07.tscn"
const RUTA_FINAL: String = "res://ui/final/final.tscn"
## Si no queda un solo enemigo vivo en el juego, el monitor lleva aqui.
const RUTA_SECRETA: String = "res://levels/secreto/nivel_secreto.tscn"
const INTERIOR: String = "res://art/placeholder/interior/"
const MUSICA_JEFE: String = "res://audio/musica_jefe.wav"

const ANCHO_TILES: int = 100
const ALTO_TILES: int = 20

## La arena: [x0, x1) en tiles y filas de techo y suelo.
const ARENA_X0: int = 40
const ARENA_X1: int = 64
const ARENA_TECHO: int = 4
const SUELO: int = 15

const HUECOS: Array = [
	[2, 8, 30, 15],                                  # A. antesala
	[30, 11, ARENA_X0, 15],                          # B. pasillo, 4 filas
	[ARENA_X0, ARENA_TECHO, ARENA_X1, 15],           # C. arena, 11 filas
	[ARENA_X1, 11, 72, 15],                          # D. pasillo de salida
	[72, 3, 98, 15],                                 # D. sala del monitor
]

const TERMINALES: Array = [[22, 15, "nivel_07_crt_01"]]
const RECOGIBLES: Array = [[12, 15, "venda", 1], [15, 15, "venda", 1]]
## El rayo del jefe se esquiva agachado: si no lo aprendieron en el nivel 3, la
## arena se lo vuelve a ofrecer (y la pista no sale si ya lo saben).
const PISTAS: Array = [[46, 15, "agachar"]]

const DECORACION: Array = [
	[5, 15, "rack", false, -3], [9, 13, "ventanal", false, -5], [18, 15, "consola", false, -3],
	[27, 15, "rack", true, -3], [33, 15, "tuberia", false, -3],
	[44, 13, "ventanal", false, -5], [59, 13, "ventanal", false, -5],
	[42, 15, "servidor_caido", false, -3], [61, 15, "servidor_caido", true, -3],
	[76, 15, "rack", false, -3], [95, 15, "rack", true, -3],
	[80, 13, "muro_monitores", false, -5],
]
const LAMPARAS: Array = [[8, 8], [20, 8], [35, 11], [78, 3], [94, 3]]

const INICIO: Vector2i = Vector2i(4, 15)
const MONITOR: int = 88

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var raiz: Node2D = C.raiz("Nivel07")
	raiz.set("margen_superior", 0)
	raiz.set("margen_inferior", 24)
	raiz.set("encuadre_camara", Vector2(0.0, -20.0))
	raiz.set("ambiente", "ambiente_interior")
	raiz.set("volumen_ambiente", -14.0)

	C.fondo(raiz, "FondoInterior", "res://shaders/interior.gdshader")
	C.parallax(raiz, [
		["CapaNave", INTERIOR + "capa_i1_nave.png", 0.12, -50],
		["CapaColumnas", INTERIOR + "capa_i3_columnas.png", 0.5, -30],
		["CapaCables", INTERIOR + "capa_i4_cables.png", 1.25, 20],
	])
	var deco: Node2D = C.decoracion_interior(raiz, DECORACION, LAMPARAS)
	var terreno: TileMapLayer = C.terreno(raiz, conjunto)
	C.excavar(terreno, ANCHO_TILES, ALTO_TILES, HUECOS, [], [[ARENA_X0, ARENA_X1, SUELO]])
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, ALTO_TILES * 16.0 + 40.0)

	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO.x * 16, INICIO.y * 16))
	C.terminales(raiz, TERMINALES)
	C.recogibles(raiz, RECOGIBLES)
	C.pistas(raiz, PISTAS)
	_arena(raiz)

	# El monitor del final: lo unico encendido de la sala. Se entra andando.
	var pie: Vector2 = Vector2(MONITOR * 16 + 8, SUELO * 16)
	C.objeto(deco, "res://art/placeholder/props/origen.png", pie, -3)
	C.luz(deco, pie + Vector2(0.0, -46.0), Color(0.42, 0.86, 0.52), Vector2(2.0, 1.6), 0, 0.5, "grande")
	var puerta: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"Monitor", pie)
	puerta.set("destino", RUTA_FINAL)
	puerta.set("destino_secreto", RUTA_SECRETA)
	puerta.set("paso_hacia_dentro", 6.0)

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(1.0, 0.7, 0.6, 0.12), 20)
	C.paleta(raiz)
	C.apertura(raiz, "Entrada", "", Vector2(0.8, 0.8), Vector2(40.0, -20.0), 2.0)

	C.guardar(raiz, RUTA_NIVEL)
	print("  nivel 7: arena %d-%d" % [ARENA_X0, ARENA_X1])
	get_tree().quit()

func _arena(raiz: Node2D) -> void:
	var arena: Node2D = Node2D.new()
	arena.name = "Arena"
	arena.set_script(load("res://systems/jefe/arena_jefe.gd"))
	arena.set("musica", load(MUSICA_JEFE))
	arena.set("limite_camara", Rect2(ARENA_X0 * 16, ARENA_TECHO * 16 - 40,
		(ARENA_X1 - ARENA_X0) * 16, 0))
	# BORRADORES. El texto es del equipo (CLAUDE.md §5): reemplacenlos en el
	# inspector del nodo Arena. Ver docs/TEXTOS_PENDIENTES.md.
	arena.set("entrada_humana", "Cuando cayó, sus manos quedaron abiertas hacia mí. No sé si me estaba atacando o me estaba pidiendo algo. Le cerré los dedos uno a uno. Me temblaban las mías.")
	arena.set("entrada_ambigua", "Guardaba la puerta y ya no la guarda. En su pantalla, un instante antes de apagarse, había una figura sentada. Podía ser yo. Podía ser cualquiera.")
	arena.set("entrada_maquina", "Obstáculo eliminado. Su núcleo y el mío emitían en la misma frecuencia. Registro la coincidencia. No la clasifico.")
	raiz.add_child(arena)

	var jefe: Node = C.instanciar("res://actors/bosses/custodio.tscn", arena, "Custodio",
		Vector2(int(ARENA_X1 - 5) * 16, SUELO * 16))
	jefe.set("limite_izq", float(ARENA_X0 * 16))
	jefe.set("limite_der", float(ARENA_X1 * 16))
	jefe.set("techo_y", float(ARENA_TECHO * 16))
	C.instanciar("res://systems/jefe/compuerta.tscn", arena, "CompuertaEntrada",
		Vector2(ARENA_X0 * 16 - 8, SUELO * 16))
	C.instanciar("res://systems/jefe/compuerta.tscn", arena, "CompuertaSalida",
		Vector2(ARENA_X1 * 16 + 8, SUELO * 16))

	var disparador: Area2D = Area2D.new()
	disparador.name = "Disparador"
	disparador.collision_layer = 0
	disparador.collision_mask = 2
	disparador.position = Vector2((ARENA_X0 + 3) * 16, SUELO * 16 - 32)
	var forma: CollisionShape2D = CollisionShape2D.new()
	forma.name = "Forma"
	var caja: RectangleShape2D = RectangleShape2D.new()
	caja.size = Vector2(16, 64)
	forma.shape = caja
	disparador.add_child(forma)
	arena.add_child(disparador)
