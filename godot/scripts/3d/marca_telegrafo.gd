class_name MarcaTelegrafo
extends Node3D
## Aviso en el suelo de un golpe que esta por caer. El area que va a pegar se
## ve desde el primer momento; adentro, un disco crece hasta llenarla y late
## cada vez mas rapido, como el emergente.
##
## Igual que el emergente, no es cortesia: el bruto y el jefe pegan fuerte a
## proposito, y la regla es que morir se vea venir. Con la marca el healer
## decide si salta, si bendice al que la va a recibir o si cura despues.
##
## Solo avisa. El golpe lo resuelve la unidad con su propio reloj y la libera
## al conectar o al perderlo; el reloj de aca es un respaldo para que no quede
## una marca sola en el suelo si la unidad desaparece sin avisar.
##
## Los discos de la escena miden 1 m de radio: la escala es el radio en metros.

## Fraccion del radio con la que arranca el disco que crece.
const INICIO := 0.3

var duracion: float = 1.0
var radio: float = 1.0
var _restante: float = 1.0

@onready var _area: MeshInstance3D = $Area
@onready var _carga: MeshInstance3D = $Carga


## Arranca la cuenta. Se puede llamar antes o despues de entrar al arbol.
func iniciar(nueva_duracion: float, nuevo_radio: float) -> void:
	duracion = maxf(nueva_duracion, 0.01)
	radio = maxf(nuevo_radio, 0.01)
	_restante = duracion
	if is_node_ready():
		_dibujar()


## La libera antes de tiempo: el golpe ya no va a caer.
func cancelar() -> void:
	set_physics_process(false)
	queue_free()


## 0 recien marcada, 1 en el momento del golpe.
func progreso() -> float:
	return 1.0 - clampf(_restante / duracion, 0.0, 1.0)


func _ready() -> void:
	_dibujar()


func _process(_delta: float) -> void:
	_dibujar()


## La cuenta va con la fisica y el latido con el frame, como en el emergente:
## lo que se ve puede ir a cualquier ritmo, pero se libera en el mismo tick en
## cada corrida.
func _physics_process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0:
		# Un frame lento corre varios pasos de fisica antes de liberar el
		# nodo: sin esto pediria liberarse una vez por paso.
		set_physics_process(false)
		queue_free()


## El area queda fija en el radio del golpe: con la camara casi de costado
## el suelo se ve muy chato, y un disco que recien al final llega a su tamano
## no diria hasta donde pega hasta que ya es tarde.
func _dibujar() -> void:
	var avance := progreso()
	var latido := 0.85 + 0.15 * sin(avance * avance * 40.0)
	var lado := lerpf(INICIO, 1.0, avance) * latido * radio
	_carga.scale = Vector3(lado, 1.0, lado)
	_area.scale = Vector3(radio, 1.0, radio)
