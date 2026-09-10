# Catálogo de habilidades de curación

## Estado del documento

Este es un **registro de candidatas**, no un plan. Nada de acá está comprometido:
la idea es tener un menú del que elegir, con una estimación honesta de lo que
cuesta cada cosa en la arquitectura que ya tenemos.

Las habilidades están inspiradas en los sistemas de healing de World of Warcraft,
que después de veinte años de iteración tiene resueltos un montón de problemas de
diseño que nos van a aparecer igual. Pero **no se trata de copiar hechizos**: se
trata de robar las *estructuras* — el HoT, la cadena, el escudo, el vínculo — y
ver cuáles producen decisiones interesantes en nuestro contexto, que es distinto:
acá el healer no cura a cinco compañeros coordinados, sino a un ejército de NPC
que no le avisa nada y que se está muriendo en varios lugares a la vez.

Ver también [`healer_campo_batalla_ideas_iniciales.md`](healer_campo_batalla_ideas_iniciales.md),
al que este documento hace referencia por sección (§).

---

## 1. Lo que ya está implementado

| Habilidad | Costo | CD | Qué hace |
|---|---|---|---|
| Curar | 25 | 0.6s | +35 HP a un aliado. El sobrante se desperdicia |
| Estabilizar | 10 | 1.2s | Corta el sangrado. No devuelve vida |
| Oleada | 45 | 14s | +18 HP a todos los aliados en 5 m |
| Bendición | 35 | 16s | −35% daño recibido y +30% velocidad de ataque, 8s |
| Impulso | 12 | 4s | Empuja al healer hacia el mouse |

Son cinco huecos que ya cubren tres arquetipos distintos: curación puntual,
curación de área y buff preventivo. Lo que sigue es cómo profundizar cada línea.

---

## 2. Los arquetipos, y qué aporta cada uno acá

### 2.1. Paladín — el francotirador

**Filosofía**: curaciones grandes sobre un solo objetivo, caras, con casteo. Muy
fuerte para mantener vivo a *uno*, muy malo para sostener a *muchos*.

Su idea más interesante es **Beacon of Light**: marcás a un soldado y, cada vez
que curás a cualquier otro, el marcado recibe un porcentaje de esa curación.

**Por qué encaja**: le da al jugador una forma de "delegar" atención. Marcás al
veterano de la §5 y después atendés el frente tranquilo, sabiendo que algo le
llega. Es una decisión previa que paga después, que es un tipo de decisión que
hoy no tenemos: todas nuestras habilidades son reactivas.

### 2.2. Druida — el jardinero

**Filosofía**: HoTs (curación repartida en el tiempo). Casi nada cura de golpe;
todo son semillas que se plantan antes de que el daño llegue.

**Por qué encaja fuertísimo**: nuestro problema central es que el healer no puede
estar en dos lugares. Un HoT es exactamente eso — dejás algo funcionando y te
vas. Convierte el juego de "correr a apagar incendios" a "administrar dónde ya
sembraste", que es una decisión más rica.

También trae **Swiftmend**: consumir un HoT activo para una curación instantánea.
Eso crea un dilema precioso — el HoT vale más como emergencia guardada o como
curación sostenida.

### 2.3. Shaman — el que cubre el frente

**Filosofía**: **Chain Heal**, curación que salta entre objetivos cercanos
perdiendo potencia en cada salto. Y tótems: objetos estacionarios que curan solos
en una zona.

**Por qué encaja**: nuestros soldados se amontonan solos en la línea de frente —
esa es justamente la geometría donde una curación en cadena brilla. Y premia
apuntar bien: dónde empieza la cadena decide a quién llega.

Los tótems son el "puesto médico" natural para un campo de batalla, y agregan una
decisión espacial: plantarlo cerca del frente rinde más pero lo pone en riesgo.

### 2.4. Sacerdote disciplina — el que cura antes

**Filosofía**: escudos que absorben daño en vez de reponerlo. **Atonement**: el
daño que hacés se convierte en curación para los aliados.

**Por qué encaja**: un escudo no se desperdicia por overhealing (§4.8), y premia
leer el campo antes de que pase. Atonement abriría la puerta a un healer que
también pelea, que es una de las preguntas abiertas del documento (§10).

### 2.5. Monje — el que cura moviéndose

**Filosofía**: HoTs que rebotan solos a otros objetivos, y curación ligada al
movimiento del personaje.

**Por qué encaja**: ya tenemos Impulso y una banda de profundidad por la que
moverse. Recompensar el movimiento en vez de castigarlo va con el espíritu de un
médico de guerra que corre entre los heridos.

### 2.6. Evoker — el que decide cuánto invertir

**Filosofía**: hechizos *empowered* — mantenés el botón y el efecto escala por
niveles; soltar antes es más débil pero más rápido.

**Por qué encaja**: mete la decisión *dentro* del casteo. Con la batalla
moviéndose alrededor, decidir si aguantás medio segundo más es exactamente la
tensión que buscamos (§4.9).

---

## 3. Catálogo por mecánica

Cada entrada dice qué es, de dónde sale y **qué costaría implementarla acá**:

- 🟢 **Solo un Resource** — usa la API que las unidades ya exponen (`curar`,
  `estabilizar`, `bendecir`). Es escribir un archivo nuevo y listo.
- 🟡 **Resource + estado en la unidad** — necesita que `Unidad3D` recuerde algo
  nuevo (un HoT corriendo, un escudo, un vínculo).
- 🔴 **Resource + sistema nuevo** — necesita infraestructura: entidades en el
  mundo, input sostenido, o que el healer pueda atacar.

### A. Curación directa

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Toque rápido** | Flash of Light | Cura poco, barato, sin cooldown. El relleno | 🟢 |
| **Gran curación** | Holy Light | Cura mucho, caro, con casteo de ~1.5s | 🔴 casteo |
| **Imposición de manos** | Lay on Hands | Cura al máximo. Cooldown de 3 minutos | 🟢 |
| **Palabra de gloria** | Word of Glory | Cura más cuanto más herido está el objetivo | 🟢 |

La cuarta es la más interesante de las cuatro: invierte el overhealing. En vez de
castigarte por curar a alguien sano, te premia por elegir bien al más grave — que
es el pilar de priorización (§3) convertido en número.

### B. Curación en el tiempo (HoTs)

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Rejuvenecer** | Rejuvenation | +X HP cada segundo durante 12s | 🟡 |
| **Vendaje** | Regrowth | Cura algo al instante y deja un HoT chico | 🟡 |
| **Crecimiento salvaje** | Wild Growth | Pone un HoT en los 4 aliados **más heridos** del área | 🟡 |
| **Cosecha** | Swiftmend | Consume un HoT activo y lo convierte en curación instantánea | 🟡 |
| **Flor de vida** | Lifebloom | HoT que al expirar estalla en una curación grande | 🟡 |

**Esta es la línea que más cambiaría el juego.** Hoy toda curación es un evento
puntual: hacés click y pasa algo. Los HoTs introducen *estado que persiste*, y con
eso aparece la pregunta "¿dónde ya invertí?", que es mucho más interesante que
"¿a quién curo ahora?".

Implementación: las unidades ya tienen dos efectos con temporizador
(`sangrado_restante` y `bendicion_restante`). Un HoT es el mismo patrón invertido.
Si vamos a tener tres o cuatro, **conviene hacer un sistema genérico de efectos**
en vez de seguir agregando campos sueltos — un `EffectHolder` como el que sugiere
la propia guía de ability-system.

*Nota de diseño*: "Flor de vida" y "Cosecha" se pelean entre sí a propósito —
dejarlo expirar da la explosión, consumirlo da la emergencia. Ese tipo de tensión
interna es lo que hace que una habilidad se sienta viva.

### C. Escudos y prevención

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Égida** | Power Word: Shield | Absorbe X de daño antes de tocar la vida | 🟡 |
| **Sobrecuración en escudo** | Divine Aegis | El overhealing se convierte en escudo en vez de perderse | 🟡 |
| **Espíritu guardián** | Guardian Spirit | Si el objetivo va a morir en los próximos Xs, sobrevive con 1 HP | 🟡 |
| **Escudo de tierra** | Earth Shield | Cargas que curan al objetivo cada vez que **recibe** un golpe | 🟡 |

La segunda es directamente la propuesta del §4.8, que ya está a medio camino:
`curar()` devuelve cuánto se aprovechó de verdad, así que el sobrante ya está
calculado, sólo falta hacer algo con él.

La tercera se cruza con los derribados (§4.4) — habría que decidir si previene el
derribo o actúa una vez derribado.

### D. Cadena y rebote

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Curación en cadena** | Chain Heal | Salta a 3-4 aliados cercanos, −30% por salto | 🟢 |
| **Cadena inteligente** | Chain Heal (moderno) | Igual, pero salta al más herido en vez del más cercano | 🟢 |
| **Niebla rebotante** | Renewing Mist | HoT que, al expirar, salta solo a otro aliado herido | 🟡 |

La cadena es **barata de implementar y muy adecuada a nuestra geometría**: los
soldados ya se amontonan solos en el frente por colisión. Es de las mejores
relaciones costo/beneficio de todo el catálogo.

La variante "inteligente" vs. "cercana" no es un detalle: la primera juega sola y
la segunda premia el posicionamiento. Para nuestro juego, donde el pilar es que
el jugador decida, **la versión que salta al más cercano es la interesante** —
que apuntar bien importe.

### E. Zonas y estructuras

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Lluvia sanadora** | Healing Rain | Zona en el suelo que cura a quien esté adentro | 🔴 |
| **Puesto médico** | Healing Stream Totem | Objeto que se planta y cura al aliado más herido cerca | 🔴 |
| **Estandarte** | Aura totémica | Zona que da un buff pasivo mientras estén dentro | 🔴 |
| **Campo de flores** | Efflorescence | Zona que cura poco pero dura mucho | 🔴 |

Todas necesitan una entidad nueva en el mundo (una escena con área y temporizador),
pero una vez hecha la primera, las demás son variaciones baratas.

**Lo que aportan es una dimensión que hoy no existe: decisiones espaciales que
sobreviven al momento.** Y encajan con la línea de frente dinámica (§4.5) — una
zona plantada donde el frente *va a estar* vale más que una donde está ahora.

### F. Transferencia y redistribución

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Faro de luz** | Beacon of Light | Marcás a uno: recibe el 40% de todo lo que cures a otros | 🟡 |
| **Vínculo espiritual** | Spirit Link Totem | Iguala el % de vida de todos los aliados cercanos | 🟢 |
| **Transfusión** | Sacrificio de vida | Curás gastando **tu propia vida** en vez de mana | 🟡 |
| **Cadena de sufrimiento** | Vampiric Link | Repartís el daño de uno entre varios | 🟡 |

"Vínculo espiritual" es sorprendentemente barato (itera el grupo y promedia) y muy
dramático: convierte a cinco moribundos y dos sanos en siete heridos estables. Es
una decisión con textura moral, que va con el §5.

"Transfusión" abre el arquetipo del healer de sangre (§6.4) y conecta con la
curación prohibida (§4.14). Requiere que el healer tenga vida y pueda morir —
hoy no la tiene.

### G. Emergencia

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Reanimar** | Ancestral Spirit | Levanta a un derribado (§4.4) | 🟡 |
| **Grito de guerra** | Rallying Cry | +vida máxima temporal a todo el ejército | 🟡 |
| **Intervención** | Blessing of Protection | Un aliado se vuelve intocable unos segundos | 🟡 |
| **Última plegaria** | Divine Hymn | Canalización larga que cura muchísimo en área. No te podés mover | 🔴 |

"Reanimar" ya está en el plan del prototipo mínimo (§8) y es el próximo paso
natural del desarrollo, más allá de este catálogo.

### H. Curación por combate

| Habilidad | Inspiración | Qué hace | Costo |
|---|---|---|---|
| **Expiación** | Atonement | El daño que hacés se convierte en curación repartida | 🔴 |
| **Puño sanador** | Fistweaving | Atacar a un enemigo cura al aliado más cercano | 🔴 |
| **Choque sagrado** | Holy Shock | Una sola habilidad: cura a aliados, daña a enemigos | 🔴 |

Todas requieren decidir antes una pregunta abierta del documento (§10): **si el
healer puede atacar**. Es una decisión de identidad, no de implementación — y
cambia bastante el juego, porque hoy la única forma de influir es a través de
otros.

### I. Economía de recursos

Menos habilidades y más reglas del sistema, pero definen cómo se siente todo lo
demás:

| Idea | Inspiración | Qué hace |
|---|---|---|
| **Poder sagrado** | Holy Power | Las curaciones baratas cargan un recurso que gastan las caras |
| **Racha** | Divine Favor / procs | Curar sin desperdiciar da chance de que la próxima salga gratis |
| **Comunión** | Innervate | Recuperás mana de golpe, con cooldown largo |
| **Sobrecarga** | — | Podés gastar mana que no tenés, a cambio de daño propio |

La primera es la más interesante estructuralmente: hoy el mana es un grifo que se
llena solo, así que la única decisión es "gastar o esperar". Un recurso secundario
que se **gana jugando bien** premia la eficiencia en vez de la paciencia.

---

## 4. Por dónde empezaría

Si tuviera que elegir tres, en este orden:

1. **Un HoT (Rejuvenecer)** — es el cambio conceptual más grande por el menor
   trabajo. Convierte el juego de reactivo a preventivo y abre toda la sección B.
   Antes conviene hacer el sistema genérico de efectos, que además ordena el
   sangrado y la bendición que ya existen.

2. **Curación en cadena** — 🟢, aprovecha una geometría que ya tenemos gratis
   (los soldados amontonados) y hace que apuntar importe más.

3. **Sobrecuración en escudo** — 🟡 chico, y cierra un cabo suelto: hoy el
   desperdicio sólo genera un mensaje en el HUD.

Después de esas tres, la pregunta grande a responder es si vamos hacia **zonas y
estructuras** (sección E, decisiones espaciales) o hacia **el healer que pelea**
(sección H, cambio de identidad). Son dos juegos distintos y conviene no hacer las
dos.

---

## 5. Lo que este catálogo no resuelve

Un healer de WoW cura a cinco personas que ven lo mismo que él y se coordinan.
Nuestro healer cura a un ejército de NPC que no le avisa nada, y no controla nada
de lo que pasa. Hay mecánicas que se traducen directo (HoTs, escudos, cadenas) y
otras que pierden sentido sin un grupo humano.

Dos cosas a vigilar cuando probemos cualquiera de estas:

- **Que no se vuelva un rotativo.** Si la respuesta óptima es siempre la misma
  secuencia de botones, perdimos la priorización (§9) por más habilidades que
  tengamos.
- **Que se pueda leer.** Cada efecto persistente necesita mostrarse encima del
  soldado. Con tres HoTs distintos, dos escudos y un vínculo, el campo se vuelve
  ilegible — y "caos legible" es un pilar. Probablemente haya un techo práctico
  de cuántos estados simultáneos podemos mostrar, y ese techo limita el catálogo
  más que el esfuerzo de programarlos.
