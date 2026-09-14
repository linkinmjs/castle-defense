extends CanvasLayer
## Pausa del juego.
##
## Se cuelga de la batalla y arranca invisible. Solo lo abre la accion "pause",
## nunca se muestra solo: las pruebas y las capturas instancian la escena de
## batalla, y un menu que se abriera por su cuenta las dejaria colgadas
## esperando a que alguien apretara un boton que nadie va a apretar.
##
## Con el arbol pausado, el healer y la batalla dejan de recibir input por su
## cuenta: en Godot un nodo pausado no recibe _unhandled_input. No hay que
## desactivar nada a mano.

signal abierto
signal cerrado

var _battle: Node

@onready var _opciones: Control = %OpcionesPausa
@onready var _botonera: Control = %BotoneraPausa


func _ready() -> void:
	# El menu tiene que seguir corriendo con el arbol pausado: es el unico que
	# puede despausarlo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	%Continuar.pressed.connect(cerrar)
	%Reiniciar.pressed.connect(_on_reiniciar)
	%OpcionesBoton.pressed.connect(_mostrar_opciones)
	%AlMenu.pressed.connect(_on_al_menu)
	_opciones.cerrado.connect(_mostrar_botonera)


## La batalla se presenta al armarse, en vez de que el menu adivine donde esta
## parado en el arbol.
func seguir_batalla(battle: Node) -> void:
	_battle = battle


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("pause"):
		return
	alternar()
	# Sin esto el mismo Escape sigue viaje y lo recibe la batalla.
	get_viewport().set_input_as_handled()


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	if visible:
		return
	get_tree().paused = true
	visible = true
	_mostrar_botonera()
	abierto.emit()


func cerrar() -> void:
	if not visible:
		return
	get_tree().paused = false
	visible = false
	cerrado.emit()


func esta_abierto() -> bool:
	return visible


## Red de seguridad: si alguien libera la batalla con el menu abierto, el arbol
## quedaria pausado para siempre y la proxima escena no correria.
func _exit_tree() -> void:
	if visible and is_inside_tree():
		get_tree().paused = false


func _on_reiniciar() -> void:
	cerrar()
	if _battle != null and is_instance_valid(_battle):
		_battle.reiniciar_encuentro()


func _on_al_menu() -> void:
	cerrar()
	Navegacion.ir_al_menu(get_tree())


func _mostrar_botonera() -> void:
	_botonera.visible = true
	_opciones.visible = false
	%Continuar.grab_focus()


func _mostrar_opciones() -> void:
	_botonera.visible = false
	_opciones.abrir()
