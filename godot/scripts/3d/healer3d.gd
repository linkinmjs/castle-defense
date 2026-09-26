class_name Healer3D
extends CharacterBody3D
## El healer, el personaje de cada jugador.
##
## Camina por el plano XZ (X es el avance del frente, Z la profundidad), salta
## y cura con dos botones. No apunta: a quien le llega cada movimiento lo decide
## Apuntado segun lo que tiene enfrente, y que movimiento sale lo decide su
## ComponenteCombos segun el orden en que se apretaron los botones. Este nodo
## pone el cuerpo: se mueve, anima, junta mana, recibe golpes y lee el input.
##
## Cada healer lee solo las acciones de su jugador (p1_*, p2_*, ver Jugadores).
## Por eso nunca marca un evento como manejado: el otro healer y la batalla
## escuchan el mismo input y cada uno se queda con lo suyo.

signal mana_cambio(actual: float, maximo: float)
signal vida_cambio(actual: float, maximo: float)
signal aviso(texto: String)
signal cayo
## Toco el suelo al terminar un salto.
signal aterrizo
## Cambio el aliado que recibiria la ligera. Lo escuchan la ficha del HUD y
## quien quiera marcarlo en el campo.
signal apuntada_cambio(unidad: Unidad3D)
## El mismo aviso del componente de combos, para que el HUD no tenga que
## saber donde vive: cuenta 0 es que el combo se corto.
signal combo_cambio(cuenta: int, nombre: String)

const FRAMES_FX := preload("res://assets/sprites/fx/fx_frames.tres")
## Alto con el que se ve un efecto en el mundo, sea cual sea su sheet.
const ALTO_EFECTO := 1.6
## Segundos que la pose de un movimiento no se deja pisar por caminar.
const DURACION_POSE := 0.45

## Que acciones lee: 1 las p1_*, 2 las p2_*.
@export_range(1, 2) var jugador: int = 1
## Color con el que se distingue a cada jugador. La escena trae el dorado del
## primero.
@export var tinte_jugador: Color = Color(1.0, 0.88, 0.55):
	set(valor):
		tinte_jugador = valor
		if is_node_ready():
			_tinte_base = valor
			_sprite.modulate = valor

@export var velocidad_maxima: float = 4.6
@export var aceleracion: float = 34.0
@export var friccion: float = 40.0
## La profundidad se recorre mas lento que el frente, igual que en la version
## 2D: mantiene la sensacion de campo lateral aunque el mundo sea 3D.
@export var factor_profundidad: float = 0.7

@export_group("Salto")
@export var altura_salto: float = 1.1
@export var gravedad: float = 22.0

@export_group("Vida")
@export var vida_maxima: float = 60.0
## Segundos que pasa en el suelo al caer. Caer no termina la partida: una
## distraccion de dos segundos no puede borrar veinte minutos de juego.
@export var tiempo_caido: float = 4.0
## Fraccion de la vida maxima con la que se levanta.
@export var vida_al_levantarse: float = 0.4

@export_group("Curacion")
@export var mana_maximo: float = 100.0
@export var regeneracion_mana: float = 7.0

## Las cajas de Apuntado, en metros. Estan aca y no solo como constantes alla
## para poder afinarlas desde el inspector, y para que otro healer pueda tener
## otro alcance.
@export_group("Alcance")
## Largo de la caja de la ligera, hacia donde mira.
@export var alcance_frontal := 2.4
## Mitad del ancho de la caja de la ligera, en profundidad.
@export var alcance_lateral := 1.3
## Cuanto se mete la caja por detras del healer.
@export var margen_trasero := 0.5
## Caja de la pesada: largo y mitad del ancho.
@export var alcance_pesada := Vector2(3.2, 2.0)

## Zona por la que puede caminar, en metros: x0, z0, ancho, profundidad.
var limites: Rect2 = Rect2(0, 0, 30, 10)
## Ademas de los limites, la X se recorta a este rango (minimo, maximo). Con
## una camara compartida, es lo que no deja a un jugador salirse de la
## pantalla del otro. Por defecto no recorta nada.
var limites_pantalla := Vector2(-INF, INF)
var mana: float
var vida: float
## Que tipo de enemigo le pego por ultima vez.
var fuente_ultimo_dano: String = ""

var _impulso_direccion: Vector3 = Vector3.ZERO
var _impulso_fuerza: float = 0.0
var _impulso_restante: float = 0.0
## Lo que falta de la pose del ultimo movimiento. Mientras dura, caminar no la
## pisa.
var _casteando: float = 0.0
## Lo que falta de la animacion de golpe. Mientras dura, caminar no la pisa.
var _hurt_restante: float = 0.0
var _en_el_aire: bool = false
var _caido_restante: float = 0.0
var _flash: float = 0.0
var _tinte_base: Color = Color.WHITE
## El aliado que recibiria la ligera ahora. Se calcula una vez por tick.
var _al_frente: Unidad3D = null

@onready var _sprite: AnimatedSprite3D = $Sprite
@onready var _combos: ComponenteCombos = $Combos


func _ready() -> void:
	# Sin gravedad ni suelo fisico: se desliza por el plano.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Capa propia y sin mascara: atraviesa a los soldados, que lo buscan por
	# grupo y no por colision, y dos healers tampoco se traban entre si.
	collision_layer = 2   # jugadores
	collision_mask = 0
	# En este grupo lo encuentran los enemigos: es un objetivo mas, y el mas
	# cercano gana. Rodeado de soldados no sos vos; solo, si.
	add_to_group("healer")
	_tinte_base = tinte_jugador
	_sprite.modulate = tinte_jugador
	_combos.combo_cambio.connect(combo_cambio.emit)
	mana = mana_maximo
	mana_cambio.emit(mana, mana_maximo)
	vida = vida_maxima
	vida_cambio.emit(vida, vida_maxima)


## Lo deja como al principio de un encuentro. Reiniciar recargando la escena
## seria mas simple, pero perderia la semilla y el indice del encuentro en
## curso, que es justo lo que hay que conservar para repetir el mismo problema.
func reiniciar(posicion: Vector3) -> void:
	global_position = posicion
	velocity = Vector3.ZERO
	vida = vida_maxima
	mana = mana_maximo
	_caido_restante = 0.0
	_impulso_restante = 0.0
	_impulso_fuerza = 0.0
	_casteando = 0.0
	_hurt_restante = 0.0
	_en_el_aire = false
	_flash = 0.0
	# Reequipar lo mismo es lo que deja al componente como nuevo: sin combo,
	# sin enfriamientos y sin una plegaria a medio rezar que saldria en el
	# campo nuevo.
	_combos.equipar(_combos.movimientos)
	_cambiar_al_frente(null)
	_sprite.modulate = _tinte_base
	_sprite.play("idle")
	vida_cambio.emit(vida, vida_maxima)
	mana_cambio.emit(mana, mana_maximo)


func _physics_process(delta: float) -> void:
	_actualizar_flash(delta)
	if _caido_restante > 0.0:
		_caido_restante -= delta
		_impulso_restante = 0.0
		if _caido_restante <= 0.0:
			_levantarse()

	# Horizontal y vertical se resuelven por separado: el impulso no tiene que
	# pisar la gravedad, ni el salto frenar el desplazamiento.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _impulso_restante > 0.0:
		_impulso_restante -= delta
		horizontal = _impulso_direccion * _impulso_fuerza
	else:
		var entrada := Vector2.ZERO
		if _puede_actuar():
			entrada = Input.get_vector(
				_accion(&"izquierda"), _accion(&"derecha"), _accion(&"arriba"), _accion(&"abajo"))
		var direccion := Vector3(entrada.x, 0.0, entrada.y * factor_profundidad)
		if direccion != Vector3.ZERO:
			horizontal = horizontal.move_toward(direccion * velocidad_maxima, aceleracion * delta)
		else:
			horizontal = horizontal.move_toward(Vector3.ZERO, friccion * delta)

	var vertical := velocity.y
	if _en_el_aire:
		vertical -= gravedad * delta
	velocity = Vector3(horizontal.x, vertical, horizontal.z)

	move_and_slide()

	var x_min := maxf(limites.position.x, limites_pantalla.x)
	var x_max := minf(limites.end.x, limites_pantalla.y)
	global_position.x = clampf(global_position.x, x_min, x_max)
	global_position.z = clampf(global_position.z, limites.position.y, limites.end.y)

	# El suelo es el plano y=0: no hay cuerpo fisico debajo.
	if global_position.y <= 0.0:
		global_position.y = 0.0
		if _en_el_aire:
			_en_el_aire = false
			velocity.y = 0.0
			aterrizo.emit()

	# Caido no junta mana: si no, caer seria una pausa gratis para recargar.
	if mana < mana_maximo and esta_viva():
		mana = minf(mana + regeneracion_mana * delta, mana_maximo)
		mana_cambio.emit(mana, mana_maximo)

	_casteando = maxf(_casteando - delta, 0.0)
	_hurt_restante = maxf(_hurt_restante - delta, 0.0)
	_actualizar_animacion()
	# Despues de moverse: la caja de la ligera sale de donde quedo parado.
	_actualizar_al_frente()


## Solo reacciona a las acciones de su jugador, y nunca marca el evento como
## manejado (ver la cabecera).
func _unhandled_input(evento: InputEvent) -> void:
	if not _puede_actuar():
		return
	if evento.is_action_pressed(_accion(&"saltar")):
		saltar()
	elif evento.is_action_pressed(_accion(&"ligera")):
		pulsar(ComponenteCombos.LIGERA)
	elif evento.is_action_pressed(_accion(&"pesada")):
		pulsar(ComponenteCombos.PESADA)


## Aprieta un boton de movimiento (&"ligera" o &"pesada"). Devuelve true si
## salio o quedo en marcha. Es lo mismo que hace el input, y lo que usan las
## pruebas y las capturas para no depender de un teclado.
func pulsar(entrada: StringName) -> bool:
	return _combos.pulsar(entrada)


## Salto fisico: sirve para esquivar lo que pega a ras del suelo. Quien
## quiera saber si el healer esta a salvo pregunta esta_en_el_aire().
func saltar() -> void:
	if _en_el_aire or not _puede_actuar():
		return
	_en_el_aire = true
	velocity.y = sqrt(2.0 * gravedad * altura_salto)
	_sprite.play("jump")


func esta_en_el_aire() -> bool:
	return _en_el_aire


## Rezando una plegaria (o cualquier movimiento con carga): el healer esta
## comprometido y no camina ni salta hasta que sale.
func esta_en_wind_up() -> bool:
	return _combos != null and _combos.esta_en_wind_up()


## -1 si mira hacia su base, +1 si mira hacia el frente.
func direccion_frente() -> float:
	return Apuntado.direccion_frente(self)


func mirando_izquierda() -> bool:
	return _sprite.flip_h


func _puede_actuar() -> bool:
	return esta_viva() and not esta_en_wind_up()


func _accion(entrada: StringName) -> StringName:
	return Jugadores.accion(jugador, entrada)


# --- Vida ----------------------------------------------------------------------

## Misma firma que en las unidades: los enemigos golpean a cualquier objetivo
## sin saber si es soldado o healer, y pasan siempre quien pego.
##
## El combo no se corta aca: el componente lo corta solo al ver bajar la vida.
func recibir_dano(cantidad: float, fuente: Node = null, _causa: StringName = &"golpe") -> void:
	if not esta_viva():
		return
	if fuente != null and fuente is Unidad3D and fuente.tipo != null:
		fuente_ultimo_dano = fuente.tipo.nombre
	vida = maxf(vida - cantidad, 0.0)
	_flash = 0.12
	vida_cambio.emit(vida, vida_maxima)
	if vida <= 0.0:
		_caer()
		return
	# En el aire, en una pose o rezando manda esa pose, como en
	# _actualizar_animacion: el golpe se lee igual por el destello.
	if not _en_el_aire and _casteando <= 0.0 and not esta_en_wind_up():
		_hurt_restante = 0.25
		_sprite.play("hurt")


## Mismo nombre que en las unidades: los enemigos preguntan esto a cualquier
## objetivo sin saber si es soldado o healer. Caido no cuenta como vivo, asi
## que dejan de pegarle y buscan a otro.
func esta_viva() -> bool:
	return _caido_restante <= 0.0


## Mismo nombre que en las unidades, por la misma razon.
func esta_derribada() -> bool:
	return _caido_restante > 0.0


## Lo que estaba cargando o esperando el suelo lo cancela el componente en su
## tick: tirado no se termina de rezar.
func _caer() -> void:
	_caido_restante = tiempo_caido
	_impulso_restante = 0.0
	_casteando = 0.0
	_hurt_restante = 0.0
	_sprite.play("dead")
	cayo.emit()
	aviso.emit("Caiste")


func _levantarse() -> void:
	_caido_restante = 0.0
	vida = vida_maxima * vida_al_levantarse
	vida_cambio.emit(vida, vida_maxima)
	_sprite.play("idle")
	aviso.emit("Te levantaste")


func _actualizar_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	_sprite.modulate = Color.WHITE if _flash > 0.0 else _tinte_base


# --- API que usan los movimientos ----------------------------------------------

## El aliado que recibiria la ligera ahora, o null. Es lo que marca la elipse a
## sus pies y lo que muestra la ficha del HUD.
func unidad_apuntada() -> Unidad3D:
	if not _sigue_en_juego(_al_frente):
		return null
	return _al_frente


## Solo descuenta: la pose la pone animar_movimiento, que sabe que movimiento
## fue. Asi un movimiento al aire tambien se ve, aunque no cobre.
func gastar_mana(cantidad: float) -> void:
	mana = maxf(mana - cantidad, 0.0)
	mana_cambio.emit(mana, mana_maximo)


## La pose de un movimiento, conecte o no. La llama el componente.
func animar_movimiento(mov: Movimiento) -> void:
	# En el aire la pose de salto manda: si la pisara otra, al terminar
	# volveria a arrancar el salto desde el primer frame.
	if mov == null or _en_el_aire:
		return
	var animacion := mov.animacion
	if not _sprite.sprite_frames.has_animation(animacion):
		animacion = "cast"
	_sprite.play(animacion)
	_casteando = DURACION_POSE


## Arranca la carga de un movimiento lento. Hasta que sale (o lo cancela una
## caida), _puede_actuar() da false: sin caminar, que frena con la friccion, y
## sin saltar.
func iniciar_wind_up(mov: Movimiento) -> void:
	animar_movimiento(mov)


func lanzar_efecto(objetivo: Node3D, animacion: String) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	if not FRAMES_FX.has_animation(animacion) or FRAMES_FX.get_frame_count(animacion) == 0:
		animacion = "heal"
	var efecto := AnimatedSprite3D.new()
	efecto.sprite_frames = FRAMES_FX
	# Mismo alto en el mundo para cualquier efecto: los sheets no miden todos
	# lo mismo (hay de 72 px y de 128 px).
	var cuadro := FRAMES_FX.get_frame_texture(animacion, 0)
	var alto := float(cuadro.get_height()) if cuadro != null else 72.0
	efecto.pixel_size = ALTO_EFECTO / alto
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


# --- Al frente -----------------------------------------------------------------

## Recalcula a quien le llegaria la ligera. El ultimo tocado por el combo es
## pegajoso, igual que para el Vendaje: la marca no salta al vecino a mitad de
## un combo. Tirado no hay a quien: la ligera no sale.
func _actualizar_al_frente() -> void:
	var nuevo: Unidad3D = null
	if esta_viva():
		nuevo = Apuntado.objetivo_ligera(self, _combos.ultimo_objetivo())
	_cambiar_al_frente(nuevo)


## Mueve la marca del anterior al nuevo y avisa si cambio.
##
## La marca lleva el numero del jugador, que el overlay pinta con su color. Se
## reescribe en cada tick: si los dos healers tienen al mismo soldado al
## frente, queda la del ultimo que proceso, y al soltarlo uno la marca sigue
## siendo del otro.
func _cambiar_al_frente(nuevo: Unidad3D) -> void:
	var anterior: Unidad3D = _al_frente if _sigue_en_juego(_al_frente) else null
	_al_frente = nuevo
	if nuevo != null:
		nuevo.resaltada = true
		# Si esta en la caja, esta al alcance: con el apuntado por posicion no
		# hay objetivo marcado que no se pueda tocar.
		nuevo.resaltada_alcanzable = true
		nuevo.resaltada_por = jugador
	if anterior == nuevo:
		return
	# Solo se suelta si todavia es propia: apagarla aunque la tenga el otro la
	# haria parpadear un frame, hasta que el otro la vuelve a marcar.
	if anterior != null and anterior.resaltada_por == jugador:
		anterior.resaltada = false
		anterior.resaltada_por = 0
	apuntada_cambio.emit(nuevo)


## Variant y no Unidad3D: la marca puede haber quedado en una unidad que ya se
## libero, y pasar eso a un parametro tipado es un error en si mismo.
static func _sigue_en_juego(unidad: Variant) -> bool:
	if not is_instance_valid(unidad):
		return false
	var nodo := unidad as Unidad3D
	return nodo != null and not nodo.is_queued_for_deletion() and nodo.esta_viva()


func _actualizar_animacion() -> void:
	if not esta_viva():
		return  # en el suelo se queda con la animacion de caida
	if velocity.x < -0.05:
		_sprite.flip_h = true
	elif velocity.x > 0.05:
		_sprite.flip_h = false

	if _en_el_aire or _casteando > 0.0 or esta_en_wind_up():
		return  # ni el salto ni la pose ni la carga se interrumpen por caminar
	if _hurt_restante > 0.0:
		return  # el golpe se ve entero antes de volver a caminar

	var rapidez := Vector2(velocity.x, velocity.z).length()
	var animacion := "idle"
	if rapidez > velocidad_maxima * 0.7:
		animacion = "run"
	elif rapidez > 0.25:
		animacion = "walk"

	if _sprite.animation != animacion:
		_sprite.play(animacion)
