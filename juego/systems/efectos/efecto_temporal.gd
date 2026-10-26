# Libera el nodo cuando sus particulas terminan. Lo llevan las tres escenas de
# systems/efectos/: son de un solo uso y nadie las recoge.
extends CPUParticles2D

func _ready() -> void:
	finished.connect(queue_free)
	# Red de seguridad: si por lo que sea no llega finished (one_shot en false,
	# el nodo pausado en el frame justo), se va igual pasado el doble de su vida.
	get_tree().create_timer(lifetime * 2.5 + 1.0).timeout.connect(queue_free)
