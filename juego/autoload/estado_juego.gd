# Progreso narrativo: banderas, misiones, armas obtenidas, entradas del diario y
# estadísticas. Autoload global "EstadoJuego".
# No contiene lógica de combate ni escribe en disco: de eso se encarga Guardado.
extends Node

## Alguna bandera narrativa cambió de valor (ej. "diario_obtenido").
signal bandera_cambiada(nombre: String, valor: bool)

## El jugador recogió un arma nueva. El diario escucha esto para escribir su entrada.
signal arma_obtenida(id_arma: String)

## Una misión de la bitácora cambió de estado.
signal mision_actualizada(id_mision: String)

## Se escribió una entrada nueva en el diario.
signal entrada_agregada(indice: int)

const BANDERA_DIARIO: String = "diario_obtenido"

var banderas: Dictionary = {}
var armas_obtenidas: Array[String] = []
## Cada entrada: { "titulo": String, "texto": String, "origen": String }
var entradas: Array[Dictionary] = []
var estadisticas: Dictionary = {
	"muertes": 0,
	"enemigos_eliminados": 0,
	"enemigos_evitados": 0,
	"tiempo_seg": 0,
}

var _tiempo_acumulado: float = 0.0

func _process(delta: float) -> void:
	# El tiempo no corre con el juego pausado: process_mode del autoload es el normal.
	_tiempo_acumulado += delta
	estadisticas["tiempo_seg"] = int(_tiempo_acumulado)

# --- Banderas ---

func bandera(nombre: String) -> bool:
	return banderas.get(nombre, false)

func fijar_bandera(nombre: String, valor: bool = true) -> void:
	if bandera(nombre) == valor:
		return
	banderas[nombre] = valor
	bandera_cambiada.emit(nombre, valor)

func tiene_diario() -> bool:
	return bandera(BANDERA_DIARIO)

# --- Armas y entradas ---

## Registra un arma recogida y escribe su entrada del diario, si tiene texto.
func registrar_arma(arma: ArmaData) -> void:
	if arma == null or armas_obtenidas.has(arma.id):
		return
	armas_obtenidas.append(arma.id)
	arma_obtenida.emit(arma.id)
	if not arma.texto_diario.is_empty():
		agregar_entrada(arma.nombre, arma.texto_diario, arma.id)

func agregar_entrada(titulo: String, texto: String, origen: String = "") -> void:
	entradas.append({"titulo": titulo, "texto": texto, "origen": origen})
	entrada_agregada.emit(entradas.size() - 1)

# --- Estadísticas ---

func sumar(clave: String, cantidad: int = 1) -> void:
	estadisticas[clave] = int(estadisticas.get(clave, 0)) + cantidad

func estadistica(clave: String) -> int:
	return int(estadisticas.get(clave, 0))

## Devuelve el tiempo jugado como "1h 23m 45s".
func tiempo_formateado() -> String:
	var total: int = estadistica("tiempo_seg")
	var horas: int = total / 3600
	var minutos: int = (total % 3600) / 60
	var segundos: int = total % 60
	if horas > 0:
		return "%dh %02dm %02ds" % [horas, minutos, segundos]
	return "%dm %02ds" % [minutos, segundos]

## Vuelve a cero para una partida nueva. Sin esto, "Despertar" despues de haber
## jugado heredaba armas, banderas y estadisticas de la partida anterior, porque
## un autoload no se reinicia al cambiar de escena.
func reiniciar() -> void:
	banderas = {}
	armas_obtenidas.clear()
	entradas.clear()
	estadisticas = {
		"muertes": 0,
		"enemigos_eliminados": 0,
		"enemigos_evitados": 0,
		"tiempo_seg": 0,
	}
	_tiempo_acumulado = 0.0

## Restaura el progreso al cargar una partida.
func cargar(datos: Dictionary) -> void:
	banderas = datos.get("flags", {}).duplicate()
	armas_obtenidas.assign(datos.get("armas", []))
	estadisticas = datos.get("estadisticas", estadisticas).duplicate()
	_tiempo_acumulado = float(estadistica("tiempo_seg"))
	entradas.clear()
	if datos.has("entradas"):
		for entrada: Variant in datos["entradas"]:
			if entrada is Dictionary:
				entradas.append(entrada)
		return
	# Partida anterior a que se guardaran las entradas: al menos se reescriben
	# las de las armas, que se pueden deducir del arsenal.
	for arma: ArmaData in ComponenteArma.cargar_carpeta("res://systems/weapons/data"):
		if armas_obtenidas.has(arma.id) and not arma.texto_diario.is_empty():
			entradas.append({"titulo": arma.nombre, "texto": arma.texto_diario, "origen": arma.id})

## Clave con la que un recogible recuerda que ya se cogio. Va en las banderas,
## asi que viaja en el JSON de guardado sin cambiar su formato.
static func clave_recogido(nivel: String, nombre: String) -> String:
	return "recogido:%s:%s" % [nivel.get_file().get_basename(), nombre]
