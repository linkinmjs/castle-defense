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

@export_group("Presentacion")
## Lado del cuadro de la hoja, en px. Los pies estan en el borde de abajo del
## cuadro: la unidad sube el sprite medio lado para apoyarlos en el suelo.
@export var lado_frame: int = 128
## Alto que ocupa el personaje dentro del cuadro, en px. No es el lado: en una
## hoja de 128 el soldado ocupa ~68 y el resto es aire para el arma.
@export var alto_util_px: float = 68.0
## Alto con el que se ve en el mundo. Junto con alto_util_px da el tamano del
## pixel, asi hojas de 40, 96 o 128 px quedan a la escala que el tipo pide.
@export var altura_metros: float = 2.0
## Cuanto ocupa en la linea: los cuerpos se bloquean entre si, y uno grande
## tiene que tapar el frente como uno grande.
@export var radio_colision: float = 0.32
## A que altura sobre los pies va la barra de vida. La lee quien la dibuje.
@export var altura_barra: float = 2.1

@export_group("Ataque telegrafiado")
## Segundos de aviso con una marca en el suelo antes de que el golpe caiga.
## 0 = golpe normal. Un golpe que pega fuerte tiene que verse venir: con el
## aviso el healer decide si salta, si bendice al que lo va a recibir o si
## cura despues.
@export var telegrafiado: float = 0.0
## Pega a ras del suelo: quien esta en el aire en el momento del golpe (el
## healer saltando) lo esquiva.
@export var barrido: bool = false
## 0 = pega solo al objetivo. Mayor que 0 = pega a todos los rivales que
## esten a esta distancia de donde cae el golpe, healers incluidos.
@export var radio_golpe: float = 0.0
## Segundo ataque que alterna con "attack" al azar sembrado. Vacio = uno solo.
@export var anim_ataque_2: String = ""
## Dano del segundo ataque respecto de `dano`.
@export var factor_ataque_2: float = 1.5
## El jefe del nivel. Quien arme el HUD lo usa para darle su propia barra.
@export var es_jefe: bool = false
