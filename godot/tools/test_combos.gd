extends SceneTree
## Movimientos y combos: cada fila de la tabla de gen_movimientos.gd y las
## reglas que las unen (ventana, recuperacion, golpe al aire, corte por dano,
## especificidad y loadout).
##
## Corre sobre ticks de fisica reales, porque el impulso y la caida necesitan
## que el healer se mueva de verdad. Cada caso es una serie de pasos: un paso
## hace algo y compara, y puede pedir que pase tiempo antes del siguiente.

const DT := 1.0 / 60.0
const ORIGEN := Vector3(15, 0, 5)
const ESCUDERO := preload("res://resources/soldados/escudero.tres")
const ZOMBIE := preload("res://resources/soldados/zombie.tres")
const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")
const DIR := "res://resources/movimientos"
const ARCHIVOS: Array[String] = [
	"toque", "vendaje", "oleada", "bendicion", "plegaria", "reanimar", "impulso", "caida",
]
const LIGERA := &"ligera"
const PESADA := &"pesada"

var _contenedor: Node3D
var _healer: Healer3D
var _combos: ComponenteCombos
var _todos: Array[Movimiento] = []
var _unidades: Array[Unidad3D] = []

# Lo que el componente fue avisando desde el ultimo _preparar().
var _usados: Array[Dictionary] = []
var _fallidos: Array[String] = []
var _cuentas: Array[int] = []
var _cortes: Array[StringName] = []
var _avisos: Array[String] = []
var _loadouts := 0

var _pasos: Array[Callable] = []
var _paso := 0
var _espera := 0
var _ticks := 0
var _fallos := 0

# Lo que un paso le deja al siguiente.
var _a: Unidad3D
var _b: Unidad3D
var _c: Unidad3D
var _d: Unidad3D
var _aturdible: Unidad3D
var _comun: Unidad3D


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	_contenedor.add_child(_healer)
	# Sin regeneracion: cada comprobacion de mana mide solo lo que se cobro.
	_healer.regeneracion_mana = 0.0

	for archivo in ARCHIVOS:
		var mov := load("%s/%s.tres" % [DIR, archivo]) as Movimiento
		if mov == null:
			print("FALLA: falta %s/%s.tres (correr gen_movimientos.gd)" % [DIR, archivo])
			quit(1)
			return
		_todos.append(mov)

	_combos = ComponenteCombos.new()
	_combos.name = "Combos"
	_combos.movimientos = _todos.duplicate()
	_healer.add_child(_combos)
	_combos.movimiento_usado.connect(_on_usado)
	_combos.movimiento_fallo.connect(_on_fallo)
	_combos.combo_cambio.connect(_on_combo_cambio)
	_combos.combo_cortado.connect(_on_combo_cortado)
	_combos.aviso.connect(_on_aviso)
	_combos.loadout_cambio.connect(_on_loadout_cambio)

	_pasos = [
		_tabla,
		_toque, _toque_desperdicio,
		_vendaje, _vendaje_segundo, _vendaje_pegajoso, _vendaje_pegajoso_segundo,
		_oleada, _oleada_segunda_ligera, _oleada_remate,
		_bendicion, _bendicion_repetida,
		_plegaria, _plegaria_cargando, _plegaria_sale, _plegaria_enfriamiento,
		_plegaria_sin_nadie, _plegaria_sin_nadie_vence,
		_reanimar,
		_especificidad, _especificidad_segunda_ligera,
		_impulso, _impulso_sale, _impulso_velocidad, _impulso_cruce, _hasta_aterrizar,
		_caida, _caida_en_el_aire, _caida_aterriza,
		_vacio, _vacio_de_espaldas,
		_ventana, _ventana_vencida,
		_recuperacion,
		_dano,
		_loadout, _loadout_segunda,
		_fichas, _fichas_aviso_de_area,
		_terminar,
	]
	physics_frame.connect(_tick)


## Corre el paso actual. Un paso devuelve true cuando termino; false para que
## se lo vuelva a llamar en el tick siguiente (esperar a que algo pase).
func _tick() -> void:
	_ticks += 1
	if _ticks > 3000:
		print("FALLA: el test no termino (paso %d)" % _paso)
		quit(1)
		return
	if _ticks < 3:
		return
	if _espera > 0:
		_espera -= 1
		return
	if _paso < _pasos.size() and _pasos[_paso].call():
		_paso += 1


## Deja pasar `segundos` de fisica antes del paso siguiente, contados desde el
## tick en que corre el paso actual.
func _esperar(segundos: float) -> void:
	_espera = maxi(roundi(segundos / DT) - 1, 0)


func _on_usado(mov: Movimiento, objetivo: Node3D, efectivo: float) -> void:
	_usados.append({"nombre": mov.nombre, "objetivo": objetivo, "efectivo": efectivo})


func _on_fallo(mov: Movimiento, motivo: String) -> void:
	_fallidos.append("%s: %s" % [mov.nombre, motivo])


func _on_combo_cambio(cuenta: int, _nombre: String) -> void:
	_cuentas.append(cuenta)


func _on_combo_cortado(motivo: StringName) -> void:
	_cortes.append(motivo)


func _on_aviso(texto: String) -> void:
	_avisos.append(texto)


func _on_loadout_cambio() -> void:
	_loadouts += 1


# --- La tabla ------------------------------------------------------------------

func _tabla() -> bool:
	print("--- la tabla ---")
	_igual("hay 8 movimientos", _todos.size(), 8)
	var esperadas := {
		"Toque": 0, "Plegaria": 0, "Impulso": 1, "Caida sanadora": 1,
		"Vendaje": 2, "Bendicion": 2, "Oleada": 4, "Reanimar": 5,
	}
	for nombre: String in esperadas:
		var mov := _mov(nombre)
		_ok("especificidad de %s: %d" % [nombre, esperadas[nombre]],
			mov != null and mov.especificidad() == esperadas[nombre])
	_ok("ninguna fila empata con otra (%s)" % ", ".join(_empates()), _empates().is_empty())
	var recuperaciones_ok := true
	for mov in _todos:
		var esperada := 0.6 if mov.entrada == PESADA else 0.3
		recuperaciones_ok = recuperaciones_ok and is_equal_approx(mov.recuperacion, esperada)
	_ok("recuperacion 0.3 en las ligeras y 0.6 en las pesadas", recuperaciones_ok)
	_ok("todos tienen icono", _todos.all(func(mov: Movimiento) -> bool: return mov.icono != null))
	return true


# --- Toque ---------------------------------------------------------------------

func _toque() -> bool:
	print("--- L: Toque ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 50.0)
	_ok("L sale", _combos.pulsar(LIGERA))
	_ok("y es Toque", _ultimo_usado() == "Toque")
	_igual("cura 18", _a.vida, 68.0)
	_igual("cobra 10", _healer.mana, 90.0)
	_ok("avisa lo que entro", _avisos.has("+18"))
	_igual("el combo cuenta 1", _combos.cuenta_combo(), 1)
	_ok("la secuencia es [ligera]", _mismos(_combos.secuencia(), [LIGERA]))
	_ok("el ultimo objetivo es el tocado", _combos.ultimo_objetivo() == _a)
	_esperar(0.8)
	return true


func _toque_desperdicio() -> bool:
	_a.vida = _a.vida_maxima - 7.0
	_avisos.clear()
	_combos.pulsar(LIGERA)
	_igual("con 7 de hueco solo entran 7", _a.vida, _a.vida_maxima)
	_ok("y avisa lo desperdiciado (%s)" % ", ".join(PackedStringArray(_avisos)),
		_avisos.has("+7 (11 desperdiciado)"))
	return true


# --- Vendaje -------------------------------------------------------------------

func _vendaje() -> bool:
	print("--- L, L: Vendaje ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 40.0)
	_a.sangrado_restante = 6.0
	_b = _aliado(1.5, 0.6, 30.0)  # mas golpeado, pero sin sangrado
	_combos.pulsar(LIGERA)
	_ok("el primer toque va al que sangra", _ultimo_objetivo_usado() == _a)
	_ok("Toque no corta el sangrado", _a.sangrado_restante > 0.0)
	_esperar(0.4)
	return true


func _vendaje_segundo() -> bool:
	var vida := _a.vida
	_ok("L, L sale", _combos.pulsar(LIGERA))
	_ok("y es Vendaje", _ultimo_usado() == "Vendaje")
	_ok("sobre el mismo paciente", _ultimo_objetivo_usado() == _a)
	_igual("corta el sangrado", _a.sangrado_restante, 0.0)
	_igual("y cura 18", _a.vida - vida, 18.0)
	_igual("cobra 10 (20 con el toque)", _healer.mana, 80.0)
	_ok("avisa el corte", _avisos.has("Vendaje: sangrado cortado"))
	_igual("el combo va 2", _combos.cuenta_combo(), 2)
	_esperar(0.8)
	return true


func _vendaje_pegajoso() -> bool:
	_preparar()
	_a = _aliado(1.0, 0.0, 60.0)
	_b = _aliado(1.4, 0.5, 70.0)
	_combos.pulsar(LIGERA)
	_ok("Toque va al mas golpeado", _ultimo_objetivo_usado() == _a)
	# Ahora el otro seria prioridad para una ligera suelta.
	_b.sangrado_restante = 5.0
	_esperar(0.4)
	return true


func _vendaje_pegajoso_segundo() -> bool:
	_combos.pulsar(LIGERA)
	_ok("Vendaje sigue sobre el paciente del combo", _ultimo_objetivo_usado() == _a)
	_ok("aunque al vecino le haya empezado a sangrar", _b.sangrado_restante > 0.0)
	return true


# --- Oleada --------------------------------------------------------------------

func _oleada() -> bool:
	print("--- L, L, P: Oleada ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 20.0)   # el unico en la caja de la ligera
	_b = _aliado(-2.0, 0.5, 40.0)  # detras, a 2.1 m
	_c = _aliado(3.0, 1.5, 40.0)   # fuera de la ligera, a 3.4 m
	_d = _aliado(4.5, 0.0, 40.0)   # a 4.5 m: fuera de la oleada
	_combos.pulsar(LIGERA)
	_esperar(0.4)
	return true


func _oleada_segunda_ligera() -> bool:
	_combos.pulsar(LIGERA)
	_ok("las dos ligeras fueron Toque y Vendaje", _mismos(_nombres_usados(), ["Toque", "Vendaje"]))
	_esperar(0.4)
	return true


func _oleada_remate() -> bool:
	var vidas := [_a.vida, _b.vida, _c.vida, _d.vida]
	var mana := _healer.mana
	_ok("L, L, P sale", _combos.pulsar(PESADA))
	_ok("y es Oleada", _ultimo_usado() == "Oleada")
	_igual("cura 30 al de adelante", _a.vida - vidas[0], 30.0)
	_igual("al de atras", _b.vida - vidas[1], 30.0)
	_igual("y al que la ligera no alcanzaba", _c.vida - vidas[2], 30.0)
	_igual("no al que esta a 4.5 m", _d.vida - vidas[3], 0.0)
	_igual("cobra 35", mana - _healer.mana, 35.0)
	_igual("tras el remate el combo vuelve a 0", _combos.cuenta_combo(), 0)
	_ok("combo_cambio conto 1, 2, 3 y 0 (%s)" % str(_cuentas), _mismos(_cuentas, [1, 2, 3, 0]))
	_ok("y el corte fue por remate", _cortes.has(&"remate"))
	_ok("la secuencia queda vacia", _combos.secuencia().is_empty())
	return true


# --- Bendicion -----------------------------------------------------------------

func _bendicion() -> bool:
	print("--- L, P: Bendicion ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 50.0)
	_a.sangrado_restante = 5.0      # la ligera lo elige por el sangrado
	_b = _aliado(1.8, -0.5, 20.0)   # mas golpeado, pero no sangra
	_combos.pulsar(LIGERA)
	_ok("la ligera toca al que sangra", _ultimo_objetivo_usado() == _a)
	# Ahora una ligera suelta elegiria al otro: sangra y tiene menos vida.
	_b.sangrado_restante = 5.0
	_ok("una ligera suelta ahora iria al otro", Apuntado.objetivo_ligera(_healer) == _b)
	_ok("L, P sale", _combos.pulsar(PESADA))
	_ok("y es Bendicion", _ultimo_usado() == "Bendicion")
	_ok("sobre el ultimo tocado", _a.esta_bendecida() and _ultimo_objetivo_usado() == _a)
	_ok("no sobre el mas golpeado", not _b.esta_bendecida())
	_igual("cobra 30 (40 con el toque)", _healer.mana, 60.0)
	_ok("avisa", _avisos.has("Bendecido"))
	var antes := _a.vida
	_a.recibir_dano(20.0)
	_igual("el dano le llega reducido", antes - _a.vida, 20.0 * 0.65 * (1.0 - _a.reduccion_base))
	return true


func _bendicion_repetida() -> bool:
	# equipar() limpia el enfriamiento de 8 s y el combo: se vuelve a armar L, P
	# sobre el que ya esta bendecido.
	_combos.equipar(_todos)
	_b.sangrado_restante = 0.0
	_combos.pulsar(LIGERA)
	_ok("la ligera vuelve al bendecido", _ultimo_objetivo_usado() == _a)
	var mana := _healer.mana
	_fallidos.clear()
	_ok("la segunda Bendicion sobre el mismo no sale", not _combos.pulsar(PESADA))
	_ok("avisa que ya esta bendecido (%s)" % ", ".join(PackedStringArray(_fallidos)),
		_fallidos.has("Bendicion: Ya bendecido"))
	_igual("y no cobra", _healer.mana, mana)
	_igual("un rechazo no corta el combo", _combos.cuenta_combo(), 1)
	return true


# --- Plegaria ------------------------------------------------------------------

func _plegaria() -> bool:
	print("--- P: Plegaria ---")
	_preparar()
	_a = _aliado(3.0, 0.0, 40.0)   # solo la pesada llega
	_b = _aliado(1.0, 1.8, 40.0)   # idem, por el costado
	_c = _aliado(3.6, 0.0, 40.0)   # fuera de la caja pesada
	_ok("P sola sale", _combos.pulsar(PESADA))
	_ok("y queda cargando", _combos.esta_en_wind_up())
	_ok("es Plegaria", _en_curso() == "Plegaria")
	_igual("todavia no cobra", _healer.mana, 100.0)
	_ok("mientras carga, otro boton no hace nada", not _combos.pulsar(LIGERA))
	_esperar(0.4)
	return true


func _plegaria_cargando() -> bool:
	_igual("a los 0.4 s todavia no curo", _a.vida, 40.0)
	_igual("ni cobro", _healer.mana, 100.0)
	_ok("sigue cargando", _combos.esta_en_wind_up())
	_esperar(0.2)
	return true


func _plegaria_sale() -> bool:
	_ok("a los 0.6 s ya salio", not _combos.esta_en_wind_up())
	_ok("salio Plegaria", _ultimo_usado() == "Plegaria")
	_igual("cura 40 al de adelante", _a.vida, 80.0)
	_igual("y al del costado", _b.vida, 80.0)
	_igual("no al que quedo fuera de la caja", _c.vida, 40.0)
	_igual("cobra 30 recien al conectar", _healer.mana, 70.0)
	var plegaria := _mov("Plegaria")
	_ok("queda en enfriamiento", _combos.enfriamiento_restante(plegaria) > 0.0)
	_ok("y no disponible", not _combos.disponible("Plegaria"))
	# Pasa la recuperacion de la pesada (0.6) pero no el enfriamiento (1.5).
	_esperar(0.7)
	return true


func _plegaria_enfriamiento() -> bool:
	var plegaria := _mov("Plegaria")
	_fallidos.clear()
	_ok("en enfriamiento no sale", not _combos.pulsar(PESADA))
	_ok("y lo avisa", _fallidos.has("Plegaria: Plegaria en enfriamiento"))

	var loadouts := _loadouts
	_combos.equipar(_todos)
	_ok("equipar avisa el cambio de loadout", _loadouts == loadouts + 1)
	_igual("equipar limpia el enfriamiento", _combos.enfriamiento_restante(plegaria), 0.0)
	_igual("la fraccion vuelve a 0", _combos.fraccion_enfriamiento(plegaria), 0.0)
	_ok("y vuelve a estar disponible", _combos.disponible("Plegaria"))

	_healer.mana = 20.0
	_fallidos.clear()
	_ok("sin mana no sale", not _combos.pulsar(PESADA))
	_ok("avisa que falta mana", _fallidos.has("Plegaria: Sin mana"))
	_ok("y no queda cargando", not _combos.esta_en_wind_up())
	_ok("sin mana no esta disponible", not _combos.disponible("Plegaria"))
	return true


func _plegaria_sin_nadie() -> bool:
	_preparar()
	_a = _aliado(2.0, 0.0, 40.0)
	_combos.pulsar(PESADA)
	# Se va de la caja mientras el healer reza.
	_a.global_position = ORIGEN + Vector3(6.0, 0.0, 0.0)
	_esperar(0.6)
	return true


func _plegaria_sin_nadie_vence() -> bool:
	_ok("si al vencer no queda nadie, sale al aire", _fallidos.has("Plegaria: En vacio"))
	_igual("y no cobra", _healer.mana, 100.0)
	_ok("ni cuenta para el combo", _combos.cuenta_combo() == 0)
	return true


# --- Reanimar ------------------------------------------------------------------

func _reanimar() -> bool:
	print("--- P con un derribado al frente: Reanimar ---")
	_preparar()
	_a = _aliado(1.5, 0.0)
	_a.derribar()
	_b = _aliado(1.0, 0.5, 50.0)
	_c = _aliado(-1.5, 0.0)
	_c.derribar()   # detras: no esta al frente
	_ok("P resuelve a Reanimar", _resuelve(PESADA) == "Reanimar")
	_ok("P sale", _combos.pulsar(PESADA))
	_ok("y es Reanimar", _ultimo_usado() == "Reanimar")
	_ok("la unidad vuelve a estar en pie", not _a.esta_derribada() and _a.esta_viva())
	_igual("con parte de la vida", _a.vida, _a.vida_maxima * _a.vida_al_reanimar)
	_igual("cobra 40", _healer.mana, 60.0)
	_ok("avisa", _avisos.has("Reanimado"))
	_ok("el de atras sigue en el suelo", _c.esta_derribada())
	_ok("sin derribado al frente, P vuelve a ser Plegaria", _resuelve(PESADA) == "Plegaria")
	return true


# --- Especificidad -------------------------------------------------------------

func _especificidad() -> bool:
	print("--- gana el mas especifico ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 40.0)
	_ok("sin combo, P es Plegaria y L es Toque",
		_resuelve(PESADA) == "Plegaria" and _resuelve(LIGERA) == "Toque")
	_combos.pulsar(LIGERA)
	_ok("con [L], P es Bendicion", _resuelve(PESADA) == "Bendicion")
	_ok("y L es Vendaje", _resuelve(LIGERA) == "Vendaje")
	_esperar(0.4)
	return true


func _especificidad_segunda_ligera() -> bool:
	_combos.pulsar(LIGERA)
	_ok("con [L, L], P es Oleada", _resuelve(PESADA) == "Oleada")
	_ok("y L sigue siendo Vendaje (sufijo [L])", _resuelve(LIGERA) == "Vendaje")
	_b = _aliado(2.0, -0.5)
	_b.derribar()
	_ok("con [L, L] y un derribado al frente, P es Reanimar", _resuelve(PESADA) == "Reanimar")
	_b.reanimar()
	_ok("levantado el derribado, vuelve a ser Oleada", _resuelve(PESADA) == "Oleada")
	return true


# --- Impulso -------------------------------------------------------------------

func _impulso() -> bool:
	print("--- aire + L: Impulso ---")
	_preparar()
	_a = _aliado(1.5, 0.0, 50.0)   # en el camino del envion
	_b = _aliado(2.4, 0.0, 50.0)   # tambien en el camino: cura una sola vez
	_healer.saltar()
	_esperar(0.1)
	return true


func _impulso_sale() -> bool:
	_ok("el healer esta en el aire", _healer.esta_en_el_aire())
	_ok("en el aire, L resuelve a Impulso", _resuelve(LIGERA) == "Impulso")
	_ok("y P a Caida sanadora", _resuelve(PESADA) == "Caida sanadora")
	_ok("L sale", _combos.pulsar(LIGERA))
	_ok("es Impulso", _ultimo_usado() == "Impulso")
	_igual("cobra 12", _healer.mana, 88.0)
	_esperar(DT)
	return true


func _impulso_velocidad() -> bool:
	var horizontal := Vector2(_healer.velocity.x, _healer.velocity.z).length()
	_ok("al tick siguiente va a mas de 5 m/s (%.1f)" % horizontal, horizontal > 5.0)
	_esperar(0.4)
	return true


func _impulso_cruce() -> bool:
	_igual("curo 12 al primero que cruzo", _a.vida, 62.0)
	_igual("y a nadie mas", _b.vida, 50.0)
	_ok("avisa la cura", _avisos.has("+12"))
	_ok("el cruzado queda como ultimo objetivo", _combos.ultimo_objetivo() == _a)
	_ok("el healer paso de largo", _healer.global_position.x > _a.global_position.x)
	return true


func _hasta_aterrizar() -> bool:
	return not _healer.esta_en_el_aire()


# --- Caida sanadora ------------------------------------------------------------

func _caida() -> bool:
	print("--- aire + P: Caida sanadora ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 50.0)    # a 1 m
	_b = _aliado(-2.5, 0.0, 50.0)   # a 2.5 m, detras
	_c = _aliado(3.6, 0.0, 50.0)    # a 3.6 m: fuera
	_aturdible = _enemigo(1.5, 0.5, true)
	_comun = _enemigo(-1.0, 0.5)    # sin aturdir(): se lo saltea sin romper nada
	_healer.saltar()
	_esperar(0.1)
	return true


func _caida_en_el_aire() -> bool:
	_ok("en el aire P sale", _combos.pulsar(PESADA))
	_ok("y queda esperando el suelo", _en_curso() == "Caida sanadora")
	_igual("no cobra en el aire", _healer.mana, 100.0)
	_igual("ni cura", _a.vida, 50.0)
	_ok("ni se anuncia", _usados.is_empty())
	_ok("otra P en el aire no se encola dos veces", not _combos.pulsar(PESADA))
	return true


func _caida_aterriza() -> bool:
	if _healer.esta_en_el_aire():
		return false
	_ok("al aterrizar sale Caida sanadora", _ultimo_usado() == "Caida sanadora")
	_igual("cura 25 al que esta a 1 m", _a.vida, 75.0)
	_igual("y al que esta a 2.5 m", _b.vida, 75.0)
	_igual("no al que esta a 3.6 m", _c.vida, 50.0)
	_igual("cobra 30 recien al aterrizar", _healer.mana, 70.0)
	_igual("aturde 0.5 s al enemigo que sabe aturdirse", _aturdible.get("aturdido"), 0.5)
	_ok("y al que no sabe no le pasa nada", _comun.esta_viva() and not _comun.esta_derribada())
	return true


# --- Golpe al aire -------------------------------------------------------------

func _vacio() -> bool:
	print("--- golpe al aire ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 50.0)
	_combos.pulsar(LIGERA)
	_igual("el combo arranca en 1", _combos.cuenta_combo(), 1)
	# Se da vuelta: el aliado queda atras, fuera del margen.
	_healer._sprite.flip_h = true
	_esperar(0.4)
	return true


func _vacio_de_espaldas() -> bool:
	var mana := _healer.mana
	_fallidos.clear()
	_ok("L sin nadie en la caja no sale", not _combos.pulsar(LIGERA))
	_ok("avisa que fue al aire (%s)" % ", ".join(PackedStringArray(_fallidos)),
		_fallidos.has("Vendaje: En vacio"))
	_igual("no cobra", _healer.mana, mana)
	_igual("corta el combo", _combos.cuenta_combo(), 0)
	_ok("por vacio", _cortes.has(&"vacio"))
	_fallidos.clear()
	_ok("sin combo, la L siguiente es Toque al aire",
		not _combos.pulsar(LIGERA) and _fallidos.has("Toque: En vacio"))
	_igual("tampoco cobra", _healer.mana, mana)
	return true


# --- Ventana -------------------------------------------------------------------

func _ventana() -> bool:
	print("--- ventana de combo ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 20.0)
	_combos.pulsar(LIGERA)
	_igual("al conectar la ventana es de 0.7 s", _combos.ventana_restante(), 0.7)
	_esperar(0.8)
	return true


func _ventana_vencida() -> bool:
	_ok("a los 0.8 s el combo se corto por tiempo", _cortes.has(&"tiempo"))
	_igual("y la cuenta volvio a 0", _combos.cuenta_combo(), 0)
	_combos.pulsar(LIGERA)
	_ok("la L siguiente es Toque, no Vendaje", _mismos(_nombres_usados(), ["Toque", "Toque"]))
	return true


# --- Recuperacion --------------------------------------------------------------

func _recuperacion() -> bool:
	print("--- recuperacion por boton ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 20.0)
	_ok("la primera L sale", _combos.pulsar(LIGERA))
	_ok("la segunda en el mismo tick no", not _combos.pulsar(LIGERA))
	_igual("sale un solo movimiento", _usados.size(), 1)
	_igual("cobra una sola vez", _healer.mana, 90.0)
	_ok("y en silencio", _fallidos.is_empty())
	_ok("la recuperacion es de la ligera, no de la pesada",
		_combos.recuperacion_restante(LIGERA) > 0.0
			and is_zero_approx(_combos.recuperacion_restante(PESADA)))
	return true


# --- Dano ----------------------------------------------------------------------

func _dano() -> bool:
	print("--- un golpe corta el combo ---")
	_preparar()
	_a = _aliado(1.0, 0.0, 40.0)
	_combos.pulsar(LIGERA)
	_igual("el combo va 1", _combos.cuenta_combo(), 1)
	_healer.recibir_dano(5.0)
	_igual("recibir dano lo corta", _combos.cuenta_combo(), 0)
	_ok("por dano", _cortes.has(&"dano"))
	_ok("P ya no es Bendicion sino Plegaria", _resuelve(PESADA) == "Plegaria")
	_ok("P sale", _combos.pulsar(PESADA))
	_ok("y lo que carga es la Plegaria", _en_curso() == "Plegaria")
	_ok("nadie quedo bendecido", not _a.esta_bendecida())
	return true


# --- Loadout -------------------------------------------------------------------

func _loadout() -> bool:
	print("--- loadout ---")
	_preparar()
	_combos.equipar([_mov("Toque")] as Array[Movimiento])
	_a = _aliado(1.0, 0.0, 20.0)
	_combos.pulsar(LIGERA)
	_esperar(0.4)
	return true


func _loadout_segunda() -> bool:
	_combos.pulsar(LIGERA)
	_ok("con solo Toque, L, L es Toque dos veces", _mismos(_nombres_usados(), ["Toque", "Toque"]))
	_ok("Vendaje no esta equipado", _combos.movimiento_por_nombre("Vendaje") == null)
	_ok("ni disponible", not _combos.disponible("Vendaje"))
	_ok("sin pesadas equipadas, P no hace nada", not _combos.pulsar(PESADA))
	return true


## Lo que la ficha del HUD muestra al mirar a un soldado: la consecuencia de
## cada movimiento sobre el, sin decir cual conviene.
func _fichas() -> bool:
	print("--- previsualizar, para la ficha ---")
	_preparar()
	_a = _aliado(1.0, 0.0)
	_a.vida = _a.vida_maxima - 7.0
	_b = _aliado(1.5, 0.5, 50.0)
	_b.sangrado_restante = 4.0
	_c = _aliado(2.0, -0.5)
	_c.derribar()
	_igual_texto("Toque con 7 de hueco", _ficha("Toque", _a), "Toque: +7 HP (11 se desperdician)")
	_igual_texto("Vendaje a uno que sangra", _ficha("Vendaje", _b),
		"Vendaje: corta el sangrado, +18 HP")
	_igual_texto("Bendicion", _ficha("Bendicion", _b), "Bendicion: -35% dano por 8s")
	_igual_texto("Plegaria", _ficha("Plegaria", _b), "Plegaria: +40 HP")
	_igual_texto("Oleada", _ficha("Oleada", _b), "Oleada: +30 HP")
	_igual_texto("Caida sanadora", _ficha("Caida sanadora", _b),
		"Caida sanadora (al aterrizar): +25 HP")
	_igual_texto("Impulso a un herido", _ficha("Impulso", _b), "Impulso: +12 HP al cruzarlo")
	_igual_texto("Reanimar a un derribado", _ficha("Reanimar", _c), "Reanimar: lo levanta con 39 HP")
	_ok("a un derribado solo Reanimar le dice algo",
		_todos.all(func(mov: Movimiento) -> bool:
			return (mov.previsualizar(_healer, _c) != "") == (mov.nombre == "Reanimar")))
	_a.vida = _a.vida_maxima
	_igual_texto("Impulso a un sano no promete nada", _ficha("Impulso", _a), "")
	_b.bendecir(8.0, 0.35, 0.3)
	_igual_texto("Bendicion a un bendecido", _ficha("Bendicion", _b), "Bendicion: ya la tiene")

	_preparar()
	_a = _aliado(3.0, 0.0, 40.0)
	_b = _aliado(1.0, 1.8, 40.0)
	_combos.pulsar(PESADA)
	_esperar(0.6)
	return true


func _fichas_aviso_de_area() -> bool:
	_ok("el aviso de un area suma lo que entro (%s)" % ", ".join(PackedStringArray(_avisos)),
		_avisos.has("Plegaria: +80 en 2 soldados"))
	return true


func _terminar() -> bool:
	_combos.equipar(_todos)
	_limpiar_unidades()
	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)
	return true


# --- Ayudantes ----------------------------------------------------------------

## Deja el campo, el healer y el componente como al principio, para que cada
## caso se pueda leer solo.
func _preparar() -> void:
	_limpiar_unidades()
	_healer.reiniciar(ORIGEN)
	_healer._sprite.flip_h = false
	_combos.equipar(_todos)
	_usados.clear()
	_fallidos.clear()
	_cuentas.clear()
	_cortes.clear()
	_avisos.clear()


func _limpiar_unidades() -> void:
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.free()
	_unidades.clear()


## Escudero quieto en ORIGEN + (dx, 0, dz). Tiene vida de sobra para que los
## combos entren enteros.
func _aliado(dx: float, dz: float, vida: float = -1.0) -> Unidad3D:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(Unidad3D.Bando.ALIADO, ESCUDERO)
	_poner(unidad, dx, dz)
	if vida >= 0.0:
		unidad.vida = vida
	return unidad


## Zombi quieto. Con `aturdible` lleva un aturdir() de mentira, que es lo que
## la Caida sanadora le pregunta a cada enemigo.
func _enemigo(dx: float, dz: float, aturdible: bool = false) -> Unidad3D:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	if aturdible:
		var guion := GDScript.new()
		guion.source_code = "\n".join([
			"extends \"res://scripts/3d/unidad3d.gd\"",
			"var aturdido := 0.0",
			"func aturdir(segundos: float) -> void:",
			"\taturdido = segundos",
		])
		guion.reload()
		unidad.set_script(guion)
	unidad.configurar(Unidad3D.Bando.ENEMIGO, ZOMBIE)
	_poner(unidad, dx, dz)
	return unidad


## Quietas y sin azar: la prueba mide lo que hace el healer, no el combate.
func _poner(unidad: Unidad3D, dx: float, dz: float) -> void:
	unidad.position = ORIGEN + Vector3(dx, 0.0, dz)
	_contenedor.add_child(unidad)
	unidad.set_physics_process(false)
	unidad.probabilidad_sangrado = 0.0
	_unidades.append(unidad)


func _mov(nombre: String) -> Movimiento:
	for mov in _todos:
		if mov.nombre == nombre:
			return mov
	return null


func _resuelve(entrada: StringName) -> String:
	var mov := _combos.resolver(entrada)
	return mov.nombre if mov != null else ""


func _ficha(nombre: String, unidad: Unidad3D) -> String:
	return _mov(nombre).previsualizar(_healer, unidad)


func _en_curso() -> String:
	var mov := _combos.movimiento_en_curso()
	return mov.nombre if mov != null else ""


func _ultimo_usado() -> String:
	return _usados.back()["nombre"] if not _usados.is_empty() else ""


func _ultimo_objetivo_usado() -> Node3D:
	return _usados.back()["objetivo"] if not _usados.is_empty() else null


func _nombres_usados() -> Array[String]:
	var nombres: Array[String] = []
	for usado in _usados:
		nombres.append(usado["nombre"])
	return nombres


## Filas que califican en las mismas condiciones: empatarian siempre y ganaria
## la que este primero en la lista, que no es una regla sino un accidente.
func _empates() -> PackedStringArray:
	var empates := PackedStringArray()
	for i in _todos.size():
		for j in range(i + 1, _todos.size()):
			var x := _todos[i]
			var y := _todos[j]
			if x.entrada == y.entrada and x.en_el_aire == y.en_el_aire \
					and x.requiere_derribado == y.requiere_derribado \
					and _mismos(x.secuencia_previa, y.secuencia_previa):
				empates.append("%s/%s" % [x.nombre, y.nombre])
	return empates


## Mismos elementos en el mismo orden, sin importar si los arrays son tipados.
func _mismos(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual_texto(que: String, obtenido: String, esperado: String) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-34s \"%s\"%s" % [
		"OK" if ok else "FALLA", que, obtenido, "" if ok else " (esperado \"%s\")" % esperado])


func _igual(que: String, obtenido: float, esperado: float, tolerancia: float = 0.01) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-46s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
