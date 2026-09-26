extends SceneTree
## Capturas del feedback enganchado: cada movimiento con su pose, su efecto y
## sus numeros, el golpe al healer con la vineta, el polvo al aterrizar y al
## correr, las chispas de un golpe. Sirven para ver que nada tape lo que hay
## que leer (la barra, el soldado, el healer) y que nada se pierda en el pasto.
##
## Un campo armado a mano y quieto: tres aliados heridos delante del healer, un
## caido aparte y un zombi. Las unidades no pelean (sin fisica), asi que cada
## foto muestra solo lo que se apreto.
##
## Correr SIN --headless: sin ventana no hay textura que guardar, y sin pantalla
## (Presentacion) no hay particulas ni numeros que fotografiar.
##   godot --path godot --script res://tools/captura_feedback.gd
## Las fotos quedan en user:// (feedback_*.png).

const ESCUDERO := preload("res://resources/soldados/escudero.tres")
const ZOMBIE := preload("res://resources/soldados/zombie.tres")
const HEALER := Vector2(12.0, 5.5)

var _battle: Node
var _healer: Healer3D
## El paciente del Toque y del Vendaje; los otros dos completan la Plegaria y
## la Oleada.
var _a: Unidad3D
var _b: Unidad3D
var _c: Unidad3D
## Caido lejos, hasta que se lo trae adelante para Reanimar: si estuviera al
## frente desde el principio, la pesada seria Reanimar y no Plegaria.
var _caido: Unidad3D
var _zombi: Unidad3D
var _inicio_ms := 0
## Cada paso: segundos que espera desde que termino el anterior, y lo que hace.
## Lo que hace devuelve true cuando termino (esperar el suelo tarda varios
## frames).
var _pasos: Array = []
var _paso := 0
var _desde := 0.0


func _initialize() -> void:
	var encuentro := Encuentro.new()
	encuentro.titulo = "Feedback"
	encuentro.semilla = 7
	encuentro.condicion = Encuentro.Condicion.SOBREVIVIR
	encuentro.duracion = 600.0
	encuentro.sangrado_habilitado = false
	encuentro.healer_inicial = HEALER
	for pos in [Vector3(13.3, 0, 5.4), Vector3(14.1, 0, 4.4), Vector3(13.9, 0, 6.6),
			Vector3(22.0, 0, 5.0)]:
		encuentro.grupos_iniciales.append(_grupo(Unidad3D.Bando.ALIADO, ESCUDERO, pos))
	encuentro.grupos_iniciales.append(_grupo(Unidad3D.Bando.ENEMIGO, ZOMBIE, Vector3(15.3, 0, 4.4)))

	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = encuentro
	_battle.unidad_creada.connect(_al_crear)
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()

	_pasos = [
		[1.5, _preparar],
		# 1. Toque: brillo verde, el efecto y el +18.
		[0.2, _apretar.bind(&"ligera")],
		[0.22, _foto.bind("feedback_1_toque.png", "Toque: brillo verde, efecto toque y +18")],
		# 2. Plegaria: mas de 0.7 s despues, para que el combo se corte y la
		# pesada no salga como Bendicion.
		[1.0, _apretar.bind(&"pesada")],
		[0.3, _foto.bind("feedback_2a_plegaria_carga.png", "Plegaria cargando: power_boost")],
		[0.3, _foto.bind("feedback_2b_plegaria_suelta.png", "Plegaria suelta: energy_wave y numeros")],
		# 3. L, L, P: el Vendaje corta el sangrado (texto de estado) y la Oleada
		# remata (hit-stop, punch de fov y numeros, uno con desperdicio).
		[1.2, _herir_para_el_combo],
		[0.05, _apretar.bind(&"ligera")],
		[0.4, _apretar.bind(&"ligera")],
		[0.15, _foto.bind("feedback_3a_vendaje.png", "Vendaje: VENDAJE sobre el +18")],
		[0.25, _apretar.bind(&"pesada")],
		[0.15, _foto.bind("feedback_3b_oleada.png", "Oleada: explosion, numeros y desperdicio")],
		# 4. Un golpe al healer: numero rojo, vineta y temblor.
		[1.2, _recibir_golpe],
		[0.1, _foto.bind("feedback_4_golpe.png", "Golpe al healer: -12 rojo y vineta")],
		# 5. Salto quieto: al tocar el suelo, polvo y la postura de aterrizar.
		[1.0, _saltar],
		[0.0, _esperar_suelo],
		[0.05, _foto.bind("feedback_5_aterrizaje.png", "Aterrizaje: polvo y land")],
		# 6. Reanimar: el pilar sale del suelo, no del pecho.
		[1.0, _traer_caido],
		[0.05, _apretar.bind(&"pesada")],
		[0.15, _foto.bind("feedback_6a_reanimar.png", "Reanimar: arrodillado junto al caido")],
		[0.3, _foto.bind("feedback_6b_reanimar_pilar.png", "Reanimar: el pilar sale del suelo")],
		# 7. Caida sanadora: pose en el aire y la onda al tocar el suelo.
		[1.2, _saltar],
		[0.12, _apretar.bind(&"pesada")],
		[0.12, _foto.bind("feedback_7a_caida_aire.png", "Caida en el aire: aerial_strike")],
		[0.0, _esperar_suelo],
		[0.12, _foto.bind("feedback_7b_caida_suelo.png", "Caida al tocar el suelo: energy_wave")],
		[0.3, _foto.bind("feedback_7c_caida_despues.png", "Caida: el numero que espero lugar")],
		# 8. Un golpe comun entre soldados: chispas en el pecho del golpeado.
		[1.0, _golpe_del_zombi],
		[0.06, _foto.bind("feedback_8_chispas.png", "Golpe del zombi: chispas")],
		# 9. Corriendo: el polvo de arrancar y los pasos.
		[0.6, _correr.bind(true)],
		[0.6, _foto.bind("feedback_9_carrera.png", "Carrera: polvo de pasos")],
		[0.0, _correr.bind(false)],
	]
	print("t(s)   foto                             anim healer      nums parts vineta fov")


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		if _healer == null:
			return false
	if _paso >= _pasos.size():
		print("listo")
		return true
	var t := _ahora()
	var paso: Array = _pasos[_paso]
	if t < _desde + float(paso[0]):
		return false
	var hecho: bool = (paso[1] as Callable).call()
	if hecho:
		_paso += 1
		_desde = t
	return false


# --- Pasos --------------------------------------------------------------------

func _preparar() -> bool:
	_healer._sprite.flip_h = false
	# La batalla todavia no arma la vineta: sin ella la foto del golpe no
	# mostraria el borde rojo.
	if root.get_tree().get_nodes_in_group(Vineta.GRUPO).is_empty():
		_battle.add_child(Vineta.new())
	_a.vida = _a.vida_maxima * 0.35
	_b.vida = _b.vida_maxima * 0.5
	_c.vida = _c.vida_maxima * 0.6
	_caido.derribar()
	return true


## Aprieta un boton parado en su lugar y mirando al frente, con mana de sobra:
## la foto es del efecto, no de la cuenta del mana.
func _apretar(entrada: StringName) -> bool:
	_healer.mana = _healer.mana_maximo
	_healer._sprite.flip_h = false
	var salio := _healer.pulsar(entrada)
	print("%5.2f  %-7s -> %s" % [_ahora(), entrada, "sale" if salio else "NO SALE"])
	return true


## El paciente sangra (para que el Vendaje tenga que cortar) y otro queda casi
## lleno, para que la Oleada muestre lo desperdiciado.
func _herir_para_el_combo() -> bool:
	_a.vida = _a.vida_maxima * 0.3
	_a.aplicar_sangrado(8.0)
	_b.vida = _b.vida_maxima - 10.0
	_c.vida = _c.vida_maxima * 0.4
	return true


func _recibir_golpe() -> bool:
	_healer.recibir_dano(12.0, _zombi)
	return true


func _saltar() -> bool:
	_healer.mana = _healer.mana_maximo
	_healer.saltar()
	return true


func _esperar_suelo() -> bool:
	return not _healer.esta_en_el_aire()


## Lo pone delante del healer, dentro de la caja pesada y del lado de la
## camara: detras de la fila no se veria el pilar.
func _traer_caido() -> bool:
	_caido.global_position = _healer.global_position + Vector3(1.3, 0.0, 1.3)
	return true


## Contra el de adelante: detras de la fila, las chispas quedarian tapadas por
## los que estan mas cerca de la camara.
func _golpe_del_zombi() -> bool:
	_zombi.global_position = _c.global_position + Vector3(1.0, 0.0, 0.0)
	_zombi._objetivo = _c
	_zombi._conectar_golpe()
	return true


func _correr(prender: bool) -> bool:
	if prender:
		Input.action_press(&"p1_derecha")
	else:
		Input.action_release(&"p1_derecha")
	return true


func _foto(nombre: String, que: String) -> bool:
	root.get_texture().get_image().save_png("user://" + nombre)
	var vinetas := root.get_tree().get_nodes_in_group(Vineta.GRUPO)
	var vineta: float = (vinetas[0] as Vineta).dano_actual() if not vinetas.is_empty() else -1.0
	var camara := root.get_viewport().get_camera_3d()
	print("%5.2f  %-32s %-16s %4d %5d %6.2f %.1f   (%s)" % [
		_ahora(), nombre, _healer._sprite.animation, NumeroFlotante.cantidad_vivos(),
		_contar(root, "CPUParticles3D"), vineta, camara.fov if camara != null else 0.0, que])
	return true


# --- Ayudantes ----------------------------------------------------------------

## Quietos y sin pelear: cada foto muestra solo lo que se apreto.
func _al_crear(unidad: Unidad3D) -> void:
	unidad.set_physics_process(false)
	if unidad.bando == Unidad3D.Bando.ENEMIGO:
		_zombi = unidad
	elif _a == null:
		_a = unidad
	elif _b == null:
		_b = unidad
	elif _c == null:
		_c = unidad
	else:
		_caido = unidad


func _contar(nodo: Node, clase: String) -> int:
	var cuantos := 1 if nodo.is_class(clase) else 0
	for hijo in nodo.get_children():
		cuantos += _contar(hijo, clase)
	return cuantos


func _ahora() -> float:
	return (Time.get_ticks_msec() - _inicio_ms) / 1000.0


func _grupo(bando: Unidad3D.Bando, tipo: TipoSoldado, pos: Vector3) -> GrupoUnidades:
	var grupo := GrupoUnidades.new()
	grupo.bando = bando
	grupo.tipo = tipo
	grupo.cantidad = 1
	grupo.x_min = pos.x
	grupo.x_max = pos.x
	grupo.z_min = pos.z
	grupo.z_max = pos.z
	return grupo
