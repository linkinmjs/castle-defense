class_name Unidad
extends CharacterBody2D
## Soldado que combate por su cuenta.
##
## La misma escena sirve para los dos bandos: el bando define a quien busca,
## hacia donde avanza y con que sprites se dibuja. El jugador no la controla,
## solo puede intervenir sobre ella con las habilidades del healer.

enum Bando { ALIADO, ENEMIGO }
enum Estado { AVANZANDO, COMBATIENDO, MUERTA }

signal murio(unidad: Unidad)

const FRAMES_ALIADO := preload("res://assets/sprites/soldier/soldier_frames.tres")
const FRAMES_ENEMIGO := preload("res://assets/sprites/enemy/enemy_frames.tres")

const TINTE_ALIADO := Color(0.62, 0.78, 1.0)
const TINTE_ENEMIGO := Color(1.0, 0.58, 0.52)
const COLOR_SANGRADO := Color("c0392b")
const COLOR_BENDICION := Color("6fd3c7")

## Caja para agarrar la unidad con el mouse, relativa al origen (los pies).
const CAJA_CUERPO := Rect2(-30, -142, 60, 150)

@export var vida_maxima: float = 80.0
@export var dano: float = 12.0
## Segundos entre ataque y ataque.
@export var cadencia: float = 1.1
## Cuanto tarda el golpe en conectar desde que arranca la animacion.
@export var retardo_impacto: float = 0.35
@export var alcance: float = 78.0
@export var velocidad: float = 44.0

@export_group("Sangrado")
## Probabilidad de que un golpe abra una herida sangrante.
@export var probabilidad_sangrado: float = 0.35
@export var duracion_sangrado: float = 8.0
@export var dano_sangrado: float = 3.5

var bando: Bando = Bando.ALIADO
var vida: float
var estado: Estado = Estado.AVANZANDO
var sangrado_restante: float = 0.0

## Las marca el healer segun a quien apunte el mouse; solo afectan el dibujo.
var resaltada: bool = false
var resaltada_alcanzable: bool = true

## Bendicion activa (la aplica una habilidad del healer).
var bendicion_restante: float = 0.0
var _reduccion_dano: float = 0.0
var _bonus_cadencia: float = 0.0

var _objetivo: Unidad = null
var _cooldown: float = 0.0
var _impacto_pendiente: float = -1.0
var _flash: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _colision: CollisionShape2D = $CollisionShape2D


func configurar(nuevo_bando: Bando) -> void:
	bando = nuevo_bando
	vida = vida_maxima

	if bando == Bando.ALIADO:
		add_to_group("aliados")
		collision_layer = 4   # allies
	else:
		add_to_group("enemigos")
		collision_layer = 8   # enemies
	# Los soldados se bloquean entre si: de ese amontonamiento sale la
	# linea de frente, sin tener que calcularla a mano.
	collision_mask = 12       # allies | enemies


func _ready() -> void:
	if vida <= 0.0:
		vida = vida_maxima
	_sprite.sprite_frames = FRAMES_ALIADO if bando == Bando.ALIADO else FRAMES_ENEMIGO
	_sprite.modulate = TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	# Los sprites miran a la derecha: el enemigo avanza al oeste, se voltea.
	_sprite.flip_h = bando == Bando.ENEMIGO
	_sprite.play("idle")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTA:
		return

	_actualizar_flash(delta)
	_actualizar_bendicion(delta)
	_actualizar_sangrado(delta)
	if estado == Estado.MUERTA:
		return  # se desangro en este mismo frame

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


## Caja del cuerpo en coordenadas de mundo: con esto el healer sabe si el
## mouse esta encima, sin depender de la distancia a un punto.
func caja_global() -> Rect2:
	return Rect2(global_position + CAJA_CUERPO.position, CAJA_CUERPO.size)


func _avanzar() -> void:
	var direccion: Vector2
	if _objetivo_valido():
		direccion = (_objetivo.global_position - global_position).normalized()
	else:
		# Sin nadie a quien enfrentar, empuja hacia la base contraria.
		direccion = Vector2.RIGHT if bando == Bando.ALIADO else Vector2.LEFT

	velocity = direccion * velocidad
	if _sprite.animation != "walk":
		_sprite.play("walk")


func _combatir() -> void:
	velocity = Vector2.ZERO
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
		return  # se alejo mientras el golpe estaba en el aire
	_objetivo.recibir_dano(dano)


func recibir_dano(cantidad: float) -> void:
	if estado == Estado.MUERTA:
		return
	_flash = 0.12
	var recibido := cantidad * (1.0 - _reduccion_dano)
	# Una herida abierta no se cierra curando vida: hay que estabilizarla.
	# La bendicion tambien protege de que se abra.
	if randf() < probabilidad_sangrado * (1.0 - _reduccion_dano):
		sangrado_restante = duracion_sangrado
	_perder_vida(recibido)


## Devuelve cuanta vida se recupero realmente. Lo que sobra se desperdicia:
## curar a alguien casi entero es tirar mana (overhealing, seccion 4.8).
func curar(cantidad: float) -> float:
	if estado == Estado.MUERTA:
		return 0.0
	var antes := vida
	vida = minf(vida + cantidad, vida_maxima)
	queue_redraw()
	return vida - antes


## Corta el sangrado. Devuelve false si no habia nada que cortar, para que el
## healer no gaste mana al pedo.
func estabilizar() -> bool:
	if estado == Estado.MUERTA or sangrado_restante <= 0.0:
		return false
	sangrado_restante = 0.0
	queue_redraw()
	return true


## Protege y acelera a la unidad por un rato.
func bendecir(duracion: float, reduccion: float, bonus_cadencia: float) -> void:
	if estado == Estado.MUERTA:
		return
	bendicion_restante = duracion
	_reduccion_dano = reduccion
	_bonus_cadencia = bonus_cadencia
	queue_redraw()


func esta_viva() -> bool:
	return estado != Estado.MUERTA


func esta_sangrando() -> bool:
	return sangrado_restante > 0.0


func esta_bendecida() -> bool:
	return bendicion_restante > 0.0


func _perder_vida(cantidad: float) -> void:
	vida = maxf(vida - cantidad, 0.0)
	queue_redraw()
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
		queue_redraw()


func _morir() -> void:
	estado = Estado.MUERTA
	velocity = Vector2.ZERO
	sangrado_restante = 0.0
	bendicion_restante = 0.0
	resaltada = false
	_colision.set_deferred("disabled", true)
	_sprite.play("dead")
	queue_redraw()
	murio.emit(self)

	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _objetivo_valido() -> bool:
	return _objetivo != null and is_instance_valid(_objetivo) and _objetivo.esta_viva()


func _buscar_objetivo() -> Unidad:
	var grupo := "enemigos" if bando == Bando.ALIADO else "aliados"
	var mejor: Unidad = null
	var mejor_distancia := INF
	for candidato: Unidad in get_tree().get_nodes_in_group(grupo):
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


func _draw() -> void:
	if estado == Estado.MUERTA:
		return

	if resaltada:
		# Elipse a los pies: marca a quien apunta el mouse sin taparle la barra.
		# El color dice si el healer llega o no, para no gastar el click.
		var color := Color(1, 1, 1, 0.75) if resaltada_alcanzable else Color(1.0, 0.45, 0.35, 0.65)
		var relleno := Color(1, 1, 1, 0.18) if resaltada_alcanzable else Color(1.0, 0.4, 0.3, 0.12)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2(0, -24), 30.0, relleno)
		draw_arc(Vector2(0, -24), 30.0, 0.0, TAU, 24, color, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var ancho := 46.0
	var alto := 7.0
	var arriba := -150.0
	var marco := Rect2(-ancho * 0.5, arriba, ancho, alto)

	draw_rect(marco, Color(0, 0, 0, 0.55))
	var proporcion := clampf(vida / vida_maxima, 0.0, 1.0)
	draw_rect(Rect2(-ancho * 0.5, arriba, ancho * proporcion, alto), _color_vida(proporcion))
	draw_rect(marco, Color(0, 0, 0, 0.7), false, 1.0)

	if esta_sangrando():
		# Rombo rojo pegado a la barra: el aviso de que hay que estabilizar.
		var centro := Vector2(ancho * 0.5 + 7.0, arriba + alto * 0.5)
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(0, -5), centro + Vector2(4, 0),
			centro + Vector2(0, 5), centro + Vector2(-4, 0),
		]), COLOR_SANGRADO)

	if esta_bendecida():
		draw_arc(Vector2(-ancho * 0.5 - 8.0, arriba + alto * 0.5), 4.0, 0.0, TAU, 12,
			COLOR_BENDICION, 2.0)


## El color es la lectura rapida del triaje: de un vistazo se ve quien esta
## por caer sin tener que comparar largos de barra.
func _color_vida(proporcion: float) -> Color:
	if proporcion > 0.5:
		return Color("5fbf5f")
	if proporcion > 0.25:
		return Color("d9c04a")
	return Color("d2503c")
