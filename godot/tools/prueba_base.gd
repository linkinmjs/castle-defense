class_name PruebaBase
extends SceneTree
## Lo que repetia cada suite headless: un tick por paso de fisica, fases
## numeradas, un limite para no colgarse y el mismo formato de salida.
##
## Por paso de fisica y no por frame: ahi corren los relojes del juego. Un
## frame lento mete varios pasos seguidos sin ningun _process en el medio, y
## una prueba que contara frames veria el campo en un tick que no es el suyo.
##
## Una suite nueva extiende esta, arma la escena en preparar() y reparte las
## comprobaciones en fase(). Las suites viejas no la usan.

var _fallos := 0
var _fase := 0
## Ticks desde que empezo la fase actual.
var _ticks := 0
## Mas ticks que esto en una misma fase es que se quedo esperando algo que no
## va a pasar.
var _limite_ticks := 900


func _initialize() -> void:
	physics_frame.connect(_tick)
	preparar()


## Arma lo que la prueba necesita. Corre antes del primer tick, cuando todavia
## no se ejecuto el _ready de nada de lo que se agregue al arbol.
func preparar() -> void:
	pass


## Se llama en cada tick con la fase en curso. La suite decide ahi si ya puede
## comprobar o si sigue esperando.
func fase(_numero: int) -> void:
	pass


func _tick() -> void:
	_ticks += 1
	fase(_fase)
	if _ticks > _limite_ticks:
		print("FALLA: la fase %d no termino en %d ticks" % [_fase, _limite_ticks])
		_desengancharse()
		quit(1)


func siguiente() -> void:
	_fase += 1
	_ticks = 0


func terminar() -> void:
	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	_desengancharse()
	quit(1 if _fallos > 0 else 0)


## quit() recien corta al terminar el paso de fisica en curso: sin esto, una
## fase podria volver a comprobar y ensuciar la salida.
func _desengancharse() -> void:
	if physics_frame.is_connected(_tick):
		physics_frame.disconnect(_tick)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float, tolerancia := 0.01) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-44s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])


func _contiene(que: String, texto: String, fragmento: String) -> void:
	if not texto.contains(fragmento):
		_fallos += 1
		print("  [FALLA] %s -> \"%s\"" % [que, texto])
		return
	print("  [OK] %s" % que)


## Un evento de accion ya apretado, para pasarle a _unhandled_input o a
## Input.parse_input_event sin depender de que tecla tenga asignada.
func accion(nombre: StringName) -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = true
	return evento
