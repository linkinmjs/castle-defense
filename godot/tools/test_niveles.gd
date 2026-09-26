extends PruebaBase
## Los tres niveles largos (niveles.tres) como datos y sobre la escena real.
##
## Primero el recurso: que esten los tres, en orden, con sus sectores bien
## armados (los x_fin crecen, los enemigos de cada sector arrancan a 9 m o mas
## de la puerta del anterior y las oleadas nacen fuera de cuadro), con los
## movimientos que enseña cada uno, el oso en el puente y el jefe al final.
## Despues cada nivel sobre battle3d.tscn: entra al primer sector con lo que
## dice el recurso, juega unos segundos sin romperse y, forzando la entrada a
## los otros dos, la batalla no avisa que se vea aparecer a nadie. Al final,
## la serie que anota el menu (Navegacion), los emergentes sin osos ni jefes y
## que la viñeta no se cree sin pantalla.

const RUTA_NIVELES := "res://resources/encuentros/niveles.tres"
const IDS: Array[StringName] = [&"n1_el_camino", &"n2_el_puente", &"n3_las_puertas"]
## Lo que se juega de cada nivel antes de mirar si algo se rompio. El primero
## un poco mas: es el que tiene que llegar a la primera pelea.
const SEGUNDOS_JUGADOS: Array[float] = [5.0, 3.0, 3.0]
## A cuanto de la puerta del sector anterior tienen que arrancar sus enemigos.
const DISTANCIA_ENTRADA := 9.0
## Cuanto mas alla del x_fin de su sector nace una oleada, como minimo.
const ENTRADA_OLEADA := 3.0
const BRUTO := "res://resources/soldados/bruto.tres"
const DEMONIO := "res://resources/soldados/demonio.tres"
const ZOMBIE := "res://resources/soldados/zombie.tres"
const ESCUDERO := "res://resources/soldados/escudero.tres"
const ALIADO := Unidad3D.Bando.ALIADO
const ENEMIGO := Unidad3D.Bando.ENEMIGO


## Anota los errores que pasan mientras corre la batalla: la suite falla por
## codigo de salida, y un SCRIPT ERROR en medio de un tick no lo cambia.
class Registro extends Logger:
	var errores: PackedStringArray = []
	var avisos: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(funcion: String, archivo: String, linea: int, codigo: String,
			razon: String, _editor: bool, tipo: int, _pila: Array[ScriptBacktrace]) -> void:
		var texto := "%s (%s:%d %s)" % [razon if not razon.is_empty() else codigo, archivo, linea, funcion]
		_mutex.lock()
		if tipo == ERROR_TYPE_WARNING:
			avisos.append(texto)
		else:
			errores.append(texto)
		_mutex.unlock()

	func _log_message(_mensaje: String, _error: bool) -> void:
		pass

	func vaciar() -> void:
		_mutex.lock()
		errores.clear()
		avisos.clear()
		_mutex.unlock()


var _niveles: Campana
var _battle: Node
var _registro := Registro.new()
## Cual de los tres se esta jugando.
var _nivel := 0


func preparar() -> void:
	OS.add_logger(_registro)
	_niveles = load(RUTA_NIVELES)
	_probar_recurso()
	_probar_navegacion_sin_anotar()
	_armar_batalla(_niveles.encuentro_en(0) if _niveles != null else null)


## 0 y 1 se repiten para cada nivel: arranque y unos segundos de juego. En 2,
## con la batalla anterior ya afuera, se arma la del siguiente o se pasa a la
## navegacion.
func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 3:
				return
			_probar_arranque(_nivel)
			if _nivel == 0:
				_probar_sin_vineta()
			_registro.vaciar()
			siguiente()
		1:
			if _ticks < int(SEGUNDOS_JUGADOS[_nivel] * Engine.physics_ticks_per_second):
				return
			_probar_juego(_nivel)
			_probar_demas_sectores(_nivel)
			_battle.queue_free()
			_battle = null
			_nivel += 1
			siguiente()
		2:
			if _nivel < IDS.size():
				_armar_batalla(_niveles.encuentro_en(_nivel))
				_fase = 0
				_ticks = 0
				return
			_probar_navegacion_anotada()
			siguiente()
		3:
			if _ticks < 3:
				return
			_probar_campana_cargada()
			_probar_emergentes_sin_osos()
			OS.remove_logger(_registro)
			terminar()


# --- El recurso ---------------------------------------------------------------

func _probar_recurso() -> void:
	print("--- niveles.tres ---")
	_ok("existe y es una Campana", _niveles != null)
	if _niveles == null:
		return
	_igual("tiene tres encuentros", _niveles.encuentros.size(), 3.0)
	for i in mini(_niveles.encuentros.size(), IDS.size()):
		var enc: Encuentro = _niveles.encuentros[i]
		_ok("el %d es %s (%s)" % [i + 1, IDS[i], enc.id if enc != null else "null"],
			enc != null and enc.id == IDS[i])
		if enc != null:
			_probar_sectores(enc)

	var n1: Encuentro = _niveles.encuentro_en(0)
	var n2: Encuentro = _niveles.encuentro_en(1)
	var n3: Encuentro = _niveles.encuentro_en(2)
	if n1 == null or n2 == null or n3 == null:
		_ok("estan los tres para mirarlos de cerca", false)
		return

	print("--- lo que enseña cada uno ---")
	_igual("N1 equipa 4 movimientos", n1.movimientos.size(), 4.0)
	_igual("N2 equipa 7 movimientos", n2.movimientos.size(), 7.0)
	_ok("N3 no restringe: la lista vacia equipa todos", n3.movimientos.is_empty())
	_ok("todos los movimientos existen", _movimientos_validos(n1) and _movimientos_validos(n2))
	_ok("N1 enseña Toque, Vendaje, Plegaria e Impulso (%s)" % _nombres_movimientos(n1),
		_nombres_movimientos(n1) == "Toque, Vendaje, Plegaria, Impulso")
	_ok("N2 suma Bendicion, Reanimar y la Caida (%s)" % _nombres_movimientos(n2),
		_nombres_movimientos(n2) == "Toque, Vendaje, Plegaria, Impulso, Bendicion, Reanimar, Caida sanadora")
	_ok("N1 y N2 se ganan llegando a la base",
		n1.condicion == Encuentro.Condicion.LLEGAR_A_BASE
		and n2.condicion == Encuentro.Condicion.LLEGAR_A_BASE)
	_ok("N3 se gana limpiando el campo",
		n3.condicion == Encuentro.Condicion.LIMPIAR_ENEMIGOS)
	_ok("en N2 hay algun oso", _tiene_tipo(n2, func(t: TipoSoldado) -> bool:
		return t.resource_path == BRUTO))
	var ultimo: Sector = n3.sectores[n3.sectores.size() - 1] if not n3.sectores.is_empty() else null
	_ok("el ultimo sector de N3 trae al jefe", ultimo != null and ultimo.grupos.any(
		func(g: GrupoUnidades) -> bool: return g.tipo != null and g.tipo.es_jefe))
	_ok("bajas generosas (4, 4, 5)", n1.bajas_aliadas_maximas == 4
		and n2.bajas_aliadas_maximas == 4 and n3.bajas_aliadas_maximas == 5)
	_ok("sin derrota por frente", n1.frente_derrota_x < 0.0 and n2.frente_derrota_x < 0.0
		and n3.frente_derrota_x < 0.0)
	_ok("semillas fijas", n1.semilla != 0 and n2.semilla != 0 and n3.semilla != 0)
	_ok("N1 lleva sangrado bajo y lo plantea en el ultimo sector con sangrado_inicial",
		n1.sangrado_habilitado and n1.probabilidad_sangrado <= 0.2
		and n1.sectores[2].refuerzos_aliados.any(
			func(g: GrupoUnidades) -> bool: return g.sangrado_inicial > 0.0))
	_ok("el puente trae caidos para reanimar y prende los emergentes",
		n2.sectores[1].emergentes and n2.sectores[1].refuerzos_aliados.any(
			func(g: GrupoUnidades) -> bool: return g.derribada_inicial))


## Los x_fin crecen y el ultimo no se pasa del campo. Los enemigos de cada
## sector, entre la puerta del anterior mas 9 m y su propio x_fin (el primero,
## desde el arranque del campo). Las oleadas, fuera de cuadro: 3 m o mas pasado
## el x_fin de su sector. Y todo dentro de la profundidad.
func _probar_sectores(enc: Encuentro) -> void:
	_igual("%s: tres sectores" % enc.id, enc.sectores.size(), 3.0)
	var fin_anterior := 0.0
	var crecen := true
	var enemigos_en_su_tramo := true
	var oleadas_fuera := true
	var en_profundidad := true
	var detalle := PackedStringArray()
	for sector in enc.sectores:
		crecen = crecen and sector.x_fin > fin_anterior
		for g in sector.grupos:
			if g.bando != ENEMIGO:
				continue
			if g.x_min < fin_anterior + DISTANCIA_ENTRADA or g.x_max > sector.x_fin:
				enemigos_en_su_tramo = false
				detalle.append("%s: %.1f-%.1f fuera de [%.1f, %.1f]" % [
					sector.titulo, g.x_min, g.x_max, fin_anterior + DISTANCIA_ENTRADA, sector.x_fin])
		for oleada in sector.oleadas:
			for g in oleada.grupos:
				if g.bando == ENEMIGO and g.x_min < sector.x_fin + ENTRADA_OLEADA:
					oleadas_fuera = false
					detalle.append("%s: oleada en %.1f" % [sector.titulo, g.x_min])
		for g in _grupos_de(sector):
			en_profundidad = en_profundidad and g.z_min >= 1.0 \
				and g.z_max <= enc.profundidad_campo - 1.0
		fin_anterior = sector.x_fin
	_ok("%s: los x_fin crecen" % enc.id, crecen)
	_ok("%s: el ultimo x_fin (%.1f) no pasa del campo (%.1f)" % [enc.id, fin_anterior, enc.ancho_campo],
		fin_anterior <= enc.ancho_campo)
	_ok("%s: los enemigos de cada sector arrancan a 9 m o mas de la puerta anterior %s"
		% [enc.id, detalle], enemigos_en_su_tramo)
	_ok("%s: las oleadas nacen fuera de cuadro" % enc.id, oleadas_fuera)
	_ok("%s: todos se despliegan dentro de la profundidad (%.0f m)" % [enc.id, enc.profundidad_campo],
		en_profundidad)


# --- Sobre la escena ----------------------------------------------------------

func _armar_batalla(enc: Encuentro) -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	if enc != null:
		_battle.encuentro = enc
	root.add_child(_battle)


## Entra al primer sector con los enemigos del sector y la tropa inicial.
func _probar_arranque(i: int) -> void:
	var enc: Encuentro = _niveles.encuentro_en(i)
	print("--- %s: el arranque ---" % enc.id)
	_ok("juega el nivel pedido", _battle._actual == enc)
	_ok("entra al sector 0 (%s)" % _battle.sector_activo().titulo if _battle.sector_activo() else "-",
		_battle.indice_sector() == 0)
	_igual("con los enemigos del sector", _contar("enemigos"),
		float(_cantidad(enc.sectores[0].grupos, ENEMIGO)))
	_igual("y la tropa inicial", _contar("aliados"),
		float(_cantidad(enc.grupos_iniciales, ALIADO)))
	if i == 0:
		_igual("N1: 5 enemigos", _contar("enemigos"), 5.0)
		_igual("N1: tropa de 5", _contar("aliados"), 5.0)
	_igual("el limite es el fin del primer sector", _battle.limite_x_actual(),
		enc.sectores[0].x_fin)
	var healer: Healer3D = _battle.get_node("%Healer")
	_igual("el healer arranca donde dice el recurso", healer.global_position.x,
		enc.healer_inicial.x, 0.01)


## Unos segundos de juego: nadie se murio de nada raro y la batalla no se
## rompio ni termino.
func _probar_juego(i: int) -> void:
	var enc: Encuentro = _niveles.encuentro_en(i)
	print("--- %s: %.0f s de juego ---" % [enc.id, SEGUNDOS_JUGADOS[i]])
	_ok("no termino", not _battle.esta_terminada())
	_igual("no murio ningun aliado", float(_battle.bajas_aliadas()), 0.0)
	_ok("todas las unidades tienen su tipo", _todas_con_tipo())
	_ok("sin errores (%s)" % [_registro.errores], _registro.errores.is_empty())


## Entra a la fuerza a los otros dos sectores: cada uno despliega lo suyo y la
## batalla no avisa que se vea aparecer a nadie.
func _probar_demas_sectores(i: int) -> void:
	var enc: Encuentro = _niveles.encuentro_en(i)
	_registro.vaciar()
	for s in range(1, enc.sectores.size()):
		var antes := _contar("enemigos")
		var aliados_antes := _contar("aliados")
		_battle._entrar_sector(s)
		var sector: Sector = enc.sectores[s]
		_igual("%s: entra con sus enemigos" % sector.titulo, _contar("enemigos") - antes,
			float(_cantidad(sector.grupos, ENEMIGO)))
		_igual("%s: y sus refuerzos" % sector.titulo, _contar("aliados") - aliados_antes,
			float(_cantidad(sector.refuerzos_aliados, ALIADO)))
	var vistos := Array(_registro.avisos).filter(func(t: String) -> bool: return t.contains("aparecer"))
	_ok("%s: la batalla no avisa enemigos a la vista (%s)" % [enc.id, vistos], vistos.is_empty())
	_ok("%s: sin errores al entrar (%s)" % [enc.id, _registro.errores], _registro.errores.is_empty())


func _probar_sin_vineta() -> void:
	print("--- sin pantalla no hay viñeta ---")
	_ok("nadie en el grupo de la viñeta", get_nodes_in_group(Vineta.GRUPO).is_empty())
	_ok("ni entre los hijos de la batalla",
		not _battle.get_children().any(func(n: Node) -> bool: return n is Vineta))


# --- Navegacion ---------------------------------------------------------------

func _probar_navegacion_sin_anotar() -> void:
	print("--- la serie que pide el menu ---")
	_ok("sin anotacion, las lecciones",
		Navegacion.campana_pedida(self) == Navegacion.RUTA_LECCIONES)
	_ok("las lecciones son campana.tres",
		Navegacion.RUTA_LECCIONES == "res://resources/encuentros/campana.tres")
	_ok("y los niveles, niveles.tres", Navegacion.RUTA_NIVELES == RUTA_NIVELES)


func _probar_navegacion_anotada() -> void:
	Navegacion.pedir_campana(self, Navegacion.RUTA_NIVELES)
	_ok("pedir_campana la anota", Navegacion.campana_pedida(self) == Navegacion.RUTA_NIVELES)
	# Sin encuentro ni campania puestos: la carga la batalla sola en su _ready.
	_armar_batalla(null)


func _probar_campana_cargada() -> void:
	_ok("la batalla carga los niveles", _battle.campana != null
		and _battle.campana.resource_path == RUTA_NIVELES)
	_igual("tres encuentros", _battle.campana.encuentros.size() if _battle.campana else 0.0, 3.0)
	_ok("y arranca por n1_el_camino", _battle._actual != null
		and _battle._actual.id == &"n1_el_camino")
	Navegacion.pedir_campana(self, "")
	_ok("pedir_campana vacia vuelve a las lecciones",
		Navegacion.campana_pedida(self) == Navegacion.RUTA_LECCIONES and not has_meta(Navegacion.CAMPANA_PEDIDA))


## Los emergentes no salen como osos ni como jefes: saltan esos tipos, y si el
## tramo no trae otro no marcan el suelo.
func _probar_emergentes_sin_osos() -> void:
	print("--- los emergentes no son osos ni jefes ---")
	_battle.iniciar_encuentro(_encuentro_con([BRUTO]))
	_ok("con un oso como unico enemigo, _tipo_enemigo() es null", _battle._tipo_enemigo() == null)
	var marcas_antes := _marcas()
	_battle._lanzar_emergentes()
	_igual("y no marca el suelo", float(_marcas() - marcas_antes), 0.0)

	_battle.iniciar_encuentro(_encuentro_con([DEMONIO]))
	_ok("con el jefe solo, tampoco", _battle._tipo_enemigo() == null)

	_battle.iniciar_encuentro(_encuentro_con([BRUTO, ZOMBIE]))
	_ok("con un oso y un zombi, salen zombis", _battle._tipo_enemigo() == load(ZOMBIE))
	marcas_antes = _marcas()
	_battle._lanzar_emergentes()
	_igual("y ahi si marca el suelo", float(_marcas() - marcas_antes), float(_battle.emergentes_por_tanda))


## Un campo de 40 m con un solo sector que prende los emergentes y trae un
## enemigo de cada tipo pedido, lejos de la tropa.
func _encuentro_con(tipos: Array) -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba_emergentes"
	enc.semilla = 4242
	enc.ancho_campo = 40.0
	enc.base_enemiga_x = 38.5
	enc.healer_inicial = Vector2(8.0, 5.0)
	enc.sangrado_habilitado = false
	var tropa: Array[GrupoUnidades] = [_grupo(ESCUDERO, ALIADO, 2, 10.0, 11.0)]
	enc.grupos_iniciales = tropa
	var sector := Sector.new()
	sector.x_fin = 40.0
	sector.emergentes = true
	var grupos: Array[GrupoUnidades] = []
	for ruta: String in tipos:
		grupos.append(_grupo(ruta, ENEMIGO, 1, 30.0, 32.0))
	sector.grupos = grupos
	var sectores: Array[Sector] = [sector]
	enc.sectores = sectores
	return enc


# --- Ayudas -------------------------------------------------------------------

func _grupo(ruta: String, bando: Unidad3D.Bando, cantidad: int, x_min: float,
		x_max: float) -> GrupoUnidades:
	var g := GrupoUnidades.new()
	g.tipo = load(ruta)
	g.bando = bando
	g.cantidad = cantidad
	g.x_min = x_min
	g.x_max = x_max
	g.z_min = 2.0
	g.z_max = 8.0
	return g


func _grupos_de(sector: Sector) -> Array[GrupoUnidades]:
	var todos: Array[GrupoUnidades] = []
	todos.append_array(sector.grupos)
	todos.append_array(sector.refuerzos_aliados)
	for oleada in sector.oleadas:
		todos.append_array(oleada.grupos)
	return todos


func _cantidad(grupos: Array[GrupoUnidades], bando: Unidad3D.Bando) -> int:
	var total := 0
	for g in grupos:
		if g != null and g.bando == bando:
			total += g.cantidad
	return total


func _tiene_tipo(enc: Encuentro, cumple: Callable) -> bool:
	var grupos: Array[GrupoUnidades] = enc.grupos_iniciales.duplicate()
	for sector in enc.sectores:
		grupos.append_array(_grupos_de(sector))
	return grupos.any(func(g: GrupoUnidades) -> bool: return g.tipo != null and cumple.call(g.tipo))


func _movimientos_validos(enc: Encuentro) -> bool:
	for m in enc.movimientos:
		if m == null or m.resource_path.is_empty() or not ResourceLoader.exists(m.resource_path):
			return false
	return true


## Los nombres en orden, separados por coma: se comparan como texto.
func _nombres_movimientos(enc: Encuentro) -> String:
	var nombres := PackedStringArray()
	for m in enc.movimientos:
		nombres.append(m.nombre if m != null else "null")
	return ", ".join(nombres)


## En juego: vivos (tirados incluidos) y no por borrarse.
func _contar(grupo: String) -> float:
	var total := 0
	for u in get_nodes_in_group(grupo):
		if u is Unidad3D and u.esta_viva() and not u.is_queued_for_deletion():
			total += 1
	return float(total)


func _todas_con_tipo() -> bool:
	for grupo in ["aliados", "enemigos"]:
		for u in get_nodes_in_group(grupo):
			if u is Unidad3D and u.tipo == null:
				return false
	return true


func _marcas() -> int:
	var total := 0
	for hijo in _battle.get_children():
		if hijo is Emergente3D and not hijo.is_queued_for_deletion():
			total += 1
	return total
