class_name TipoSoldado
extends Resource
## Datos de un tipo de soldado: stats, sprites y estilo de combate.
##
## La misma escena de unidad sirve para todos: lo que cambia es este recurso.
## Un tipo nuevo vale la pena solo si le crea un problema distinto al healer
## (ver soldados_y_comportamientos.md); variedad por variedad no suma.

@export var nombre: String = ""
@export var frames: SpriteFrames
@export var vida_maxima: float = 80.0
@export var dano: float = 12.0
## Segundos entre golpes.
@export var cadencia: float = 1.1
## En metros. Largo en el lancero: pega desde la segunda fila.
@export var alcance: float = 1.35
@export var velocidad: float = 1.0

@export_group("Estilo de combate")
## Fraccion de dano que no recibe (el escudo del escudero).
@export_range(0.0, 0.9) var reduccion_dano: float = 0.0
## Por debajo de esta fraccion de vida se retira hacia su base. 0 = nunca.
## Con retirada el herido viene solo hacia el healer; sin ella hay que ir
## a buscarlo. Es el dial que mas cambia el ritmo del juego.
@export_range(0.0, 0.9) var retirada_bajo: float = 0.0
## Elige al enemigo mas herido que tenga cerca en vez del mas cercano.
@export var oportunista: bool = false
