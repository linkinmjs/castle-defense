extends Control
## Ajustes de pantalla. Es un panel, no una pantalla: se instancia oculto dentro
## del menu principal y del de pausa.
##
## Asi no hay una tercera transicion de escena ni hay que recordar "a donde
## vuelvo cuando cierro": vuelve a donde estaba, porque nunca se fue.

signal cerrado

@onready var _completa: Button = %PantallaCompleta
@onready var _fila_resolucion: Control = %FilaResolucion
@onready var _resolucion: Label = %Resolucion


func _ready() -> void:
	visible = false
	_completa.toggled.connect(_on_pantalla_completa)
	%Anterior.pressed.connect(_on_resolucion.bind(-1))
	%Siguiente.pressed.connect(_on_resolucion.bind(1))
	%Volver.pressed.connect(cerrar)
	# En web el canvas lo dimensiona la pagina: elegir resolucion no haria nada.
	_fila_resolucion.visible = Opciones.hay_ventana()
	_refrescar()


func abrir() -> void:
	_refrescar()
	visible = true
	%Volver.grab_focus()


func cerrar() -> void:
	visible = false
	cerrado.emit()


func _on_pantalla_completa(activado: bool) -> void:
	Opciones.poner_pantalla_completa(activado)
	_refrescar()


func _on_resolucion(paso: int) -> void:
	Opciones.rotar_resolucion(paso)
	_refrescar()


func _refrescar() -> void:
	_completa.button_pressed = Opciones.pantalla_completa
	_completa.text = "Pantalla completa: %s" % ["si" if Opciones.pantalla_completa else "no"]
	_resolucion.text = Opciones.etiqueta_resolucion()
	# En pantalla completa manda el monitor: la resolucion elegida no aplica.
	_fila_resolucion.modulate.a = 0.45 if Opciones.pantalla_completa else 1.0
