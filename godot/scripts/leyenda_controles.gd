extends Label
## Los controles de un jugador en un renglon, al pie de la pantalla.
##
## Reemplaza a la fila de habilidades: sin mouse ni teclas por habilidad, lo
## unico que hay que recordar son tres botones y el movimiento. Que sale con
## cada uno lo dice la tarjeta de la ficha, y el aviso del combo al usarlos.
##
## El HUD tiene una por jugador, cada una abajo en el lado de su ficha. Los
## nombres salen de Jugadores.etiquetas(), el mismo lugar que sabe que teclas y
## botones tiene cada jugador: si cambia el mapa, cambia la leyenda.

const SEPARADOR := " · "

## De que jugador son los controles. Lo pone el generador; seguir() lo toma
## del healer.
@export_range(1, 2) var jugador: int = 1


func _ready() -> void:
	# Sin healer todavia (el HUD suelto, las pruebas) muestra la de su jugador.
	mostrar(jugador)


## La batalla le pasa el healer cuyos controles son estos.
func seguir(healer: Node) -> void:
	var propio: Variant = healer.get(&"jugador")
	mostrar(int(propio) if propio != null else jugador)


func mostrar(numero: int) -> void:
	jugador = numero
	text = texto(numero)


## "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A"
static func texto(numero: int) -> String:
	var e := Jugadores.etiquetas(numero)
	return SEPARADOR.join(PackedStringArray([
		"Mover %s" % e["mover"],
		"Ligera %s" % e["ligera"],
		"Pesada %s" % e["pesada"],
		"Saltar %s" % e["saltar"],
	]))
