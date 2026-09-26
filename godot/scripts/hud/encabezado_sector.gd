class_name EncabezadoSector
extends Control
## Que encuentro es, que enseña y en que sector va la batalla.
##
## Al arrancar un encuentro el titulo entra grande desde arriba con el
## objetivo pedagogico debajo, se queda unos segundos y se encoge a un
## renglon chico que queda puesto: el objetivo es la gracia de cada leccion y
## tiene que poder releerse jugando. Cada sector nuevo se anuncia con la misma
## entrada ("Sector 2 · Puente") y se va solo.
##
## Los carteles no se pisan. El del sector que arranca junto con el encuentro
## espera a que termine el del encuentro: si lo reemplazara, el objetivo no se
## llegaria a leer.
##
## Los nodos los arma tools/gen_hud.gd: Linea (el renglon que queda) y Cartel
## (Titulo y Subtitulo), que se dibuja por encima de lo que sigue en la
## columna. El alto de esto es el del renglon: el cartel entra y sale sin
## empujar a nadie.

const ENTRADA := 0.4
const QUEDA_ENCUENTRO := 3.0
const QUEDA_SECTOR := 2.5
const SALIDA := 0.35
## Hasta donde se achica el cartel del encuentro al volverse renglon.
const ESCALA_RENGLON := 0.3
const SEPARADOR := " · "

enum Anuncio { NINGUNO, ENCUENTRO, SECTOR }

var _tween: Tween
var _anuncio: Anuncio = Anuncio.NINGUNO
## El texto de un sector que llego mientras se anunciaba el encuentro.
var _pendiente: String = ""

@onready var _linea: Label = $Linea
@onready var _cartel: Control = $Cartel
@onready var _titulo: Label = $Cartel/Titulo
@onready var _subtitulo: Label = $Cartel/Subtitulo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linea.minimum_size_changed.connect(update_minimum_size)
	_cartel.visible = false
	_linea.text = ""


func _get_minimum_size() -> Vector2:
	if _linea == null:
		return Vector2.ZERO
	return Vector2(0.0, _linea.get_combined_minimum_size().y)


func seguir(battle: Node) -> void:
	if battle.has_signal(&"encuentro_iniciado"):
		battle.connect(&"encuentro_iniciado", _on_encuentro_iniciado)
	if battle.has_signal(&"sector_iniciado"):
		battle.connect(&"sector_iniciado", _on_sector_iniciado)
	if battle.has_signal(&"batalla_terminada"):
		battle.connect(&"batalla_terminada", _on_batalla_terminada)


## Saca el cartel y lo que esperaba turno; el renglon queda. Al terminar la
## batalla el centro es del desenlace, y un sector anunciado encima de
## "VICTORIA" diria que el nivel sigue.
func callar() -> void:
	_cortar()
	_pendiente = ""
	_anuncio = Anuncio.NINGUNO
	_cartel.visible = false
	_cartel.offset_transform_scale = Vector2.ONE
	_cartel.offset_transform_position = Vector2.ZERO
	if _linea.text != "":
		_linea.modulate.a = 1.0


## "1. Mantener la linea" grande, el objetivo debajo, y despues el renglon.
func mostrar_encuentro(encuentro: Object, indice: int) -> void:
	_pendiente = ""
	if encuentro == null:
		_cortar()
		_anuncio = Anuncio.NINGUNO
		_cartel.visible = false
		_linea.text = ""
		return
	var titulo := _texto_de(encuentro, &"titulo")
	var objetivo := _texto_de(encuentro, &"objetivo_pedagogico")
	var renglon := "%d. %s" % [indice + 1, titulo]
	if objetivo != "":
		renglon += SEPARADOR + objetivo
	_linea.text = renglon
	# El renglon aparece cuando el cartel se encoge: antes diria lo mismo dos
	# veces.
	_linea.modulate.a = 0.0
	_anunciar(Anuncio.ENCUENTRO, "%d. %s" % [indice + 1, titulo], objetivo)


## "Sector 2 · Puente". El indice llega desde 0, como el de los encuentros.
func mostrar_sector(indice: int, sector: Variant) -> void:
	var titulo := _texto_de(sector, &"titulo")
	var texto := "Sector %d" % (indice + 1)
	if titulo != "":
		texto += SEPARADOR + titulo
	if _anuncio == Anuncio.ENCUENTRO:
		_pendiente = texto
		return
	_anunciar(Anuncio.SECTOR, texto, "")


# --- Lo que leen las pruebas --------------------------------------------------

## Lo que dice el cartel grande, se vea o no.
func texto_cartel() -> String:
	return _titulo.text


func subtitulo_cartel() -> String:
	return _subtitulo.text


func cartel_visible() -> bool:
	return _cartel.visible


## "encuentro", "sector" o "" si no se anuncia nada.
func anunciando() -> String:
	match _anuncio:
		Anuncio.ENCUENTRO:
			return "encuentro"
		Anuncio.SECTOR:
			return "sector"
	return ""


## El sector que espera a que termine el cartel del encuentro, o "".
func pendiente() -> String:
	return _pendiente


## "1. Mantener la linea · Curar a tiempo sostiene el frente."
func texto_linea() -> String:
	return _linea.text


func linea_visible() -> bool:
	return _linea.visible and _linea.modulate.a > 0.0 and _linea.text != ""


# --- Carteles -----------------------------------------------------------------

## Entra desde arriba (fuera de la pantalla) con un rebote corto, se queda y
## se va: el del encuentro encogiendose hacia el renglon, el de un sector
## subiendo por donde vino.
func _anunciar(anuncio: Anuncio, titulo: String, subtitulo: String) -> void:
	_cortar()
	_anuncio = anuncio
	_titulo.text = titulo
	_subtitulo.text = subtitulo
	_subtitulo.visible = subtitulo != ""
	_cartel.visible = true
	_cartel.modulate.a = 0.0
	_cartel.offset_transform_scale = Vector2.ONE
	var arriba := Vector2(0.0, -_distancia_entrada())
	_cartel.offset_transform_position = arriba

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_cartel, "offset_transform_position", Vector2.ZERO, ENTRADA) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_cartel, "modulate:a", 1.0, ENTRADA * 0.5)
	_tween.chain().tween_interval(
		QUEDA_ENCUENTRO if anuncio == Anuncio.ENCUENTRO else QUEDA_SECTOR)
	if anuncio == Anuncio.ENCUENTRO:
		_tween.chain().tween_property(_cartel, "offset_transform_scale",
			Vector2(ESCALA_RENGLON, ESCALA_RENGLON), SALIDA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_cartel, "modulate:a", 0.0, SALIDA)
		_tween.parallel().tween_property(_linea, "modulate:a", 1.0, SALIDA) \
			.set_delay(SALIDA * 0.5)
	else:
		_tween.chain().tween_property(_cartel, "offset_transform_position", arriba, SALIDA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_cartel, "modulate:a", 0.0, SALIDA)
	_tween.chain().tween_callback(_termino)


func _termino() -> void:
	_cartel.visible = false
	_cartel.offset_transform_scale = Vector2.ONE
	_cartel.offset_transform_position = Vector2.ZERO
	_anuncio = Anuncio.NINGUNO
	if _pendiente != "":
		var texto := _pendiente
		_pendiente = ""
		_anunciar(Anuncio.SECTOR, texto, "")


## Lo que hay que subirlo para que arranque fuera de la pantalla: hasta donde
## esta, mas su alto.
func _distancia_entrada() -> float:
	var alto := maxf(_cartel.get_combined_minimum_size().y, 64.0)
	return _cartel.global_position.y + alto + 8.0


func _cortar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Una propiedad de texto de un recurso que no se tipa (el Sector es de otro
## paquete), o "" si no la tiene.
static func _texto_de(fuente: Variant, propiedad: StringName) -> String:
	if fuente == null or not (fuente is Object) or not is_instance_valid(fuente):
		return ""
	var valor: Variant = (fuente as Object).get(propiedad)
	return str(valor) if valor != null else ""


func _on_encuentro_iniciado(encuentro: Object, _semilla: int, indice: int) -> void:
	mostrar_encuentro(encuentro, indice)


func _on_sector_iniciado(indice: int, sector: Variant) -> void:
	mostrar_sector(indice, sector)


func _on_batalla_terminada(_victoria: bool) -> void:
	callar()
