extends Label
## Los controles del jugador en un renglon, debajo de las barras.
##
## Reemplaza a la fila de habilidades: sin mouse ni teclas por habilidad, lo
## unico que hay que recordar son tres botones y el movimiento. Que sale con
## cada uno lo cuenta el aviso del combo al usarlos.
##
## Los nombres salen de Jugadores.etiquetas(), el mismo lugar que sabe que
## teclas y botones tiene cada jugador: si cambia el mapa, cambia la leyenda.

const SEPARADOR := " · "


func _ready() -> void:
	# Sin healer todavia (el HUD suelto, las pruebas) muestra la del primero.
	if text == "":
		mostrar(1)


## La batalla le pasa el healer cuyo HUD es este.
func seguir(healer: Node) -> void:
	var jugador: Variant = healer.get(&"jugador")
	mostrar(int(jugador) if jugador != null else 1)


func mostrar(jugador: int) -> void:
	text = texto(jugador)


## "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A"
static func texto(jugador: int) -> String:
	var e := Jugadores.etiquetas(jugador)
	return SEPARADOR.join(PackedStringArray([
		"Mover %s" % e["mover"],
		"Ligera %s" % e["ligera"],
		"Pesada %s" % e["pesada"],
		"Saltar %s" % e["saltar"],
	]))
