# Healer en Campo de Batalla — Ideas Iniciales de Diseño

## Estado del documento

Este documento reúne **ideas, hipótesis y sugerencias de diseño** para explorar un juego inspirado estructuralmente en *Dwarves: Glory, Death and Loot*, pero centrado en el rol activo de un **healer dentro de un campo de batalla lateral**.

Nada de lo descrito aquí debe considerarse definitivo. El objetivo es utilizar estas propuestas como una **base de experimentación**, prototipado y discusión.

Las mecánicas pueden:

- implementarse tal como están;
- simplificarse;
- combinarse entre sí;
- descartarse;
- reemplazarse por nuevas variantes.

La prioridad inicial debería ser descubrir qué combinación produce un gameplay claro, divertido y con identidad propia.

---

# 1. Concepto general

El jugador controla principalmente a un **healer o support** dentro de una batalla donde dos ejércitos combaten de manera mayormente automática.

Los NPC de ambos bandos aparecen mediante oleadas, avanzan lateralmente por el escenario y, al encontrarse, comienzan a combatir.

El jugador no controla directamente a cada soldado.

Su responsabilidad principal es:

- mantener vivo al ejército;
- decidir a quién ayudar;
- administrar recursos limitados;
- moverse por el campo de batalla;
- reaccionar ante situaciones críticas;
- determinar cuándo curar, estabilizar, potenciar o abandonar una unidad.

La propuesta puede resumirse con la siguiente idea:

> Los soldados saben luchar. El jugador debe conseguir que sobrevivan el tiempo suficiente para ganar.

---

# 2. Hipótesis de Core Loop

Una posible estructura básica podría ser:

1. Preparación previa al combate.
2. Comienza una oleada.
3. Aparecen unidades aliadas y enemigas.
4. Ambos ejércitos avanzan lateralmente.
5. Se forma una línea de combate.
6. Aparecen soldados heridos, derribados o afectados por estados negativos.
7. El jugador identifica prioridades.
8. Utiliza curaciones, buffs, rescates u otras habilidades.
9. La línea de batalla avanza o retrocede según el resultado del enfrentamiento.
10. Finaliza la oleada.
11. El jugador recibe recompensas, mejoras o nuevas decisiones.
12. Comienza la siguiente oleada.

Este loop debería considerarse solamente una estructura inicial para prototipar.

---

# 3. Principio de diseño sugerido

Una de las ideas más importantes a explorar es que el juego **no consista únicamente en detectar barras de vida bajas y llenarlas nuevamente**.

El interés puede aparecer cuando el jugador debe tomar decisiones bajo presión.

Por ejemplo:

- un caballero veterano está al 15% de vida;
- tres soldados comunes están heridos;
- un arquero está envenenado;
- una unidad derribada morirá en pocos segundos;
- el healer solamente tiene recursos suficientes para resolver dos situaciones.

La pregunta interesante pasa a ser:

> ¿A quién vale la pena salvar?

Esto podría convertirse en uno de los pilares centrales del juego.

---

# 4. Ideas de mecánicas

## 4.1. Sistema de triaje

Los soldados podrían presentar distintos niveles de gravedad.

Ejemplo:

- herida leve;
- herida seria;
- estado crítico;
- derribado;
- muerte inminente.

El jugador debe decidir qué paciente tiene prioridad.

### Posible aporte

Evita que el sistema de curación se reduzca a utilizar siempre la misma habilidad sobre la unidad con menor porcentaje de vida.

---

## 4.2. Diferentes tipos de heridas

Las unidades podrían sufrir problemas distintos.

Ejemplos:

- sangrado;
- fractura;
- quemadura;
- veneno;
- infección;
- aturdimiento;
- hemorragia;
- trauma;
- maldición.

Cada problema podría necesitar una respuesta diferente.

Por ejemplo:

- venda para sangrado;
- antídoto para veneno;
- magia para maldiciones;
- inmovilización para fracturas.

### Posible aporte

Hace que observar el campo de batalla sea tan importante como reaccionar rápidamente.

---

## 4.3. Estabilizar vs. curar

El jugador podría disponer de dos grandes tipos de intervención.

### Estabilizar

Acción rápida y relativamente barata.

Evita que una unidad empeore o muera durante algunos segundos.

### Curar

Acción más costosa que recupera una cantidad significativa de vida.

### Posible aporte

Permite elegir entre:

- solucionar inmediatamente un problema;
- ganar tiempo;
- reservar recursos para otro soldado.

---

## 4.4. Soldados derribados

Cuando una unidad llega a cero de vida podría no morir inmediatamente.

En cambio, entra en estado:

**Derribado**

Durante algunos segundos permanece en el campo.

Si el healer consigue llegar hasta ella puede:

- estabilizarla;
- revivirla;
- arrastrarla;
- utilizar una habilidad especial.

Si el temporizador termina, la unidad muere definitivamente.

### Posible aporte

Genera pequeñas emergencias dentro del combate.

---

## 4.5. Línea de batalla dinámica

El frente podría desplazarse lateralmente.

Conceptualmente:

```text
BASE ALIADA ← Retirada — Ejército aliado ⚔ Ejército enemigo — Avance → BASE ENEMIGA
```

Si el ejército aliado pierde unidades:

```text
⚔ ← ← ←
```

El enemigo empuja hacia la base aliada.

Si el jugador consigue recuperar soldados importantes:

```text
→ → ⚔
```

El ejército vuelve a ganar terreno.

### Posible aporte

La curación deja de afectar únicamente barras de vida.

Las decisiones del healer modifican físicamente la posición de la batalla.

---

## 4.6. Amenaza generada por curación

Los enemigos podrían reconocer que el healer es una unidad estratégica.

Algunas acciones podrían generar amenaza.

Ejemplos:

- curaciones grandes;
- resurrecciones;
- habilidades de área;
- buffs poderosos.

Esto podría provocar que determinadas unidades enemigas intenten alcanzar al healer.

Ejemplos:

- asesinos;
- arqueros;
- unidades voladoras;
- magos;
- cargas de caballería.

### Posible aporte

Evita que el jugador permanezca siempre en una zona completamente segura.

---

## 4.7. Recursos médicos limitados

El healer puede utilizar recursos finitos.

Ejemplos:

- mana;
- vendas;
- pociones;
- medicamentos;
- cargas;
- energía;
- sangre;
- stamina.

La recuperación de estos recursos puede ser limitada durante cada oleada.

### Posible aporte

Obliga al jugador a pensar antes de utilizar una curación.

---

## 4.8. Overhealing

Curar por encima de la vida máxima podría considerarse un desperdicio.

Ejemplo:

Una habilidad cura 50 HP.

El soldado solamente necesita recuperar 10 HP.

Los 40 HP restantes se pierden.

También podrían existir builds que transformen el overhealing en:

- escudo;
- regeneración;
- armadura temporal;
- energía;
- resistencia.

### Posible aporte

Introduce eficiencia y optimización.

---

## 4.9. Curaciones canalizadas

Las habilidades más fuertes podrían necesitar tiempo.

Ejemplo:

El healer debe permanecer durante dos segundos cerca del objetivo.

Durante ese tiempo:

- puede recibir daño;
- puede ser interrumpido;
- puede necesitar permanecer quieto;
- puede tener que proteger al paciente.

### Posible aporte

Curar deja de ser únicamente presionar un botón.

---

## 4.10. Rescate de heridos

El jugador podría sacar físicamente a soldados de situaciones peligrosas.

Ejemplos:

- arrastrarlos;
- cargarlos;
- teletransportarlos;
- empujarlos fuera del combate;
- utilizar una camilla;
- pedir ayuda a otra unidad.

### Posible aporte

Genera pequeñas misiones emergentes dentro de la batalla.

Ejemplo:

1. entrar en la línea enemiga;
2. alcanzar a un veterano derribado;
3. estabilizarlo;
4. retirarlo;
5. escapar antes de ser rodeado.

---

## 4.11. Buffs tácticos

El healer puede funcionar también como support.

Posibles buffs:

- armadura;
- velocidad;
- daño;
- resistencia;
- regeneración;
- moral;
- inmunidad;
- velocidad de ataque.

### Posible aporte

Permite que el jugador influya en la batalla incluso cuando nadie necesita una curación urgente.

---

## 4.12. Moral del ejército

El ejército podría tener un valor global de moral.

La moral puede disminuir cuando:

- mueren aliados;
- cae un veterano;
- retrocede demasiado la línea;
- aparece un enemigo peligroso.

La moral puede aumentar cuando:

- se revive una unidad;
- se gana terreno;
- se salva un capitán;
- se derrota un enemigo importante.

La moral podría modificar:

- daño;
- velocidad;
- resistencia;
- probabilidad de retirada.

### Posible aporte

Las acciones individuales del healer afectan al comportamiento colectivo del ejército.

---

## 4.13. Soldados persistentes

Algunas unidades podrían sobrevivir entre oleadas.

Con el tiempo pueden adquirir:

- experiencia;
- nombres;
- niveles;
- traits;
- cicatrices;
- equipamiento;
- estadísticas;
- relaciones;
- especializaciones.

Ejemplo:

```text
Roland
Caballero — Nivel 7

Batallas sobrevividas: 12

Traits:
- Protector
- Pierna lesionada
```

Si Roland cae en combate, el jugador puede tener razones emocionales y mecánicas para intentar salvarlo.

### Posible aporte

Genera narrativa emergente sin requerir una historia completamente escrita.

---

## 4.14. Curación prohibida

Algunas habilidades podrían ofrecer resultados extraordinarios a cambio de consecuencias.

Ejemplos:

- sacrificar vida propia;
- sacrificar otra unidad;
- generar corrupción;
- provocar una herida permanente;
- aumentar dificultad futura;
- invocar algo peligroso;
- aplicar una deuda de vida.

### Posible aporte

Introduce decisiones de riesgo/recompensa.

---

## 4.15. Combos de tratamiento

Determinadas acciones realizadas en cierto orden pueden producir beneficios adicionales.

Ejemplo:

```text
Limpiar estado
      ↓
Curar
      ↓
Buff
      ↓
Regeneración temporal
```

Otra posibilidad:

```text
Estabilizar
      ↓
Revivir
      ↓
Inmunidad temporal
```

### Posible aporte

Aumenta la profundidad del sistema sin necesariamente agregar muchos botones.

---

# 5. Soldados con valor individual

Una dirección especialmente interesante sería conseguir que algunas unidades dejen de sentirse descartables.

Un soldado que sobrevivió muchas batallas puede convertirse espontáneamente en alguien importante para el jugador.

Ejemplo:

> "Este arquero está conmigo desde la primera oleada."

El juego podría generar estas historias sin necesidad de imponerlas mediante narrativa tradicional.

Esto también crea decisiones interesantes.

Desde un punto de vista puramente matemático podría ser mejor salvar tres soldados comunes.

Pero el jugador quizá decida salvar al veterano que lleva diez batallas sobreviviendo.

Ese conflicto entre:

- eficiencia;
- estrategia;
- apego;

puede convertirse en una parte importante de la experiencia.

---

# 6. Diferentes tipos de healer

La progresión podría evitar una estructura demasiado lineal del estilo:

```text
Heal I
↓
Heal II
↓
Heal III
↓
Heal IV
```

En su lugar podrían existir diferentes filosofías de healer.

---

## 6.1. Médico de combate

Especializado en:

- estabilización;
- vendas;
- rescate;
- tratamiento rápido;
- revive.

Puede tener muchas herramientas pero curaciones menos explosivas.

---

## 6.2. Clérigo

Especializado en:

- curaciones mágicas;
- escudos;
- regeneración;
- buffs;
- curaciones de área.

Puede depender fuertemente del mana.

---

## 6.3. Alquimista / médico de guerra

Utiliza:

- drogas;
- estimulantes;
- pociones;
- antídotos;
- mejoras temporales.

Sus habilidades podrían tener efectos secundarios.

Ejemplo:

```text
+50% velocidad de ataque
-20% defensa durante 10 segundos
```

---

## 6.4. Healer de sangre

Utiliza:

- vida propia;
- sacrificios;
- corrupción;
- transferencia de vida.

Puede conseguir curaciones extremadamente fuertes a cambio de riesgos importantes.

---

## 6.5. Support táctico

Especializado en mejorar el funcionamiento del ejército.

Puede utilizar:

- buffs;
- debuffs;
- protección;
- control de masas;
- repositioning.

Su gameplay puede estar menos orientado a curar HP directamente.

---

# 7. Una posible identidad para el juego

Una dirección conceptual interesante sería alejar el diseño de:

> "Juego donde curamos barras de vida."

y acercarlo a:

> "Médico de guerra fantástico dentro de una batalla que no controlamos completamente."

Esto permite que el caos sea parte de la experiencia.

El jugador observa un sistema vivo donde constantemente aparecen problemas que debe interpretar.

---

# 8. Posible prototipo inicial

No sería necesario implementar todas las mecánicas al mismo tiempo.

Un primer prototipo podría limitarse a:

1. NPC aliados automáticos.
2. NPC enemigos automáticos.
3. Movimiento lateral.
4. Combate automático.
5. Línea de frente dinámica.
6. Healer controlable.
7. Recurso de mana limitado.
8. Una curación básica.
9. Un estado negativo.
10. Estado derribado.
11. Revivir.

El objetivo de este prototipo sería responder una pregunta:

> ¿Es divertido observar una batalla caótica, identificar quién necesita ayuda y desplazarse por el escenario intentando mantener vivo al ejército?

Si este núcleo funciona, se podrían agregar gradualmente:

- loot;
- builds;
- clases;
- reliquias;
- veteranos;
- heridas;
- bosses;
- talentos;
- corrupción;
- meta-progresión;
- nuevas unidades.

---

# 9. Posibles pilares de diseño

Estos pilares no son definitivos, pero pueden servir como orientación inicial.

## Priorización

El jugador nunca debería poder solucionar todos los problemas al mismo tiempo.

## Caos legible

El campo puede ser caótico, pero el jugador debe poder comprender rápidamente qué está ocurriendo.

## Decisiones antes que spam

Las curaciones deberían implicar decisiones y no simplemente utilizar habilidades constantemente.

## Consecuencias visibles

Las acciones del healer deberían modificar el resultado de la batalla de manera evidente.

## Historias emergentes

Los soldados sobrevivientes pueden generar pequeñas historias propias.

## Especialización

Diferentes builds deberían cambiar la manera en que el jugador interpreta los problemas del campo.

---

# 10. Preguntas abiertas

Antes de convertir estas ideas en sistemas definitivos convendría explorar varias preguntas.

### Control del personaje

- ¿El healer se mueve libremente?
- ¿Se controla con teclado/gamepad?
- ¿Se utilizan clicks sobre unidades?
- ¿Las habilidades requieren apuntar?

### Escala de batalla

- ¿10 vs. 10?
- ¿30 vs. 30?
- ¿100 unidades simultáneas?

### Persistencia

- ¿Los soldados sobreviven entre niveles?
- ¿Solamente sobreviven los especiales?
- ¿Las unidades son completamente descartables?

### Recursos

- ¿Mana?
- ¿Pociones?
- ¿Cooldowns?
- ¿Una combinación de varios sistemas?

### Duración

- ¿Oleadas de 30 segundos?
- ¿Batallas de varios minutos?
- ¿Niveles completos divididos en diferentes frentes?

### Rol del healer

- ¿Puede atacar?
- ¿Debe permanecer completamente indefenso?
- ¿Puede defenderse solamente?
- ¿Puede elegir builds ofensivas?

### Derrota

- ¿Se pierde cuando muere el healer?
- ¿Cuando cae la base?
- ¿Cuando el ejército es eliminado?
- ¿Cuando la línea de batalla alcanza cierto punto?

---

# 11. Filosofía del documento

Este documento no pretende cerrar el diseño.

Su función es servir como una **caja de herramientas inicial**.

A medida que se desarrollen prototipos, cada sistema debería poder clasificarse como:

```text
[ ] Idea
[ ] Investigar
[ ] Prototipar
[ ] Funciona
[ ] Modificar
[ ] Descartar
[ ] Confirmado
```

El objetivo debería ser descubrir progresivamente cuáles de estas ideas generan realmente una experiencia divertida y cuáles solamente parecen interesantes sobre el papel.

---

# 12. Dirección sugerida para continuar

Una posible secuencia de trabajo sería:

```text
Concepto
   ↓
Core Loop
   ↓
Movimiento del healer
   ↓
Combate automático de NPC
   ↓
Sistema básico de curación
   ↓
Derribados y revive
   ↓
Movimiento de la línea de batalla
   ↓
Prototipo jugable
   ↓
Evaluación
   ↓
Nuevas mecánicas
```

La intención es mantener inicialmente el juego pequeño y entendible.

Las mecánicas más complejas pueden incorporarse solamente después de comprobar que el núcleo —**moverse, observar, priorizar y salvar unidades dentro de una batalla automática**— resulta divertido.
