# Datos de un arma. Es un Resource puro: no tiene nodos ni comportamiento.
# Cada arma vive como un .tres en systems/weapons/data/ y ComponenteArma los carga
# solos al arrancar, así que agregar un arma NO requiere tocar código (CLAUDE.md §3.2).
class_name ArmaData
extends Resource

enum Tipo { MELEE, FUEGO, PLASMA, RADIACION }

@export_group("Identidad")
## Id técnico, el que va al JSON de guardado. Sin espacios ni tildes.
@export var id: String = ""
## Nombre visible en el Arsenal del diario.
@export var nombre: String = ""
@export var tipo: Tipo = Tipo.MELEE

@export_group("Combate")
@export var dano: int = 1
## Segundos entre un ataque y el siguiente con esta arma.
@export var cadencia: float = 0.3
## Empuje que recibe el jugador al usarla. Las armas pesadas se sienten.
@export var retroceso: float = 0.0
## Píxeles por delante donde nace el golpe (melee) o el proyectil.
@export var alcance: float = 16.0

@export_group("A distancia")
@export var es_a_distancia: bool = false
@export var escena_proyectil: PackedScene
@export var velocidad_proyectil: float = 220.0
## Segundos que vive el proyectil antes de desaparecer solo.
@export var vida_proyectil: float = 1.2

@export_group("Eje del alma")
## Cuánto empuja el eje al matar con esta arma. Positivo = humano, negativo = máquina.
## Valores sugeridos por CLAUDE.md §3.2: melee +0.02, fuego +0.01, plasma -0.02, radiación -0.03.
@export var peso_hum: float = 0.0

@export_group("Presentación")
## Entrada del diario, en primera persona. La escriben ustedes, no Claude Code.
@export_multiline var texto_diario: String = ""
@export var sprite: Texture2D
@export var sfx: AudioStream

func es_humana() -> bool:
	return peso_hum > 0.0

func nombre_tipo() -> String:
	return Tipo.keys()[tipo].capitalize()
