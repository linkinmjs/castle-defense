# Castle Defense

Sos un **médico de guerra** dentro de una batalla 2.5D que no controlás. Dos
ejércitos automáticos empujan una línea de frente; vos no atacás y podés morir.
Se gana leyendo mejor qué intervención cambia el destino del frente: a quién
curar, a quién estabilizar, a quién levantar del suelo y a quién dejar ir.

Desarrollado con **Godot 4.7** (renderer GL Compatibility, para que corra en
navegador). Cada push a `master` exporta el juego a HTML5 y lo publica
automáticamente en itch.io.

El diseño y hacia dónde va están en [`godot/docs/`](godot/docs/); el documento
que ordena las prioridades es
[`mejoras_desde_a_theory_of_fun.md`](godot/docs/mejoras_desde_a_theory_of_fun.md).

## Estructura del repositorio

```
.
├── .github/workflows/     # Pipeline de export + deploy a itch.io
├── builds/                # Salida de los exports (ignorada por git)
└── godot/                 # El proyecto de Godot (abrir esta carpeta en el editor)
    ├── assets/            # sprites, audio, fonts
    ├── docs/              # diseño: qué es el juego y hacia dónde va
    ├── resources/         # encuentros, tipos de soldado y movimientos (.tres)
    ├── scenes/            # battle3d.tscn es la escena principal
    ├── scripts/           # scripts de GDScript
    └── tools/             # pruebas headless y generadores de recursos
```

## Cómo está armado

La partida se juega por **encuentros**. Cada uno es un `Resource` que define
quiénes entran al campo y en qué estado, qué movimientos tiene disponibles el
healer, cuándo termina y con qué semilla se despliega. Eso permite enseñar una
cosa por vez y repetir exactamente el mismo problema entre intentos.

- `resources/encuentros/campana.tres` — la serie que se juega, en orden.
- `resources/soldados/` — los tipos de soldado (stats, sprites, estilo).
- `resources/movimientos/` — los movimientos del healer y sus combos.

Todo eso lo generan scripts en `tools/` (`gen_encuentros.gd`,
`gen_movimientos.gd`, `gen_scenes3d.gd`), así que el contenido se lee de corrido
en un archivo en vez de estar repartido por el inspector.

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
| `gen_frames.gd` | los `SpriteFrames` de cada personaje |
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

Están todas en `godot/tools/test_*.gd`. Ninguna instancia el HUD para medir: el
modelo de combate tiene que poder probarse sin interfaz.

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
