extends SceneTree
## Genera las escenas y los recursos del prototipo.
##
## El HUD sale de gen_hud.gd y los movimientos del healer de gen_movimientos.gd;
## los dos se corren antes que este, que los usa tal como quedaron guardados.

const ANCHO := 30.0
const PROFUNDIDAD := 10.0
## El personaje mide ~68 px de arte y queremos que mida 2 m en el mundo.
const PIXEL_SIZE := 2.0 / 68.0
const RUTA_GRILLA := "res://assets/texturas/grilla.png"
const DIR_MOVIMIENTOS := "res://resources/movimientos"
const DIR_SOLDADOS := "res://resources/soldados"
const RUTA_HUD := "res://scenes/ui/hud.tscn"
## Lo que el healer trae equipado de fabrica, en el orden en que se lee la
## tabla: primero lo que sale sin combo, despues lo que lo continua, al final
## lo del aire. El orden solo desempata, y en la tabla no hay empates.
const MOVIMIENTOS: Array[String] = [
	"toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar", "impulso", "caida",
]


func _initialize() -> void:
	for archivo in MOVIMIENTOS:
		if not ResourceLoader.exists(_ruta_movimiento(archivo)):
			print("Falta %s. Correr primero:" % _ruta_movimiento(archivo))
			print("  --script res://tools/gen_movimientos.gd")
			quit(1)
			return

	_crear_textura_grilla()
	_crear_tipos()
	_crear_healer()
	_crear_unidad()
	_crear_emergente()
	_crear_marca_telegrafo()
	_crear_battle()
	quit()


## Textura de una celda de 1 m: sin una referencia repetida en el piso, en 3D
## no se percibe ni el avance ni la profundidad.
func _crear_textura_grilla() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/texturas"))

	var lado := 64
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var base := Color("343a4d")
	var linea := Color("3e455c")
	imagen.fill(base)
	for i in lado:
		imagen.set_pixel(i, 0, linea)
		imagen.set_pixel(0, i, linea)
	imagen.save_png(ProjectSettings.globalize_path(RUTA_GRILLA))
	print("%s -> OK" % RUTA_GRILLA)


## Cada tipo le crea un problema distinto al healer: el escudero es el mejor
## paciente pero esta en primera linea; el lancero depende de tener a alguien
## adelante; el espadachin se mete solo en problemas. Del otro lado, el bruto
## avisa donde va a pegar y obliga a decidir antes de que caiga, y el demonio
## hace lo mismo con media linea adentro.
func _crear_tipos() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_SOLDADOS))

	var escudero := TipoSoldado.new()
	escudero.nombre = "Escudero"
	escudero.frames = load("res://assets/sprites/soldier/soldier_frames.tres")
	escudero.vida_maxima = 110.0
	escudero.dano = 9.0
	escudero.cadencia = 1.4
	escudero.alcance = 1.3
	escudero.velocidad = 0.9
	escudero.reduccion_dano = 0.25
	_guardar_tipo(escudero, "escudero.tres")

	var lancero := TipoSoldado.new()
	lancero.nombre = "Lancero"
	lancero.frames = load("res://assets/sprites/lancero/lancero_frames.tres")
	lancero.vida_maxima = 70.0
	lancero.dano = 13.0
	lancero.cadencia = 1.1
	lancero.alcance = 2.2
	lancero.velocidad = 1.0
	lancero.retirada_bajo = 0.3
	_guardar_tipo(lancero, "lancero.tres")

	var espadachin := TipoSoldado.new()
	espadachin.nombre = "Espadachin"
	espadachin.frames = load("res://assets/sprites/espadachin/espadachin_frames.tres")
	espadachin.vida_maxima = 65.0
	espadachin.dano = 16.0
	espadachin.cadencia = 0.8
	espadachin.alcance = 1.3
	espadachin.velocidad = 1.3
	espadachin.oportunista = true
	_guardar_tipo(espadachin, "espadachin.tres")

	var zombie := TipoSoldado.new()
	zombie.nombre = "Zombi"
	zombie.frames = load("res://assets/sprites/enemy/enemy_frames.tres")
	zombie.vida_maxima = 75.0
	zombie.dano = 12.0
	zombie.cadencia = 1.0
	zombie.alcance = 1.3
	zombie.velocidad = 0.95
	_guardar_tipo(zombie, "zombie.tres")

	# Pega poco pero muy fuerte, y se ve venir: carga el golpe con una marca en
	# el suelo. El healer elige entre saltarlo, bendecir al que lo va a recibir
	# o curar despues. Pega a ras del suelo y en un circulo chico.
	var bruto := TipoSoldado.new()
	bruto.nombre = "Bruto"
	bruto.frames = load("res://assets/sprites/bruto/bruto_frames.tres")
	bruto.vida_maxima = 260.0
	bruto.dano = 34.0
	bruto.cadencia = 2.6
	bruto.alcance = 1.6
	bruto.velocidad = 0.7
	bruto.telegrafiado = 1.2
	bruto.barrido = true
	bruto.radio_golpe = 1.2
	# Hoja de 40 px con el oso ocupando 31: sin esto se veria de un metro.
	bruto.lado_frame = 40
	bruto.alto_util_px = 31.0
	bruto.altura_metros = 2.2
	bruto.radio_colision = 0.5
	bruto.altura_barra = 2.4
	_guardar_tipo(bruto, "bruto.tres")

	# El jefe del ultimo nivel: grande, con dos golpes anunciados que pegan en
	# un area que abarca media linea. El segundo pega mas.
	var demonio := TipoSoldado.new()
	demonio.nombre = "Demonio"
	demonio.frames = load("res://assets/sprites/demonio/demonio_frames.tres")
	demonio.vida_maxima = 900.0
	demonio.dano = 30.0
	demonio.cadencia = 3.0
	demonio.alcance = 2.6
	demonio.velocidad = 0.8
	demonio.telegrafiado = 1.4
	demonio.barrido = false
	demonio.radio_golpe = 2.5
	demonio.anim_ataque_2 = "attack2"
	demonio.factor_ataque_2 = 1.5
	demonio.lado_frame = 96
	demonio.alto_util_px = 52.0
	demonio.altura_metros = 3.2
	demonio.radio_colision = 0.7
	demonio.altura_barra = 3.5
	demonio.es_jefe = true
	_guardar_tipo(demonio, "demonio.tres")


func _guardar_tipo(recurso: Resource, archivo: String) -> void:
	var ruta := "%s/%s" % [DIR_SOLDADOS, archivo]
	var err := ResourceSaver.save(recurso, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


func _ruta_movimiento(archivo: String) -> String:
	return "%s/%s.tres" % [DIR_MOVIMIENTOS, archivo]


func _crear_healer() -> void:
	var healer := CharacterBody3D.new()
	healer.name = "Healer"
	healer.set_script(load("res://scripts/3d/healer3d.gd"))

	var sprite := AnimatedSprite3D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/sprites/healer/healer_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	sprite.pixel_size = PIXEL_SIZE
	# El frame tiene los pies apoyados abajo: subirlo media altura deja el
	# origen del nodo a ras del suelo.
	sprite.offset = Vector2(0, 64)
	# Encara siempre a la camara pero sin inclinarse: es un recorte parado.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Sin alpha_cut el recorte no proyecta sombra y se pelea con el z-buffer.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# El tinte del jugador 1, apenas un toque: el contorno dorado ya viene en
	# el sprite, y el tinte fuerte de antes lo ensuciaba. Va en los dos lados:
	# el healer pisa el modulate del sprite con tinte_jugador al arrancar, y el
	# modulate es lo que se ve en el editor.
	var tinte := Jugadores.tinte(1)
	sprite.modulate = tinte
	healer.set("tinte_jugador", tinte)
	healer.add_child(sprite)
	sprite.owner = healer

	var colision := CollisionShape3D.new()
	colision.name = "CollisionShape3D"
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.7
	colision.shape = capsula
	colision.position = Vector3(0, 0.85, 0)
	healer.add_child(colision)
	colision.owner = healer

	# Todos los movimientos: un encuentro que quiera menos los recorta al
	# empezar, y uno que no diga nada juega con estos.
	var combos := ComponenteCombos.new()
	combos.name = "Combos"
	var lista: Array[Movimiento] = []
	for archivo in MOVIMIENTOS:
		lista.append(load(_ruta_movimiento(archivo)))
	combos.movimientos = lista
	healer.add_child(combos)
	combos.owner = healer

	_guardar(healer, "res://scenes/3d/healer3d.tscn")


func _crear_unidad() -> void:
	var unidad := CharacterBody3D.new()
	unidad.name = "Unidad"
	unidad.set_script(load("res://scripts/3d/unidad3d.gd"))
	unidad.collision_layer = 4
	unidad.collision_mask = 12

	var sprite := AnimatedSprite3D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/sprites/soldier/soldier_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	sprite.pixel_size = PIXEL_SIZE
	sprite.offset = Vector2(0, 64)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	unidad.add_child(sprite)
	sprite.owner = unidad

	var colision := CollisionShape3D.new()
	colision.name = "CollisionShape3D"
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.7
	colision.shape = capsula
	colision.position = Vector3(0, 0.85, 0)
	unidad.add_child(colision)
	colision.owner = unidad

	_guardar(unidad, "res://scenes/3d/unidad3d.tscn")


## Aviso en el suelo: un disco chato, sin luz ni sombra, que la batalla
## escala mientras late.
func _crear_emergente() -> void:
	var raiz := Node3D.new()
	raiz.name = "Emergente"
	raiz.set_script(load("res://scripts/3d/emergente3d.gd"))

	var marca := MeshInstance3D.new()
	marca.name = "Marca"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.75
	disco.bottom_radius = 0.75
	disco.height = 0.04
	marca.mesh = disco
	marca.position = Vector3(0, 0.02, 0)
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.12, 0.1, 0.7)
	marca.material_override = material
	raiz.add_child(marca)
	marca.owner = raiz

	_guardar(raiz, "res://scenes/3d/emergente3d.tscn")


## Aviso de un golpe telegrafiado: el area del golpe, tenue y fija, y adentro un
## disco que crece hasta llenarla. Los dos miden 1 m de radio, asi la marca los
## escala directo al radio del golpe en metros.
func _crear_marca_telegrafo() -> void:
	var raiz := Node3D.new()
	raiz.name = "MarcaTelegrafo"
	raiz.set_script(load("res://scripts/3d/marca_telegrafo.gd"))

	var color := Color(0.95, 0.35, 0.15, 0.7)
	_agregar_disco(raiz, "Area", Color(color, 0.22), 0.02, 0)
	# Mas alto y dibujado despues: el que crece va siempre encima del area,
	# aunque las dos transparencias queden casi a la misma distancia.
	_agregar_disco(raiz, "Carga", color, 0.04, 1)

	_guardar(raiz, "res://scenes/3d/marca_telegrafo.tscn")


## Disco chato, sin luz ni sombra, como el del emergente.
func _agregar_disco(raiz: Node3D, nombre: String, color: Color, alto: float,
		prioridad: int) -> void:
	var disco := MeshInstance3D.new()
	disco.name = nombre
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 1.0
	cilindro.bottom_radius = 1.0
	cilindro.height = alto
	disco.mesh = cilindro
	disco.position = Vector3(0, alto * 0.5, 0)
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.render_priority = prioridad
	disco.material_override = material
	raiz.add_child(disco)
	disco.owner = raiz


func _crear_battle() -> void:
	var battle := Node3D.new()
	battle.name = "Battle3D"
	battle.set_script(load("res://scripts/3d/battle3d.gd"))
	battle.set("ancho_campo", ANCHO)
	battle.set("profundidad_campo", PROFUNDIDAD)

	_agregar_entorno(battle)
	_agregar_suelo(battle)
	_agregar_base(battle, Vector3(1.0, 0, PROFUNDIDAD * 0.5), Color("4a7fd4"), "BaseAliada")
	_agregar_base(battle, Vector3(ANCHO - 1.0, 0, PROFUNDIDAD * 0.5), Color("c4553f"), "BaseEnemiga")

	var unidades := Node3D.new()
	unidades.name = "Unidades"
	battle.add_child(unidades)
	unidades.owner = battle
	unidades.unique_name_in_owner = true

	var escena_healer: PackedScene = load("res://scenes/3d/healer3d.tscn")
	var healer: Node3D = escena_healer.instantiate()
	healer.name = "Healer"
	healer.position = Vector3(ANCHO * 0.4, 0, PROFUNDIDAD * 0.5)
	unidades.add_child(healer)
	healer.owner = battle
	healer.unique_name_in_owner = true

	# La camara lateral que sigue a los healers. No tiene _process propio: la
	# batalla la avanza desde el suyo y le pasa el campo en cada encuentro.
	var camara := CamaraBatalla.new()
	camara.name = "Camara"
	camara.fov = 42.0
	battle.add_child(camara)
	camara.owner = battle
	camara.unique_name_in_owner = true

	# Las barras de vida van en una capa 2D encima del mundo: se proyectan
	# desde la camara en vez de colgar carteles de cada soldado.
	var capa := CanvasLayer.new()
	capa.name = "CapaUnidades"
	battle.add_child(capa)
	capa.owner = battle

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_script(load("res://scripts/3d/overlay_unidades.gd"))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(overlay)
	overlay.owner = battle
	overlay.unique_name_in_owner = true

	# El HUD lo genera gen_hud.gd. Si todavia no se corrio, el resto se genera
	# igual y queda el aviso; la batalla no arranca sin HUD, asi que despues
	# hay que correr gen_hud.gd y este de nuevo.
	if ResourceLoader.exists(RUTA_HUD):
		var escena_hud: PackedScene = load(RUTA_HUD)
		var hud := escena_hud.instantiate()
		hud.name = "HUD"
		battle.add_child(hud)
		hud.owner = battle
		hud.unique_name_in_owner = true
	else:
		push_warning("Falta %s: correr antes tools/gen_hud.gd" % RUTA_HUD)

	# El menu de pausa va por encima del HUD y arranca invisible. Si todavia no
	# se genero (proyecto recien clonado, sin correr gen_ui), la batalla se
	# arma igual y simplemente no hay pausa.
	if ResourceLoader.exists("res://scenes/ui/menu_pausa.tscn"):
		var escena_pausa: PackedScene = load("res://scenes/ui/menu_pausa.tscn")
		var pausa := escena_pausa.instantiate()
		pausa.name = "MenuPausa"
		battle.add_child(pausa)
		pausa.owner = battle
		pausa.unique_name_in_owner = true

	_guardar(battle, "res://scenes/3d/battle3d.tscn")


func _agregar_entorno(battle: Node3D) -> void:
	var entorno := WorldEnvironment.new()
	entorno.name = "Entorno"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("161a27")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a6180")
	env.ambient_light_energy = 0.9
	# Niebla suave: da sensacion de distancia y despega el fondo del frente.
	env.fog_enabled = true
	env.fog_light_color = Color("161a27")
	env.fog_density = 0.03
	entorno.environment = env
	battle.add_child(entorno)
	entorno.owner = battle

	var luz := DirectionalLight3D.new()
	luz.name = "Sol"
	luz.rotation_degrees = Vector3(-52, -130, 0)
	luz.light_energy = 1.1
	luz.light_color = Color("fff2d8")
	luz.shadow_enabled = true
	battle.add_child(luz)
	luz.owner = battle


func _agregar_suelo(battle: Node3D) -> void:
	var suelo := MeshInstance3D.new()
	suelo.name = "Suelo"
	var plano := PlaneMesh.new()
	plano.size = Vector2(ANCHO * 2.2, PROFUNDIDAD * 3.0)
	suelo.mesh = plano
	suelo.position = Vector3(ANCHO * 0.5, 0, PROFUNDIDAD * 0.5)

	var material := StandardMaterial3D.new()
	var textura: Texture2D = load(RUTA_GRILLA)
	material.albedo_texture = textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Una repeticion por metro: cada celda del piso mide 1 m.
	material.uv1_scale = Vector3(plano.size.x, plano.size.y, 1.0)
	material.roughness = 1.0
	suelo.material_override = material
	battle.add_child(suelo)
	suelo.owner = battle


func _agregar_base(battle: Node3D, pos: Vector3, color: Color, nombre: String) -> void:
	var base := MeshInstance3D.new()
	base.name = nombre
	var caja := BoxMesh.new()
	caja.size = Vector3(1.6, 4.0, 5.0)
	base.mesh = caja
	base.position = pos + Vector3(0, 2.0, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	base.material_override = material
	battle.add_child(base)
	base.owner = battle


func _guardar(nodo: Node, ruta: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ruta.get_base_dir()))
	var empaquetada := PackedScene.new()
	var err := empaquetada.pack(nodo)
	if err != OK:
		push_error("No se pudo empaquetar %s: %d" % [ruta, err])
		return
	err = ResourceSaver.save(empaquetada, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])
