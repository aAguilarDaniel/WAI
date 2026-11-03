# Lleva la cuenta de QUE enemigos concretos han muerto, no de cuantos. Lo usan
# los enemigos (al nacer y al morir) y la puerta del ultimo monitor, que abre el
# camino secreto si no queda ninguno vivo en todo el juego.
#
# Clase de funciones estaticas, no autoload: el estado vive en las banderas de
# EstadoJuego, que ya viajan en el JSON de guardado sin cambiar su formato.
#
# Por que por enemigo y no con la estadistica "enemigos_eliminados": esa sube cada
# vez que algo muere, y al retomar una partida el nivel se recarga entero. Sin
# esto se podria llegar al total matando dos veces a los mismos.
class_name RegistroEnemigos
extends RefCounted

## Los niveles que cuentan, en orden. El secreto pide vaciarlos TODOS.
const NIVELES: PackedStringArray = [
	"res://levels/nivel_01/nivel_01.tscn",
	"res://levels/nivel_02/nivel_02.tscn",
	"res://levels/nivel_03/nivel_03.tscn",
	"res://levels/nivel_04/nivel_04.tscn",
	"res://levels/nivel_05/nivel_05.tscn",
	"res://levels/nivel_06/nivel_06.tscn",
]
## Contenedor de cada nivel donde viven los enemigos.
const CONTENEDOR: String = "Enemigos"

static var _total_cacheado: int = -1

static func clave(nivel: String, nombre: String) -> String:
	return "eliminado:%s:%s" % [nivel.get_file().get_basename(), nombre]

## La clave de un enemigo concreto, a partir de su nodo. Usa el nivel al que
## pertenece (su owner), asi la clave no depende de donde este instanciado.
static func clave_de(enemigo: Node) -> String:
	var nivel: String = enemigo.owner.scene_file_path if enemigo.owner != null else ""
	return clave(nivel, enemigo.name)

static func esta_eliminado(enemigo: Node) -> bool:
	return EstadoJuego.bandera(clave_de(enemigo))

static func marcar(enemigo: Node) -> void:
	EstadoJuego.fijar_bandera(clave_de(enemigo), true)

## Cuantos enemigos hay en todo el juego. Se lee de las escenas SIN
## instanciarlas (SceneState), asi que anadir uno en el editor ya cuenta.
static func total() -> int:
	if _total_cacheado >= 0:
		return _total_cacheado
	var cuenta: int = 0
	for ruta: String in NIVELES:
		cuenta += _enemigos_de(ruta).size()
	_total_cacheado = cuenta
	return cuenta

static func eliminados() -> int:
	var cuenta: int = 0
	for ruta: String in NIVELES:
		for nombre: String in _enemigos_de(ruta):
			if EstadoJuego.bandera(clave(ruta, nombre)):
				cuenta += 1
	return cuenta

static func todos_eliminados() -> bool:
	return total() > 0 and eliminados() >= total()

## Nombres de los hijos directos del contenedor de enemigos de un nivel.
static func _enemigos_de(ruta: String) -> PackedStringArray:
	var nombres: PackedStringArray = []
	if not ResourceLoader.exists(ruta):
		return nombres
	var escena: PackedScene = load(ruta) as PackedScene
	var estado: SceneState = escena.get_state()
	for i: int in estado.get_node_count():
		if str(estado.get_node_path(i, true)) == "./" + CONTENEDOR:
			nombres.append(str(estado.get_node_name(i)))
	return nombres
