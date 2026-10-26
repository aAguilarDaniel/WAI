# Pestaña de Ajustes del diario: volumen por bus, pantalla completa y remapeo de
# controles. Construye sus controles por código para no tener 50 nodos en la escena.
# Persiste en user://ajustes.cfg.
class_name PanelAjustes
extends VBoxContainer

signal ajustes_guardados

const RUTA_AJUSTES: String = "user://ajustes.cfg"

## Acciones que el jugador puede reasignar. El orden es el que ve en pantalla.
const ACCIONES_REMAPEABLES: PackedStringArray = [
	"mover_izq", "mover_der", "mirar_arriba", "agachar", "saltar", "correr",
	"rodar", "atacar", "curar", "interactuar", "diario", "cambiar_arma",
]

const NOMBRES_VISIBLES: Dictionary = {
	"mover_izq": "Izquierda", "mover_der": "Derecha", "mirar_arriba": "Mirar arriba",
	"agachar": "Agacharse", "saltar": "Saltar", "correr": "Correr", "rodar": "Rodar",
	"atacar": "Atacar", "curar": "Curarse", "interactuar": "Interactuar",
	"diario": "Abrir el diario", "cambiar_arma": "Cambiar de arma",
}

var _botones: Dictionary = {}
var _accion_capturando: String = ""

func _ready() -> void:
	_construir_audio()
	_construir_video()
	_construir_controles()
	cargar()

# --- Captura de teclas para el remapeo ---

func _input(evento: InputEvent) -> void:
	if _accion_capturando.is_empty():
		return
	var es_tecla: bool = evento is InputEventKey and evento.is_pressed() and not evento.is_echo()
	var es_boton: bool = evento is InputEventJoypadButton and evento.is_pressed()
	if not (es_tecla or es_boton):
		return
	get_viewport().set_input_as_handled()
	var accion: String = _accion_capturando
	_accion_capturando = ""
	if evento is InputEventKey and evento.keycode == KEY_ESCAPE:
		_refrescar_boton(accion)  # Escape cancela sin cambiar nada
		return
	_reasignar(accion, evento)
	_refrescar_boton(accion)
	guardar()

## Sustituye solo el evento del mismo tipo: reasignar una tecla no borra el mando.
func _reasignar(accion: String, nuevo: InputEvent) -> void:
	for viejo: InputEvent in InputMap.action_get_events(accion):
		var mismo_tipo: bool = (nuevo is InputEventKey and viejo is InputEventKey) 			or (nuevo is InputEventJoypadButton and viejo is InputEventJoypadButton)
		if mismo_tipo:
			InputMap.action_erase_event(accion, viejo)
	InputMap.action_add_event(accion, nuevo)

# --- Construcción de la interfaz ---

func _construir_audio() -> void:
	_titulo("Audio")
	for bus: String in DirectorAudio.BUSES:
		var fila: HBoxContainer = HBoxContainer.new()
		var etiqueta: Label = Label.new()
		etiqueta.text = bus
		etiqueta.custom_minimum_size.x = 60
		var deslizador: HSlider = HSlider.new()
		deslizador.min_value = 0.0
		deslizador.max_value = 1.0
		deslizador.step = 0.05
		deslizador.custom_minimum_size.x = 90
		deslizador.value = DirectorAudio.volumen(bus)
		deslizador.value_changed.connect(func(v: float) -> void:
			DirectorAudio.fijar_volumen(bus, v)
			guardar())
		fila.add_child(etiqueta)
		fila.add_child(deslizador)
		add_child(fila)

func _construir_video() -> void:
	_titulo("Pantalla")
	var completa: CheckButton = CheckButton.new()
	completa.text = "Pantalla completa"
	completa.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	completa.toggled.connect(func(activo: bool) -> void:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if activo else DisplayServer.WINDOW_MODE_WINDOWED)
		guardar())
	add_child(completa)

func _construir_controles() -> void:
	_titulo("Controles")
	var ayuda: Label = Label.new()
	ayuda.text = "Pulsá un botón y luego la tecla nueva. Escape cancela."
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ayuda)
	for accion: String in ACCIONES_REMAPEABLES:
		var fila: HBoxContainer = HBoxContainer.new()
		var etiqueta: Label = Label.new()
		etiqueta.text = NOMBRES_VISIBLES.get(accion, accion)
		etiqueta.custom_minimum_size.x = 90
		var boton: Button = Button.new()
		boton.custom_minimum_size.x = 80
		boton.pressed.connect(func() -> void:
			_accion_capturando = accion
			boton.text = "..." )
		_botones[accion] = boton
		fila.add_child(etiqueta)
		fila.add_child(boton)
		add_child(fila)
		_refrescar_boton(accion)

func _titulo(texto: String) -> void:
	var etiqueta: Label = Label.new()
	etiqueta.text = texto.to_upper()
	add_child(etiqueta)

func _refrescar_boton(accion: String) -> void:
	var boton: Button = _botones.get(accion) as Button
	if boton == null:
		return
	boton.text = _texto_de_accion(accion)

func _texto_de_accion(accion: String) -> String:
	for evento: InputEvent in InputMap.action_get_events(accion):
		if evento is InputEventKey:
			var tecla: InputEventKey = evento
			return OS.get_keycode_string(tecla.physical_keycode)
	return "-"

# --- Persistencia ---

func guardar() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: String in DirectorAudio.BUSES:
		cfg.set_value("audio", bus, DirectorAudio.volumen(bus))
	cfg.set_value("pantalla", "completa",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	for accion: String in ACCIONES_REMAPEABLES:
		var eventos: Array = []
		for evento: InputEvent in InputMap.action_get_events(accion):
			if evento is InputEventKey:
				eventos.append({"tipo": "tecla", "codigo": (evento as InputEventKey).physical_keycode})
			elif evento is InputEventJoypadButton:
				eventos.append({"tipo": "boton", "codigo": (evento as InputEventJoypadButton).button_index})
		cfg.set_value("controles", accion, eventos)
	cfg.save(RUTA_AJUSTES)
	ajustes_guardados.emit()

func cargar() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) != OK:
		return
	for bus: String in DirectorAudio.BUSES:
		DirectorAudio.fijar_volumen(bus, float(cfg.get_value("audio", bus, 1.0)))
	if bool(cfg.get_value("pantalla", "completa", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for accion: String in ACCIONES_REMAPEABLES:
		var guardados: Array = cfg.get_value("controles", accion, [])
		if guardados.is_empty():
			continue
		InputMap.action_erase_events(accion)
		for datos: Dictionary in guardados:
			if datos.get("tipo", "") == "tecla":
				var tecla: InputEventKey = InputEventKey.new()
				tecla.physical_keycode = int(datos["codigo"])
				InputMap.action_add_event(accion, tecla)
			else:
				var boton: InputEventJoypadButton = InputEventJoypadButton.new()
				boton.button_index = int(datos["codigo"])
				InputMap.action_add_event(accion, boton)
		_refrescar_boton(accion)
