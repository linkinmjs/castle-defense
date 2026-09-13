extends Node3D
## Escena principal del prototipo 3D.
##
## Despliega los dos ejercitos, manda refuerzos y sigue al healer con la
## camara. El combate lo resuelve cada unidad por su cuenta.

const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")

signal batalla_terminada(victoria: bool)

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

@export_group("Ejercitos")
@export var base_aliada_x: float = 1.5
@export var base_enemiga_x: float = 28.5
## Los dos ejercitos arrancan ya trabados en el centro: si salieran desde las
## bases habria medio minuto de marcha antes de ver el primer golpe.
@export var unidades_iniciales: int = 6
@export var refuerzos_por_tanda: int = 2
## La horda es horda por numero: mas zombis que soldados, mas por tanda.
@export var enemigos_iniciales: int = 9
@export var refuerzos_enemigos: int = 3
@export var intervalo_refuerzos: float = 9.0
## De estos se elige al azar cada vez que entra un soldado.
@export var tipos_aliados: Array[TipoSoldado] = []
@export var tipos_enemigos: Array[TipoSoldado] = []

@export_group("Azar")
## Semilla del despliegue. En 0 se sortea una al empezar y queda guardada en
## semilla_actual, asi un reinicio repite la misma batalla en vez de armar otra.
@export var semilla: int = 0

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
## La semilla que se esta usando de verdad, ya sea la configurada o la sorteada.
var semilla_actual: int = 0
var _escena_emergente: PackedScene
var _terminada: bool = false
var _relojes: Array[Timer] = []


func _ready() -> void:
	_healer.limites = Rect2(1.5, 1.5, ancho_campo - 3.0, profundidad_campo - 3.0)
	# Rotacion fija de una vez: la camara nunca gira, solo se traslada. Si se
	# le hiciera look_at cada frame mientras la posicion va con retraso, el
	# yaw iria corrigiendo y la vista se ladearia al caminar.
	_camara.rotation_degrees = Vector3(-angulo_camara, 0.0, 0.0)
	_camara_x = _healer.global_position.x
	_camara.global_position = _posicion_deseada()

	# Apuntar y dibujar barras necesitan proyectar el mundo a pantalla.
	_healer.usar_camara(_camara)
	_overlay.seguir(_camara)
	_hud.seguir(_healer)
	_hud.seguir_batalla(self)

	sembrar(semilla)
	_desplegar_formacion_inicial()

	var reloj := Timer.new()
	reloj.wait_time = intervalo_refuerzos
	reloj.timeout.connect(_enviar_refuerzos)
	add_child(reloj)
	reloj.start()
	_relojes.append(reloj)

	# Cargado en runtime y no con preload: la escena la genera el mismo script
	# que genera esta, y un preload rompe el parseo si todavia no existe.
	_escena_emergente = load("res://scenes/3d/emergente3d.tscn")
	var reloj_emergentes := Timer.new()
	reloj_emergentes.wait_time = intervalo_emergentes
	reloj_emergentes.timeout.connect(_lanzar_emergentes)
	add_child(reloj_emergentes)
	reloj_emergentes.start()
	_relojes.append(reloj_emergentes)


func _process(delta: float) -> void:
	_actualizar_camara(delta)
	if not _terminada:
		_revisar_desenlace()


func _unhandled_input(evento: InputEvent) -> void:
	if _terminada and evento.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()


## Gana quien llega a la base contraria. Los derribados no cuentan: un
## soldado tirado a un metro de la base enemiga no la tomo.
func _revisar_desenlace() -> void:
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
	for reloj in _relojes:
		reloj.stop()
	batalla_terminada.emit(victoria)


## Fija el azar del despliegue. Con 0 sortea una semilla y la guarda, para que
## se la pueda leer y repetir.
func sembrar(nueva_semilla: int) -> void:
	semilla_actual = nueva_semilla if nueva_semilla != 0 else randi()
	_rng.seed = semilla_actual


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


func _desplegar_formacion_inicial() -> void:
	var centro := ancho_campo * 0.5
	for i in unidades_iniciales:
		_crear_unidad(Unidad3D.Bando.ALIADO, centro - _rng.randf_range(1.5, 4.5))
	for i in enemigos_iniciales:
		_crear_unidad(Unidad3D.Bando.ENEMIGO, centro + _rng.randf_range(1.5, 5.5))


func _enviar_refuerzos() -> void:
	for i in refuerzos_por_tanda:
		_crear_unidad(Unidad3D.Bando.ALIADO, base_aliada_x + _rng.randf_range(0.5, 1.5))
	for i in refuerzos_enemigos:
		_crear_unidad(Unidad3D.Bando.ENEMIGO, base_enemiga_x - _rng.randf_range(0.5, 1.5))


func _crear_unidad(bando: Unidad3D.Bando, x: float) -> void:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando, _tipo_al_azar(bando))
	unidad.sembrar(_rng.randi())
	unidad.base_x = base_aliada_x if bando == Unidad3D.Bando.ALIADO else base_enemiga_x
	unidad.position = Vector3(x, 0.0, _rng.randf_range(1.5, profundidad_campo - 1.5))
	_unidades.add_child(unidad)


func _tipo_al_azar(bando: Unidad3D.Bando) -> TipoSoldado:
	var lista: Array[TipoSoldado] = tipos_aliados
	if bando == Unidad3D.Bando.ENEMIGO:
		lista = tipos_enemigos
	if lista.is_empty():
		return null
	return lista[_rng.randi() % lista.size()]


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
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(Unidad3D.Bando.ENEMIGO, _tipo_al_azar(Unidad3D.Bando.ENEMIGO))
	unidad.sembrar(_rng.randi())
	unidad.base_x = base_enemiga_x
	unidad.position = pos
	_unidades.add_child(unidad)
	unidad.emerger(0.5)


func _objetivo_camara() -> Vector3:
	return Vector3(_camara_x, altura_objetivo, profundidad_campo * 0.5)


func _posicion_deseada() -> Vector3:
	var objetivo := _objetivo_camara()
	var radianes := deg_to_rad(angulo_camara)
	return objetivo + Vector3(
		0.0,
		sin(radianes) * distancia_camara,
		cos(radianes) * distancia_camara)
