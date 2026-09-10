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
	for unidad in _alcanzados(healer):
		var recuperado: float = unidad.curar(cantidad)
		if recuperado > 0.0:
			curados += 1
			total += recuperado
		healer.lanzar_efecto(unidad, "heal")

	if curados == 0:
		return "Nadie lo necesitaba"
	var plural := "soldados" if curados != 1 else "soldado"
	return "Oleada: +%d en %d %s" % [total, curados, plural]


## El objetivo no se tipa: Unidad (2D) y Unidad3D heredan de CharacterBody2D
## y CharacterBody3D, que no comparten un tipo comun. Se usan por los
## metodos que ambas exponen.
func _alcanzados(healer: Node) -> Array:
	var lista: Array = []
	for unidad in healer.get_tree().get_nodes_in_group("aliados"):
		if not unidad.esta_viva():
			continue
		if healer.global_position.distance_to(unidad.global_position) <= radio:
			lista.append(unidad)
	return lista
