extends Node2D
## Escena principal del prototipo de batalla.
##
## Despliega los dos ejercitos y va mandando refuerzos. El combate lo resuelve
## cada unidad por su cuenta: aca solo se decide quien entra al campo y cuando.

const ESCENA_UNIDAD := preload("res://scenes/units/unidad.tscn")

@export var ancho_campo: float = 1800.0
@export var banda_alta: float = 40.0
@export var banda_baja: float = 280.0
## Altura fija a la que mira la camara: el campo es lateral, no conviene que
## suba y baje siguiendo la profundidad del healer.
@export var altura_camara: float = 150.0

@export_group("Ejercitos")
@export var base_aliada_x: float = 100.0
@export var base_enemiga_x: float = 1700.0
## Los dos ejercitos arrancan ya trabados en el centro: si salieran desde las
## bases habria medio minuto de marcha antes de ver el primer golpe.
@export var unidades_iniciales: int = 6
@export var refuerzos_por_tanda: int = 2
@export var intervalo_refuerzos: float = 9.0

@onready var _healer: Healer = %Healer
@onready var _camara: Camera2D = %Camara
@onready var _unidades: Node2D = %Unidades
@onready var _hud: CanvasLayer = %HUD


func _ready() -> void:
	_healer.limites = Rect2(
		Vector2(40.0, banda_alta),
		Vector2(ancho_campo - 80.0, banda_baja - banda_alta)
	)
	_camara.limit_left = 0
	_camara.limit_right = int(ancho_campo)
	_camara.global_position = Vector2(_healer.global_position.x, altura_camara)

	_hud.seguir(_healer)
	_desplegar_formacion_inicial()

	var reloj := Timer.new()
	reloj.wait_time = intervalo_refuerzos
	reloj.timeout.connect(_enviar_refuerzos)
	add_child(reloj)
	reloj.start()


func _process(_delta: float) -> void:
	# El suavizado lo aplica la propia Camera2D (position_smoothing).
	_camara.global_position = Vector2(_healer.global_position.x, altura_camara)


func _desplegar_formacion_inicial() -> void:
	var centro := ancho_campo * 0.5
	for i in unidades_iniciales:
		_crear_unidad(Unidad.Bando.ALIADO, centro - randf_range(90.0, 260.0))
		_crear_unidad(Unidad.Bando.ENEMIGO, centro + randf_range(90.0, 260.0))


func _enviar_refuerzos() -> void:
	for i in refuerzos_por_tanda:
		_crear_unidad(Unidad.Bando.ALIADO, base_aliada_x + randf_range(20.0, 90.0))
		_crear_unidad(Unidad.Bando.ENEMIGO, base_enemiga_x - randf_range(20.0, 90.0))


func _crear_unidad(bando: Unidad.Bando, x: float) -> void:
	var unidad: Unidad = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando)
	unidad.position = Vector2(x, randf_range(banda_alta + 10.0, banda_baja))
	_unidades.add_child(unidad)
