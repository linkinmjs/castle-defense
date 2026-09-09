extends Node2D
## Escena raíz del juego. Punto de entrada configurado en
## Project Settings > Application > Run > Main Scene.


func _ready() -> void:
	print("Castle Defense corriendo en Godot %s" % Engine.get_version_info().string)
