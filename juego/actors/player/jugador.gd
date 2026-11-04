# Jugador. Concentra la física y todos los parámetros del feel; el comportamiento
# lo deciden los estados de estados/. Lo usa levels/plantillas/caja_blanca.tscn.
class_name Jugador
extends CharacterBody2D

# --- Parámetros del feel. Todo esto se toca en el inspector, jugando. ---

@export_group("Movimiento horizontal")
## Velocidad tope caminando, en píxeles por segundo.
@export var velocidad_caminar: float = 70.0
## Velocidad tope corriendo, en píxeles por segundo.
@export var velocidad_correr: float = 115.0
## Velocidad tope agachado.
@export var velocidad_agachado: float = 35.0
## Segundos que tarda en llegar a la velocidad tope desde parado.
@export var tiempo_acelerar: float = 0.08
## Segundos que tarda en frenar del todo. Más bajo = más seco.
@export var tiempo_frenar: float = 0.06
## Cuánto control tiene en el aire respecto del suelo. 1.0 = igual, 0.0 = ninguno.
@export_range(0.0, 1.0, 0.05) var control_aereo: float = 0.65

@export_group("Salto")
## Altura máxima del salto en píxeles. El personaje mide 24 px: 48 son dos personajes.
@export var altura_salto: float = 48.0
## Segundos que tarda en llegar al punto más alto. Más bajo = salto más nervioso.
@export var tiempo_subida: float = 0.35
## Cuánto más rápido cae que sube. docs/ARQUITECTURA.md §4 pide ~1.6.
@export var multiplicador_caida: float = 1.6
## Al soltar el botón, la velocidad de subida se multiplica por esto. Salto de altura variable.
@export_range(0.0, 1.0, 0.05) var factor_corte_salto: float = 0.45
## Tope de velocidad de caída, para que no acelere infinito.
@export var velocidad_caida_maxima: float = 320.0

@export_group("Perdón al jugador")
## Segundos de gracia para saltar después de haberse ido del borde.
@export var coyote_time: float = 0.1
## Segundos que se recuerda un salto pulsado antes de tocar suelo.
@export var jump_buffer: float = 0.12
## Píxeles laterales que se perdona si la cabeza roza una esquina al subir.
@export var correccion_esquina_px: int = 2

@export_group("Rodar")
@export var velocidad_rodar: float = 160.0
@export var duracion_rodar: float = 0.3
@export var enfriamiento_rodar: float = 0.5
## Esquiva tipo Dark Souls: durante parte del rodar ningún golpe entra.
@export var rodar_da_invulnerabilidad: bool = true
## Segundos desde el inicio del rodar hasta que arrancan los i-frames.
## No es 0 a propósito: hay que comprometerse antes de estar a salvo.
@export var rodar_iframes_inicio: float = 0.04
## Cuánto duran los i-frames. Si igualara a duracion_rodar, rodar sería gratis.
@export var rodar_iframes_duracion: float = 0.18
## Tiñe el sprite mientras es invulnerable, para poder aprender el timing.
@export var rodar_mostrar_iframes: bool = true
## Color del destello durante la esquiva.
@export var color_iframes: Color = Color(0.6, 0.85, 1.0, 0.75)

@export_group("Ataque")
## Daño de un golpe melee, en corazones.
@export var dano_ataque: int = 1
## Píxeles por delante del centro donde nace la hitbox. Alcance tipo látigo.
@export var alcance_ataque: float = 16.0
## Fase 1: el brazo se levanta. La hitbox todavía no existe.
@export var anticipacion_ataque: float = 0.06
## Fase 2: el golpe es real. Solo aquí la hitbox puede lastimar.
@export var duracion_golpe: float = 0.1
## Fase 3: el arma vuelve. No podés atacar de nuevo ni actuar. Es el compromiso.
@export var recuperacion_ataque: float = 0.14
## Segundos entre un ataque y el siguiente.
@export var enfriamiento_ataque: float = 0.12
## Cuánto de la velocidad de caminar conservás mientras atacás. 0.0 = clavado en el sitio.
@export_range(0.0, 1.0, 0.05) var factor_velocidad_atacando: float = 0.4
## Castlevania clásico no lo permitía; Symphony of the Night sí.
@export var permitir_ataque_aereo: bool = true

@export_group("Daño recibido")
## Empuje horizontal al ser golpeado.
@export var retroceso_x: float = 90.0
## Empuje vertical al ser golpeado. Un salto pequeño hace que el golpe se lea.
@export var retroceso_y: float = 110.0
## Cuán rápido se frena el retroceso.
@export var frenado_retroceso: float = 300.0
## Segundos sin control tras un golpe. Los i-frames los maneja ComponenteSalud.
@export var duracion_aturdimiento: float = 0.22

@export_group("Curación")
## Vendas que lleva encima. Limitadas y consumibles (CLAUDE.md §3.5).
@export var vendas: int = 2
@export var vendas_maximas: int = 5
## Cuánta salud devuelve una venda.
@export var curacion_por_venda: int = 2

@export_group("Depuración")
## Muestra el nombre del estado activo encima del personaje.
## En false por defecto: es una herramienta de desarrollo y estaba saliendo
## en pantalla durante toda la partida, con un "Quieto" flotando sobre la
## cabeza del protagonista en cada plano.
@export var mostrar_estado: bool = false

# --- Valores derivados. No se tocan a mano: salen de los de arriba. ---

## Impulso inicial del salto (negativo porque en 2D el eje Y crece hacia abajo).
var velocidad_salto: float:
	get:
		return -2.0 * altura_salto / tiempo_subida

## Gravedad mientras sube.
var gravedad_subida: float:
	get:
		return 2.0 * altura_salto / (tiempo_subida * tiempo_subida)

## Gravedad mientras cae. Más fuerte que la de subida: el salto se siente con peso.
var gravedad_caida: float:
	get:
		return gravedad_subida * multiplicador_caida

# --- Estado interno ---

## Tinte del sprite mientras dura la gracia tras un golpe.
const tinte_herido: Color = Color(2.2, 0.7, 0.7)

## Hacia dónde mira: 1 derecha, -1 izquierda. Lo usa rodar y luego el ataque.
var mira: int = 1

## Cambió la cantidad de vendas. La escucha el HUD.
signal vendas_cambiadas(cantidad: int)

## Dirección desde la que llegó el último golpe. La usa el estado Herido.
var direccion_ultimo_golpe: Vector2 = Vector2.RIGHT

## Ultimo terreno firme que piso. Vuelve aqui al caer en unos pinchos sin morir.
## Las plataformas moviles y las fragiles no cuentan: podrian no seguir ahi.
var ultimo_suelo_seguro: Vector2 = Vector2.ZERO

## Dónde reaparece al morir. En el Hito 5 lo reemplaza la última TerminalCRT.
var punto_de_reaparicion: Vector2 = Vector2.ZERO

var _coyote_restante: float = 0.0
var _buffer_restante: float = 0.0
var _enfriamiento_rodar_restante: float = 0.0
var _enfriamiento_ataque_restante: float = 0.0

@onready var maquina: MaquinaEstados = $MaquinaEstados
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var forma: CollisionShape2D = $Forma
@onready var etiqueta_estado: Label = $EtiquetaEstado
@onready var salud: ComponenteSalud = $Salud
@onready var hurtbox: ComponenteHurtbox = $Hurtbox
@onready var hitbox_ataque: ComponenteHitbox = $HitboxAtaque
@onready var arma: ComponenteArma = $Arma
@onready var animador: AnimadorJugador = $Animador

func _ready() -> void:
	punto_de_reaparicion = global_position
	ultimo_suelo_seguro = global_position
	salud.recibio_dano.connect(_al_recibir_dano)
	salud.murio.connect(_al_morir)
	salud.invulnerabilidad_terminada.connect(_al_terminar_invulnerabilidad)
	maquina.inicializar(self)
	# Despues de la maquina: el animador se suscribe a su senal y necesita que
	# ya haya un estado activo del que leer el nombre.
	animador.inicializar(self)
	etiqueta_estado.visible = mostrar_estado
	if mostrar_estado:
		maquina.estado_cambiado.connect(_al_cambiar_estado)
		etiqueta_estado.text = maquina.nombre_actual()

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("saltar"):
		_buffer_restante = jump_buffer
	elif evento.is_action_pressed("cambiar_arma"):
		arma.siguiente_arma()
	elif evento.is_action_pressed("curar"):
		usar_venda()

func _physics_process(delta: float) -> void:
	_actualizar_temporizadores(delta)
	var estaba_en_suelo: bool = is_on_floor()
	maquina.procesar_fisica(delta)
	move_and_slide()
	_recordar_suelo()
	if is_on_ceiling():
		_corregir_esquina()
	if estaba_en_suelo and not is_on_floor():
		_coyote_restante = coyote_time

func _actualizar_temporizadores(delta: float) -> void:
	_coyote_restante = maxf(0.0, _coyote_restante - delta)
	_buffer_restante = maxf(0.0, _buffer_restante - delta)
	_enfriamiento_rodar_restante = maxf(0.0, _enfriamiento_rodar_restante - delta)
	_enfriamiento_ataque_restante = maxf(0.0, _enfriamiento_ataque_restante - delta)

func _recordar_suelo() -> void:
	if not is_on_floor():
		return
	for i: int in get_slide_collision_count():
		var choque: KinematicCollision2D = get_slide_collision(i)
		if choque.get_collider() is TileMapLayer and choque.get_normal().y < -0.7:
			if _suelo_a_ambos_lados():
				ultimo_suelo_seguro = global_position
			return

## Hay suelo de sobra a los dos lados. Sin esto, el ultimo punto al salir andando de
## un borde era el de la ultima pisada, con el cuerpo ya colgando: se reaparecia sin
## apoyo y se volvia a caer a los pinchos, una y otra vez hasta morir.
func _suelo_a_ambos_lados() -> bool:
	const MARGEN: float = 12.0
	const ABAJO: Vector2 = Vector2(0.0, 2.0)
	return test_move(global_transform.translated(Vector2(-MARGEN, 0.0)), ABAJO) \
		and test_move(global_transform.translated(Vector2(MARGEN, 0.0)), ABAJO)

## Lo llama Pinchos. Duele y devuelve al ultimo suelo firme, con la gracia del
## golpe puesta (como en Hollow Knight). Si el golpe mata, de la reaparicion se
## encarga _al_morir: revive antes de volver de aqui, por eso se mira ANTES.
func caer_en_pinchos(dano: int, fuente: Node) -> void:
	var mortal: bool = salud.salud_actual <= dano
	salud.herir_ignorando_gracia(dano, Vector2.DOWN, fuente)
	if mortal:
		return
	velocity = Vector2.ZERO
	set_deferred("global_position", ultimo_suelo_seguro)

# --- API que usan los estados ---

## -1, 0 o 1 según las acciones de movimiento. Nunca leer teclas físicas acá.
func entrada_horizontal() -> float:
	return Input.get_axis("mover_izq", "mover_der")

## Acelera hacia la velocidad objetivo. Si no hay input, frena.
func mover_horizontal(delta: float, velocidad_tope: float) -> void:
	var direccion: float = entrada_horizontal()
	var factor: float = 1.0 if is_on_floor() else control_aereo
	if direccion != 0.0:
		mira = signi(int(direccion))
		sprite.flip_h = mira < 0
		var aceleracion: float = velocidad_tope / maxf(tiempo_acelerar, 0.001) * factor
		velocity.x = move_toward(velocity.x, direccion * velocidad_tope, aceleracion * delta)
	else:
		frenar(delta)

func frenar(delta: float) -> void:
	var factor: float = 1.0 if is_on_floor() else control_aereo
	var desaceleracion: float = velocidad_caminar / maxf(tiempo_frenar, 0.001) * factor
	velocity.x = move_toward(velocity.x, 0.0, desaceleracion * delta)

func aplicar_gravedad(delta: float) -> void:
	var g: float = gravedad_subida if velocity.y < 0.0 else gravedad_caida
	velocity.y = minf(velocity.y + g * delta, velocidad_caida_maxima)

## Hay un salto pedido (ahora o hace poco) esperando a ejecutarse.
func hay_salto_pedido() -> bool:
	return _buffer_restante > 0.0

## Puede saltar si está en el suelo o si todavía le queda coyote time.
func puede_saltar() -> bool:
	return is_on_floor() or _coyote_restante > 0.0

func ejecutar_salto() -> void:
	velocity.y = velocidad_salto
	_buffer_restante = 0.0
	_coyote_restante = 0.0

## Corta el ascenso al soltar el botón. Da el salto de altura variable.
func cortar_salto() -> void:
	if velocity.y < 0.0:
		velocity.y *= factor_corte_salto

func puede_atacar() -> bool:
	return _enfriamiento_ataque_restante <= 0.0 and salud.esta_vivo()

## La cadencia la manda el arma equipada; enfriamiento_ataque es solo el respaldo
## para cuando todavía no hay ninguna.
func iniciar_enfriamiento_ataque() -> void:
	var equipada: ArmaData = arma.arma_actual()
	_enfriamiento_ataque_restante = equipada.cadencia if equipada != null else enfriamiento_ataque

func duracion_total_ataque() -> float:
	return anticipacion_ataque + duracion_golpe + recuperacion_ataque

## Prepara el golpe del lado hacia el que mira. Los valores salen del ArmaData
## equipado; los @export de abajo solo se usan si no hay ninguna arma.
func orientar_hitbox() -> void:
	if arma.arma_actual() != null:
		arma.preparar(mira)
		return
	hitbox_ataque.position.x = mira * alcance_ataque
	hitbox_ataque.dano = dano_ataque

func puede_rodar() -> bool:
	return _enfriamiento_rodar_restante <= 0.0

func iniciar_enfriamiento_rodar() -> void:
	_enfriamiento_rodar_restante = enfriamiento_rodar

## Cambia la caja de colisión al agacharse y al levantarse.
func ajustar_forma(agachado: bool) -> void:
	var rect: RectangleShape2D = forma.shape as RectangleShape2D
	if rect == null:
		return
	var alto: float = 14.0 if agachado else 24.0
	rect.size = Vector2(rect.size.x, alto)
	forma.position.y = -alto * 0.5
	# La hurtbox tambien: antes agacharse encogia el cuerpo pero no la zona que
	# recibe golpes, asi que agacharse no esquivaba nada que pasara por arriba.
	var zona: CollisionShape2D = hurtbox.get_node_or_null("Forma") as CollisionShape2D
	if zona != null and zona.shape is RectangleShape2D:
		(zona.shape as RectangleShape2D).size.y = alto
		zona.position.y = -alto * 0.5

## True si hay techo justo encima y no puede levantarse.
func hay_techo_encima() -> bool:
	return test_move(global_transform, Vector2(0.0, -10.0))

# --- Corner correction ---

## Si la cabeza pega en una esquina por 1-2 px, lo empuja al costado en vez de frenarlo.
func _corregir_esquina() -> void:
	if velocity.y >= 0.0:
		return
	for px: int in range(1, correccion_esquina_px + 1):
		for lado: int in [1, -1]:
			var desvio: Vector2 = Vector2(px * lado, 0.0)
			if not test_move(global_transform.translated(desvio), Vector2(0.0, -2.0)):
				global_position += desvio
				return
	velocity.y = 0.0

## Consume una venda si queda alguna y falta salud. Devuelve true si se usó.
func usar_venda() -> bool:
	if vendas <= 0 or salud.salud_actual >= salud.salud_maxima:
		return false
	vendas -= 1
	salud.curar(curacion_por_venda)
	vendas_cambiadas.emit(vendas)
	return true

func recoger_venda(cantidad: int = 1) -> void:
	vendas = mini(vendas_maximas, vendas + cantidad)
	vendas_cambiadas.emit(vendas)

# --- Lo que lleva encima ---
# Lo usan TerminalCRT al guardar y PuertaNivel al cambiar de nivel: el nodo
# Jugador muere con la escena, asi que lo que lleva encima viaja como diccionario.

## Salud, vendas y arsenal, con ids de arma en vez de recursos para que se pueda
## escribir tal cual en el JSON de guardado.
func instantanea() -> Dictionary:
	var ids: Array[String] = []
	for propia: ArmaData in arma.arsenal:
		ids.append(propia.id)
	var equipada: ArmaData = arma.arma_actual()
	return {
		"salud": salud.salud_actual,
		"vendas": vendas,
		"armas": ids,
		"arma_equipada": equipada.id if equipada != null else "",
	}

## Lo contrario de instantanea(). Las claves que falten se quedan como estaban.
func restaurar(datos: Dictionary) -> void:
	vendas = int(datos.get("vendas", vendas))
	vendas_cambiadas.emit(vendas)
	var salud_guardada: int = int(datos.get("salud", 0))
	if salud_guardada > 0:
		salud.salud_actual = mini(salud_guardada, salud.salud_maxima)
		salud.salud_cambiada.emit(salud.salud_actual, salud.salud_maxima)
	_restaurar_arsenal(datos.get("armas", []), str(datos.get("arma_equipada", "")))

## Vuelve a meter en el arsenal las armas que ya tenia, por id. Se recorre la
## carpeta y no una lista escrita a mano: agregar un .tres nuevo sigue sin
## obligar a tocar codigo (CLAUDE.md §3.2).
func _restaurar_arsenal(ids: Array, equipada: String) -> void:
	if ids.is_empty():
		return
	for disponible: ArmaData in ComponenteArma.cargar_carpeta(arma.carpeta_armas):
		if ids.has(disponible.id):
			arma.obtener(disponible)
	for i: int in arma.arsenal.size():
		if arma.arsenal[i].id == equipada:
			arma.equipar(i)
			return

# --- Control externo (la TerminalCRT lo usa durante su escena) ---

## Devuelve o quita el control al jugador sin sacarlo del árbol.
func fijar_control(activo: bool) -> void:
	set_physics_process(activo)
	set_process_unhandled_input(activo)
	if not activo:
		velocity = Vector2.ZERO
		maquina.cambiar_a("Quieto")

## Postura de sentado frente al CRT (CLAUDE.md §3.4). El animador sostiene la
## pose mientras dure la escena; al salir vuelve al estado que tenga la máquina.
func sentarse(activo: bool) -> void:
	if activo:
		animador.sentar()
	else:
		animador.sincronizar()

# --- Reacciones al daño ---

func _al_recibir_dano(_cantidad: int, direccion: Vector2) -> void:
	direccion_ultimo_golpe = direccion
	sprite.modulate = tinte_herido
	Efectos.chispas(self, global_position + Vector2(0.0, -12.0), direccion,
		Color(1.0, 0.42, 0.36))
	# Mas fuerte que un golpe dado: recibir tiene que doler mas que acertar.
	Impacto.golpe(0.75)
	DirectorAudio.efecto("dano", -4.0)
	maquina.cambiar_a("Herido")

func _al_terminar_invulnerabilidad() -> void:
	sprite.modulate = Color.WHITE

func _al_morir(_fuente: Node) -> void:
	EstadoJuego.sumar("muertes")
	Efectos.restos(self, global_position + Vector2(0.0, -12.0))
	Impacto.muerte(1.0)
	DirectorAudio.efecto("rotura", -3.0, 0.75)
	# Reaparición provisional. En el Hito 5 esto pasa a ser la última TerminalCRT.
	global_position = punto_de_reaparicion
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	salud.revivir()
	maquina.cambiar_a("Quieto")

func _al_cambiar_estado(_anterior: String, nuevo: String) -> void:
	etiqueta_estado.text = nuevo
