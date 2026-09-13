class_name Habilidad
extends Resource
## Datos de una habilidad del healer. No guarda estado de runtime: los
## enfriamientos los lleva ComponenteHabilidades, asi que el mismo recurso
## puede reutilizarse sin problemas.
##
## El healer se recibe como Node y se usa por duck typing a proposito: tiparlo
## como Healer crearia un ciclo entre el recurso y el nodo que lo usa.

enum Objetivo {
	ALIADO,  ## necesita un aliado apuntado y dentro del alcance
	AREA,    ## afecta a todos los aliados alrededor del healer
	PROPIA,  ## actua sobre el healer
}

@export var nombre: String = ""
## Accion de input que la dispara. El healer busca por aca y no por posicion en
## la lista: un encuentro puede entregar media docena de habilidades o una sola,
## y la tecla tiene que seguir haciendo lo mismo en los dos casos.
@export var accion: StringName = &""
## Etiqueta de la tecla, solo para mostrar en el HUD.
@export var tecla: String = ""
@export var costo: float = 0.0
@export var enfriamiento: float = 1.0
@export var objetivo: Objetivo = Objetivo.ALIADO
@export var color: Color = Color.WHITE
@export_multiline var descripcion: String = ""


func requiere_objetivo() -> bool:
	return objetivo == Objetivo.ALIADO


## Devuelve el motivo por el que no puede usarse, o "" si se puede.
func motivo_bloqueo(_healer: Node) -> String:
	return ""


## Aplica el efecto y devuelve el texto que se muestra en el HUD.
func ejecutar(_healer: Node) -> String:
	return ""


## Que haria esta habilidad sobre ese objetivo, para la tarjeta al apuntar.
## Devuelve "" si no aplica.
##
## Vive aca y no en el HUD porque cada habilidad es la unica que sabe cuenta
## hacer. La tarjeta muestra la consecuencia, nunca cual conviene: decidir es
## del jugador.
func previsualizar(_healer: Node, _objetivo: Node) -> String:
	return ""
