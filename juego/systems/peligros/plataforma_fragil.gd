# Plataforma que cede: aguanta un momento con el jugador encima, tiembla, cae y
# vuelve a su sitio al rato. Peligro del nivel 4 (la cornisa). La instancia
# tools/generar_nivel_04.gd.
#
# Mismo idioma que el resto del juego: AVISO (tiembla y cruje), GOLPE (cae),
# DESCANSO (vuelve). Se lee distinta de la viga del tileset a proposito.
class_name PlataformaFragil
extends StaticBody2D

enum Fase { FIRME, TEMBLANDO, CAIDA }

## Segundos que aguanta desde que alguien la pisa.
@export var aguante: float = 0.5
## Segundos hasta que vuelve a aparecer.
@export var reaparicion: float = 2.6

@onready var sprite: Sprite2D = $Sprite
@onready var forma: CollisionShape2D = $Forma
@onready var sensor: Area2D = $Sensor

var _fase: Fase = Fase.FIRME
var _reloj: float = 0.0

func _ready() -> void:
	sensor.body_entered.connect(_al_pisar)

func _process(delta: float) -> void:
	if _fase == Fase.FIRME:
		return
	_reloj -= delta
	if _fase == Fase.TEMBLANDO:
		sprite.position.x = (1.0 if int(_reloj * 40.0) % 2 == 0 else -1.0)
		if _reloj <= 0.0:
			_caer()
	elif _fase == Fase.CAIDA and _reloj <= 0.0:
		_volver()

func _al_pisar(cuerpo: Node2D) -> void:
	if _fase != Fase.FIRME or not (cuerpo is Jugador):
		return
	_fase = Fase.TEMBLANDO
	_reloj = aguante
	DirectorAudio.efecto_variado("derrumbe", -16.0, 0.15)

func _caer() -> void:
	_fase = Fase.CAIDA
	_reloj = reaparicion
	forma.set_deferred("disabled", true)
	sprite.position = Vector2.ZERO
	Efectos.polvo(self, global_position + Vector2(0.0, 4.0), 0.9)
	DirectorAudio.efecto_variado("derrumbe", -8.0, 0.1)
	var caida: Tween = create_tween().set_parallel(true)
	caida.tween_property(sprite, "position:y", 40.0, 0.5).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	caida.tween_property(sprite, "modulate:a", 0.0, 0.5)

func _volver() -> void:
	_fase = Fase.FIRME
	sprite.position = Vector2.ZERO
	forma.set_deferred("disabled", false)
	var vuelta: Tween = create_tween()
	vuelta.tween_property(sprite, "modulate:a", 1.0, 0.35)
