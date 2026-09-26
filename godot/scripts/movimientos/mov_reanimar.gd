class_name MovimientoReanimar
extends Movimiento
## Levanta al derribado que el healer tiene al frente. En la tabla pesa mas
## que cualquier combo: con un cuerpo en el suelo delante, la pesada es esto.
## Vuelve con poca vida, asi que reanimar suele ser el principio del problema.


func motivo_bloqueo(healer: Node3D) -> String:
	return SIN_OBJETIVO if Apuntado.derribado_al_frente(healer) == null else ""


func ejecutar(healer: Node3D) -> Dictionary:
	var unidad := Apuntado.derribado_al_frente(healer)
	# reanimar() dice si habia a quien levantar: si no, no se anuncia nada.
	if unidad == null or not unidad.reanimar():
		return _resultado(false)
	healer.lanzar_efecto(unidad, efecto, color)
	return _resultado(true, unidad, unidad.vida, "Reanimado")


## Redondea hacia arriba, como la tarjeta del HUD muestra la vida: la ficha no
## puede prometer 38 y que al levantarse la barra diga 39.
func previsualizar(_healer: Node3D, objetivo: Unidad3D) -> String:
	if objetivo == null or not objetivo.esta_derribada():
		return ""
	return "%s: lo levanta con %d HP" % [
		nombre, ceili(objetivo.vida_maxima * objetivo.vida_al_reanimar)]
