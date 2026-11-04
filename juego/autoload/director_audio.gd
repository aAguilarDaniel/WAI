# Mezcla global y reproduccion de efectos. Autoload "DirectorAudio".
#
# Antes solo creaba los buses. Ahora ademas:
#   - sostiene el ambiente en bucle, que es lo que hace que el nivel no suene a
#     vacio (ARTE.md §7: capas superpuestas, no pistas separadas);
#   - reproduce los efectos puntuales desde una pequena reserva de reproductores.
#
# La reserva existe porque un AudioStreamPlayer solo puede sonar una vez a la
# vez: con uno solo, tres golpes seguidos se cortan entre si y el combate suena
# a un unico impacto. Ocho es de sobra para lo que hay en pantalla.
#
# Nadie mas carga .wav: las entidades piden efectos por nombre, asi que cambiar
# un sonido es cambiar el archivo de audio/ sin tocar codigo.
extends Node

## Cambio la mezcla activa (ej. de "exploracion" a "combate").
signal mezcla_cambiada(nombre_mezcla: String)
signal volumen_cambiado(bus: String, valor: float)

## Buses que el juego espera encontrar. Se crean por codigo si no existen, asi no
## dependemos de un default_bus_layout.tres escrito a mano.
const BUSES: PackedStringArray = ["Master", "Musica", "SFX"]

const CARPETA: String = "res://audio"
## Cuantos efectos pueden sonar a la vez.
const RESERVA: int = 8

var _efectos: Dictionary = {}
var _reproductores: Array[AudioStreamPlayer] = []
var _siguiente: int = 0
var _ambiente: AudioStreamPlayer = null
## La musica va en su propio reproductor y no en el del ambiente: el zumbido del
## nivel tiene que seguir sonando debajo de la cancion, no ser sustituido por ella.
var _musica: AudioStreamPlayer = null

func _ready() -> void:
	# El audio no se para con el juego: la pausa del diario dejaba el ambiente
	# cortado en seco, y ese corte se oye mas que el silencio.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nombre: String in BUSES:
		if AudioServer.get_bus_index(nombre) != -1:
			continue
		AudioServer.add_bus()
		var indice: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, nombre)
		AudioServer.set_bus_send(indice, "Master")

	_cargar_efectos()
	for i: int in RESERVA:
		var reproductor: AudioStreamPlayer = AudioStreamPlayer.new()
		reproductor.bus = "SFX"
		add_child(reproductor)
		_reproductores.append(reproductor)

	_ambiente = AudioStreamPlayer.new()
	_ambiente.bus = "Musica"
	_ambiente.volume_db = -12.0
	add_child(_ambiente)

	_musica = AudioStreamPlayer.new()
	_musica.bus = "Musica"
	add_child(_musica)

## Carga todos los .wav de audio/ por su nombre sin extension. Soltar un archivo
## nuevo ahi basta para poder pedirlo: no hay ninguna lista que actualizar.
func _cargar_efectos() -> void:
	var dir: DirAccess = DirAccess.open(CARPETA)
	if dir == null:
		push_warning("DirectorAudio: no hay carpeta %s. El juego corre en silencio." % CARPETA)
		return
	for archivo: String in dir.get_files():
		# En un juego exportado el .wav no aparece en la carpeta: solo su .import.
		# Sin quitar ese sufijo, el .exe arrancaba sin un solo efecto ni ambiente.
		var nombre: String = archivo.trim_suffix(".remap").trim_suffix(".import")
		if not nombre.ends_with(".wav") or _efectos.has(nombre.get_basename()):
			continue
		var flujo: AudioStream = load(CARPETA.path_join(nombre)) as AudioStream
		if flujo != null:
			_efectos[nombre.get_basename()] = flujo

## Reproduce un efecto por nombre de archivo sin extension ("golpe", "salto"...).
## Si no existe, no hace nada y no se queja: el juego tiene que correr aunque
## falte el audio.
func efecto(nombre: String, volumen_db: float = 0.0, tono: float = 1.0) -> void:
	var flujo: AudioStream = _efectos.get(nombre)
	if flujo == null or _reproductores.is_empty():
		return
	var reproductor: AudioStreamPlayer = _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % _reproductores.size()
	reproductor.stream = flujo
	reproductor.volume_db = volumen_db
	reproductor.pitch_scale = tono
	reproductor.play()

## Igual que efecto(), pero con el tono variado al azar. Repetir el mismo sample
## exacto veinte veces seguidas suena a maquina de escribir; un pelo arriba o
## abajo basta para que no se note.
func efecto_variado(nombre: String, volumen_db: float = 0.0, variacion: float = 0.10) -> void:
	efecto(nombre, volumen_db, randf_range(1.0 - variacion, 1.0 + variacion))

## Arranca el ambiente en bucle. Lo llama el nivel al entrar.
func ambiente(nombre: String = "ambiente", volumen_db: float = -12.0) -> void:
	var flujo: AudioStream = _efectos.get(nombre)
	if flujo == null or _ambiente == null:
		return
	if _ambiente.stream == flujo and _ambiente.playing:
		return
	_ambiente.stream = flujo
	_ambiente.volume_db = volumen_db
	_ambiente.play()

func parar_ambiente() -> void:
	if _ambiente != null:
		_ambiente.stop()

## Arranca la musica del nivel. El bucle lo pone la importacion del archivo
## (loop=true en su .import), no el codigo: cambiar de cancion es cambiar el
## recurso. Si ya esta sonando la misma no la reinicia, asi morir y reaparecer
## no la corta a medias.
func musica(flujo: AudioStream, volumen_db: float = -8.0) -> void:
	if _musica == null:
		return
	if flujo == null:
		parar_musica()
		return
	if _musica.stream == flujo and _musica.playing:
		_musica.volume_db = volumen_db
		return
	_musica.stream = flujo
	_musica.volume_db = volumen_db
	_musica.play()

func parar_musica() -> void:
	if _musica != null:
		_musica.stop()
		_musica.stream = null

func sonando_musica() -> AudioStream:
	if _musica == null or not _musica.playing:
		return null
	return _musica.stream

# --- Mezcla ---

## Volumen en [0.0, 1.0]. Internamente Godot trabaja en decibelios.
func fijar_volumen(bus: String, valor: float) -> void:
	var indice: int = AudioServer.get_bus_index(bus)
	if indice == -1:
		return
	var acotado: float = clampf(valor, 0.0, 1.0)
	AudioServer.set_bus_mute(indice, is_zero_approx(acotado))
	AudioServer.set_bus_volume_db(indice, linear_to_db(acotado))
	volumen_cambiado.emit(bus, acotado)

func volumen(bus: String) -> float:
	var indice: int = AudioServer.get_bus_index(bus)
	if indice == -1:
		return 1.0
	if AudioServer.is_bus_mute(indice):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(indice)), 0.0, 1.0)
