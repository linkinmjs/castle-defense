# Movimientos y combos

## Estado del documento

Describe lo que **esta implementado** desde el rediseño de septiembre de 2026:
el healer juega con tres botones (curacion ligera, curacion pesada y salto)
mas el movimiento, y lo que sale con cada boton depende del orden en que se
apretaron. La tabla de datos vive en `tools/gen_movimientos.gd` (genera
`resources/movimientos/*.tres`); este documento explica el porque. El
catalogo anterior de habilidades queda en
[`habilidades_catalogo.md`](habilidades_catalogo.md) como registro de ideas.

---

## 1. Por que tres botones

Con seis habilidades apuntadas con el mouse, la punteria competia con la
decision y en la linea amontonada el click caia en cualquiera. Con tres
botones el juego se aprende con las manos: la **ligera** es el gesto de todos
los dias, la **pesada** compromete (tiene carga y cuesta mas) y el **salto**
saca al healer del suelo, que es donde pegan los barridos, y habilita las
variantes aereas. La decision se traslada a **donde pararse** y a **que orden
apretar**, que es lo que un beat-em-up sabe ensenar.

## 2. Apuntado: la caja que tenes enfrente

Nadie apunta. Cada movimiento mira una caja en el plano del suelo, hacia donde
mira el healer (`scripts/movimientos/apuntado.gd`):

| Caja | Largo hacia el frente | Medio ancho en profundidad | Margen atras |
|---|---|---|---|
| Ligera | 2.4 m | 1.3 m | 0.5 m |
| Pesada | 3.2 m | 2.0 m | 0.5 m |

- La ligera le llega a **un** aliado de su caja: primero el que sangra,
  despues el de menor fraccion de vida, despues el mas cercano. Es pegajosa:
  si el ultimo tocado sigue en la caja y herido, lo mantiene.
- La pesada le llega a **todos** los aliados en pie de su caja, o al
  **derribado** mas cercano si hay uno (entonces es Reanimar).
- Un aliado pegado pero fuera de la caja no cuenta: el juego premia pararse
  bien. Los derribados nunca reciben la ligera.
- Si no hay nadie: el movimiento sale **al aire**, no cobra, no suma al combo
  y lo corta.

## 3. La tabla

`L` = ligera, `P` = pesada. Todo cuesta mana (100 de tope, regenera 7 por
segundo; caido no regenera).

| Entrada | Nombre | Que hace | Mana | Enfriamiento |
|---|---|---|---|---|
| `L` | Toque | +18 a un aliado, instantaneo | 10 | 0.35 s |
| `L L` (mismo aliado) | Vendaje | +18 y corta el sangrado | 10 | 0.35 s |
| `L L P` | Oleada (remate) | +30 a todos los aliados a 4 m alrededor; cierra el combo | 35 | 6 s |
| `L P` | Bendicion | -35 % de dano y +30 % de cadencia durante 8 s al ultimo tocado | 30 | 8 s |
| `P` | Plegaria | carga 0.5 s quieto; +40 a todos los de la caja pesada | 30 | 1.5 s |
| `P` con un derribado al frente | Reanimar | lo levanta con el 35 % de su vida | 40 | 4 s |
| salto + `L` | Impulso | embestida (9.5 m/s, 0.22 s); +12 al primer aliado herido que cruza | 12 | 2.5 s |
| salto + `P` | Caida sanadora | al aterrizar, +25 a los aliados a 3 m y aturde 0.5 s a los enemigos a 2 m (sin dano) | 30 | 5 s |

Ademas del enfriamiento por movimiento hay una **recuperacion por boton**:
0.3 s despues de una ligera y 0.6 s despues de una pesada. Es el ritmo del
combo: apretar rapido no vale mas que apretar bien.

## 4. Como se resuelve que sale

`ComponenteCombos` recuerda los botones que **conectaron** dentro de la
ventana (0.7 s desde el ultimo que conecto; se pausa mientras algo carga).
Al apretar, califican los movimientos equipados con esa entrada, el mismo
estado de salto que el healer, una `secuencia_previa` que coincide con el
final de lo apretado y, si lo piden, un derribado al frente. Gana el de mayor
`especificidad()`:

```
especificidad = pasos de secuencia_previa * 2 + 5 si requiere derribado + 1 si es aereo
```

Un cuerpo en el suelo manda: `[L, L] + P` con un derribado adelante es
Reanimar (5), no Oleada (4). El combo se corta por golpe al aire, por recibir
dano, por vencer la ventana o por remate.

## 5. Lo que se ve y se siente

- Cada movimiento tiene su pose del healer (`healing`, `power_boost` al
  cargar, `energy_wave`, `magic_shield`, `resurrection`, `aerial_strike`) y
  su efecto propio de `fx_frames`.
- Numeros flotantes: verde lo que entro, gris lo que se desperdicio, rojo el
  dano al healer. Chispas al golpear, brillo al curar, polvo al correr y
  aterrizar, estela en el Impulso.
- Los remates frenan el tiempo 0.05 s y dan un punch de camara; los golpes
  anunciados del bruto y del jefe sacuden la vista.
- El HUD muestra, por jugador, el icono y la tecla de lo que saldria ahora
  con cada boton, el enfriamiento, la ventana del combo y la carga.
- Todo lo que no cambia el juego pasa por `Presentacion.activa()` y se apaga
  en headless: las pruebas siguen deterministas.

## 6. Que registra la telemetria

`usos_por_movimiento`, `usos_por_jugador`, `combo_maximo`,
`movimientos_en_vacio`, mana gastado por costo real, y los eventos
`movimiento` con jugador y cuenta del combo. La observacion causal del resumen
habla de Vendaje y Reanimar por nombre.

## 7. Pruebas

`tools/test_apuntado_auto.gd` (cajas y prioridades), `tools/test_combos.gd`
(cada fila de la tabla, ventana, recuperacion, golpes al aire, corte por dano,
especificidad, loadout), `tools/test_entradas.gd` (acciones por jugador y
dispositivos), `tools/test_enganche.gd` (poses y efectos por movimiento).
