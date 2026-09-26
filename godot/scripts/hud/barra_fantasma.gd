class_name BarraFantasma
extends Control
## Una barra de vida con fantasma de dano, como en los beat-em-up: al recibir
## un golpe la vida baja en el acto y detras queda una segunda barra, mas
## oscura, que la alcanza despues. El hueco entre las dos es lo que costo el
## golpe, y se lee sin mirar el numero.
##
## La usan la ficha de cada jugador y la barra del jefe. Las dos barras las
## arma el generador del HUD (Fantasma atras, con el fondo; Vida adelante, con
## fondo transparente) y esto las mueve. Al curarse la vida sube suave y el
## fantasma nunca queda por debajo de ella.

## El fantasma espera un instante antes de bajar: si arrancara con el golpe,
## el hueco no se llegaria a ver.
const ESPERA := 0.2
const BAJADA := 0.6
## Constante de tiempo de la subida al curarse, en segundos: recorre el 63%
## de lo que falta en ese tiempo. Es un seguimiento y no un tween porque la
## vida puede cambiar varias veces en medio (una cura por tick).
const SUBIDA := 0.08

## La vida de verdad, la ultima que llego.
var _objetivo: float = 0.0
var _tween: Tween

@onready var _fantasma: ProgressBar = $Fantasma
@onready var _vida: ProgressBar = $Vida


func _ready() -> void:
	# Sin pasos: con el default (0.01 del maximo en Range) el fantasma bajaria a
	# saltos en una barra de 1200 de vida.
	for barra: ProgressBar in [_fantasma, _vida]:
		barra.step = 0.0
		barra.show_percentage = false


## La vida nueva. Inmediato es para arrancar o cambiar de dueno: sin
## fantasma ni subida, las dos barras quedan donde corresponde.
func fijar(actual: float, maximo: float, inmediato: bool = false) -> void:
	_fantasma.max_value = maxf(maximo, 0.001)
	_vida.max_value = maxf(maximo, 0.001)
	if inmediato:
		_cortar()
		_objetivo = actual
		_vida.value = actual
		_fantasma.value = actual
		return

	if actual < _objetivo:
		# Golpe: la vida baja ya. El fantasma se queda donde estaba y la
		# alcanza; si ya venia bajando de otro golpe sigue sin volver a
		# esperar, o bajo una lluvia de golpes no bajaria nunca.
		var en_reposo := _fantasma.value <= _objetivo + 0.001
		_vida.value = actual
		_cortar()
		_tween = create_tween()
		_tween.tween_property(_fantasma, "value", actual, BAJADA) \
			.set_delay(ESPERA if en_reposo else 0.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif actual > _objetivo and _fantasma.value < actual:
		# Cura: el fantasma no puede quedar escondido debajo de la vida.
		_cortar()
		_fantasma.value = actual
	_objetivo = actual


## La vida que se esta dibujando (puede ir atras de la real mientras sube).
func valor() -> float:
	return _vida.value


## Donde esta el fantasma. Mayor que valor() mientras queda hueco por bajar.
func fantasma() -> float:
	return _fantasma.value


func objetivo() -> float:
	return _objetivo


func _process(delta: float) -> void:
	if _vida.value >= _objetivo:
		return
	var nuevo := lerpf(_vida.value, _objetivo, 1.0 - exp(-delta / SUBIDA))
	_vida.value = _objetivo if _objetivo - nuevo < 0.05 else nuevo


func _cortar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
