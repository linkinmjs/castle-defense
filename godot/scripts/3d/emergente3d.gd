class_name Emergente3D
extends Node3D
## Aviso en el suelo de que algo esta por salir. Late cada vez mas rapido y,
## cuando termina, avisa donde para que la batalla haga aparecer al enemigo.
##
## El aviso no es cortesia: sin el, morir por un zombi que sale justo debajo
## seria injusto, y la regla es que morir se vea venir.

signal termino(posicion: Vector3)

@export var duracion: float = 1.0

var _restante: float

@onready var _marca: MeshInstance3D = $Marca


func _ready() -> void:
	_restante = duracion
	_marca.scale = Vector3(0.2, 1.0, 0.2)


func _process(delta: float) -> void:
	_restante -= delta
	var progreso := 1.0 - clampf(_restante / duracion, 0.0, 1.0)
	# Crece hasta su tamano final y late mas rapido cuanto mas cerca esta.
	var latido := 0.85 + 0.15 * sin(progreso * progreso * 40.0)
	var lado := lerpf(0.2, 1.0, progreso) * latido
	_marca.scale = Vector3(lado, 1.0, lado)

	if _restante <= 0.0:
		termino.emit(global_position)
		queue_free()
