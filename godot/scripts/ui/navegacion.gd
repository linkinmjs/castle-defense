class_name Navegacion
extends RefCounted
## Adonde se va desde cada pantalla.
##
## Funciones estaticas y no un autoload: son cuatro rutas y el orden en que hay
## que hacer las cosas al cambiar de escena. Un singleton para esto solo
## agregaria estado global que despues hay que resetear en las pruebas.

const MENU := "res://scenes/ui/menu_principal.tscn"
const BATALLA := "res://scenes/3d/battle3d.tscn"
## Por donde le avisa el menu a la batalla con que leccion arrancar. El
## SceneTree sobrevive al cambio de escena, asi que alcanza con dejarlo anotado
## ahi; sin la anotacion la batalla arranca por la primera, como siempre.
const ENCUENTRO_INICIAL := &"encuentro_inicial"


static func jugar(arbol: SceneTree, indice: int = 0) -> void:
	arbol.paused = false
	arbol.set_meta(ENCUENTRO_INICIAL, maxi(indice, 0))
	arbol.change_scene_to_file(BATALLA)


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
