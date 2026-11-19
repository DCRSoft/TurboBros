# TurboBros

Juego de karts arcade 3D low poly para Windows (Godot 4, GDScript, renderizador Compatibility).
Hasta 8 jugadores locales con mandos USB/Bluetooth. Licencia del código: MIT (ver `LICENSE`).

> Repositorio público: nunca subir tokens, claves ni datos personales. Assets de terceros: registrar en `CREDITS.md`.

## Ejecutar
1. Abrir la carpeta con Godot 4.7 (`project.godot`) y pulsar F5.
2. Controles del hito 1:
   - **Mando**: stick izq. girar · RT/A acelerar · LT/B frenar · LB/RB derrapar (salto + derrape) (pulsar con el stick inclinado).
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

## Lobby y 2 jugadores por kart (hito 3)
El juego arranca en el lobby. Cada jugador se une pulsando su botón: **A** (mando), **Espacio** (teclado J1) o **K** (teclado J2).
- Reparto automático: 1=1, 2=1+1, 3=1+1+1, 4=1+1+1+1, 5=1+2+2, 6=2+2+2, 7=1+2+2+2, 8=2+2+2+2 (máx. 4 karts humanos, 2 asientos por kart).
- **Izq/Der** cambia de kart (máx. 2 por kart), **Y / E / ;** intercambia conductor y artillero, **B / Q / J** sale, **Start** o **Enter** inicia. Al entrar o salir alguien se reparte de nuevo.
- Conductor: gira, acelera, frena, derrapa. Artillero: ítems y golpes laterales (LB/RB en mando; Q/E en teclado J1; J/; en J2). Jugador solo: ítem + dirección golpea (en el hito 4 solo sin ítem).
- Los golpes empujan lateralmente a los karts cercanos (provisional; el sistema de efectos llega en el hito 4). **Esc** vuelve al lobby.

## Ítems y efectos (hito 4)
- **Cajas de ítems** en la pista de prueba: al tocarlas, ruleta de 1 s y el ítem sale según tu posición (los últimos reciben opciones más fuertes; el 1.º nunca recibe cohete, estrella, etc.).
- **Usar ítem**: botón X/Y (mando), Espacio (J1), K (J2). Con "atrás" (stick abajo / S / ↓) los ataques salen hacia atrás y las trampas se colocan 3 m detrás; sin él, hacia adelante (trampas a 6 m).
- **Sin ítem en mano**, el artillero (o jugador solo con botón de ítem + dirección) golpea a los lados.
- 23 ítems: velocidad (turbo, triple turbo, cohete), defensa (escudo, orbitales, burbuja reflectante), ataque (recto, rebotador, teledirigido, bomba de área, ola de choque), trampas (aceite, clavos, caja falsa, barrera, mina; sin soltar hacen de escudo trasero), invencibilidad (estrella, fantasma, gigante) y caos (tinta, controles invertidos, ralentizar a los de delante, intercambio de posición).
- **Un único sistema de efectos** (`KartEffect` + `KartEffects`): turbos, giros, escudos, tinta... son recursos `.tres` en `data/effects/`. Los turbos de derrape y aterrizaje también pasan por él.
- **Añadir un ítem nuevo = crear un `.tres`** en `data/items/` (subclases `ItemSelfEffect`, `ItemProjectile`, `ItemTrap`, `ItemChaos`, `ItemSwap`); el catálogo lo detecta solo. `tools/generate_data.gd` regenera los valores iniciales:
```powershell
Godot_console.exe --headless --path . --script tools/generate_data.gd
```
- Todos los ataques entran por `Kart.take_hit` (compañeros/fantasma → reflejo → inmunidad → guardias → trampa trasera → efecto). Equipos y fuego amigo ya están soportados (`team`, `friendly_fire`); los equipos se asignan en el hito 5.
- La clasificación es provisional (avance hacia -Z); en el hito 5 pasa a vueltas y checkpoints.

## Carrera, bots y equipos (hito 5)
Flujo: **menú principal → lobby → carrera → resultados → lobby**.
- **Circuito**: generado por código desde una curva cerrada (`scripts/race/circuit.gd`, ≈920 m, carretera con muros y línea de meta). La misma curva mide el progreso/vueltas y guía a los bots. La pista de pruebas anterior sigue en `scenes/tracks/test_track.tscn` (la usa el autotest).
- **Carrera** (`RaceManager`): cuenta atrás 3-2-1 con los karts congelados, vueltas (1-9), clasificación en vivo, aviso de contramano, reaparición si te caes (o con **R**), y resultados con puntos por puesto (15, 12, 10, 8, 6, 4, 3, 2). El progreso no deja "saltarse" tramos.
- **Bots** (`BotController`): siguen la curva con un punto de mira, frenan en curvas cerradas, usan ítems con reglas sencillas y se desatascan solos. Piensan a 20 Hz y escalonados entre sí (poca CPU). Hasta 8 karts en pantalla (4 humanos + 4 bots); los bots no tienen vista.
- **Equipos**: Arriba/Abajo en el lobby cambia el equipo de tu kart (Rojo, Azul, Verde, Amarillo; máx. 4 karts por equipo). Los bots equilibran los equipos. Los resultados suman puntos por equipo. **Sin fuego amigo** por defecto (activable con Select/F).
- **Lobby**: LB/RB o `-`/`+` = nº de bots · LT/RT o `[` `]` = vueltas · Select o `F` = fuego amigo · Start/Enter = iniciar · Esc = menú.
- Al terminar, un kart humano pasa a piloto automático. La carrera acaba cuando llegan todos los humanos o 25 s después del primero; los que no llegan puntúan por progreso.

Autotest de carrera (1 humano en piloto automático + 3 bots, 2 vueltas):
```powershell
Godot_console.exe --headless --path . res://scenes/debug/race_selftest.tscn
```

## Física y estabilidad
- El proyecto usa **Jolt Physics** (`physics/3d/physics_engine`): con el motor anterior las mallas de colisión del circuito hacían rebotar el kart (≈8 % del tiempo en el aire, ±7 m/s de velocidad vertical); con Jolt 0 % y ±2 m/s.
- `scenes/debug/stability_probe.tscn` conduce un kart una vuelta y falla si vuelve el rebote:
```powershell
Godot_console.exe --headless --path . res://scenes/debug/stability_probe.tscn
```
- Derrape: el lado hacia el que giras mantiene el cierre de siempre; con el stick al lado contrario el derrape se abre mucho (gira ≈ 20 % del cerrado).

## Vehículos, personajes y equilibrio (hito 6)
- Tras el lobby hay una **pantalla de selección**: cada jugador elige su **personaje** (Izq/Der) y el jugador solo o el conductor elige el **vehículo** (Arriba/Abajo). A/confirmar = listo; cuando todos lo están, arranca la carrera. Muestra las estadísticas finales del kart en vivo.
- **6 vehículos** (`data/vehicles/`: Chatarrero, Azulón, Relámpago, Escorpión, Tanque, Cohete) y **14 personajes** (`data/characters/`: Brutus, Crimson, Azur, Titán, Sakura, Áurea, Violeta, Chispa, DranCr, Agnelopolus, EnD, ClarStar, PoleWar, FerChaos). Añadir un `.tres` = opción nueva.
- **Estadísticas** (% sobre la base): velocidad, aceleración, manejo, peso, derrape, fuera de pista, fuerza de golpe y rapidez con ítems. Kart final = vehículo + personaje + **sinergia** (a cada personaje le gustan o le sientan mal ciertos vehículos). *Fuera de pista* se activará cuando haya superficies; el circuito actual tiene muros.
- **Kart de 2 jugadores**: el conductor aporta manejo y estadísticas de conducción; el artillero aporta fuerza de golpe, rapidez con ítems y la mitad de su peso. Llevar dos personas cuesta -2 % de velocidad y -3 % de aceleración.
- **Rapidez con ítems** acorta la ruleta y la espera entre usos; **peso** reduce lo que te empuja un golpe. El color del 3.er mini turbo sigue saliendo del personaje del conductor.
- **Equilibrio**: `tools/balance.gd` calcula TODAS las combinaciones (84 en solitario y 1092 con artillero), marca las que se salen de ±15 % del promedio y escribe `docs/BALANCE.md`:
```powershell
Godot_console.exe --headless --path . --script tools/balance.gd -- --write
```
  Resultado actual: ninguna marcada; diferencia mejor/peor 5.8 % (solo) y 8.8 % (con artillero).
- Los datos se regeneran con `tools/generate_data.gd` (también crea vehículos y personajes).
- La portada (`assets/ui/cover.jpg`) se muestra en el menú principal pero **no está en el repositorio** hasta decidir su licencia (ver `CREDITS.md`).
