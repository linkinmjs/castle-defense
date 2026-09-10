class_name Healer3D
extends CharacterBody3D
## Healer del prototipo 3D.
##
## Mismo comportamiento que la version 2D: el mundo ahora es un plano XZ, donde
## X es el avance del frente y Z la profundidad. Expone la misma API que el
## healer 2D (objetivo_apuntado, en_rango, lanzar_efecto...), asi que los
## recursos de habilidad se reutilizan tal cual.

signal mana_cambio(actual: float, maximo: float)
signal aviso(texto: String)

const FRAMES_FX := preload("res://assets/sprites/fx/fx_frames.tres")
## Radio en pixeles para enganchar una unidad cuando el mouse no cae encima.
const IMAN_MOUSE := 70.0

@export var velocidad_maxima: float = 4.6
@export var aceleracion: float = 34.0
@export var friccion: float = 40.0
## La profundidad se recorre mas lento que el frente, igual que en la version
## 2D: mantiene la sensacion de campo lateral aunque el mundo sea 3D.
@export var factor_profundidad: float = 0.7

@export_group("Curacion")
@export var mana_maximo: float = 100.0
@export var regeneracion_mana: float = 7.0
@export var rango_curacion: float = 3.6

## Zona por la que puede caminar, en metros: x0, z0, ancho, profundidad.
var limites: Rect2 = Rect2(0, 0, 30, 10)
var mana: float

var _camara: Camera3D
var _apuntada: Unidad3D = null
var _impulso_direccion: Vector3 = Vector3.ZERO
var _impulso_fuerza: float = 0.0
var _impulso_restante: float = 0.0
var _casteando: float = 0.0

@onready var _sprite: AnimatedSprite3D = $Sprite
@onready var _habilidades: ComponenteHabilidades = $Habilidades


func _ready() -> void:
	# Sin gravedad ni suelo fisico: se desliza por el plano.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	mana = mana_maximo
	mana_cambio.emit(mana, mana_maximo)


## La batalla le pasa la camara: sin ella no se puede saber a que apunta el
## mouse ni proyectar nada a pantalla.
func usar_camara(camara: Camera3D) -> void:
	_camara = camara


func _physics_process(delta: float) -> void:
	if _impulso_restante > 0.0:
		_impulso_restante -= delta
		velocity = _impulso_direccion * _impulso_fuerza
	else:
		var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var direccion := Vector3(entrada.x, 0.0, entrada.y * factor_profundidad)
		if direccion != Vector3.ZERO:
			velocity = velocity.move_toward(direccion * velocidad_maxima, aceleracion * delta)
		else:
			velocity = velocity.move_toward(Vector3.ZERO, friccion * delta)

	move_and_slide()

	global_position.x = clampf(global_position.x, limites.position.x, limites.end.x)
	global_position.z = clampf(global_position.z, limites.position.y, limites.end.y)
	global_position.y = 0.0

	if mana < mana_maximo:
		mana = minf(mana + regeneracion_mana * delta, mana_maximo)
		mana_cambio.emit(mana, mana_maximo)

	_casteando = maxf(_casteando - delta, 0.0)
	_actualizar_animacion()


func _process(_delta: float) -> void:
	_actualizar_apuntada()


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
	if habilidad.requiere_objetivo() and objetivo_apuntado() == null:
		return
	_habilidades.intentar(habilidad)


# --- API que usan las habilidades -------------------------------------------

func objetivo_apuntado() -> Unidad3D:
	if _apuntada == null or not is_instance_valid(_apuntada) or not _apuntada.esta_viva():
		return null
	return _apuntada


func en_rango(unidad: Node3D) -> bool:
	return global_position.distance_to(unidad.global_position) <= rango_curacion


func gastar_mana(cantidad: float) -> void:
	mana = maxf(mana - cantidad, 0.0)
	mana_cambio.emit(mana, mana_maximo)
	if cantidad > 0.0:
		_casteando = 0.45
		_sprite.play("cast")


func lanzar_efecto(objetivo: Node3D, animacion: String) -> void:
	var efecto := AnimatedSprite3D.new()
	efecto.sprite_frames = FRAMES_FX
	# El sheet de efectos es de 72 px y queremos ~1.6 m de alto.
	efecto.pixel_size = 1.6 / 72.0
	efecto.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	efecto.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	efecto.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	efecto.shaded = false
	efecto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(efecto)
	efecto.global_position = objetivo.global_position + Vector3(0, 1.1, 0)
	efecto.play(animacion)
	efecto.animation_finished.connect(efecto.queue_free)


func impulsar(direccion: Vector3, fuerza: float, duracion: float) -> void:
	_impulso_direccion = direccion
	_impulso_fuerza = fuerza
	_impulso_restante = duracion


## La habilidad no sabe en cuantas dimensiones vive el mundo: le pide al healer
## que se lance hacia donde apunta el jugador y listo.
func impulsar_hacia_mouse(fuerza: float, duracion: float) -> void:
	var direccion := _punto_suelo_bajo_mouse() - global_position
	direccion.y = 0.0
	if direccion.length() < 0.2:
		direccion = Vector3.LEFT if mirando_izquierda() else Vector3.RIGHT
	impulsar(direccion.normalized(), fuerza, duracion)


func mirando_izquierda() -> bool:
	return _sprite.flip_h


# --- Apuntado ----------------------------------------------------------------

func _actualizar_apuntada() -> void:
	if _camara == null:
		return

	var anterior := _apuntada
	_apuntada = buscar_bajo_punto(get_viewport().get_mouse_position())

	if anterior != _apuntada and anterior != null and is_instance_valid(anterior):
		anterior.resaltada = false

	if _apuntada != null:
		_apuntada.resaltada = true
		_apuntada.resaltada_alcanzable = en_rango(_apuntada)


## Igual que en 2D, pero la caja del cuerpo se calcula proyectando la unidad a
## pantalla: asi el area de click acompana el tamano con el que se la ve.
func buscar_bajo_punto(mouse: Vector2) -> Unidad3D:
	var mejor: Unidad3D = null
	var mejor_alcanzable := false
	var mejor_distancia := INF

	for unidad: Unidad3D in get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva() or unidad.is_queued_for_deletion():
			continue
		var caja := _caja_pantalla(unidad)
		if caja.size == Vector2.ZERO or not caja.has_point(mouse):
			continue

		var alcanzable := en_rango(unidad)
		var distancia := _camara.global_position.distance_to(unidad.global_position)
		# Primero los que puedo tocar; entre esos, el mas cercano a la camara,
		# que es el que el jugador ve adelante.
		if mejor == null \
				or (alcanzable and not mejor_alcanzable) \
				or (alcanzable == mejor_alcanzable and distancia < mejor_distancia):
			mejor = unidad
			mejor_alcanzable = alcanzable
			mejor_distancia = distancia

	if mejor != null:
		return mejor
	return _mas_cercano_al_mouse(mouse)


## Caja del cuerpo en coordenadas de pantalla, o una vacia si esta detras.
func _caja_pantalla(unidad: Unidad3D) -> Rect2:
	var pies: Vector3 = unidad.global_position
	var cabeza: Vector3 = pies + Vector3(0, 2.0, 0)
	if _camara.is_position_behind(pies) or _camara.is_position_behind(cabeza):
		return Rect2()

	var p := _camara.unproject_position(pies)
	var c := _camara.unproject_position(cabeza)
	var alto := absf(p.y - c.y)
	var ancho := maxf(alto * 0.55, 12.0)
	return Rect2(Vector2(p.x - ancho * 0.5, c.y), Vector2(ancho, alto))


func _mas_cercano_al_mouse(mouse: Vector2) -> Unidad3D:
	var mejor: Unidad3D = null
	var mejor_distancia := IMAN_MOUSE
	for unidad: Unidad3D in get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva() or unidad.is_queued_for_deletion():
			continue
		var torso: Vector3 = unidad.punto_torso()
		if _camara.is_position_behind(torso):
			continue
		var distancia := _camara.unproject_position(torso).distance_to(mouse)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = unidad
	return mejor


## Cruce del rayo del mouse con el plano del suelo.
func _punto_suelo_bajo_mouse() -> Vector3:
	if _camara == null:
		return global_position
	var mouse := get_viewport().get_mouse_position()
	var origen := _camara.project_ray_origin(mouse)
	var direccion := _camara.project_ray_normal(mouse)
	if absf(direccion.y) < 0.001:
		return global_position
	return origen + direccion * (-origen.y / direccion.y)


func _actualizar_animacion() -> void:
	if velocity.x < -0.05:
		_sprite.flip_h = true
	elif velocity.x > 0.05:
		_sprite.flip_h = false

	if _casteando > 0.0:
		return

	var rapidez := velocity.length()
	var animacion := "idle"
	if rapidez > velocidad_maxima * 0.7:
		animacion = "run"
	elif rapidez > 0.25:
		animacion = "walk"

	if _sprite.animation != animacion:
		_sprite.play(animacion)
