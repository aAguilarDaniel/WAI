# Arco electrico entre dos nodos (suelo y techo). Peligro del nivel 2.
# Lo instancia tools/generar_nivel_02.gd en los pasillos de la nave.
#
# Es un enemigo sin cuerpo con el MISMO idioma que el de patrulla: avisa, golpea
# y descansa. El aviso (chispas y zumbido) es la ventana para decidir; el
# descanso es cuando se pasa. Rodar atraviesa el arco si se acierta el momento,
# porque los i-frames del rodar valen para todo (CLAUDE.md §7).
#
# El dano lo hace un ComponenteHitbox normal en la capa de hitbox_enemigo: el
# jugador no distingue entre un arco y una embestida, y no hace falta.
class_name ArcoElectrico
extends Node2D

enum Fase { APAGADO, AVISO, ACTIVO }

## Distancia entre los dos nodos, en px. Debe coincidir con el hueco suelo-techo.
@export var altura: float = 64.0
@export var tiempo_apagado: float = 1.6
## Chispas sueltas antes de la descarga. Es la telegrafia: nunca bajar de ~0.4 s.
@export var tiempo_aviso: float = 0.6
@export var tiempo_activo: float = 0.7
## Segundos de adelanto en el ciclo. Dos arcos seguidos desfasados obligan a
## pasar uno y esperar entre los dos.
@export var desfase: float = 0.0
@export var dano: int = 1
@export var color_nucleo: Color = Color(0.92, 1.0, 1.0)
@export var color_halo: Color = Color(0.47, 0.91, 0.96, 0.6)
## Cada cuanto se vuelve a comprobar el contacto mientras esta activo. Sin esto,
## quedarse quieto dentro del arco solo dolia una vez.
@export var intervalo_dano: float = 0.3

@onready var hitbox: ComponenteHitbox = $Hitbox
@onready var forma: CollisionShape2D = $Hitbox/Forma
@onready var emisor_abajo: Sprite2D = $EmisorAbajo
@onready var emisor_arriba: Sprite2D = $EmisorArriba
@onready var rayo: Line2D = $Rayo
@onready var halo: Line2D = $Halo
@onready var brillo: Sprite2D = $Brillo

var _fase: Fase = Fase.APAGADO
var _reloj: float = 0.0
var _reloj_rayo: float = 0.0
var _reloj_dano: float = 0.0

func _ready() -> void:
	var caja: RectangleShape2D = RectangleShape2D.new()
	caja.size = Vector2(8.0, maxf(8.0, altura - 8.0))
	forma.shape = caja
	forma.position = Vector2(0.0, -altura * 0.5)
	emisor_arriba.position = Vector2(0.0, -altura + 5.0)
	brillo.position = Vector2(0.0, -altura * 0.5)
	brillo.scale = Vector2(0.8, altura / 48.0)
	hitbox.dano = dano
	hitbox.desactivar()
	rayo.default_color = color_nucleo
	halo.default_color = color_halo
	_entrar(Fase.APAGADO)
	_reloj = fposmod(tiempo_apagado - desfase, tiempo_apagado + tiempo_aviso + tiempo_activo)

func _process(delta: float) -> void:
	_reloj -= delta
	match _fase:
		Fase.APAGADO:
			if _reloj <= 0.0:
				_entrar(Fase.AVISO)
		Fase.AVISO:
			_chisporrotear(delta)
			if _reloj <= 0.0:
				_entrar(Fase.ACTIVO)
		Fase.ACTIVO:
			_descargar(delta)
			if _reloj <= 0.0:
				_entrar(Fase.APAGADO)

func _entrar(fase: Fase) -> void:
	_fase = fase
	match fase:
		Fase.APAGADO:
			_reloj += tiempo_apagado
			hitbox.desactivar()
			rayo.visible = false
			halo.visible = false
			brillo.modulate.a = 0.0
		Fase.AVISO:
			_reloj += tiempo_aviso
			_sonar("aviso_arco", -14.0)
		Fase.ACTIVO:
			_reloj += tiempo_activo
			_reloj_dano = 0.0
			hitbox.activar()
			rayo.visible = true
			halo.visible = true
			_sonar("arco", -8.0)

## Aviso: chispazos cortos que salen de los nodos y no llegan a unirse.
func _chisporrotear(delta: float) -> void:
	var progreso: float = 1.0 - clampf(_reloj / maxf(tiempo_aviso, 0.01), 0.0, 1.0)
	brillo.modulate = Color(color_halo.r, color_halo.g, color_halo.b, 0.12 + progreso * 0.25)
	_reloj_rayo -= delta
	if _reloj_rayo > 0.0:
		return
	_reloj_rayo = 0.06
	var visible_ahora: bool = randf() < 0.5 + progreso * 0.4
	rayo.visible = visible_ahora
	halo.visible = false
	if visible_ahora:
		var desde_arriba: bool = randf() < 0.5
		var largo: float = altura * randf_range(0.15, 0.25 + progreso * 0.3)
		var inicio: float = -altura + 4.0 if desde_arriba else -4.0
		var fin: float = inicio + largo if desde_arriba else inicio - largo
		_trazar(rayo, inicio, fin, 2.0)

## Descarga: el rayo entero, recalculado cada pocos frames para que se retuerza.
func _descargar(delta: float) -> void:
	_reloj_rayo -= delta
	if _reloj_rayo <= 0.0:
		_reloj_rayo = 0.045
		_trazar(rayo, -4.0, -altura + 4.0, 3.0)
		halo.points = rayo.points
	brillo.modulate = Color(color_halo.r, color_halo.g, color_halo.b,
		0.45 + sin(Time.get_ticks_msec() * 0.05) * 0.1)
	_reloj_dano -= delta
	if _reloj_dano <= 0.0:
		_reloj_dano = intervalo_dano
		# Apagar y encender la hitbox vuelve a detectar a quien siga dentro.
		hitbox.desactivar()
		hitbox.set_deferred("monitoring", true)

func _trazar(linea: Line2D, desde: float, hasta: float, desvio: float) -> void:
	var puntos: PackedVector2Array = PackedVector2Array()
	var pasos: int = maxi(2, int(absf(hasta - desde) / 6.0))
	for i: int in pasos + 1:
		var t: float = float(i) / float(pasos)
		var x: float = 0.0 if i == 0 or i == pasos else randf_range(-desvio, desvio)
		puntos.append(Vector2(roundf(x), roundf(lerpf(desde, hasta, t))))
	linea.points = puntos

## Solo suena si esta cerca de la camara: un arco del otro lado del nivel no
## tiene por que oirse.
func _sonar(nombre: String, volumen: float) -> void:
	var camara: Camera2D = get_viewport().get_camera_2d()
	if camara == null:
		return
	if camara.get_screen_center_position().distance_to(global_position) < 260.0:
		DirectorAudio.efecto_variado(nombre, volumen)
