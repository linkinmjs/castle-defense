extends PruebaBase
## Bruto y jefe: golpe telegrafiado con marca en el suelo, barrido que se
## salta, golpe en area, golpe perdido al aturdirlo o derribarlo, los dos
## ataques del jefe con su semilla, tamano por tipo y limite de avance. Sobre
## ticks de fisica reales.
##
## Los tiempos se miden con las senales del golpe y no contando frames: el
## anuncio y la caida dicen en que tick paso cada cosa.

const DT := 1.0 / 60.0
const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")
const ESCENA_HEALER := preload("res://scenes/3d/healer3d.tscn")
const BRUTO := preload("res://resources/soldados/bruto.tres")
const DEMONIO := preload("res://resources/soldados/demonio.tres")
const ESCUDERO := preload("res://resources/soldados/escudero.tres")
const LANCERO := preload("res://resources/soldados/lancero.tres")
const ZOMBIE := preload("res://resources/soldados/zombie.tres")
## Donde espera el healer cuando la prueba no lo usa: lejos de todos, para que
## ningun enemigo lo elija de objetivo.
const HEALER_APARTE := Vector3(1.0, 0.0, 9.5)
## Frente al bruto, a 1.2 m: dentro de su alcance desde el primer tick.
const PUNTO := Vector3(10.0, 0.0, 5.0)
const LUGAR_BRUTO := Vector3(11.2, 0.0, 5.0)

var _contenedor: Node3D
var _healer: Healer3D
var _bruto: Unidad3D
var _escudero: Unidad3D
var _andador: Unidad3D
var _zombi: Unidad3D
## Nombre -> unidad, para las pruebas con varios muñecos.
var _munecos: Dictionary = {}
var _demonios: Array[Unidad3D] = []
## Lo que avisan las senales, en orden.
var _anuncios: Array[Dictionary] = []
var _caidas: Array[Dictionary] = []
var _posicion: Vector3
var _dano_temprano := false
var _se_movio := false
var _aturdido_ya := false


func preparar() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = ESCENA_HEALER.instantiate()
	_healer.position = HEALER_APARTE
	_contenedor.add_child(_healer)


func fase(numero: int) -> void:
	match numero:
		0:
			_tamanos_crear()
		1:
			_tamanos_revisar()
		2:
			_escudero_crear()
		3:
			_escudero_esperar()
		4:
			_salto_crear()
		5:
			_salto_esperar()
		6:
			_area_crear()
		7:
			_area_esperar()
		8:
			_frena_crear()
		9:
			_frena_aturdir()
		10:
			_frena_esperar()
		11:
			_pierde_golpe_crear()
		12:
			_pierde_golpe_esperar()
		13:
			_derribado_crear()
		14:
			_derribado_esperar()
		15:
			_demonio_crear()
		16:
			_demonio_esperar()
		17:
			_limite_crear()
		18:
			_limite_llega()
		19:
			_limite_objetivo_lejos()
		20:
			_limite_enemigo()


# --- Tamano por tipo ---------------------------------------------------------

func _tamanos_crear() -> void:
	print("--- el tamano sale del tipo ---")
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, Vector3(20, 0, 2), false)
	_demonios.clear()
	_demonios.append(_unidad(Unidad3D.Bando.ENEMIGO, DEMONIO, Vector3(24, 0, 2), false))
	_escudero = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, Vector3(4, 0, 2), false)
	siguiente()


func _tamanos_revisar() -> void:
	var demonio := _demonios[0]
	# En milimetros por pixel, para que la salida diga algo con dos decimales.
	_igual("pixel del bruto: 2.2 m sobre 31 px (mm)", _bruto._sprite.pixel_size * 1000.0,
		2200.0 / 31.0)
	_ok("sus pies en el suelo con la hoja de 40 px", _bruto._sprite.offset == Vector2(0, 20))
	_igual("pixel del demonio: 3.2 m sobre 52 px (mm)", demonio._sprite.pixel_size * 1000.0,
		3200.0 / 52.0)
	_ok("sus pies en el suelo con la hoja de 96 px", demonio._sprite.offset == Vector2(0, 48))
	_igual("el escudero sigue como la escena (mm)", _escudero._sprite.pixel_size * 1000.0,
		2000.0 / 68.0)
	_ok("con su offset de siempre", _escudero._sprite.offset == Vector2(0, 64))

	var capsula_bruto := _bruto._colision.shape as CapsuleShape3D
	var capsula_demonio := demonio._colision.shape as CapsuleShape3D
	var capsula_escudero := _escudero._colision.shape as CapsuleShape3D
	_igual("capsula del bruto", capsula_bruto.radius, 0.5)
	_igual("capsula del demonio", capsula_demonio.radius, 0.7)
	_igual("y alta como el demonio", capsula_demonio.height, 3.2 * 0.85)
	_igual("la del escudero no cambia", capsula_escudero.radius, 0.32)
	_ok("porque la del bruto es otra forma y no la compartida",
		capsula_bruto != capsula_escudero)

	_ok("la barra del bruto va a 2.4 m",
		_bruto.punto_cabeza().is_equal_approx(_bruto.global_position + Vector3(0, 2.4, 0)))
	_ok("la del demonio a 3.5 m",
		demonio.punto_cabeza().is_equal_approx(demonio.global_position + Vector3(0, 3.5, 0)))
	_ok("la del escudero donde siempre",
		_escudero.punto_cabeza().is_equal_approx(_escudero.global_position + Vector3(0, 2.1, 0)))
	_ok("el demonio es jefe y el bruto no", demonio.es_jefe and not _bruto.es_jefe)
	_ok("sin sector no hay limite de avance", is_inf(_escudero.limite_avance_x))
	_limpiar()
	siguiente()


# --- Bruto contra un escudero --------------------------------------------------

func _escudero_crear() -> void:
	print("--- bruto contra escudero: se ve venir ---")
	_escudero = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, PUNTO, false)
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, LUGAR_BRUTO)
	_posicion = LUGAR_BRUTO
	_dano_temprano = false
	siguiente()


func _escudero_esperar() -> void:
	if _anuncios.is_empty():
		return
	var anuncio: Dictionary = _anuncios[0]
	if _caidas.is_empty():
		if _escudero.vida < _escudero.vida_maxima - 0.001:
			_dano_temprano = true
		if _ticks - int(anuncio["tick"]) == 40:
			_escudero_a_mitad(anuncio)
		return

	var caida: Dictionary = _caidas[0]
	_igual("el golpe cae a los 1.2 s de empezar",
		(int(caida["tick"]) - int(anuncio["tick"])) * DT, 1.2, DT + 0.001)
	_ok("antes no hace dano", not _dano_temprano)
	_igual("y cuando cae pega 34 menos el escudo", _escudero.vida_maxima - _escudero.vida,
		34.0 * (1.0 - 0.25))
	_ok("la marca ya no esta despues de conectar", _sin_marca(anuncio["marca"]))
	_igual("la animacion vuelve a su ritmo", _bruto._sprite.speed_scale, 1.0)
	_ok("avisa que cayo sobre uno", int(caida["alcanzados"]) == 1)
	_limpiar()
	siguiente()


func _escudero_a_mitad(anuncio: Dictionary) -> void:
	_ok("la marca aparece al iniciar el golpe", not _sin_marca(anuncio["marca"]))
	if _sin_marca(anuncio["marca"]):
		return
	var marca: MarcaTelegrafo = anuncio["marca"]
	_ok("en el suelo, donde estaba el objetivo",
		marca.global_position.is_equal_approx(PUNTO) and marca.get_parent() == _contenedor)
	_igual("del radio del golpe", marca.radio, 1.2)
	_igual("y dura lo que dura el aviso", marca.duracion, 1.2)
	_ok("crece mientras tanto (%.2f)" % marca.progreso(),
		marca.progreso() > 0.4 and marca.progreso() < 0.8)
	_ok("el bruto no se mueve mientras carga", _bruto.global_position.is_equal_approx(_posicion))
	_ok("carga con la animacion de ataque", _bruto._sprite.animation == &"attack")
	# 6 cuadros a 12 fps duran 0.5 s: para durar 1.2 s va a 0.5 / 1.2.
	_igual("estirada a lo que dura el aviso", _bruto._sprite.speed_scale, 0.5 / 1.2, 0.001)

	_bruto.recibir_dano(5.0)
	_ok("un golpe de la linea no lo interrumpe", _bruto._sprite.animation == &"attack"
		and _bruto._hurt_restante <= 0.0)
	_ok("solo destella", _bruto._flash > 0.0)


# --- Barrido: el healer lo salta -----------------------------------------------

func _salto_crear() -> void:
	print("--- barrido: el healer en el aire lo esquiva ---")
	_healer.reiniciar(PUNTO)
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, LUGAR_BRUTO)
	siguiente()


func _salto_esperar() -> void:
	if _anuncios.is_empty():
		return
	var desde := _ticks - int(_anuncios[0]["tick"])
	# El salto dura ~0.63 s: saltando a 0.83 s del inicio sigue arriba a 1.2 s.
	if desde == 50 and _caidas.is_empty():
		_ok("el bruto apunta al healer", _bruto._objetivo == _healer)
		_healer.saltar()
	if _caidas.size() < 2:
		return

	var arriba: Dictionary = _caidas[0]
	var abajo: Dictionary = _caidas[1]
	_ok("el healer estaba en el aire cuando cayo el primero", bool(arriba["healer_en_el_aire"]))
	_igual("y no recibio dano", float(arriba["healer_vida"]), _healer.vida_maxima)
	_ok("el golpe no alcanzo a nadie", int(arriba["alcanzados"]) == 0)
	_ok("en el segundo estaba en el suelo", not bool(abajo["healer_en_el_aire"]))
	_igual("y ese si le pego", float(abajo["healer_vida"]), _healer.vida_maxima - 34.0)
	_limpiar()
	_healer.reiniciar(HEALER_APARTE)
	siguiente()


# --- Area: pega donde cae, no a quien apuntaba -----------------------------------

func _area_crear() -> void:
	print("--- area: pega donde cayo el golpe ---")
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, LUGAR_BRUTO)
	# Todos lanceros, sin escudo: el que recibe pierde 34 justos.
	_munecos = {
		"objetivo": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO, false),
		"costado": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO + Vector3(0, 0, 0.8), false),
		"atras": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO + Vector3(-0.8, 0, 0), false),
		"afuera": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO + Vector3(0, 0, 2.0), false),
		"sale": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO + Vector3(0, 0, -0.7), false),
		"entra": _unidad(Unidad3D.Bando.ALIADO, LANCERO, PUNTO + Vector3(0, 0, 3.5), false),
	}
	siguiente()


func _area_esperar() -> void:
	if _anuncios.is_empty():
		return
	if _ticks - int(_anuncios[0]["tick"]) == 10:
		_ok("apunta al que tiene enfrente", _bruto._objetivo == _munecos["objetivo"])
		# Uno se sale de la marca y otro se mete, con el golpe ya cargando.
		(_munecos["sale"] as Unidad3D).global_position = PUNTO + Vector3(0, 0, -2.5)
		(_munecos["entra"] as Unidad3D).global_position = PUNTO + Vector3(0.6, 0, -0.7)
	if _caidas.is_empty():
		return

	_igual("pega al objetivo", _perdio("objetivo"), 34.0)
	_igual("y a uno a 0.8 m de costado", _perdio("costado"), 34.0)
	_igual("y a otro a 0.8 m por detras", _perdio("atras"), 34.0)
	_igual("no al que esta a 2 m", _perdio("afuera"), 0.0)
	_igual("el que salio de la marca se salva", _perdio("sale"), 0.0)
	_igual("el que entro la recibe", _perdio("entra"), 34.0)
	_ok("avisa que cayo sobre cuatro", int(_caidas[0]["alcanzados"]) == 4)
	_limpiar()
	siguiente()


func _perdio(nombre: String) -> float:
	var unidad: Unidad3D = _munecos[nombre]
	return unidad.vida_maxima - unidad.vida


# --- Aturdido ---------------------------------------------------------------------

func _frena_crear() -> void:
	print("--- aturdido: frena ---")
	# Sin enemigos camina derecho hacia el frente.
	_andador = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, Vector3(5, 0, 3))
	siguiente()


func _frena_aturdir() -> void:
	if _ticks < 20:
		return
	_ok("antes de aturdirlo camina", _andador.velocity.x > 0.5)
	_andador.aturdir(0.5)
	_ok("aturdido", _andador.esta_aturdida())
	_ok("muestra el golpe", _andador._sprite.animation == &"hurt")
	_posicion = _andador.global_position
	_se_movio = false
	siguiente()


func _frena_esperar() -> void:
	if _ticks <= 29:
		if not _andador.global_position.is_equal_approx(_posicion):
			_se_movio = true
		if _ticks == 29:
			_ok("no se movio en medio segundo", not _se_movio)
			_ok("y sigue aturdido", _andador.esta_aturdida())
		return
	if _ticks < 45:
		return
	_ok("se le paso", not _andador.esta_aturdida())
	_ok("y despues sigue caminando", _andador.global_position.x > _posicion.x + 0.05)
	_limpiar()
	siguiente()


func _pierde_golpe_crear() -> void:
	print("--- aturdido: pierde el golpe que cargaba ---")
	_escudero = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, PUNTO, false)
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, LUGAR_BRUTO)
	_aturdido_ya = false
	siguiente()


func _pierde_golpe_esperar() -> void:
	if _anuncios.is_empty():
		return
	var desde := _ticks - int(_anuncios[0]["tick"])
	if desde == 36 and not _aturdido_ya:
		_aturdido_ya = true
		_bruto.aturdir(0.5)
		_ok("la marca se va al aturdirlo", _sin_marca(_anuncios[0]["marca"]))
		_ok("el golpe pendiente se cancela", _bruto._impacto_pendiente <= 0.0)
		_ok("muestra el golpe aunque sea bruto", _bruto._sprite.animation == &"hurt")
		_igual("y la animacion vuelve a su ritmo", _bruto._sprite.speed_scale, 1.0)
		return
	if desde == 80:
		_ok("el golpe que cargaba no cae", _caidas.is_empty())
		_igual("el escudero no pierde vida", _escudero.vida, _escudero.vida_maxima)
		_ok("el aturdido ya paso", not _bruto.esta_aturdida())
	if _anuncios.size() < 2:
		return
	_igual("despues sigue: vuelve a cargar al terminar la cadencia",
		(int(_anuncios[1]["tick"]) - int(_anuncios[0]["tick"])) * DT, 2.6, DT * 1.5)
	_limpiar()
	siguiente()


func _derribado_crear() -> void:
	print("--- derribado mientras carga: no pega ---")
	_escudero = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, PUNTO, false)
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, LUGAR_BRUTO)
	siguiente()


func _derribado_esperar() -> void:
	if _anuncios.is_empty():
		return
	var desde := _ticks - int(_anuncios[0]["tick"])
	if desde == 30:
		_bruto.derribar()
		_ok("la marca se va con el", _sin_marca(_anuncios[0]["marca"]))
		_ok("y el golpe pendiente tambien", _bruto._impacto_pendiente <= 0.0)
	if desde < 80:
		return
	_ok("el golpe que cargaba no cae", _caidas.is_empty())
	_igual("el escudero no pierde vida", _escudero.vida, _escudero.vida_maxima)
	_limpiar()
	siguiente()


# --- Demonio: dos ataques con su semilla ------------------------------------------

func _demonio_crear() -> void:
	print("--- demonio: dos ataques, la semilla decide cual ---")
	# Dos corridas a la vez, bien separadas: cada demonio con su muñeco, que
	# no le devuelve los golpes. Asi el azar del demonio solo elige ataques.
	_demonios.clear()
	for z in [2.0, 8.0]:
		var muneco := _unidad(Unidad3D.Bando.ALIADO, LANCERO, Vector3(21.0, 0.0, z), false)
		muneco.vida_maxima = 10000.0
		muneco.vida = 10000.0
		_demonios.append(_unidad(Unidad3D.Bando.ENEMIGO, DEMONIO, Vector3(22.5, 0.0, z), true, 7))
	siguiente()


func _demonio_esperar() -> void:
	if _caidas.size() < 6:
		return
	var secuencias: Array[Array] = []
	for demonio in _demonios:
		var secuencia: Array[StringName] = []
		for anuncio in _anuncios:
			if anuncio["quien"] == demonio:
				secuencia.append(anuncio["anim"])
		secuencias.append(secuencia)
	_ok("misma semilla, misma secuencia en las dos corridas %s" % [secuencias[0]],
		secuencias[0] == secuencias[1])
	_ok("usa los dos ataques", secuencias[0].has(&"attack") and secuencias[0].has(&"attack2"))

	var primero := _demonios[0]
	var vida_antes := 10000.0
	var indice := 0
	for caida in _caidas:
		if caida["quien"] != primero:
			continue
		var anim: StringName = secuencias[0][indice]
		var esperado := 24.0 * (1.5 if anim == &"attack2" else 1.0)
		_igual("golpe %d (%s) pega %d" % [indice + 1, anim, esperado],
			vida_antes - float(caida["vida_objetivo"]), esperado)
		vida_antes = float(caida["vida_objetivo"])
		indice += 1

	for anuncio in _anuncios:
		if anuncio["quien"] != primero:
			continue
		# attack: 4 cuadros a 10 fps; attack2: 8 a 11. Los dos duran 1.4 s.
		var duracion := 0.4 if anuncio["anim"] == &"attack" else 8.0 / 11.0
		_igual("%s estirado a 1.4 s" % anuncio["anim"], float(anuncio["escala"]),
			duracion / 1.4, 0.001)
	_igual("la marca del jefe abarca 1.8 m", float(_anuncios[0]["radio"]), 1.8)
	primero.recibir_dano(10.0)
	_ok("al jefe tampoco lo interrumpe un golpe", primero._sprite.animation != &"hurt")
	_limpiar()
	siguiente()


# --- Limite de avance ---------------------------------------------------------------

func _limite_crear() -> void:
	print("--- limite de avance ---")
	_andador = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, Vector3(9.0, 0, 5))
	_andador.limite_avance_x = 10.0
	siguiente()


func _limite_llega() -> void:
	if _ticks < 120:
		return
	var x := _andador.global_position.x
	_ok("sin objetivo avanza hasta el limite y no lo pasa (x=%.3f)" % x, x <= 10.0 and x > 9.95)
	_ok("y espera quieto", _andador._sprite.animation == &"idle")
	# Un enemigo mas alla del limite: lo tiene de objetivo y aun asi no pasa.
	_zombi = _unidad(Unidad3D.Bando.ENEMIGO, ZOMBIE, Vector3(13.0, 0, 5), false)
	siguiente()


func _limite_objetivo_lejos() -> void:
	if _ticks < 40:
		return
	_ok("persigue al que esta mas alla", _andador._objetivo == _zombi)
	_ok("pero tampoco pasa (x=%.3f)" % _andador.global_position.x,
		_andador.global_position.x <= 10.0)
	_limpiar()
	# Un enemigo que avanza hacia la derecha: el limite no es para el.
	_unidad(Unidad3D.Bando.ALIADO, LANCERO, Vector3(13.5, 0, 5), false)
	_zombi = _unidad(Unidad3D.Bando.ENEMIGO, ZOMBIE, Vector3(9.0, 0, 5))
	_zombi.limite_avance_x = 10.0
	siguiente()


func _limite_enemigo() -> void:
	if _ticks < 120:
		return
	_ok("un enemigo no lo mira (x=%.2f)" % _zombi.global_position.x,
		_zombi.global_position.x > 10.2)
	_limpiar()
	terminar()


# --- Utilidades ----------------------------------------------------------------------

## Sin azar de sangrado: la prueba mide golpes, no sangrados. Quieta (sin
## fisica) sirve de muñeco: recibe y no pega ni se mueve.
func _unidad(bando: Unidad3D.Bando, tipo: TipoSoldado, pos: Vector3,
		activa: bool = true, semilla: int = 1) -> Unidad3D:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando, tipo)
	unidad.sembrar(semilla)
	unidad.probabilidad_sangrado = 0.0
	unidad.position = pos
	_contenedor.add_child(unidad)
	unidad.set_physics_process(activa)
	unidad.golpe_anunciado.connect(_al_anunciar.bind(unidad))
	unidad.golpe_cayo.connect(_al_caer.bind(unidad))
	return unidad


func _al_anunciar(punto: Vector3, radio: float, segundos: float, quien: Unidad3D) -> void:
	_anuncios.append({
		"quien": quien, "tick": _ticks, "punto": punto, "radio": radio,
		"segundos": segundos, "anim": quien._sprite.animation,
		"escala": quien._sprite.speed_scale, "marca": quien._marca,
	})


func _al_caer(punto: Vector3, alcanzados: int, quien: Unidad3D) -> void:
	var objetivo := quien._objetivo as Unidad3D
	_caidas.append({
		"quien": quien, "tick": _ticks, "punto": punto, "alcanzados": alcanzados,
		"healer_en_el_aire": _healer.esta_en_el_aire(), "healer_vida": _healer.vida,
		"vida_objetivo": objetivo.vida if objetivo != null else -1.0,
	})


## Si la marca ya no esta en el suelo: liberada o por liberarse. Variant y no
## MarcaTelegrafo: asignar una ya liberada a una variable tipada es un error.
func _sin_marca(marca: Variant) -> bool:
	return not is_instance_valid(marca) or (marca as Node).is_queued_for_deletion()


## Saca todo lo de la prueba anterior menos el healer. Con free y no con
## queue_free: la siguiente arranca en este mismo tick y no tiene que verlos.
func _limpiar() -> void:
	for hijo in _contenedor.get_children():
		if hijo == _healer or not is_instance_valid(hijo):
			continue
		hijo.free()
	_munecos.clear()
	_anuncios.clear()
	_caidas.clear()
