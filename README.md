# TurboBros

Juego de karts arcade 3D low poly para Windows (Godot 4, GDScript, renderizador Compatibility).
Hasta 8 jugadores locales con mandos USB/Bluetooth. Licencia del código: MIT (ver `LICENSE`).

> Repositorio público: nunca subir tokens, claves ni datos personales. Assets de terceros: registrar en `CREDITS.md`.

## Ejecutar
1. Abrir la carpeta con Godot 4.7 (`project.godot`) y pulsar F5.
2. Controles del hito 1:
   - **Mando**: stick izq. girar · RT/A acelerar · LT/B frenar · LB/RB derrapar (pulsar con el stick inclinado).
   - **Teclado (solo desarrollo)**: WASD, Shift = derrape, R = reiniciar.

## Pantalla dividida (hito 2)
- **F1–F4**: número de karts (1 a 4). 2 = arriba/abajo, 3–4 = cuadrícula 2×2.
- **[ y ]**: escala de render por vista (0.25–1.0). Con ventana 1280×720 y 4 vistas a escala 1.0 son ≈0.91 M píxeles internos.
- Asignación provisional de dispositivos por orden: mandos conectados, luego teclado J1 (WASD + Shift) y J2 (flechas + L). Karts sin dispositivo quedan inactivos. El lobby llega en el hito 3.
- Cada kart tiene su `SubViewport` (mismo mundo 3D) con su cámara y se dibuja en un `TextureRect`.

## Autotest sin interfaz
```powershell
Godot_console.exe --headless --path . res://scenes/debug/selftest.tscn
```
Devuelve código 0 si pasan aceleración, derrape (niveles 1-3 + turbo), rampa con mini turbo de aterrizaje, frenado y versión.

## Estructura
| Carpeta | Contenido |
|---------|-----------|
| `scripts/input` | `KartControls`, `Seat` (rol SOLO/DRIVER/GUNNER), `KartController` (humano, bots, red) |
| `scripts/autoload` | `GameVersion` (lee `VERSION`), `InputManager` (mandos/teclado → controles) |
| `scripts/kart` | `Kart` (física esfera arcade, derrape, mini turbos), `ChaseCamera` |
| `scripts/data` + `data/` | Recursos `.tres`: `KartStats`, `CharacterData` (color del 3.er turbo) |
| `scenes/tracks` | Pista de prueba con rampas |

## Versionado
El único archivo de versión es `VERSION` (semver). Releases con etiqueta `vX.Y.Z` (hito 7: GitHub Actions + actualizador).

## Medición de rendimiento
Tras cada hito, anotar FPS en `docs/PERFORMANCE.md`.
