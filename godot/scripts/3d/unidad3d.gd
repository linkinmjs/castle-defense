class_name Unidad3D
extends CharacterBody3D
## Soldado que combate por su cuenta, version 3D.
##
## Misma logica que la unidad 2D: cambia el mundo (plano XZ) y el dibujo, no
## las reglas. Las barras de vida ya no se pintan aca sino en un overlay, que
## proyecta a pantalla la posicion de cada unidad.

enum Bando { ALIADO, ENEMIGO }
enum Estado { AVANZANDO, COMBATIENDO, RETIRANDOSE, DERRIBADA, MUERTA }
## Cuanto apura atender a esta unidad. Compartida por todos los estados, para
## que la lectura del campo no dependa de aprenderse un icono por problema.
enum Urgencia { ESTABLE, EN_RIESGO, CRITICO }

signal murio(unidad: Unidad3D)
signal derribada(unidad: Unidad3D)
## Cuanto se pidio y cuanto entro de verdad. La diferencia es el desperdicio,
## que es justo lo que el encuentro 2 quiere que el jugador aprenda a ver.
signal curada(solicitada: float, efectiva: float)
signal sangrado_iniciado()
## Cuantos segundos estuvo sangrando antes de que lo cortaran.
signal sangrado_cortado(segundos: float)
## Nadie lo corto: el sangrado se agoto solo.
signal sangrado_expiro(segundos: float)
signal reanimada()

const FRAMES_ALIADO := preload("res://assets/sprites/soldier/soldier_frames.tres")
const FRAMES_ENEMIGO := preload("res://assets/sprites/enemy/enemy_frames.tres")

const TINTE_ALIADO := Color(0.62, 0.78, 1.0)
const TINTE_ENEMIGO := Color(1.0, 0.58, 0.52)

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
## Nombre propio, si el encuentro reparte. Un soldado con nombre pesa distinto
## que uno sin nombre a la hora de elegir a quien salvar.
var nombre_unidad: String = ""
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
## Por que se cayo y por que murio. Sin esto el resumen puede decir cuantos se
## perdieron pero no si habia algo que hacer al respecto.
var causa_caida: StringName = &""
var causa_muerte: StringName = &""
## Que tipo de unidad le pego por ultima vez.
var fuente_ultimo_dano: String = ""
## Segundos acumulados sangrando en el episodio actual.
var segundos_sangrando: float = 0.0
## Ultima causa de perdida de vida, para saber de que se cayo.
var _ultima_causa: StringName = &"golpe"

## Las marca el healer en quien recibiria su ligera; las lee el overlay.
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
## Lo que falta de la animacion de golpe. Avanzar y combatir siguen decidiendo
## el movimiento pero no la pisan: al tick siguiente ya no se veia.
var _hurt_restante: float = 0.0

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
			# Distinto de morir de un golpe: aca hubo una ventana y se agoto.
			_morir(&"sin_atencion")
		return

	_actualizar_bendicion(delta)
	_actualizar_sangrado(delta)
	# El sangrado pudo tirarla o matarla en este mismo tick: si siguiera, avanzar
	# o combatir le pisarian el derribo y caminaria con 0 de vida sin poder ser
	# reanimada.
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return

	_cooldown -= delta
	_hurt_restante -= delta

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
	_animar(&"walk")


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
		# El golpe sale igual; lo que se posterga es solo el dibujo.
		if _hurt_restante <= 0.0:
			_sprite.play("attack")
	elif _sprite.animation != "attack" and _impacto_pendiente <= 0.0:
		_animar(&"idle")


## Cambia la animacion de movimiento o de combate, salvo mientras se ve el
## golpe recibido.
func _animar(animacion: StringName) -> void:
	if _hurt_restante > 0.0 or _sprite.animation == animacion:
		return
	_sprite.play(animacion)


func _conectar_golpe() -> void:
	_impacto_pendiente = -1.0
	if not _objetivo_valido():
		return
	if global_position.distance_to(_objetivo.global_position) > alcance * 1.25:
		return
	_objetivo.recibir_dano(dano, self)


## La fuente y la causa llegan con valor por defecto para que quien solo quiera
## restar vida no tenga que saber de esto.
func recibir_dano(cantidad: float, fuente: Node = null, causa: StringName = &"golpe") -> void:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return
	_flash = 0.12
	if fuente != null:
		fuente_ultimo_dano = _nombrar(fuente)
	var recibido := cantidad * (1.0 - _reduccion_dano) * (1.0 - reduccion_base)
	if _azar.randf() < probabilidad_sangrado * (1.0 - _reduccion_dano):
		aplicar_sangrado(duracion_sangrado)
	_perder_vida(recibido, causa)
	# Si el golpe lo tiro, manda la animacion de caida. Sin _ready todavia no
	# hay sprite: test_determinismo golpea unidades que no entraron al arbol.
	if esta_viva() and not esta_derribada() and is_node_ready():
		_hurt_restante = 0.25
		_sprite.play("hurt")


## Un solo lugar donde empieza un sangrado, para que el aviso salga siempre.
func aplicar_sangrado(segundos: float) -> void:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return
	var ya_sangraba := sangrado_restante > 0.0
	sangrado_restante = segundos
	if not ya_sangraba:
		segundos_sangrando = 0.0
		sangrado_iniciado.emit()


func _nombrar(nodo: Node) -> String:
	if nodo is Unidad3D and nodo.tipo != null:
		return nodo.tipo.nombre
	if nodo.is_in_group("healer"):
		return "Healer"
	return nodo.name


## Sobre una derribada no hace nada: a esa hay que reanimarla.
func curar(cantidad: float) -> float:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		curada.emit(cantidad, 0.0)
		return 0.0
	var antes := vida
	vida = minf(vida + cantidad, vida_maxima)
	var efectiva := vida - antes
	curada.emit(cantidad, efectiva)
	return efectiva


func estabilizar() -> bool:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA or sangrado_restante <= 0.0:
		return false
	sangrado_restante = 0.0
	sangrado_cortado.emit(segundos_sangrando)
	segundos_sangrando = 0.0
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


## Un solo problema por unidad, el mas grave. Con quince soldados amontonados no
## hay lugar en pantalla para varios iconos por cabeza, y el detalle completo
## va en la tarjeta al apuntar.
func estado_dominante() -> StringName:
	if estado == Estado.MUERTA:
		return &"muerta"
	if estado == Estado.DERRIBADA:
		return &"derribada"
	if esta_sangrando():
		return &"sangrado"
	if vida < vida_maxima * 0.35:
		return &"vida_baja"
	if estado == Estado.RETIRANDOSE:
		return &"retirada"
	if esta_bendecida():
		return &"bendicion"
	return &"estable"


func urgencia() -> Urgencia:
	match estado_dominante():
		&"derribada":
			return Urgencia.CRITICO
		&"sangrado":
			# Sangrando y con poca vida ya no hay tiempo de curar y despues ver.
			return Urgencia.CRITICO if vida < vida_maxima * 0.4 else Urgencia.EN_RIESGO
		&"vida_baja":
			return Urgencia.CRITICO if vida < vida_maxima * 0.2 else Urgencia.EN_RIESGO
		&"retirada":
			return Urgencia.EN_RIESGO
	return Urgencia.ESTABLE


## Segundos que quedan del estado dominante, o 0 si no corre ningun reloj. Un
## derribado con tres segundos se lee muy distinto que una fraccion abstracta.
func segundos_estado() -> float:
	match estado_dominante():
		&"derribada":
			return maxf(derribada_restante, 0.0)
		&"sangrado":
			return maxf(sangrado_restante, 0.0)
	return 0.0


func _perder_vida(cantidad: float, causa: StringName = &"golpe") -> void:
	_ultima_causa = causa
	vida = maxf(vida - cantidad, 0.0)
	if vida <= 0.0:
		_caer()


func _actualizar_sangrado(delta: float) -> void:
	if sangrado_restante <= 0.0:
		return
	segundos_sangrando += delta
	sangrado_restante -= delta
	_perder_vida(dano_sangrado * delta, &"sangrado")
	# Se agoto sin que nadie lo cortara: es una crisis que quedo sin atender,
	# aunque el soldado haya sobrevivido.
	if sangrado_restante <= 0.0 and estado != Estado.DERRIBADA:
		sangrado_expiro.emit(segundos_sangrando)
		segundos_sangrando = 0.0


func _actualizar_bendicion(delta: float) -> void:
	if bendicion_restante <= 0.0:
		return
	bendicion_restante -= delta
	if bendicion_restante <= 0.0:
		_reduccion_dano = 0.0
		_bonus_cadencia = 0.0


## La tira al suelo sin pasar por el daño. La usa el encuentro que quiere
## plantear un derribado desde el primer segundo.
func derribar() -> void:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA:
		return
	vida = 0.0
	_caer()


## A cero no muere: queda en el suelo con un reloj. Es la emergencia del
## documento (4.4): alguien tirado que todavia se puede salvar.
func _caer() -> void:
	estado = Estado.DERRIBADA
	causa_caida = _ultima_causa
	derribada_restante = tiempo_derribada
	velocity = Vector3.ZERO
	# Si cayo sangrando, el sangrado quedo sin tratar aunque no se haya agotado
	# solo: nadie llego a cortarlo.
	if sangrado_restante > 0.0:
		sangrado_expiro.emit(segundos_sangrando)
	sangrado_restante = 0.0
	segundos_sangrando = 0.0
	bendicion_restante = 0.0
	_reduccion_dano = 0.0
	_bonus_cadencia = 0.0
	_impacto_pendiente = -1.0
	_hurt_restante = 0.0
	# Sin colision: la linea puede pasarle por encima y el healer llegar.
	_colision.set_deferred("disabled", true)
	_sprite.play("dead")  # no vuelve sola: queda en el ultimo frame, tirada
	derribada.emit(self)


func _morir(causa: StringName = &"") -> void:
	estado = Estado.MUERTA
	causa_muerte = causa if causa != &"" else causa_caida
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
	causa_caida = &""
	vida = vida_maxima * vida_al_reanimar
	_colision.set_deferred("disabled", false)
	_sprite.play("idle")
	reanimada.emit()
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
		_animar(&"idle")
		return
	velocity = Vector3(signf(dx), 0.0, 0.0) * velocidad * 1.2
	_encarar(dx)
	_animar(&"run")


## Sale del suelo: sin fisica ni colision hasta que termina de asomar, asi no
## empuja a nadie desde abajo ni recibe golpes antes de existir del todo.
func emerger(duracion: float) -> void:
	set_physics_process(false)
	_colision.disabled = true
	global_position.y = -2.1
	# Con la fisica y no con el frame: cuando termina, la unidad entra al
	# combate, y eso tiene que pasar en el mismo tick en cada corrida.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
