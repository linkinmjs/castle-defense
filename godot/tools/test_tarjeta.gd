extends SceneTree
## Lo que la tarjeta de la ficha le dice al jugador sobre el soldado que tiene
## al frente.
##
## Cada movimiento calcula su propia previsualizacion. La tarjeta no las lista
## todas: dice quien esta al frente y que haria el movimiento que saldria ahora
## con cada boton, segun el combo en curso y lo que haya tirado adelante.
## Muestra la consecuencia, nunca cual conviene.
##
## Prueba TarjetaObjetivo sin HUD: son datos. Como los pinta la ficha lo mira
## test_hud.gd.

const ORIGEN := Vector3(15, 0, 5)

var _contenedor: Node3D
var _healer: Healer3D
var _combos: ComponenteCombos
var _fallos := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	_contenedor.add_child(_healer)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	if _ticks != 2:
		return
	_combos = _healer.get_node("Combos")
	var toque := _combos.movimiento_por_nombre("Toque")
	var vendaje := _combos.movimiento_por_nombre("Vendaje")
	var plegaria := _combos.movimiento_por_nombre("Plegaria")
	var reanimar := _combos.movimiento_por_nombre("Reanimar")
	var bendicion := _combos.movimiento_por_nombre("Bendicion")

	print("--- Toque dice cuanto entra y cuanto se pierde ---")
	var u := _crear()
	u.vida = u.vida_maxima - 10.0
	var texto := toque.previsualizar(_healer, u)
	_contiene("avisa el desperdicio", texto, "se desperdician")
	_contiene("y cuanto entra de verdad", texto, "+10 HP")

	u.vida = u.vida_maxima * 0.3
	texto = toque.previsualizar(_healer, u)
	_ok("sobre un herido no habla de desperdicio", not texto.contains("desperdician"))

	print("--- Vendaje habla del sangrado solo si hay algo que cortar ---")
	_ok("sin sangrado no promete cortarlo",
		not vendaje.previsualizar(_healer, u).contains("sangrado"))
	u.aplicar_sangrado(5.0)
	_contiene("sangrando, dice que corta la causa",
		vendaje.previsualizar(_healer, u), "corta el sangrado")

	print("--- Reanimar es al reves: solo sobre un derribado ---")
	_igual("en pie no dice nada", reanimar.previsualizar(_healer, u), "")
	u.recibir_dano(500.0)
	_ok("derribado, dice con cuanta vida lo levanta",
		reanimar.previsualizar(_healer, u).contains("HP"))
	_igual("y Toque deja de ofrecerse", toque.previsualizar(_healer, u), "")
	_igual("Vendaje tampoco", vendaje.previsualizar(_healer, u), "")
	u.free()

	print("--- Bendicion avisa si ya la tiene ---")
	var b := _crear()
	_contiene("dice cuanto dano evita", bendicion.previsualizar(_healer, b), "dano")
	b.bendecir(8.0, 0.35, 0.3)
	_contiene("y avisa si ya esta bendecido", bendicion.previsualizar(_healer, b), "ya la tiene")
	b.free()

	print("--- sin healer, la tarjeta no inventa nada ---")
	var vacia := TarjetaObjetivo.lineas(null)
	_igual("nadie al frente", vacia[0], TarjetaObjetivo.NADIE)
	_igual("y ningun boton hace nada", vacia[1] + " | " + vacia[2], "L · — | P · —")

	print("--- tres renglones: quien es y que sale con cada boton ---")
	var paciente := _crear()
	paciente.nombre_unidad = "Mara"
	paciente.vida = paciente.vida_maxima * 0.5
	paciente.aplicar_sangrado(5.2)
	# A 0.8 m al frente del healer, que mira hacia +X: esta en la caja. El
	# healer lo marca en su tick, y la tarjeta lo toma de ahi.
	await physics_frame
	await physics_frame
	_ok("el healer lo tiene al frente", _healer.unidad_apuntada() == paciente)

	_combos.equipar([toque] as Array[Movimiento])
	var lineas := TarjetaObjetivo.lineas(_healer)
	_ok("son tres renglones, no uno por movimiento equipado", lineas.size() == 3)
	_igual("pone el nombre, el rol y la vida", lineas[0], "Mara · Lancero · 35 / 70 HP")
	_igual("que hace la ligera", lineas[1], "L · Toque: +18 HP")
	_igual("y una raya si la pesada no tiene nada", lineas[2], "P · —")

	_combos.equipar([toque, vendaje, plegaria, bendicion, reanimar] as Array[Movimiento])
	lineas = TarjetaObjetivo.lineas(_healer)
	_igual("sin combo, la pesada es la Plegaria, con lo que se pierde", lineas[2],
		"P · Plegaria: +35 HP (5 se desperdician)")
	_ok("el Vendaje todavia no aparece: no es lo que sale", not _texto(lineas).contains("Vendaje"))
	_ok("ni se habla de alcance: si esta en la tarjeta, esta al frente",
		not _texto(lineas).contains("alcance"))

	print("--- a mitad del combo, la tarjeta dice lo que sigue ---")
	_ok("la ligera sale", _healer.pulsar(&"ligera"))
	lineas = TarjetaObjetivo.lineas(_healer)
	_contiene("la ligera ya es el Vendaje, que corta el sangrado", lineas[1],
		"L · Vendaje: corta el sangrado")
	_contiene("y la pesada, la Bendicion", lineas[2], "P · Bendicion")
	_combos.cortar_combo(&"tiempo")
	_contiene("cortado el combo, vuelve el Toque", TarjetaObjetivo.lineas(_healer)[1], "L · Toque")

	print("--- con un caido adelante, la pesada es para el ---")
	var caido := _crear()
	caido.recibir_dano(500.0)
	lineas = TarjetaObjetivo.lineas(_healer)
	_igual("el de arriba sigue siendo el que esta en pie", lineas[0].get_slice(" · ", 0), "Mara")
	_contiene("y la pesada dice con cuanto levanta al caido", lineas[2],
		"P · Reanimar: lo levanta con")
	caido.free()

	print("--- sin nadie adelante, solo los nombres ---")
	paciente.global_position = ORIGEN + Vector3(6.0, 0, 0)
	await physics_frame
	await physics_frame
	_ok("fuera de la caja ya no es el de la tarjeta", _healer.unidad_apuntada() == null)
	lineas = TarjetaObjetivo.lineas(_healer)
	_igual("nadie al frente", lineas[0], TarjetaObjetivo.NADIE)
	_igual("la ligera, sin numeros", lineas[1], "L · Toque")
	_igual("la pesada, igual", lineas[2], "P · Plegaria")

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Lancero sin azar ni fisica, a 0.8 m al frente del healer.
func _crear() -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/lancero.tres"))
	u.sembrar(1)
	u.position = ORIGEN + Vector3(0.8, 0, 0)
	_contenedor.add_child(u)
	u.set_physics_process(false)
	u.probabilidad_sangrado = 0.0
	return u


func _texto(lineas: PackedStringArray) -> String:
	return "\n".join(lineas)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _contiene(que: String, texto: String, fragmento: String) -> void:
	_ok("%s (%s)" % [que, texto], texto.contains(fragmento))


func _igual(que: String, obtenido: String, esperado: String) -> void:
	_ok("%s [%s]" % [que, obtenido], obtenido == esperado)
