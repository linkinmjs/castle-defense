# Soldados y comportamientos de combate

## Estado del documento

Análisis en tres pasos: **qué personajes tenemos realmente** en los assets, **qué
soldados** se pueden armar con eso, y **qué IA** le da a cada uno un estilo de
pelea reconocible.

Nada de acá está implementado. El inventario de la sección 1 sí es verificado:
salió de abrir los 32 packs, listar sus animaciones y mirar los sprites para
identificar las armas — no de suponerlo por el nombre del archivo.

Criterio que atraviesa todo el documento: **un soldado nuevo sólo vale la pena si
le crea un problema distinto al healer.** Variedad por variedad es trabajo de
arte sin efecto en el juego.

Ver también [`healer_campo_batalla_ideas_iniciales.md`](healer_campo_batalla_ideas_iniciales.md)
y [`habilidades_catalogo.md`](habilidades_catalogo.md).

---

## 1. Qué hay en los assets

### 1.1. Personajes con set de combate completo

Estos tienen locomoción (idle/walk/run), ataques, hurt y muerte. Son los
directamente utilizables como tropa:

| Pack | Arma (verificada) | Animaciones propias |
|---|---|---|
| `689963` (medieval 5) | **Espada corta + escudo redondo** | Shield_Strike, Blow_to_shield, Defense, Parry, Prick, Power_punch, Rolling |
| `852737` (medieval 6) | **Lanza** (asta larga, dos manos) | Las mismas: Prick es una estocada frontal larga |
| `949015` (saber fighter) | **Sable curvo**, sin escudo | Las mismas, con arcos de corte más amplios |
| `362398` (archer) | **Arco** | Shot, Charging, Aim, Fighting stance |
| `834564` (zombie) | Sin arma (garras) | Attack 1/2/3, Idle 2 |
| `607266` (pack 2) | **Puños y patadas** + magia elemental | Punch, Kick, Ground_Slam, Ice_Charge, Counterattack, Protect |
| `573981` (necromancer) | Magia + **invoca un minion** | Summon, Wave of souls, Magic Arrow, Desiccation, y el "Soul" con su propio set completo |

**Hallazgo importante**: los tres packs medievales (5, 6 y saber) tienen
**exactamente el mismo set de animaciones con los mismos nombres**. Eso significa
que se intercambian cambiando sólo el `SpriteFrames` — cero código. Tres tipos de
soldado visualmente distintos salen prácticamente gratis.

### 1.2. Monstruos

| Pack | Contenido |
|---|---|
| `987745` (tiny monsters) | Seis criaturas chicas: Bear, Mage, Ooze, Red, Tiny, Yellow. Cada una con Attack/Idle/Walk/Hurt/Death |
| `897123` (boss monsters) | Tres jefes: Mage, Demon y Ooze. Cuatro ataques cada uno, más "sneer", y proyectiles propios (bola de fuego, rayo, bloque de hielo, orbe de veneno) |

### 1.3. Piezas sueltas muy útiles

Estos no son tropa, pero tienen animaciones que resuelven problemas concretos:

- **`635958` tiene `Near_Death`**: un personaje tirado en el suelo. Es
  exactamente la animación que falta para el estado **derribado** (§4.4), que es
  el próximo paso del prototipo. También trae `Dragging_Objects`, que sirve para
  arrastrar heridos (§4.10), y `Resting`.
- **`565335` tiene `Wounded Stance` y `Kneeling Down`**: posturas de herido para
  un soldado que sigue en pie pero está mal.
- **`196564`** es el pack de soporte que ya usamos para el healer: Healing,
  Resurrection, Magic_Shield, Summon_Ally, Time_Slow, Power_Boost.

### 1.4. Lo que NO sirve para este juego

Vale anotarlo para no volver a mirarlos:

- **`607243` (gunslinger) y `671351` / `700501` (shooter)**: son **armas de
  fuego**. Verificado mirando los sprites: pistola con fogonazo y rifle. No pegan
  con un juego de castillos.
- **`405285`**: sólo locomoción de plataformas (nadar, trepar, deslizarse).
- **`565335` y `635958`**: gestos sociales e interacciones de escenario. Sirven
  las piezas sueltas de 1.3, no el pack como tropa.
- Los packs de **iconos** (armas, armaduras, pociones, anillos, escudos, capas) y
  el **tileset** y la **UI**: son para inventario y menús, no para el campo.

### 1.5. Limitaciones a tener en cuenta

- **Todos los sprites son de perfil, una sola dirección.** Ya lo sabemos por el
  pase a 3D: con billboards funciona, pero ningún personaje puede mirar hacia la
  cámara.
- **Ningún soldado tiene animación de curar a otro.** Si alguna vez queremos un
  médico NPC o un sanador enemigo, hay que reusar algo (el `Enchantment_of_Weapons`
  de los medievales sirve como "cast" genérico).
- Los personajes son **maniquíes monocromáticos**. Hoy los diferenciamos por
  tinte; con más tipos en pantalla eso se va a quedar corto y va a hacer falta
  distinguirlos por silueta (el escudo, el arco y la lanza se leen bien; el sable
  y la espada corta no tanto).

---

## 2. Soldados propuestos

Ocho tipos: cuatro aliados, cuatro enemigos. Cada ficha dice qué problema le crea
al healer, que es la única razón por la que existe.

### 2.1. Aliados

#### Escudero — `689963`
> Infantería pesada. Aguanta el frente y no lo suelta.

| | |
|---|---|
| Vida | Alta |
| Daño | Bajo |
| Cadencia | Lenta |
| Alcance | Corto |
| Rasgo | Reduce el daño recibido de frente (`Defense`, `Blow_to_shield`) |

**Problema que crea**: es el mejor candidato a curar — cada punto de vida que le
devolvés rinde el doble porque mitiga. Pero está en la primera línea, o sea
metido en el peligro. Curarlo es rentable y costoso a la vez.

#### Lancero — `852737`
> Ataca desde la segunda fila, por encima del escudero.

| | |
|---|---|
| Vida | Media-baja |
| Daño | Medio |
| Cadencia | Media |
| Alcance | **Largo para melee** (la estocada llega más lejos) |
| Rasgo | Busca colocarse detrás de un aliado |

**Problema que crea**: es eficiente mientras tenga a alguien adelante. Si el
escudero cae, queda expuesto y muere rápido — así que salvar al escudero es
también salvar al lancero. Crea **dependencias entre unidades**, que es lo que
hace que una baja duela más que un número.

#### Espadachín — `949015`
> Daño alto, sin defensa, se mete solo en problemas.

| | |
|---|---|
| Vida | Media |
| Daño | **Alto** |
| Cadencia | Rápida |
| Alcance | Corto |
| Rasgo | Persigue al enemigo más herido, aunque tenga que meterse |

**Problema que crea**: el jugador lo ve alejarse hacia el peligro y tiene que
decidir si lo acompaña (dejando el resto de la línea) o lo deja ir. Es el soldado
que genera la pregunta "¿lo salvo a él o a los tres de allá?" (§3).

#### Arquero — `362398`
> Daño a distancia. Inútil si lo alcanzan.

| | |
|---|---|
| Vida | **Baja** |
| Daño | Medio, a distancia |
| Cadencia | Lenta (con `Charging` previo) |
| Alcance | Muy largo |
| Rasgo | Retrocede si tiene un enemigo encima |

**Problema que crea**: está lejos del frente, o sea lejos del healer, que suele
estar cerca de la pelea. Cuando un enemigo lo alcanza, salvarlo exige **abandonar
la línea** e ir hasta atrás. Estira al jugador por el campo.

### 2.2. Enemigos

#### Horda — `834564` (zombie)
> Muchos, débiles, sin táctica.

Vida baja, daño bajo, lentos, en cantidad. **Problema que crea**: daño constante y
repartido sobre toda la línea. Es el enemigo que hace valiosas las curaciones de
área y los HoT, en lugar de las curaciones grandes puntuales.

#### Bruto — `987745` (Bear)
> Pocos golpes, muy fuertes.

Vida alta, daño **muy alto**, cadencia muy lenta. **Problema que crea**: mata de
dos o tres golpes, así que el margen para reaccionar es corto y hay que anticipar
en vez de reaccionar. Es el enemigo que justifica los escudos y la bendición
preventiva.

#### Nigromante — `573981`
> No pelea: fabrica problemas.

Se queda atrás e invoca minions (el pack trae el "Soul" con set completo).
**Problema que crea**: mientras viva, la presión no baja. Es el primer enemigo
cuya existencia el jugador quisiera poder resolver **y no puede**, porque no
ataca. Buena tensión para un personaje que no tiene forma de matar a nadie.

#### Asesino — `949015` con otro comportamiento
> Ignora la línea. Va por vos.

Rápido, frágil, atraviesa la formación buscando al healer. **Problema que crea**:
es la respuesta al §4.6 — evita que el jugador se quede parado curando desde un
lugar cómodo. Y obliga a usar Impulso para escapar, dándole a esa habilidad una
razón de ser que hoy no tiene.

---

## 3. Comportamientos de IA

Hoy todas las unidades comparten una sola FSM: avanzar hacia el enemigo más
cercano y pegarle. Los comportamientos de abajo son **variaciones sobre esa
misma máquina**, no sistemas nuevos: cambian a quién eligen como objetivo, a qué
distancia se detienen, y cuándo dejan de avanzar.

Los ordeno por lo que cuesta hacerlos, de menos a más.

### 3.1. Elección de objetivo

Hoy: el más cercano. Variantes:

| Comportamiento | Regla | Quién lo usa |
|---|---|---|
| **Oportunista** | Elige al enemigo con **menos vida** en un radio | Espadachín, Bruto |
| **Disciplinado** | No cambia de objetivo hasta matarlo | Escudero |
| **Cazador** | Ignora a todos y va por el healer | Asesino |
| **Vengativo** | Cambia al último que lo golpeó | Bruto |

Es sólo cambiar el criterio de `_buscar_objetivo()`, que ya está aislado en su
propia función. Es la palanca más barata de todas y la que más "personalidad"
aparente da.

### 3.2. Distancia de combate

Hoy: todos se pegan al enemigo. Variantes:

| Comportamiento | Regla | Quién lo usa |
|---|---|---|
| **Contacto** | Avanza hasta tocar | Escudero, Horda |
| **Segunda fila** | Se detiene si ya hay un aliado adelante | Lancero |
| **Distancia** | Mantiene un mínimo; **retrocede** si se lo acercan | Arquero |
| **Retaguardia** | Se queda cerca de su base y nunca avanza | Nigromante |

La "segunda fila" es la más interesante para el juego, porque hace que la
formación se ordene sola en capas y que la línea se vea como una línea de verdad,
no como un amontonamiento.

### 3.3. Reacción al daño

Acá es donde el comportamiento toca directamente el trabajo del healer:

| Comportamiento | Regla | Efecto sobre el jugador |
|---|---|---|
| **Retirada** | Bajo cierto % de vida, se retira hacia su base | **El herido viene solo hacia vos.** Baja la exigencia |
| **Sin retirada** | Nunca huye, pelea hasta caer | **Hay que ir a buscarlo.** La sube |
| **Desesperado** | Bajo cierto % de vida, ataca más rápido | Crea la duda de si conviene curarlo |
| **Protector** | Se interpone entre un aliado muy herido y el enemigo | Te compra tiempo |

**Esta es la tabla más importante del documento.** "Retirada" y "Sin retirada" son
dos líneas de código y cambian por completo el ritmo: un ejército que se repliega
solo es un juego de gestión tranquila; uno que pelea hasta morir es un juego de
correr. Probablemente queramos **mezclar**: reclutas que se retiran y veteranos
que no, para que el jugador aprenda a quién tiene que ir a buscar.

### 3.4. Comportamientos que necesitan sistemas nuevos

- **Invocador** (nigromante): necesita generar unidades en runtime. El spawner ya
  existe en `battle3d.gd`, habría que dárselo a una unidad.
- **Formación**: que un grupo se mueva coordinado en vez de individualmente.
  Es el más caro y el de beneficio menos claro; lo dejaría para el final.
- **Moral** (§4.12): un valor global que modifique el comportamiento de todos —
  que la línea se quiebre y retroceda cuando cae un veterano. Es el que más
  cambiaría la sensación de "ejército" en vez de "quince individuos".

---

## 4. Por dónde empezaría

1. **Tres tipos de aliado con el mismo comportamiento** (escudero, lancero,
   espadachín). Como los tres packs comparten animaciones, es sólo stats y
   `SpriteFrames`: se ve muchísimo más variado sin tocar la IA.
2. **"Retirada" vs "Sin retirada"**. Dos líneas, y cambia el ritmo del juego
   entero. Es lo que más rápido nos va a decir qué tipo de juego queremos.
3. **Arquero con comportamiento de distancia**. Estira al jugador por el campo y
   rompe la costumbre de quedarse pegado al frente.
4. **Asesino**. Le da sentido al Impulso y ataca el problema de quedarse parado
   en un lugar seguro (§4.6).

El nigromante y los jefes los dejaría para cuando el núcleo esté confirmado: son
los más caros y los que menos aportan a la pregunta de si el juego es divertido.

---

## 5. Riesgos

- **Legibilidad**: cuatro tipos de aliado y cuatro de enemigo, todos maniquíes
  monocromáticos distinguidos por tinte, en una línea amontonada. Hoy ya cuesta
  seguir quién es quién. Antes de sumar tipos, probablemente haya que resolver
  cómo se distinguen — silueta, color por rol, o un icono chico.
- **Los comportamientos compiten con el healer.** Si los soldados se retiran
  solos, se protegen entre ellos y esquivan bien, el jugador sobra. El objetivo
  no es una IA que juegue bien: es una IA que **falle de formas interesantes**,
  para que haya algo que salvar.
- **El asesino puede ser frustrante.** Si el healer no tiene forma de defenderse
  (§10) y hay algo que lo caza, la respuesta óptima es correr todo el tiempo. Eso
  compite con curar, que es el juego. Habría que probarlo con un solo asesino
  ocasional antes de convertirlo en una amenaza constante.
