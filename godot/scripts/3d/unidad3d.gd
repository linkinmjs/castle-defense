class_name Unidad3D
extends CharacterBody3D
## Soldado que combate por su cuenta, version 3D.
##
## Misma logica que la unidad 2D: cambia el mundo (plano XZ) y el dibujo, no
## las reglas. Las barras de vida ya no se pintan aca sino en un overlay, que
## proyecta a pantalla la posicion de cada unidad.

enum Bando { ALIADO, ENEMIGO }
enum Estado { AVANZANDO, COMBATIENDO, MUERTA }

signal murio(unidad: Unidad3D)

const FRAMES_ALIADO := preload("res://assets/sprites/soldier/soldier_frames.tres")
const FRAMES_ENEMIGO := preload("res://assets/sprites/enemy/enemy_frames.tres")

const TINTE_ALIADO := Color(0.62, 0.78, 1.0)
const TINTE_ENEMIGO := Color(1.0, 0.58, 0.52)

## Altura del torso: es donde apunta el mouse y donde salen los efectos.
const ALTURA_TORSO := 1.15

@export var vida_maxima: float = 80.0
@export var dano: float = 12.0
@export var cadencia: float = 1.1
@export var retardo_impacto: float = 0.35
## En metros.
@export var alcance: float = 1.35
@export var velocidad: float = 1.0

@export_group("Sangrado")
@export var probabilidad_sangrado: float = 0.35
@export var duracion_sangrado: float = 8.0
@export var dano_sangrado: float = 3.5

var bando: Bando = Bando.ALIADO
var vida: float
var estado: Estado = Estado.AVANZANDO
var sangrado_restante: float = 0.0

## Las marca el healer segun a quien apunte el mouse; las lee el overlay.
var resaltada: bool = false
var resaltada_alcanzable: bool = true

var bendicion_restante: float = 0.0
var _reduccion_dano: float = 0.0
var _bonus_cadencia: float = 0.0

var _objetivo: Unidad3D = null
var _cooldown: float = 0.0
var _impacto_pendiente: float = -1.0
var _flash: float = 0.0

@onready var _sprite: AnimatedSprite3D = $Sprite
@onready var _colision: CollisionShape3D = $CollisionShape3D


func configurar(nuevo_bando: Bando) -> void:
	bando = nuevo_bando
	vida = vida_maxima

	if bando == Bando.ALIADO:
		add_to_group("aliados")
		collision_layer = 4   # allies
	else:
		add_to_group("enemigos")
		collision_layer = 8   # enemies
	# Se bloquean entre si: de ese amontonamiento sale la linea de frente.
	collision_mask = 12       # allies | enemies


func _ready() -> void:
	# Sin gravedad ni suelo fisico: los soldados se deslizan por el plano.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if vida <= 0.0:
		vida = vida_maxima
	_sprite.sprite_frames = FRAMES_ALIADO if bando == Bando.ALIADO else FRAMES_ENEMIGO
	_sprite.modulate = TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	_sprite.flip_h = bando == Bando.ENEMIGO
	_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTA:
		return

	_actualizar_flash(delta)
	_actualizar_bendicion(delta)
	_actualizar_sangrado(delta)
	if estado == Estado.MUERTA:
		return

	_cooldown -= delta

	if _impacto_pendiente > 0.0:
		_impacto_pendiente -= delta
		if _impacto_pendiente <= 0.0:
			_conectar_golpe()

	if not _objetivo_valido():
		_objetivo = _buscar_objetivo()

	if _objetivo_valido() and global_position.distance_to(_objetivo.global_position) <= alcance:
		estado = Estado.COMBATIENDO
	else:
		estado = Estado.AVANZANDO

	match estado:
		Estado.AVANZANDO:
			_avanzar()
		Estado.COMBATIENDO:
			_combatir()

	move_and_slide()
	global_position.y = 0.0


## Punto al que apunta el jugador y donde se dibuja la barra.
func punto_torso() -> Vector3:
	return global_position + Vector3(0, ALTURA_TORSO, 0)


func _avanzar() -> void:
	var direccion: Vector3
	if _objetivo_valido():
		direccion = (_objetivo.global_position - global_position)
		direccion.y = 0.0
		direccion = direccion.normalized()
	else:
		direccion = Vector3.RIGHT if bando == Bando.ALIADO else Vector3.LEFT

	velocity = direccion * velocidad
	if _sprite.animation != "walk":
		_sprite.play("walk")


func _combatir() -> void:
	velocity = Vector3.ZERO
	if _cooldown <= 0.0 and _impacto_pendiente <= 0.0:
		_cooldown = cadencia * (1.0 - _bonus_cadencia)
		_impacto_pendiente = retardo_impacto
		_sprite.play("attack")
	elif _sprite.animation != "attack" and _impacto_pendiente <= 0.0:
		if _sprite.animation != "idle":
			_sprite.play("idle")


func _conectar_golpe() -> void:
	_impacto_pendiente = -1.0
	if not _objetivo_valido():
		return
	if global_position.distance_to(_objetivo.global_position) > alcance * 1.25:
		return
	_objetivo.recibir_dano(dano)


func recibir_dano(cantidad: float) -> void:
	if estado == Estado.MUERTA:
		return
	_flash = 0.12
	var recibido := cantidad * (1.0 - _reduccion_dano)
	if randf() < probabilidad_sangrado * (1.0 - _reduccion_dano):
		sangrado_restante = duracion_sangrado
	_perder_vida(recibido)


func curar(cantidad: float) -> float:
	if estado == Estado.MUERTA:
		return 0.0
	var antes := vida
	vida = minf(vida + cantidad, vida_maxima)
	return vida - antes


func estabilizar() -> bool:
	if estado == Estado.MUERTA or sangrado_restante <= 0.0:
		return false
	sangrado_restante = 0.0
	return true


func bendecir(duracion: float, reduccion: float, bonus_cadencia: float) -> void:
	if estado == Estado.MUERTA:
		return
	bendicion_restante = duracion
	_reduccion_dano = reduccion
	_bonus_cadencia = bonus_cadencia


func esta_viva() -> bool:
	return estado != Estado.MUERTA


func esta_sangrando() -> bool:
	return sangrado_restante > 0.0


func esta_bendecida() -> bool:
	return bendicion_restante > 0.0


func _perder_vida(cantidad: float) -> void:
	vida = maxf(vida - cantidad, 0.0)
	if vida <= 0.0:
		_morir()


func _actualizar_sangrado(delta: float) -> void:
	if sangrado_restante <= 0.0:
		return
	sangrado_restante -= delta
	_perder_vida(dano_sangrado * delta)


func _actualizar_bendicion(delta: float) -> void:
	if bendicion_restante <= 0.0:
		return
	bendicion_restante -= delta
	if bendicion_restante <= 0.0:
		_reduccion_dano = 0.0
		_bonus_cadencia = 0.0


func _morir() -> void:
	estado = Estado.MUERTA
	velocity = Vector3.ZERO
	sangrado_restante = 0.0
	bendicion_restante = 0.0
	resaltada = false
	_colision.set_deferred("disabled", true)
	_sprite.play("dead")
	murio.emit(self)

	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _objetivo_valido() -> bool:
	return _objetivo != null and is_instance_valid(_objetivo) and _objetivo.esta_viva()


func _buscar_objetivo() -> Unidad3D:
	var grupo := "enemigos" if bando == Bando.ALIADO else "aliados"
	var mejor: Unidad3D = null
	var mejor_distancia := INF
	for candidato: Unidad3D in get_tree().get_nodes_in_group(grupo):
		if not candidato.esta_viva() or candidato.is_queued_for_deletion():
			continue
		var distancia := global_position.distance_squared_to(candidato.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = candidato
	return mejor


func _actualizar_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	var base := TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	_sprite.modulate = Color.WHITE if _flash > 0.0 else base
