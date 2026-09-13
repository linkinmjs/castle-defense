extends Node3D
## Escena principal del prototipo 3D.
##
## Corre un encuentro: despliega lo que el recurso pide, manda los refuerzos
## cuando se cumple su disparador y decide cuando termina. El combate lo
## resuelve cada unidad por su cuenta, y la camara sigue al healer.
##
## La composicion vive en el Encuentro y no aca. Antes salia de dos relojes y
## azar sin semilla, y eso hacia que dos partidas no fueran comparables: no se
## podia saber si una fue mas dificil por lo que hizo el jugador o por como
## cayo el reparto.

const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")
const RUTA_CAMPANA := "res://resources/encuentros/campana.tres"

signal batalla_terminada(victoria: bool)
## Arranco un encuentro, propio o el siguiente de la campania.
signal encuentro_iniciado(encuentro: Encuentro, semilla: int, indice: int)
## Unico punto por el que pasan todas las unidades que entran al campo: quien
## quiera observarlas (telemetria, overlay) se engancha aca y no a la escena.
signal unidad_creada(unidad: Unidad3D)

@export var ancho_campo: float = 30.0
@export var profundidad_campo: float = 10.0

@export_group("Camara")
## Cuanto se aleja la camara del healer, sobre el eje de vision.
@export var distancia_camara: float = 11.0
## Angulo picado: 0 seria de perfil puro, 90 seria cenital.
@export var angulo_camara: float = 15.0
## La camara mira a la altura del pecho, no a los pies.
@export var altura_objetivo: float = 1.05
@export var suavizado_camara: float = 4.0
## Ventana alrededor del punto que mira la camara: mientras el healer se mueva
## dentro de ella, la camara no se mueve. Sin esto acompana cada pasito.
@export var zona_muerta_camara: float = 1.8

@export_group("Campo")
@export var base_aliada_x: float = 1.5
@export var base_enemiga_x: float = 28.5

@export_group("Encuentros")
## La serie que se juega. Si queda vacia se carga la de RUTA_CAMPANA.
@export var campana: Campana
## Encuentro suelto: si esta puesto se juega solo este y se ignora la campania.
## Lo usan las pruebas y sirve para probar uno desde el editor.
@export var encuentro: Encuentro

@export_group("Emergentes")
## Cada cuanto sale algo del suelo cerca del healer. Es un evento que
## interrumpe, no un ritmo de fondo: constante, el juego seria esquivar.
@export var intervalo_emergentes: float = 14.0
@export var emergentes_por_tanda: int = 1
## Aparecen a esta distancia del healer como maximo, nunca en la linea.
@export var radio_emergentes: float = 4.0
## Segundos de aviso en el suelo antes de que salga el enemigo.
@export var aviso_emergente: float = 1.0

@onready var _healer: Healer3D = %Healer
@onready var _camara: Camera3D = %Camara
@onready var _unidades: Node3D = %Unidades
@onready var _overlay: Control = %Overlay
@onready var _hud: CanvasLayer = %HUD

## Punto X que la camara esta mirando. Se mueve solo cuando el healer sale de
## la zona muerta, y nunca mas alla de los bordes del campo.
var _camara_x: float
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
var _actual: Encuentro
## Creada por codigo y no puesta en la escena: asi no hay que tocar battle3d
## para medir, y las pruebas pueden armar una a mano sin instanciar el HUD.
var _telemetria: Telemetria
var _escena_emergente: PackedScene
var _terminada: bool = false
## Mana del healer tal como viene en la escena. Un encuentro puede recortarlo,
## y el siguiente que no diga nada tiene que recuperar este, no heredar el
## recorte del anterior.
var _mana_maximo_base: float = 0.0
var _regeneracion_base: float = 0.0
var _bajas_aliadas: int = 0
var _emergente_restante: float = 0.0
## Oleadas ya disparadas, por indice, para no repetir las que no se repiten.
var _oleadas_lanzadas: Dictionary = {}


func _ready() -> void:
	# Rotacion fija de una vez: la camara nunca gira, solo se traslada. Si se
	# le hiciera look_at cada frame mientras la posicion va con retraso, el
	# yaw iria corrigiendo y la vista se ladearia al caminar.
	_camara.rotation_degrees = Vector3(-angulo_camara, 0.0, 0.0)

	_mana_maximo_base = _healer.mana_maximo
	_regeneracion_base = _healer.regeneracion_mana

	_telemetria = Telemetria.new()
	_telemetria.name = "Telemetria"
	add_child(_telemetria)
	_telemetria.observar_batalla(self)
	_telemetria.observar_healer(_healer)

	# Apuntar y dibujar barras necesitan proyectar el mundo a pantalla.
	_healer.usar_camara(_camara)
	_overlay.seguir(_camara)
	_hud.seguir(_healer)
	_hud.seguir_batalla(self)

	# Cargado en runtime y no con preload: la escena la genera el mismo script
	# que genera esta, y un preload rompe el parseo si todavia no existe.
	_escena_emergente = load("res://scenes/3d/emergente3d.tscn")

	if campana == null and encuentro == null and ResourceLoader.exists(RUTA_CAMPANA):
		campana = load(RUTA_CAMPANA)

	iniciar_encuentro(_primer_encuentro())


func _process(delta: float) -> void:
	_actualizar_camara(delta)
	if _terminada or _actual == null:
		return

	tiempo_encuentro += delta
	_revisar_oleadas()
	_revisar_emergentes(delta)
	_revisar_desenlace()


func _unhandled_input(evento: InputEvent) -> void:
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
	_limpiar_campo()

	if _actual == null:
		return

	sembrar(nueva_semilla if nueva_semilla >= 0 else _actual.semilla)

	ancho_campo = _actual.ancho_campo
	profundidad_campo = _actual.profundidad_campo
	base_aliada_x = _actual.base_aliada_x
	base_enemiga_x = _actual.base_enemiga_x
	_emergente_restante = intervalo_emergentes

	_healer.limites = Rect2(1.5, 1.5, ancho_campo - 3.0, profundidad_campo - 3.0)
	# Un encuentro que no declara mana recupera el de la escena, no el que
	# dejo el encuentro anterior.
	if _actual.mana_maximo > 0.0:
		_healer.mana_maximo = _actual.mana_maximo
	else:
		_healer.mana_maximo = _mana_maximo_base
	if _actual.regeneracion_mana >= 0.0:
		_healer.regeneracion_mana = _actual.regeneracion_mana
	else:
		_healer.regeneracion_mana = _regeneracion_base
	_healer.reiniciar(Vector3(_actual.healer_inicial.x, 0.0, _actual.healer_inicial.y))
	if not _actual.habilidades.is_empty():
		_habilidades().equipar(_actual.habilidades)

	_camara_x = _healer.global_position.x
	_camara.global_position = _posicion_deseada()

	# Antes de desplegar: quien mide arranca en cero justo aca, y asi los
	# soldados que entran ya sangrando cuentan como crisis del encuentro.
	encuentro_iniciado.emit(_actual, semilla_actual, indice_encuentro)

	for grupo in _actual.grupos_iniciales:
		_desplegar_grupo(grupo)


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


## Saca del campo todo lo desplegado. El healer y la camara se quedan: son
## parte de la escena, no del encuentro.
func _limpiar_campo() -> void:
	for hijo in _unidades.get_children():
		if hijo == _healer:
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


func _primer_encuentro() -> Encuentro:
	if encuentro != null:
		return encuentro
	if campana != null:
		return campana.encuentro_en(indice_encuentro)
	return null


func _habilidades() -> ComponenteHabilidades:
	return _healer.get_node("Habilidades")


## Fija el azar del despliegue. Con 0 sortea una semilla y la guarda, para que
## se la pueda leer y repetir.
func sembrar(nueva_semilla: int) -> void:
	semilla_actual = nueva_semilla if nueva_semilla != 0 else randi()
	_rng.seed = semilla_actual


# --- Despliegue ---------------------------------------------------------------

func _desplegar_grupo(grupo: GrupoUnidades) -> void:
	if grupo == null:
		return
	for i in grupo.cantidad:
		var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
		unidad.configurar(grupo.bando, grupo.tipo)
		unidad.sembrar(_rng.randi())
		unidad.base_x = base_aliada_x if grupo.bando == Unidad3D.Bando.ALIADO \
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

func _revisar_oleadas() -> void:
	for i in _actual.oleadas.size():
		var oleada: OleadaEncuentro = _actual.oleadas[i]
		if oleada == null:
			continue
		var lanzadas: int = _oleadas_lanzadas.get(i, 0)
		if lanzadas > 0 and not oleada.repetir:
			continue
		if not _disparador_cumplido(oleada, lanzadas):
			continue
		for grupo in oleada.grupos:
			_desplegar_grupo(grupo)
		_oleadas_lanzadas[i] = lanzadas + 1


func _disparador_cumplido(oleada: OleadaEncuentro, lanzadas: int) -> bool:
	match oleada.disparador:
		OleadaEncuentro.Disparador.RELOJ:
			# Al repetirse, la siguiente entra un intervalo mas tarde.
			return tiempo_encuentro >= oleada.valor * (lanzadas + 1)
		OleadaEncuentro.Disparador.BAJAS_ALIADAS:
			return _bajas_aliadas >= int(oleada.valor) * (lanzadas + 1)
		OleadaEncuentro.Disparador.FRENTE_PASA_X:
			return frente_x() <= oleada.valor
		OleadaEncuentro.Disparador.SIN_ENEMIGOS:
			return _vivos("enemigos") == 0
	return false


# --- Emergentes ---------------------------------------------------------------

func _revisar_emergentes(delta: float) -> void:
	if _actual == null or not _actual.emergentes_habilitados:
		return
	_emergente_restante -= delta
	if _emergente_restante > 0.0:
		return
	_emergente_restante = intervalo_emergentes
	_lanzar_emergentes()


## Marca el suelo cerca del healer; cuando el aviso termina, sale el enemigo.
func _lanzar_emergentes() -> void:
	for i in emergentes_por_tanda:
		var angulo := _rng.randf() * TAU
		var radio := _rng.randf_range(2.0, radio_emergentes)
		var pos := _healer.global_position + Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio)
		# Nunca dentro de una base: un zombi que nace en la zona de derrota
		# la dispararia solo, sin que nadie haya llegado a nada.
		pos.x = clampf(pos.x, base_aliada_x + 2.5, base_enemiga_x - 2.5)
		pos.z = clampf(pos.z, 1.5, profundidad_campo - 1.5)
		pos.y = 0.0

		var aviso: Emergente3D = _escena_emergente.instantiate()
		aviso.duracion = aviso_emergente
		aviso.position = pos
		aviso.termino.connect(_emerger_enemigo)
		add_child(aviso)


func _emerger_enemigo(pos: Vector3) -> void:
	var grupo := GrupoUnidades.new()
	grupo.bando = Unidad3D.Bando.ENEMIGO
	grupo.tipo = _tipo_enemigo()
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
## meter una silueta que el jugador no vio nunca.
func _tipo_enemigo() -> TipoSoldado:
	if _actual == null:
		return null
	for grupo in _actual.grupos_iniciales:
		if grupo != null and grupo.bando == Unidad3D.Bando.ENEMIGO and grupo.tipo != null:
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
			if _vivos("enemigos") == 0:
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


# --- Camara -------------------------------------------------------------------

## Sigue solo el avance del frente (X): ni la profundidad ni los saltos mueven
## la vista, que en un campo lateral marean mas de lo que aportan.
func _actualizar_camara(delta: float) -> void:
	var hx := _healer.global_position.x
	_camara_x = clampf(_camara_x, hx - zona_muerta_camara, hx + zona_muerta_camara)
	var mitad := _mitad_visible()
	_camara_x = clampf(_camara_x, mitad, ancho_campo - mitad)

	_camara.global_position = _camara.global_position.lerp(
		_posicion_deseada(), 1.0 - exp(-suavizado_camara * delta))


## Media anchura que entra en pantalla a la distancia del objetivo, para no
## mostrar mas alla de los bordes del campo.
func _mitad_visible() -> float:
	var aspecto := get_viewport().get_visible_rect().size.aspect()
	return tan(deg_to_rad(_camara.fov * 0.5)) * distancia_camara * aspecto


func _objetivo_camara() -> Vector3:
	return Vector3(_camara_x, altura_objetivo, profundidad_campo * 0.5)


func _posicion_deseada() -> Vector3:
	var objetivo := _objetivo_camara()
	var radianes := deg_to_rad(angulo_camara)
	return objetivo + Vector3(
		0.0,
		sin(radianes) * distancia_camara,
		cos(radianes) * distancia_camara)
