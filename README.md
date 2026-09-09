# Castle Defense

Juego 2D de defensa de castillo, desarrollado con **Godot 4.7** (renderer GL Compatibility, para que corra en navegador).

Cada push a `master` exporta el juego a HTML5 y lo publica automáticamente en itch.io.

## Estructura del repositorio

```
.
├── .github/workflows/     # Pipeline de export + deploy a itch.io
├── builds/                # Salida de los exports (ignorada por git)
└── godot/                 # El proyecto de Godot (abrir esta carpeta en el editor)
    ├── assets/            # sprites, audio, fonts
    ├── autoload/          # singletons (Project Settings > Globals)
    ├── scenes/            # escenas de gameplay (main.tscn es la escena principal)
    ├── scripts/           # scripts de GDScript
    └── ui/                # menús y HUD
```

## Requisitos

- [Godot 4.7](https://godotengine.org/download) (versión estándar, sin C#).
- **Export templates de 4.7** instaladas: `Editor > Manage Export Templates... > Download and Install`.
  Sin esto no se puede exportar a Web desde la máquina local (el CI las descarga por su cuenta).

## Desarrollo local

1. Abrir Godot y elegir **Import** apuntando a la carpeta `godot/`.
2. `F5` corre la escena principal (`scenes/main.tscn`).

Configuración base ya incluida en `project.godot`:

- Resolución base **1280x720**, stretch `canvas_items` / `expand` (escala a cualquier ventana).
- Acciones de input: `move_left`, `move_right`, `move_up`, `move_down`, `select`, `cancel`, `pause`.
- Capas de física 2D nombradas: `world`, `player`, `enemies`, `projectiles`, `buildings`.

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
