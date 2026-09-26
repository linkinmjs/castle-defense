class_name Sector
extends Resource
## Un tramo de un nivel largo: lo que hay que resolver antes de seguir.
##
## En un campo de hasta 90 m, con todo desplegado de entrada, la tropa se
## adelantaba sola hasta chocar con enemigos que la camara no mostraba y a
## donde el healer no llegaba a tiempo. Partido en sectores, cada pelea pasa
## donde esta la camara: mientras el sector esta en curso nadie pasa de su
## x_fin, y sus enemigos recien entran cuando alguien llega. El ritmo es el
## del genero: pelear, avanzar, pelear.

enum Liberacion {
	SIN_ENEMIGOS,    ## cuando no queda ningun enemigo en juego (los tirados cuentan)
	FRENTE_PASA_X,   ## cuando el frente avanza hasta la X indicada o mas alla
	RELOJ,           ## a los N segundos de haber entrado al sector
}

## Lo que el HUD muestra al entrar: el nombre del tramo.
@export var titulo: String = ""
## Borde derecho mientras el sector esta en curso: la camara no muestra mas
## alla, los healers se frenan un poco antes y los aliados tambien.
@export var x_fin: float = 30.0

@export_group("Composicion")
## Enemigos que entran cuando alguien llega al sector. Sus X son absolutas;
## conviene que arranquen a 9 m o mas del x_fin del sector anterior: a menos,
## el jugador los ve aparecer (la media pantalla es de unos 7.5 m). La batalla
## avisa si no.
@export var grupos: Array[GrupoUnidades] = []
## Aliados que se suman al entrar, tambien en X absolutas.
@export var refuerzos_aliados: Array[GrupoUnidades] = []
## Como las del encuentro, pero el RELOJ cuenta desde que se entro al sector y
## no desde que arranco el encuentro. Los demas disparadores van igual.
@export var oleadas: Array[OleadaEncuentro] = []

@export_group("Liberacion")
## Que hace falta para poder seguir. Liberado, el limite pasa al x_fin del
## siguiente y la batalla avisa que se puede avanzar.
@export var liberacion: Liberacion = Liberacion.SIN_ENEMIGOS
## Posicion del frente o segundos, segun la liberacion. SIN_ENEMIGOS no lo usa.
@export var valor_liberacion: float = 0.0

@export_group("Que esta en juego")
## Prende los emergentes mientras el sector esta en curso, aunque el encuentro
## no los tenga. Si el encuentro ya los tiene, siguen igual.
@export var emergentes: bool = false
