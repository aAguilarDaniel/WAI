# Herramienta: genera la sala del jefe secreto. Solo se llega si no queda un
# enemigo vivo en todo el juego: el ultimo monitor del relicario lleva aqui en
# vez de al final (PuertaNivel.destino_secreto + RegistroEnemigos).
#
#   godot --headless --path juego res://tools/generar_nivel_secreto.tscn
#
# Un pasillo y una sala de un cuadro de ancho (384 px) con un CRT enorme al fondo.
# En el CRT hay una figura sentada. Al entrar, sale.
#
# Volver a correr esto PISA el nivel: si ya lo editaron a mano, no lo ejecuten.
extends Node

const C = preload("res://tools/constructor_nivel.gd")

const RUTA_NIVEL: String = "res://levels/secreto/nivel_secreto.tscn"
const RUTA_FINAL: String = "res://ui/final/final.tscn"
const MUSICA: String = "res://audio/musica_secreta.wav"

const ANCHO_TILES: int = 40
const ALTO_TILES: int = 20
const ARENA_X0: int = 12
const ARENA_X1: int = 36
const SUELO: int = 15

const HUECOS: Array = [
	[2, 11, ARENA_X0, 15],          # pasillo: 4 filas, el alto de la compuerta
	[ARENA_X0, 3, ARENA_X1, 15],    # la sala: 12 filas
]

func _ready() -> void:
	var conjunto: TileSet = load(C.RUTA_TILESET) as TileSet
	var raiz: Node2D = C.raiz("NivelSecreto")
	raiz.set("margen_superior", 0)
	raiz.set("margen_inferior", 24)
	raiz.set("encuadre_camara", Vector2(0.0, -30.0))
	raiz.set("ambiente", "crt_zumbido")
	raiz.set("volumen_ambiente", -14.0)

	C.fondo(raiz, "FondoInterior", "res://shaders/interior.gdshader")
	var deco: Node2D = C.contenedor(raiz, "Decoracion")
	var centro: Vector2 = Vector2((ARENA_X0 + ARENA_X1) * 8.0, SUELO * 16.0)
	C.objeto(deco, "res://art/placeholder/props/pantalla_secreta.png", centro, -4)
	C.luz(deco, centro + Vector2(0.0, -52.0), Color(0.42, 0.86, 0.52), Vector2(3.4, 2.4), 1, 0.35, "grande")
	C.luz(deco, Vector2(5 * 16, 12 * 16), Color(0.42, 0.86, 0.52), Vector2(0.6, 0.5), 2, 0.4)

	var terreno: TileMapLayer = C.terreno(raiz, conjunto)
	C.excavar(terreno, ANCHO_TILES, ALTO_TILES, HUECOS)
	C.zona_mortal(raiz, ANCHO_TILES * 16.0, ALTO_TILES * 16.0 + 40.0)
	C.instanciar("res://actors/player/jugador.tscn", raiz, "Jugador", Vector2(4 * 16, SUELO * 16))

	var arena: Node2D = Node2D.new()
	arena.name = "Arena"
	arena.set_script(load("res://systems/jefe/arena_jefe.gd"))
	arena.set("bandera", "jefe_reflejo_derrotado")
	arena.set("musica", load(MUSICA))
	arena.set("volumen_musica", -4.0)
	arena.set("limite_camara", Rect2(ARENA_X0 * 16, 0, (ARENA_X1 - ARENA_X0) * 16, 0))
	arena.set("titulo_entrada", "El reflejo")
	# BORRADORES (docs/TEXTOS_PENDIENTES.md). Se cambian en el inspector de Arena.
	arena.set("entrada_humana", "Tenía mi cara. Cuando cayó se sentó como me siento yo frente a las pantallas. No supe por quién estaba llorando.")
	arena.set("entrada_ambigua", "Hacía lo que yo hacía, un instante después. O un instante antes. Ya no lo puedo comprobar.")
	arena.set("entrada_maquina", "Copia no autorizada eliminada. Original: sin verificar.")
	raiz.add_child(arena)

	var reflejo: Node = C.instanciar("res://actors/bosses/reflejo.tscn", arena, "Reflejo",
		centro + Vector2(0.0, -40.0))
	reflejo.set("limite_izq", float(ARENA_X0 * 16))
	reflejo.set("limite_der", float(ARENA_X1 * 16))
	C.instanciar("res://systems/jefe/compuerta.tscn", arena, "CompuertaEntrada",
		Vector2(ARENA_X0 * 16 - 8, SUELO * 16))
	# Al vencerlo, la pantalla (ya vacia) es la salida.
	var puerta: Node = C.instanciar("res://systems/transicion/puerta_nivel.tscn", arena,
		"PuertaSalida", centro)
	puerta.set("destino", RUTA_FINAL)
	puerta.set("paso_hacia_dentro", 4.0)

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

	C.instanciar("res://ui/diario/diario.tscn", raiz, "Diario", Vector2.ZERO)
	C.polvo(raiz, Color(0.6, 1.0, 0.7, 0.10), 18)
	C.paleta(raiz)
	C.guardar(raiz, RUTA_NIVEL)
	get_tree().quit()
