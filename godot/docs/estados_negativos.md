# Estados negativos y su tratamiento

## Estado del documento

Boceto de sistema, abierto a cambios. Desarrolla la idea de "distintos tipos de
heridas" del §4.2 del documento original, sumándole la capa que hace interesante
al sistema de WoW: **que no todo se pueda limpiar**.

Hoy el prototipo tiene un solo estado negativo (sangrado) y una herramienta que
lo corta (Estabilizar). Esto es cómo podría crecer.

Ver también [`habilidades_catalogo.md`](habilidades_catalogo.md) —los estados son
el problema, las habilidades la respuesta— y
[`healer_campo_batalla_ideas_iniciales.md`](healer_campo_batalla_ideas_iniciales.md).

---

## 1. Qué robarle a WoW

En WoW cada efecto negativo tiene una **escuela** (magia, maldición, veneno,
enfermedad, sangrado) y cada clase puede limpiar sólo algunas. Dos consecuencias
de diseño que nos sirven:

1. **No alcanza con ver que alguien está mal: hay que ver de qué.** Mirar el
   campo se vuelve tan importante como reaccionar rápido, que es exactamente lo
   que pide el §4.2.
2. **El sangrado no se puede limpiar con nada.** Sólo se sobrevive curando.

El segundo punto es el más valioso y el menos obvio:

> **Los efectos que no se pueden limpiar son los que le dan sentido a la curación
> bruta.** Si todo se resolviera apretando el botón correcto, el juego sería un
> puzzle de identificación. Los efectos irremovibles son los que obligan a gastar
> recursos de verdad y a decidir si el soldado vale lo que va a costar.

Un sistema sano necesita las tres capas: efectos que **se limpian**, efectos que
hay que **aguantar curando**, y efectos que sólo se pueden **prevenir**.

---

## 2. Catálogo de estados

| Estado | Qué hace | Tratamiento | Gravedad |
|---|---|---|---|
| **Sangrado** | Daño constante durante unos segundos | Vendaje | Media, ya implementado |
| **Veneno** | Daño bajo pero muy largo; se acumula en dosis | Antídoto | Baja al principio, alta si se ignora |
| **Quemadura** | Daño alto y corto | **Ninguno**: hay que curar y aguantar | Alta e inmediata |
| **Maldición** | El soldado **recibe la mitad de curación** | Purificación | Muy alta: te ataca a vos |
| **Fractura** | No hace daño: el soldado no puede retirarse ni esquivar | Férula | Baja sola, alta combinada |
| **Infección** | Daño creciente **y se contagia a los soldados de al lado** | Antídoto, urgente | Baja al principio, catastrófica después |
| **Trauma** | El soldado queda aturdido: no pelea ni se mueve | **Ninguno**: pasa solo | Media, cuesta daño del ejército |
| **Miedo** | El soldado **rompe formación y huye** del combate | Presencia del healer, o un buff de moral | Alta: estructural, no numérica |

Cuatro notas sobre los más interesantes:

**Maldición** es el único que no ataca al soldado sino al jugador: reduce la
eficacia de tus curaciones. Obliga a limpiar *antes* de curar, o a aceptar que
vas a gastar el doble. Es la clase de efecto que convierte una decisión simple en
una de dos pasos.

**Infección** es el único que empeora la situación general si lo ignorás. Todos
los demás son problemas de un soldado; éste es un problema del ejército, y premia
mirar el campo entero en vez de la barra más baja.

**Quemadura y trauma no tienen cura.** Uno se aguanta con vida, el otro con
tiempo. Son los que impiden que el juego se reduzca a identificar y apretar.

**Miedo** es el único que no se trata con un objeto sino **con tu presencia**. Un
soldado aterrado se calma si el healer está cerca, o con un buff de moral. Eso lo
vuelve el estado más peligroso de todos por dos razones: no hace daño pero
desarma la formación, y **te obliga a acercarte al lugar donde las cosas están
saliendo mal**. Es también el vínculo natural con la moral del ejército (§4.12):
el miedo sería el efecto individual de un sistema colectivo, y con el healer
vulnerable (ver [`amenaza_y_supervivencia.md`](amenaza_y_supervivencia.md)) tiene
una consecuencia extra: si tus soldados huyen, te quedás sin cobertura.

---

## 3. La matriz de herramientas

Acá está el juego real: **qué herramienta cubre qué, con huecos deliberados.**

| | Sangrado | Veneno | Quemadura | Maldición | Fractura | Infección | Trauma | Miedo |
|---|---|---|---|---|---|---|---|---|
| **Vendaje** | ✅ | — | — | — | — | — | — | — |
| **Antídoto** | — | ✅ | — | — | — | ✅ | — | — |
| **Purificación** | — | — | — | ✅ | — | — | — | — |
| **Férula** | — | — | — | — | ✅ | — | ✅ | — |
| **Estar cerca** | — | — | — | — | — | — | — | ✅ |
| **Curar** | paliativo | paliativo | **única salida** | reducido a la mitad | — | paliativo | — | — |

Lo importante no son las casillas llenas sino **que el healer no pueda llevar
todas las herramientas a la vez**. Si tiene las cuatro, esto es una tabla de
consulta. Si tiene dos, es una decisión antes de cada batalla y una serie de
decisiones incómodas durante.

Eso conecta directo con los tipos de healer del §6 y con los suministros
limitados del §4.7:

- El **médico de combate** lleva vendaje y férula: resuelve lo físico, sufre con
  lo mágico.
- El **clérigo** lleva purificación y cura fuerte: limpia maldiciones y aguanta
  quemaduras, pero se desangra con lo demás.
- El **alquimista** lleva antídotos: reina contra veneno e infección.

Ninguno cubre todo, y la composición enemiga de cada sector decide quién la pasa
bien.

---

## 4. Combinaciones

Los estados se vuelven interesantes cuando se cruzan, sin necesidad de sumar
efectos nuevos:

| Combinación | Por qué duele |
|---|---|
| Fractura + sangrado | No puede retirarse **y** se está desangrando: si no vas vos, muere |
| Maldición + cualquier daño | Curarlo cuesta el doble: quizá convenga otro paciente |
| Infección + amontonamiento | La línea de frente es el peor lugar para un contagio |
| Veneno + veneno | Las dosis se acumulan: dos golpes leves se vuelven letales |
| Trauma en un escudero | El que sostenía la línea deja de pelear y todo se corre |
| Miedo + healer vulnerable | Los que huyen eran tu cobertura: quedás expuesto |
| Miedo en cadena | Si el miedo se contagia al ver caer a un aliado, un mal momento se vuelve una desbandada |

El caso del trauma es el que mejor ilustra el punto: **no hace ni un punto de
daño**, y sin embargo puede costar la línea entera. Un buen sistema de estados no
es sólo maneras distintas de restar vida.

---

## 5. El límite real: legibilidad

Este es el problema serio, y probablemente el que decida cuántos estados podemos
tener.

Hoy mostramos el sangrado con un rombo rojo al lado de la barra de vida. Con
ocho estados, quince soldados amontonados y una cámara que no está tan cerca,
**no hay espacio físico para ocho iconos distinguibles**.

Posibles salidas, de menos a más ambiciosa:

- **Mostrar sólo el más grave.** Un ícono por soldado, el del efecto que más lo
  está matando. Simple y probablemente suficiente.
- **Color en la barra.** La barra de vida cambia de tinte según el estado
  dominante: verde-veneno, naranja-quemadura, rojo-sangrado.
- **Detalle al apuntar.** El campo muestra lo mínimo; cuando pasás el mouse por
  un soldado, un panel chico lista todo lo que tiene.
- **Silueta o aura.** Un efecto sobre el sprite en vez de un icono aparte.

Mi apuesta: **el más grave en el campo, el detalle al apuntar**. Mantiene el caos
legible (§9) y le da una razón más a apuntar, que ya es la acción central.

**Un techo práctico honesto**: probablemente **tres o cuatro estados** sean el
máximo que se pueda leer en combate. El catálogo de la sección 2 tiene ocho
porque conviene elegir entre varios, no implementarlos todos.

---

## 6. Por dónde empezaría

1. **Veneno**, como segundo estado. Se comporta distinto al sangrado (más lento,
   más largo, acumulable) y valida si el jugador puede distinguir dos efectos en
   pleno combate. Si con dos ya cuesta, la respuesta sobre los siete llegó gratis.
2. **Maldición**, como tercero. Es el que más cambia la decisión, porque ataca la
   herramienta principal del jugador en vez de al paciente.
3. **Quemadura**, como primer efecto sin cura. Confirma si "no podés limpiarlo,
   sólo aguantarlo" se siente tenso o injusto.

4. **Miedo**, cuando el healer sea vulnerable. Antes de eso es sólo pérdida de
   daño; después, es el estado que te deja sin escudo, y ahí se vuelve el más
   interesante de todos.

Fractura, infección y trauma después, y sólo si la legibilidad aguanta.

---

## 7. Riesgos

- **Que se vuelva un juego de reconocer iconos.** Si cada efecto tiene su botón,
  la partida es identificar y apretar. Se evita con herramientas que cubran
  varias categorías de forma imperfecta y con efectos que no se limpien.
- **Frustración con lo irremovible.** "No podés hacer nada" es tenso si el
  jugador entiende por qué y tiene una salida (curar fuerte, prevenir la próxima);
  es injusto si parece arbitrario. La quemadura tiene que verse venir.
- **Choque con los suministros.** Si limpiar gasta items escasos, el jugador
  puede terminar sin herramientas a mitad de sector. Eso puede ser buena tensión o
  un callejón sin salida, y hay que probarlo antes de decidir cuál.
