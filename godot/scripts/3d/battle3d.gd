extends Node3D
## Escena principal del prototipo 3D.
##
## Despliega los dos ejercitos, manda refuerzos y sigue al healer con la
## camara. El combate lo resuelve cada unidad por su cuenta.

const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")

@export var ancho_campo: float = 30.0
@export var profundidad_campo: float = 10.0

@export_group("Camara")
## Cuanto se aleja la camara del healer, sobre el eje de vision.
@export var distancia_camara: float = 11.0
## Angulo picado: 0 seria de perfil puro, 90 seria cenital.
@export var angulo_camara: float = 15.0
## La camara mira a la altura del pecho, no a los pies.
@export var altura_objetivo: float = 1.05
@export var suavizado_camara: float = 5.0

@export_group("Ejercitos")
@export var base_aliada_x: float = 1.5
@export var base_enemiga_x: float = 28.5
## Los dos ejercitos arrancan ya trabados en el centro: si salieran desde las
## bases habria medio minuto de marcha antes de ver el primer golpe.
@export var unidades_iniciales: int = 6
@export var refuerzos_por_tanda: int = 2
@export var intervalo_refuerzos: float = 9.0

@onready var _healer: Healer3D = %Healer
@onready var _camara: Camera3D = %Camara
@onready var _unidades: Node3D = %Unidades
@onready var _overlay: Control = %Overlay
@onready var _hud: CanvasLayer = %HUD


func _ready() -> void:
	_healer.limites = Rect2(1.5, 1.5, ancho_campo - 3.0, profundidad_campo - 3.0)
	_camara.global_position = _posicion_deseada()
	_camara.look_at(_objetivo_camara(), Vector3.UP)

	# Apuntar y dibujar barras necesitan proyectar el mundo a pantalla.
	_healer.usar_camara(_camara)
	_overlay.seguir(_camara)
	_hud.seguir(_healer)

	_desplegar_formacion_inicial()

	var reloj := Timer.new()
	reloj.wait_time = intervalo_refuerzos
	reloj.timeout.connect(_enviar_refuerzos)
	add_child(reloj)
	reloj.start()


func _process(delta: float) -> void:
	# La camara solo sigue el avance del frente (X). Si tambien siguiera la
	# profundidad, el horizonte subiria y bajaria al caminar y marearia.
	var deseada := _posicion_deseada()
	_camara.global_position = _camara.global_position.lerp(
		deseada, 1.0 - exp(-suavizado_camara * delta))
	_camara.look_at(_objetivo_camara(), Vector3.UP)


func _desplegar_formacion_inicial() -> void:
	var centro := ancho_campo * 0.5
	for i in unidades_iniciales:
		_crear_unidad(Unidad3D.Bando.ALIADO, centro - randf_range(1.5, 4.5))
		_crear_unidad(Unidad3D.Bando.ENEMIGO, centro + randf_range(1.5, 4.5))


func _enviar_refuerzos() -> void:
	for i in refuerzos_por_tanda:
		_crear_unidad(Unidad3D.Bando.ALIADO, base_aliada_x + randf_range(0.5, 1.5))
		_crear_unidad(Unidad3D.Bando.ENEMIGO, base_enemiga_x - randf_range(0.5, 1.5))


func _crear_unidad(bando: Unidad3D.Bando, x: float) -> void:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando)
	unidad.position = Vector3(x, 0.0, randf_range(1.5, profundidad_campo - 1.5))
	_unidades.add_child(unidad)


func _objetivo_camara() -> Vector3:
	return Vector3(_healer.global_position.x, altura_objetivo, profundidad_campo * 0.5)


func _posicion_deseada() -> Vector3:
	var objetivo := _objetivo_camara()
	var radianes := deg_to_rad(angulo_camara)
	return objetivo + Vector3(
		0.0,
		sin(radianes) * distancia_camara,
		cos(radianes) * distancia_camara)
