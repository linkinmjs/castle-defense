extends SceneTree
## El escenario de la batalla: que %Mundo traiga todas sus piezas con las
## texturas de assets/fondos, que las capas del fondo esten montadas como pide
## su LEEME (sin luz, recorte duro, sin niebla ni sombra), que la luz sea la
## del atardecer, y que Mundo.configurar() acomode todo para cualquier campo
## sin duplicar nada.
##
## Instancia la escena real sin meterla en el arbol: asi no arranca ningun
## encuentro y se mira solo lo que dejo el generador.

const ESCENA := "res://scenes/3d/battle3d.tscn"
const DIR_FONDOS := "res://assets/fondos"
## Nodo -> textura que tiene que usar.
const TEXTURAS := {
	"Cielo": "cielo", "Montanas": "montanas", "Loma": "castillo", "Castillo": "castillo",
	"Arboles": "arboles", "Suelo": "suelo", "Camino": "camino",
	"MuroAliado": "muro", "MuroEnemigo": "muro", "Porton": "porton",
}
const CAPAS := ["Cielo", "Montanas", "Loma", "Castillo", "Arboles"]
const PARADOS := ["Cielo", "Montanas", "Loma", "Castillo", "Arboles", "MuroAliado", "MuroEnemigo", "Porton"]
const TOL := 0.01

var _fallos := 0


func _initialize() -> void:
	var battle := (load(ESCENA) as PackedScene).instantiate()
	var mundo := battle.get_node_or_null("Mundo") as Mundo
	_ok("battle3d tiene un Mundo con el script Mundo", mundo != null)
	if mundo == null:
		_terminar([battle])
		return
	_ok("con nombre unico (%Mundo)", mundo.unique_name_in_owner)

	_piezas(mundo)
	_sin_grilla(battle)
	_montaje(mundo)
	_luz(battle)
	_campo_de_fabrica(mundo)
	_campo_largo(mundo)
	_profundidad(mundo)
	_dos_veces(mundo)
	var otra := (load(ESCENA) as PackedScene).instantiate()
	_instancias_separadas(mundo, otra.get_node("Mundo") as Mundo)
	_terminar([battle, otra])


func _piezas(mundo: Mundo) -> void:
	print("--- estan todas las piezas, con sus texturas ---")
	for nombre: String in TEXTURAS:
		var nodo := mundo.get_node_or_null(nombre) as MeshInstance3D
		if nodo == null:
			_ok("%s existe y es un MeshInstance3D" % nombre, false)
			continue
		var material := nodo.material_override as StandardMaterial3D
		var ruta := material.albedo_texture.resource_path if material != null and material.albedo_texture != null else "-"
		var esperada := "%s/%s.png" % [DIR_FONDOS, TEXTURAS[nombre]]
		_ok("%s usa %s" % [nombre, esperada.get_file()], ruta == esperada)


func _sin_grilla(battle: Node) -> void:
	print("--- grilla.png ya no se usa ---")
	var texto := FileAccess.get_file_as_string(ESCENA)
	_ok("battle3d.tscn no menciona grilla.png", not texto.contains("grilla.png"))
	var usan: Array[String] = []
	for nodo in _todos(battle):
		if nodo is GeometryInstance3D:
			var material := (nodo as GeometryInstance3D).material_override as BaseMaterial3D
			if material != null and material.albedo_texture != null \
					and material.albedo_texture.resource_path.contains("grilla"):
				usan.append(nodo.name)
	_ok("ningun nodo la tiene de textura %s" % str(usan), usan.is_empty())
	_ok("no quedan las cajas de las bases",
		battle.get_node_or_null("BaseAliada") == null and battle.get_node_or_null("BaseEnemiga") == null)


func _montaje(mundo: Mundo) -> void:
	print("--- las capas del fondo, montadas como pide su LEEME ---")
	for nombre: String in CAPAS:
		var capa := mundo.get_node(nombre) as MeshInstance3D
		var m := capa.material_override as StandardMaterial3D
		_ok("%s: sin luz, recorte, nearest, sin niebla, sin sombra" % nombre,
			m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST
			and m.disable_fog
			and capa.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		# Texel cuadrado: si el alto y la repeticion no salen de la misma
		# distancia, la capa se ve estirada.
		var quad := capa.mesh as QuadMesh
		var textura := m.albedo_texture
		var filas := float(Mundo.CAPAS[StringName(nombre)].get("filas", textura.get_height()))
		var ancho_texel := quad.size.x / m.uv1_scale.x / textura.get_width()
		var alto_texel := quad.size.y / filas
		if nombre != "Cielo":
			_ok("%s: texel cuadrado (%.4f x %.4f m)" % [nombre, ancho_texel, alto_texel],
				absf(ancho_texel - alto_texel) < 0.0005)
	print("--- porton y murallas: parados como los fondos, sin sombra ---")
	for nombre: String in PARADOS:
		var nodo := mundo.get_node(nombre) as MeshInstance3D
		_ok("%s: rotado -15 grados en X, paralelo a la camara" % nombre,
			nodo.rotation_degrees.is_equal_approx(Vector3(-15, 0, 0)))
		_ok("%s: el nodo esta en el borde de abajo" % nombre,
			is_equal_approx((nodo.mesh as QuadMesh).center_offset.y, (nodo.mesh as QuadMesh).size.y * 0.5))
	for nombre: String in ["MuroAliado", "MuroEnemigo", "Porton"]:
		var nodo := mundo.get_node(nombre) as MeshInstance3D
		var m := nodo.material_override as StandardMaterial3D
		_ok("%s: sin sombra, sin luz y con recorte" % nombre,
			nodo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		# A la escala de los sprites: 34 texeles por metro, 5.6 m de alto.
		var quad := nodo.mesh as QuadMesh
		_igual("%s: alto a 34 texeles/m" % nombre, quad.size.y, m.albedo_texture.get_height() / 34.0)
	for nombre: String in ["Suelo", "Camino"]:
		var m := (mundo.get_node(nombre) as MeshInstance3D).material_override as StandardMaterial3D
		_ok("%s: mate, nearest, sin metal" % nombre,
			m.roughness == 1.0 and m.metallic == 0.0 and m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)


func _luz(battle: Node) -> void:
	print("--- atardecer: glow, filmic y niebla por distancia ---")
	var entorno := battle.get_node_or_null("Entorno") as WorldEnvironment
	var env := entorno.environment if entorno != null else null
	_ok("hay un WorldEnvironment con Environment", env != null)
	if env == null:
		return
	_ok("glow prendido", env.glow_enabled)
	_ok("tonemap FILMIC", env.tonemap_mode == Environment.TONE_MAPPER_FILMIC)
	_ok("fondo de color (por si asoma algo)", env.background_mode == Environment.BG_COLOR)
	_ok("niebla por distancia", env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH)
	var sol := battle.get_node_or_null("Sol") as DirectionalLight3D
	_ok("el Sol tira sombra", sol != null and sol.shadow_enabled)
	if sol != null:
		# La luz viaja por el -Z del nodo: tiene que ir hacia +X, hacia abajo y
		# hacia la camara (+Z), mas de costado que de frente.
		var direccion := -sol.basis.z
		_ok("el sol tira las sombras hacia +X y +Z (%s)" % str(direccion.snapped(Vector3.ONE * 0.01)),
			direccion.x > 0.0 and direccion.z > 0.0 and direccion.y < 0.0 and direccion.x > direccion.z)
		# Largo de la sombra de un soldado de 2 m hacia la camara: la de la
		# fila de adelante (z = 8.5) no pasa del borde de abajo (~z = 10.26).
		_ok("la sombra de la fila de adelante no se sale por abajo (%.2f m hacia la camara)" % (2.0 * direccion.z / -direccion.y),
			8.5 + 2.0 * direccion.z / -direccion.y < 10.26)


## Lo que trae la escena: el campo de 30 x 10 de battle3d, con las bases en 1.5
## y 28.5. Sin que nadie lo configure.
func _campo_de_fabrica(mundo: Mundo) -> void:
	print("--- de fabrica: el campo de 30 x 10 ---")
	_ok("recien instanciado no esta configurado", not mundo.esta_configurado())
	_ok("pero ya sabe su campo: limite (0.5, 29.0) -> %s" % str(mundo.limite_x_jugable()),
		mundo.limite_x_jugable().is_equal_approx(Vector2(0.5, 29.0)))
	_igual("porton en x = 28.5 + 2", _nodo(mundo, "Porton").position.x, 30.5)
	var suelo := _extension_x(_nodo(mundo, "Suelo"))
	_ok("suelo de -20 a 50 (%s)" % str(suelo), suelo.x <= -20.0 + TOL and suelo.y >= 50.0 - TOL)


func _campo_largo(mundo: Mundo) -> void:
	print("--- configurar(90, 10, 1.5, 88.5) ---")
	mundo.configurar(90.0, 10.0, 1.5, 88.5)
	_ok("queda configurado", mundo.esta_configurado())
	_ok("limite jugable (0.5, 89.0) -> %s" % str(mundo.limite_x_jugable()),
		mundo.limite_x_jugable().is_equal_approx(Vector2(0.5, 89.0)))

	var porton := _nodo(mundo, "Porton")
	_igual("porton en x = 88.5 + 2", porton.position.x, 90.5)
	var ancho_porton := (porton.mesh as QuadMesh).size.x
	_ok("el porton arranca pasando lo que pisan los healers (ancho - 1.5 = 88.5)",
		porton.position.x - ancho_porton * 0.5 > 88.5)

	var suelo := _nodo(mundo, "Suelo")
	var x := _extension_x(suelo)
	_ok("suelo de -20 a 110 en X (%s)" % str(x), x.x <= -20.0 + TOL and x.y >= 110.0 - TOL)
	var z := _extension_z(suelo)
	_ok("y de -6 a 16 en Z, al menos (%s)" % str(z), z.x <= -6.0 + TOL and z.y >= 16.0 - TOL)
	var plano := suelo.mesh as PlaneMesh
	var m := suelo.material_override as StandardMaterial3D
	_igual("suelo: una vuelta de la textura cada 128/34 m en X",
		plano.size.x / m.uv1_scale.x, 128.0 / 34.0, 0.001)
	_igual("y en Z", plano.size.y / m.uv1_scale.y, 128.0 / 34.0, 0.001)

	var camino := _nodo(mundo, "Camino")
	_igual("camino por la mitad de la profundidad", camino.position.z, 5.0)
	_igual("apenas sobre el suelo", camino.position.y, 0.005, 0.0001)
	var largo := _extension_x(camino)
	_ok("a lo largo de todo el suelo (%s)" % str(largo), largo.x <= x.x + TOL and largo.y >= x.y - TOL)

	# Las capas de 240 m tienen que cubrir todo lo que barre la camara. En el
	# cielo, la mas lejana, eso va de x = -44 a x = 134 con este campo.
	for nombre: String in CAPAS:
		var capa := _nodo(mundo, nombre)
		var quad := capa.mesh as QuadMesh
		var datos: Dictionary = Mundo.CAPAS[StringName(nombre)]
		if datos.get("una_vuelta", false):
			continue
		var cubre := Vector2(capa.position.x - quad.size.x * 0.5, capa.position.x + quad.size.x * 0.5)
		_ok("%s cubre de -44 a 134 (%s)" % [nombre, str(cubre)], cubre.x <= -44.0 and cubre.y >= 134.0)

	# El torreon (la columna del medio de castillo.png) cae 6.5 m antes de la
	# base enemiga, una sola vez: el quad del castillo mide una vuelta.
	var castillo := _nodo(mundo, "Castillo")
	_igual("el torreon en x = 88.5 - 6.5", _x_de_columna_del_medio(castillo, 82.0), 82.0, 0.001)
	var ancho_castillo := (castillo.mesh as QuadMesh).size.x
	var repeticion := ancho_castillo / (castillo.material_override as StandardMaterial3D).uv1_scale.x
	_igual("el castillo mide una sola vuelta de la textura", ancho_castillo, repeticion, 0.001)
	# La loma corre alineada con el castillo: si no, entre los arboles se
	# veria un escalon donde termina el quad del castillo.
	_igual("la loma corre con el mismo corrimiento que el castillo",
		_x_de_columna_del_medio(_nodo(mundo, "Loma"), 82.0), 82.0, 0.001)
	_ok("la loma va apenas detras del castillo",
		_nodo(mundo, "Loma").position.z < castillo.position.z
		and castillo.position.z - _nodo(mundo, "Loma").position.z < 0.05)

	var enemigo := _extension_x(_nodo(mundo, "MuroEnemigo"))
	_ok("la muralla enemiga sale de abajo de la torrecita del porton (%.2f)" % enemigo.x,
		enemigo.x < porton.position.x + ancho_porton * 0.5 and enemigo.x > porton.position.x)
	_ok("y sigue hasta el final del suelo (%.2f)" % enemigo.y, enemigo.y >= x.y - TOL)
	var aliado := _extension_x(_nodo(mundo, "MuroAliado"))
	var tramo := 96.0 / 34.0
	_igual("la muralla aliada termina pasando su base (1.5 - 2.5 + medio tramo)", aliado.y, 1.5 - 2.5 + tramo * 0.5)
	_ok("y viene desde el final del suelo (%.2f)" % aliado.x, aliado.x <= x.x + TOL)
	_ok("fuera del limite jugable", aliado.y < mundo.limite_x_jugable().x)
	for nombre: String in ["MuroAliado", "MuroEnemigo", "Porton"]:
		_ok("%s: en el fondo del campo, detras de todo soldado" % nombre, _nodo(mundo, nombre).position.z < 0.0)


## Con otra profundidad la camara se para en otro Z: las capas se corren con
## ella para quedar a la misma distancia, que es lo que hace que un texel mida
## 2 px exactos.
func _profundidad(mundo: Mundo) -> void:
	print("--- con 6 m de profundidad, las capas se corren con la camara ---")
	var antes := {}
	for nombre: String in CAPAS:
		antes[nombre] = _nodo(mundo, nombre).position.z - 5.0
	mundo.configurar(90.0, 6.0, 1.5, 88.5)
	for nombre: String in CAPAS:
		_igual("%s: misma distancia al medio del campo" % nombre,
			_nodo(mundo, nombre).position.z - 3.0, antes[nombre])
	_igual("el camino sigue por la mitad", _nodo(mundo, "Camino").position.z, 3.0)
	var z := _extension_z(_nodo(mundo, "Suelo"))
	_ok("el suelo cubre de -6 a 12 (%s)" % str(z), z.x <= -6.0 + TOL and z.y >= 12.0 - TOL)


func _dos_veces(mundo: Mundo) -> void:
	print("--- configurar dos veces no duplica nada ---")
	var hijos := mundo.get_child_count()
	mundo.configurar(60.0, 10.0, 2.0, 57.0)
	var una := _foto(mundo)
	mundo.configurar(60.0, 10.0, 2.0, 57.0)
	_ok("los mismos %d hijos" % hijos, mundo.get_child_count() == hijos)
	_ok("y todo queda igual que con una sola vez", _foto(mundo) == una)
	mundo.configurar(30.0, 10.0, 1.5, 28.5)
	_igual("y vuelve al campo de 30 m", _nodo(mundo, "Porton").position.x, 30.5)


## Dos batallas a la vez no comparten el suelo ni las capas: configurar una
## no le cambia el campo a la otra.
func _instancias_separadas(mundo: Mundo, otro: Mundo) -> void:
	print("--- cada batalla tiene su propio suelo ---")
	mundo.configurar(90.0, 10.0, 1.5, 88.5)
	var suelo_otro := _extension_x(_nodo(otro, "Suelo"))
	_ok("la otra sigue con su suelo de 30 m (%s)" % str(suelo_otro), is_equal_approx(suelo_otro.y, 50.0))
	var castillo := _nodo(otro, "Castillo").material_override as StandardMaterial3D
	var propio := _nodo(mundo, "Arboles").material_override as StandardMaterial3D
	_ok("y sus materiales son otros", castillo != _nodo(mundo, "Castillo").material_override
		and propio != _nodo(otro, "Arboles").material_override)


# --- Ayudas ----------------------------------------------------------------------

func _nodo(mundo: Mundo, nombre: String) -> MeshInstance3D:
	return mundo.get_node(nombre) as MeshInstance3D


## De donde a donde llega en X un plano o un quad.
func _extension_x(nodo: MeshInstance3D) -> Vector2:
	var ancho := (nodo.mesh.get("size") as Vector2).x
	return Vector2(nodo.position.x - ancho * 0.5, nodo.position.x + ancho * 0.5)


func _extension_z(nodo: MeshInstance3D) -> Vector2:
	var largo: float = (nodo.mesh as PlaneMesh).size.y
	return Vector2(nodo.position.z - largo * 0.5, nodo.position.z + largo * 0.5)


## La X del mundo mas cercana a cerca_de donde el quad muestra la columna del
## medio de su textura (u = 0.5 en cada vuelta). Hace la cuenta del shader:
## u = (x - borde) / ancho * uv1_scale + uv1_offset.
func _x_de_columna_del_medio(capa: MeshInstance3D, cerca_de: float) -> float:
	var m := capa.material_override as StandardMaterial3D
	var ancho := (capa.mesh as QuadMesh).size.x
	var repeticion := ancho / m.uv1_scale.x
	var borde := capa.position.x - ancho * 0.5
	var u := (cerca_de - borde) / repeticion + m.uv1_offset.x
	return cerca_de + (roundf(u - 0.5) + 0.5 - u) * repeticion


## Posiciones, tamanos y corrimientos de todos los hijos, para comparar.
func _foto(mundo: Mundo) -> String:
	var partes: PackedStringArray = []
	for hijo in mundo.get_children():
		var nodo := hijo as MeshInstance3D
		var m := nodo.material_override as StandardMaterial3D
		partes.append("%s %s %s %s %s" % [nodo.name, nodo.position, nodo.mesh.get("size"),
			m.uv1_scale, m.uv1_offset])
	return "\n".join(partes)


func _todos(nodo: Node) -> Array[Node]:
	var lista: Array[Node] = [nodo]
	for hijo in nodo.get_children():
		lista.append_array(_todos(hijo))
	return lista


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float, tolerancia := TOL) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-58s obtenido=%.3f esperado=%.3f" % ["OK" if ok else "FALLA", que, obtenido, esperado])


func _terminar(liberar: Array) -> void:
	for nodo: Node in liberar:
		nodo.free()
	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)
