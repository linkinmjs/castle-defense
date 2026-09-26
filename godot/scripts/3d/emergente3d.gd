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


func _process(_delta: float) -> void:
	var progreso := 1.0 - clampf(_restante / duracion, 0.0, 1.0)
	# Crece hasta su tamano final y late mas rapido cuanto mas cerca esta.
	var latido := 0.85 + 0.15 * sin(progreso * progreso * 40.0)
	var lado := lerpf(0.2, 1.0, progreso) * latido
	_marca.scale = Vector3(lado, 1.0, lado)


## La cuenta va con la fisica y el latido con el frame: lo que se ve puede ir
## a cualquier ritmo, pero el enemigo tiene que salir en el mismo tick en cada
## corrida, porque desde ahi entra al combate.
func _physics_process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0:
		# Un frame lento corre varios pasos de fisica antes de liberar el
		# nodo: sin esto avisaria una vez por paso.
		set_physics_process(false)
		termino.emit(global_position)
		queue_free()
