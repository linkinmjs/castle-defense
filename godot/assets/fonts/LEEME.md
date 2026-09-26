# Fuente de la interfaz

`ui.ttf` es **Pixelify Sans** (variable, eje de peso), de los Pixelify Sans
Project Authors (https://github.com/eifetx/Pixelify-Sans), tomada del
repositorio de Google Fonts (`ofl/pixelifysans`). Licencia **SIL Open Font
License 1.1**, copiada en `OFL.txt`: permite usarla, incluirla en un juego
comercial y redistribuirla, con la unica condicion de no venderla suelta y de
conservar el aviso de copyright. Cubre acentos, la enie y los signos de
apertura del espanol.

Antes se habia probado `Planes_ValMore.ttf`, que viene dentro de los packs de
CraftPix: su EULA interno reserva el uso comercial a quien compre la fuente,
asi que no se usa.

`gen_ui.gd` la toma automaticamente al generar el tema (`resources/ui/tema.tres`)
si el archivo existe. El `.import` la deja sin antialiasing ni hinting para que
se vea nitida como pixel art; los tamanos mas limpios son multiplos de su
cuerpo base.
