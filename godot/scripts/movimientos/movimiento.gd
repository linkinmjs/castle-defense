class_name Movimiento
extends Resource
## Un movimiento del healer: que boton lo dispara, en que punto del combo sale
## y que hace al conectar.
##
## Reemplaza a las habilidades. El jugador ya no elige de una lista ni apunta:
## tiene una ligera y una pesada, y el orden en que las toca decide que sale
## (la tabla completa esta en tools/gen_movimientos.gd). A quien le llega lo
## decide Apuntado, segun donde este parado el healer.
##
## Como las habilidades, no guarda estado de runtime: enfriamientos, secuencia
## y ventana los lleva ComponenteCombos, asi el mismo recurso sirve para
## cualquier healer. El healer se recibe como Node3D y se usa por duck typing,
## por la misma razon de siempre: tiparlo ataria el recurso a la escena.

## Motivo de bloqueo que en realidad es un golpe al aire: el componente no lo
## trata como un rechazo sino como un whiff (anima, no cobra y corta el combo).
const SIN_OBJETIVO := "Sin objetivo"
## Tope de destellos por uso: una plegaria sobre diez soldados con diez efectos
## tapa justo lo que el jugador quiere ver, que es a quien le subio la vida.
const MAX_EFECTOS := 6

@export var nombre: String = ""
## Boton que lo dispara: &"ligera" o &"pesada".
@export var entrada: StringName = &"ligera"
## Solo sale en el aire, y en el aire solo salen los que tienen esto.
@export var en_el_aire: bool = false
## Botones que tienen que venir justo antes dentro del combo, en orden.
## Vacia = sale en cualquier momento.
@export var secuencia_previa: Array[StringName] = []
## Solo sale con un aliado derribado al frente.
@export var requiere_derribado: bool = false
## Cierra el combo al conectar: es el remate.
@export var termina_combo: bool = false
## Se aprieta en el aire y se resuelve al tocar el suelo.
@export var al_aterrizar: bool = false
@export var costo: float = 0.0
## Segundos hasta poder repetir este movimiento.
@export var enfriamiento: float = 0.0
## Segundos que su boton queda bloqueado despues de conectar. Es el ritmo del
## combo: sin esto, apretar rapido valdria mas que apretar bien.
@export var recuperacion: float = 0.3
## Segundos entre apretar y que salga el efecto, con el healer comprometido.
## Es el precio de las curas grandes.
@export var wind_up: float = 0.0
## Animacion del healer al soltarlo.
@export var animacion: String = "cast"
## Animacion de fx_frames que aparece sobre lo que alcanza.
@export var efecto: String = "heal"
@export var color: Color = Color.WHITE
## Dibujo para el HUD. Opcional: sin icono se muestra el nombre.
@export var icono: Texture2D
@export_multiline var descripcion: String = ""


## Cuanto pide para salir. Entre los que califican gana el mas exigente: cada
## paso de secuencia vale 2, un derribado al frente 5 (mas que cualquier combo
## de dos pasos: un cuerpo en el suelo manda) y el aire 1.
func especificidad() -> int:
	var valor := secuencia_previa.size() * 2
	if requiere_derribado:
		valor += 5
	if en_el_aire:
		valor += 1
	return valor


## "" si puede salir. SIN_OBJETIVO si saldria al aire. Cualquier otro texto es
## un rechazo con explicacion ("Ya bendecido") que no cuenta como whiff.
func motivo_bloqueo(_healer: Node3D) -> String:
	return ""


## Aplica el efecto y devuelve {conecto, objetivo, efectivo, aviso}: si
## conecto, sobre quien (null si fueron varios o nadie en particular), cuanta
## vida entro de verdad y un texto corto para el HUD. Si no conecto, no tiene
## que haber cambiado nada: el componente no cobra.
func ejecutar(_healer: Node3D) -> Dictionary:
	return _resultado(false)


## Que haria sobre ese aliado, para la ficha del HUD; "" si no aplica. Muestra
## la consecuencia y nunca cual conviene: decidir es del jugador.
func previsualizar(_healer: Node3D, _objetivo: Unidad3D) -> String:
	return ""


func _resultado(conecto: bool, objetivo: Node3D = null, efectivo: float = 0.0,
		aviso: String = "") -> Dictionary:
	return {"conecto": conecto, "objetivo": objetivo, "efectivo": efectivo, "aviso": aviso}


## El ultimo aliado que toco el combo en curso de este healer, o null.
##
## Se busca por duck typing y no por tipo: tipar el componente crearia un ciclo
## entre el recurso y el nodo que lo corre. Primero por su nombre de siempre,
## Combos; si no esta, cualquier hijo que sepa responder.
func _ultimo_tocado(healer: Node3D) -> Unidad3D:
	var combos := healer.get_node_or_null(^"Combos")
	if combos == null or not combos.has_method(&"ultimo_objetivo"):
		combos = null
		for hijo in healer.get_children():
			if hijo.has_method(&"ultimo_objetivo"):
				combos = hijo
				break
	if combos == null:
		return null
	return combos.call(&"ultimo_objetivo") as Unidad3D


## "+18", o "+11 (7 desperdiciado)" si parte de la cura no entro.
static func _texto_cura(pedido: float, entro: float) -> String:
	var sobra := pedido - entro
	if sobra >= 1.0:
		return "+%d (%d desperdiciado)" % [roundi(entro), roundi(sobra)]
	return "+%d" % roundi(entro)


## "+18 HP", o "+11 HP (7 se desperdician)": lo mismo, antes de curar.
static func _texto_previa(unidad: Unidad3D, cantidad: float) -> String:
	var entra := clampf(unidad.vida_maxima - unidad.vida, 0.0, cantidad)
	var sobra := cantidad - entra
	if sobra >= 1.0:
		return "+%d HP (%d se desperdician)" % [roundi(entra), roundi(sobra)]
	return "+%d HP" % roundi(entra)
