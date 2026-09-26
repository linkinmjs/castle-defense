class_name Unidad3D
extends CharacterBody3D
## Soldado que combate por su cuenta, version 3D.
##
## Misma logica que la unidad 2D: cambia el mundo (plano XZ) y el dibujo, no
## las reglas. Las barras de vida ya no se pintan aca sino en un overlay, que
## proyecta a pantalla la posicion de cada unidad.
##
## El tamano y el golpe salen del TipoSoldado. Un tipo con golpe telegrafiado
## (el bruto, el jefe) marca el suelo donde va a caer, se queda plantado
## mientras carga y pega ahi cuando vence el aviso, este quien este.

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
## Empezo un golpe telegrafiado: la marca ya esta en el suelo y el golpe cae en
## `segundos`. Para quien quiera sumarle un sonido o contar esquivas sin mirar
## la escena.
signal golpe_anunciado(punto: Vector3, radio: float, segundos: float)
## Cayo un golpe telegrafiado. `alcanzados` es a cuantos les pego: los que se
## salieron de la marca o la saltaron no cuentan. Es el momento para sacudir
## la camara, no el anuncio.
signal golpe_cayo(punto: Vector3, alcanzados: int)

const FRAMES_ALIADO := preload("res://assets/sprites/soldier/soldier_frames.tres")
const FRAMES_ENEMIGO := preload("res://assets/sprites/enemy/enemy_frames.tres")
## Cargada en runtime y no con preload: la escena la genera gen_scenes3d, que
## tambien carga este script, y un preload rompe el parseo si todavia no existe.
const RUTA_MARCA := "res://scenes/3d/marca_telegrafo.tscn"

const TINTE_ALIADO := Color(0.62, 0.78, 1.0)
const TINTE_ENEMIGO := Color(1.0, 0.58, 0.52)
## La capsula de la escena mide 1.7 m para un soldado de 2 m. Un tipo mas alto
## o mas bajo conserva la proporcion.
const PROPORCION_CAPSULA := 0.85
## Radio minimo de la marca: un golpe telegrafiado a un solo objetivo tambien
## tiene que verse en el suelo, aunque no pegue en area.
const RADIO_MARCA_MINIMO := 0.8

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
## Golpe telegrafiado, copiado del tipo (ver TipoSoldado).
var telegrafiado: float = 0.0
var barrido: bool = false
var radio_golpe: float = 0.0
var anim_ataque_2: StringName = &""
var factor_ataque_2: float = 1.5
## A que altura sobre los pies va la barra de vida. Sale del tipo: un oso de
## 2.2 m o un jefe de 3.2 m no la llevan donde un soldado.
var altura_barra: float = 2.1
## El jefe del nivel, copiado del tipo. El HUD lo usa para darle su barra.
var es_jefe: bool = false
## X que un aliado no pasa al avanzar. La fija el sector en curso; INF es que
## no hay limite. Los enemigos no la miran.
var limite_avance_x: float = INF
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
## Que jugador la marco (0 = nadie): el overlay pinta la marca con su color,
## para que con dos healers cada uno sepa cual es la suya.
var resaltada_por: int = 0

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
## Lo que le queda aturdida: mientras dure no camina ni pega.
var _aturdida_restante: float = 0.0
## Donde cae el golpe en curso: la posicion del objetivo cuando empezo.
var _punto_golpe: Vector3 = Vector3.ZERO
## Cuanto pega el golpe en curso respecto de `dano`: el segundo ataque del
## jefe pega mas.
var _factor_golpe: float = 1.0
## La marca en el suelo del golpe telegrafiado en curso, si hay.
var _marca: MarcaTelegrafo = null

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
		telegrafiado = tipo.telegrafiado
		barrido = tipo.barrido
		radio_golpe = tipo.radio_golpe
		anim_ataque_2 = StringName(tipo.anim_ataque_2)
		factor_ataque_2 = tipo.factor_ataque_2
		altura_barra = tipo.altura_barra
		es_jefe = tipo.es_jefe
	vida = vida_maxima

	if bando == Bando.ALIADO:
		add_to_group("aliados")
		collision_layer = 4   # allies
	else:
		add_to_group("enemigos")
		collision_layer = 8   # enemies
	# Se bloquean entre si: de ese amontonamiento sale la linea de frente.
	collision_mask = 12       # allies | enemies

	# Lo normal es configurarla antes de entrar al arbol y que el cuerpo se
	# ajuste en _ready. Si ya entro, _ready no vuelve a correr: se ajusta aca.
	if is_node_ready():
		_aplicar_presentacion()


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
	_aplicar_presentacion()
	_sprite.modulate = TINTE_ALIADO if bando == Bando.ALIADO else TINTE_ENEMIGO
	_sprite.flip_h = bando == Bando.ENEMIGO
	_sprite.play("idle")


## Sprites y tamano del tipo. Las hojas vienen de 40, 96 o 128 px y el
## personaje ocupa una parte distinta del cuadro en cada una: el tamano del
## pixel sale del alto que ocupa y de lo que tiene que medir en el mundo. Sin
## tipo quedan los valores de la escena, que son los del soldado.
func _aplicar_presentacion() -> void:
	if tipo != null and tipo.frames != null:
		_sprite.sprite_frames = tipo.frames
	else:
		_sprite.sprite_frames = FRAMES_ALIADO if bando == Bando.ALIADO else FRAMES_ENEMIGO
	if tipo == null:
		return
	_sprite.pixel_size = tipo.altura_metros / tipo.alto_util_px
	# Los pies estan en el borde de abajo del cuadro: subirlo medio lado deja
	# el origen del nodo a ras del suelo.
	_sprite.offset = Vector2(0.0, tipo.lado_frame / 2.0)
	_ajustar_capsula(tipo.radio_colision, tipo.altura_metros * PROPORCION_CAPSULA)


## Forma nueva y no la de la escena: esa la comparten todas las instancias, y
## agrandarla agrandaria a todos los soldados a la vez. Si el tipo mide lo
## mismo que la escena se queda con la compartida.
func _ajustar_capsula(radio: float, alto: float) -> void:
	var actual := _colision.shape as CapsuleShape3D
	if actual != null and is_equal_approx(actual.radius, radio) \
			and is_equal_approx(actual.height, alto):
		return
	var capsula := CapsuleShape3D.new()
	capsula.radius = radio
	capsula.height = maxf(alto, radio * 2.0)
	_colision.shape = capsula
	_colision.position = Vector3(0.0, capsula.height * 0.5, 0.0)


## Si la sacan del campo con un golpe telegrafiado en marcha, la marca no se
## queda en el suelo avisando algo que ya no va a pasar.
func _exit_tree() -> void:
	_cancelar_golpe()


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

	# Aturdida no hace nada mas: ni camina, ni pega, ni se retira. Sin
	# move_and_slide, asi tampoco la corre de lugar el amontonamiento.
	if _aturdida_restante > 0.0:
		_aturdida_restante -= delta
		velocity = Vector3.ZERO
		return

	if _impacto_pendiente > 0.0:
		_impacto_pendiente -= delta
		if _impacto_pendiente <= 0.0:
			_conectar_golpe()

	# Con un golpe telegrafiado en marcha se queda plantada hasta que cae: si
	# pudiera caminar, la marca dejaria de decir de donde viene el golpe.
	if _telegrafiando():
		velocity = Vector3.ZERO
		return

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

	var x_antes := global_position.x
	move_and_slide()
	global_position.y = 0.0
	_respetar_limite(x_antes)


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
	if _frenar_en_limite(delta):
		_animar(&"idle")
		return
	_animar(&"walk")


## Un aliado no pasa del limite de avance, ni caminando sin objetivo ni
## persiguiendo a uno que esta mas alla: la linea se arma ahi y espera. Frena
## justo en el borde en vez de pasarse y volver. Devuelve true si quedo parada
## contra el limite, para que no camine en el lugar.
func _frenar_en_limite(delta: float) -> bool:
	if bando != Bando.ALIADO or velocity.x <= 0.0:
		return false
	var margen := maxf(limite_avance_x - global_position.x, 0.0)
	velocity.x = minf(velocity.x, margen / delta)
	return margen <= 0.001 and absf(velocity.z) < 0.05


## El freno de _avanzar ya la deja en el borde; esto cubre lo que el freno no
## ve, como un roce con otro soldado que la desliza hacia adelante. Si ya
## estaba pasada (el limite se corrio para atras), no la trae de vuelta: solo
## no la deja seguir.
func _respetar_limite(x_antes: float) -> void:
	if bando != Bando.ALIADO:
		return
	var tope := maxf(limite_avance_x, x_antes)
	if global_position.x > tope:
		global_position.x = tope


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
		_iniciar_golpe()
	elif not _es_ataque(_sprite.animation) and _impacto_pendiente <= 0.0:
		_animar(&"idle")


## El golpe normal cae a los retardo_impacto. El telegrafiado marca el suelo
## donde esta el objetivo y cae ahi cuando vence el aviso.
func _iniciar_golpe() -> void:
	_cooldown = cadencia * (1.0 - _bonus_cadencia)
	var animacion := _elegir_ataque()
	_punto_golpe = _objetivo.global_position if _objetivo_valido() else global_position
	# En el suelo aunque el objetivo este saltando: ahi va la marca.
	_punto_golpe.y = 0.0
	if telegrafiado > 0.0:
		_impacto_pendiente = telegrafiado
		_marcar_suelo()
	else:
		_impacto_pendiente = retardo_impacto
	# El golpe sale igual; lo que se posterga es solo el dibujo.
	if _hurt_restante <= 0.0 and _sprite.sprite_frames.has_animation(animacion):
		# El telegrafiado estira la animacion a lo que dura el aviso: se ve
		# cargar mientras la marca crece y baja cuando pega.
		_sprite.speed_scale = _escala_para(animacion, telegrafiado) if telegrafiado > 0.0 else 1.0
		_sprite.play(animacion)
	if telegrafiado > 0.0:
		golpe_anunciado.emit(_punto_golpe, _radio_marca(), telegrafiado)


## El jefe alterna dos ataques con su azar sembrado: la misma semilla repite la
## misma secuencia. Los dos se anuncian igual; el segundo pega mas.
func _elegir_ataque() -> StringName:
	_factor_golpe = 1.0
	if anim_ataque_2 == &"" or _azar.randf() < 0.5:
		return &"attack"
	_factor_golpe = factor_ataque_2
	return anim_ataque_2


func _es_ataque(animacion: StringName) -> bool:
	return animacion == &"attack" or (anim_ataque_2 != &"" and animacion == anim_ataque_2)


## Cuanto hay que frenar la animacion para que dure `segundos`.
func _escala_para(animacion: StringName, segundos: float) -> float:
	var frames := _sprite.sprite_frames
	var fps := frames.get_animation_speed(animacion)
	if segundos <= 0.0 or fps <= 0.0:
		return 1.0
	var cuadros := 0.0
	for i in frames.get_frame_count(animacion):
		cuadros += frames.get_frame_duration(animacion, i)
	return (cuadros / fps) / segundos


func _telegrafiando() -> bool:
	return telegrafiado > 0.0 and _impacto_pendiente > 0.0


func _radio_marca() -> float:
	return maxf(radio_golpe, RADIO_MARCA_MINIMO)


## La marca cuelga del padre y no de la unidad: es del suelo, no del cuerpo. Y
## asi, al limpiar el campo, se va junto con las unidades.
func _marcar_suelo() -> void:
	_cerrar_telegrafiado()
	var padre := get_parent()
	if padre == null or not ResourceLoader.exists(RUTA_MARCA):
		return
	var escena: PackedScene = load(RUTA_MARCA)
	_marca = escena.instantiate()
	_marca.iniciar(telegrafiado, _radio_marca())
	padre.add_child(_marca)
	_marca.global_position = _punto_golpe


## Termina el telegrafiado, haya caido el golpe o no: saca la marca del suelo
## y devuelve la animacion a su ritmo.
func _cerrar_telegrafiado() -> void:
	if _marca != null and is_instance_valid(_marca):
		_marca.cancelar()
	_marca = null
	if is_node_ready():
		_sprite.speed_scale = 1.0


## El golpe en curso no llega a caer: la tiraron, la aturdieron o se fue.
func _cancelar_golpe() -> void:
	_impacto_pendiente = -1.0
	_cerrar_telegrafiado()


## Cambia la animacion de movimiento o de combate, salvo mientras se ve el
## golpe recibido.
func _animar(animacion: StringName) -> void:
	if _hurt_restante > 0.0 or _sprite.animation == animacion:
		return
	_sprite.play(animacion)


func _conectar_golpe() -> void:
	_impacto_pendiente = -1.0
	var anunciado := telegrafiado > 0.0
	_cerrar_telegrafiado()
	var cantidad := dano * _factor_golpe
	var alcanzados := 0
	if radio_golpe > 0.0:
		alcanzados = _golpear_area(cantidad)
	elif _objetivo_valido() \
			and global_position.distance_to(_objetivo.global_position) <= alcance * 1.25 \
			and not (barrido and _en_el_aire(_objetivo)):
		_objetivo.recibir_dano(cantidad, self)
		alcanzados = 1
	if anunciado:
		golpe_cayo.emit(_punto_golpe, alcanzados)


## Pega donde cayo el golpe y no a quien apuntaba: el que salio de la marca se
## salva y el que entro la recibe. Si no, la marca no le diria nada al healer.
## Devuelve a cuantos les pego.
func _golpear_area(cantidad: float) -> int:
	var alcanzados := 0
	for grupo in _grupos_rivales():
		for candidato in get_tree().get_nodes_in_group(grupo):
			var nodo := candidato as Node3D
			if not _en_juego(nodo):
				continue
			# Sobre el suelo, sin la altura: saltar solo salva de un barrido.
			var dx := nodo.global_position.x - _punto_golpe.x
			var dz := nodo.global_position.z - _punto_golpe.z
			if dx * dx + dz * dz > radio_golpe * radio_golpe:
				continue
			if barrido and _en_el_aire(nodo):
				continue
			nodo.recibir_dano(cantidad, self)
			alcanzados += 1
	return alcanzados


## Solo el healer salta: un soldado no tiene como esquivar un barrido.
func _en_el_aire(nodo: Node3D) -> bool:
	return nodo.has_method(&"esta_en_el_aire") and nodo.esta_en_el_aire()


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
	if esta_viva() and not esta_derribada() and is_node_ready() and not _no_se_inmuta():
		_hurt_restante = 0.25
		_sprite.play("hurt")


## El bruto y el jefe no acusan los golpes: con toda la linea pegandoles
## vivirian en la animacion de dolor, y la carga de su golpe, que es el aviso,
## no se veria. Se enteran por el destello.
func _no_se_inmuta() -> bool:
	return telegrafiado > 0.0 or es_jefe


## La frena: no camina ni pega mientras dure, y pierde el golpe que tenia en
## marcha, marca incluida. Lo usa la Caida sanadora del healer.
func aturdir(segundos: float) -> void:
	if estado == Estado.MUERTA or estado == Estado.DERRIBADA or segundos <= 0.0:
		return
	_aturdida_restante = maxf(_aturdida_restante, segundos)
	_cancelar_golpe()
	velocity = Vector3.ZERO
	if is_node_ready():
		_sprite.play("hurt")


func esta_aturdida() -> bool:
	return _aturdida_restante > 0.0


## Donde va la barra de vida: sobre los pies, a la altura que pide el tipo.
func punto_cabeza() -> Vector3:
	return global_position + Vector3(0.0, altura_barra, 0.0)


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
	# El golpe que tenia en marcha no cae: su marca se va con ella.
	_cancelar_golpe()
	_aturdida_restante = 0.0
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
	_cancelar_golpe()
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


## Para un enemigo, el healer entra en la lista de rivales: de ahi sale la
## cobertura sin programarla aparte, y por eso tambien lo alcanza un golpe en
## area.
func _grupos_rivales() -> Array[String]:
	if bando == Bando.ENEMIGO:
		return ["aliados", "healer"]
	return ["enemigos"]


## Una derribada no es objetivo ni recibe golpes: ya esta fuera de combate.
func _en_juego(nodo: Node3D) -> bool:
	return nodo != null and nodo.esta_viva() and not nodo.esta_derribada() \
		and not nodo.is_queued_for_deletion()


## El mas cercano de los grupos rivales. Rodeado de soldados, siempre hay
## alguien mas cerca que el healer.
func _buscar_objetivo() -> Node3D:
	var grupos := _grupos_rivales()

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
			if not _en_juego(nodo):
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
			if not _en_juego(nodo):
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
