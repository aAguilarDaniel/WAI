# Prensa: un piston que cae del techo con un ciclo fijo. Peligro del nivel 6 (los
# hornos). La instancia tools/generar_nivel_06.gd.
#
# Mismo idioma que el arco: DESCANSO (arriba), AVISO (tiembla, chispas, 0.55 s),
# GOLPE (baja en 0.12 s) y vuelve a subir. Solo hace dano al bajar: quedarse
# debajo mientras sube no castiga, lo que castiga es no leer el aviso.
# Varias seguidas con desfase obligan a pasar una, esperar y pasar la otra.
class_name Prensa
extends Node2D

enum Fase { ARRIBA, AVISO, BAJANDO, ABAJO, SUBIENDO }

## Distancia del techo al suelo, en px. La cabeza mide 16.
@export var recorrido: float = 64.0
@export var tiempo_arriba: float = 1.5
@export var tiempo_aviso: float = 0.55
@export var tiempo_bajada: float = 0.12
@export var tiempo_abajo: float = 0.45
@export var tiempo_subida: float = 0.8
@export var desfase: float = 0.0
@export var dano: int = 2

@onready var cabeza: Node2D = $Cabeza
@onready var vastago: Sprite2D = $Vastago
@onready var hitbox: ComponenteHitbox = $Cabeza/Hitbox

var _fase: Fase = Fase.ARRIBA
var _reloj: float = 0.0
var _abajo: float = 0.0

func _ready() -> void:
	_abajo = recorrido - 16.0
	hitbox.dano = dano
	hitbox.desactivar()
	_reloj = tiempo_arriba - fposmod(desfase, tiempo_arriba)
	_colocar(0.0)

func _process(delta: float) -> void:
	_reloj -= delta
	match _fase:
		Fase.ARRIBA:
			if _reloj <= 0.0:
				_entrar(Fase.AVISO, tiempo_aviso)
		Fase.AVISO:
			cabeza.position.x = 1.0 if int(_reloj * 40.0) % 2 == 0 else -1.0
			if _reloj <= 0.0:
				cabeza.position.x = 0.0
				hitbox.activar()
				_entrar(Fase.BAJANDO, tiempo_bajada)
		Fase.BAJANDO:
			_colocar(1.0 - clampf(_reloj / tiempo_bajada, 0.0, 1.0))
			if _reloj <= 0.0:
				_colocar(1.0)
				_golpear()
				_entrar(Fase.ABAJO, tiempo_abajo)
		Fase.ABAJO:
			if _reloj <= tiempo_abajo - 0.08:
				hitbox.desactivar()
			if _reloj <= 0.0:
				_entrar(Fase.SUBIENDO, tiempo_subida)
		Fase.SUBIENDO:
			_colocar(clampf(_reloj / tiempo_subida, 0.0, 1.0))
			if _reloj <= 0.0:
				_entrar(Fase.ARRIBA, tiempo_arriba)

func _entrar(fase: Fase, duracion: float) -> void:
	_fase = fase
	_reloj = duracion
	if fase == Fase.AVISO:
		Efectos.chispas(self, global_position + Vector2(0.0, 8.0), Vector2.DOWN, Color(1.0, 0.7, 0.35))

## 0 arriba, 1 abajo.
func _colocar(t: float) -> void:
	cabeza.position.y = _abajo * t
	vastago.region_rect = Rect2(0, 0, 8, maxf(1.0, cabeza.position.y + 2.0))

func _golpear() -> void:
	Efectos.polvo(self, global_position + Vector2(0.0, recorrido), 1.1)
	DirectorAudio.efecto_variado("prensa", -6.0, 0.1)
	var jugador: Node2D = get_tree().get_first_node_in_group("jugador") as Node2D
	if jugador != null and jugador.global_position.distance_to(global_position) < 140.0:
		Impacto.sacudir(2.2, 0.18)
