class_name HabilidadReanimar
extends Habilidad
## Levanta a un aliado derribado. Cara y con enfriamiento: cada uso es una
## decision, no un reflejo. El derribado vuelve con poca vida, asi que
## reanimarlo suele ser el principio del problema, no el final.


## El objetivo no se tipa: ver hab_curar.gd.
func motivo_bloqueo(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	if objetivo == null:
		return "Sin objetivo"
	if not healer.en_rango(objetivo):
		return "Fuera de alcance"
	if not objetivo.esta_derribada():
		return "No esta derribado"
	return ""


func ejecutar(healer: Node) -> String:
	var objetivo: Variant = healer.objetivo_apuntado()
	objetivo.reanimar()
	healer.lanzar_efecto(objetivo, "heal")
	return "Reanimado"


func previsualizar(_healer: Node, objetivo: Node) -> String:
	if not objetivo.esta_derribada():
		return ""
	return "%s: lo levanta con %d HP" % [
		nombre, objetivo.vida_maxima * objetivo.vida_al_reanimar]
