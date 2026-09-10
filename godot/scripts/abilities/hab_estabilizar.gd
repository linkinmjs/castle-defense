class_name HabilidadEstabilizar
extends Habilidad
## Corta el sangrado sin devolver vida. Barata: la decision interesante es
## elegirla en vez de curar cuando el soldado se esta desangrando.

@export var vida_extra: float = 0.0


## El objetivo no se tipa: Unidad (2D) y Unidad3D heredan de CharacterBody2D
## y CharacterBody3D, que no comparten un tipo comun. Se usan por los
## metodos que ambas exponen.
func motivo_bloqueo(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	if objetivo == null:
		return "Sin objetivo"
	if not healer.en_rango(objetivo):
		return "Fuera de alcance"
	if not objetivo.esta_sangrando():
		return "No esta sangrando"
	return ""


func ejecutar(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	objetivo.estabilizar()
	if vida_extra > 0.0:
		objetivo.curar(vida_extra)
	healer.lanzar_efecto(objetivo, "shield")
	return "Estabilizado"
