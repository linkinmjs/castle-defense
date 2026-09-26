class_name FichaJugador
extends PanelContainer
## La ficha de un jugador, en su esquina del HUD: quien es, como esta su healer,
## que le acaba de pasar y que saldria ahora con cada boton.
##
## Junta lo que el HUD de un solo jugador tenia repartido por la pantalla: las
## barras, el combo y los avisos abajo a la izquierda, la tarjeta del objetivo
## abajo a la derecha. Con dos jugadores cada uno tiene que encontrar lo suyo
## en un solo lugar, y que ese lugar no sea el del otro.
##
## Los nodos los arma tools/gen_hud.gd, iguales en las dos fichas; esto los
## llena. Casi todo sale de las senales del healer y de su ComponenteCombos. La
## tarjeta no: quien esta al frente, su vida y lo que saldria con cada boton
## cambian aunque el healer no avise nada, asi que se rearma en cada frame.

const DURACION_AVISO := 1.8
## Un golpe al aire se avisa, pero mas bajo: el jugador ya vio que no paso
## nada, y un aviso a pleno taparia uno que si importa ("Sin mana", "+18").
const ALFA_VACIO := 0.5
## Cuanto queda en pantalla el remate despues de cerrar el combo. Los demas
## cortes (un golpe, uno al aire, el tiempo) lo apagan en el acto: no hay
## nada que festejar.
const DURACION_REMATE := 1.2
## Un renglon de la tarjeta que no dice nada util (nadie al frente, un boton
## sin movimiento) se sigue viendo, para que la ficha no cambie de alto, pero
## apagado.
const ALFA_APAGADO := 0.45

## De que jugador es. Lo pone el generador y seguir() lo confirma con el healer
## que recibe.
@export_range(1, 2) var jugador: int = 1

var _healer: Healer3D
var _combos: ComponenteCombos
var _tiempo_aviso: float = 0.0
## Hasta donde sube la opacidad del aviso actual: 1, o menos si es de los que
## se dicen bajo.
var _alfa_aviso: float = 1.0
## Lo que falta del festejo de un remate. 0 = el combo se muestra fijo
## mientras dure, o no se muestra.
var _tiempo_remate: float = 0.0
## Los renglones de la tarjeta que estan pintados. Si no cambiaron no se
## vuelven a aplicar: cada override de color hace rearmar el texto.
var _tarjeta: Array[Dictionary] = []

@onready var _titulo: Label = $Columna/Cabecera/Titulo
@onready var _combo: Label = $Columna/Cabecera/Combo
@onready var _barra_vida: ProgressBar = $Columna/Vida/BarraVida
@onready var _texto_vida: Label = $Columna/Vida/TextoVida
@onready var _barra_mana: ProgressBar = $Columna/Mana/BarraMana
@onready var _texto_mana: Label = $Columna/Mana/TextoMana
@onready var _aviso: Label = $Columna/Aviso
## Quien esta al frente, la ligera y la pesada, en el orden de
## TarjetaObjetivo.renglones().
@onready var _renglones: Array[Label] = [
	$Columna/Objetivo, $Columna/Ligera, $Columna/Pesada,
]


func _ready() -> void:
	_pintar_titulo()
	_combo.text = ""
	_ocultar_combo()
	_aviso.text = ""
	_aviso.modulate.a = 0.0
	_refrescar_tarjeta()


## Empieza a mostrar a este healer. Con el que ya mostraba no hace nada, y con
## otro suelta al anterior: una senal conectada dos veces mostraria cada aviso
## dos veces, y una que quedara del anterior mezclaria a dos healers.
func seguir(healer: Healer3D) -> void:
	if healer == null or healer == siguiendo():
		return
	_soltar()
	_healer = healer
	_combos = healer.get_node("Combos") as ComponenteCombos
	jugador = healer.jugador
	_pintar_titulo()
	for conexion in _conexiones():
		var senal: Signal = conexion[0]
		senal.connect(conexion[1])
	_on_vida_cambio(healer.vida, healer.vida_maxima)
	_on_mana_cambio(healer.mana, healer.mana_maximo)
	_refrescar_tarjeta()


## El healer que muestra, o null si todavia no sigue a nadie o el que seguia
## ya no existe.
func siguiendo() -> Healer3D:
	return _healer if is_instance_valid(_healer) else null


func _process(delta: float) -> void:
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		_aviso.modulate.a = clampf(_tiempo_aviso / DURACION_AVISO, 0.0, 1.0) * _alfa_aviso

	if _tiempo_remate > 0.0:
		_tiempo_remate -= delta
		_combo.modulate.a = clampf(_tiempo_remate / DURACION_REMATE, 0.0, 1.0)
		if _tiempo_remate <= 0.0:
			_ocultar_combo()

	_refrescar_tarjeta()


# --- Lo que leen las pruebas y el HUD -----------------------------------------

## "Jugador 1".
func titulo() -> String:
	return _titulo.text


## "48 / 60".
func texto_vida() -> String:
	return _texto_vida.text


func texto_mana() -> String:
	return _texto_mana.text


## "x2 VENDAJE", aunque ya no se vea: el texto queda para festejar el remate.
func texto_combo() -> String:
	return _combo.text


func texto_aviso() -> String:
	return _aviso.text


## Menos de 1 si el aviso actual es de los que se dicen bajo o se esta yendo.
func opacidad_aviso() -> float:
	return _aviso.modulate.a


## Si el combo se esta viendo.
func combo_visible() -> bool:
	return _combo.text != "" and _combo.modulate.a > 0.0


## Lo que dice la tarjeta ahora, renglon por renglon: quien esta al frente, la
## ligera y la pesada. Se calcula en el momento, no se lee de los Labels.
func lineas_tarjeta() -> PackedStringArray:
	return TarjetaObjetivo.lineas(_healer_en_juego())


# --- Healer -------------------------------------------------------------------

## Las senales que mueven la ficha, en un solo lugar: seguir() las conecta y
## _soltar() las desconecta recorriendo la misma lista.
func _conexiones() -> Array[Array]:
	return [
		[_healer.vida_cambio, _on_vida_cambio],
		[_healer.mana_cambio, _on_mana_cambio],
		[_healer.aviso, _on_aviso],
		[_healer.combo_cambio, _on_combo_cambio],
		# Lo que conecto ("+18", "Reanimado") y lo que no ("Sin mana", "En
		# vacio") lo avisa el componente, que es el que sabe que paso.
		[_combos.aviso, _on_aviso],
		[_combos.movimiento_fallo, _on_movimiento_fallo],
		[_combos.combo_cortado, _on_combo_cortado],
	]


func _soltar() -> void:
	if is_instance_valid(_healer) and is_instance_valid(_combos):
		for conexion in _conexiones():
			var senal: Signal = conexion[0]
			if senal.is_connected(conexion[1]):
				senal.disconnect(conexion[1])
	_healer = null
	_combos = null
	_combo.text = ""
	_ocultar_combo()


## El healer, si todavia esta en el campo. La tarjeta pregunta por lo que tiene
## al frente, y eso necesita el arbol.
func _healer_en_juego() -> Healer3D:
	var healer := siguiendo()
	return healer if healer != null and healer.is_inside_tree() else null


## "Jugador 1", del color de su marca en el campo: asi cada uno sabe cual de
## las dos elipses es la suya.
func _pintar_titulo() -> void:
	_titulo.text = "Jugador %d" % jugador
	_titulo.add_theme_color_override("font_color", OverlayUnidades.color_jugador(jugador))


func _on_vida_cambio(actual: float, maximo: float) -> void:
	_barra_vida.max_value = maximo
	_barra_vida.value = actual
	_texto_vida.text = "%d / %d" % [actual, maximo]


func _on_mana_cambio(actual: float, maximo: float) -> void:
	_barra_mana.max_value = maximo
	_barra_mana.value = actual
	_texto_mana.text = "%d / %d" % [actual, maximo]


# --- Combo y avisos -----------------------------------------------------------

## "x2 VENDAJE" mientras el combo siga abierto, del color del movimiento. Con
## cuenta 0 se apaga, salvo que el corte sea un remate: eso lo decide
## _on_combo_cortado, que llega justo despues y vuelve a mostrar el ultimo
## texto.
func _on_combo_cambio(cuenta: int, nombre: String) -> void:
	if cuenta <= 0:
		_ocultar_combo()
		return
	_combo.text = "x%d %s" % [cuenta, nombre.to_upper()]
	var mov: Movimiento = _combos.movimiento_por_nombre(nombre) if _combos != null else null
	if mov != null:
		_combo.add_theme_color_override("font_color", mov.color)
	else:
		_combo.remove_theme_color_override("font_color")
	_combo.modulate.a = 1.0
	_tiempo_remate = 0.0


func _on_combo_cortado(motivo: StringName) -> void:
	if motivo != &"remate" or _combo.text == "":
		return
	_combo.modulate.a = 1.0
	_tiempo_remate = DURACION_REMATE


## Oculto con transparencia y no con visible: el renglon sigue ocupando su
## lugar y la ficha no cambia de alto cada vez que un combo empieza o se corta.
## El texto queda: es el que festeja el remate.
func _ocultar_combo() -> void:
	_tiempo_remate = 0.0
	_combo.modulate.a = 0.0


func _on_movimiento_fallo(_mov: Movimiento, motivo: String) -> void:
	_mostrar_aviso(motivo, ALFA_VACIO if motivo == ComponenteCombos.EN_VACIO else 1.0)


func _on_aviso(texto: String) -> void:
	_mostrar_aviso(texto)


func _mostrar_aviso(texto: String, alfa: float = 1.0) -> void:
	if texto == "":
		return
	_aviso.text = texto
	_alfa_aviso = alfa
	_tiempo_aviso = DURACION_AVISO
	_aviso.modulate.a = alfa


# --- Tarjeta ------------------------------------------------------------------

## Pinta los tres renglones de TarjetaObjetivo: el texto, el color del
## movimiento si lo tiene y apagado si no dice nada que sirva.
func _refrescar_tarjeta() -> void:
	var nuevos := TarjetaObjetivo.renglones(_healer_en_juego())
	if nuevos == _tarjeta:
		return
	_tarjeta = nuevos
	for i in _renglones.size():
		var etiqueta := _renglones[i]
		var renglon: Dictionary = nuevos[i]
		etiqueta.text = renglon["texto"]
		if renglon.has("color"):
			etiqueta.add_theme_color_override("font_color", renglon["color"])
		else:
			etiqueta.remove_theme_color_override("font_color")
		etiqueta.modulate.a = ALFA_APAGADO if renglon["apagado"] else 1.0
