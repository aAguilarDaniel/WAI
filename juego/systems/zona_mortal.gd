# Area bajo el nivel: caerse mata. La reaparicion la resuelve el propio jugador,
# que vuelve a la ultima TerminalCRT que activo (CLAUDE.md §3.5).
class_name ZonaMortal
extends Area2D

func _ready() -> void:
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo: Node2D) -> void:
	var jugador: Jugador = cuerpo as Jugador
	if jugador != null:
		jugador.salud.matar(self)
