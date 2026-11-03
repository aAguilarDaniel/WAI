# Herramienta: genera el nivel 3, los conductos de refrigeracion bajo la nave.
# Se llega por el ascensor del santuario del nivel 2.
#
#   godot --headless --path juego res://tools/generar_nivel_03.tscn
#
# Interior, descrito por HUECOS como el nivel 2 (ConstructorNivel.excavar). Una
# cosa nueva por tramo, igual que en los dos primeros:
#
#   A. Llegada del ascensor, un CRT                    -> respirar
#   B. Pasillo con una torreta en el techo y cobertura  -> leer un disparo: la
#                                                          mira se congela antes
#                                                          de disparar
#   C. Conducto de un tile de alto                     -> agacharse (el juego no
#                                                          lo ensenaba y el jefe
#                                                          lo exige)
#   D. Pozo con pasarelas en zigzag y una torreta      -> subir bajo fuego
#   E. Galeria alta: CRT, dos enemigos y un arco        -> todo lo anterior junto
#   F. Caida a la sala de torretas                      -> cruzar fuego cruzado
#   G. La escotilla a la azotea                         -> nivel 4
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/nivel_03/nivel_03.tscn"
const RUTA_SIGUIENTE: String = "res://levels/nivel_04/nivel_04.tscn"
const INTERIOR: String = "res://art/placeholder/interior/"
const MUSICA: String = "res://audio/musica/bruh_150.mp3"

const ANCHO_TILES: int = 180
const ALTO_TILES: int = 20

## Aire: [x0, y0, x1, y1) en tiles. La fila y1 es el suelo de ese hueco.
const HUECOS: Array = [
	[2, 6, 20, 15],      # A. llegada: 9 filas
	[20, 10, 48, 15],    # B. pasillo de la primera torreta: 5 filas
	[48, 14, 60, 15],    # C. conducto: UNA fila (16 px). De pie no se pasa (24 px)
	[60, 1, 72, 15],     # D. pozo de subida: techo a la altura del de la galeria, o el ultimo salto se da con la cabeza
	[72, 1, 110, 5],     # E. galeria alta, suelo en la fila 5
	[110, 1, 118, 15],   # F. caida a la sala
	[118, 5, 160, 15],   # F. sala de torretas: 10 filas
	[160, 10, 178, 15],  # G. salida
]

## Coberturas y peldanos. Ninguno a mas de 2 tiles de donde se sube.
const BLOQUES: Array = [
	[29, 13, 31, 15],    # B. cobertura frente a la torreta
	[38, 13, 39, 15],    # B. segunda cobertura
	[124, 13, 126, 15],  # F. cobertura
	[137, 13, 139, 15],  # F. peldano hacia la pasarela
]

## Pasarelas de un solo sentido: [x0, x1, fila]. Las del pozo suben de 2 en 2.
const PASARELAS: Array = [
	[61, 65, 13], [67, 71, 11], [61, 65, 9], [67, 71, 7],
	[139, 147, 11],
]

const FRANJAS: Array = [[88, 92, 5], [58, 60, 15], [48, 50, 15]]

## [tile, fila del suelo, filas de alto, desfase]
const ARCOS: Array = [[90, 5, 4, 0.0]]

const TERMINALES: Array = [
	[9, 15, "nivel_03_crt_01"], [76, 5, "nivel_03_crt_02"], [156, 15, "nivel_03_crt_03"],
]

## [tile, fila del suelo, direccion]
const ENEMIGOS: Array = [
	[44, 15, -1],
	[83, 5, 1], [101, 5, -1],
	[131, 15, 1], [150, 15, -1],
]

## [tile, fila, colgada]. Colgada: la fila es la primera de aire bajo el techo.
const TORRETAS: Array = [
	[34, 10, true],      # B
	[64, 1, true],       # D, dispara al que sube
	[128, 5, true], [146, 5, true],  # F
]

const RECOGIBLES: Array = [
	[15, 15, "venda", 1],
	[99, 5, "venda", 1],
	[143, 11, "venda", 1],
]

## [tile, fila del suelo, accion]
const PISTAS: Array = [[46, 15, "agachar"]]

const INICIO: Vector2i = Vector2i(4, 15)
const SALIDA: Vector2i = Vector2i(174, 15)

const DECORACION: Array = [
	[3, 15, "ascensor", false, -3], [12, 13, "ventanal", false, -5],
	[22, 15, "tuberia", false, -3], [26, 15, "rack", false, -3], [42, 15, "rack", true, -3],
	[62, 15, "servidor_caido", false, -3],
	[74, 5, "consola", false, -3], [86, 5, "rack", false, -3], [95, 5, "tuberia", false, -3],
	[106, 5, "rack", true, -3],
	[120, 15, "barril", false, -3], [134, 15, "rack", false, -3], [152, 15, "consola", true, -3],
	[129, 12, "ventanal", false, -5], [148, 12, "ventanal", false, -5],
	[163, 15, "tuberia", false, -3], [168, 15, "barril", false, -3],
]

const LAMPARAS: Array = [
	[8, 6], [16, 6], [25, 10], [41, 10], [80, 1], [96, 1], [104, 1],
	[122, 5], [136, 5], [154, 5], [166, 10],
]

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var raiz: Node2D = C.raiz("Nivel03")
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
	C.terminales(raiz, TERMINALES)
	var enemigos: Node2D = C.contenedor(raiz, "Enemigos")
	C.enemigos(enemigos, ENEMIGOS)
	C.torretas(enemigos, TORRETAS)
	C.recogibles(raiz, RECOGIBLES)
	C.pistas(raiz, PISTAS)
	var salida: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", raiz,
		"Escotilla", Vector2(SALIDA.x * 16 + 8, SALIDA.y * 16))
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
	print("  nivel 3: %d tiles  enemigos: %d  torretas: %d" % [
		ANCHO_TILES, ENEMIGOS.size(), TORRETAS.size()])
	get_tree().quit()
