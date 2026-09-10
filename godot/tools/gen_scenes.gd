extends SceneTree
## Genera los recursos de habilidad y las escenas del prototipo con el formato
## nativo de Godot.

const ANCHO_CAMPO := 1800.0
const BANDA_ALTA := 40.0
const BANDA_BAJA := 280.0
const DIR_HABILIDADES := "res://resources/habilidades"


func _initialize() -> void:
	_crear_habilidades()
	_crear_healer()
	_crear_unidad()
	_crear_hud()
	_crear_battle()
	quit()


func _crear_habilidades() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_HABILIDADES))

	var curar := HabilidadCurar.new()
	curar.nombre = "Curar"
	curar.tecla = "LMB"
	curar.costo = 25.0
	curar.enfriamiento = 0.6
	curar.objetivo = Habilidad.Objetivo.ALIADO
	curar.color = Color("5fbf5f")
	curar.cantidad = 35.0
	curar.descripcion = "Devuelve vida a un aliado. Lo que pasa del tope se pierde."
	_guardar_recurso(curar, "curar.tres")

	var estabilizar := HabilidadEstabilizar.new()
	estabilizar.nombre = "Estabilizar"
	estabilizar.tecla = "RMB"
	estabilizar.costo = 10.0
	estabilizar.enfriamiento = 1.2
	estabilizar.objetivo = Habilidad.Objetivo.ALIADO
	estabilizar.color = Color("d2503c")
	estabilizar.descripcion = "Corta el sangrado. No devuelve vida."
	_guardar_recurso(estabilizar, "estabilizar.tres")

	var oleada := HabilidadOleada.new()
	oleada.nombre = "Oleada"
	oleada.tecla = "1"
	oleada.costo = 45.0
	oleada.enfriamiento = 14.0
	oleada.objetivo = Habilidad.Objetivo.AREA
	oleada.color = Color("4a9fd4")
	oleada.cantidad = 18.0
	oleada.radio = 240.0
	oleada.descripcion = "Cura poco a todos los aliados alrededor."
	_guardar_recurso(oleada, "oleada.tres")

	var bendicion := HabilidadBendicion.new()
	bendicion.nombre = "Bendicion"
	bendicion.tecla = "2"
	bendicion.costo = 35.0
	bendicion.enfriamiento = 16.0
	bendicion.objetivo = Habilidad.Objetivo.ALIADO
	bendicion.color = Color("6fd3c7")
	bendicion.duracion = 8.0
	bendicion.reduccion_dano = 0.35
	bendicion.bonus_cadencia = 0.30
	bendicion.descripcion = "Protege y acelera a un aliado por unos segundos."
	_guardar_recurso(bendicion, "bendicion.tres")

	var impulso := HabilidadImpulso.new()
	impulso.nombre = "Impulso"
	impulso.tecla = "3"
	impulso.costo = 12.0
	impulso.enfriamiento = 4.0
	impulso.objetivo = Habilidad.Objetivo.PROPIA
	impulso.color = Color("e0c060")
	impulso.fuerza = 620.0
	impulso.duracion = 0.22
	impulso.descripcion = "Empuja al healer hacia el mouse. Para llegar a tiempo."
	_guardar_recurso(impulso, "impulso.tres")


func _crear_healer() -> void:
	var healer := CharacterBody2D.new()
	healer.name = "Healer"
	healer.set_script(load("res://scripts/healer.gd"))
	healer.collision_layer = 2  # player
	healer.collision_mask = 1   # world

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = load("res://assets/sprites/healer/healer_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	# El frame mide 128x128 con los pies apoyados en el borde inferior:
	# subirlo media altura deja el origen del nodo a la altura del piso.
	sprite.offset = Vector2(0, -64)
	# El arte es de 128px pero el personaje ocupa ~68px: al doble tiene
	# presencia real en pantalla sin perder nitidez (filtro Nearest).
	sprite.scale = Vector2(2, 2)
	# Dorado: tiene que despegarse del azul de su propio ejercito.
	sprite.modulate = Color(1.0, 0.88, 0.55)
	healer.add_child(sprite)
	sprite.owner = healer

	var colision := CollisionShape2D.new()
	colision.name = "CollisionShape2D"
	var capsula := CapsuleShape2D.new()
	capsula.radius = 14.0
	capsula.height = 44.0
	colision.shape = capsula
	colision.position = Vector2(0, -22)
	healer.add_child(colision)
	colision.owner = healer

	var habilidades := Node.new()
	habilidades.name = "Habilidades"
	habilidades.set_script(load("res://scripts/abilities/componente_habilidades.gd"))
	# El orden importa: es el que usan los indices del input (0 = click izq).
	var lista: Array[Habilidad] = [
		load(DIR_HABILIDADES + "/curar.tres"),
		load(DIR_HABILIDADES + "/estabilizar.tres"),
		load(DIR_HABILIDADES + "/oleada.tres"),
		load(DIR_HABILIDADES + "/bendicion.tres"),
		load(DIR_HABILIDADES + "/impulso.tres"),
	]
	habilidades.set("habilidades", lista)
	healer.add_child(habilidades)
	habilidades.owner = healer

	_guardar(healer, "res://scenes/units/healer.tscn")


func _crear_unidad() -> void:
	var unidad := CharacterBody2D.new()
	unidad.name = "Unidad"
	unidad.set_script(load("res://scripts/unidad.gd"))
	# configurar() ajusta capas y bando al instanciarla; esto es solo el default
	# para poder abrir la escena sola en el editor.
	unidad.collision_layer = 4
	unidad.collision_mask = 12

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = load("res://assets/sprites/soldier/soldier_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	sprite.offset = Vector2(0, -64)
	sprite.scale = Vector2(2, 2)
	unidad.add_child(sprite)
	sprite.owner = unidad

	var colision := CollisionShape2D.new()
	colision.name = "CollisionShape2D"
	var capsula := CapsuleShape2D.new()
	capsula.radius = 14.0
	capsula.height = 44.0
	colision.shape = capsula
	colision.position = Vector2(0, -22)
	unidad.add_child(colision)
	colision.owner = unidad

	_guardar(unidad, "res://scenes/units/unidad.tscn")


func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Todo el HUD ignora el mouse: los clicks tienen que llegar al campo.
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(raiz)
	raiz.owner = hud

	var contadores := _etiqueta("Contadores", 20, Color(0.88, 0.9, 1.0))
	contadores.set_anchors_preset(Control.PRESET_TOP_LEFT)
	contadores.position = Vector2(24, 16)
	raiz.add_child(contadores)
	contadores.owner = hud
	contadores.unique_name_in_owner = true

	var aviso := _etiqueta("Aviso", 22, Color(1.0, 0.92, 0.6))
	aviso.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	aviso.position = Vector2(24, -170)
	raiz.add_child(aviso)
	aviso.owner = hud
	aviso.unique_name_in_owner = true

	var slots := Control.new()
	slots.name = "Slots"
	slots.set_script(load("res://scripts/slots_habilidades.gd"))
	slots.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slots.position = Vector2(24, -140)
	slots.size = Vector2(560, 62)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(slots)
	slots.owner = hud
	slots.unique_name_in_owner = true

	var barra := ProgressBar.new()
	barra.name = "BarraMana"
	barra.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	barra.position = Vector2(24, -62)
	barra.size = Vector2(280, 18)
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra)
	barra.owner = hud
	barra.unique_name_in_owner = true

	var texto_mana := _etiqueta("TextoMana", 16, Color(0.8, 0.9, 1.0))
	texto_mana.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	texto_mana.position = Vector2(314, -64)
	raiz.add_child(texto_mana)
	texto_mana.owner = hud
	texto_mana.unique_name_in_owner = true

	var ayuda := _etiqueta("Ayuda", 15, Color(0.7, 0.75, 0.85))
	ayuda.text = "WASD mover      Click sobre un aliado para actuar"
	ayuda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ayuda.position = Vector2(24, -34)
	raiz.add_child(ayuda)
	ayuda.owner = hud

	_guardar(hud, "res://scenes/ui/hud.tscn")


func _etiqueta(nombre: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	etiqueta.add_theme_constant_override("shadow_offset_y", 1)
	return etiqueta


func _crear_battle() -> void:
	var battle := Node2D.new()
	battle.name = "Battle"
	battle.set_script(load("res://scripts/battle.gd"))
	battle.set("ancho_campo", ANCHO_CAMPO)
	battle.set("banda_alta", BANDA_ALTA)
	battle.set("banda_baja", BANDA_BAJA)

	var campo := Node2D.new()
	campo.name = "Campo"
	campo.set_script(load("res://scripts/campo.gd"))
	campo.set("ancho", ANCHO_CAMPO)
	campo.set("banda_alta", BANDA_ALTA)
	campo.set("banda_baja", BANDA_BAJA)
	battle.add_child(campo)
	campo.owner = battle

	# Ordena a los hijos por Y para que quien esta mas abajo se dibuje adelante.
	var unidades := Node2D.new()
	unidades.name = "Unidades"
	unidades.y_sort_enabled = true
	battle.add_child(unidades)
	unidades.owner = battle
	unidades.unique_name_in_owner = true

	var escena_healer: PackedScene = load("res://scenes/units/healer.tscn")
	var healer := escena_healer.instantiate()
	healer.name = "Healer"
	healer.position = Vector2(700, 220)
	unidades.add_child(healer)
	healer.owner = battle
	healer.unique_name_in_owner = true

	var camara := Camera2D.new()
	camara.name = "Camara"
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 6.0
	battle.add_child(camara)
	camara.owner = battle
	camara.unique_name_in_owner = true

	var escena_hud: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud := escena_hud.instantiate()
	hud.name = "HUD"
	battle.add_child(hud)
	hud.owner = battle
	hud.unique_name_in_owner = true

	_guardar(battle, "res://scenes/battle.tscn")


func _guardar_recurso(recurso: Resource, archivo: String) -> void:
	var ruta := "%s/%s" % [DIR_HABILIDADES, archivo]
	var err := ResourceSaver.save(recurso, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


func _guardar(nodo: Node, ruta: String) -> void:
	var empaquetada := PackedScene.new()
	var err := empaquetada.pack(nodo)
	if err != OK:
		push_error("No se pudo empaquetar %s: %d" % [ruta, err])
		return
	err = ResourceSaver.save(empaquetada, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])
