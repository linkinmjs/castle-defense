class_name ComponenteHabilidades
extends Node
## Corre las habilidades de su nodo padre: valida mana y enfriamiento, ejecuta
## y avisa por señales. Las habilidades en si son Resources sin estado.
##
## El mana no vive aca sino en el healer, porque ya lo comparten el movimiento
## y el HUD; el componente solo lo consulta y lo descuenta.

signal habilidad_usada(habilidad: Habilidad, aviso: String)
signal habilidad_fallo(habilidad: Habilidad, motivo: String)
signal enfriamientos_cambiaron

@export var habilidades: Array[Habilidad] = []

var _restante: Dictionary = {}


func _process(delta: float) -> void:
	if _restante.is_empty():
		return

	var terminadas: Array[String] = []
	for nombre: String in _restante:
		_restante[nombre] -= delta
		if _restante[nombre] <= 0.0:
			terminadas.append(nombre)
	for nombre in terminadas:
		_restante.erase(nombre)

	enfriamientos_cambiaron.emit()


func habilidad_en(indice: int) -> Habilidad:
	if indice < 0 or indice >= habilidades.size():
		return null
	return habilidades[indice]


func intentar(habilidad: Habilidad) -> bool:
	if habilidad == null:
		return false

	var healer := get_parent()

	if enfriamiento_restante(habilidad) > 0.0:
		habilidad_fallo.emit(habilidad, "%s en enfriamiento" % habilidad.nombre)
		return false

	if healer.mana < habilidad.costo:
		habilidad_fallo.emit(habilidad, "Sin mana")
		return false

	var bloqueo := habilidad.motivo_bloqueo(healer)
	if bloqueo != "":
		habilidad_fallo.emit(habilidad, bloqueo)
		return false

	# El costo se cobra recien despues de ejecutar, para que una habilidad que
	# decide no hacer nada no cobre igual.
	var aviso := habilidad.ejecutar(healer)
	healer.gastar_mana(habilidad.costo)
	if habilidad.enfriamiento > 0.0:
		_restante[habilidad.nombre] = habilidad.enfriamiento
		enfriamientos_cambiaron.emit()

	habilidad_usada.emit(habilidad, aviso)
	return true


func enfriamiento_restante(habilidad: Habilidad) -> float:
	return _restante.get(habilidad.nombre, 0.0)


## 0.0 = lista para usar, 1.0 = recien usada. Para dibujar el HUD.
func fraccion_enfriamiento(habilidad: Habilidad) -> float:
	if habilidad.enfriamiento <= 0.0:
		return 0.0
	return clampf(enfriamiento_restante(habilidad) / habilidad.enfriamiento, 0.0, 1.0)
