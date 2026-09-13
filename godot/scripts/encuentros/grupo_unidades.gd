class_name GrupoUnidades
extends Resource
## Un puñado de soldados del mismo tipo, con el estado en el que entran al
## campo.
##
## Sirve tanto para la formacion inicial como para los refuerzos. Poder
## desplegar a alguien ya herido o ya sangrando es lo que permite plantear una
## situacion concreta desde el primer segundo, en vez de esperar a que el
## combate la produzca sola.

@export var bando: Unidad3D.Bando = Unidad3D.Bando.ALIADO
@export var tipo: TipoSoldado
@export var cantidad: int = 1

@export_group("Donde")
@export var x_min: float = 13.0
@export var x_max: float = 15.0
@export var z_min: float = 1.5
@export var z_max: float = 8.5

@export_group("En que estado entran")
## Fraccion de la vida maxima con la que aparecen. En 1.0 entran sanos.
@export_range(0.05, 1.0) var vida_inicial: float = 1.0
## Segundos de sangrado con los que aparecen. En 0 no sangran.
@export var sangrado_inicial: float = 0.0
## Aparecen ya tirados, con el reloj del derribo corriendo.
@export var derribada_inicial: bool = false
