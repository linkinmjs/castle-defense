extends SceneTree
## Genera los encuentros de la vertical de aprendizaje y la campania que los
## ordena.
##
## Estan escritos como codigo y no a mano en el editor por la misma razon que
## las escenas: son muchos recursos anidados, y verlos juntos en un archivo
## hace evidente que cambia de un encuentro al siguiente. La progresion es el
## contenido, y aca se lee de corrido.

const DIR := "res://resources/encuentros"
const DIR_PRUEBAS := "res://resources/encuentros/pruebas"

const ESCUDERO := "res://resources/soldados/escudero.tres"
const LANCERO := "res://resources/soldados/lancero.tres"
const ESPADACHIN := "res://resources/soldados/espadachin.tres"
const ZOMBIE := "res://resources/soldados/zombie.tres"

const CURAR := "res://resources/habilidades3d/curar.tres"
const ESTABILIZAR := "res://resources/habilidades3d/estabilizar.tres"
const OLEADA := "res://resources/habilidades3d/oleada.tres"
const BENDICION := "res://resources/habilidades3d/bendicion.tres"
const IMPULSO := "res://resources/habilidades3d/impulso.tres"
const REANIMAR := "res://resources/habilidades3d/reanimar.tres"

# No es const: PackedStringArray no cuenta como expresion constante.
var NOMBRES := PackedStringArray([
	"Mara", "Tobias", "Elsa", "Bruno", "Nadia", "Ciro", "Delia", "Ivan",
])


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_PRUEBAS))

	var e1 := _mantener_la_linea()
	var e2 := _no_desperdiciar()
	var e3 := _tratar_la_causa()

	var campana := Campana.new()
	campana.encuentros = [e1, e2, e3] as Array[Encuentro]
	_guardar(campana, DIR + "/campana.tres")

	_guardar(_abierto(), DIR_PRUEBAS + "/abierto.tres")
	print("encuentros generados")
	quit()


## Leccion 1: acercarse, apuntar, curar y ver el efecto sobre el frente.
##
## Sin sangrado y sin mas herramientas que Curar. El unico problema es la vida
## que falta, que es la variable que hay que aprender a leer primero. Los
## escuderos aguantan lo suficiente como para que el error no sea instantaneo.
func _mantener_la_linea() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"e1_mantener_linea"
	enc.titulo = "Mantener la linea"
	enc.objetivo_pedagogico = "Curar a tiempo sostiene el frente."
	enc.semilla = 71001
	enc.nombres = NOMBRES
	enc.sangrado_habilitado = false
	enc.habilidades = _habilidades([CURAR])
	enc.condicion = Encuentro.Condicion.SOBREVIVIR
	enc.duracion = 75.0
	enc.bajas_aliadas_maximas = 2
	enc.frente_derrota_x = 8.0
	enc.grupos_iniciales = _grupos([
		_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 4, 13.0, 15.0),
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 5, 16.5, 18.5),
	])

	# Refuerzos enemigos cada 12 s: la presion sube sola, y el jugador puede
	# anticiparla porque el ritmo es estable.
	var oleada := OleadaEncuentro.new()
	oleada.disparador = OleadaEncuentro.Disparador.RELOJ
	oleada.valor = 12.0
	oleada.repetir = true
	oleada.grupos = _grupos([_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 2, 26.0, 28.0)])
	enc.oleadas = [oleada] as Array[OleadaEncuentro]

	_guardar(enc, DIR + "/e1_mantener_linea.tres")
	return enc


## Leccion 2: overhealing y costo de oportunidad.
##
## Mismos elementos que el anterior, pero con heridas de distinta magnitud y
## mana recortado. Curar al primero que se ve deja de alcanzar: hay que elegir
## a quien aprovecha la curacion entera.
func _no_desperdiciar() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"e2_no_desperdiciar"
	enc.titulo = "No desperdiciar"
	enc.objetivo_pedagogico = "Lo que sobra de una curacion se pierde."
	enc.semilla = 71002
	enc.nombres = NOMBRES
	enc.sangrado_habilitado = false
	enc.habilidades = _habilidades([CURAR])
	enc.mana_maximo = 60.0
	enc.regeneracion_mana = 4.0
	enc.condicion = Encuentro.Condicion.SOBREVIVIR
	enc.duracion = 75.0
	enc.bajas_aliadas_maximas = 2
	enc.frente_derrota_x = 8.0

	# Tres estados de herida bien distintos: el que esta por caer, el que
	# aprovecha una curacion entera, y el que casi no la necesita.
	var grave := _grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 2, 13.0, 14.5)
	grave.vida_inicial = 0.35
	var medio := _grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 2, 13.0, 14.5)
	medio.vida_inicial = 0.60
	var sano := _grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 2, 13.0, 14.5)
	sano.vida_inicial = 0.95
	enc.grupos_iniciales = _grupos([
		grave, medio, sano,
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 6, 16.5, 18.5),
	])

	var oleada := OleadaEncuentro.new()
	oleada.disparador = OleadaEncuentro.Disparador.RELOJ
	oleada.valor = 14.0
	oleada.repetir = true
	oleada.grupos = _grupos([_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 2, 26.0, 28.0)])
	enc.oleadas = [oleada] as Array[OleadaEncuentro]

	enc.metas = [
		_meta(&"fraccion_desperdiciada", MetaEncuentro.Comparador.MENOR_QUE, 0.15,
			"Menos del 15% de curacion desperdiciada"),
	] as Array[MetaEncuentro]

	_guardar(enc, DIR + "/e2_no_desperdiciar.tres")
	return enc


## Leccion 3: cortar la causa antes de reponer la vida.
##
## Entra Estabilizar y el sangrado pasa a ser frecuente. Dos lanceros arrancan
## sangrando para que la situacion este planteada de entrada y no dependa de
## que el azar la produzca. Curar sigue funcionando, pero solo compra tiempo.
func _tratar_la_causa() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"e3_tratar_la_causa"
	enc.titulo = "Tratar la causa"
	enc.objetivo_pedagogico = "Estabilizar corta el daño; curar solo lo repone."
	enc.semilla = 71003
	enc.nombres = NOMBRES
	enc.sangrado_habilitado = true
	enc.probabilidad_sangrado = 0.7
	enc.habilidades = _habilidades([CURAR, ESTABILIZAR])
	enc.condicion = Encuentro.Condicion.SOBREVIVIR
	enc.duracion = 80.0
	enc.bajas_aliadas_maximas = 2
	enc.frente_derrota_x = 8.0

	var sangrando := _grupo(LANCERO, Unidad3D.Bando.ALIADO, 2, 12.5, 13.5)
	sangrando.vida_inicial = 0.7
	sangrando.sangrado_inicial = 6.0
	enc.grupos_iniciales = _grupos([
		_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 3, 13.5, 15.0),
		sangrando,
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 6, 16.5, 18.5),
	])

	var oleada := OleadaEncuentro.new()
	oleada.disparador = OleadaEncuentro.Disparador.RELOJ
	oleada.valor = 13.0
	oleada.repetir = true
	oleada.grupos = _grupos([_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 3, 26.0, 28.0)])
	enc.oleadas = [oleada] as Array[OleadaEncuentro]

	enc.metas = [
		_meta(&"sangrados_sin_tratar", MetaEncuentro.Comparador.IGUAL, 0.0,
			"Ningun sangrado quedo sin tratar"),
		_meta(&"tiempo_hasta_estabilizar", MetaEncuentro.Comparador.MENOR_IGUAL, 3.0,
			"Menos de 3 segundos para cortar un sangrado"),
	] as Array[MetaEncuentro]

	_guardar(enc, DIR + "/e3_tratar_la_causa.tres")
	return enc


## La batalla completa de siempre: los tres tipos aliados, la horda, las seis
## habilidades y victoria por llegar a la base. No es parte de la campania;
## existe para que las pruebas sigan ejercitando el caso abierto.
func _abierto() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"abierto"
	enc.titulo = "Batalla abierta"
	enc.objetivo_pedagogico = "Todo junto, como estaba antes de la vertical."
	enc.semilla = 0
	enc.nombres = NOMBRES
	enc.emergentes_habilitados = true
	enc.habilidades = _habilidades([CURAR, ESTABILIZAR, OLEADA, BENDICION, IMPULSO, REANIMAR])
	enc.condicion = Encuentro.Condicion.LLEGAR_A_BASE
	enc.grupos_iniciales = _grupos([
		_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 2, 10.5, 13.5),
		_grupo(LANCERO, Unidad3D.Bando.ALIADO, 2, 10.5, 13.5),
		_grupo(ESPADACHIN, Unidad3D.Bando.ALIADO, 2, 10.5, 13.5),
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 9, 16.5, 20.5),
	])

	var refuerzos := OleadaEncuentro.new()
	refuerzos.disparador = OleadaEncuentro.Disparador.RELOJ
	refuerzos.valor = 9.0
	refuerzos.repetir = true
	refuerzos.grupos = _grupos([
		_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 2, 2.0, 3.0),
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 3, 27.0, 28.0),
	])
	enc.oleadas = [refuerzos] as Array[OleadaEncuentro]

	return enc


# --- Ayudantes ----------------------------------------------------------------

func _grupo(ruta_tipo: String, bando: Unidad3D.Bando, cantidad: int,
		x_min: float, x_max: float) -> GrupoUnidades:
	var g := GrupoUnidades.new()
	g.tipo = load(ruta_tipo)
	g.bando = bando
	g.cantidad = cantidad
	g.x_min = x_min
	g.x_max = x_max
	g.z_min = 1.5
	g.z_max = 8.5
	return g


func _meta(clave: StringName, comparador: MetaEncuentro.Comparador,
		valor: float, texto: String) -> MetaEncuentro:
	var m := MetaEncuentro.new()
	m.clave = clave
	m.comparador = comparador
	m.valor = valor
	m.texto = texto
	return m


func _grupos(lista: Array) -> Array[GrupoUnidades]:
	var tipado: Array[GrupoUnidades] = []
	for g: GrupoUnidades in lista:
		tipado.append(g)
	return tipado


func _habilidades(rutas: Array) -> Array[Habilidad]:
	var lista: Array[Habilidad] = []
	for ruta: String in rutas:
		lista.append(load(ruta))
	return lista


func _guardar(recurso: Resource, ruta: String) -> void:
	var error := ResourceSaver.save(recurso, ruta)
	if error != OK:
		push_error("no se pudo guardar %s (error %d)" % [ruta, error])
		return
	recurso.take_over_path(ruta)
	print("  %s" % ruta)
