# Amenaza y supervivencia del healer

## Estado del documento

Boceto abierto, pero de un cambio más profundo que los anteriores: **el healer
deja de ser invulnerable**. Hoy el jugador puede pararse en medio de la batalla y
mirar; con esto, tiene que sobrevivir mientras cura.

Desarrolla el §4.6 del documento original (amenaza generada por curación) y le
suma dos amenazas nuevas: bombardeos que hay que esquivar y enemigos que emergen
del suelo.

---

## 1. El bucle que esto habilita

Antes que las mecánicas, lo importante es lo que produce. Hoy el juego responde
así a "¿por qué me importa salvar a este soldado?":

> Porque si mueren todos, pierdo la batalla.

Es una razón cierta pero lejana y abstracta. Con el healer vulnerable y la idea
de resguardarse entre la tropa, la respuesta pasa a ser:

> **Porque ese soldado es lo que me separa de un zombi.**

Ese es el cambio de fondo, y es el mejor argumento a favor de todo el sistema.
Deja de haber altruismo o puntaje: **mantener vivo al ejército es mantener viva
tu propia cobertura**. El juego se entiende sin explicarlo, que es la mejor
propiedad que puede tener una mecánica.

También le da sentido a cosas que ya existen y hoy están sueltas:

- **Impulso** deja de ser un atajo de movilidad y pasa a ser el botón de escape.
- **El alcance corto de curación** (que hoy es una restricción arbitraria) se
  vuelve una tensión real: para curar tenés que acercarte al peligro.
- **El miedo** (ver [`estados_negativos.md`](estados_negativos.md)) se convierte
  en el peor estado del juego, porque los que huyen eran tu escudo.

---

## 2. Las tres amenazas

### 2.1. Bombardeo — el que te obliga a moverte

Proyectiles de asedio que caen en zonas marcadas del suelo. Se telegrafían: un
círculo aparece, crece o parpadea, y después impacta.

| | |
|---|---|
| Aviso | ~1.5s antes del impacto |
| Daño | Alto al healer, alto también a los soldados que estén ahí |
| Frecuencia | Esporádico, no constante |

**Qué produce**: impide quedarse parado en un lugar cómodo. Y crea una decisión
fea y buena: la zona marcada suele estar justo donde está el herido que ibas a
curar.

*Cuidado*: si el bombardeo es constante, el juego se convierte en esquivar y la
curación pasa a segundo plano. Debería ser un evento que interrumpe, no un ritmo
de fondo.

### 2.2. Emergentes — el que te obliga a mirar cerca

Zombis que salen del suelo, **cerca del healer y no en la línea de frente**.
También telegrafiados: la tierra se agrieta o se levanta antes de que salga nada.

| | |
|---|---|
| Aviso | ~1s de grieta en el suelo |
| Comportamiento | Al salir, atacan lo que tengan más cerca |
| Cantidad | De a uno o dos, no hordas |

**Qué produce**: rompe la separación entre "el frente" y "la retaguardia segura".
Si el arquero de atrás está solo y aparece un emergente, tenés dos problemas en
dos lugares.

Encaja perfecto con la facción de no-muertos y **no necesita arte nuevo**: es el
mismo zombi que ya tenemos, con una animación de aparición.

### 2.3. Asesinos — el que te obliga a esconderte

Ya estaba propuesto en [`soldados_y_comportamientos.md`](soldados_y_comportamientos.md):
un enemigo rápido y frágil que ignora la línea y va directo al healer. Con el §4.6,
lo que lo atrae es **haber curado mucho**: cuanto más trabajás, más lo llamás.

**Qué produce**: la tensión más pura del documento original. Curar te salva y te
delata.

---

## 3. La defensa: resguardarse entre los soldados

Es la parte más original de la propuesta y la que hay que diseñar con más
cuidado, porque es donde vive el bucle.

### Tres formas de implementarlo

| Forma | Cómo funciona | Qué tan bien se lee |
|---|---|---|
| **Por objetivo** | Los enemigos atacan a quien tengan más cerca; rodeado de soldados, no sos vos | Muy orgánica, casi no hay que explicarla |
| **Por bloqueo físico** | Los cuerpos frenan proyectiles: un soldado se come la flecha que iba para vos | Dramática y muy visual |
| **Por estadística** | Estar cerca de N soldados da un % de reducción de daño | Clara pero artificial |

**Mi recomendación: las dos primeras, nunca la tercera.** La de objetivo ya casi
funciona con lo que hay (las unidades eligen el enemigo más cercano y se bloquean
por colisión), y la de bloqueo produce el mejor momento posible del juego: ver a
un soldado que salvaste hace treinta segundos comerse un flechazo por vos.

Un número en una barra que dice "-30% de daño por cobertura" comunica lo mismo y
no emociona a nadie.

### Lo que hace falta que exista

- El healer necesita **vida** y una condición de derrota propia.
- Necesita alguna forma de **leer si está a cubierto** — quizá el mismo indicador
  de alcance que ya dibujamos, cambiando de color cuando estás expuesto.
- Los enemigos necesitan poder **elegir al healer** como objetivo.

---

## 4. Qué le queda al healer para defenderse

Sin capacidad de matar, sus herramientas son de posición y de tiempo:

| Herramienta | Estado | Nota |
|---|---|---|
| **Impulso** | Ya existe | Pasa a ser el escape, no un atajo |
| **Cobertura** | Por diseñar | La defensa principal: moverse hacia los suyos |
| **Bendición sobre uno mismo** | Fácil | Reduciría el daño recibido unos segundos |
| **Aturdir / empujar** | Nuevo | Ganar dos segundos sin matar a nadie |
| **Reanimar rápido a un caído cercano** | Nuevo | Recuperar tu escudo bajo presión |

Todas defensivas a propósito: si el healer puede matar, el juego cambia de género
y la pregunta del §10 ("¿puede atacar?") se responde sola por la puerta de atrás.

---

## 5. Calibración

Esto puede arruinar el juego si está mal medido. Cuatro reglas que propondría:

1. **Morir tiene que ser culpa tuya y verse venir.** Todo lo que mata al healer se
   telegrafía. Nada de daño instantáneo sin aviso.
2. **La amenaza interrumpe, no acompaña.** Si hay peligro constante, el jugador
   deja de curar y sólo esquiva. Momentos de peligro separados por momentos de
   trabajo.
3. **Estar expuesto es peligroso; estar cubierto, no.** El castigo debe caer sobre
   *quedarse solo*, que es la decisión que queremos desincentivar, y no sobre
   estar cerca del frente, que es donde queremos que juegue.
4. **La muerte del healer no debería ser el final inmediato.** Quizá caiga
   derribado como los soldados y un aliado pueda levantarlo, o pierda la batalla
   pero no la partida. Que una distracción de dos segundos borre veinte minutos de
   progreso es la receta para que nadie quiera arriesgarse — y arriesgarse es
   justamente lo que el juego pide.

---

## 6. Riesgos

- **Que el juego se convierta en esquivar.** El riesgo más real. Si sobrevivir
  ocupa más atención que curar, cambiamos de juego sin querer. Se mide fácil:
  si en una batalla pasás más tiempo mirando el suelo que las barras de vida,
  está mal calibrado.
- **Que la cobertura sea explotable.** Si esconderse detrás de un escudero es
  seguridad total, la respuesta óptima es no moverse nunca de ahí, y volvimos al
  problema que queríamos resolver. Los emergentes aparecen *cerca tuyo*
  justamente para eso.
- **Que curar se vuelva imposible bajo presión.** Con curaciones instantáneas,
  moverse y curar conviven bien. Si más adelante sumamos canalizadas (§4.9), esa
  tensión aparece y hay que revisarla.
- **Que la muerte se sienta arbitraria.** Un emergente que sale exactamente abajo
  tuyo sin aviso es injusto. El aviso previo no es cortesía, es lo que hace que la
  mecánica sea justa.

---

## 7. Por dónde empezaría

1. **Darle vida al healer y que los emergentes lo ataquen.** Es el cambio mínimo
   que prueba la idea completa: ¿se siente tenso o molesto?
2. **Cobertura por objetivo.** Que los enemigos prefieran al soldado más cercano.
   Casi no hay que programarlo y hace que esconderse funcione solo.
3. **Bombardeo telegrafiado.** Sólo si lo anterior funcionó, porque es el que más
   riesgo tiene de volver el juego un esquiva-balas.
4. **Bloqueo físico de proyectiles.** El más caro de los cuatro y el que más
   momentos memorables produce; lo dejaría para cuando el resto esté afinado.

El paso 1 y el 2 juntos ya responden la pregunta importante: **¿es más divertido
un healer que puede morir?** Todo lo demás depende de esa respuesta.
