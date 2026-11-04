# Pinchos del fondo de los pozos. Los instancia ConstructorNivel en los niveles
# con abismos (1, 2 y 4). Al jugador le duelen y lo devuelven a tierra firme; a un
# enemigo que cae lo matan, para que siga contando en RegistroEnemigos.
class_name Pinchos
extends Area2D

@export var dano: int = 2
## Ancho en px. El sprite se repite y la zona de dano se ajusta.
@export var ancho: float = 32.0

@onready var sprite: Sprite2D = $Sprite
@onready var forma: CollisionShape2D = $Forma

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4                  # jugador y enemigos
	sprite.region_rect = Rect2(0.0, 0.0, ancho, 12.0)
	sprite.offset = Vector2(-ancho * 0.5, -12.0)
	var caja: RectangleShape2D = RectangleShape2D.new()
	caja.size = Vector2(ancho, 10.0)
	forma.shape = caja
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo: Node2D) -> void:
	var jugador: Jugador = cuerpo as Jugador
	if jugador != null:
		jugador.caer_en_pinchos(dano, self)
		return
	var salud: ComponenteSalud = cuerpo.get_node_or_null("Salud") as ComponenteSalud
	if salud != null:
		salud.matar(self)
