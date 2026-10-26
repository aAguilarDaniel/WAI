# Arsenal del jugador: carga las armas de disco, gestiona cuál está equipada y
# ejecuta el golpe (melee o proyectil) según los datos del ArmaData.
#
# Es el ÚNICO lugar del proyecto que le habla al autoload Alma. Los enemigos y las
# hitboxes no saben que el eje existe: solo informan que alguien murió y con qué.
class_name ComponenteArma
extends Node

signal arma_equipada(arma: ArmaData)
signal arma_obtenida(arma: ArmaData)

## Carpeta que se escanea al arrancar. Soltar un .tres nuevo ahí basta para
## agregar un arma: no hay ninguna lista que actualizar (CLAUDE.md §3.2).
@export_dir var carpeta_armas: String = "res://systems/weapons/data"
## Hitbox del golpe cuerpo a cuerpo. Se asigna en el inspector.
@export var hitbox_melee: ComponenteHitbox
## Desde dónde salen los proyectiles.
@export var origen_disparo: Node2D
## Provisional para probar: arranca con todo el arsenal. En el juego real las
## armas se recogen del mundo y esto va en false.
@export var empezar_con_todas: bool = true

var arsenal: Array[ArmaData] = []

var _indice: int = 0
var _peso_en_curso: float = 0.0

func _ready() -> void:
	# Mismo criterio que ComponenteHurtbox: si no se cableó a mano, se busca en la
	# propia entidad. Escribir un NodePath a mano en el .tscn NO funciona (ver README).
	if hitbox_melee == null:
		hitbox_melee = ComponenteHitbox.buscar_en_hermanos(self)
	if origen_disparo == null:
		origen_disparo = _buscar_origen()
	if hitbox_melee != null:
		hitbox_melee.mato.connect(_al_matar_melee)
	if empezar_con_todas:
		arsenal = cargar_carpeta(carpeta_armas)
	if not arsenal.is_empty():
		equipar(0)

# --- Arsenal ---

## Carga todos los .tres de una carpeta. Estático para poder usarlo desde el diario.
static func cargar_carpeta(ruta: String) -> Array[ArmaData]:
	var lista: Array[ArmaData] = []
	var dir: DirAccess = DirAccess.open(ruta)
	if dir == null:
		push_error("ComponenteArma: no se pudo abrir %s" % ruta)
		return lista
	for archivo: String in dir.get_files():
		# En un proyecto exportado los recursos aparecen como .tres.remap
		var nombre: String = archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var arma: ArmaData = load(ruta.path_join(nombre)) as ArmaData
		if arma != null:
			lista.append(arma)
	# Las más humanas primero: así se arranca con el tubo de metal y no con
	# el emisor de radiación, que sería una decisión narrativa por accidente.
	lista.sort_custom(func(a: ArmaData, b: ArmaData) -> bool:
		if not is_equal_approx(a.peso_hum, b.peso_hum):
			return a.peso_hum > b.peso_hum
		return a.id < b.id)
	return lista

func arma_actual() -> ArmaData:
	if arsenal.is_empty() or _indice < 0 or _indice >= arsenal.size():
		return null
	return arsenal[_indice]

func equipar(indice: int) -> void:
	if arsenal.is_empty():
		return
	_indice = posmod(indice, arsenal.size())
	arma_equipada.emit(arma_actual())

func siguiente_arma() -> void:
	if arsenal.size() > 1:
		equipar(_indice + 1)

## Recoger un arma del mundo. Si ya la tenía, no la duplica.
func obtener(arma: ArmaData) -> void:
	if arma == null or arsenal.has(arma):
		return
	arsenal.append(arma)
	arma_obtenida.emit(arma)
	if arsenal.size() == 1:
		equipar(0)

# --- Ataque, en las tres fases que maneja el estado Atacar ---

## Fase de anticipación: coloca el golpe y recuerda con qué arma se está atacando.
func preparar(mira: int) -> void:
	var arma: ArmaData = arma_actual()
	_peso_en_curso = arma.peso_hum if arma != null else 0.0
	if hitbox_melee == null:
		return
	hitbox_melee.position.x = mira * (arma.alcance if arma != null else 16.0)
	hitbox_melee.dano = arma.dano if arma != null else 1

## Fase activa: el golpe se hace real.
func ejecutar_golpe(mira: int) -> void:
	var arma: ArmaData = arma_actual()
	if arma != null and arma.es_a_distancia:
		_disparar(arma, mira)
	elif hitbox_melee != null:
		hitbox_melee.activar()

## Fase de recuperación y salidas de emergencia.
func terminar_golpe() -> void:
	if hitbox_melee != null:
		hitbox_melee.desactivar()

## Respaldo del origen de disparo, igual que el de hitbox_melee: busca el nodo
## OrigenDisparo dentro de la misma entidad.
##
## Si no lo encuentra cae en el propietario, PERO el origen del jugador está en
## los PIES: un proyectil que nace ahí aparece dentro del suelo, su hitbox toca
## la capa 1 y se libera en el mismo frame en que se disparó. Ese era el motivo
## de que no se viera ni un disparo de la pistola, el plasma ni la radiación.
func _buscar_origen() -> Node2D:
	if owner == null:
		return null
	var marca: Node2D = owner.get_node_or_null("OrigenDisparo") as Node2D
	return marca if marca != null else owner as Node2D


func _disparar(arma: ArmaData, mira: int) -> void:
	if arma.escena_proyectil == null:
		push_error("El arma '%s' es a distancia pero no tiene escena_proyectil." % arma.id)
		return
	var proyectil: Proyectil = arma.escena_proyectil.instantiate() as Proyectil
	if proyectil == null:
		push_error("La escena de proyectil de '%s' no tiene el script Proyectil." % arma.id)
		return
	var origen: Node2D = origen_disparo if origen_disparo != null else (owner as Node2D)
	# El proyectil cuelga del NIVEL, no de quien dispara. Si colgara del jugador
	# viajaría con él y el disparo no se separaría nunca. Antes salía bien por
	# accidente, porque el origen era el propio jugador.
	var duenio: Node2D = owner as Node2D
	var padre: Node = duenio.get_parent() if duenio != null else origen.get_parent()
	padre.add_child(proyectil)
	proyectil.global_position = origen.global_position + Vector2(mira * arma.alcance, 0.0)
	proyectil.configurar(Vector2(mira, 0.0), arma.velocidad_proyectil, arma.dano,
		arma.vida_proyectil, self)
	# El peso se captura al disparar: si cambia de arma en pleno vuelo, cuenta la que disparó.
	proyectil.mato.connect(_al_matar_a_distancia.bind(arma.peso_hum))

# --- El único contacto con el eje del alma ---

func _al_matar_melee(_objetivo: ComponenteHurtbox) -> void:
	Alma.registrar(_peso_en_curso)

func _al_matar_a_distancia(_objetivo: ComponenteHurtbox, peso: float) -> void:
	Alma.registrar(peso)
