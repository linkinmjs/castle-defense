extends CanvasLayer
## HUD del prototipo: lo minimo para poder jugar y para leer como va la batalla.

const COLOR_MANA := Color("4a9fd4")
const COLOR_VIDA := Color("c94b3f")
const DURACION_AVISO := 1.8
## Un golpe al aire se avisa, pero mas bajo: el jugador ya vio que no paso
## nada, y un aviso a pleno taparia uno que si importa ("Sin mana", "+18").
const ALFA_VACIO := 0.5
## Cuanto queda en pantalla el remate despues de cerrar el combo. Los demas
## cortes (un golpe, uno al aire, el tiempo) lo apagan en el acto: no hay
## nada que festejar.
const DURACION_REMATE := 1.2

@onready var _barra_mana: ProgressBar = %BarraMana
@onready var _texto_mana: Label = %TextoMana
@onready var _barra_vida: ProgressBar = %BarraVida
@onready var _texto_vida: Label = %TextoVida
@onready var _contadores: Label = %Contadores
@onready var _aviso: Label = %Aviso
@onready var _combo: Label = %Combo
@onready var _leyenda: Label = %Leyenda
@onready var _frente: Control = %Frente
@onready var _desenlace: Label = %Desenlace
@onready var _tarjeta: Control = %Tarjeta
@onready var _encabezado: Label = %Encabezado
@onready var _resumen: Control = %Resumen

var _tiempo_aviso: float = 0.0
## Hasta donde sube la opacidad del aviso actual: 1, o menos si es de los que
## se dicen bajo.
var _alfa_aviso: float = 1.0
## Lo que falta del festejo de un remate. 0 = el combo se muestra fijo
## mientras dure, o no se muestra.
var _tiempo_remate: float = 0.0
var _battle: Node
var _encuentro: Encuentro


func _ready() -> void:
	_estilizar(_barra_mana, COLOR_MANA)
	_estilizar(_barra_vida, COLOR_VIDA)
	_aviso.modulate.a = 0.0
	_combo.text = ""
	_ocultar_combo()
	_desenlace.visible = false
	_resumen.visible = false


func _estilizar(barra: ProgressBar, color: Color) -> void:
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	relleno.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("fill", relleno)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.55)
	barra.add_theme_stylebox_override("background", fondo)


## La batalla llama a esto cuando el healer ya esta en el arbol.
func seguir(healer: Node) -> void:
	healer.mana_cambio.connect(_on_mana_cambio)
	healer.vida_cambio.connect(_on_vida_cambio)
	healer.aviso.connect(_on_aviso)
	healer.combo_cambio.connect(_on_combo_cambio)
	_on_mana_cambio(healer.mana, healer.mana_maximo)
	_on_vida_cambio(healer.vida, healer.vida_maxima)

	# El aviso de lo que conecto ("+18", "Reanimado") y el de lo que no ("Sin
	# mana", "En vacio") salen del componente, que es el que sabe que paso.
	var combos: ComponenteCombos = healer.get_node("Combos")
	combos.aviso.connect(_on_aviso)
	combos.movimiento_fallo.connect(_on_movimiento_fallo)
	combos.combo_cortado.connect(_on_combo_cortado)
	_tarjeta.seguir(healer, combos)
	_leyenda.seguir(healer)


func seguir_batalla(battle: Node) -> void:
	_battle = battle
	battle.batalla_terminada.connect(_on_batalla_terminada)
	battle.encuentro_iniciado.connect(_on_encuentro_iniciado)
	battle.telemetria().encuentro_cerrado.connect(_on_encuentro_cerrado)
	_frente.seguir(battle)


func _process(delta: float) -> void:
	var aliados := "Aliados %d" % _vivos("aliados")
	var caidos := _derribados("aliados")
	if caidos > 0:
		aliados += "  (%d en el suelo)" % caidos
	_contadores.text = "%s      Enemigos %d" % [aliados, _vivos("enemigos")]

	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		_aviso.modulate.a = clampf(_tiempo_aviso / DURACION_AVISO, 0.0, 1.0) * _alfa_aviso

	if _tiempo_remate > 0.0:
		_tiempo_remate -= delta
		_combo.modulate.a = clampf(_tiempo_remate / DURACION_REMATE, 0.0, 1.0)
		if _tiempo_remate <= 0.0:
			_ocultar_combo()


func _on_mana_cambio(actual: float, maximo: float) -> void:
	_barra_mana.max_value = maximo
	_barra_mana.value = actual
	_texto_mana.text = "%d / %d" % [actual, maximo]


func _on_vida_cambio(actual: float, maximo: float) -> void:
	_barra_vida.max_value = maximo
	_barra_vida.value = actual
	_texto_vida.text = "%d / %d" % [actual, maximo]


func _on_movimiento_fallo(_mov: Movimiento, motivo: String) -> void:
	_mostrar_aviso(motivo, ALFA_VACIO if motivo == ComponenteCombos.EN_VACIO else 1.0)


## "x2 VENDAJE" mientras el combo siga abierto. Con cuenta 0 se apaga, salvo
## que el corte sea un remate: eso lo decide _on_combo_cortado, que llega justo
## despues y vuelve a mostrar el ultimo texto.
func _on_combo_cambio(cuenta: int, nombre: String) -> void:
	if cuenta <= 0:
		_ocultar_combo()
		return
	_combo.text = "x%d %s" % [cuenta, nombre.to_upper()]
	_combo.modulate.a = 1.0
	_tiempo_remate = 0.0


func _on_combo_cortado(motivo: StringName) -> void:
	if motivo != &"remate" or _combo.text == "":
		return
	_combo.modulate.a = 1.0
	_tiempo_remate = DURACION_REMATE


## Oculto con transparencia y no con visible: el renglon sigue ocupando su
## lugar, y el aviso de arriba no salta cada vez que un combo empieza o se
## corta. El texto queda: es el que festeja el remate.
func _ocultar_combo() -> void:
	_tiempo_remate = 0.0
	_combo.modulate.a = 0.0


## Si el combo se esta viendo: lo usan las pruebas y las capturas.
func combo_visible() -> bool:
	return _combo.text != "" and _combo.modulate.a > 0.0


func _on_encuentro_iniciado(encuentro: Encuentro, _semilla: int, indice: int) -> void:
	_encuentro = encuentro
	_desenlace.visible = false
	_resumen.ocultar()
	if encuentro == null:
		_encabezado.text = ""
		return
	_encabezado.text = "%d. %s\n%s" % [
		indice + 1, encuentro.titulo, encuentro.objetivo_pedagogico]


func _on_batalla_terminada(victoria: bool) -> void:
	# Sin el "R para reiniciar": ahora eso lo dice el pie del resumen, que sale
	# justo debajo y explica ademas que hace Enter.
	_desenlace.text = "VICTORIA" if victoria else "DERROTA"
	_desenlace.add_theme_color_override("font_color",
		Color("9fd88f") if victoria else Color("e07a6a"))
	_desenlace.visible = true


## El desenlace dice como termino; esto, por que. Los datos llegan como
## Dictionary y texto plano: el HUD no conoce la telemetria.
func _on_encuentro_cerrado(datos: Dictionary) -> void:
	var metas: Array[MetaEncuentro] = _encuentro.metas if _encuentro != null else []
	var titulo: String = _encuentro.titulo if _encuentro != null else "Encuentro"
	_resumen.mostrar(
		titulo, datos, _battle.telemetria().observacion_causal(), metas,
		"R / Back para repetir el mismo     Enter / Start para seguir")


func _on_aviso(texto: String) -> void:
	_mostrar_aviso(texto)


func _mostrar_aviso(texto: String, alfa: float = 1.0) -> void:
	if texto == "":
		return
	_aviso.text = texto
	_alfa_aviso = alfa
	_tiempo_aviso = DURACION_AVISO
	_aviso.modulate.a = alfa


func _derribados(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva() and unidad.esta_derribada():
			total += 1
	return total


func _vivos(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva():
			total += 1
	return total
