# Sprites de personajes y efectos

Derivados de packs gratuitos de [CraftPix](https://craftpix.net/freebies/) por
`tools/extraer_sprites.gd`. Los originales estan en `assets/_raw/` y no se tocan.

A las hojas de personaje se les hornea un contorno de 1 px del color de su lado
(aliados azul, enemigos rojo, jugador 1 dorado, jugador 2 turquesa). Las de
`bruto/` y `demonio/` ademas se espejan cuadro por cuadro para que miren a la
derecha, como el resto. Los efectos de `fx/` se copian tal cual.

| Pack | Id | Hojas |
|---|---|---|
| Pixel Prototype Medieval Character Sprites Pack 5 | 689963 | `soldier/` (idle, walk, run, attack, hurt, dead) |
| Pixel Art Prototype Medieval Character Pack 6 | 852737 | `lancero/` (idle, walk, run, attack, hurt, dead) |
| Prototype Saber Fighter Pixel Sprite Sheet | 949015 | `espadachin/` (idle, walk, run, attack, hurt, dead) |
| Prototype Zombie Sprite Sheet Pixel Art Pack | 834564 | `enemy/` (idle, walk, run, attack, hurt, dead) |
| Free Necromancer Pixel Art Prototype Character Sprites | 573981 | `healer/` (idle), `healer2/` (idle) |
| Free Pixel Art Prototype Character Sprites | 405285 | `healer/` (walk, run, jump, fall, land), `healer2/` (walk, run, jump, fall, land) |
| Prototype Pixel Hero Free Sprite Pack 3 | 196564 | `healer/` (hurt, dead, cast, healing, power_boost, resurrection, magic_shield, energy_wave, aerial_strike), `healer2/` (hurt, dead, cast, healing, power_boost, resurrection, magic_shield, energy_wave, aerial_strike) |
| Tiny Monsters Pixel Art Pack | 987745 | `bruto/` (idle, walk, attack, hurt, dead) |
| Boss Monsters Pixel Art | 897123 | `demonio/` (idle, walk, run, attack, attack2, hurt, dead, sneer) |
| 10 Magic Sprite Sheet Effects Pixel Art | 671189 | `fx/` (heal, shield, toque, plegaria, bendicion, oleada, impulso) |
| Magic Pixel Art Sprite for Prototype | 572720 | `fx/` (caida, reanimar) |

La licencia de los packs gratuitos esta en https://craftpix.net/file-licenses/ .
Permite usarlos dentro de un juego, incluso comercial, pero no redistribuirlos
como assets sueltos. **Conviene releerla antes de publicar.**

Estos archivos se generan: no editarlos a mano. Para cambiar que se extrae o de
que color es el contorno, tocar `tools/extraer_sprites.gd`, volver a correrlo,
importar y correr `tools/gen_frames.gd`.
