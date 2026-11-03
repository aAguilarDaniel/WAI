# Area bajo el nivel: caerse mata. La reaparicion la resuelve el propio jugador,
# que vuelve a la ultima TerminalCRT que activo (CLAUDE.md §3.5).
#
# Tambien mata ENEMIGOS: un golpe puede empujar a uno al abismo, y antes caia
# para siempre sin morir. Con el final secreto (matarlos a todos) eso lo volvia
# imposible sin que el jugador pudiera saberlo.
class_name ZonaMortal
extends Area2D

func _ready() -> void:
	collision_mask = 2 | 4                  # jugador y enemigos
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo: Node2D) -> void:
	var salud: ComponenteSalud = cuerpo.get_node_or_null("Salud") as ComponenteSalud
	if salud != null:
		salud.matar(self)
