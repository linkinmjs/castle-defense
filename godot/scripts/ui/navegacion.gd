class_name Navegacion
extends RefCounted
## Adonde se va desde cada pantalla.
##
## Funciones estaticas y no un autoload: son cuatro rutas y el orden en que hay
## que hacer las cosas al cambiar de escena. Un singleton para esto solo
## agregaria estado global que despues hay que resetear en las pruebas.

const MENU := "res://scenes/ui/menu_principal.tscn"
const BATALLA := "res://scenes/3d/battle3d.tscn"
## Las dos series que se pueden jugar: las lecciones cortas, que enseñan un
## movimiento por vez, y los niveles largos por sectores, que son el juego.
const RUTA_LECCIONES := "res://resources/encuentros/campana.tres"
const RUTA_NIVELES := "res://resources/encuentros/niveles.tres"
## Por donde le avisa el menu a la batalla con que leccion arrancar. El
## SceneTree sobrevive al cambio de escena, asi que alcanza con dejarlo anotado
## ahi; sin la anotacion la batalla arranca por la primera, como siempre.
const ENCUENTRO_INICIAL := &"encuentro_inicial"
## Lo mismo para la serie. Sin anotacion la batalla juega las lecciones, que es
## lo que esperan las pruebas y el F6 sobre la escena.
const CAMPANA_PEDIDA := &"campana_pedida"


## Arranca la batalla en el encuentro `indice` de la serie `ruta_campana`.
## Con la ruta vacia solo anota el indice: la serie sigue siendo la que ya
## estaba anotada, o las lecciones si nadie anoto ninguna. Por eso quien pueda
## venir de otra serie (el menu, al volver de los niveles) nombra la suya.
static func jugar(arbol: SceneTree, indice: int = 0, ruta_campana: String = "") -> void:
	arbol.paused = false
	arbol.set_meta(ENCUENTRO_INICIAL, maxi(indice, 0))
	if not ruta_campana.is_empty():
		pedir_campana(arbol, ruta_campana)
	arbol.change_scene_to_file(BATALLA)


## Deja anotada la serie que carga la proxima batalla. Vacia borra la
## anotacion y vuelve a las lecciones.
static func pedir_campana(arbol: SceneTree, ruta: String) -> void:
	if ruta.is_empty():
		if arbol.has_meta(CAMPANA_PEDIDA):
			arbol.remove_meta(CAMPANA_PEDIDA)
		return
	arbol.set_meta(CAMPANA_PEDIDA, ruta)


## Despausar antes de cambiar: si no, el menu aparece congelado y no responde.
static func ir_al_menu(arbol: SceneTree) -> void:
	arbol.paused = false
	arbol.change_scene_to_file(MENU)


static func salir(arbol: SceneTree) -> void:
	if en_web():
		return  # el navegador no deja cerrar la pestania
	arbol.quit()


## En web no hay ventana propia: no se puede salir ni cambiar la resolucion.
static func en_web() -> bool:
	return OS.has_feature("web")


## Con que encuentro arrancar, segun lo que haya dejado anotado el menu.
static func encuentro_pedido(arbol: SceneTree) -> int:
	if not arbol.has_meta(ENCUENTRO_INICIAL):
		return 0
	return int(arbol.get_meta(ENCUENTRO_INICIAL))


## Que serie cargar, segun lo que haya dejado anotado el menu. Sin anotacion,
## las lecciones.
static func campana_pedida(arbol: SceneTree) -> String:
	if not arbol.has_meta(CAMPANA_PEDIDA):
		return RUTA_LECCIONES
	return String(arbol.get_meta(CAMPANA_PEDIDA))
