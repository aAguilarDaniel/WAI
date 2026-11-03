# Herramienta: genera el nivel 6, los hornos: la fundicion que alimenta el
# edificio. La ultima parada antes del relicario.
#
#   godot --headless --path juego res://tools/generar_nivel_06.tscn
#
# Lo nuevo son las PRENSAS: pistones que caen del techo con un ciclo fijo.
#
#   A. Llegada, un CRT                                 -> respirar
#   B. Pasillo con tres prensas desfasadas              -> leer el aviso, pasar
#                                                          una, esperar, pasar otra
#   C. La sala de colada: drones, torreta y enemigos    -> todo lo aprendido
#   D. Pasillo de cuatro prensas en cadena y un dron     -> el ritmo, bajo presion
#   E. Salida y ultimo CRT                              -> nivel 7, el relicario
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_06/nivel_06.tscn"
const RUTA_SIGUIENTE: String = "res://levels/nivel_07/nivel_07.tscn"
const INTERIOR: String = "res://art/placeholder/interior/"
const MUSICA: String = "res://audio/musica/bruh_150.mp3"

const ANCHO_TILES: int = 148
const ALTO_TILES: int = 20

const HUECOS: Array = [
	[2, 6, 16, 15],      # A
	[16, 10, 50, 15],    # B. pasillo de prensas: 5 filas
	[50, 3, 90, 15],     # C. sala de colada
	[90, 10, 124, 15],   # D. segundo pasillo de prensas
	[124, 6, 146, 15],   # E. salida
]

const BLOQUES: Array = [
	[55, 13, 56, 15],    # C. peldano
	[86, 13, 88, 15],    # C. cobertura frente a la torreta
]

const PASARELAS: Array = [
	[56, 62, 13], [64, 70, 11], [72, 78, 13],
]

const FRANJAS: Array = [
	[23, 26, 15], [29, 32, 15], [35, 38, 15],
	[95, 98, 15], [100, 103, 15], [105, 108, 15], [110, 113, 15],
]
const ARCOS: Array = []

## [tile, fila del techo, filas hasta el suelo, desfase]
const PRENSAS: Array = [
	[24, 10, 5, 0.0], [30, 10, 5, 0.7], [36, 10, 5, 1.4],
	[96, 10, 5, 0.0], [101, 10, 5, 0.45], [106, 10, 5, 0.9], [111, 10, 5, 1.35],
]

const TERMINALES: Array = [
	[8, 15, "nivel_06_crt_01"], [52, 15, "nivel_06_crt_02"], [128, 15, "nivel_06_crt_03"],
]

const ENEMIGOS: Array = [
	[44, 15, -1], [60, 15, 1], [80, 15, -1], [134, 15, -1],
]

const TORRETAS: Array = [
	[83, 3, true], [139, 15, false],
]

const DRONES: Array = [
	[62, 6], [76, 6], [118, 11],
]

const RECOGIBLES: Array = [
	[67, 11, "venda", 1], [92, 15, "venda", 1], [131, 15, "venda", 1],
]

const PISTAS: Array = []

const INICIO: Vector2i = Vector2i(4, 15)
const SALIDA: Vector2i = Vector2i(143, 15)

const DECORACION: Array = [
	[3, 15, "barril", false, -3], [11, 13, "ventanal", false, -5],
	[18, 15, "tuberia", false, -3], [42, 15, "barril", false, -3],
	[58, 12, "ventanal", false, -5], [74, 12, "ventanal", false, -5],
	[66, 15, "tuberia", false, -3], [84, 15, "barril", true, -3],
	[92, 15, "tuberia", false, -3], [120, 15, "barril", false, -3],
	[132, 13, "ventanal", false, -5], [141, 15, "consola", true, -3],
]

const LAMPARAS: Array = [
	[8, 6], [20, 10], [44, 10], [54, 3], [70, 3], [84, 3], [116, 10], [130, 6], [140, 6],
]

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var raiz: Node2D = C.raiz("Nivel06")
	raiz.set("margen_superior", 0)
	raiz.set("margen_inferior", 24)
	raiz.set("encuadre_camara", Vector2(0.0, -14.0))
	raiz.set("ambiente", "ambiente_interior")
	raiz.set("volumen_ambiente", -11.0)

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
	C.polvo(raiz, Color(1.0, 0.6, 0.35, 0.22), 30)
	C.paleta(raiz)
	C.apertura(raiz, "Entrada", "", Vector2(0.75, 0.75), Vector2(60.0, -20.0), 2.2)

	C.guardar(raiz, RUTA_NIVEL)
	print("  nivel 6: %d tiles  enemigos: %d  torretas: %d  drones: %d" % [
		ANCHO_TILES, ENEMIGOS.size(), TORRETAS.size(), DRONES.size()])
	get_tree().quit()
