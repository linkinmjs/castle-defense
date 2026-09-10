class_name HabilidadImpulso
extends Habilidad
## Empuja al healer hacia donde apunta el mouse. No cura: existe para llegar
## a tiempo, que en este juego es la mitad del problema.

@export var fuerza: float = 620.0
@export var duracion: float = 0.22


func ejecutar(healer: Node) -> String:
	# El healer decide la direccion: la habilidad no necesita saber en cuantas
	# dimensiones vive el mundo.
	healer.impulsar_hacia_mouse(fuerza, duracion)
	return ""
