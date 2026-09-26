extends PruebaBase
## Un nivel largo partido en sectores, sobre la escena real de la batalla.
##
## El primer sector entra con el encuentro y frena a la camara, a los healers y
## a la tropa en su x_fin; se libera al quedar sin enemigos en juego, y el
## siguiente entra cuando alguien llega a la puerta, con su tropa, sus refuerzos
## y sus oleadas con reloj propio. Reiniciar vuelve al primero, un encuentro
## sin sectores se juega como siempre, y en LIMPIAR_ENEMIGOS limpiar un sector
## que no es el ultimo no gana. Tambien las otras dos liberaciones (frente y
## reloj) y los emergentes que prende un sector.
##
## El tope de la tropa (limite_avance_x) es de Unidad3D y la batalla lo fija por
## nombre: si no estuviera, esas comprobaciones se saltan y el resto se prueba
## igual.

const ESCUDERO := "res://resources/soldados/escudero.tres"
const ZOMBIE := "res://resources/soldados/zombie.tres"
const E1 := "res://resources/encuentros/e1_mantener_linea.tres"
const LIMITE_AVANCE := &"limite_avance_x"
const ALIADO := Unidad3D.Bando.ALIADO
const ENEMIGO := Unidad3D.Bando.ENEMIGO


## Hace de %Mundo mientras la escena no traiga uno: anota con que campo lo
## configura la batalla.
class MundoFalso extends Node3D:
	var llamadas: Array = []

	func configurar(ancho: float, profundidad: float, base_aliada: float,
			base_enemiga: float) -> void:
		llamadas.append([ancho, profundidad, base_aliada, base_enemiga])


var _battle: Node
var _healer: Healer3D
var _camara: CamaraBatalla
var _mundo: MundoFalso
## Lo que fue avisando la batalla, en orden: [indice, sector] por cada
## sector_iniciado, el indice de cada sector_liberado y cada desenlace.
var _iniciados: Array = []
var _liberados: Array[int] = []
var _victorias: Array[bool] = []
## Cada unidad que entro desde la ultima vez que se vacio, con su bando y la X
## en la que entro: despues de un tick ya se movio.
var _creadas: Array[Dictionary] = []
var _zombis: Array[Unidad3D] = []
## Si Unidad3D ya tiene el tope de avance.
var _con_tope := false
var _x_antes := 0.0
var _progreso_antes := 0.0


func preparar() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = encuentro_por_sectores()
	# Si la escena ya trae su %Mundo se deja el real: dos con el mismo nombre
	# unico no pueden convivir.
	if _battle.get_node_or_null("%Mundo") == null:
		_mundo = MundoFalso.new()
		_mundo.name = "Mundo"
		_battle.add_child(_mundo)
		_mundo.owner = _battle
		_mundo.unique_name_in_owner = true
	# Antes de su _ready, que es donde arranca el primer encuentro.
	_battle.sector_iniciado.connect(func(i: int, s: Sector) -> void: _iniciados.append([i, s]))
	_battle.sector_liberado.connect(func(i: int) -> void: _liberados.append(i))
	_battle.batalla_terminada.connect(func(v: bool) -> void: _victorias.append(v))
	_battle.unidad_creada.connect(func(u: Unidad3D) -> void:
		_creadas.append({"unidad": u, "bando": u.bando, "x": u.position.x}))
	root.add_child(_battle)


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 3:
				return
			_healer = _battle.get_node("%Healer")
			_camara = _battle.get_node("%Camara")
			_probar_arranque()
			_tirar_zombis()
			_mantener(&"p1_derecha", true)
			siguiente()
		1:
			# Tiempo de sobra para que el healer y la tropa lleguen al limite.
			if _ticks < 240:
				return
			_probar_limite()
			_mantener(&"p1_derecha", false)
			# Ahora si se mueren: sin enemigos en juego, el sector se libera.
			for z in _zombis:
				z.derribada_restante = 0.05
			siguiente()
		2:
			if not _battle.sector_esta_liberado():
				return
			_probar_liberacion()
			_creadas.clear()
			# En la puerta. La batalla lo ve en su tick, antes de que el healer
			# se recorte contra la pantalla en el suyo.
			_healer.global_position.x = 24.5
			siguiente()
		3:
			_probar_entrada()
			_x_antes = _healer.global_position.x
			_progreso_antes = _battle.progreso_nivel()
			_mantener(&"p1_derecha", true)
			siguiente()
		4:
			if _battle.tiempo_sector < 2.1:
				return
			_mantener(&"p1_derecha", false)
			_probar_oleada_y_progreso()
			_probar_reinicio()
			siguiente()
		5:
			if _ticks < 3:
				return
			_igual("unos ticks despues siguen los 2 zombis", _enemigos(), 2.0)
			if _con_tope:
				_ok("y la tropa vuelve al tope del sector 0 (%s)" % [_topes()],
					_todos_los_topes_en(25.0 - 2.6))
			_probar_sin_sectores()
			siguiente()
		6:
			if _ticks < 3:
				return
			_ok("los healers usan todo el campo (%s)" % _healer.limites,
				_healer.limites.is_equal_approx(Rect2(1.5, 1.5, 27.0, 7.0)))
			if _con_tope:
				_ok("y la tropa no tiene tope (%s)" % [_topes()], _todos_los_topes_en(INF))
			print("--- limpiar un sector que no es el ultimo no gana ---")
			_iniciados.clear()
			_liberados.clear()
			_victorias.clear()
			_battle.iniciar_encuentro(_encuentro_limpiar())
			siguiente()
		7:
			if _ticks < 3:
				return
			_ok("sin enemigos en el primer sector no se gana: faltan sectores",
				not _battle.esta_terminada() and _victorias.is_empty())
			_ok("FRENTE_PASA_X no se cumple con el frente atras (%.2f < 14)" % _battle.frente_x(),
				_battle.frente_x() < 14.0 and not _battle.sector_esta_liberado())
			_ok("ni el encuentro ni el primer sector prenden los emergentes",
				not _battle._emergentes_activos())
			siguiente()
		8:
			if not _battle.sector_esta_liberado():
				return
			_ok("se libera cuando el frente avanza hasta 14 (%.2f)" % _battle.frente_x(),
				_battle.frente_x() >= 14.0)
			_ok("y todavia no se gano", not _battle.esta_terminada())
			_healer.global_position.x = 19.5
			siguiente()
		9:
			_ok("en la puerta entra el ultimo sector", _battle.indice_sector() == 1)
			_igual("con su zombi", _enemigos(), 1.0)
			_ok("con un enemigo en pie no termina", not _battle.esta_terminada())
			_ok("este sector prende los emergentes", _battle._emergentes_activos())
			_ok("y salen como su zombi, aunque la tropa inicial no traiga enemigos",
				_battle._tipo_enemigo() == load(ZOMBIE))
			siguiente()
		10:
			if not _battle.sector_esta_liberado():
				return
			_ok("RELOJ lo libera a los 0.5 s del sector (%.2f)" % _battle.tiempo_sector,
				_battle.tiempo_sector >= 0.5 and _battle.tiempo_sector < 0.6)
			_ok("avisa los dos sector_liberado (%s)" % [_liberados],
				_liberados.size() == 2 and _liberados[0] == 0 and _liberados[1] == 1)
			_igual("liberado el ultimo, el limite es todo el campo",
				_battle.limite_x_actual(), 40.0)
			if _con_tope:
				_ok("y la tropa ya no tiene tope (%s)" % [_topes()], _todos_los_topes_en(INF))
			var zombi: Unidad3D = _unidades_vivas("enemigos")[0]
			zombi.recibir_dano(9999.0)
			zombi.derribada_restante = 0.05
			siguiente()
		11:
			if not _battle.esta_terminada():
				return
			_ok("sin enemigos en el ultimo sector se gana",
				_victorias.size() == 1 and _victorias[0])
			terminar()


# --- Pruebas ------------------------------------------------------------------

func _probar_arranque() -> void:
	print("--- al arrancar entra el primer sector ---")
	var sectores: Array[Sector] = _battle._actual.sectores
	_ok("el encuentro tiene dos sectores", _battle.cantidad_sectores() == 2)
	_ok("indice_sector() es 0", _battle.indice_sector() == 0)
	_ok("sector_activo() es el primero", _battle.sector_activo() == sectores[0])
	_ok("sector_iniciado salio una vez, con 0 y su recurso (%d avisos)" % _iniciados.size(),
		_iniciados.size() == 1 and _iniciados[0][0] == 0 and _iniciados[0][1] == sectores[0])
	_igual("despliega los 2 zombis del sector", _enemigos(), 2.0)
	_igual("y la tropa inicial, 3 escuderos", _aliados(), 3.0)
	_ok("todavia sin liberar", not _battle.sector_esta_liberado() and _liberados.is_empty())
	_igual("limite_x_actual() es el fin del sector", _battle.limite_x_actual(), 25.0)
	_ok("los healers caminan hasta 1.5 antes (%s)" % _healer.limites,
		_healer.limites.is_equal_approx(Rect2(1.5, 1.5, 22.0, 7.0)))
	_ok("la camara arranca sin mostrar mas alla (borde en %.2f)" % _borde_camara(),
		_borde_camara() <= 25.0 + 0.001)
	_igual("progreso_nivel() con el healer en x 8", _battle.progreso_nivel(),
		(8.0 - 1.5) / 57.0, 0.001)
	if _mundo != null:
		_ok("el %%Mundo se configura con el campo del encuentro (%s)" % [_mundo.llamadas],
			_mundo.llamadas == [[60.0, 10.0, 1.5, 58.5]])
	else:
		_ok("la escena ya trae su %Mundo: se usa ese y no se mide la llamada", true)

	_con_tope = LIMITE_AVANCE in _primer_aliado()
	if _con_tope:
		_ok("la tropa inicial queda con el tope en 22.4 (%s)" % [_topes()],
			_todos_los_topes_en(25.0 - 2.6))
	else:
		_ok("Unidad3D todavia no tiene limite_avance_x: se salta el tope de la tropa", true)


## Los dos zombis del sector quedan tirados y con mucho reloj: siguen en juego,
## asi que el sector no se libera mientras se prueba el limite, y la tropa no
## tiene con quien pelear y camina hasta el.
func _tirar_zombis() -> void:
	_zombis = _unidades_vivas("enemigos")
	for z in _zombis:
		z.recibir_dano(9999.0)
		z.derribada_restante = 60.0
	if not _con_tope:
		return
	# Cerca del limite, para no esperar la caminata desde x 10.
	var aliados := _unidades_vivas("aliados")
	for i in aliados.size():
		aliados[i].global_position.x = 19.0 + i


func _probar_limite() -> void:
	print("--- el sector frena a la camara, a los healers y a la tropa ---")
	_ok("con los zombis tirados no se libera: siguen en juego",
		not _battle.sector_esta_liberado() and _liberados.is_empty())
	var x := _healer.global_position.x
	_ok("el healer empujado con p1_derecha avanzo (x %.2f)" % x, x > 18.0)
	_ok("y no pasa de 25 - 1.5 (x %.2f)" % x, x <= 25.0 - 1.5 + 0.001)
	_ok("la camara no muestra mas alla del fin (borde en %.2f)" % _borde_camara(),
		_borde_camara() <= 25.0 + 0.001)
	if _con_tope:
		var maximo := _x_maxima("aliados")
		_ok("los escuderos no pasan de 22.4 (el mas adelantado en %.2f)" % maximo,
			maximo <= 25.0 - 2.6 + 0.05 and maximo >= 21.0)
	else:
		_ok("Unidad3D todavia no tiene limite_avance_x: la tropa no se frena (se salta)", true)


func _probar_liberacion() -> void:
	print("--- sin enemigos en juego el sector se libera ---")
	var muertos := 0
	for z in _zombis:
		if not is_instance_valid(z) or not z.esta_viva():
			muertos += 1
	_igual("los dos zombis ya murieron", float(muertos), 2.0)
	_ok("avisa sector_liberado(0), una vez (%s)" % [_liberados],
		_liberados.size() == 1 and _liberados[0] == 0)
	_ok("sector_esta_liberado()", _battle.sector_esta_liberado())
	_ok("sigue en el sector 0 hasta que alguien llegue a la puerta", _battle.indice_sector() == 0)
	_igual("limite_x_actual() pasa al fin del siguiente", _battle.limite_x_actual(), 60.0)
	_ok("los healers ya pueden pasar (%s)" % _healer.limites,
		_healer.limites.is_equal_approx(Rect2(1.5, 1.5, 57.0, 7.0)))
	if _con_tope:
		_ok("y la tropa tambien: su tope pasa a 57.4 (%s)" % [_topes()],
			_todos_los_topes_en(60.0 - 2.6))


func _probar_entrada() -> void:
	print("--- al llegar a la puerta entra el siguiente ---")
	var sectores: Array[Sector] = _battle._actual.sectores
	_ok("indice_sector() es 1", _battle.indice_sector() == 1)
	_ok("sector_iniciado salio con 1 y su recurso",
		_iniciados.size() == 2 and _iniciados[1][0] == 1 and _iniciados[1][1] == sectores[1])
	_ok("arranca sin liberar", not _battle.sector_esta_liberado())
	_igual("tiempo_sector arranca de 0", _battle.tiempo_sector, 0.0, 0.001)
	var zombis := _creadas_de(ENEMIGO)
	var escuderos := _creadas_de(ALIADO)
	_ok("entra 1 zombi, en x >= 40 (%s)" % [_xs(zombis)],
		zombis.size() == 1 and zombis[0]["x"] >= 40.0)
	_ok("y 1 escudero de refuerzo, entre x 28 y 30 (%s)" % [_xs(escuderos)],
		escuderos.size() == 1 and escuderos[0]["x"] >= 28.0 and escuderos[0]["x"] <= 30.0)
	_igual("queda 1 enemigo en juego", _enemigos(), 1.0)
	_igual("el limite sigue en 60", _battle.limite_x_actual(), 60.0)
	if _con_tope and escuderos.size() == 1:
		var refuerzo: Unidad3D = escuderos[0]["unidad"]
		_igual("el refuerzo entra con el tope del sector", refuerzo.get(LIMITE_AVANCE), 57.4, 0.001)


func _probar_oleada_y_progreso() -> void:
	print("--- las oleadas del sector corren con su reloj ---")
	var zombis := _creadas_de(ENEMIGO)
	var de_la_oleada := zombis.filter(func(c: Dictionary) -> bool: return c["x"] >= 50.0)
	_ok("a los 2 s del sector entro el zombi de la oleada, en x 50-52 (%s)" % [_xs(zombis)],
		zombis.size() == 2 and de_la_oleada.size() == 1 and de_la_oleada[0]["x"] <= 52.0)
	_igual("hay 2 enemigos en juego", _enemigos(), 2.0)

	print("--- el progreso sigue al healer ---")
	var x := _healer.global_position.x
	var progreso: float = _battle.progreso_nivel()
	_ok("el healer camino hacia adelante (%.2f -> %.2f)" % [_x_antes, x], x > _x_antes + 3.0)
	_ok("y progreso_nivel() subio (%.3f -> %.3f)" % [_progreso_antes, progreso],
		progreso > _progreso_antes)
	_igual("es la X del healer entre las bases", progreso, (x - 1.5) / 57.0, 0.001)


func _probar_reinicio() -> void:
	print("--- reiniciar vuelve al primer sector ---")
	_iniciados.clear()
	_liberados.clear()
	_battle.reiniciar_encuentro()
	_ok("vuelve al sector 0", _battle.indice_sector() == 0)
	_ok("y lo avisa de nuevo", _iniciados.size() == 1 and _iniciados[0][0] == 0)
	_igual("con sus 2 zombis", _enemigos(), 2.0)
	_igual("y la tropa inicial", _aliados(), 3.0)
	_ok("sin liberar y con el reloj del sector en 0",
		not _battle.sector_esta_liberado() and _battle.tiempo_sector == 0.0)
	_igual("limite_x_actual() vuelve a 25", _battle.limite_x_actual(), 25.0)
	_ok("la camara vuelve a quedar dentro del sector (borde en %.2f)" % _borde_camara(),
		_borde_camara() <= 25.0 + 0.001)
	_igual("el healer vuelve a su inicio", _healer.global_position.x, 8.0)
	if _mundo != null:
		_ok("y el %Mundo se vuelve a configurar", _mundo.llamadas.size() == 2)


func _probar_sin_sectores() -> void:
	print("--- un encuentro sin sectores es el de siempre ---")
	_iniciados.clear()
	_battle.iniciar_encuentro(load(E1))
	_ok("sector_activo() es null", _battle.sector_activo() == null)
	_ok("cantidad_sectores() es 0", _battle.cantidad_sectores() == 0)
	_ok("indice_sector() es -1", _battle.indice_sector() == -1)
	_igual("limite_x_actual() es el ancho del campo",
		_battle.limite_x_actual(), _battle.ancho_campo)
	_igual("que en el encuentro 1 es 30", _battle.ancho_campo, 30.0)
	_ok("no avisa ningun sector", _iniciados.is_empty())
	_ok("la camara sin limite de sector", is_inf(_camara._limite_x))


# --- Encuentros ---------------------------------------------------------------

## 60 m con las bases en 1.5 y 58.5: tres escuderos de arranque y dos sectores.
## El 0 termina en 25 y trae dos zombis; el 1 llega al final del campo con un
## zombi lejos, un escudero de refuerzo y una oleada por reloj que se repite.
## Estatica: captura_sectores.gd saca las fotos de este mismo encuentro.
static func encuentro_por_sectores() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba_sectores"
	enc.semilla = 2468
	enc.sangrado_habilitado = false
	enc.ancho_campo = 60.0
	enc.base_aliada_x = 1.5
	enc.base_enemiga_x = 58.5
	# Detras de la tropa y lejos de los zombis del primer sector.
	enc.healer_inicial = Vector2(8.0, 5.0)
	enc.condicion = Encuentro.Condicion.LLEGAR_A_BASE
	var iniciales: Array[GrupoUnidades] = [_grupo(ESCUDERO, ALIADO, 3, 10.0, 12.0)]
	enc.grupos_iniciales = iniciales

	var s0 := Sector.new()
	s0.titulo = "La entrada"
	s0.x_fin = 25.0
	var grupos_0: Array[GrupoUnidades] = [_grupo(ZOMBIE, ENEMIGO, 2, 18.0, 20.0)]
	s0.grupos = grupos_0
	s0.liberacion = Sector.Liberacion.SIN_ENEMIGOS

	var s1 := Sector.new()
	s1.titulo = "El camino"
	s1.x_fin = 60.0
	var grupos_1: Array[GrupoUnidades] = [_grupo(ZOMBIE, ENEMIGO, 1, 40.0, 42.0)]
	s1.grupos = grupos_1
	var refuerzos: Array[GrupoUnidades] = [_grupo(ESCUDERO, ALIADO, 1, 28.0, 30.0)]
	s1.refuerzos_aliados = refuerzos
	var oleada := OleadaEncuentro.new()
	oleada.disparador = OleadaEncuentro.Disparador.RELOJ
	oleada.valor = 2.0
	oleada.repetir = true
	var de_la_oleada: Array[GrupoUnidades] = [_grupo(ZOMBIE, ENEMIGO, 1, 50.0, 52.0)]
	oleada.grupos = de_la_oleada
	var oleadas: Array[OleadaEncuentro] = [oleada]
	s1.oleadas = oleadas
	s1.liberacion = Sector.Liberacion.RELOJ
	s1.valor_liberacion = 100.0

	var sectores: Array[Sector] = [s0, s1]
	enc.sectores = sectores
	return enc


## 40 m, se gana dejando el campo sin enemigos. El primer sector no trae
## ninguno y se libera cuando el frente avanza hasta x 14; el ultimo trae un
## zombi, prende los emergentes y se libera por reloj.
static func _encuentro_limpiar() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba_sectores_limpiar"
	enc.semilla = 1357
	enc.sangrado_habilitado = false
	enc.ancho_campo = 40.0
	enc.base_aliada_x = 1.5
	enc.base_enemiga_x = 38.5
	enc.healer_inicial = Vector2(8.0, 5.0)
	enc.condicion = Encuentro.Condicion.LIMPIAR_ENEMIGOS
	var iniciales: Array[GrupoUnidades] = [_grupo(ESCUDERO, ALIADO, 2, 10.0, 12.0)]
	enc.grupos_iniciales = iniciales

	var s0 := Sector.new()
	s0.x_fin = 20.0
	s0.liberacion = Sector.Liberacion.FRENTE_PASA_X
	s0.valor_liberacion = 14.0

	var s1 := Sector.new()
	s1.x_fin = 40.0
	var grupos_1: Array[GrupoUnidades] = [_grupo(ZOMBIE, ENEMIGO, 1, 30.0, 30.0)]
	s1.grupos = grupos_1
	s1.liberacion = Sector.Liberacion.RELOJ
	s1.valor_liberacion = 0.5
	# El primero sale a los 14 s de entrar: no llega a cruzarse con la prueba.
	s1.emergentes = true

	var sectores: Array[Sector] = [s0, s1]
	enc.sectores = sectores
	return enc


static func _grupo(ruta_tipo: String, bando: Unidad3D.Bando, cantidad: int, x_min: float,
		x_max: float) -> GrupoUnidades:
	var g := GrupoUnidades.new()
	g.tipo = load(ruta_tipo)
	g.bando = bando
	g.cantidad = cantidad
	g.x_min = x_min
	g.x_max = x_max
	g.z_min = 2.0
	g.z_max = 8.0
	return g


# --- Ayudas -------------------------------------------------------------------

## Aprieta o suelta una accion por Input, como un teclado: el healer la lee con
## Input.get_vector en su tick.
func _mantener(nombre: StringName, apretada: bool) -> void:
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = apretada
	Input.parse_input_event(evento)
	Input.flush_buffered_events()


## Hasta donde se ve a la derecha, en el plano del medio del campo.
func _borde_camara() -> float:
	return _camara.x_actual() + _camara.mitad_visible()


func _unidades_vivas(grupo: String) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	for u in get_nodes_in_group(grupo):
		if u is Unidad3D and u.esta_viva() and not u.is_queued_for_deletion():
			lista.append(u)
	return lista


func _enemigos() -> float:
	return float(_unidades_vivas("enemigos").size())


func _aliados() -> float:
	return float(_unidades_vivas("aliados").size())


func _primer_aliado() -> Unidad3D:
	var aliados := _unidades_vivas("aliados")
	return aliados[0] if not aliados.is_empty() else null


func _x_maxima(grupo: String) -> float:
	var maximo := -INF
	for u in _unidades_vivas(grupo):
		maximo = maxf(maximo, u.global_position.x)
	return maximo


## El tope de avance de cada aliado en juego.
func _topes() -> Array[float]:
	var topes: Array[float] = []
	for u in _unidades_vivas("aliados"):
		topes.append(u.get(LIMITE_AVANCE))
	return topes


func _todos_los_topes_en(x: float) -> bool:
	var topes := _topes()
	if topes.is_empty():
		return false
	for tope in topes:
		if not is_equal_approx(tope, x):
			return false
	return true


func _creadas_de(bando: Unidad3D.Bando) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for c in _creadas:
		if c["bando"] == bando:
			lista.append(c)
	return lista


func _xs(creadas: Array[Dictionary]) -> String:
	var xs := PackedStringArray()
	for c in creadas:
		xs.append("%.2f" % c["x"])
	return ", ".join(xs)
