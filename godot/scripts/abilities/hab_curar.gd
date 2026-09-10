class_name HabilidadCurar
extends Habilidad
## Curacion directa sobre un aliado. Barata y sin casi enfriamiento: es la
## herramienta de todos los dias, y lo que sobra del tope se desperdicia.

@export var cantidad: float = 35.0


## El objetivo no se tipa: Unidad (2D) y Unidad3D heredan de CharacterBody2D
## y CharacterBody3D, que no comparten un tipo comun. Se usan por los
## metodos que ambas exponen.
func motivo_bloqueo(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	if objetivo == null:
		return "Sin objetivo"
	if not healer.en_rango(objetivo):
		return "Fuera de alcance"
	return ""


func ejecutar(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	var recuperado: float = objetivo.curar(cantidad)
	healer.lanzar_efecto(objetivo, "heal")

	var desperdicio: float = cantidad - recuperado
	if desperdicio > 1.0:
		return "+%d  (%d desperdiciado)" % [recuperado, desperdicio]
	return "+%d" % recuperado
