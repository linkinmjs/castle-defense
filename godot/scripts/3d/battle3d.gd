extends Node3D
## Escena principal del prototipo 3D.
##
## Corre un encuentro: despliega lo que el recurso pide, manda los refuerzos
## cuando se cumple su disparador y decide cuando termina. El combate lo
## resuelve cada unidad por su cuenta, y la camara (CamaraBatalla) sigue a los
## healers.
##
## La composicion vive en el Encuentro y no aca. Antes salia de dos relojes y
## azar sin semilla, y eso hacia que dos partidas no fueran comparables: no se
## podia saber si una fue mas dificil por lo que hizo el jugador o por como
## cayo el reparto.
##
## Juegan uno o dos healers con una sola camara. El 1 viene en la escena; el 2
## entra si el menu pidio dos, o cuando su jugador aprieta cualquier boton suyo
## (drop-in). Desde ahi es de la partida como el 1: cada encuentro lo reubica y
## ninguno lo saca. Los dos quedan siempre en cuadro: la camara dice entre que
## X puede andar cada uno, y la batalla se lo pasa en cada tick.
##
## Un nivel largo se juega por sectores (ver Sector). Mientras uno esta en
## curso, la camara, los healers y la tropa no pasan de su x_fin; cuando se
## libera, la batalla avisa, el limite pasa al del siguiente, y ese entra
## cuando alguien llega a su puerta. Un encuentro sin sectores es un solo tramo
## con todo el campo, como siempre.

const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")
## Cargada en runtime y no con preload, como la del emergente: la genera el
## mismo script que genera esta escena.
const RUTA_HEALER := "res://scenes/3d/healer3d.tscn"
## El 2 tiene las mismas animaciones que el 1 con el contorno turquesa. El 1
## trae las suyas, de contorno dorado, en la escena.
const RUTA_FRAMES_JUGADOR_2 := "res://assets/sprites/healer2/healer2_frames.tres"
## Donde se para el 2 respecto del 1: un paso atras y un poco mas cerca de la
## camara, para que de entrada no se tapen.
const LADO_DEL_1 := Vector3(-1.2, 0.0, 0.8)
## Lo que los healers no pisan en cada borde del campo.
const MARGEN_HEALERS := 1.5
## Cuanto antes del limite del sector se frena la tropa. En la practica a los
## healers los frena la camara unos 3 m antes del limite, asi que los soldados
## siguen esperando adelante de ellos, que es donde se pelea. No menos de 2.6:
## la fila mas cercana a la camara ve menos campo, y un soldado parado a 1.2 m
## de la puerta quedaba cortado por el borde de la pantalla.
const RETRASO_ALIADOS := 2.6
## A cuanto del x_fin de un sector liberado tiene que llegar alguien para que
## entre el siguiente. Menos que los dos margenes de arriba: con el sector en
## curso nadie llega a la puerta, y el siguiente no entra antes de tiempo.
const PUERTA_SECTOR := 1.0
## Mas cerca que esto de la puerta, los enemigos de un sector se ven aparecer:
## la media pantalla es de unos 7.5 m.
const DISTANCIA_ENTRADA := 9.0
## El tope de avance de la tropa lo agrega Unidad3D en otro cambio.
const LIMITE_AVANCE := &"limite_avance_x"

signal batalla_terminada(victoria: bool)
## Arranco un encuentro, propio o el siguiente de la campania.
signal encuentro_iniciado(encuentro: Encuentro, semilla: int, indice: int)
## Unico punto por el que pasan todas las unidades que entran al campo: quien
## quiera observarlas (telemetria, overlay) se engancha aca y no a la escena.
signal unidad_creada(unidad: Unidad3D)
## Se sumo un healer. Cuando sale ya esta en el arbol, en el campo y armado
## para el encuentro en curso. Si el menu pidio dos, sale dentro del _ready de
## la batalla, antes del primer encuentro_iniciado; si entra a mitad (drop-in),
## sale en ese momento, con el encuentro andando o ya terminado. El 1 no pasa
## por aca: viene en la escena.
signal jugador_agregado(healer: Healer3D)
## Entro un sector: su tropa ya esta desplegada y su limite puesto. El primero
## sale al arrancar el encuentro, despues de encuentro_iniciado, y otra vez en
## cada reinicio. Un encuentro sin sectores no lo emite nunca.
signal sector_iniciado(indice: int, sector: Sector)
## El sector en curso se libero: el limite ya paso al x_fin del siguiente (o a
## todo el campo, si era el ultimo) y la tropa puede avanzar. Es el momento del
## cartel de avanzar.
signal sector_liberado(indice: int)

@export var ancho_campo: float = 30.0
@export var profundidad_campo: float = 10.0

@export_group("Campo")
@export var base_aliada_x: float = 1.5
@export var base_enemiga_x: float = 28.5

@export_group("Encuentros")
## La serie que se juega. Si queda vacia se carga la que anoto el menu
## (Navegacion.campana_pedida), que sin anotacion son las lecciones.
@export var campana: Campana
## Encuentro suelto: si esta puesto se juega solo este y se ignora la campania.
## Lo usan las pruebas y sirve para probar uno desde el editor.
@export var encuentro: Encuentro

@export_group("Emergentes")
## Cada cuanto sale algo del suelo cerca de un healer. Es un evento que
## interrumpe, no un ritmo de fondo: constante, el juego seria esquivar.
@export var intervalo_emergentes: float = 14.0
@export var emergentes_por_tanda: int = 1
## Aparecen a esta distancia del healer como maximo, nunca en la linea.
@export var radio_emergentes: float = 4.0
## Segundos de aviso en el suelo antes de que salga el enemigo.
@export var aviso_emergente: float = 1.0

## El jugador 1, el que trae la escena. A los demas se llega con healer_de().
@onready var _healer: Healer3D = %Healer
@onready var _camara: CamaraBatalla = %Camara
@onready var _unidades: Node3D = %Unidades
@onready var _overlay: Control = %Overlay
@onready var _hud: CanvasLayer = %HUD

## Todo el azar del despliegue sale de aca y no de las funciones globales: es
## lo que permite repetir una batalla y comparar dos intentos.
var _rng := RandomNumberGenerator.new()
## La semilla que se esta usando de verdad, ya sea la del encuentro o la
## sorteada cuando venia en 0.
var semilla_actual: int = 0
## Cual de la campania se esta jugando.
var indice_encuentro: int = 0
## Segundos desde que arranco el encuentro. Es el reloj de las oleadas y del
## limite de duracion; reemplaza a los Timer, que no se podian reiniciar sin
## recrearlos y no sobrevivian a un reinicio sin recargar la escena.
var tiempo_encuentro: float = 0.0
## Segundos desde que entro el sector en curso: el reloj de sus oleadas y de
## su liberacion por tiempo. Va con la fisica, igual que tiempo_encuentro.
var tiempo_sector: float = 0.0
var _actual: Encuentro
## Creada por codigo y no puesta en la escena: asi no hay que tocar battle3d
## para medir, y las pruebas pueden armar una a mano sin instanciar el HUD.
var _telemetria: Telemetria
var _escena_emergente: PackedScene
var _terminada: bool = false
## Mana del healer tal como viene en la escena. Un encuentro puede recortarlo,
## y el siguiente que no diga nada tiene que recuperar este, no heredar el
## recorte del anterior. Vale para todos: el 2 sale de la misma escena.
var _mana_maximo_base: float = 0.0
var _regeneracion_base: float = 0.0
## Los movimientos que trae la escena del healer. Un encuentro que no pide
## ninguno en particular equipa estos, no los que dejo el anterior.
var _movimientos_base: Array[Movimiento] = []
var _bajas_aliadas: int = 0
var _emergente_restante: float = 0.0
## Oleadas ya disparadas, por indice, para no repetir las que no se repiten.
var _oleadas_lanzadas: Dictionary = {}
## Por indice de oleada: si su disparador por flanco puede volver a disparar.
## Falta la clave hasta la primera vez que se evalua, y eso cuenta como armada.
var _disparador_armado: Dictionary = {}
## Sector en curso, por su indice en el encuentro. -1 si no tiene sectores.
var _indice_sector: int = -1
## Si el sector en curso ya se libero: el limite es el del siguiente.
var _sector_liberado: bool = false
## Como _oleadas_lanzadas y _disparador_armado, para las oleadas del sector en
## curso: sus indices son de otra lista, y se vacian al entrar a cada sector.
var _oleadas_sector_lanzadas: Dictionary = {}
var _disparador_sector_armado: Dictionary = {}


func _ready() -> void:
	# Cada jugador con su joystick. Los ids de los pads cambian al enchufar y
	# desenchufar (y en web son los que el navegador quiera), asi que se
	# vuelven a repartir cada vez.
	Jugadores.aplicar_dispositivos()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	_mana_maximo_base = _healer.mana_maximo
	_regeneracion_base = _healer.regeneracion_mana
	_movimientos_base = _combos_de(_healer).movimientos.duplicate()

	_telemetria = Telemetria.new()
	_telemetria.name = "Telemetria"
	add_child(_telemetria)
	_telemetria.observar_batalla(self)
	_telemetria.observar_healer(_healer)

	# Dibujar las barras necesita proyectar el mundo a pantalla.
	_overlay.seguir(_camara)
	_hud.seguir(_healer)
	_hud.seguir_batalla(self)

	# El borde rojo del golpe al healer. Por codigo y no en la escena: solo hay
	# que verla, y en headless (las pruebas) no se crea. Quien la pulse lo hace
	# por su grupo (Vineta.GRUPO), sin tenerla a mano.
	if Presentacion.activa():
		add_child(Vineta.new())

	# Cargado en runtime y no con preload: la escena la genera el mismo script
	# que genera esta, y un preload rompe el parseo si todavia no existe.
	_escena_emergente = load("res://scenes/3d/emergente3d.tscn")

	# Lecciones o niveles, segun lo que eligio el menu. Sin anotacion (pruebas,
	# F6 sobre esta escena) las lecciones, como siempre.
	if campana == null and encuentro == null:
		var ruta_campana := Navegacion.campana_pedida(get_tree())
		if ResourceLoader.exists(ruta_campana):
			campana = load(ruta_campana)

	var pausa := get_node_or_null("%MenuPausa")
	if pausa != null:
		pausa.seguir_batalla(self)

	# Con el campo de la escena, antes de que haya encuentro: si no hubiera
	# ninguno que jugar, la camara igual mira el campo, y el 2 que entra aca
	# abajo se ubica contra una pantalla que existe.
	_encuadrar_camara()

	# Los que pidio el menu entran antes del primer encuentro, que despues los
	# ubica a todos. Va despues de seguir_batalla: quien escuche
	# jugador_agregado desde ahi (el HUD) ya esta enganchado.
	if Jugadores.cantidad_pedida(get_tree()) >= 2:
		agregar_jugador(2)

	# Por que leccion arrancar lo deja anotado el menu. Sin anotacion (pruebas,
	# F6 sobre esta escena) arranca por la primera, como siempre.
	indice_encuentro = Navegacion.encuentro_pedido(get_tree())
	iniciar_encuentro(_primer_encuentro())


## La camara va con el frame: solo muestra, no decide nada del juego. Lo que si
## decide (por donde puede andar cada healer) lo toma la fisica, en
## _acotar_healers().
func _process(delta: float) -> void:
	_camara.actualizar(delta)


## Los relojes del encuentro van al paso de la fisica, como el combate. Un
## frame lento hace que Godot recupere el atraso con varios pasos de fisica
## seguidos y ningun _process en el medio: con los relojes en _process, el
## desenlace y las oleadas se evaluaban tarde, y el mismo encuentro podia
## terminar distinto segun cuanto tardara cada frame.
func _physics_process(delta: float) -> void:
	# Antes de cortar por el desenlace: debajo del cartel del final los
	# healers se siguen moviendo, y tienen que seguir en cuadro.
	_acotar_healers()
	if _terminada or _actual == null:
		return

	tiempo_encuentro += delta
	if _indice_sector >= 0:
		tiempo_sector += delta
	_revisar_oleadas()
	# Despues de las oleadas: una que entra al quedar el campo vacio sostiene
	# el sector, en vez de llegar con el cartel de avanzar ya puesto. Antes del
	# desenlace: lo que entra con un sector cuenta en el mismo tick.
	_revisar_sector()
	_revisar_emergentes(delta)
	_revisar_desenlace()


func _unhandled_input(evento: InputEvent) -> void:
	# Drop-in: el 2 se suma apretando cualquier boton suyo, jugando o con el
	# cartel del final. No se marca como manejado, y no hace falta: la batalla
	# lo ve despues que todos sus hijos, asi que el healer nuevo no recibe el
	# boton que lo sumo (entrar no le hace curar ni saltar). Primero se mira el
	# evento, que es barato: llegan todo el tiempo, y recorrer el campo buscando
	# al 2 solo hace falta cuando aprieta algo suyo.
	if Jugadores.es_entrada_de(2, evento) and not tiene_jugador(2):
		agregar_jugador(2)

	if not _terminada:
		return
	if evento.is_action_pressed("reiniciar"):
		reiniciar_encuentro()
	elif evento.is_action_pressed("continuar"):
		avanzar_encuentro()


# --- Encuentros ---------------------------------------------------------------

## Deja el campo como lo pide el encuentro y lo arranca. Con semilla en -1 usa
## la que trae el propio encuentro.
func iniciar_encuentro(enc: Encuentro, nueva_semilla: int = -1) -> void:
	_actual = enc
	_terminada = false
	_bajas_aliadas = 0
	tiempo_encuentro = 0.0
	_oleadas_lanzadas.clear()
	_disparador_armado.clear()
	# Antes de ubicar a nadie: los limites de los healers salen del sector en
	# curso, y el del encuentro anterior no puede filtrarse a este.
	_indice_sector = -1
	_sector_liberado = false
	tiempo_sector = 0.0
	_oleadas_sector_lanzadas.clear()
	_disparador_sector_armado.clear()
	_limpiar_campo()

	if _actual == null:
		return

	sembrar(nueva_semilla if nueva_semilla >= 0 else _actual.semilla)

	ancho_campo = _actual.ancho_campo
	profundidad_campo = _actual.profundidad_campo
	base_aliada_x = _actual.base_aliada_x
	base_enemiga_x = _actual.base_enemiga_x
	_emergente_restante = intervalo_emergentes
	_configurar_mundo()

	# Todos por el mismo camino, el 2 al lado del 1: igual que cuando entra a
	# mitad de un encuentro.
	var inicio := Vector3(_actual.healer_inicial.x, 0.0, _actual.healer_inicial.y)
	for h in _healers():
		_configurar_healer(h, inicio if h.jugador == 1 else _al_lado_del_1(inicio))

	# Despues de ubicarlos: la camara arranca sobre ellos, sin deslizarse desde
	# donde quedo el encuentro anterior.
	_encuadrar_camara()

	# Antes de desplegar: quien mide arranca en cero justo aca, y asi los
	# soldados que entran ya sangrando cuentan como crisis del encuentro.
	encuentro_iniciado.emit(_actual, semilla_actual, indice_encuentro)

	for grupo in _actual.grupos_iniciales:
		_desplegar_grupo(grupo)

	# Despues de la tropa inicial, que asi queda frenada por el primer limite,
	# y de encuentro_iniciado, por lo mismo que los grupos: quien mide ya
	# arranco y cuenta a los que entran con el sector.
	if not _actual.sectores.is_empty():
		_entrar_sector(0)


## Repite el mismo encuentro con la misma semilla: el problema es identico y lo
## unico que cambia es lo que haga el jugador.
func reiniciar_encuentro() -> void:
	iniciar_encuentro(_actual, semilla_actual)


## Pasa al siguiente de la campania. Devuelve false si era el ultimo, y en ese
## caso vuelve al primero.
func avanzar_encuentro() -> bool:
	if campana == null or campana.encuentros.is_empty():
		reiniciar_encuentro()
		return false

	var hay_mas := indice_encuentro + 1 < campana.encuentros.size()
	indice_encuentro = indice_encuentro + 1 if hay_mas else 0
	iniciar_encuentro(campana.encuentro_en(indice_encuentro))
	return hay_mas


## Saca del campo todo lo desplegado. Los healers y la camara se quedan: son de
## la partida, no del encuentro.
func _limpiar_campo() -> void:
	for hijo in _unidades.get_children():
		if hijo is Healer3D:
			continue
		# Sacarlo del grupo ya mismo: queue_free recien libera al final del
		# frame, y hasta entonces el desenlace y el frente seguirian contandolo.
		if hijo is Unidad3D:
			hijo.remove_from_group("aliados")
			hijo.remove_from_group("enemigos")
		hijo.queue_free()
	for hijo in get_children():
		if hijo is Emergente3D:
			hijo.queue_free()


## Lo que se ve del campo (suelo, bases, fondo) se estira al del encuentro. Es
## opcional: una escena sin %Mundo, o con uno que no se configura, se juega
## igual.
func _configurar_mundo() -> void:
	var mundo := get_node_or_null("%Mundo")
	if mundo != null and mundo.has_method(&"configurar"):
		mundo.configurar(ancho_campo, profundidad_campo, base_aliada_x, base_enemiga_x)


func _primer_encuentro() -> Encuentro:
	if encuentro != null:
		return encuentro
	if campana != null:
		return campana.encuentro_en(indice_encuentro)
	return null


func _combos_de(healer: Node) -> ComponenteCombos:
	return healer.get_node("Combos")


func _on_joy_connection_changed(_device: int, _conectado: bool) -> void:
	Jugadores.aplicar_dispositivos()


## Fija el azar del despliegue. Con 0 sortea una semilla y la guarda, para que
## se la pueda leer y repetir.
func sembrar(nueva_semilla: int) -> void:
	semilla_actual = nueva_semilla if nueva_semilla != 0 else randi()
	_rng.seed = semilla_actual


# --- Jugadores ----------------------------------------------------------------

## Suma el healer del jugador j al lado del 1, armado para el encuentro en
## curso (o con lo de la escena si todavia no hay ninguno), y avisa con
## jugador_agregado. Si ya estaba, devuelve el que hay sin tocarlo.
func agregar_jugador(j: int) -> Healer3D:
	var existente := healer_de(j)
	if existente != null:
		return existente
	if j < 1 or j > Jugadores.MAXIMO:
		push_error("No hay jugador %d: juegan de 1 a %d" % [j, Jugadores.MAXIMO])
		return null

	var escena: PackedScene = load(RUTA_HEALER)
	var h: Healer3D = escena.instantiate()
	h.name = "Healer%d" % j
	h.jugador = j
	if j == 2:
		h.tinte_jugador = Jugadores.tinte(2)
		var sprite: AnimatedSprite3D = h.get_node("Sprite")
		sprite.sprite_frames = load(RUTA_FRAMES_JUGADOR_2)
	_unidades.add_child(h)

	# Al lado del 1 y ya en cuadro: si entrara fuera de la pantalla, el recorte
	# del tick siguiente lo haria aparecer de un salto.
	var pos := _al_lado_del_1(_healer.global_position)
	var campo := _limites_campo()
	var pantalla := _camara.rango_x_jugadores()
	pos.x = clampf(pos.x, maxf(campo.position.x, pantalla.x), minf(campo.end.x, pantalla.y))
	_configurar_healer(h, pos)

	_telemetria.observar_healer(h)
	_camara.seguir(_healers_como_nodos())
	jugador_agregado.emit(h)
	return h


## El healer del jugador j, o null si ese jugador no esta jugando.
func healer_de(j: int) -> Healer3D:
	for h in _healers():
		if h.jugador == j:
			return h
	return null


func tiene_jugador(j: int) -> bool:
	return healer_de(j) != null


## Los healers en juego, el 1 primero. Se leen del campo y no de una lista
## aparte: al sumar uno no hay nada que mantener, y uno liberado deja de
## contar solo.
func _healers() -> Array[Healer3D]:
	var lista: Array[Healer3D] = []
	for hijo in _unidades.get_children():
		var h := hijo as Healer3D
		if h != null and not h.is_queued_for_deletion():
			lista.append(h)
	lista.sort_custom(func(a: Healer3D, b: Healer3D) -> bool: return a.jugador < b.jugador)
	return lista


## La misma lista, con el tipo que pide la camara.
func _healers_como_nodos() -> Array[Node3D]:
	var nodos: Array[Node3D] = []
	nodos.assign(_healers())
	return nodos


## Deja a un healer como lo pide el encuentro en curso: limites, mana,
## regeneracion, posicion y movimientos. Es el mismo camino para todos, al
## empezar un encuentro y al sumarse a mitad de uno. Sin encuentro, con lo de
## la escena.
func _configurar_healer(h: Healer3D, posicion: Vector3) -> void:
	h.limites = _limites_campo()
	# Un encuentro que no declara mana recupera el de la escena, no el que
	# dejo el encuentro anterior.
	if _actual != null and _actual.mana_maximo > 0.0:
		h.mana_maximo = _actual.mana_maximo
	else:
		h.mana_maximo = _mana_maximo_base
	if _actual != null and _actual.regeneracion_mana >= 0.0:
		h.regeneracion_mana = _actual.regeneracion_mana
	else:
		h.regeneracion_mana = _regeneracion_base
	h.reiniciar(posicion)
	if _actual != null and not _actual.movimientos.is_empty():
		_combos_de(h).equipar(_actual.movimientos)
	else:
		_combos_de(h).equipar(_movimientos_base)


## Por donde pueden caminar los healers: el campo hasta el limite del sector en
## curso, menos un margen en cada borde. Sin sectores, todo el campo.
func _limites_campo() -> Rect2:
	return Rect2(MARGEN_HEALERS, MARGEN_HEALERS,
		limite_x_actual() - 2.0 * MARGEN_HEALERS, profundidad_campo - 2.0 * MARGEN_HEALERS)


## Donde se para el 2 si el 1 esta en pos_1, sin salirse del campo.
func _al_lado_del_1(pos_1: Vector3) -> Vector3:
	var campo := _limites_campo()
	var pos := pos_1 + LADO_DEL_1
	return Vector3(
		clampf(pos.x, campo.position.x, campo.end.x),
		0.0,
		clampf(pos.z, campo.position.y, campo.end.y))


## Por donde puede andar cada healer en este tick: el campo (hasta el limite del
## sector) y lo que se ve. Va en la fisica de la batalla porque el padre procesa
## antes que sus hijos: cada healer se mueve y se recorta despues, contra lo que
## muestra la camara ahora.
func _acotar_healers() -> void:
	var campo := _limites_campo()
	var pantalla := _camara.rango_x_jugadores()
	for h in _healers():
		h.limites = campo
		h.limites_pantalla = pantalla


## Arma la camara para el campo actual, le dice a quienes seguir y la pone sobre
## ellos sin suavizado.
func _encuadrar_camara() -> void:
	_camara.configurar(profundidad_campo, 0.0, ancho_campo)
	_camara.seguir(_healers_como_nodos())
	_camara.saltar_a(_x_media_healers())


## El punto medio entre los healers de las puntas: lo que sigue la camara.
func _x_media_healers() -> float:
	var minimo := INF
	var maximo := -INF
	for h in _healers():
		minimo = minf(minimo, h.global_position.x)
		maximo = maxf(maximo, h.global_position.x)
	if minimo > maximo:
		return ancho_campo * 0.5
	return (minimo + maximo) * 0.5


# --- Despliegue ---------------------------------------------------------------

func _desplegar_grupo(grupo: GrupoUnidades) -> void:
	if grupo == null:
		return
	for i in grupo.cantidad:
		var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
		unidad.configurar(grupo.bando, grupo.tipo)
		unidad.sembrar(_rng.randi())
		unidad.base_x = _base_retirada_aliados() if grupo.bando == Unidad3D.Bando.ALIADO \
			else base_enemiga_x
		unidad.position = Vector3(
			_rng.randf_range(grupo.x_min, grupo.x_max),
			0.0,
			_rng.randf_range(grupo.z_min, grupo.z_max))

		if _actual != null:
			if not _actual.sangrado_habilitado:
				unidad.probabilidad_sangrado = 0.0
			elif _actual.probabilidad_sangrado >= 0.0:
				unidad.probabilidad_sangrado = _actual.probabilidad_sangrado

		if grupo.bando == Unidad3D.Bando.ALIADO:
			unidad.nombre_unidad = _proximo_nombre()

		_unidades.add_child(unidad)
		_aplicar_estado_inicial(unidad, grupo)
		# Con un sector en curso, el que llega tampoco se adelanta a la camara.
		if grupo.bando == Unidad3D.Bando.ALIADO and _indice_sector >= 0:
			_fijar_limite_avance(unidad, _limite_avance_aliados())
		unidad.murio.connect(_on_unidad_murio)
		unidad_creada.emit(unidad)


## Lo que hace que un encuentro pueda plantear una situacion desde el arranque
## en vez de esperar a que el combate la produzca.
func _aplicar_estado_inicial(unidad: Unidad3D, grupo: GrupoUnidades) -> void:
	if grupo.vida_inicial < 1.0:
		unidad.vida = maxf(unidad.vida_maxima * grupo.vida_inicial, 1.0)
	if grupo.sangrado_inicial > 0.0 and _actual != null and _actual.sangrado_habilitado:
		unidad.sangrado_restante = grupo.sangrado_inicial
	if grupo.derribada_inicial:
		unidad.derribar()


func _proximo_nombre() -> String:
	if _actual == null or _actual.nombres.is_empty():
		return ""
	return _actual.nombres[_rng.randi() % _actual.nombres.size()]


func _on_unidad_murio(unidad: Unidad3D) -> void:
	if unidad.bando == Unidad3D.Bando.ALIADO:
		_bajas_aliadas += 1


# --- Oleadas ------------------------------------------------------------------

## Las del encuentro y, detras, las del sector en curso: con la misma regla,
## cada lista con su reloj y su propia cuenta de lanzadas y de armadas.
func _revisar_oleadas() -> void:
	_lanzar_oleadas(_actual.oleadas, tiempo_encuentro, _oleadas_lanzadas, _disparador_armado)
	var sector := sector_activo()
	if sector != null:
		_lanzar_oleadas(sector.oleadas, tiempo_sector, _oleadas_sector_lanzadas,
				_disparador_sector_armado)


## Despliega las oleadas de la lista cuyo disparador se cumple. Los diccionarios
## son los de esa lista, por indice, y se actualizan aca mismo.
func _lanzar_oleadas(oleadas: Array[OleadaEncuentro], reloj: float,
		lanzadas_por_indice: Dictionary, armadas: Dictionary) -> void:
	for i in oleadas.size():
		var oleada: OleadaEncuentro = oleadas[i]
		if oleada == null:
			continue
		var lanzadas: int = lanzadas_por_indice.get(i, 0)
		if lanzadas > 0 and not oleada.repetir:
			continue
		if not _disparador_cumplido(oleada, lanzadas, reloj, armadas, i):
			continue
		for grupo in oleada.grupos:
			_desplegar_grupo(grupo)
		lanzadas_por_indice[i] = lanzadas + 1


func _disparador_cumplido(oleada: OleadaEncuentro, lanzadas: int, reloj: float,
		armadas: Dictionary, indice: int) -> bool:
	match oleada.disparador:
		OleadaEncuentro.Disparador.RELOJ:
			# Al repetirse, la siguiente entra un intervalo mas tarde.
			return reloj >= oleada.valor * (lanzadas + 1)
		OleadaEncuentro.Disparador.BAJAS_ALIADAS:
			return _bajas_aliadas >= int(oleada.valor) * (lanzadas + 1)
		OleadaEncuentro.Disparador.FRENTE_PASA_X:
			return _flanco(armadas, indice, frente_x() <= oleada.valor)
		OleadaEncuentro.Disparador.SIN_ENEMIGOS:
			return _flanco(armadas, indice, _vivos("enemigos") == 0)
	return false


## Para los disparadores que miran un estado y no un evento: el frente puede
## quedarse del otro lado de la X, o el campo vacio, durante cientos de ticks.
## Mirando solo si se cumple, una oleada que se repite entraba en cada uno de
## esos ticks. Por flanco dispara cuando la condicion se vuelve cierta, y para
## volver a disparar tiene que dejar de cumplirse antes.
##
## Arranca armada: si la condicion ya se cumple al empezar, dispara enseguida.
## Las de un sector arrancan cuando se entra a el.
func _flanco(armadas: Dictionary, indice: int, cumplida: bool) -> bool:
	if not cumplida:
		armadas[indice] = true
		return false
	var armado: bool = armadas.get(indice, true)
	if not armado:
		return false
	armadas[indice] = false
	return true


# --- Sectores -----------------------------------------------------------------

## El sector en curso, o null si el encuentro no tiene sectores.
func sector_activo() -> Sector:
	return _sector_en(_indice_sector)


## Su indice en el encuentro; -1 si el encuentro no tiene sectores.
func indice_sector() -> int:
	return _indice_sector


func cantidad_sectores() -> int:
	return _actual.sectores.size() if _actual != null else 0


## Si el sector en curso ya se libero, y se puede avanzar hasta el siguiente.
func sector_esta_liberado() -> bool:
	return _sector_liberado


## Hasta que X se puede llegar ahora: el x_fin del sector en curso, o el del
## siguiente si ya se libero. Sin sectores, o liberado el ultimo, todo el campo.
func limite_x_actual() -> float:
	var sector := sector_activo()
	if sector != null and _sector_liberado:
		sector = _sector_en(_indice_sector + 1)
	if sector == null:
		return ancho_campo
	return minf(sector.x_fin, ancho_campo)


## Cuanto del nivel se recorrio, de 0 en la base aliada a 1 en la enemiga, por
## el healer mas adelantado: es lo que el jugador siente como avanzar. Para la
## barra del HUD.
func progreso_nivel() -> float:
	var tramo := base_enemiga_x - base_aliada_x
	var adelante := -INF
	for h in _healers():
		adelante = maxf(adelante, h.global_position.x)
	if tramo <= 0.0 or is_inf(adelante):
		return 0.0
	return clampf((adelante - base_aliada_x) / tramo, 0.0, 1.0)


func _sector_en(indice: int) -> Sector:
	if _actual == null or indice < 0 or indice >= _actual.sectores.size():
		return null
	return _actual.sectores[indice]


## Si todavia falta entrar a algun sector.
func _quedan_sectores() -> bool:
	return _indice_sector + 1 < cantidad_sectores()


## Pone en juego el sector i: su tropa, sus refuerzos, su reloj, sus oleadas,
## sus emergentes y su limite, que vale para la camara, los healers y los
## aliados que ya estan y los que lleguen.
func _entrar_sector(i: int) -> void:
	var emergentes_antes := _emergentes_activos()
	_indice_sector = i
	_sector_liberado = false
	tiempo_sector = 0.0
	_oleadas_sector_lanzadas.clear()
	_disparador_sector_armado.clear()

	var sector := sector_activo()
	if sector != null:
		_avisar_enemigos_a_la_vista(sector, _sector_en(i - 1))
		for grupo in sector.grupos:
			_desplegar_grupo(grupo)
		for grupo in sector.refuerzos_aliados:
			_desplegar_grupo(grupo)
		# Con el sector entrado, la tropa que ya estaba se retira hasta la
		# puerta anterior y no cruza todo el nivel hacia atras.
		for nodo in get_tree().get_nodes_in_group("aliados"):
			if nodo is Unidad3D:
				(nodo as Unidad3D).base_x = _base_retirada_aliados()
	# El sector que los prende arranca con el intervalo entero: el primero no
	# puede salir apenas se cruza la puerta.
	if _emergentes_activos() and not emergentes_antes:
		_emergente_restante = intervalo_emergentes

	_camara.limitar_x(limite_x_actual())
	if i == 0:
		# El primero entra con el encuentro recien armado: la camara arranca ya
		# dentro de el, sin deslizarse desde lo que el sector no muestra.
		_camara.saltar_a(_x_media_healers())
	_aplicar_limite_avance()
	_acotar_healers()
	sector_iniciado.emit(i, sector)


## Hasta donde se retira un aliado herido. Sin sectores, hasta su base; con
## sectores, hasta unos metros antes de la puerta que ya cruzo: un lancero que
## cruzara los 90 m del nivel para curarse se perdia para la pelea.
func _base_retirada_aliados() -> float:
	if _indice_sector <= 0:
		return base_aliada_x
	var anterior := _sector_en(_indice_sector - 1)
	if anterior == null:
		return base_aliada_x
	return maxf(base_aliada_x, anterior.x_fin - 3.0)


## El sector en curso quedo resuelto: el limite pasa al x_fin del siguiente, o
## se abre todo el campo si era el ultimo, y la tropa puede seguir.
func _liberar_sector() -> void:
	_sector_liberado = true
	_camara.limitar_x(limite_x_actual())
	_aplicar_limite_avance()
	_acotar_healers()
	sector_liberado.emit(_indice_sector)


## Libera el sector en curso cuando se cumple lo suyo. Liberado, y si hay otro
## despues, ese entra en cuanto alguien llega a la puerta.
func _revisar_sector() -> void:
	var sector := sector_activo()
	if sector == null:
		return
	if not _sector_liberado and _liberacion_cumplida(sector):
		_liberar_sector()
	if _sector_liberado and _sector_en(_indice_sector + 1) != null \
			and _alguien_en_pie_llega_a(sector.x_fin - PUERTA_SECTOR):
		_entrar_sector(_indice_sector + 1)


func _liberacion_cumplida(sector: Sector) -> bool:
	match sector.liberacion:
		Sector.Liberacion.SIN_ENEMIGOS:
			# Como en las oleadas y en LIMPIAR_ENEMIGOS: un enemigo tirado
			# sigue en juego hasta que muere.
			return _vivos("enemigos") == 0
		Sector.Liberacion.FRENTE_PASA_X:
			# Al reves que el disparador de las oleadas, que mira al frente
			# retroceder: un sector se libera avanzando.
			return frente_x() >= sector.valor_liberacion
		Sector.Liberacion.RELOJ:
			return tiempo_sector >= sector.valor_liberacion
	return false


## Si algun healer o aliado en pie llego a esa X. Uno tirado en la puerta no
## la cruzo.
func _alguien_en_pie_llega_a(x: float) -> bool:
	for h in _healers():
		if h.esta_viva() and h.global_position.x >= x:
			return true
	for u in get_tree().get_nodes_in_group("aliados"):
		var n := u as Unidad3D
		if n != null and n.esta_viva() and not n.esta_derribada() \
				and not n.is_queued_for_deletion() and n.global_position.x >= x:
			return true
	return false


## Hasta donde avanza sola la tropa: un poco antes del limite actual. Sin
## sectores, o liberado el ultimo, sin tope: tiene que poder llegar a la base.
func _limite_avance_aliados() -> float:
	if sector_activo() == null:
		return INF
	if _sector_liberado and _sector_en(_indice_sector + 1) == null:
		return INF
	return limite_x_actual() - RETRASO_ALIADOS


## A todos los aliados en el campo, con el tope que corresponde ahora.
func _aplicar_limite_avance() -> void:
	var limite := _limite_avance_aliados()
	for u in get_tree().get_nodes_in_group("aliados"):
		_fijar_limite_avance(u, limite)


## Por nombre y preguntando: el tope entro en Unidad3D por separado, y la
## batalla no depende de el. Sin el, los sectores igual frenan a la camara y a
## los healers, y la tropa avanza como siempre.
static func _fijar_limite_avance(unidad: Node, x: float) -> void:
	if LIMITE_AVANCE in unidad:
		unidad.set(LIMITE_AVANCE, x)


## Los enemigos de un sector se despliegan donde dice el recurso. Si arrancan a
## menos de DISTANCIA_ENTRADA de la puerta del anterior, el jugador los ve
## aparecer: el aviso es para quien arma el nivel. El primer sector no tiene
## puerta: entra con el campo, como los grupos iniciales.
func _avisar_enemigos_a_la_vista(sector: Sector, anterior: Sector) -> void:
	if anterior == null:
		return
	var puerta := anterior.x_fin - PUERTA_SECTOR
	for grupo in sector.grupos:
		if grupo != null and grupo.bando == Unidad3D.Bando.ENEMIGO \
				and grupo.x_min < puerta + DISTANCIA_ENTRADA:
			push_warning("Sector \"%s\": un grupo enemigo arranca en x %.1f, a menos de %.0f m"
				% [sector.titulo, grupo.x_min, DISTANCIA_ENTRADA]
				+ " de la puerta (x %.1f): se lo ve aparecer." % puerta)


# --- Emergentes ---------------------------------------------------------------

func _revisar_emergentes(delta: float) -> void:
	if not _emergentes_activos():
		return
	_emergente_restante -= delta
	if _emergente_restante > 0.0:
		return
	_emergente_restante = intervalo_emergentes
	_lanzar_emergentes()


## Los prende el encuentro entero o el sector en curso.
func _emergentes_activos() -> bool:
	if _actual == null:
		return false
	var sector := sector_activo()
	return _actual.emergentes_habilitados or (sector != null and sector.emergentes)


## Marca el suelo cerca de un healer; cuando el aviso termina, sale el enemigo.
## Sin un tipo que pueda salir (ver _tipo_enemigo) no marca nada: un aviso del
## que no sale nadie enseña a ignorar los avisos.
func _lanzar_emergentes() -> void:
	if _tipo_enemigo() == null:
		return
	for i in emergentes_por_tanda:
		var healer := _healer_para_emergente()
		if healer == null:
			return
		var angulo := _rng.randf() * TAU
		var radio := _rng.randf_range(2.0, radio_emergentes)
		var pos := healer.global_position + Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio)
		# Nunca dentro de una base: un zombi que nace en la zona de derrota
		# la dispararia solo, sin que nadie haya llegado a nada. Ni pasado el
		# limite del sector, donde no se ve y los healers no pueden ir.
		pos.x = clampf(pos.x, base_aliada_x + 2.5,
				minf(base_enemiga_x - 2.5, limite_x_actual() - MARGEN_HEALERS))
		pos.z = clampf(pos.z, 1.5, profundidad_campo - 1.5)
		pos.y = 0.0

		var aviso: Emergente3D = _escena_emergente.instantiate()
		aviso.duracion = aviso_emergente
		aviso.position = pos
		aviso.termino.connect(_emerger_enemigo)
		add_child(aviso)


## Alrededor de quien sale el proximo emergente: uno de los healers en juego,
## sorteado con el azar del encuentro, asi dos intentos con la misma semilla y
## los mismos jugadores lo repiten. Con uno solo no se sortea nada: la
## secuencia de una partida de uno queda como era antes del cooperativo.
func _healer_para_emergente() -> Healer3D:
	var candidatos := _healers()
	if candidatos.is_empty():
		return null
	if candidatos.size() == 1:
		return candidatos[0]
	return candidatos[_rng.randi_range(0, candidatos.size() - 1)]


func _emerger_enemigo(pos: Vector3) -> void:
	# El sector pudo cambiar durante el aviso. Sin tipo saldria una unidad con
	# los valores de la escena, que no es ninguno de los del nivel.
	var tipo := _tipo_enemigo()
	if tipo == null:
		return
	var grupo := GrupoUnidades.new()
	grupo.bando = Unidad3D.Bando.ENEMIGO
	grupo.tipo = tipo
	grupo.cantidad = 1
	grupo.x_min = pos.x
	grupo.x_max = pos.x
	grupo.z_min = pos.z
	grupo.z_max = pos.z
	_desplegar_grupo(grupo)

	# El ultimo que entro es el que acaba de salir del suelo.
	var recien: Node = _unidades.get_child(_unidades.get_child_count() - 1)
	if recien is Unidad3D:
		recien.emerger(0.5)


## Los emergentes son del mismo tipo que los enemigos del encuentro, para no
## meter una silueta que el jugador no vio nunca. Con sectores, los del tramo
## en curso o, si no trae, los del ultimo que trajo: un nivel largo puede no
## tener ningun enemigo entre los grupos iniciales. Nunca uno de golpe
## telegrafiado ni el jefe: un oso o un demonio que sale del suelo al lado del
## healer no deja tiempo de leer su aviso, y el jefe es uno solo. Si no queda
## ninguno comun, null: ese tramo no tiene emergentes.
func _tipo_enemigo() -> TipoSoldado:
	if _actual == null:
		return null
	for i in range(_indice_sector, -1, -1):
		var sector := _sector_en(i)
		if sector != null:
			var del_sector := _primer_tipo_enemigo(sector.grupos)
			if del_sector != null:
				return del_sector
	return _primer_tipo_enemigo(_actual.grupos_iniciales)


func _primer_tipo_enemigo(grupos: Array[GrupoUnidades]) -> TipoSoldado:
	for grupo in grupos:
		if grupo == null or grupo.bando != Unidad3D.Bando.ENEMIGO or grupo.tipo == null:
			continue
		if grupo.tipo.telegrafiado > 0.0 or grupo.tipo.es_jefe:
			continue
		return grupo.tipo
	return null


# --- Desenlace ----------------------------------------------------------------

func _revisar_desenlace() -> void:
	if _actual.bajas_aliadas_maximas >= 0 and _bajas_aliadas > _actual.bajas_aliadas_maximas:
		_terminar(false)
		return
	if _actual.frente_derrota_x >= 0.0 and frente_x() <= _actual.frente_derrota_x:
		_terminar(false)
		return

	match _actual.condicion:
		Encuentro.Condicion.LLEGAR_A_BASE:
			_revisar_llegada_a_base()
		Encuentro.Condicion.SOBREVIVIR:
			if _actual.duracion > 0.0 and tiempo_encuentro >= _actual.duracion:
				_terminar(true)
		Encuentro.Condicion.LIMPIAR_ENEMIGOS:
			# Con sectores, dejar limpio uno que no es el ultimo es poder
			# avanzar, no ganar: los enemigos que faltan todavia no entraron.
			if _vivos("enemigos") == 0 and not _quedan_sectores():
				_terminar(true)
			elif _vivos("aliados") == 0:
				_terminar(false)


## Gana quien llega a la base contraria. Los derribados no cuentan: un
## soldado tirado a un metro de la base enemiga no la tomo.
func _revisar_llegada_a_base() -> void:
	for u in get_tree().get_nodes_in_group("aliados"):
		var n := u as Node3D
		if n.esta_viva() and not n.esta_derribada() and n.global_position.x >= base_enemiga_x - 1.0:
			_terminar(true)
			return
	for u in get_tree().get_nodes_in_group("enemigos"):
		var n := u as Node3D
		if n.esta_viva() and not n.esta_derribada() and n.global_position.x <= base_aliada_x + 1.0:
			_terminar(false)
			return


func _terminar(victoria: bool) -> void:
	_terminada = true
	# Las unidades quedan quietas: seguir peleando debajo del cartel de
	# victoria embarraba la lectura de como habia quedado el campo.
	for unidad in get_tree().get_nodes_in_group("aliados"):
		unidad.set_physics_process(false)
	for unidad in get_tree().get_nodes_in_group("enemigos"):
		unidad.set_physics_process(false)
	batalla_terminada.emit(victoria)


func telemetria() -> Telemetria:
	return _telemetria


func esta_terminada() -> bool:
	return _terminada


func bajas_aliadas() -> int:
	return _bajas_aliadas


func _vivos(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva() and not unidad.is_queued_for_deletion():
			total += 1
	return total


## Donde esta el choque: entre el aliado mas adelantado y el enemigo mas
## atrasado. Lo lee el indicador del HUD.
func frente_x() -> float:
	var max_aliado := -INF
	var min_enemigo := INF
	for u in get_tree().get_nodes_in_group("aliados"):
		var n := u as Node3D
		if n.esta_viva() and not n.esta_derribada():
			max_aliado = maxf(max_aliado, n.global_position.x)
	for u in get_tree().get_nodes_in_group("enemigos"):
		var n := u as Node3D
		if n.esta_viva() and not n.esta_derribada():
			min_enemigo = minf(min_enemigo, n.global_position.x)
	if max_aliado > -INF and min_enemigo < INF:
		return (max_aliado + min_enemigo) * 0.5
	if max_aliado > -INF:
		return max_aliado
	if min_enemigo < INF:
		return min_enemigo
	return ancho_campo * 0.5
