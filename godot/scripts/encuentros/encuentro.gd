class_name Encuentro
extends Resource
## Todo lo que define una batalla concreta: quienes entran, con que estados,
## que movimientos tiene el healer y cuando termina.
##
## La batalla dejaba de ser comparable entre intentos porque la composicion se
## decidia con relojes globales y azar sin semilla. Definirla como dato permite
## repetir el mismo problema, restringir lo que esta en juego y enseñar una
## cosa por vez (ver mejoras_desde_a_theory_of_fun.md, 6.1).

enum Condicion {
	LLEGAR_A_BASE,      ## gana quien alcanza la base contraria
	SOBREVIVIR,         ## hay que aguantar la duracion sin perder
	LIMPIAR_ENEMIGOS,   ## gana el jugador cuando no queda ningun enemigo
}

@export var id: StringName = &""
@export var titulo: String = ""
## Que se supone que el jugador aprende aca. Se muestra al empezar y vuelve a
## aparecer en el resumen.
@export_multiline var objetivo_pedagogico: String = ""
## En 0 se sortea al iniciar y queda fija, para que reiniciar repita la misma.
@export var semilla: int = 0

@export_group("Campo")
@export var ancho_campo: float = 30.0
@export var profundidad_campo: float = 10.0
@export var base_aliada_x: float = 1.5
@export var base_enemiga_x: float = 28.5
## Donde arranca el healer, en x y z.
@export var healer_inicial: Vector2 = Vector2(15.0, 5.0)

@export_group("Composicion")
@export var grupos_iniciales: Array[GrupoUnidades] = []
@export var oleadas: Array[OleadaEncuentro] = []
## Nombres propios para repartir entre los aliados. Un soldado con nombre pesa
## distinto que uno sin nombre cuando hay que elegir a quien salvar.
@export var nombres: PackedStringArray = []

@export_group("Sectores")
## Los tramos de un nivel largo, en orden: cada uno frena a la camara, a los
## healers y a la tropa en su x_fin hasta que se libera (ver Sector). Vacio es
## el comportamiento de siempre: todo el campo es un solo sector implicito.
## Los grupos_iniciales siguen siendo la tropa del arranque, y el primer sector
## entra junto con ella.
@export var sectores: Array[Sector] = []

@export_group("Que esta en juego")
## Con el sangrado apagado, el unico problema es la vida que falta. Es lo que
## permite enseñar a curar antes de enseñar a tratar la causa.
@export var sangrado_habilitado: bool = true
## En -1 cada tipo usa su propia probabilidad.
@export var probabilidad_sangrado: float = -1.0
@export var emergentes_habilitados: bool = false

@export_group("Healer")
## Lo que se equipa al empezar. Vacia = se equipan todos los que trae la
## escena del healer. Es explicito a proposito: un encuentro que no dice nada
## juega con todo, no con lo que dejo equipado el encuentro anterior.
@export var movimientos: Array[Movimiento] = []
## En -1 no se tocan y quedan los de la escena.
@export var mana_maximo: float = -1.0
@export var regeneracion_mana: float = -1.0

@export_group("Desenlace")
@export var condicion: Condicion = Condicion.LLEGAR_A_BASE
## Segundos que hay que aguantar en SOBREVIVIR. En las demas condiciones, 0
## significa sin limite de tiempo.
@export var duracion: float = 0.0
## Cuantos aliados pueden morir antes de perder. En -1 no hay limite.
@export var bajas_aliadas_maximas: int = -1
## Si el frente retrocede mas alla de esta X, se pierde. En -1 no se evalua.
@export var frente_derrota_x: float = -1.0
## Exito secundario: no decide la victoria, describe que es jugarlo bien.
@export var metas: Array[MetaEncuentro] = []
