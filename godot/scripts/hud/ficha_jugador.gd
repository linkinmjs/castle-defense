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
## Se lee como la de un beat-em-up: la vida tiene fantasma (lo que costo el
## ultimo golpe se ve un instante detras), el mana se desliza en vez de
## saltar, el combo pega un golpe de escala en cada paso y una raya fina bajo
## la cabecera dice cuanto queda para encadenar. Mientras se reza una plegaria
## o se espera el suelo con la caida, el renglon del aviso se vuelve la barra
## de carga. Los dos renglones de abajo son los botones: el icono de lo que
## saldria (con el velo del enfriamiento), la tecla y la consecuencia.
##
## Los nodos los arma tools/gen_hud.gd, iguales en las dos fichas; esto los
## llena. Casi todo sale de las senales del healer y de su ComponenteCombos.
## Lo que corre con el reloj (la tarjeta, la ventana, la carga) se lee en cada
## frame: cambia aunque el healer no avise nada.

const DURACION_AVISO := 1.8
## Un golpe al aire se avisa, pero mas bajo: el jugador ya vio que no paso
## nada, y un aviso a pleno taparia uno que si importa ("Sin mana", "+18").
const ALFA_VACIO := 0.5
## Cuanto queda en pantalla el remate despues de cerrar el combo. Los demas
## cortes (un golpe, uno al aire, el tiempo) lo apagan en el acto: no hay
## nada que festejar.
const DURACION_REMATE := 1.2
## El renglon de quien esta al frente, cuando no hay nadie: se sigue viendo,
## para que la ficha no cambie de alto, pero apagado.
const ALFA_APAGADO := 0.45
## El golpe del combo: arranca grande y vuelve a su tamano. Corto, para que
## dos pasos seguidos se lean como dos golpes y no como uno largo.
const ESCALA_GOLPE := 1.4
const DURACION_GOLPE := 0.15
## Constante de tiempo con que el mana alcanza su valor, en segundos. No es un
## tween: el mana cambia en cada tick al regenerarse, y un tween por tick se
## pisaria con el siguiente.
const SUAVIZADO_MANA := 0.08
## Latidos por segundo del nombre de lo que se esta cargando.
const LATIDOS_CARGA := 3.0
## El marco de la ficha va del color del jugador, apenas.
const ALFA_MARCO := 0.55

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
var _mana_objetivo: float = 0.0
var _tween_golpe: Tween
## Reloj propio para el latido de la carga.
var _reloj: float = 0.0
## Lo que se esta cargando, para no repintar su nombre y color en cada frame.
var _mov_carga: Movimiento
## El renglon de quien esta al frente tal como esta pintado.
var _renglon_objetivo: Dictionary = {}

@onready var _titulo: Label = $Columna/Cabecera/Titulo
@onready var _combo: Label = $Columna/Cabecera/Combo
@onready var _ventana: ProgressBar = $Columna/Ventana/BarraVentana
@onready var _vida: BarraFantasma = $Columna/Vida/PilaVida
@onready var _texto_vida: Label = $Columna/Vida/TextoVida
@onready var _barra_mana: ProgressBar = $Columna/Mana/BarraMana
@onready var _texto_mana: Label = $Columna/Mana/TextoMana
@onready var _aviso: Label = $Columna/Estado/Aviso
@onready var _carga: Control = $Columna/Estado/Carga
@onready var _nombre_carga: Label = $Columna/Estado/Carga/NombreCarga
@onready var _barra_carga: ProgressBar = $Columna/Estado/Carga/BarraCarga
@onready var _objetivo: Label = $Columna/Objetivo
## La ligera y la pesada, en el orden de TarjetaObjetivo.BOTONES.
@onready var _lineas: Array[LineaMovimiento] = [$Columna/Ligera, $Columna/Pesada]


func _ready() -> void:
	for barra: ProgressBar in [_ventana, _barra_mana, _barra_carga]:
		barra.step = 0.0
		barra.show_percentage = false
	_pintar_titulo()
	_combo.text = ""
	_ocultar_combo()
	_aviso.text = ""
	_aviso.modulate.a = 0.0
	_ventana.visible = false
	_carga.visible = false
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
	# Al tomar un healer las barras van directo a su lugar: no hubo golpe que
	# mostrar ni mana que deslizar.
	_vida.fijar(healer.vida, healer.vida_maxima, true)
	_texto_vida.text = "%d / %d" % [healer.vida, healer.vida_maxima]
	_on_mana_cambio(healer.mana, healer.mana_maximo)
	_barra_mana.value = healer.mana
	_refrescar_tarjeta()


## El healer que muestra, o null si todavia no sigue a nadie o el que seguia
## ya no existe.
func siguiendo() -> Healer3D:
	return _healer if is_instance_valid(_healer) else null


func _process(delta: float) -> void:
	_reloj += delta
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		_aviso.modulate.a = clampf(_tiempo_aviso / DURACION_AVISO, 0.0, 1.0) * _alfa_aviso

	if _tiempo_remate > 0.0:
		_tiempo_remate -= delta
		_combo.modulate.a = clampf(_tiempo_remate / DURACION_REMATE, 0.0, 1.0)
		if _tiempo_remate <= 0.0:
			_ocultar_combo()

	if not is_equal_approx(_barra_mana.value, _mana_objetivo):
		var nuevo := lerpf(_barra_mana.value, _mana_objetivo, 1.0 - exp(-delta / SUAVIZADO_MANA))
		_barra_mana.value = _mana_objetivo if absf(_mana_objetivo - nuevo) < 0.05 else nuevo

	_refrescar_ventana()
	_refrescar_carga()
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


## La vida que dibuja la barra y donde va el fantasma: justo despues de un
## golpe el fantasma queda mas alto, y baja despues.
func vida_mostrada() -> float:
	return _vida.valor()


func fantasma_vida() -> float:
	return _vida.fantasma()


## El mana que dibuja la barra, que va detras del real mientras se desliza.
func mana_mostrado() -> float:
	return _barra_mana.value


## "x2 VENDAJE", aunque ya no se vea: el texto queda para festejar el remate.
func texto_combo() -> String:
	return _combo.text


## 1 en reposo; mas grande justo despues de un paso del combo.
func escala_combo() -> float:
	return _combo.offset_transform_scale.x


func texto_aviso() -> String:
	return _aviso.text


## Menos de 1 si el aviso actual es de los que se dicen bajo o se esta yendo.
func opacidad_aviso() -> float:
	return _aviso.modulate.a


## Si el combo se esta viendo.
func combo_visible() -> bool:
	return _combo.text != "" and _combo.modulate.a > 0.0


## La raya que dice cuanto queda para encadenar: se ve mientras quede ventana.
func ventana_visible() -> bool:
	return _ventana.visible


## Lo que queda de ventana, de 1 (recien conectado) a 0.
func fraccion_ventana() -> float:
	return _ventana.value


## La barra de carga: se ve mientras hay un movimiento en curso.
func carga_visible() -> bool:
	return _carga.visible


func progreso_carga() -> float:
	return _barra_carga.value


## El nombre de lo que se esta cargando ("Plegaria").
func texto_carga() -> String:
	return _nombre_carga.text


## Lo que dice la tarjeta ahora, renglon por renglon: quien esta al frente, la
## ligera y la pesada, con su tecla. Se calcula en el momento, no se lee de
## los nodos.
func lineas_tarjeta() -> PackedStringArray:
	return TarjetaObjetivo.lineas(_healer_en_juego())


## Lo que muestran los renglones de los botones, leido de los nodos: la
## tecla, el movimiento, el icono, si se enfria, si falta mana y el texto.
func estado_lineas() -> Array[Dictionary]:
	var estados: Array[Dictionary] = []
	for linea in _lineas:
		estados.append(linea.estado())
	return estados


## El renglon de quien esta al frente, tal como se ve.
func texto_objetivo() -> String:
	return _objetivo.text


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
	_mov_carga = null
	_carga.visible = false
	_aviso.visible = true
	_ventana.visible = false


## El healer, si todavia esta en el campo. La tarjeta pregunta por lo que tiene
## al frente, y eso necesita el arbol.
func _healer_en_juego() -> Healer3D:
	var healer := siguiendo()
	return healer if healer != null and healer.is_inside_tree() else null


## El componente, si el healer sigue en juego.
func _combos_en_juego() -> ComponenteCombos:
	return _combos if _healer_en_juego() != null and is_instance_valid(_combos) else null


## "Jugador 1", del color de su marca en el campo: asi cada uno sabe cual de
## las dos elipses es la suya. El marco de la ficha lleva el mismo color.
func _pintar_titulo() -> void:
	var color := OverlayUnidades.color_jugador(jugador)
	_titulo.text = "Jugador %d" % jugador
	_titulo.add_theme_color_override("font_color", color)
	var caja := get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if caja != null:
		caja.border_color = Color(color, ALFA_MARCO)
		add_theme_stylebox_override(&"panel", caja)


func _on_vida_cambio(actual: float, maximo: float) -> void:
	_vida.fijar(actual, maximo)
	_texto_vida.text = "%d / %d" % [actual, maximo]


## El numero cambia ya; la barra lo alcanza en _process.
func _on_mana_cambio(actual: float, maximo: float) -> void:
	_barra_mana.max_value = maxf(maximo, 0.001)
	_mana_objetivo = actual
	_texto_mana.text = "%d / %d" % [actual, maximo]


# --- Combo y avisos -----------------------------------------------------------

## "x2 VENDAJE" mientras el combo siga abierto, del color del movimiento, con
## un golpe de escala en cada paso. Con cuenta 0 se apaga, salvo que el corte
## sea un remate: eso lo decide _on_combo_cortado, que llega justo despues y
## vuelve a mostrar el ultimo texto.
func _on_combo_cambio(cuenta: int, nombre: String) -> void:
	if cuenta <= 0:
		_ocultar_combo()
		return
	_combo.text = "x%d %s" % [cuenta, nombre.to_upper()]
	var mov: Movimiento = _combos.movimiento_por_nombre(nombre) if _combos != null else null
	if mov != null:
		_combo.add_theme_color_override("font_color", mov.color)
		_pintar_relleno(_ventana, mov.color)
	else:
		_combo.remove_theme_color_override("font_color")
	_combo.modulate.a = 1.0
	_tiempo_remate = 0.0
	_golpe_combo()


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


## 1.4 -> 1 en 0.15 s. Sobre la transformacion visual y no sobre scale: el
## combo esta en un contenedor, y asi no se rearma la cabecera en cada paso.
func _golpe_combo() -> void:
	if _tween_golpe != null and _tween_golpe.is_valid():
		_tween_golpe.kill()
	_combo.offset_transform_scale = Vector2(ESCALA_GOLPE, ESCALA_GOLPE)
	_tween_golpe = create_tween()
	_tween_golpe.tween_property(_combo, "offset_transform_scale", Vector2.ONE, DURACION_GOLPE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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


# --- Relojes del combo --------------------------------------------------------

## La raya bajo la cabecera: se vacia con la ventana del combo y se va a 0.
func _refrescar_ventana() -> void:
	var combos := _combos_en_juego()
	var fraccion := 0.0
	if combos != null:
		fraccion = clampf(combos.ventana_restante() / ComponenteCombos.VENTANA, 0.0, 1.0)
	_ventana.visible = fraccion > 0.0
	_ventana.value = fraccion


## Mientras algo carga, el renglon del aviso muestra que y cuanto falta: el
## nombre late y la barra se llena hasta que sale. El aviso vuelve solo al
## terminar, y lo primero que dice es como salio.
func _refrescar_carga() -> void:
	var combos := _combos_en_juego()
	var mov: Movimiento = combos.movimiento_en_curso() if combos != null else null
	if mov == null:
		if _carga.visible:
			_carga.visible = false
			_aviso.visible = true
		_mov_carga = null
		return
	if mov != _mov_carga:
		_mov_carga = mov
		_nombre_carga.text = mov.nombre
		_nombre_carga.add_theme_color_override("font_color", mov.color)
		_pintar_relleno(_barra_carga, mov.color)
	_carga.visible = true
	_aviso.visible = false
	_barra_carga.value = combos.progreso_en_curso()
	var latido := 0.5 + 0.5 * cos(_reloj * TAU * LATIDOS_CARGA)
	_nombre_carga.modulate.a = lerpf(0.45, 1.0, latido)


## El relleno de una barra en otro color, sobre una copia del estilo del tema.
func _pintar_relleno(barra: ProgressBar, color: Color) -> void:
	var caja := barra.get_theme_stylebox(&"fill").duplicate() as StyleBoxFlat
	if caja == null:
		return
	caja.bg_color = color
	barra.add_theme_stylebox_override(&"fill", caja)


# --- Tarjeta ------------------------------------------------------------------

## Quien esta al frente arriba, y un renglon por boton. Cada parte repinta
## solo lo que cambio.
func _refrescar_tarjeta() -> void:
	var nuevos := TarjetaObjetivo.renglones(_healer_en_juego())
	var paciente: Dictionary = nuevos[0]
	if paciente != _renglon_objetivo:
		_renglon_objetivo = paciente
		_objetivo.text = paciente["texto"]
		_objetivo.modulate.a = ALFA_APAGADO if paciente["apagado"] else 1.0
	for i in _lineas.size():
		_lineas[i].mostrar(nuevos[i + 1])
