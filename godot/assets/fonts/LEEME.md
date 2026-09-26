# Fuente de la interfaz

`ui.ttf` es **Planes_ValMore** ("Typeface (c) ValMore. 2019. All Rights
Reserved", version 1.00), copiada sin tocar un byte de
`_raw/craftpix-671189-10-magic-sprite-sheet-effects-pixel-art.zip`
(`Font/Planes_ValMore.ttf`; la misma viene en los packs 897123 y 987745).
La extrae `tools/gen_fondos.gd`, que tambien deja `ui.ttf.import` sin
antialiasing, sin hinting y sin posicion subpixel.

## Licencia: pendiente de verificar

- El zip no trae `Font.txt` ni licencia de la fuente: solo `License.txt` con
  la URL de CraftPix, https://craftpix.net/file-licenses/ .
- La fuente trae adentro (tabla `name`, campo de descripcion de licencia) un
  EULA de ValMore en ruso. Resumido: la licencia es para un usuario o
  empresa; la fuente sigue siendo de ValMore; se pueden hacer copias de
  respaldo pero **no modificarla** ni hacer fuentes derivadas; para usarla en
  un juego u otro software **no hace falta una licencia especial**; se puede
  usar en proyectos ilimitados; y el uso comercial es "despues de comprar la
  fuente". El contacto del autor esta en ese mismo campo.
- Lo que falta confirmar: si la licencia de CraftPix del pack gratuito cubre
  el uso comercial de una fuente de terceros que el EULA ata a una compra.
  Hasta entonces, tratarla como apta para el prototipo y revisarla antes de
  publicar.

## Uso

- La grilla de la fuente es de 68 unidades sobre 1000: un pixel de la fuente
  mide 0.068 em. Los tamanos nitidos son 15 (x1), 29 o 30 (x2) y 44 (x3); en
  16 o en 32 algunos pixeles salen dobles. Importada asi, los glifos salen
  sin un solo pixel de alpha intermedio.
- Glifos: ASCII menos `$ & ' < > ^ ~` y el acento grave, cirilico, comillas
  y rayas. **No trae acentos, ni ene, ni signos de apertura**: esos
  caracteres caen al fallback (en web, sin fuentes del sistema, se ven como
  cajitas). Hoy los usan el objetivo de e3 ("dano" con ene) y los botones
  "<" y ">" de `menu_principal.tscn` y `menu_pausa.tscn`: antes de aplicar
  la fuente a todo el tema hay que darles un fallback o cambiarlos.
