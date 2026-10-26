# HUD: corazones, vendas y arma equipada. Cuelga del jugador (jugador.tscn).
# Se suscribe a las señales de ComponenteSalud, Jugador y ComponenteArma; nunca
# consulta nada cada frame.
#
# El HUD es lo unico que el juego dice sin que se lo pregunten, asi que dice lo
# minimo: cuanta vida queda, cuantas vendas quedan y con que estas pegando. El
# eje del alma NO aparece aqui y no puede aparecer nunca (CLAUDE.md §3.1).
class_name BarraSalud
extends CanvasLayer

## Que salud representa. Se asigna en el inspector desde la escena que lo instancia.
@export var salud: ComponenteSalud
## Placeholder de 7x7. Reemplazar por el corazon final sin tocar codigo.
@export var textura_corazon: Texture2D
@export var color_lleno: Color = Color(0.83, 0.24, 0.28)
@export var color_vacio: Color = Color(0.20, 0.14, 0.16)
## Se enciende un instante al perder un corazon: sin eso, a 384x216 un corazon
## que se apaga en la esquina no lo ve nadie.
@export var color_destello: Color = Color(1.0, 0.9, 0.8)

@onready var contenedor: HBoxContainer = $Margen/Fila/Corazones
@onready var etiqueta_vendas: Label = $Margen/Fila/Vendas
@onready var etiqueta_arma: Label = $Margen/Fila/Arma

var _corazones: Array[TextureRect] = []
var _ultima_salud: int = -1

func _ready() -> void:
	var duenio: Jugador = owner as Jugador
	if salud == null:
		salud = ComponenteSalud.buscar_en_hermanos(self)
	if salud == null:
		push_warning("BarraSalud: no se asignó 'salud'. El HUD queda vacío.")
	else:
		salud.salud_cambiada.connect(_al_cambiar_salud)
		_al_cambiar_salud(salud.salud_actual, salud.salud_maxima)
	if duenio == null:
		return
	duenio.vendas_cambiadas.connect(_al_cambiar_vendas)
	_al_cambiar_vendas(duenio.vendas)
	# El nodo se busca por ruta y NO por duenio.arma: ese es un @onready del
	# Jugador y los _ready() de los hijos corren ANTES que el del padre, asi que
	# aqui todavia vale null. El HUD se quedaba sin nombre de arma toda la partida.
	var arsenal: ComponenteArma = duenio.get_node_or_null("Arma") as ComponenteArma
	if arsenal != null:
		arsenal.arma_equipada.connect(_al_equipar)
		_al_equipar(arsenal.arma_actual())

func _al_cambiar_salud(actual: int, maxima: int) -> void:
	_asegurar_cantidad(maxima)
	var perdio: bool = _ultima_salud >= 0 and actual < _ultima_salud
	_ultima_salud = actual
	for i: int in _corazones.size():
		_corazones[i].modulate = color_lleno if i < actual else color_vacio
	if not perdio or actual >= _corazones.size():
		return
	# Destello del corazon que se acaba de perder.
	var perdido: TextureRect = _corazones[actual]
	perdido.modulate = color_destello
	var destello: Tween = create_tween()
	destello.tween_property(perdido, "modulate", color_vacio, 0.35)

func _al_cambiar_vendas(cantidad: int) -> void:
	etiqueta_vendas.text = "+%d" % cantidad
	etiqueta_vendas.modulate = Color(0.85, 0.78, 0.7) if cantidad > 0 else Color(0.36, 0.3, 0.3)

## El nombre del arma, no su icono: los iconos de los .tres siguen pendientes
## (art/PLACEHOLDERS.md) y un cuadro vacio se lee peor que una palabra.
func _al_equipar(arma: ArmaData) -> void:
	etiqueta_arma.text = arma.nombre.to_upper() if arma != null else ""

func _asegurar_cantidad(cantidad: int) -> void:
	while _corazones.size() < cantidad:
		var corazon: TextureRect = TextureRect.new()
		corazon.texture = textura_corazon
		corazon.stretch_mode = TextureRect.STRETCH_KEEP
		contenedor.add_child(corazon)
		_corazones.append(corazon)
	while _corazones.size() > cantidad:
		_corazones.pop_back().queue_free()
