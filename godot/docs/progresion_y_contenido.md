# Progresión y contenido

## Estado del documento

Cuatro temas que hoy no existen en el prototipo: **equipo por tier**, **items y
economía**, **estructura de niveles** y **variedad de enemigos**. Son bocetos para
discutir, no decisiones — igual que el resto de los documentos de esta carpeta.

Resumido a propósito: la idea es ver la forma general de cada sistema y decidir
cuál vale la pena desarrollar, no cerrar detalles.

---

## 1. Armas y armaduras por tier

### Lo que tenemos

Verificado abriendo los packs: **~900 iconos de equipo de 32×32** (armas ×200,
armaduras ×300, escudos ×100, capas y cinturones ×100, anillos y amuletos ×100,
ropa ×100, varitas y libros ×100).

Dos cosas importantes que salieron de mirarlos:

- **No vienen ordenados por calidad.** Están agrupados por tipo de pieza y varían
  en cuánto detalle tienen. Los tiers hay que armarlos a mano eligiendo qué icono
  va en cada nivel; es un rato de curaduría, no algo automático.
- **El equipo no se puede mostrar en el soldado.** Nuestros personajes son
  maniquíes de una sola pieza: no hay capas de sprite para cambiarle la armadura.
  Un soldado con equipo legendario se ve exactamente igual que un recluta.

Esa segunda limitación condiciona todo el sistema, y conviene decidirla antes de
diseñar nada más.

### Tres formas de resolver la invisibilidad del equipo

| Opción | Cómo | Costo |
|---|---|---|
| **Sólo en la ficha** | El equipo se ve al mirar la ficha del soldado, no en el campo | Bajo |
| **Tinte por tier** | El color del soldado indica su nivel de equipo | Bajo, pero compite con el tinte de bando |
| **Insignia** | Un icono chico junto a la barra de vida | Medio, y suma ruido visual |

Mi recomendación: **sólo en la ficha, más un detalle sutil para los tiers altos**.
Si el equipo no se ve, el jugador no puede tomar decisiones en combate con esa
información — y si intentamos mostrarlo todo, el campo se vuelve ilegible.

### Estructura de tiers

Cinco niveles, con el código de color de rigor:

| Tier | Color | Efecto aproximado |
|---|---|---|
| Común | Gris | Base |
| Poco común | Verde | +10% en una stat |
| Raro | Azul | +20%, o +10% en dos |
| Épico | Violeta | +35%, y un rasgo |
| Legendario | Naranja | +50%, y un rasgo fuerte y raro |

Los **rasgos** son más interesantes que los porcentajes, porque cambian cómo se
juega en vez de cuánto aguanta alguien:

- *Terco*: no se retira aunque esté por morir
- *Resistente*: no puede sangrar
- *Inspirador*: los aliados cercanos pegan más fuerte
- *Segunda vida*: la primera vez que caería, queda derribado en vez de morir
- *Sanguíneo*: recibe el doble de curación

**Lo interesante para nuestro juego**: el equipo no debería hacer al soldado más
fuerte a secas, sino **cambiar cuánto vale la pena salvarlo**. Un soldado con
"Sanguíneo" es rentable de curar; uno con "Segunda vida" te da margen; uno
"Terco" te obliga a ir a buscarlo. El equipo se vuelve información táctica.

---

## 2. Items y economía

### Lo que tenemos

**1.100 iconos de poción**: once familias de cien variantes, separadas por color
del líquido. Las familias por color se mapean solas a tipos de efecto (roja =
vida, azul = mana, verde = antídoto, etc.). Sobra material.

### Dos recursos que se comportan distinto

Hoy el healer tiene un solo recurso: mana, que se regenera solo. Eso hace que la
única decisión sea "gasto ahora o espero". La propuesta es sumar un segundo
recurso con la lógica opuesta:

| | Mana | Suministros |
|---|---|---|
| Se recupera | Solo, durante la batalla | **Nunca durante la batalla** |
| Se repone | — | Entre niveles, comprando |
| Decisión que genera | Ritmo: cuándo gastar | Reserva: si vale la pena usarlo *acá* |

Los suministros son las vendas, pociones y antídotos del §4.7. Son pocos y no
vuelven: usar el último antídoto en un soldado común es una decisión que se
siente, y eso es exactamente lo que el mana no puede darnos porque siempre
vuelve.

### Tipos de item

| Item | Efecto | Nota |
|---|---|---|
| Poción de vida | Curación fuerte instantánea, sin gastar mana | El recurso de emergencia |
| Vendas | Cortan el sangrado sin gastar mana | Barato, cantidad alta |
| Antídoto | Limpia estados negativos | Escaso |
| Elixir de mana | Recupera mana de golpe | Rompe el techo del ritmo |
| Piedra de resurrección | Levanta a un muerto, no a un derribado | Muy escaso, decisión pesada |

### Oro y qué se compra

El oro cae de la batalla y se gasta entre niveles. Lo importante es en qué
compite, porque ahí está el juego de la economía:

- **Suministros** — resolver la próxima batalla
- **Equipo para los soldados** — que el ejército aguante mejor solo
- **Mejoras del healer** — más mana, más alcance, habilidades nuevas
- **Reclutas** — reponer las bajas

Esa última es la más interesante: si reclutar cuesta oro, **cada soldado que se
te muere tiene precio**. Deja de ser una unidad genérica y pasa a ser una
inversión perdida, que es la manera más directa de darle peso a un cuerpo tirado
en el suelo.

---

## 3. Estructura de niveles y dificultad

Esta es la pregunta más abierta de las cuatro. Cuatro formas posibles:

| Estructura | Cómo es | A favor | En contra |
|---|---|---|---|
| **A. Campo fijo, oleadas** | Lo de hoy: llegan tandas cada vez peores | Ya está hecho | Se vuelve repetitivo; no hay sensación de avance |
| **B. Campo largo** | Un frente que empujás de un extremo al otro | Se ve el progreso; encaja con la línea dinámica (§4.5) | Si es sólo empujar, se hace monótono |
| **C. Mapas separados** | Cada nivel es un campo distinto | Variedad, ritmo claro | Cada mapa es trabajo de arte |
| **D. Roguelite** | Mapa de nodos, elegís ruta y recompensas | Rejugabilidad, decisiones meta | Es un juego más grande |

### Lo que propondría: campo largo por sectores

Es la **B**, resolviendo lo que la hace monótona.

```
BASE ALIADA ──[ sector 1 ]──[ sector 2 ]──[ sector 3 ]── BASE ENEMIGA
                    ▲
              puesto tomado
         (nuevo punto de refuerzo)
```

- El campo es largo y el frente se mueve, como ya está diseñado.
- Está dividido en **sectores por puestos intermedios**. Cuando el frente pasa un
  puesto, lo tomás: pasa a ser tu nuevo punto de llegada de refuerzos, y si te
  hacen retroceder, no perdés todo.
- Cada sector tiene su propia composición de enemigos, así que avanzar cambia a
  quién enfrentás y no sólo cuántos.
- Entre sectores hay una pausa corta: repone suministros y deja gastar oro.

Esto da tres cosas que la estructura de oleadas pura no da: **progreso visible**
(mirás para atrás y ves cuánto avanzaste), **hitos** (tomar un puesto es un
logro), y **posibilidad de recuperarse** sin perder la partida entera.

### Cómo escalar la dificultad

En orden de qué tan bien funciona cada palanca:

1. **Composición, no cantidad.** Un sector con dos brutos y un nigromante es más
   difícil *y más interesante* que uno con veinte zombies. Más enemigos iguales
   sólo hace la pantalla más ruidosa.
2. **Presión sobre el recurso escaso.** Sectores donde el sangrado es más
   frecuente vacían los suministros y obligan a decidir peor.
3. **Enemigos que atacan tu forma de jugar.** El asesino que va por el healer, o
   un enemigo que hace daño en área y castiga tener a los soldados amontonados.
4. **Tier del equipo enemigo.** La palanca más aburrida, pero la más fácil de
   ajustar fino.

Lo que **no** haría es subir los números del jugador y del enemigo en paralelo:
si todo escala igual, nada cambia y sólo se alargan las peleas.

---

## 4. Facciones enemigas

Hoy todos los enemigos son zombies. Coincido en que conviene variar, y la buena
noticia es que **el ejército espejo sale casi gratis**: los tres packs medievales
comparten animaciones, así que un lancero enemigo es el mismo soldado con otro
tinte.

### Tres facciones con los assets que hay

| Facción | Unidades | De dónde salen | Qué le hace al jugador |
|---|---|---|---|
| **Ejército rival** | Escudero, lancero, espadachín, arquero | Los mismos packs medievales, tinte rojo | Pelea ordenada y simétrica: enfrentás una línea parecida a la tuya |
| **No-muertos** | Zombies, nigromante, almas invocadas | `834564`, `573981` | Presión constante y numerosa; el nigromante hace que no se termine |
| **Bestias** | Oso, ooze, y las otras cuatro criaturas | `987745` (seis criaturas completas) | Rompe la formación: golpes fuertes, comportamiento errático |

Y los **tres jefes** de `897123` (mago, demonio y ooze), con cuatro ataques cada
uno y proyectiles propios, para cerrar cada acto.

### Por qué el ejército espejo es la mejor primera facción

- Es **legible**: el jugador ya entiende qué hace un lancero porque tiene uno.
- Es **barata**: cero arte nuevo, cero animaciones nuevas.
- Es **simétrica**: enfrentar una línea igual a la tuya hace que la diferencia la
  ponga el healer, que es justamente lo que el juego quiere demostrar.

Los no-muertos y las bestias entran después, como cambio de ritmo. Una progresión
de actos posible: **acto 1 ejército rival** (aprendés las reglas), **acto 2
no-muertos** (cambia el ritmo a resistencia), **acto 3 mezcla y jefes**.

---

## 5. Cómo se conectan los cuatro sistemas

No son cuatro temas sueltos; forman un bucle:

```
      combate  ──> loot (oro, equipo, suministros)
         ▲                        │
         │                        ▼
   sector siguiente  <──  gastar entre sectores
   (mas dificil)              (equipo, reclutas)
```

El riesgo es que ese bucle **le saque protagonismo al healer**. Si el ejército
mejora lo suficiente con equipo, el jugador deja de ser necesario y el juego se
convierte en un simulador de batallas con un menú de compras.

La forma de evitarlo: que la progresión **amplíe las decisiones del healer**, no
que reemplace su necesidad. Equipo con rasgos que cambian a quién conviene salvar
(sección 1), suministros escasos que obligan a elegir (sección 2), y composiciones
enemigas que atacan la manera de jugar (sección 3). Todo eso hace el trabajo del
healer más interesante; subir la vida de todos los soldados lo hace innecesario.

---

## 6. Veteranía: soldados descartables que suben de nivel

**Decisión tomada**: el equipo va al healer; los soldados no se equipan pero
**suben de nivel** con mejoras chicas.

Parece contradictorio ("descartable" y "sube de nivel" tiran para lados
opuestos), pero no lo es, y es el modelo de XCOM, Fire Emblem y Darkest Dungeon.
La distinción que lo hace funcionar:

> **Descartable** describe el sistema: hay flujo de reemplazo y el juego espera
> bajas. **El nivel** describe el valor: perderlo cuesta. Lo contradictorio sería
> "descartable e insustituible", donde perder a uno rompe la partida.

### Por qué encaja en este juego

Hoy el trabajo del healer es puramente defensivo: curás para *no* perder, y no se
construye nada. Con veteranía, cada soldado que mantenés vivo se vuelve mejor: el
trabajo se capitaliza. Es la diferencia entre "no perdí" y "logré algo".

Y le da respuesta mecánica a la pregunta central del §5 —"¿a quién vale la pena
salvar?"— sin tener que escribir narrativa: al veterano, porque vale más.

**La experiencia se gana por sobrevivir, no por matar.** Es importante: el jugador
no mata a nadie, así que ésta es la única forma de que participe de la economía de
progresión. Dicho de otro modo, **el healer es la fuente de experiencia del
ejército**: cada soldado que llega vivo al final del sector sube por su trabajo.

### El filtro de calibración

Las mejoras van en el eje *"vale más la pena salvarlo"*, nunca en *"necesita menos
ayuda"*:

| Sirve | Arruina |
|---|---|
| +vida máxima: más margen, sigue necesitándote | +armadura o reducción de daño |
| Recibe más curación por punto de mana | Autocuración o regeneración |
| Rasgos que crean situaciones (*no se retira*) | +daño alto: gana solo |

Un veterano con +40% de vida es un mejor paciente. Uno con +40% de armadura es un
paciente que no te necesita, y ahí perdimos el juego.

### Escala propuesta

| Nivel | Nombre | Mejora | Marca |
|---|---|---|---|
| 1 | Recluta | — | Ninguna |
| 2 | Soldado | +10% vida máxima | **Gana nombre propio** |
| 3 | Veterano | +20% vida | Marca visible en el campo |
| 4 | Élite | +30% vida, un rasgo | Marca destacada |
| 5 | Leyenda | +40% vida, rasgo fuerte | Inconfundible |

El salto importante no es el 10% de vida: es que **al llegar a nivel 2 el soldado
deja de ser "Recluta" y pasa a llamarse Roland**. Cuesta casi nada implementarlo y
es lo que dispara el apego del §5. A partir de ahí, cuando cae, cae alguien.

### Modos de falla a vigilar

- **Que el jugador sólo cuide veteranos.** Es una decisión legítima e
  interesante, pero si se vuelve la respuesta obvia siempre, deja de ser
  decisión. Se corrige haciendo que los reclutas hagan falta en cantidad, o que
  reemplazarlos cueste oro.
- **Legibilidad.** Con quince soldados en pantalla hay que poder distinguir al
  veterano de un vistazo, y ya tenemos poco espacio visual sobre cada unidad.
- **Que perder duela demasiado.** Si la pérdida de un veterano se siente
  irreparable, el jugador juega a la defensiva o reinicia. Hay que decidir si el
  juego *acepta* la pérdida como parte del tema (Darkest Dungeon) o la castiga.

---

## 7. Qué está sin decidir

- ¿Cuánto dura una partida? Un sector de tres minutos por seis sectores es media
  hora; si además hay meta-progresión entre partidas, es otro tipo de juego.
- ¿El oro se gana por matar o por sobrevivir? Mismo razonamiento que la
  experiencia: si es por matar, el jugador queda fuera de la economía.
- ¿La veteranía sobrevive entre partidas, o el arco es de una sola partida?
- ¿Qué gana el healer con su equipo? Debería ampliar decisiones (más alcance,
  habilidades nuevas, más mana) y no dar potencia bruta, por la misma razón que
  las mejoras de los soldados.
