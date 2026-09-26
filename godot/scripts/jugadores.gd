class_name Jugadores
extends RefCounted
## Quien es quien cuando juegan dos: que acciones del Input Map le tocan a cada
## healer, con que joystick, como se nombran sus botones en pantalla y con que
## color se lo distingue.
##
## Funciones estaticas y no un autoload, como Navegacion: el unico estado que
## hay (cuantos juegan) lo deja anotado el menu en el SceneTree, y un singleton
## solo sumaria algo global que resetear entre pruebas.
##
## Las acciones llevan el numero de jugador adelante (p1_ligera, p2_ligera). Las
## teclas de cada uno son distintas, y los botones de joystick se separan por
## device: InputMap solo empareja un evento con una accion si el device de la
## accion es -1 o es el mismo del evento, asi que la X del segundo pad dispara
## p2_ligera y nunca p1_ligera.

const MAXIMO := 2
## Lo que cada jugador puede hacer, en el orden en que se generan las acciones.
const ENTRADAS: Array[StringName] = [
	&"izquierda", &"derecha", &"arriba", &"abajo", &"ligera", &"pesada", &"saltar",
]
## Donde deja anotado el menu cuantos juegan. El SceneTree sobrevive al cambio
## de escena, igual que la leccion pedida en Navegacion.
const CANTIDAD := &"jugadores"

## Como se nombran los controles en pantalla. Los del teclado de P2 van con
## palabras: "/ / A" no se lee.
const _ETIQUETAS := {
	1: {"mover": "WASD / Stick", "ligera": "J / X", "pesada": "K / Y", "saltar": "Espacio / A"},
	2: {"mover": "Flechas / Stick", "ligera": "Coma / X", "pesada": "Punto / Y", "saltar": "Barra / A"},
}
## Con que color se tine el sprite de cada healer. Apenas un toque: el
## contorno ya viene horneado en su sprite (dorado el 1, turquesa el 2), y un
## tinte fuerte lo ensuciaba. Esta aca y no en la batalla para que el HUD
## pinte a cada jugador con el mismo color que se ve en el campo.
const _TINTES := {
	1: Color(1.0, 0.96, 0.85),
	2: Color(0.85, 1.0, 0.97),
}


## &"p1_ligera" para (1, &"ligera").
static func accion(jugador: int, entrada: StringName) -> StringName:
	return StringName("p%d_%s" % [jugador, entrada])


## Cuantos healers pidio el menu. Sin anotacion (pruebas, F6 sobre la batalla)
## juega uno solo.
static func cantidad_pedida(arbol: SceneTree) -> int:
	if not arbol.has_meta(CANTIDAD):
		return 1
	return clampi(int(arbol.get_meta(CANTIDAD)), 1, MAXIMO)


static func pedir_cantidad(arbol: SceneTree, cantidad: int) -> void:
	arbol.set_meta(CANTIDAD, clampi(cantidad, 1, MAXIMO))


## El id real del joystick de ese jugador: el primero conectado para P1, el
## segundo para P2. Sin pad propio queda el id que trae el Input Map (0 y 1).
##
## Si ese id lo tiene un pad conectado, ese pad ya es de otro jugador: pasa con
## un solo pad que el sistema numero 1 (en web los ids son arbitrarios, y en
## escritorio queda asi al desenchufar el primero). Sin correrse, un joystick
## manejaria a los dos healers a la vez.
static func pad_de(jugador: int) -> int:
	var pads := Input.get_connected_joypads()
	var indice := jugador - 1
	if indice >= 0 and indice < pads.size():
		return pads[indice]
	var libre := indice
	while pads.has(libre):
		libre += MAXIMO
	return libre


## Reescribe el device de los eventos de joystick de cada accion p{n}_* con el
## pad que le toca a ese jugador ahora. El Input Map sale del proyecto con 0 y
## 1, que es lo que numera el escritorio; en web y tras desenchufar un pad los
## ids pueden ser otros. Se llama al armar la batalla y cada vez que se conecta
## o desconecta un joystick.
static func aplicar_dispositivos() -> void:
	for jugador in range(1, MAXIMO + 1):
		var pad := pad_de(jugador)
		for entrada in ENTRADAS:
			var nombre := accion(jugador, entrada)
			if not InputMap.has_action(nombre):
				continue
			# Los eventos que devuelve el InputMap son los mismos que guarda:
			# cambiarlos en el lugar alcanza, no hace falta sacarlos y volverlos
			# a poner.
			for evento: InputEvent in InputMap.action_get_events(nombre):
				if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
					evento.device = pad


## Si el evento aprieta alguna accion de ese jugador. Para que un segundo
## jugador se sume apretando cualquier boton suyo.
##
## Apretar y no solo tocar: un stick que deriva por debajo de la zona muerta
## tambien "es" p2_izquierda, pero nadie lo movio a proposito.
static func es_entrada_de(jugador: int, evento: InputEvent) -> bool:
	for entrada in ENTRADAS:
		var nombre := accion(jugador, entrada)
		if InputMap.has_action(nombre) and evento.is_action_pressed(nombre):
			return true
	return false


## Como se llaman los controles de ese jugador: {"mover", "ligera", "pesada",
## "saltar"}. Un jugador que no existe recibe los del primero.
static func etiquetas(jugador: int) -> Dictionary:
	var propias: Dictionary = _ETIQUETAS.get(jugador, _ETIQUETAS[1])
	return propias.duplicate()


## El tinte del healer de ese jugador. Un jugador que no existe recibe el del
## primero, como con las etiquetas.
static func tinte(jugador: int) -> Color:
	return _TINTES.get(jugador, _TINTES[1])
