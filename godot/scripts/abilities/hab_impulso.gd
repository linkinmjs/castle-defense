class_name HabilidadImpulso
extends Habilidad
## Empuja al healer hacia donde apunta el mouse. No cura: existe para llegar
## a tiempo, que en este juego es la mitad del problema.

@export var fuerza: float = 620.0
@export var duracion: float = 0.22


func ejecutar(healer: Node) -> String:
	var direccion: Vector2 = healer.get_global_mouse_position() - healer.global_position
	if direccion.length() < 4.0:
		direccion = Vector2.RIGHT if not healer.mirando_izquierda() else Vector2.LEFT
	healer.impulsar(direccion.normalized(), fuerza, duracion)
	return ""
