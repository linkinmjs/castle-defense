# Fondos del campo de batalla

Generados por `tools/gen_fondos.gd`: todo procedural, con semillas fijas.
**No editarlos a mano**: se cambia el generador y se vuelve a correr (ver el
encabezado del script). La vista previa con la camara de la batalla queda en
`user://fondos_preview.png`.

| Archivo | Tamano | Que es |
|---|---|---|
| `cielo.png` | 16x512 | Atardecer en 23 bandas planas (1b1a3a, 4a3560, c9694a) y abajo el resplandor e8a05a, macizo en el ultimo 15%: en pantalla solo asoma su filo en los valles. Se estira. |
| `montanas.png` | 1024x256 | Cordillera lejana 4c3f6b de picos suaves y, delante, un faldeo mas bajo y mas claro 5a4c7c: el aire entre las dos filas. Empalma en X. |
| `castillo.png` | 1024x256 | Castillo enemigo 352a4f en el centro de la repeticion (torreon, cuatro torres, muralla con almenas) con ventanas e8a05a, sobre una loma corrida. Empalma en X. |
| `arboles.png` | 1024x192 | Linea de pinos y copas redondas: fila de atras 241d3d, fila de adelante y monte bajo 1c1730. Empalma en X. |
| `suelo.png` | 128x128 | Pasto pisoteado (3f5a3a, 365033, 4a6a44) con manchas de tierra (6b5138, 5a432f) y alguna piedra 7d7a6e. Empalma en X y en Y. |
| `camino.png` | 128x64 | Tierra apisonada con dos huellas de carro y bordes de pasto. Empalma en X. |
| `muro.png` | 96x192 | Segmento de muralla de sillares con almenas, de frente (5a4c7c, 3d3358, 2a2340). Empalma en X. |
| `porton.png` | 128x192 | Porton en arco con puerta de tablones (6b4a2a, 4a321f) y herrajes 3a3a44 entre dos torrecitas. |

Las siluetas tienen alpha 0 o 255 (nada intermedio), fila de arriba vacia y
fila de abajo llena. Ninguna capa pasa de 6 colores salvo el cielo.

## Como se cuelgan

Pensado para la camara de `battle3d.gd` (fov 42, a 11 m, picado de 15
grados) a 1280x720. Cada capa es un `QuadMesh` con `center_offset =
(0, alto/2, 0)`, asi el nodo queda en el borde de abajo:

- `rotation_degrees = (-15, 0, 0)`: paralelo al plano de la camara. Parado
  derecho, las torres se inclinan hacia los bordes de la pantalla y los
  texeles cambian de tamano de arriba abajo.
- Material: `shading_mode = UNSHADED`, `transparency = ALPHA_SCISSOR`,
  `texture_filter = NEAREST` (el default es lineal con mipmaps),
  `texture_repeat = true`, `uv1_scale = (240 / ancho, 1, 1)` para un quad
  de 240 m y `disable_fog = true`: la perspectiva aerea ya esta pintada, y
  con la niebla actual las montanas quedarian tres cuartos azul noche.
- `cast_shadow = OFF`: el sol viene de atras, y la silueta proyectaria una
  franja de sombra hacia el campo.

| Capa | z (m) | Borde de abajo en y (m) | Una repeticion (m) | uv1_scale.x en 240 m |
|---|---|---|---|---|
| `arboles.png` | -8 | -0.50 | 52.32 x 9.81 | 4.587 |
| `castillo.png` | -16 | -1.50 | 69.76 x 17.44 | 3.440 |
| `montanas.png` | -30 | -2.50 | 99.86 x 24.96 | 2.403 |

Con esas medidas cada texel ocupa 2 px de pantalla exactos a 720p (como un
texel de sprite a mitad del campo; a otra resolucion escala igual que los
sprites): al moverse la camara los texeles no cambian de ancho, solo se
corren de a un pixel. Cada repeticion es mas ancha que todo lo que la camara
barre en una batalla, asi que ninguna capa se ve dos veces. Las bases
negativas hunden el pie macizo de cada capa bajo el suelo: es lo que tapa
los claros entre los arboles.

El centro de cada textura (columna 512) cae en la x del mundo que se elija
con `uv1_offset.x = 0.5 - (X - borde_izquierdo_del_quad) / ancho` (tomar la
parte fraccionaria). En el castillo esa columna es el torreon: conviene
ponerlo detras del lado enemigo. Con el quad centrado en x = 15 y el
torreon en x = 22 da `uv1_offset.x = 0.679`.

Cielo: quad del mismo estilo en z = -60, con el borde de abajo en
y = -1.50 m y 15.0 m de alto (`uv1_scale = (1, 1, 1)`; es liso
en X). Asi el azul noche queda arriba, bajo el HUD, el naranja detras de los
picos, y el borde de abajo del quad pasa por debajo del valle mas hondo de
la cordillera: no hay rendija por donde se vea el fondo del Environment.
Alternativa sin geometria: `Environment.background_mode = BG_CANVAS` y el
PNG en un `TextureRect` estirado en una `CanvasLayer` con `layer = -1`.

Niebla (opcional, probada en el render Compatibility): con
`fog_mode = FOG_MODE_DEPTH`, `fog_light_color = 1c1730`,
`fog_depth_begin = 16`, `fog_depth_end = 26` y `fog_density = 0.85` el campo
queda limpio y el pasto de atras se oscurece hacia el tono del monte, que
borra la raya recta donde el suelo se mete bajo los arboles. Las capas no la
ven por `disable_fog`.

Suelo: `uv1_scale` = metros del plano x 34 / 128 (una repeticion cada
3.76 m): el pasto queda con el mismo texel que los sprites. Con el plano
actual de 66 x 30 m son `(17.53, 7.97, 1)`; si se quieren numeros redondos,
una repeticion cada 4 m (32 texeles/m, el tile de 32 px = 1 m) da
`(16.5, 7.5, 1)`. Con la luz actual (sol fff2d8 x1.1) el pasto renderiza
entre 1.6 y 2 veces su albedo en lineal: si para el atardecer se ve muy vivo,
conviene bajar o entibiar el sol antes que oscurecer la textura. El camino va
igual que el suelo: 34 texeles/m, o sea 3.76 x 1.88 m por repeticion.

Muro y porton: a 34 texeles/m miden 2.8 x 5.6 m y 3.8 x 5.6 m. Con la
camara actual, parado en el fondo del campo (z = 0) el borde de arriba de
la pantalla queda a ~5.5 m: el porton entra justo; mas adelante se corta.

## Origen y atribucion

No hay pixeles de terceros: todo sale del script. Se miro el pack
*Free Prototype 2D Platformer 32x32 Pixel Tileset* de
[CraftPix](https://craftpix.net/freebies/)
(`_raw/craftpix-net-141897-free-prototype-2d-platformer-32x32-pixel-tileset.zip`)
para piedra y almenas, pero es un tileset de prototipo: cada tile trae un
"32" impreso y los `BackTiles` son formas planas con rotulos de angulo. De
ahi se tomo solo la escala (modulo de 32 px: sillares de 16x8, almenas y
torres en multiplos de 4) y las pendientes de 45 y 27 grados de las laderas.
Licencia del pack: https://craftpix.net/file-licenses/
