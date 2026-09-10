class_name HabilidadCurar
extends Habilidad
## Curacion directa sobre un aliado. Barata y sin casi enfriamiento: es la
## herramienta de todos los dias, y lo que sobra del tope se desperdicia.

@export var cantidad: float = 35.0


func motivo_bloqueo(healer: Node) -> String:
	var objetivo: Unidad = healer.objetivo_apuntado()
	if objetivo == null:
		return "Sin objetivo"
	if not healer.en_rango(objetivo):
		return "Fuera de alcance"
	return ""


func ejecutar(healer: Node) -> String:
	var objetivo: Unidad = healer.objetivo_apuntado()
	var recuperado := objetivo.curar(cantidad)
	healer.lanzar_efecto(objetivo, "heal")

	var desperdicio := cantidad - recuperado
	if desperdicio > 1.0:
		return "+%d  (%d desperdiciado)" % [recuperado, desperdicio]
	return "+%d" % recuperado
