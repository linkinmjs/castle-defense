# Castle Defense

Sos un **médico de guerra** en un beat-em-up 2.5D: dos ejércitos automáticos
empujan una línea de frente por un campo largo y vos, solo o con otro jugador
en la misma pantalla, no atacás: curás. Tres botones (curación ligera, curación
pesada y salto) y el orden en que los apretás deciden qué sale; dónde te parás
decide a quién le llega. Se gana leyendo mejor qué intervención cambia el
destino del frente: a quién curar, a quién vendar, a quién levantar del suelo y
a quién dejar ir.

Desarrollado con **Godot 4.7** (renderer GL Compatibility, para que corra en
navegador). Cada push a `master` exporta el juego a HTML5 y lo publica
automáticamente en itch.io.

El diseño está en [`godot/docs/`](godot/docs/): qué sale con cada botón en
[`movimientos_y_combos.md`](godot/docs/movimientos_y_combos.md), los niveles en
[`niveles.md`](godot/docs/niveles.md), y el documento que ordena las
prioridades de diseño es
[`mejoras_desde_a_theory_of_fun.md`](godot/docs/mejoras_desde_a_theory_of_fun.md).

## Estructura del repositorio

```
.
├── .github/workflows/     # Pipeline de export + deploy a itch.io
├── builds/                # Salida de los exports (ignorada por git)
└── godot/                 # El proyecto de Godot (abrir esta carpeta en el editor)
    ├── assets/            # sprites, fondos, efectos, fuente y UI (generados desde _raw/)
    ├── docs/              # diseño: qué es el juego y hacia dónde va
    ├── resources/         # encuentros, tipos de soldado y movimientos (.tres)
    ├── scenes/            # menu_principal.tscn es la escena principal; battle3d.tscn la batalla
    ├── scripts/           # scripts de GDScript
    └── tools/             # pruebas headless, capturas y generadores de recursos
```

## Cómo está armado

- **Movimientos y combos** (`scripts/movimientos/`): cada movimiento es un
  `Resource` sin estado (`Movimiento`) y `ComponenteCombos`, hijo del healer,
  recuerda qué botones conectaron y resuelve qué sale (`Toque`, `Vendaje`,
  `Oleada`, `Bendicion`, `Plegaria`, `Reanimar`, `Impulso`, `Caida sanadora`).
  `Apuntado` elige a quién le llega según la caja que el healer tiene enfrente.
- **Dos jugadores** (`scripts/jugadores.gd`, `scripts/3d/camara_batalla.gd`):
  cada healer lee sólo las acciones de su jugador (`p1_*`, `p2_*`); el segundo
  entra desde el menú o apretando cualquiera de sus botones en plena batalla.
  La cámara sigue el punto medio y ninguno se sale de cuadro.
- **Encuentros y sectores** (`scripts/encuentros/`): un `Encuentro` define
  quiénes entran al campo, qué movimientos hay, cómo se gana y con qué semilla;
  un nivel largo se parte en `Sector`es que frenan el avance hasta que se
  liberan. `resources/encuentros/campana.tres` son las tres lecciones y
  `niveles.tres` los tres niveles.
- **Soldados** (`scripts/3d/unidad3d.gd`, `resources/soldados/`): escudero,
  lancero, espadachín y zombi, más el **bruto** (golpe lento anunciado en el
  suelo, se esquiva saltando) y el **demonio** (jefe con dos ataques en área).
- **Presentación** (`scripts/3d/mundo.gd`, `scripts/3d/particulas.gd`,
  `scripts/3d/numero_flotante.gd`, `scripts/ui/vineta.gd`,
  `scripts/presentacion.gd`): el mundo del atardecer, las partículas, los
  números flotantes, la viñeta de daño, el hit-stop y la sacudida de cámara. Todo
  lo que no cambia el juego se apaga en headless para que las pruebas sigan
  deterministas.
- **HUD** (`scripts/hud.gd`, `scripts/hud/`): una ficha por jugador, barra de
  nivel con los sectores, cartel de avanzar, barra de jefe y resumen.

Todo el contenido lo generan scripts en `tools/` (`gen_encuentros.gd`,
`gen_movimientos.gd`, `gen_scenes3d.gd`...), así que se lee de corrido en un
archivo en vez de estar repartido por el inspector.

### Controles

Sin mouse: tres botones y el movimiento, para uno o dos jugadores.

| | Teclado P1 | Teclado P2 | Joystick (el 1.º es P1, el 2.º es P2) |
|---|---|---|---|
| Mover | `WASD` | Flechas | Stick izquierdo y cruceta |
| Ligera | `J` | `,` (y `Num 1`) | `X` |
| Pesada | `K` | `.` (y `Num 2`) | `Y` |
| Saltar | `Espacio` | `/` (y `Num 0`) | `A` |
| Pausa | `Esc` | | `Start` (cualquier pad) |
| Seguir al terminar | `Enter` | | `Start` (cualquier pad) |
| Repetir el encuentro | `R` | | `Back` (cualquier pad) |

Nadie apunta: la ligera le llega al aliado que el healer tiene enfrente (primero
al que sangra, después al más golpeado) y la pesada a todos los de una caja más
grande. Qué sale con cada botón depende de lo que vino antes: `L` Toque, `L L`
Vendaje (corta el sangrado), `P` Plegaria, `L P` Bendición, `L L P` Oleada, `P`
con un caído adelante Reanimar, y en el aire `L` Impulso y `P` Caída sanadora.
La tabla completa está en `tools/gen_movimientos.gd`.

Las acciones son `p1_*` y `p2_*` (ver `scripts/jugadores.gd`); cada joystick se
asigna a su jugador al armar la batalla y cada vez que se conecta uno.

## Artefactos generados

Las escenas, el tema y los recursos **no se editan a mano**: los produce un
script de `tools/` y el editor los pisa en la proxima corrida. Si hay que
cambiar algo, se cambia en el generador.

| Script | Que produce |
|---|---|
| `extraer_ui.gd` | `assets/ui/` desde los packs de `assets/_raw/`, escalado x2 |
| `extraer_sprites.gd` | `assets/sprites/` desde los packs: hojas de personajes con el contorno de su bando horneado, y los efectos |
| `gen_fondos.gd` | `assets/fondos/`: cielo, siluetas parallax, suelo, camino, muro y porton, dibujados por codigo |
| `gen_ui.gd` | `resources/ui/tema.tres` y las escenas de menu |
| `gen_movimientos.gd` | `resources/movimientos/*.tres`: los movimientos del healer y sus combos |
| `gen_hud.gd` | `scenes/ui/hud.tscn`, el HUD de la batalla (usa el tema) |
| `gen_scenes3d.gd` | escenas 3D (la batalla instancia el HUD ya generado y el healer trae los movimientos) y tipos de soldado |
| `gen_encuentros.gd` | los encuentros y la campania |
| `gen_frames.gd` | los `SpriteFrames` de cada personaje (healer, tropa, bruto, demonio) y de los efectos |
| `setup_input.gd` | en `project.godot`: el Input Map entero (acciones por jugador y compartidas), los nombres de las capas 3D y la importacion por defecto de texturas |

El orden importa cuando se tocan los assets de interfaz, porque un PNG escrito
por un script no se puede cargar hasta que Godot lo importe:

```bash
godot --headless --path godot --script res://tools/extraer_ui.gd
godot --headless --path godot --script res://tools/extraer_sprites.gd
godot --headless --path godot --script res://tools/gen_fondos.gd
godot --headless --path godot --import
godot --headless --path godot --script res://tools/gen_ui.gd
godot --headless --path godot --script res://tools/gen_movimientos.gd
godot --headless --path godot --script res://tools/gen_hud.gd
godot --headless --path godot --script res://tools/gen_scenes3d.gd
godot --headless --path godot --script res://tools/gen_encuentros.gd
godot --headless --path godot --script res://tools/setup_input.gd
```

La interfaz usa un pack gratuito de CraftPix; la atribucion y la licencia estan
en [`godot/assets/ui/LEEME.md`](godot/assets/ui/LEEME.md).

## Requisitos

- [Godot 4.7](https://godotengine.org/download) (versión estándar, sin C#).
- **Export templates de 4.7** instaladas: `Editor > Manage Export Templates... > Download and Install`.
  Sin esto no se puede exportar a Web desde la máquina local (el CI las descarga por su cuenta).

## Desarrollo local

1. Abrir Godot y elegir **Import** apuntando a la carpeta `godot/`.
2. `F5` abre el menu principal (`scenes/ui/menu_principal.tscn`). Para entrar
   directo a una batalla, `F6` sobre `scenes/3d/battle3d.tscn`.

### Pruebas

Son scripts headless sin dependencias externas: cada uno corre la parte del
juego que le toca y termina con código de error si algo falla. Las corre el CI
antes de exportar, y una a una:

```bash
godot --headless --path godot --script res://tools/test_encuentro.gd
```

Están todas en `godot/tools/test_*.gd` (las nuevas extienden `tools/prueba_base.gd`,
que trae los helpers y el avance por ticks de física). El modelo de combate se
prueba sin interfaz; el HUD y el menú tienen sus propias suites. Todo lo que es
puro dibujo (partículas, números, sacudidas) se apaga en headless, así que los
resultados son deterministas.

Lo que no se puede medir sin pantalla se mira: los `tools/captura_*.gd` sacan
fotos de la batalla, el HUD, el mundo, los combos, el bruto y los niveles. Van
**sin** `--headless` y guardan PNG en la carpeta de usuario de Godot
(`%APPDATA%\Godot\app_userdata\castle-defense\`):

```bash
godot --path godot --script res://tools/captura_hud.gd
godot --path godot --resolution 1920x1080 --script res://tools/captura_mundo.gd
```

### Exportar a Web localmente

```bash
godot --headless --path godot --export-release "Web" ../builds/web/index.html
```

El export web **no se puede abrir con doble clic** (`file://` no funciona). Para probarlo:

```bash
python -m http.server 8000 --directory builds/web
```

y abrir <http://localhost:8000>.

## Publicación automática en itch.io

El workflow [`deploy-to-itch.yml`](.github/workflows/deploy-to-itch.yml) hace:

1. En **pull requests a `master`**: exporta el juego para validar que compila (no publica).
2. En **push a `master`**: exporta, sube el build como artefacto de la Action y lo publica en itch.io con `butler` (canal `web`).

### Configuración inicial (una sola vez)

#### Paso 1

Crear el proyecto en itch

   <img height="300" alt="image" src="https://github.com/user-attachments/assets/289a1dd2-72b3-40af-b76a-81bef6d9212f" />

#### Paso 2

Ponerle un título al juego, y configurar el **Kind of project** como HTML

   <img height="600" alt="image" src="https://github.com/user-attachments/assets/12ba7e65-e05a-4106-a8f0-69ce8415a851" />

#### Paso 3

Clickear Save & view page

   <img width="631" height="190" alt="image" src="https://github.com/user-attachments/assets/bea9ca55-ddf6-4043-87b3-78b079718dac" />

#### Paso 4

Configurar los siguientes secretos en el repositorio (Settings > Secrets and Variables > Actions):

   - `BUTLER_API_KEY` -> se obtiene en https://itch.io/user/settings/api-keys
   - `ITCHIO_GAME` -> el nombre del juego en itch (el que aparece en la URL)
   - `ITCHIO_USERNAME` -> el usuario de itch

#### Paso 5

Hacer un commit y un push a `master`, eso dispara la acción que exporta el juego y lo sube a itch:

<img width="1910" height="369" alt="image" src="https://github.com/user-attachments/assets/06312139-8854-4d35-8670-552dda17ff6c" />

#### Paso 6

Tras subirlo por primera vez, volver a itch y marcar la opción **This file will be played in the browser**. Luego guardar de nuevo.

<img width="627" height="410" alt="image" src="https://github.com/user-attachments/assets/0c5c671d-248e-457c-963e-9144a240f687" />

### Listo

Cada push a `master` actualiza el juego en itch automáticamente.

## Actualizar la versión de Godot

Al pasar a una versión nueva del motor hay que tocar dos lugares:

1. `godot/project.godot` -> `config/features` (lo actualiza el propio editor al abrir el proyecto).
2. `.github/workflows/deploy-to-itch.yml` -> la variable `GODOT_VERSION`.

Si las dos versiones no coinciden, el build del CI puede fallar o comportarse distinto que en local.
