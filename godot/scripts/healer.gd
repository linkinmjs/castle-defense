class_name Healer
extends CharacterBody2D
## Healer controlado por el jugador.
##
## Se mueve libremente por la banda del campo y actua sobre los aliados que
## tenga cerca. Las habilidades viven en ComponenteHabilidades; aca queda el
## movimiento, el mana y a quien se esta apuntando.

signal mana_cambio(actual: float, maximo: float)
## Texto corto para el HUD: que paso con la ultima accion.
signal aviso(texto: String)

const FRAMES_FX := preload("res://assets/sprites/fx/fx_frames.tres")
## Si el mouse no cae sobre ningun cuerpo, se agarra al mas cercano dentro de
## este radio. Sin esta ayuda, apuntar en medio del amontonamiento es un
## ejercicio de punteria y no de decision.
const IMAN_MOUSE := 90.0
## El origen del sprite esta en los pies; el torso queda mas arriba.
const ALTURA_TORSO := Vector2(0, -70)

@export var velocidad_maxima: float = 190.0
@export var aceleracion: float = 1400.0
@export var friccion: float = 1600.0
## Cuanto mas lento se mueve en profundidad respecto al eje horizontal.
@export var factor_profundidad: float = 0.55

@export_group("Curacion")
@export var mana_maximo: float = 100.0
@export var regeneracion_mana: float = 7.0
## Hay que acercarse al frente para curar: no se puede jugar desde atras.
@export var rango_curacion: float = 155.0

## Zona por la que puede caminar. La define la batalla al iniciar.
var limites: Rect2 = Rect2(0, 0, 4000, 200)
var mana: float

var _apuntada: Unidad = null
var _casteando: float = 0.0
var _impulso_direccion: Vector2 = Vector2.ZERO
var _impulso_fuerza: float = 0.0
var _impulso_restante: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _habilidades: ComponenteHabilidades = $Habilidades


func _ready() -> void:
	mana = mana_maximo
	mana_cambio.emit(mana, mana_maximo)


func _physics_process(delta: float) -> void:
	if _impulso_restante > 0.0:
		_impulso_restante -= delta
		velocity = _impulso_direccion * _impulso_fuerza
	else:
		var direccion := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		direccion.y *= factor_profundidad
		if direccion != Vector2.ZERO:
			velocity = velocity.move_toward(direccion * velocidad_maxima, aceleracion * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friccion * delta)

	move_and_slide()

	global_position.x = clampf(global_position.x, limites.position.x, limites.end.x)
	global_position.y = clampf(global_position.y, limites.position.y, limites.end.y)

	if mana < mana_maximo:
		mana = minf(mana + regeneracion_mana * delta, mana_maximo)
		mana_cambio.emit(mana, mana_maximo)

	_casteando = maxf(_casteando - delta, 0.0)
	_actualizar_animacion()


func _process(_delta: float) -> void:
	_actualizar_apuntada()
	queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			_usar(0)
		elif evento.button_index == MOUSE_BUTTON_RIGHT:
			_usar(1)
		return

	if evento.is_action_pressed("habilidad_1"):
		_usar(2)
	elif evento.is_action_pressed("habilidad_2"):
		_usar(3)
	elif evento.is_action_pressed("habilidad_3"):
		_usar(4)


func _usar(indice: int) -> void:
	var habilidad := _habilidades.habilidad_en(indice)
	if habilidad == null:
		return
	# Click al vacio: no vale la pena avisar nada, el jugador ya lo sabe.
	if habilidad.requiere_objetivo() and objetivo_apuntado() == null:
		return
	_habilidades.intentar(habilidad)


# --- API que usan las habilidades -------------------------------------------

func objetivo_apuntado() -> Unidad:
	if _apuntada == null or not is_instance_valid(_apuntada) or not _apuntada.esta_viva():
		return null
	return _apuntada


func en_rango(unidad: Unidad) -> bool:
	return global_position.distance_to(unidad.global_position) <= rango_curacion


func gastar_mana(cantidad: float) -> void:
	mana = maxf(mana - cantidad, 0.0)
	mana_cambio.emit(mana, mana_maximo)
	if cantidad > 0.0:
		_casteando = 0.45
		_sprite.play("cast")


func lanzar_efecto(objetivo: Node2D, animacion: String) -> void:
	var efecto := AnimatedSprite2D.new()
	efecto.sprite_frames = FRAMES_FX
	# Chico a proposito: a mayor escala el efecto tapa a los soldados y no se
	# ve el estado de la linea, que es lo que hay que poder leer.
	efecto.scale = Vector2(1.05, 1.05)
	efecto.z_index = 5
	get_parent().add_child(efecto)
	efecto.global_position = objetivo.global_position + ALTURA_TORSO
	efecto.play(animacion)
	efecto.animation_finished.connect(efecto.queue_free)


func impulsar(direccion: Vector2, fuerza: float, duracion: float) -> void:
	_impulso_direccion = direccion
	_impulso_fuerza = fuerza
	_impulso_restante = duracion


func mirando_izquierda() -> bool:
	return _sprite.flip_h


# --- Apuntado ----------------------------------------------------------------

func _actualizar_apuntada() -> void:
	var anterior := _apuntada
	_apuntada = buscar_bajo_punto(get_global_mouse_position())

	if anterior != _apuntada and anterior != null and is_instance_valid(anterior):
		anterior.resaltada = false
		anterior.queue_redraw()

	if _apuntada != null:
		var alcanzable := en_rango(_apuntada)
		if not _apuntada.resaltada or _apuntada.resaltada_alcanzable != alcanzable:
			_apuntada.resaltada = true
			_apuntada.resaltada_alcanzable = alcanzable
			_apuntada.queue_redraw()


## Elige a quien apunta el jugador. Con la linea amontonada suele haber varios
## cuerpos superpuestos, asi que el orden importa: primero los que el healer
## puede tocar, y entre esos el que esta mas adelante, que es justamente el
## que el jugador ve arriba de todo (el y-sort dibuja por Y creciente).
## Recibe el punto en vez de leer el mouse para poder probarlo sin ventana.
func buscar_bajo_punto(mouse: Vector2) -> Unidad:
	var mejor: Unidad = null
	var mejor_alcanzable := false
	var mejor_y := -INF

	for unidad: Unidad in get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva() or unidad.is_queued_for_deletion():
			continue
		if not unidad.caja_global().has_point(mouse):
			continue

		var alcanzable := en_rango(unidad)
		if mejor == null \
				or (alcanzable and not mejor_alcanzable) \
				or (alcanzable == mejor_alcanzable and unidad.global_position.y > mejor_y):
			mejor = unidad
			mejor_alcanzable = alcanzable
			mejor_y = unidad.global_position.y

	if mejor != null:
		return mejor
	return _mas_cercano_al_mouse(mouse)


## Sin nadie bajo el cursor, engancha al mas cercano dentro del radio del iman.
func _mas_cercano_al_mouse(mouse: Vector2) -> Unidad:
	var mejor: Unidad = null
	var mejor_distancia := IMAN_MOUSE
	for unidad: Unidad in get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva() or unidad.is_queued_for_deletion():
			continue
		var distancia := (unidad.global_position + ALTURA_TORSO).distance_to(mouse)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = unidad
	return mejor


func _actualizar_animacion() -> void:
	if velocity.x < -1.0:
		_sprite.flip_h = true
	elif velocity.x > 1.0:
		_sprite.flip_h = false

	if _casteando > 0.0:
		return  # la animacion de cast no se interrumpe por caminar

	var rapidez := velocity.length()
	var animacion := "idle"
	if rapidez > velocidad_maxima * 0.7:
		animacion = "run"
	elif rapidez > 10.0:
		animacion = "walk"

	if _sprite.animation != animacion:
		_sprite.play(animacion)


func _draw() -> void:
	# El alcance dibujado como elipse: en un campo con perspectiva lateral un
	# circulo perfecto enganaria sobre hasta donde llega en profundidad.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	var color := Color(1.0, 0.9, 0.55, 0.30)
	if _apuntada != null and is_instance_valid(_apuntada) and not en_rango(_apuntada):
		color = Color(1.0, 0.45, 0.35, 0.35)  # apuntando algo que no llego a tocar
	draw_arc(Vector2.ZERO, rango_curacion, 0.0, TAU, 48, color, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
