# Los tres niveles

## Qué son

Tres campos largos partidos en sectores, que son el juego después de las
lecciones: la tropa avanza sola, los healers la mantienen viva y cada sector
suma **una sola cosa nueva**. Viven en `resources/encuentros/niveles.tres`
(la serie) y `n1_el_camino.tres`, `n2_el_puente.tres`, `n3_las_puertas.tres`.
Los genera `tools/gen_encuentros.gd`; `campana.tres` (las tres lecciones)
sigue igual.

La batalla carga la serie que dejó anotada el menú (`Navegacion`): sin
anotación, las lecciones, que es lo que esperan las pruebas y el F6 sobre la
escena.

```gdscript
Navegacion.jugar(get_tree(), 0, Navegacion.RUTA_NIVELES)   # "Jugar"
Navegacion.jugar(get_tree(), i, Navegacion.RUTA_LECCIONES) # una lección
```

`jugar()` sin ruta sólo anota el índice y deja la serie que ya estaba
anotada: quien pueda venir de la otra serie (el menú, al volver de los niveles)
tiene que nombrar la suya.

---

## Reglas de los sectores

Lo que ya hace la batalla (`scripts/3d/battle3d.gd`) y hay que tener en cuenta
al armar un nivel:

| Regla | Valor | Por qué |
|---|---|---|
| La cámara no muestra más allá del `x_fin` del sector en curso | — | La pelea pasa donde está la cámara |
| Los healers se frenan antes del `x_fin` | 1.5 m (`MARGEN_HEALERS`) | No salir de cuadro |
| La tropa se frena antes del `x_fin` | 2.6 m (`RETRASO_ALIADOS`) | Que espere delante del healer y no quede cortada por el borde |
| Puerta del sector | `x_fin − 1` (`PUERTA_SECTOR`) | Liberado un sector, el siguiente entra cuando alguien en pie llega ahí |
| Los enemigos de un sector arrancan lejos de la puerta anterior | ≥ 9 m (`DISTANCIA_ENTRADA`); la batalla avisa con `push_warning` | La media pantalla es de ~7.5 m: más cerca se los ve aparecer |
| Las oleadas nacen fuera de cuadro | ≥ `x_fin + 3` de su sector (`ENTRADA_OLEADA`) | Ver abajo |
| Liberación de todos los sectores | `SIN_ENEMIGOS` | El cartel de avanzar llega con el campo limpio (los tirados cuentan hasta que mueren) |

`test_niveles.gd` es un poco más estricto que la batalla: pide los enemigos de
cada sector entre `x_fin del anterior + 9` y su propio `x_fin` (el primero,
desde el arranque del campo), las oleadas a 3 m o más pasado su `x_fin`, y
entra a la fuerza a cada sector para comprobar que la batalla no avise nada.

**Las oleadas nacen fuera de cuadro.** Mientras un sector está en curso la
cámara no muestra más allá de su `x_fin` (la fila del fondo, con 10 m de
profundidad, ve unos 2.5 m más), y la tropa espera en `x_fin − 2.6`. Una
oleada dentro del sector (como `55-58` en un sector que termina en 60) nacía a
la vista y encima de la tropa. Nacen 3 m o más pasado el `x_fin` y entran
caminando desde el borde. En el último sector de las puertas eso cae fuera del
campo (73-75 con 70 de ancho): salen por las puertas.

### Cómo se gana y cómo se pierde

- **Llegar a la base** (N1, N2): un aliado en pie (no tirado) llega a
  `base_enemiga_x − 1` = 87.5. En el último sector la tropa está frenada en
  90 − 2.6 = 87.4, así que primero hay que limpiarlo; liberado el último, no
  hay tope.
- **Limpiar enemigos** (N3): sin enemigos en juego (los tirados cuentan) **en
  el último sector**; limpiar uno que no es el último sólo deja avanzar.
- **Se pierde** con más bajas que el máximo (4, 4 y 5: la baja número 5, 5 y 6
  pierde). Sin derrota por frente (`frente_derrota_x = −1`): con sectores el
  frente casi no retrocede. En N1 y N2 también pierde un enemigo que llega a la
  base aliada; en N3, quedarse sin aliados.

---

## Nivel 1 — El camino

`n1_el_camino` · semilla 72001 · 90 × 10 m · bases 1.5 / 88.5 · healer en
(6, 5) · Toque, Vendaje, Plegaria, Impulso · llegar a la base · bajas 4 ·
sangrado 0.15

> Toque para curar, dos Toques seguidos para cortar un sangrado, Plegaria para
> el grupo.

Tropa inicial: 3 escuderos + 2 lanceros en x 7-10.

| Sector | `x_fin` | Enemigos | Refuerzos | Oleadas | Enseña |
|---|---|---|---|---|---|
| El camino | 30 | 5 zombis, x 18-22 | — | — | Toque: curar a tiempo al que está al frente |
| El bosque | 60 | 6 zombis, x 42-46 | 1 escudero, x 33-34 | 2 zombis cada 20 s (reloj, se repite), x 63-65 | Plegaria: el grupo entero bajo presión constante |
| La cuesta | 90 | 7 zombis, x 72-76 | 2 lanceros, x 62-64, **sangrando 6 s** | — | Vendaje: cortar la causa antes de curar |

El sangrado es del encuentro y no del sector: va bajo (0.15 por golpe) para
que aparezca poco en los dos primeros tramos, y la cuesta lo plantea de entrada
con los dos lanceros que llegan sangrando.

## Nivel 2 — El puente

`n2_el_puente` · semilla 72002 · 90 × **6** m · bases 1.5 / 88.5 · healer en
(6, 3) · + Bendición, Reanimar, Caída (7 movimientos) · llegar a la base ·
bajas 4 · sangrado 0.15 · todos en las filas z 1.5-4.5

> Bendecí (L, P) a quien va a recibir el golpe del oso; Reanimá (P) a los
> caídos; saltá el barrido.

Tropa inicial: 4 escuderos + 1 espadachín + 1 lancero en x 7-10.

| Sector | `x_fin` | Enemigos | Refuerzos | Oleadas | Enseña |
|---|---|---|---|---|---|
| La cabecera | 30 | 3 zombis x 18-22 + 1 oso x 22-24 | — | — | El golpe anunciado: Bendición al que lo va a recibir, saltar el barrido |
| El puente | 60 | 5 zombis, x 44-48 | 2 escuderos **caídos**, x 31-33 | — (emergentes prendidos: salen zombis) | Reanimar: 8 s de reloj por caído |
| La otra orilla | 90 | 1 oso x 72-74, 3 zombis x 76-80, 1 oso x 80-82 | 1 lancero x 63 + 1 escudero x 62-64 | — | Todo junto, con los osos de a uno |

Más angosto: en el puente la tropa se apelotona y el barrido del oso alcanza a
varios. Los caídos piden 40 de maná cada uno con 4 s de enfriamiento entre
Reanimar y Reanimar, y llegan justo después del primer oso: entrar al puente
con menos de ~50 de maná cuesta uno de los dos.

## Nivel 3 — Las puertas

`n3_las_puertas` · semilla 72003 · 70 × 10 m · bases 1.5 / 68.5 · healer en
(6, 5) · todos los movimientos · limpiar enemigos · bajas 5 · sangrado 0.2

> El demonio anuncia sus golpes: Bendecí, curá en área con Oleada (L, L, P) y
> no te quedes parado.

Tropa inicial: 3 escuderos + 2 lanceros + 1 espadachín en x 7-10.

| Sector | `x_fin` | Enemigos | Refuerzos | Oleadas | Enseña |
|---|---|---|---|---|---|
| El foso | 25 | 5 zombis x 15-19 + 1 oso x 19-21 | — | — | Repaso: el oso entre zombis |
| La muralla | 50 | 8 zombis, x 36-42 | 2 escuderos, x 27-29 | 2 zombis por cada baja aliada (se repite), x 53-55 | Cada baja se paga |
| Las puertas | 70 | 1 demonio x 62-64 + 3 zombis x 60-62 | — | 2 zombis cada 20 s (reloj, se repite), x 73-75 | El jefe: golpes anunciados en área |

La oleada de la muralla cuenta las bajas **del nivel entero** (así funciona
`BAJAS_ALIADAS`): quien llega con muertos del foso los paga al entrar, una
oleada por cada uno.

---

## Números: cómo se midieron

Cada nivel se jugó entero en headless con `--fixed-fps 60`, en dos modos y
con cuatro semillas (la del nivel, 11, 22 y 33):

- **Sin curar**: el healer sigue a la tropa y no hace nada. Tiene que perder:
  si no, el nivel no necesita al healer.
- **Bot**: un healer que se parece a un jugador competente pero no brillante.
  Cura primero lo que tiene al alcance (2.3 m) y si no camina hacia lo más
  urgente (caído > sangrando > más herido), con 0.8-1 s de reacción; junta
  maná para reanimar; usa Plegaria con dos o más heridos al frente, Oleada con
  tres o más a 4 m, Bendición al que va a recibir un golpe anunciado y Caída
  para cortarlo si llega; sale de las marcas. No salta barridos ni usa
  Impulso. Respeta costos, enfriamientos y la regeneración de maná (7/s).

El simulador no está en el repo: es una herramienta de balance, no una prueba.

| Nivel | Sin curar | Bot | Duración con el bot |
|---|---|---|---|
| N1 | pierde en el bosque (55-63 s, 5 bajas) | 4/4, **0 bajas** | 132-148 s (camino ~24 s, bosque 60-78 s, cuesta ~26 s) |
| N2 | pierde en la cabecera o el puente (31-49 s) | 3/4, **2-3 bajas** | 123-147 s |
| N3 | pierde en la muralla (~48 s) | 1/4 (1 baja); las otras tres, contra el demonio | 143 s |

N1 es cómodo para quien cura a tiempo y no perdona a quien no cura. N2 es el
salto: se gana perdiendo gente. N3 hoy lo gana un jugador muy bueno (ver
abajo).

### Cambios respecto del brief, y por qué

| Qué | Brief | Quedó | Por qué |
|---|---|---|---|
| Oleadas | Dentro del sector (bosque 55-58, muralla 47-49, puertas 66-68) | 3 m o más pasado su `x_fin` (63-65, 53-55, 73-75) | Nacían a la vista y encima de la tropa, que espera en `x_fin − 2.6` |
| Oleada del bosque | Cada 14 s | Cada 20 s | Con 14 s (y la oleada fuera de cuadro) el bosque no se liberaba nunca: ver "Lo que no es de los niveles" |
| N2, tropa | 4 escuderos + 1 espadachín | + 1 lancero | Con 5, el bot perdía 4 de 4 |
| N2, cabecera | 4 zombis + oso | 3 zombis + oso | Idem: llegaba al puente sin maná |
| N2, puente | Caídos en 34-36; 6 zombis en 42-46 | Caídos en 31-33; 5 zombis en 44-48 | Llegar a los caídos antes que los zombis |
| N2, otra orilla | 2 osos en 72-76 + 5 zombis; refuerzo 1 lancero | 1 oso en 72-74 y otro en 80-82, 3 zombis; + 1 escudero | Los osos de a uno se leen; juntos y con 5 zombis la orilla perdía siempre |
| Sangrado N2 y N3 | No decía | 0.15 y 0.2 | Presente pero sin tapar lo que enseña cada nivel |
| Healer en N2 | No decía | (6, 3) | La mitad de los 6 m de profundidad |

N3 quedó como pide el brief (salvo dónde nacen las oleadas): ninguna variante
de datos lo mejoró. Probadas con el bot, todas 0/4 o 1/4: sin escolta delante
del demonio, con la escolta detrás, con dos escuderos y un espadachín de
refuerzo, con el demonio entrando al 60-75 % de la vida y con la oleada cada
25 s.

---

## Lo que no es de los niveles

Salió al medir, y no se arregla con datos:

- **El demonio decide N3.** Con 900 de vida, 30/45 de daño en 2.5 m cada 3 s
  y alcance 2.6, cada golpe alcanza a 5 o 6 de una tropa amontonada: ~75 de
  daño por segundo en área, contra ~20-37 que sostiene un healer y ~30 que la
  tropa le hace a él. Más tropa empeora (más cuerpos en el área) y la escolta
  delante lo empeora más (la tropa pelea con los zombis mientras él pega desde
  la segunda fila). Para aflojarlo, en `demonio.tres`: `radio_golpe` 2.5 → ~1.6,
  o daño ~20/30, o vida ~600; y volver a medir.
- **La tropa en su tope pelea mal contra lo que llega de adelante.** Frenados
  en `x_fin − 2.6`, sólo 1 o 2 aliados alcanzan a los enemigos que se paran a
  su alcance; el resto no puede avanzar. Cada par de zombis tarda 10-15 s en
  morir, y una oleada por reloj más rápida que eso no deja nunca el campo
  vacío (`SIN_ENEMIGOS` no se cumple). Por eso el bosque va cada 20 s.
- **Los lanceros se retiran a su base, en x 1.5.** En un campo de 90 m, uno
  que baja del 30 % en la otra orilla camina 60 m para atrás y se pierde para
  la pelea. Tendría que retirarse unos metros detrás de la tropa.
- Las oleadas de un sector siguen saliendo después de liberarlo, hasta que
  entra el siguiente.
