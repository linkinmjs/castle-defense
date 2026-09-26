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
## Cada boton se nombra con la tecla de ese jugador ("J", "K"; "," y "." para
## el 2; "X" e "Y" con joystick) y no con L y P: lo que el jugador tiene que
## encontrar en la ficha es lo que tiene bajo el dedo.
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
## Lo que dice el renglon de un movimiento que no se puede pagar: la
## consecuencia no importa si no va a salir.
const SIN_MANA := "sin mana"
## Un renglon por boton, en este orden.
const BOTONES: Array[StringName] = [&"ligera", &"pesada"]
## Jugadores.etiquetas() nombra algunas teclas con palabras, para que la
## leyenda se lea ("Coma / X"); en la tecla dibujada de la ficha va el signo.
const SIGNOS: Dictionary[String, String] = {"Coma": ",", "Punto": ".", "Barra": "/"}


## Tres renglones: quien esta al frente, la ligera y la pesada.
##
## El del frente es {texto, apagado}. Los de los botones suman lo que la ficha
## dibuja al lado del texto: {entrada, boton, movimiento, icono, enfriamiento,
## sin_mana} y, si lo pinta el movimiento, {color}; sin color va el del tema.
## Apagado es que no dice nada que sirva (nadie al frente, un boton sin
## movimiento): se muestra igual, para que la ficha no cambie de alto.
static func renglones(healer: Healer3D) -> Array[Dictionary]:
	var paciente: Unidad3D = null
	var combos: ComponenteCombos = null
	if healer != null and healer.is_inside_tree():
		paciente = healer.unidad_apuntada()
		combos = healer.get_node_or_null(^"Combos") as ComponenteCombos
	var jugador := healer.jugador if healer != null else 1
	var joystick := usa_joystick(jugador)
	var lista: Array[Dictionary] = [_renglon_paciente(paciente)]
	for entrada in BOTONES:
		var mov: Movimiento = combos.resolver(entrada) if combos != null else null
		var renglon := _renglon_boton(healer, combos, entrada, mov, paciente)
		renglon["boton"] = boton(jugador, entrada, joystick)
		lista.append(renglon)
	return lista


## Solo los textos, con la tecla adelante: "Mara · Lancero · 40 / 80 HP",
## "J · Toque: +18 HP", "K · Plegaria: +40 HP".
static func lineas(healer: Healer3D) -> PackedStringArray:
	var textos := PackedStringArray()
	for renglon in renglones(healer):
		var boton_renglon: String = renglon.get("boton", "")
		textos.append(renglon["texto"] if boton_renglon == "" \
			else boton_renglon + SEPARADOR + renglon["texto"])
	return textos


## La tecla de ese boton tal como se dibuja en la ficha: "J" y "K" para el 1,
## "," y "." para el 2; con joystick, "X" e "Y". Sale de Jugadores.etiquetas(),
## el mismo lugar que arma la leyenda: si cambia el mapa, cambia la tecla.
static func boton(jugador: int, entrada: StringName, con_joystick: bool = false) -> String:
	var etiqueta: String = Jugadores.etiquetas(jugador).get(String(entrada), "")
	if etiqueta == "":
		return ""
	var partes := etiqueta.split(" / ")
	var parte := partes[partes.size() - 1] if con_joystick and partes.size() > 1 else partes[0]
	return SIGNOS.get(parte, parte)


## Si ese jugador tiene un joystick propio conectado: el primero es del 1 y el
## segundo del 2, igual que en Jugadores.pad_de(). Con joystick la ficha
## nombra sus botones y no las teclas.
static func usa_joystick(jugador: int) -> bool:
	return Input.get_connected_joypads().size() >= jugador


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


## "Toque: +18 HP". Sin nadie al frente, o si al que esta no le haria nada,
## solo el nombre: igual sirve saber que sale. Sin mana para pagarlo, "Toque:
## sin mana", que es lo unico que importa de ese boton.
static func _renglon_boton(healer: Healer3D, combos: ComponenteCombos, entrada: StringName,
		mov: Movimiento, paciente: Unidad3D) -> Dictionary:
	var renglon := {
		"entrada": entrada,
		"texto": SIN_MOVIMIENTO,
		"apagado": true,
		"movimiento": "",
		"icono": null,
		"enfriamiento": 0.0,
		"sin_mana": false,
	}
	if mov == null:
		return renglon
	renglon["movimiento"] = mov.nombre
	renglon["icono"] = mov.icono
	renglon["color"] = mov.color
	renglon["apagado"] = false
	if combos != null:
		renglon["enfriamiento"] = combos.fraccion_enfriamiento(mov)
	if healer != null and healer.mana < mov.costo:
		renglon["sin_mana"] = true
		renglon["texto"] = "%s: %s" % [mov.nombre, SIN_MANA]
		return renglon
	# Reanimar no es para el de la ligera, que nunca es un caido, sino para el
	# derribado que el healer tiene adelante: la consecuencia es sobre ese.
	var objetivo: Unidad3D = paciente
	if mov.requiere_derribado and healer != null:
		objetivo = Apuntado.derribado_al_frente(healer)
	var previa := mov.previsualizar(healer, objetivo) if objetivo != null else ""
	renglon["texto"] = previa if previa != "" else mov.nombre
	return renglon
