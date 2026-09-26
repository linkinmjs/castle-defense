class_name TarjetaObjetivo
extends RefCounted
## Lo que dice la tarjeta compacta de cada ficha del HUD: a quien tiene el
## healer al frente y que saldria ahora con cada boton.
##
## Antes era un panel aparte que listaba lo que haria cada movimiento equipado,
## hasta ocho renglones. Con dos jugadores no entra, y tampoco hacia falta: lo
## unico que se decide en el momento es que boton apretar, y
## ComponenteCombos.resolver() ya sabe que sale con cada uno segun el combo en
## curso, el aire y lo que haya tirado adelante. Por eso la tarjeta cambia
## sola a mitad de un combo: despues de una ligera, la ligera ya es Vendaje.
##
## Muestra la consecuencia, nunca cual conviene: elegir es el juego. Tampoco
## hay "fuera de alcance": con el apuntado por posicion, el que no esta en la
## caja de la ligera no es el de la tarjeta.
##
## Son datos y no nodos, y estaticos: FichaJugador los pinta y las pruebas los
## leen sin armar ningun HUD.

## Lo que ocupa el lugar del movimiento cuando el boton no tiene ninguno: en el
## primer encuentro solo esta Toque, y la pesada no hace nada.
const SIN_MOVIMIENTO := "—"
const NADIE := "Nadie al frente"
const SEPARADOR := " · "
## Un renglon por boton, en este orden, con la letra con que se nombra.
const BOTONES: Array[StringName] = [&"ligera", &"pesada"]
const LETRAS: Dictionary[StringName, String] = {&"ligera": "L", &"pesada": "P"}


## Tres renglones: quien esta al frente, la ligera y la pesada. Cada uno es
## {texto, apagado} y, si lo pinta el movimiento, {color}; sin color va el del
## tema. Apagado es que no dice nada que sirva (nadie al frente, un boton sin
## movimiento): se muestra igual, para que la ficha no cambie de alto.
static func renglones(healer: Healer3D) -> Array[Dictionary]:
	var paciente: Unidad3D = null
	var combos: ComponenteCombos = null
	if healer != null and healer.is_inside_tree():
		paciente = healer.unidad_apuntada()
		combos = healer.get_node_or_null(^"Combos") as ComponenteCombos
	var lista: Array[Dictionary] = [_renglon_paciente(paciente)]
	for entrada in BOTONES:
		var mov: Movimiento = combos.resolver(entrada) if combos != null else null
		lista.append(_renglon_boton(healer, entrada, mov, paciente))
	return lista


## Solo los textos: "Mara · Lancero · 40 / 80 HP", "L · Toque: +18 HP",
## "P · Plegaria: +40 HP".
static func lineas(healer: Healer3D) -> PackedStringArray:
	var textos := PackedStringArray()
	for renglon in renglones(healer):
		textos.append(renglon["texto"])
	return textos


## Nombre, rol y vida en un renglon. La vida se redondea hacia arriba: con 0.3
## todavia esta vivo, y la tarjeta no puede decir 0.
static func _renglon_paciente(paciente: Unidad3D) -> Dictionary:
	if paciente == null:
		return {"texto": NADIE, "apagado": true}
	var partes := PackedStringArray()
	if paciente.nombre_unidad != "":
		partes.append(paciente.nombre_unidad)
	if paciente.tipo != null and paciente.tipo.nombre != "":
		partes.append(paciente.tipo.nombre)
	if partes.is_empty():
		partes.append("Soldado")
	partes.append("%d / %d HP" % [ceilf(paciente.vida), paciente.vida_maxima])
	return {"texto": SEPARADOR.join(partes), "apagado": false}


## "L · Toque: +18 HP". Sin nadie al frente, o si al que esta no le haria
## nada, solo el nombre: igual sirve saber que sale.
static func _renglon_boton(healer: Healer3D, entrada: StringName, mov: Movimiento,
		paciente: Unidad3D) -> Dictionary:
	var letra: String = LETRAS[entrada]
	if mov == null:
		return {"texto": letra + SEPARADOR + SIN_MOVIMIENTO, "apagado": true}
	# Reanimar no es para el de la ligera, que nunca es un caido, sino para el
	# derribado que el healer tiene adelante: la consecuencia es sobre ese.
	var objetivo: Unidad3D = paciente
	if mov.requiere_derribado and healer != null:
		objetivo = Apuntado.derribado_al_frente(healer)
	var previa := mov.previsualizar(healer, objetivo) if objetivo != null else ""
	return {
		"texto": letra + SEPARADOR + (previa if previa != "" else mov.nombre),
		"color": mov.color,
		"apagado": false,
	}
