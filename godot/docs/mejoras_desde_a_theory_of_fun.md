# Mejorar Castle Defense desde *A Theory of Fun for Game Design*

## Estado del documento

Propuesta de diseño basada en la lectura de *A Theory of Fun for Game Design*,
de Raph Koster, y en una revisión del prototipo 3D, sus recursos, pruebas y los
documentos de diseño actuales.

No es una lista de features comprometidas. Es una hipótesis de dirección, un
orden de prototipado y un conjunto de criterios para decidir qué merece entrar
al juego.

Referencias como “p. 51” indican la página del archivo PDF guardado en
[`pdfs/[Raph_Koster]_A_Theory_Of_Fun_For_Game_Design(BookFi).pdf`](pdfs/%5BRaph_Koster%5D_A_Theory_Of_Fun_For_Game_Design%28BookFi%29.pdf),
no la numeración impresa del libro.

---

## 1. Conclusión ejecutiva

La idea más útil de Koster para este proyecto es que el jugador se divierte
mientras **descubre, practica y domina patrones**. Aplicada acá, la pregunta no
es “¿cuántas habilidades, estados o enemigos podemos agregar?”, sino:

> **¿Qué aprende a reconocer y decidir el jugador como médico de guerra, y cómo
> le presentamos variaciones de ese problema antes de que se vuelva rutina?**

El patrón central que ya existe es prometedor:

1. leer un campo de batalla que se mueve solo;
2. detectar qué crisis importa;
3. estimar tiempo, distancia, costo y valor del paciente;
4. elegir una intervención imperfecta;
5. desplazarse y ejecutarla bajo amenaza;
6. observar cómo la decisión altera el frente;
7. aprender del resultado.

Hoy el prototipo contiene casi todas las piezas necesarias para demostrar ese
patrón, pero las entrega juntas, con poca progresión pedagógica y con resultados
que todavía son difíciles de atribuir a una decisión concreta. El mejor próximo
paso no es ampliar el catálogo: es construir una **vertical de aprendizaje** de
seis encuentros breves, añadir feedback causal y medir si las decisiones cambian
con el contexto.

La dirección recomendada es:

- mantener al healer como actor indirecto que gana a través de otros;
- convertir el triaje en la habilidad que el jugador aprende;
- enseñar una variable por vez y después combinarlas;
- generar variedad mediante composiciones y geometría, no sólo con más cantidad;
- hacer que los errores cuesten, pero también expliquen algo;
- usar veteranía, nombres y sectores para volver significativas las decisiones;
- postergar economía, árboles de habilidades y ocho estados hasta validar el
  núcleo.

---

## 2. Qué tomamos de Koster

El libro funciona mejor como lente que como receta. Varias afirmaciones sobre
psicología son divulgativas y tienen más de veinte años; deben transformarse en
hipótesis y comprobarse con jugadores, no tratarse como leyes.

| Idea del libro | Dónde aparece | Traducción para este juego |
|---|---:|---|
| El cerebro busca, completa y agrupa patrones | pp. 25-43 | La interfaz debe permitir reconocer una crisis sin leer números uno por uno. Los casos parecidos deben compartir señales visuales. |
| Los juegos son sistemas concentrados donde se practican permutaciones de un patrón | pp. 45-49 | Cada encuentro debe recombinar distancia, gravedad, tipo de unidad, amenaza y recursos alrededor del mismo acto: priorizar. |
| La satisfacción principal aparece al comprender o dominar un problema | p. 51 | La recompensa más importante debe ser “leí bien la batalla”, no sólo una explosión visual o un número más grande. |
| Un juego aburre si ya se entendió, si no se distingue ningún patrón o si revela variantes demasiado lento o demasiado rápido | pp. 53-57 | Hay que evitar tanto la rotación automática de habilidades como el caos ilegible. La curva debe alternar enseñanza, práctica y combinación. |
| Los sistemas muy cerrados se agotan; variables menos predecibles prolongan el interés | p. 49 | Composición, posición, objetivos enemigos y soldados persistentes pueden refrescar el problema. El azar debe variar situaciones, no decidir resultados opacos. |
| El jugador intentará optimizar, explotar y eliminar el trabajo | pp. 121-129 | Si “curar siempre al de menor vida” o esperar mana resuelve todo, el jugador lo hará. Hay que diseñar dilemas donde ninguna regla simple sea universal. |
| Un juego robusto combina preparación, espacio, una mecánica central sólida, retos variados, varias herramientas y habilidad al usarlas | pp. 131-135 | El proyecto ya tiene espacio, herramientas y ejecución. Le faltan preparación acotada y una secuencia explícita de retos. |
| El feedback debe variar con la calidad de la acción; el dominio y el costo del fracaso requieren diseño | pp. 133-137 | Curar 10 HP y salvar una línea no debería comunicar lo mismo que desperdiciar 25 de mana. El cierre de batalla debe explicar causalidad. |
| Todos los sistemas deberían apoyar lo que el juego quiere enseñar | p. 137 | Economía, veteranía, estados y enemigos sólo entran si enriquecen el triaje. Si crean una capa paralela o una solución automática, distraen. |
| La presentación y la ficción son parte de la experiencia, aunque el jugador vea las reglas | pp. 171-173 | “Médico de guerra” debe sentirse en animación, sonido, nombres, cuerpos y consecuencias. No alcanza con barras técnicamente claras. |

### El criterio editorial que sale del libro

Antes de agregar una mecánica, debería poder completarse esta frase:

> “Esta mecánica enseña al jugador a reconocer **___**, decidir entre **___** y
> **___**, y revisar su hipótesis cuando **___**.”

Si sólo agrega potencia, volumen o una animación nueva, no necesariamente amplía
el juego.

---

## 3. Diagnóstico del prototipo actual

### 3.1. Lo que ya está fuerte

El proyecto ya tiene una identidad mecánica bastante más clara que la que
sugiere el README:

- dos ejércitos automáticos empujan una línea y ganan al llegar a la base rival;
- el jugador se mueve libremente en un campo 3D lateral;
- la cámara sigue el frente con zona muerta;
- apuntar usa selección “pegajosa” e imán de mouse para resolver el
  amontonamiento;
- hay vida y mana del healer, salto e impulso;
- los enemigos pueden atacar al healer, y los aliados funcionan como cobertura
  emergente;
- hay aviso y aparición de enemigos cerca del healer;
- los soldados pueden sangrar, retirarse, caer, morir o ser reanimados;
- existen tres roles aliados diferentes: escudero resistente, lancero de segunda
  fila y espadachín oportunista;
- hay seis acciones equipadas: Curar, Estabilizar, Oleada, Bendición, Impulso y
  Reanimar;
- el HUD comunica vida, mana, enfriamientos, conteos, caídos y posición del
  frente;
- hay pruebas dedicadas a combate, apuntado, habilidades, derribados, amenaza,
  tipos de soldado y desenlace.

Eso ya permite aprender más que “hacer click sobre una barra baja”. El jugador
puede aprender geometría, ventanas temporales, eficiencia, valor relativo,
cobertura y prevención.

### 3.2. El problema principal

La partida actual funciona como una **prueba de integración de todos los sistemas
a la vez**. Arranca con tres tipos aliados aleatorios, más enemigos que aliados,
refuerzos periódicos, sangrado, retiradas, derribos, seis acciones y emergentes.
Para quien recién entra, buena parte de eso se percibe como ruido.

Koster distingue dos fracasos que acá pueden convivir:

- para un principiante, el patrón no aparece: “pasan demasiadas cosas”;
- para quien descubre una rutina suficientemente buena, las tandas de zombies
  cambian cantidad pero no naturaleza: “ya entendí qué hacer”.

La prioridad de diseño es abrir un pasillo entre esos extremos.

### 3.3. Brechas concretas

| Área | Estado actual | Brecha de aprendizaje |
|---|---|---|
| Objetivo | Ganar al llegar a la base rival | Es claro al sistema, pero el jugador no recibe metas intermedias ni aprende por qué el frente avanzó o retrocedió. |
| Lectura | Barras, rombo de sangrado, caídos y frente | Falta jerarquía de urgencia y detalle contextual al apuntar. |
| Herramientas | Seis desde el inicio | No hay secuencia para formar modelos mentales ni saber cuándo conviene cada una. |
| Enemigos | Un tipo, más emergentes del mismo tipo | Cambia la posición y la cantidad, pero no suficientemente la decisión médica. |
| Recursos | Mana regenerativo y cooldowns | Favorece esperar o usar una rotación; no registra eficiencia ni costo de oportunidad persistente. |
| Resultado | Victoria/derrota y reinicio | No atribuye el resultado: qué se salvó, qué se desperdició, qué crisis se ignoró. |
| Dificultad | Parámetros globales y azar | No hay una curva intencional de enseñanza, práctica, examen y recombinación. |
| Persistencia | Diseñada en documentos, no implementada | Las bajas todavía tienen poco peso más allá de perder presencia en el frente. |

### 3.4. Desajustes de documentación

- El README presenta un juego 2D y una escena principal distinta, pero
  `project.godot` ejecuta `scenes/3d/battle3d.tscn`.
- `habilidades_catalogo.md` enumera cinco habilidades implementadas, mientras la
  escena actual equipa también Reanimar.

No afectan el prototipo, pero dificultan usar la documentación como memoria de
diseño. Conviene corregirlos cuando se cierre esta dirección.

---

## 4. La lección central del juego

### 4.1. Fantasía

> **Soy un médico de guerra dentro de una batalla que no controlo. No puedo
> salvar a todos; gano leyendo mejor qué intervención cambia el destino del
> frente.**

### 4.2. Habilidad que queremos enseñar

La habilidad maestra es **triaje situado**, compuesta por cinco lecturas:

1. **Urgencia:** cuánto tiempo queda antes de una consecuencia irreversible.
2. **Impacto:** qué cambia en el frente si esa unidad sigue operativa.
3. **Costo:** mana, cooldown, tiempo de viaje y exposición del healer.
4. **Tratabilidad:** qué herramienta resuelve la causa y cuál sólo compra tiempo.
5. **Valor:** rol, veteranía y contexto; no siempre coincide con la vida más baja.

### 4.3. Gramática mínima

Cada crisis debería poder describirse con cuatro componentes combinables:

`paciente + problema + ventana + contexto`

Ejemplos:

- lancero + sangrado + 6 segundos + sostiene la segunda fila;
- recluta + derribado + 3 segundos + está lejos y expuesto;
- escudero + daño entrante + inmediato + es la cobertura del healer;
- veterano + herida moderada + sin urgencia + un sector difícil por delante.

La profundidad no necesita decenas de verbos. Sale de recombinar pocos elementos
legibles y hacer que cambie la respuesta correcta.

---

## 5. Curva de aprendizaje propuesta

La secuencia usa el ritmo **mostrar → practicar → variar → combinar → examinar**.
No depende de tutoriales largos: cada encuentro restringe el espacio de
posibilidades para que la regla se vea jugando.

| Encuentro | Sistemas disponibles | Patrón que enseña | Señal de dominio |
|---|---|---|---|
| 1. Mantener la línea | Movimiento + Curar; escuderos vs. zombies; sin sangrado | Acercarse, apuntar, curar y ver el efecto sobre el frente | El jugador salva a un escudero y asocia su supervivencia con detener el retroceso. |
| 2. No desperdiciar | Curar + mana limitado; heridas de distinta magnitud | Overhealing y costo de oportunidad | Elige a quien aprovecha la curación completa, no sólo al primero que ve. |
| 3. Tratar la causa | Se suma Estabilizar y sangrado telegrafiado | Cortar daño futuro antes de reponer vida | Estabiliza antes de curar cuando el tiempo lo permite. |
| 4. La ventana | Se suma derribo y Reanimar; un paciente cercano y otro lejano | Urgencia, distancia y renuncia | Decide a cuál llegar y acepta conscientemente perder al otro. |
| 5. Curar antes | Se suma Bendición; enemigo de golpe fuerte anunciado | Prevención frente a reacción | Bendice al escudero antes del impacto en vez de reparar después. |
| 6. Leer la formación | Se suman lancero, espadachín, Oleada e Impulso | Rol, geometría y reposicionamiento | Usa área en un grupo rentable y conserva la unidad cuya función importa. |
| 7. Sin lugar seguro | Se activan emergentes y daño al healer | Cobertura y atención dividida | Se mueve detrás de aliados sin abandonar la lectura del frente. |
| 8. Examen abierto | Todo lo anterior con composición variable | Triaje completo | Dos jugadores pueden ganar con decisiones distintas y explicar por qué. |

### Reglas de introducción

- No explicar una habilidad antes de que exista una situación que la necesite.
- No introducir dos iconos médicos nuevos en el mismo encuentro.
- Después de presentar una regla, repetirla una vez con parámetros distintos.
- La primera aparición debe ser indulgente; la segunda puede exigir ejecución.
- El encuentro siguiente debe mezclar la regla nueva con una anterior.
- Si una regla requiere texto permanente para entenderse, todavía no está bien
  expresada visualmente.

---

## 6. Cambios de diseño recomendados

### 6.1. De oleadas aleatorias a encuentros compuestos

La tanda actual elige tipos al azar. Eso sirve para estrés, pero dificulta saber
qué aprendió el jugador. Introducir una definición de encuentro con:

- formación inicial fija o con variación acotada;
- refuerzos por evento y no sólo por reloj;
- estados permitidos;
- habilidades habilitadas;
- objetivo pedagógico;
- condiciones de éxito secundarias;
- semilla repetible para pruebas.

El azar debería variar posiciones o elegir entre dos equivalentes. No debería
ocultar por qué una partida fue mucho más difícil que otra.

**Criterio de aceptación:** repetir un encuentro con la misma semilla debe
producir un problema comparable; cambiar de semilla puede exigir otra ejecución,
pero no enseñar otra regla.

### 6.2. Feedback causal en tres escalas

#### Inmediato, menos de 0,3 segundos

- número o pulso de vida realmente recuperada;
- mana gastado;
- sobrante desperdiciado;
- confirmación distinta para causa resuelta, vida repuesta y prevención;
- dirección clara cuando el objetivo está fuera de rango;
- sonido particular para “decisión eficiente”, no sólo para “botón válido”.

#### Táctico, entre 1 y 5 segundos

- la unidad salvada vuelve a cumplir su rol;
- el frente responde de forma visible;
- la amenaza que se evitó deja una marca comprensible;
- un derribado muestra tiempo alcanzable en segundos o pulsos, no sólo una
  fracción abstracta.

#### Reflexivo, fin de encuentro

Un informe corto, no una planilla:

- soldados que llegaron vivos / muertos / reanimados;
- crisis atendidas e ignoradas;
- curación efectiva frente a desperdiciada;
- mana sin usar;
- tiempo promedio para tratar sangrado;
- “momento bisagra”: la acción con mayor impacto estimado;
- una sugerencia basada en una conducta, no en el resultado.

Ejemplo: “Perdiste dos lanceros por sangrado mientras Curar estaba disponible.
Estabilizar primero habría frenado el daño futuro.”

El informe debe ayudar a formular una hipótesis para el próximo intento. No debe
dar una nota universal que reduzca todo a maximizar puntuación.

### 6.3. Jerarquía visual de urgencia

Mantener la propuesta de `estados_negativos.md`: **un problema dominante sobre la
unidad y detalle al apuntar**. Añadir tres niveles de urgencia compartidos por
todos los estados:

- estable: información tenue;
- en riesgo: pulso lento y color de familia;
- crítico: pulso rápido, sonido espacial breve y cuenta regresiva si corresponde.

Al apuntar, mostrar una tarjeta mínima:

```text
Mara · Lancera · Veterana
42 / 70 HP
Sangrado · 5,2 s
Estabilizar: corta el sangrado
Curar: +35 HP (7 se desperdician)
```

La tarjeta no debería decidir por el jugador. Puede mostrar consecuencias
inmediatas, pero no decir “mejor objetivo”.

### 6.4. Herramientas con roles que se pisan parcialmente

Koster advierte indirectamente contra los problemas con una única respuesta. Si
cada icono tiene su botón gemelo, sólo enseñamos asociación visual. Para cada
crisis deberían existir al menos dos respuestas con costos diferentes:

| Crisis | Respuesta eficiente | Respuesta de emergencia | Renuncia posible |
|---|---|---|---|
| Sangrado | Estabilizar y luego curar | Curar repetidamente para aguantar | Dejar retirarse al soldado |
| Daño fuerte anunciado | Bendición antes del golpe | Curar o reanimar después | Salvar a otra unidad más rentable |
| Grupo herido | Oleada bien posicionada | Curaciones individuales | Abandonar una parte del frente |
| Derribado lejano | Impulso + Reanimar | Reanimar a uno cercano | Aceptar la muerte y conservar mana |
| Healer perseguido | Usar aliados como cobertura | Impulso o salto | Ceder terreno para sobrevivir |

Esto evita que sumar estados convierta el juego en memorizar una tabla.

### 6.5. Recurso que premie comprensión

El mana regenerativo regula el ritmo, pero no distingue una buena decisión de una
mala. Antes de sumar suministros persistentes, probar un recurso secundario
pequeño, por ejemplo **Temple**:

- se gana al curar con poco desperdicio, cortar un estado antes de su primer tick
  grave o prevenir una caída;
- se pierde lentamente, no por recibir daño;
- potencia una habilidad existente o permite reducir su costo;
- tiene un tope bajo para evitar acumulación.

La intención es que jugar bien produzca nuevas opciones. Si el jugador empieza a
farmear acciones triviales para cargarlo, la regla falló y debe cerrarse, no
premiarse.

No implementar Temple y suministros juntos. Primero hay que saber si el núcleo
necesita una recompensa de pericia o una reserva de largo plazo.

### 6.6. Composición antes que multiplicación

El mejor contenido siguiente no son diez zombies más. Son enemigos que alteran
qué información importa:

1. **Soldado rival / escudero enemigo:** enseña daño sostenido y una línea
   predecible.
2. **Bruto:** golpe lento y telegrafiado; hace valiosa la prevención.
3. **Hostigador o arquero:** amenaza segunda fila y obliga a leer profundidad.
4. **Asesino:** busca al healer; convierte formación en cobertura.
5. **Nigromante:** alarga una crisis; crea una decisión entre sostener y resolver
   la fuente indirectamente a través del ejército.

Cada uno debe cambiar la decisión médica con una silueta, animación y señal de
ataque distinguibles. Si sólo cambia daño/vida, es una variante de balance, no un
nuevo patrón.

### 6.7. Veteranía como memoria del aprendizaje

La veteranía propuesta en `progresion_y_contenido.md` encaja especialmente bien:
convierte la supervivencia en progreso y da contexto al triaje. Implementación
mínima:

- al sobrevivir un sector, una unidad gana experiencia;
- al llegar a nivel 2 recibe nombre;
- veteranos tienen una marca visual sobria;
- el resumen cuenta su historial;
- las mejoras aumentan margen o eficiencia como paciente, no autonomía.

Primero probarlo dentro de una sesión de tres sectores. No hace falta guardado
permanente todavía. Si los jugadores recuerdan un nombre y cambian una decisión
por él, la hipótesis está validada.

### 6.8. Presentación al servicio del patrón

La ficción no es decoración separada. Debe volver legible y emocional el sistema:

- una unidad que se retira necesita una animación/voz distinta de quien avanza;
- estabilizar debe verse como cortar una causa, no como una curación verde más;
- reanimar necesita una transición clara de cuerpo a combatiente;
- una muerte definitiva debe tener más peso que un derribo;
- los roles necesitan siluetas legibles aun sin mirar la ficha;
- el frente debe comunicar empuje con sonido, polvo, formación y cámara, no sólo
  con el indicador del HUD.

La estética correcta es la que hace visible la gramática del juego y sostiene la
fantasía de médico de guerra.

---

## 7. Estructura de campaña que enseña

El “campo largo por sectores” ya propuesto puede funcionar como currículo. Cada
sector presenta una pregunta y el puesto conquistado actúa como cierre de una
unidad de aprendizaje.

### Acto 1: Leer cuerpos

- Sector 1: daño simple y curación.
- Sector 2: overhealing y mana.
- Sector 3: sangrado frente a daño directo.
- Cierre: encuentro que mezcla los tres sin amenaza al healer.

### Acto 2: Leer tiempo y espacio

- Sector 4: derribados a diferentes distancias.
- Sector 5: roles de formación y curación de área.
- Sector 6: emergentes y cobertura.
- Cierre: sostener dos crisis en lugares distintos.

### Acto 3: Leer consecuencias

- Sector 7: veteranos y reclutas con valor distinto.
- Sector 8: bruto con ataques anunciados.
- Sector 9: composición variable y preparación de dos herramientas.
- Cierre: examen abierto con varias soluciones viables.

Entre sectores, ofrecer **una decisión**, no un menú completo. Por ejemplo:

- reponer mana o recuperar un soldado;
- elegir Bendición u Oleada para el siguiente sector;
- tomar ruta corta con bruto o ruta larga con sangrado.

La preparación importa sólo si modifica lo que el jugador observará y decidirá
en el campo.

---

## 8. Evitar estrategias dominantes

Estas son las simplificaciones que probablemente intentará el jugador y cómo
deberíamos responder desde el diseño:

| Rutina dominante | Por qué aparecería | Contramedida sana |
|---|---|---|
| Curar siempre la barra más baja | Toda vida parece igual | Roles, ventanas, valor persistente y causas que siguen haciendo daño |
| Gastar todo apenas sale del cooldown | Mana que vuelve y presión constante | Picos anunciados, oportunidades de prevención y recompensa por reserva útil |
| Esperar mana en zona segura | No hay costo por tiempo | Frente que cede y amenazas que obligan a reposicionarse |
| Salvar siempre veteranos | Su pérdida pesa más | Reclutas necesarios para masa/cobertura y objetivos donde cantidad importe |
| Usar siempre la misma rotación | Encuentros y estados homogéneos | Composiciones que cambian el orden correcto, loadout limitado y herramientas solapadas |
| Reiniciar ante una baja | Pérdida demasiado binaria | Recuperación posible, reemplazos y recompensas por continuar en desventaja |
| Farmear enemigos débiles | Recompensa plana por acción | Recompensa por riesgo, urgencia e impacto; rendimientos decrecientes |

No hay que prohibir que el jugador sea ingenioso. Una estrategia inesperada que
usa las reglas y conserva decisiones puede enriquecer el juego. Se corrigen las
que eliminan sistemáticamente la necesidad de leer y elegir.

---

## 9. Roadmap priorizado

### Fase 0: Instrumentar el núcleo

**Objetivo:** poder observar aprendizaje antes de agregar contenido.

- registrar por encuentro curación emitida/efectiva/desperdiciada;
- registrar mana gastado y sin usar;
- registrar caídas, reanimaciones, muertes y causa;
- registrar tiempo entre aparición de sangrado y estabilización;
- registrar posición del frente cada pocos segundos;
- fijar semilla y composición desde un recurso de encuentro;
- crear un resumen final de depuración, aunque al principio sea texto.

**Salida:** podemos comparar dos intentos y explicar qué conducta cambió.

### Fase 1: Vertical de tres lecciones

**Objetivo:** validar leer → decidir → actuar → entender.

- Encuentro 1: Curar.
- Encuentro 2: eficiencia/overhealing.
- Encuentro 3: sangrado y Estabilizar.
- desbloqueo progresivo de acciones;
- tarjeta contextual al apuntar;
- feedback inmediato diferenciado;
- resumen de fin de encuentro.

**Salida:** al menos 4 de 5 jugadores nuevos explican la diferencia entre curar
y estabilizar sin repetir el texto del tutorial.

### Fase 2: Tiempo, espacio y amenaza

**Objetivo:** comprobar que el juego supera la lectura de barras.

- derribados y Reanimar;
- un encuentro con elección imposible entre dos pacientes;
- Bendición frente a ataque anunciado;
- emergente como amenaza al healer;
- uso explícito de aliados como cobertura;
- composición fija y semillas para balance.

**Salida:** aparecen rutas y prioridades distintas entre jugadores, pero el
resultado se percibe justo.

### Fase 3: Variación sostenible

**Objetivo:** evitar que el patrón dominado se vuelva rutina.

- primer enemigo realmente nuevo: Bruto;
- primer estado adicional sólo si sangrado se lee con fiabilidad;
- sector de tres encuentros;
- veteranía de sesión y nombres;
- una elección de preparación entre sectores;
- ajuste de dificultad por composición.

**Salida:** el jugador cambia de estrategia al reconocer la composición y puede
explicar ese cambio.

### Fase 4: Expansión condicionada

Sólo después de validar las fases anteriores:

- sistema genérico de efectos;
- HoT, cadena o escudo, de a uno;
- suministros/economía;
- facciones completas;
- persistencia entre partidas;
- mapa de rutas o metaprogresión.

No construir simultáneamente sistema de efectos, economía, equipo y campaña.
Todos amplían el espacio de estados y harían muy difícil descubrir cuál mejoró o
empeoró el núcleo.

---

## 10. Prototipos y preguntas falsables

### Experimento A: ¿el triaje existe?

Situación: dos aliados caen casi juntos. Uno es cercano y común; el otro lejano y
clave para sostener el frente. Sólo alcanza el tiempo para uno.

- Hipótesis: los jugadores toman decisiones diferentes y pueden justificarlas.
- Falla: todos eligen la barra/contador más urgente sin considerar contexto.
- Acción si falla: hacer más visible el rol y la consecuencia sobre el frente,
  no agregar otra habilidad.

### Experimento B: ¿se aprende la causa?

Situación: dos soldados con igual vida; uno sangra y otro no.

- Hipótesis: tras una demostración, el segundo intento prioriza Estabilizar.
- Falla: el icono se ignora o Curar domina igualmente.
- Acción si falla: reforzar telegraph y ajustar números para que la diferencia
  causal sea observable.

### Experimento C: ¿la prevención se siente atribuible?

Situación: un bruto anuncia un golpe sobre un escudero.

- Hipótesis: Bendición previa se asocia con evitar la caída.
- Falla: el jugador gana pero no sabe si la habilidad importó.
- Acción si falla: comparación audiovisual del daño absorbido y reacción del
  frente.

### Experimento D: ¿el caos sigue siendo legible?

Situación: doce unidades, dos estados y un emergente.

- Hipótesis: en una captura de tres segundos el jugador identifica la crisis más
  urgente y su ubicación.
- Falla: busca iconos uno por uno o mira sólo el HUD.
- Acción si falla: reducir señales simultáneas y mostrar sólo el estado dominante.

### Experimento E: ¿la veteranía cambia conducta?

Situación: un veterano y dos reclutas compiten por recursos.

- Hipótesis: algunos jugadores protegen al veterano aun cuando no maximiza el
  número de supervivientes, y recuerdan su nombre después.
- Falla: el nombre no afecta decisiones o siempre las determina.
- Acción si falla: ajustar peso y presentación; el objetivo es tensión, no una
  respuesta obligatoria.

---

## 11. Métricas útiles

No buscar una única métrica de “diversión”. Combinar telemetría con observación y
una entrevista muy corta.

### Durante la partida

- porcentaje de curación desperdiciada;
- mana promedio y tiempo al máximo: indica si el jugador olvida gastar;
- tiempo de respuesta por tipo de crisis;
- distancia recorrida por intervención efectiva;
- habilidades usadas por encuentro y orden;
- muertes evitables frente a inevitables según la composición;
- posición y velocidad del frente;
- daño recibido por el healer y proximidad a cobertura;
- frecuencia de reinicio tras una baja.

### Después de la partida

Preguntar, sin enseñar términos:

1. ¿Qué situación te preocupó más y por qué?
2. ¿Qué acción tuya cambió la batalla?
3. ¿Qué harías distinto en otro intento?
4. ¿Hubo algo que pareciera aleatorio o injusto?
5. ¿En qué momento sentiste que ya sabías qué hacer?

La tercera pregunta mide aprendizaje. La quinta detecta tanto dominio saludable
como inicio de rutina.

### Señales de éxito

- el jugador predice consecuencias antes de actuar;
- usa la misma herramienta con intenciones distintas;
- cambia de prioridad cuando cambia la composición;
- puede explicar una derrota sin culpar a ruido invisible;
- una segunda partida muestra una hipótesis nueva, no sólo más velocidad;
- dos estrategias distintas resultan viables.

### Señales de alarma

- mira barras en orden y no el campo;
- recita una rotación universal;
- no distingue qué habilidad causó qué efecto;
- gana sin desplazarse;
- una crisis exige una sola respuesta correcta e inmediata;
- más dificultad sólo significa más unidades o más vida;
- el resumen enseña información que no fue visible durante la acción.

---

## 12. Mapa técnico sugerido

Sin implementar todavía, el diseño encaja con la arquitectura actual de esta
forma:

| Cambio | Punto de entrada probable |
|---|---|
| Recurso/definición de encuentro y semilla | Nuevo `encuentro.gd`; `scripts/3d/battle3d.gd` deja de decidir toda la composición por timers globales |
| Telemetría de acciones | Señales de `ComponenteHabilidades`, `Unidad3D` y `Battle3D`; nuevo recolector desacoplado |
| Causa de caída/muerte | `scripts/3d/unidad3d.gd`, conservando fuente y último efecto relevante |
| Tarjeta al apuntar | `scripts/3d/healer3d.gd` ya conoce `_apuntada`; nueva vista en `scenes/ui/hud.tscn` |
| Urgencia visual | `scripts/3d/overlay_unidades.gd`, sin sumar más de un icono dominante |
| Desbloqueo por encuentro | Filtro en `ComponenteHabilidades` o loadout definido por el recurso de encuentro |
| Informe final | Señal `batalla_terminada`; nueva capa de resumen antes de reiniciar |
| Ataques telegrafiados | Extender `TipoSoldado` sólo después de definir el Bruto como problema pedagógico |
| Veteranía de sesión | Identidad/datos fuera de `Unidad3D`; la escena debería representar a un soldado persistente, no ser el guardado |

Dos precauciones técnicas:

1. No seguir acumulando temporizadores específicos en `Unidad3D` si se aprueba un
   segundo o tercer efecto persistente; ahí sí conviene extraer un contenedor de
   efectos.
2. No acoplar analítica al HUD. El resumen y la interfaz deben consumir eventos;
   el modelo de combate debe seguir funcionando en las pruebas headless.

---

## 13. Decisiones que conviene tomar ahora

### Recomendada: el healer no ataca en la primera vertical

Atacar abre otro patrón central y compite con el triaje. Primero hay que probar
si influir indirectamente alcanza para sostener el juego. Más adelante, una
habilidad híbrida puede ser una variación deliberada, no un parche al aburrimiento.

### Recomendada: seis habilidades existen, pero no aparecen juntas al inicio

La complejidad total puede ser adecuada para un jugador que ya aprendió. El
problema es el orden de presentación, no necesariamente la cantidad final.

### Recomendada: el siguiente enemigo es el Bruto

Es la forma más económica de probar anticipación, Bendición y feedback causal.
Agrega un patrón nuevo sin exigir aún un sistema genérico de estados.

### Recomendada: veteranía dentro de la sesión antes que economía completa

Valida apego y valor diferencial con menos infraestructura. Oro, tienda,
suministros y reclutas pueden venir después si la pérdida ya resulta interesante.

### Recomendada: dificultad diseñada antes que adaptación automática

Primero construir encuentros con intención y semillas repetibles. Un director
dinámico sin un modelo claro podría ocultar errores de balance y volver opaca la
causalidad.

---

## 14. Qué no haría todavía

- implementar los ocho estados negativos del catálogo;
- agregar más slots de habilidades;
- subir dificultad aumentando vida y cantidad en paralelo;
- construir equipo por tiers para soldados;
- hacer una tienda completa;
- añadir metaprogresión permanente;
- usar rareza aleatoria para fabricar variedad;
- convertir el resumen en una puntuación que imponga una forma única de jugar;
- pulir mucho arte antes de validar que se leen las consecuencias;
- tratar el libro como prueba de que una idea funcionará sin playtests.

---

## 15. Próximo corte jugable recomendado

El corte más informativo y pequeño contiene:

1. un recurso de encuentro con semilla y loadout;
2. tres encuentros consecutivos: Curar, eficiencia, Sangrado;
3. tarjeta contextual al apuntar;
4. señales diferenciadas para curación efectiva, desperdicio y estabilización;
5. telemetría mínima;
6. resumen final con una observación causal;
7. reinicio rápido del mismo encuentro.

Este corte responde la pregunta más importante antes de ampliar el juego:

> **¿El jugador está aprendiendo a hacer triaje, o solamente está reaccionando a
> estímulos y cooldowns?**

Si la respuesta es triaje, los sistemas ya imaginados —roles, amenaza, estados,
veteranos, sectores, suministros y nuevas habilidades— tienen una columna
vertebral firme. Si no, agregar esos sistemas sólo hará más difícil ver el
problema.
