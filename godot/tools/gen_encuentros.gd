extends SceneTree
## Genera los encuentros de la vertical de aprendizaje, la campania que los
## ordena y los tres niveles largos del juego (niveles.tres).
##
## Estan escritos como codigo y no a mano en el editor por la misma razon que
## las escenas: son muchos recursos anidados, y verlos juntos en un archivo
## hace evidente que cambia de un encuentro al siguiente. La progresion es el
## contenido, y aca se lee de corrido. Los numeros de los niveles y por que
## son esos estan en docs/niveles.md.

const DIR := "res://resources/encuentros"
const DIR_PRUEBAS := "res://resources/encuentros/pruebas"

const ESCUDERO := "res://resources/soldados/escudero.tres"
const LANCERO := "res://resources/soldados/lancero.tres"
const ESPADACHIN := "res://resources/soldados/espadachin.tres"
const ZOMBIE := "res://resources/soldados/zombie.tres"
const BRUTO := "res://resources/soldados/bruto.tres"
const DEMONIO := "res://resources/soldados/demonio.tres"

## Los movimientos los genera gen_movimientos.gd, que corre antes que este.
const TOQUE := "res://resources/movimientos/toque.tres"
const VENDAJE := "res://resources/movimientos/vendaje.tres"
const PLEGARIA := "res://resources/movimientos/plegaria.tres"
const IMPULSO := "res://resources/movimientos/impulso.tres"
const BENDICION := "res://resources/movimientos/bendicion.tres"
const REANIMAR := "res://resources/movimientos/reanimar.tres"
const CAIDA := "res://resources/movimientos/caida.tres"

const ALIADO := Unidad3D.Bando.ALIADO
const ENEMIGO := Unidad3D.Bando.ENEMIGO
## Las filas por las que se despliega en el puente, que tiene 6 m de
## profundidad y no 10: el mismo margen de 1.5 m que dejan los healers.
const FRANJA_PUENTE := Vector2(1.5, 4.5)
## Cuanto mas alla del x_fin de su sector nace una oleada como minimo, para no
## verse aparecer (ver la nota de los niveles).
const ENTRADA_OLEADA := 3.0

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

	# Cada nivel se guarda en su archivo antes que la serie, para que la serie
	# los referencie en vez de copiarlos adentro.
	var niveles := Campana.new()
	niveles.encuentros = [_el_camino(), _el_puente(), _las_puertas()] as Array[Encuentro]
	_guardar(niveles, DIR + "/niveles.tres")

	_guardar(_abierto(), DIR_PRUEBAS + "/abierto.tres")
	print("encuentros generados")
	quit()


## Leccion 1: acercarse, pararse frente al herido, curar y ver el efecto sobre
## el frente.
##
## Sin sangrado y sin mas herramientas que Toque: la ligera sola, que con
## cualquier secuencia sigue siendo Toque. El unico problema es la vida que
## falta, que es la variable que hay que aprender a leer primero. Los escuderos
## aguantan lo suficiente como para que el error no sea instantaneo.
func _mantener_la_linea() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"e1_mantener_linea"
	enc.titulo = "Mantener la linea"
	enc.objetivo_pedagogico = "Curar a tiempo sostiene el frente."
	enc.semilla = 71001
	enc.nombres = NOMBRES
	enc.sangrado_habilitado = false
	enc.movimientos = _movimientos([TOQUE])
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
	enc.movimientos = _movimientos([TOQUE])
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
## Entra Vendaje (la segunda ligera sobre el mismo paciente) y el sangrado
## pasa a ser frecuente. Dos lanceros arrancan sangrando para que la situacion
## este planteada de entrada y no dependa de que el azar la produzca. Toque
## sigue funcionando, pero solo compra tiempo.
func _tratar_la_causa() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"e3_tratar_la_causa"
	enc.titulo = "Tratar la causa"
	enc.objetivo_pedagogico = "Vendaje (ligera dos veces sobre el mismo) corta el daño; curar solo lo repone."
	enc.semilla = 71003
	enc.nombres = NOMBRES
	enc.sangrado_habilitado = true
	enc.probabilidad_sangrado = 0.7
	enc.movimientos = _movimientos([TOQUE, VENDAJE])
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


# --- Niveles ------------------------------------------------------------------
#
# Cada nivel es un campo largo partido en tres sectores: la tropa avanza sola,
# los healers la mantienen viva, y cada sector suma una sola cosa nueva. Nada
# de derrota por frente (con sectores el frente casi no retrocede) y bajas
# generosas: lo que se castiga es dejar morir, no llegar tarde.
#
# Los enemigos de cada sector arrancan a 9 m o mas de la puerta del anterior
# (la batalla avisa si no). Las oleadas nacen fuera de cuadro, a ENTRADA_OLEADA
# o mas pasado el x_fin de su sector, y entran caminando: mientras el sector
# esta en curso la camara no muestra mas alla de su x_fin (la fila del fondo,
# unos 2.5 m mas), y la tropa espera en x_fin - 2.6. Una oleada dentro del
# sector nacia encima de la tropa y a la vista.

## Nivel 1: el camino. Curar, cortar un sangrado y curar al grupo, en campo
## abierto y sin enemigos que hagan nada raro.
##
## El sangrado es del encuentro y no del sector, asi que va bajo (0.15) para
## que aparezca poco en los dos primeros tramos, y el tercero lo plantea de
## entrada con dos lanceros que llegan sangrando: ahi Vendaje deja de ser una
## opcion. El bosque suma una oleada con reloj para que el grupo junto (y la
## Plegaria) tenga sentido.
func _el_camino() -> Encuentro:
	var enc := _nivel(&"n1_el_camino", "El camino",
		"Toque para curar, dos Toques seguidos para cortar un sangrado, Plegaria para el grupo.",
		72001, 90.0, 10.0)
	enc.probabilidad_sangrado = 0.15
	enc.movimientos = _movimientos([TOQUE, VENDAJE, PLEGARIA, IMPULSO])
	enc.condicion = Encuentro.Condicion.LLEGAR_A_BASE
	enc.bajas_aliadas_maximas = 4
	enc.grupos_iniciales = _grupos([
		_grupo(ESCUDERO, ALIADO, 3, 7.0, 10.0),
		_grupo(LANCERO, ALIADO, 2, 7.0, 10.0),
	])

	var camino := _sector("El camino", 30.0, [
		_grupo(ZOMBIE, ENEMIGO, 5, 18.0, 22.0),
	])

	# Dos zombis cada 20 s desde el fondo del bosque: la presion no depende de
	# lo que tarde el jugador, y el ritmo se aprende. Cada 14 s no: la tropa
	# frenada en su tope tarda mas que eso en matar a cada par, el campo no
	# queda nunca vacio y el sector no se libera.
	var bosque := _sector("El bosque", 60.0, [
		_grupo(ZOMBIE, ENEMIGO, 6, 42.0, 46.0),
	], [
		_grupo(ESCUDERO, ALIADO, 1, 33.0, 34.0),
	], [
		_oleada(OleadaEncuentro.Disparador.RELOJ, 20.0, true, [
			_grupo(ZOMBIE, ENEMIGO, 2, 60.0 + ENTRADA_OLEADA, 65.0),
		]),
	])

	# Los lanceros de refuerzo llegan sangrando: la situacion esta planteada y
	# no depende del azar.
	var sangrando := _grupo(LANCERO, ALIADO, 2, 62.0, 64.0)
	sangrando.sangrado_inicial = 6.0
	var cuesta := _sector("La cuesta", 90.0, [
		_grupo(ZOMBIE, ENEMIGO, 7, 72.0, 76.0),
	], [sangrando])

	enc.sectores = [camino, bosque, cuesta] as Array[Sector]
	_guardar(enc, DIR + "/n1_el_camino.tres")
	return enc


## Nivel 2: el puente. Los golpes anunciados del oso, los caidos y el salto.
##
## Mas angosto (6 m): en el puente la tropa se apelotona, y el barrido del oso
## alcanza a varios. La cabecera presenta a un solo oso entre zombis; el
## puente trae dos escuderos ya caidos para reanimar (8 s de reloj cada uno) y
## prende los emergentes, que salen como zombis; la otra orilla trae dos osos,
## uno detras del otro, para que se lea cada golpe.
##
## Es el salto grande de dificultad, y por eso la tropa trae un lancero mas y
## las peleas son mas cortas que las del primer nivel: los caidos piden 80 de
## mana en 8 s, justo despues del primer oso (ver docs/niveles.md).
func _el_puente() -> Encuentro:
	var enc := _nivel(&"n2_el_puente", "El puente",
		"Bendeci (L, P) a quien va a recibir el golpe del oso; Reanima (P) a los caidos; salta el barrido.",
		72002, 90.0, 6.0)
	enc.probabilidad_sangrado = 0.15
	enc.movimientos = _movimientos([TOQUE, VENDAJE, PLEGARIA, IMPULSO, BENDICION, REANIMAR, CAIDA])
	enc.condicion = Encuentro.Condicion.LLEGAR_A_BASE
	enc.bajas_aliadas_maximas = 4
	enc.grupos_iniciales = _franja([
		_grupo(ESCUDERO, ALIADO, 4, 7.0, 10.0),
		_grupo(ESPADACHIN, ALIADO, 1, 7.0, 10.0),
		_grupo(LANCERO, ALIADO, 1, 7.0, 10.0),
	])

	var cabecera := _sector("La cabecera", 30.0, _franja([
		_grupo(ZOMBIE, ENEMIGO, 3, 18.0, 22.0),
		_grupo(BRUTO, ENEMIGO, 1, 22.0, 24.0),
	]))

	# Los caidos, pegados a la puerta: se llega a ellos antes que los zombis.
	var caidos := _grupo(ESCUDERO, ALIADO, 2, 31.0, 33.0)
	caidos.derribada_inicial = true
	var puente := _sector("El puente", 60.0, _franja([
		_grupo(ZOMBIE, ENEMIGO, 5, 44.0, 48.0),
	]), _franja([caidos]))
	puente.emergentes = true

	var orilla := _sector("La otra orilla", 90.0, _franja([
		_grupo(BRUTO, ENEMIGO, 1, 72.0, 74.0),
		_grupo(ZOMBIE, ENEMIGO, 3, 76.0, 80.0),
		_grupo(BRUTO, ENEMIGO, 1, 80.0, 82.0),
	]), _franja([
		_grupo(LANCERO, ALIADO, 1, 63.0, 63.0),
		_grupo(ESCUDERO, ALIADO, 1, 62.0, 64.0),
	]))

	enc.sectores = [cabecera, puente, orilla] as Array[Sector]
	_guardar(enc, DIR + "/n2_el_puente.tres")
	return enc


## Nivel 3: las puertas. Todo lo aprendido contra el jefe.
##
## Se gana dejando el campo limpio, y con sectores eso solo cuenta en el
## ultimo. La muralla castiga cada baja con dos zombis mas (la cuenta es la
## del nivel entero: quien llega con muertos del foso los paga al entrar), y
## en las puertas el demonio pega en area con dos golpes anunciados mientras
## cada 20 s llegan dos zombis. Todos los movimientos.
##
## Lo que decide este nivel es el demonio y no su escolta: sin zombis delante,
## con la vida recortada o con mas tropa se gana apenas mas seguido (ver
## docs/niveles.md). Si hay que aflojarlo, es en demonio.tres.
func _las_puertas() -> Encuentro:
	var enc := _nivel(&"n3_las_puertas", "Las puertas",
		"El demonio anuncia sus golpes: Bendeci, cura en area con Oleada (L, L, P) y no te quedes parado.",
		72003, 70.0, 10.0)
	enc.probabilidad_sangrado = 0.2
	# Vacia: todos los de la escena del healer.
	enc.movimientos = [] as Array[Movimiento]
	enc.condicion = Encuentro.Condicion.LIMPIAR_ENEMIGOS
	enc.bajas_aliadas_maximas = 5
	enc.grupos_iniciales = _grupos([
		_grupo(ESCUDERO, ALIADO, 3, 7.0, 10.0),
		_grupo(LANCERO, ALIADO, 2, 7.0, 10.0),
		_grupo(ESPADACHIN, ALIADO, 1, 7.0, 10.0),
	])

	var foso := _sector("El foso", 25.0, [
		_grupo(ZOMBIE, ENEMIGO, 5, 15.0, 19.0),
		_grupo(BRUTO, ENEMIGO, 1, 19.0, 21.0),
	])

	var muralla := _sector("La muralla", 50.0, [
		_grupo(ZOMBIE, ENEMIGO, 8, 36.0, 42.0),
	], [
		_grupo(ESCUDERO, ALIADO, 2, 27.0, 29.0),
	], [
		_oleada(OleadaEncuentro.Disparador.BAJAS_ALIADAS, 1.0, true, [
			_grupo(ZOMBIE, ENEMIGO, 2, 50.0 + ENTRADA_OLEADA, 55.0),
		]),
	])

	# Los de la oleada salen por las puertas, pasado el borde del campo: la
	# camara nunca muestra mas alla del ancho.
	var puertas := _sector("Las puertas", 70.0, [
		_grupo(DEMONIO, ENEMIGO, 1, 62.0, 64.0),
		_grupo(ZOMBIE, ENEMIGO, 3, 60.0, 62.0),
	], [], [
		_oleada(OleadaEncuentro.Disparador.RELOJ, 20.0, true, [
			_grupo(ZOMBIE, ENEMIGO, 2, 70.0 + ENTRADA_OLEADA, 75.0),
		]),
	])

	enc.sectores = [foso, muralla, puertas] as Array[Sector]
	_guardar(enc, DIR + "/n3_las_puertas.tres")
	return enc


## La batalla completa de siempre: los tres tipos aliados, la horda, todos los
## movimientos y victoria por llegar a la base. No es parte de la campania;
## existe para que las pruebas sigan ejercitando el caso abierto.
func _abierto() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"abierto"
	enc.titulo = "Batalla abierta"
	enc.objetivo_pedagogico = "Todo junto, como estaba antes de la vertical."
	enc.semilla = 0
	enc.nombres = NOMBRES
	enc.emergentes_habilitados = true
	# Vacia: todos los de la escena del healer.
	enc.movimientos = [] as Array[Movimiento]
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


## Lo comun a los niveles: el campo largo con las bases a 1.5 m de cada punta,
## el healer detras de la tropa y en la mitad de la profundidad, los nombres,
## el sangrado prendido y sin derrota por frente.
func _nivel(id: StringName, titulo: String, objetivo: String, semilla: int,
		ancho: float, profundidad: float) -> Encuentro:
	var enc := Encuentro.new()
	enc.id = id
	enc.titulo = titulo
	enc.objetivo_pedagogico = objetivo
	enc.semilla = semilla
	enc.nombres = NOMBRES
	enc.ancho_campo = ancho
	enc.profundidad_campo = profundidad
	enc.base_aliada_x = 1.5
	enc.base_enemiga_x = ancho - 1.5
	enc.healer_inicial = Vector2(6.0, profundidad * 0.5)
	enc.sangrado_habilitado = true
	enc.frente_derrota_x = -1.0
	return enc


## Un tramo que se libera al quedar sin enemigos en juego, que es como se
## liberan todos los de los niveles: el cartel de avanzar llega cuando el
## campo esta limpio, no por reloj.
func _sector(titulo: String, x_fin: float, grupos: Array, refuerzos: Array = [],
		oleadas: Array = []) -> Sector:
	var s := Sector.new()
	s.titulo = titulo
	s.x_fin = x_fin
	s.grupos = _grupos(grupos)
	s.refuerzos_aliados = _grupos(refuerzos)
	var tipadas: Array[OleadaEncuentro] = []
	for o: OleadaEncuentro in oleadas:
		tipadas.append(o)
	s.oleadas = tipadas
	s.liberacion = Sector.Liberacion.SIN_ENEMIGOS
	return s


func _oleada(disparador: OleadaEncuentro.Disparador, valor: float, repetir: bool,
		grupos: Array) -> OleadaEncuentro:
	var o := OleadaEncuentro.new()
	o.disparador = disparador
	o.valor = valor
	o.repetir = repetir
	o.grupos = _grupos(grupos)
	return o


## Los grupos de la lista, desplegados en las filas del puente.
func _franja(lista: Array) -> Array[GrupoUnidades]:
	var tipado := _grupos(lista)
	for g in tipado:
		g.z_min = FRANJA_PUENTE.x
		g.z_max = FRANJA_PUENTE.y
	return tipado


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


func _movimientos(rutas: Array) -> Array[Movimiento]:
	var lista: Array[Movimiento] = []
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
