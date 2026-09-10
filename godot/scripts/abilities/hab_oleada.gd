class_name HabilidadOleada
extends Habilidad
## Cura poco a todos los aliados alrededor. Cara y con enfriamiento largo:
## sirve cuando media linea esta golpeada, no para un herido puntual.

@export var cantidad: float = 18.0
@export var radio: float = 240.0


func motivo_bloqueo(healer: Node) -> String:
	if _alcanzados(healer).is_empty():
		return "Nadie cerca"
	return ""


func ejecutar(healer: Node) -> String:
	var curados := 0
	var total := 0.0
	for unidad: Unidad in _alcanzados(healer):
		var recuperado := unidad.curar(cantidad)
		if recuperado > 0.0:
			curados += 1
			total += recuperado
		healer.lanzar_efecto(unidad, "heal")

	if curados == 0:
		return "Nadie lo necesitaba"
	var plural := "soldados" if curados != 1 else "soldado"
	return "Oleada: +%d en %d %s" % [total, curados, plural]


func _alcanzados(healer: Node) -> Array[Unidad]:
	var lista: Array[Unidad] = []
	for unidad: Unidad in healer.get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva():
			continue
		if healer.global_position.distance_to(unidad.global_position) <= radio:
			lista.append(unidad)
	return lista
