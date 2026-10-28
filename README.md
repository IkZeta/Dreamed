# Dreamed

Proyecto Godot 4.7 (probado en Godot 4.7.2). Abre `project.godot` y pulsa F5.
Godot 4.7 project (tested on Godot 4.7.2). Open `project.godot` and press F5.

## Flujo / Flow
Menú principal → Jugar → ¿Qué soñará hoy Kroker? → Sueño 1 en su habitación (se levanta de la cama; 30 s de Foox) → Sueño superado / Kroker se ha despertado

## Controles / Controls
WASD, flechas o stick izquierdo para moverse. Esc o Start para pausar. El arma ataca sola.

## Armas / Weapons (`scripts/game/weapon_*.gd`)
| Arma | Ataque | Bonificación |
|---|---|---|
| Bate | Golpe cuerpo a cuerpo al más cercano | +30 % de ataque |
| Escudo-almohada | Poco daño, gran empuje en cono | +3 de defensa |
| Libro | Rayo a distancia que salta a 3 enemigos | — |
| Aspiradora (Barrepesadillas) | Absorbe solo hacia el enemigo al que apunta: lo atrae y lo daña | +25 % de velocidad |

Los números (daño, alcance, enfriamiento) están como constantes al principio de cada archivo.
Las oleadas se definen en `GameState.WAVES` y las estadísticas base en `GameState.BASE_STATS`.

## Archivos / Files
- `scripts/autoload/` — textos ES/EN (`i18n.gd`), ajustes y controles (`settings.gd`), datos (`game_state.gd`)
- `scripts/ui/` — menú principal, ajustes, selección y tema visual
- `scripts/game/` — partida, habitación (`bedroom.gd`), Kroker, Foox, armas, HUD, efectos y pantallas de pausa/fin
- `scripts/visual/` — cielo estrellado y el dibujo de Kroker en pijama (provisional: sustituir por sprites)
- `assets/fonts/` — Lora y Poppins (SIL Open Font License)
