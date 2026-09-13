class_name OleadaEncuentro
extends Resource
## Refuerzos que entran cuando pasa algo, no solo cuando pasa el tiempo.
##
## Un reloj fijo hace que toda la dificultad dependa de cuanto tardo el
## jugador. Atar la oleada a una baja o al avance del frente la vuelve una
## consecuencia de lo que ocurrio en el campo, que es lo que se puede leer y
## aprender.

enum Disparador {
	RELOJ,           ## a los N segundos de empezar el encuentro
	BAJAS_ALIADAS,   ## cuando murieron N aliados
	FRENTE_PASA_X,   ## cuando el frente cruza la X indicada
	SIN_ENEMIGOS,    ## cuando no queda ningun enemigo en pie
}

@export var disparador: Disparador = Disparador.RELOJ
## Segundos, cantidad de bajas o posicion del frente, segun el disparador.
@export var valor: float = 10.0
## Si se repite, vuelve a dispararse cada vez que se cumple la condicion.
@export var repetir: bool = false
@export var grupos: Array[GrupoUnidades] = []
