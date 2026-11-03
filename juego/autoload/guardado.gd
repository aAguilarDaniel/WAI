# Serialización de la partida a user:// en JSON versionado. Autoload global "Guardado".
# No decide cuándo guardar: eso lo pide la TerminalCRT. Consulta a Alma y a
# EstadoJuego al serializar, y a nadie más (docs/ARQUITECTURA.md §2).
extends Node

## Versión del formato JSON (docs/ARQUITECTURA.md §5). Subirla obliga a migrar.
const VERSION_GUARDADO: int = 1

## user:// apunta a la carpeta de datos del usuario, no a la del juego.
const RUTA_PARTIDA: String = "user://partida.json"

## Nivel en el que se retoma una partida que no dice cual (las anteriores a que
## existiera el nivel 2).
const NIVEL_POR_DEFECTO: String = "res://levels/nivel_01/nivel_01.tscn"

signal partida_guardada(ruta: String)
signal partida_cargada(datos: Dictionary)
signal fallo_de_guardado(mensaje: String)

## Escribe la partida. Los datos del jugador los pasa quien llama (la TerminalCRT),
## así este autoload no anda buscando nodos por el árbol.
func guardar(checkpoint_id: String, datos_jugador: Dictionary) -> bool:
	var datos: Dictionary = {
		"save_version": VERSION_GUARDADO,
		"fecha": Time.get_datetime_string_from_system(false, true),
		"checkpoint_id": checkpoint_id,
		# Escena del nivel de la terminal. Campo nuevo pero opcional: una partida
		# sin el se lee como del nivel 1, asi que no hace falta subir la version.
		"nivel": str(datos_jugador.get("nivel", NIVEL_POR_DEFECTO)),
		"alma": Alma.valor(),
		"salud": int(datos_jugador.get("salud", 0)),
		"vendas": int(datos_jugador.get("vendas", 0)),
		"armas": datos_jugador.get("armas", []),
		"arma_equipada": str(datos_jugador.get("arma_equipada", "")),
		"flags": EstadoJuego.banderas.duplicate(),
		# Campo opcional, como "nivel": sin el, "Seguir donde estaba" abria un
		# diario vacio aunque se hubieran recogido armas y el cuaderno.
		"entradas": EstadoJuego.entradas.duplicate(true),
		"estadisticas": EstadoJuego.estadisticas.duplicate(),
	}
	var archivo: FileAccess = FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	if archivo == null:
		var motivo: String = "No se pudo escribir %s (error %d)" % [
			RUTA_PARTIDA, FileAccess.get_open_error()]
		push_error(motivo)
		fallo_de_guardado.emit(motivo)
		return false
	archivo.store_string(JSON.stringify(datos, "	"))
	archivo.close()
	partida_guardada.emit(RUTA_PARTIDA)
	return true

func hay_partida() -> bool:
	return FileAccess.file_exists(RUTA_PARTIDA)

## Lee y valida la partida. Devuelve un diccionario vacío si no hay o no sirve.
## Aplica lo que le corresponde a Alma y EstadoJuego; el resto lo aplica quien llama.
func cargar() -> Dictionary:
	var datos: Dictionary = _leer()
	if datos.is_empty():
		return {}
	Alma.cargar(float(datos.get("alma", 0.0)))
	EstadoJuego.cargar(datos)
	partida_cargada.emit(datos)
	return datos

## Escena del nivel en el que quedó la partida. NO aplica nada: el menú lo
## necesita para saber qué escena abrir antes de que exista el nivel.
func nivel_guardado() -> String:
	var ruta: String = str(_leer().get("nivel", NIVEL_POR_DEFECTO))
	if not ResourceLoader.exists(ruta):
		return NIVEL_POR_DEFECTO
	return ruta

## Lee el archivo y comprueba la versión, sin efectos sobre el resto del juego.
func _leer() -> Dictionary:
	if not hay_partida():
		return {}
	var archivo: FileAccess = FileAccess.open(RUTA_PARTIDA, FileAccess.READ)
	if archivo == null:
		_fallar("No se pudo leer %s" % RUTA_PARTIDA)
		return {}
	var crudo: String = archivo.get_as_text()
	archivo.close()
	var resultado: Variant = JSON.parse_string(crudo)
	if typeof(resultado) != TYPE_DICTIONARY:
		_fallar("La partida está corrupta: no es un objeto JSON válido.")
		return {}
	var datos: Dictionary = resultado
	if not _version_valida(datos):
		return {}
	return datos

func borrar() -> void:
	if hay_partida():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PARTIDA))

## Rechaza con un mensaje claro en vez de cargar datos de un formato desconocido.
func _version_valida(datos: Dictionary) -> bool:
	if not datos.has("save_version"):
		_fallar("La partida no indica su versión. Se descarta.")
		return false
	var version: int = int(datos["save_version"])
	if version > VERSION_GUARDADO:
		_fallar("La partida es de una versión más nueva (%d) que este juego (%d)."
			% [version, VERSION_GUARDADO])
		return false
	if version < VERSION_GUARDADO:
		# Cuando haya una versión 2, la migración va aquí.
		_fallar("La partida es de la versión %d y no hay migración a la %d."
			% [version, VERSION_GUARDADO])
		return false
	return true

func _fallar(mensaje: String) -> void:
	push_warning(mensaje)
	fallo_de_guardado.emit(mensaje)
