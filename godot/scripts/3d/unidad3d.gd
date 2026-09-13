class_name Unidad3D
extends CharacterBody3D
## Soldado que combate por su cuenta, version 3D.
##
## Misma logica que la unidad 2D: cambia el mundo (plano XZ) y el dibujo, no
## las reglas. Las barras de vida ya no se pintan aca sino en un overlay, que
## proyecta a pantalla la posicion de cada unidad.

enum Bando { ALIADO, ENEMIGO }
enum Estado { AVANZANDO, COMBATIENDO, RETIRANDOSE, DERRIBADA, MUERTA }

signal murio(unidad: Unidad3D)
signal derribada(unidad: Unidad3D)

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
## Vida por segundo mientras esta retirado. Sin esto, el que se retira no
## vuelve nunca salvo que el healer lo cure; con esto vuelve solo, despacio,
## y el healer lo acelera.
@export var regeneracion_retirada: float = 3.0

@export_group("Derribo")
## Segundos que aguanta en el suelo antes de morir de verdad. Es el reloj
## de la emergencia: lo que tiene el healer para llegar.
@export var tiempo_derribada: float = 8.0
## Fraccion de la vida maxima con la que vuelve al reanimarla.
@export var vida_al_reanimar: float = 0.35

@export_group("Sangrado")
@export var probabilidad_sangrado: float = 0.35
@export var duracion_sangrado: float = 8.0
@export var dano_sangrado: float = 3.5

var bando: Bando = Bando.ALIADO
## Tipo de soldado; si es null, la unidad usa sus valores exportados.
var tipo: TipoSoldado
## X de la base propia: hacia donde se retira. Lo asigna la batalla.
var base_x: float = NAN
## Estilo de combate, copiado del tipo (ver TipoSoldado).
var reduccion_base: float = 0.0
var retirada_bajo: float = 0.0
var oportunista: bool = false
var vida: float
var estado: Estado = Estado.AVANZANDO
var sangrado_restante: float = 0.0
var derribada_restante: float = 0.0

## Las marca el healer segun a quien apunte el mouse; las lee el overlay.
var resaltada: bool = false
var resaltada_alcanzable: bool = true

var bendicion_restante: float = 0.0
var _reduccion_dano: float = 0.0
var _bonus_cadencia: float = 0.0

## Node3D y no Unidad3D: para un enemigo, el healer tambien es un objetivo.
var _objetivo: Node3D = null
## Azar propio y no el global: asi el sangrado de esta unidad depende de su
## semilla y no del orden en que le tocaron golpes a las demas.
var _azar := RandomNumberGenerator.new()
var _sembrada: bool = false
var _cooldown: float = 0.0
var _impacto_pendiente: float = -1.0
var _flash: float = 0.0

@onready var _sprite: AnimatedSprite3D = $Sprite
@onready var _colision: CollisionShape3D = $CollisionShape3D


func configurar(nuevo_bando: Bando, nuevo_tipo: TipoSoldado = null) -> void:
	bando = nuevo_bando
	tipo = nuevo_tipo
	if tipo != null:
		vida_maxima = tipo.vida_maxima
		dano = tipo.dano
		cadencia = tipo.cadencia
		alcance = tipo.alcance
		velocidad = tipo.velocidad
		reduccion_base = tipo.reduccion_dano
		retirada_bajo = tipo.retirada_bajo
		oportunista = tipo.oportunista
	vida = vida_maxima

	if bando == Bando.ALIADO:
		add_to_group("aliados")
		collision_layer = 4   # allies
	else:
		add_to_group("enemigos")
		collision_layer = 8   # enemies
	# Se bloquean entre si: de ese amontonamiento sale la linea de frente.
	collision_mask = 12       # allies | enemies


## La batalla la siembra al crearla, para que un encuentro con la misma semilla
## produzca los mismos sangrados. Sin sembrar, el azar es distinto cada vez.
func sembrar(semilla: int) -> void:
	_azar.seed = semilla
	_sembrada = true


func _ready() -> void:
	# Sin gravedad ni suelo fisico: los soldados se deslizan por el plano.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if not _sembrada:
		_azar.randomize()
	if vida <= 0.0:
		vida = vida_maxima
	if tipo != null and tipo.frames != null:
		_sprite.sprite_frames = tipo.frames
	else:
		_sprite.sprite_frames = FRAMES_ALIADO if bando == Bando.ALIADO else FRAMES_ENEMIGO
	_sprite.modulate = TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	_sprite.flip_h = bando == Bando.ENEMIGO
	_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTA:
		return

	_actualizar_flash(delta)
	if estado == Estado.DERRIBADA:
		# En el suelo solo corre el reloj. Si nadie llega, muere de verdad.
		derribada_restante -= delta
		if derribada_restante <= 0.0:
			_morir()
		return

	_actualizar_bendicion(delta)
	_actualizar_sangrado(delta)
	if estado == Estado.MUERTA:
		return

	_cooldown -= delta

	if _impacto_pendiente > 0.0:
		_impacto_pendiente -= delta
		if _impacto_pendiente <= 0.0:
			_conectar_golpe()

	if _quiere_retirarse():
		estado = Estado.RETIRANDOSE
		vida = minf(vida + regeneracion_retirada * delta, vida_maxima)
		_retirarse()
		move_and_slide()
		global_position.y = 0.0
		return

	if not _objetivo_valido():
		_objetivo = _buscar_objetivo()

	if _objetivo_valido():
		var distancia := global_position.distance_to(_objetivo.global_position)
		# Con histeresis: entra al alcance justo y sale recien un poco mas
		# lejos. Sin ella, en el borde alterna parar y avanzar cada frame.
		var limite := alcance * 1.15 if estado == Estado.COMBATIENDO else alcance
		estado = Estado.COMBATIENDO if distancia <= limite else Estado.AVANZANDO
	else:
		estado = Estado.AVANZANDO

	match estado:
		Estado.AVANZANDO:
			_avanzar(delta)
		Estado.COMBATIENDO:
			_combatir()

	move_and_slide()
	global_position.y = 0.0


## Punto al que apunta el jugador y donde se dibuja la barra.
func punto_torso() -> Vector3:
	return global_position + Vector3(0, ALTURA_TORSO, 0)


func _avanzar(delta: float) -> void:
	var direccion: Vector3
	if _objetivo_valido():
		direccion = _objetivo.global_position - global_position
		direccion.y = 0.0
		# Banda muerta en profundidad: en la linea amontonada, corregir la Z
		# cada frame hace que el soldado se deslice de un lado al otro.
		if absf(direccion.z) < 0.35:
			direccion.z = 0.0
		direccion = direccion.normalized()
	else:
		direccion = Vector3.RIGHT if bando == Bando.ALIADO else Vector3.LEFT

	# Acelera en vez de saltar a la velocidad: amortigua los cambios de rumbo.
	velocity = velocity.move_toward(direccion * velocidad, 6.0 * delta)
	_encarar(direccion.x)
	if _sprite.animation != "walk":
		_sprite.play("walk")


## Solo gira si el otro esta claramente a un lado. Con el objetivo justo
## adelante o atras en profundidad, girar cada frame se ve como un temblor.
func _encarar(dx: float) -> void:
	if absf(dx) < 0.3:
		return
	_sprite.flip_h = dx < 0.0


func _combatir() -> void:
	velocity = Vector3.ZERO
	if _objetivo_valido():
		_encarar(_objetivo.global_position.x - global_position.x)
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
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return
	_flash = 0.12
	var recibido := cantidad * (1.0 - _reduccion_dano) * (1.0 - reduccion_base)
	if _azar.randf() < probabilidad_sangrado * (1.0 - _reduccion_dano):
		sangrado_restante = duracion_sangrado
	_perder_vida(recibido)


## Sobre una derribada no hace nada: a esa hay que reanimarla.
func curar(cantidad: float) -> float:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return 0.0
	var antes := vida
	vida = minf(vida + cantidad, vida_maxima)
	return vida - antes


func estabilizar() -> bool:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA or sangrado_restante <= 0.0:
		return false
	sangrado_restante = 0.0
	return true


func bendecir(duracion: float, reduccion: float, bonus_cadencia: float) -> void:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
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
		_caer()


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


## A cero no muere: queda en el suelo con un reloj. Es la emergencia del
## documento (4.4): alguien tirado que todavia se puede salvar.
func _caer() -> void:
	estado = Estado.DERRIBADA
	derribada_restante = tiempo_derribada
	velocity = Vector3.ZERO
	sangrado_restante = 0.0
	bendicion_restante = 0.0
	_reduccion_dano = 0.0
	_bonus_cadencia = 0.0
	_impacto_pendiente = -1.0
	# Sin colision: la linea puede pasarle por encima y el healer llegar.
	_colision.set_deferred("disabled", true)
	_sprite.play("dead")  # no vuelve sola: queda en el ultimo frame, tirada
	derribada.emit(self)


func _morir() -> void:
	estado = Estado.MUERTA
	velocity = Vector3.ZERO
	resaltada = false
	_colision.set_deferred("disabled", true)
	murio.emit(self)

	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


## Levanta a una derribada. Devuelve false si no habia a quien levantar.
func reanimar() -> bool:
	if estado != Estado.DERRIBADA:
		return false
	estado = Estado.AVANZANDO
	derribada_restante = 0.0
	vida = vida_maxima * vida_al_reanimar
	_colision.set_deferred("disabled", false)
	_sprite.play("idle")
	return true


func esta_derribada() -> bool:
	return estado == Estado.DERRIBADA


## 1.0 recien caida, 0.0 a punto de morir. Para la barra del overlay.
func fraccion_derribada() -> float:
	if tiempo_derribada <= 0.0:
		return 0.0
	return clampf(derribada_restante / tiempo_derribada, 0.0, 1.0)


func _objetivo_valido() -> bool:
	return _objetivo != null and is_instance_valid(_objetivo) \
		and _objetivo.esta_viva() and not _objetivo.esta_derribada()


## El mas cercano de los grupos rivales. Para un enemigo, el healer entra en
## la lista: de ahi sale la cobertura sin programarla aparte. Rodeado de
## soldados, siempre hay alguien mas cerca que el.
func _buscar_objetivo() -> Node3D:
	var grupos: Array[String] = ["enemigos"]
	if bando == Bando.ENEMIGO:
		grupos = ["aliados", "healer"]

	# El oportunista prefiere al mas herido que tenga cerca. Si no hay nadie
	# a mano, elige al mas cercano como todos.
	if oportunista:
		var herido := _mas_herido_cerca(grupos, 6.0)
		if herido != null:
			return herido

	var mejor: Node3D = null
	var mejor_distancia := INF
	for grupo in grupos:
		for candidato in get_tree().get_nodes_in_group(grupo):
			var nodo := candidato as Node3D
			# Una derribada no es objetivo: ya esta fuera de combate.
			if nodo == null or not nodo.esta_viva() or nodo.esta_derribada() \
					or nodo.is_queued_for_deletion():
				continue
			var distancia := global_position.distance_squared_to(nodo.global_position)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = nodo
	return mejor


func _mas_herido_cerca(grupos: Array[String], radio: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_fraccion := INF
	for grupo in grupos:
		for candidato in get_tree().get_nodes_in_group(grupo):
			var nodo := candidato as Node3D
			if nodo == null or not nodo.esta_viva() or nodo.esta_derribada() \
					or nodo.is_queued_for_deletion():
				continue
			if global_position.distance_to(nodo.global_position) > radio:
				continue
			var fraccion: float = nodo.vida / nodo.vida_maxima
			if fraccion < mejor_fraccion:
				mejor_fraccion = fraccion
				mejor = nodo
	return mejor


## Con histeresis: se retira por debajo del umbral y vuelve recien cuando lo
## curaron bastante, para no oscilar justo en el borde.
func _quiere_retirarse() -> bool:
	if retirada_bajo <= 0.0:
		return false
	var fraccion := vida / vida_maxima
	if estado == Estado.RETIRANDOSE:
		return fraccion < retirada_bajo + 0.25
	return fraccion < retirada_bajo


## Corre hacia su base y se queda ahi hasta que lo curen. Es el soldado que
## viene solo hacia el healer.
func _retirarse() -> void:
	var destino_x := base_x
	if is_nan(destino_x):
		destino_x = 1.5 if bando == Bando.ALIADO else 28.5
	var dx := destino_x - global_position.x
	if absf(dx) < 1.0:
		velocity = Vector3.ZERO
		if _sprite.animation != "idle":
			_sprite.play("idle")
		return
	velocity = Vector3(signf(dx), 0.0, 0.0) * velocidad * 1.2
	_encarar(dx)
	if _sprite.animation != "run":
		_sprite.play("run")


## Sale del suelo: sin fisica ni colision hasta que termina de asomar, asi no
## empuja a nadie desde abajo ni recibe golpes antes de existir del todo.
func emerger(duracion: float) -> void:
	set_physics_process(false)
	_colision.disabled = true
	global_position.y = -2.1
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", 0.0, duracion).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_colision.disabled = false
		set_physics_process(true))


func _actualizar_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	var base := TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	_sprite.modulate = Color.WHITE if _flash > 0.0 else base
