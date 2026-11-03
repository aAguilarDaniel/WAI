# Herramienta: genera el nivel 5, el archivo: salas de cintas y servidores
# apilados hasta el techo. Se llega por la puerta de la cornisa (nivel 4).
#
#   godot --headless --path juego res://tools/generar_nivel_05.tscn
#
# Lo nuevo es el DRON: la primera amenaza que viene de arriba.
#
#   A. Llegada, un CRT                                  -> respirar
#   B. Sala alta con UN dron solo y estanterias          -> leer el picado: se
#                                                           coloca encima, apunta
#                                                           y cae recto
#   C. Pasillo: dron, enemigo y torreta juntos            -> mirar arriba y adelante
#   D. Gran nave con pasarelas, dos drones arriba         -> por abajo o por arriba
#   E. Salida vigilada                                    -> nivel 6
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_05/nivel_05.tscn"
const RUTA_SIGUIENTE: String = "res://levels/nivel_06/nivel_06.tscn"
const INTERIOR: String = "res://art/placeholder/interior/"
const MUSICA: String = "res://audio/musica/bruh_150.mp3"

const ANCHO_TILES: int = 132
const ALTO_TILES: int = 20

const HUECOS: Array = [
	[2, 6, 18, 15],      # A
	[18, 3, 52, 15],     # B. sala alta, 12 filas
	[52, 10, 70, 15],    # C. pasillo, 5 filas
	[70, 2, 110, 15],    # D. gran nave
	[110, 10, 130, 15],  # E. salida
]

const BLOQUES: Array = [
	[26, 13, 28, 15], [40, 13, 42, 15],   # B. estanterias: cobertura
	[73, 13, 74, 15],                     # D. peldano a la primera pasarela
]

## Pasarelas de un solo sentido. La ruta alta de la nave sube de 2 en 2.
const PASARELAS: Array = [
	[34, 38, 13],                         # B. a 2 tiles del suelo (regla de CLAUDE.md §7)
	[74, 80, 13], [82, 88, 11], [90, 96, 9], [98, 104, 11],
]

const FRANJAS: Array = []
const ARCOS: Array = []

const TERMINALES: Array = [
	[8, 15, "nivel_05_crt_01"], [72, 15, "nivel_05_crt_02"],
]

const ENEMIGOS: Array = [
	[46, 15, -1], [66, 15, -1], [79, 15, 1], [105, 15, -1], [124, 15, -1],
]

const TORRETAS: Array = [
	[62, 10, true], [93, 15, false], [116, 10, true],
]

## [tile, fila en la que flota]
const DRONES: Array = [
	[31, 8], [57, 11], [86, 5], [101, 5], [120, 11],
]

const RECOGIBLES: Array = [
	[14, 15, "venda", 1], [93, 9, "venda", 1], [113, 15, "venda", 1],
]

const PISTAS: Array = []
const PRENSAS: Array = []

const INICIO: Vector2i = Vector2i(4, 15)
const SALIDA: Vector2i = Vector2i(127, 15)

const DECORACION: Array = [
	[3, 15, "rack", false, -3], [12, 13, "ventanal", false, -5],
	[20, 15, "rack", false, -3], [22, 15, "rack", false, -3], [33, 15, "consola", false, -3],
	[36, 15, "rack", true, -3], [44, 15, "rack", false, -3], [48, 15, "rack", false, -3],
	[54, 15, "tuberia", false, -3], [68, 15, "servidor_caido", false, -3],
	[76, 12, "ventanal", false, -5], [96, 12, "ventanal", false, -5],
	[84, 15, "rack", false, -3], [88, 15, "rack", true, -3], [107, 15, "consola", true, -3],
	[114, 15, "barril", false, -3], [122, 15, "rack", false, -3],
]

const LAMPARAS: Array = [
	[10, 6], [24, 3], [38, 3], [48, 3], [60, 10], [78, 2], [92, 2], [104, 2], [118, 10],
]

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var raiz: Node2D = C.raiz("Nivel05")
	raiz.set("margen_superior", 0)
	raiz.set("margen_inferior", 24)
	raiz.set("encuadre_camara", Vector2(0.0, -14.0))
	raiz.set("ambiente", "ambiente_interior")
	raiz.set("volumen_ambiente", -11.0)
	raiz.set("musica", load(MUSICA))
	raiz.set("volumen_musica", -12.0)

	C.fondo(raiz, "FondoInterior", "res://shaders/interior.gdshader")
	C.parallax(raiz, [
		["CapaNave", INTERIOR + "capa_i1_nave.png", 0.12, -50],
		["CapaRacks", INTERIOR + "capa_i2_racks.png", 0.32, -40],
		["CapaColumnas", INTERIOR + "capa_i3_columnas.png", 0.58, -30],
		["CapaCables", INTERIOR + "capa_i4_cables.png", 1.25, 20],
	])
	C.decoracion_interior(raiz, DECORACION, LAMPARAS)
	var terreno: TileMapLayer = C.terreno(raiz, conjunto)
	C.excavar(terreno, ANCHO_TILES, ALTO_TILES, HUECOS, BLOQUES, FRANJAS, PASARELAS)
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, ALTO_TILES * 16.0 + 40.0)

	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador",
		Vector2(INICIO.x * 16, INICIO.y * 16))
	var peligros: Node2D = C.contenedor(raiz, "Peligros")
	C.arcos(peligros, ARCOS)
	C.prensas(peligros, PRENSAS)
	C.terminales(raiz, TERMINALES)
	var enemigos: Node2D = C.contenedor(raiz, "Enemigos")
	C.enemigos(enemigos, ENEMIGOS)
	C.torretas(enemigos, TORRETAS)
	C.drones(enemigos, DRONES)
	C.recogibles(raiz, RECOGIBLES)
	C.pistas(raiz, PISTAS)
	var salida: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"Salida", Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16))
	salida.set("destino", RUTA_SIGUIENTE)
	var deco: Node = raiz.get_node("Decoracion")
	C.objeto(deco, "res://art/placeholder/props/ascensor.png",
		Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16), -3)
	C.luz(deco, Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16 - 56), Color(0.42, 0.86, 0.52),
		Vector2(0.4, 0.3), 0, 0.8)

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(0.7, 0.9, 1.0, 0.12), 24)
	C.paleta(raiz)
	C.apertura(raiz, "Entrada", "", Vector2(0.75, 0.75), Vector2(60.0, -20.0), 2.2)

	C.guardar(raiz, RUTA_NIVEL)
	print("  nivel 5: %d tiles  enemigos: %d  torretas: %d  drones: %d" % [
		ANCHO_TILES, ENEMIGOS.size(), TORRETAS.size(), DRONES.size()])
	get_tree().quit()
