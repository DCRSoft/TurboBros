# TurboBros

Juego de karts arcade 3D low poly para Windows (Godot 4, GDScript, renderizador Compatibility).
Hasta 8 jugadores locales con mandos USB/Bluetooth.

**Licencias:** el código es MIT (ver `LICENSE`). Las imágenes y los personajes (nombres, diseños, descripciones) son © DCRSoft, **todos los derechos reservados** (ver `LICENSE-ASSETS.md`).

> Repositorio público: nunca subir tokens, claves ni datos personales. Assets de terceros: registrar en `CREDITS.md`.

## Ejecutar
1. Abrir la carpeta con Godot 4.7 (`project.godot`) y pulsar F5.
2. Controles del hito 1:
   - **Mando (esquema Xbox)**: stick izq. girar · **A** (o RT) acelerar · **Y** (o LT) reversa/freno · **B** ítem · **X** mirar atrás · **LB/RB** derrapar (salto + derrape, con el stick inclinado) · Start pausa.
   - **Teclado** (control adicional, se puede combinar con mandos y con otros teclados): J1 = WASD + Shift (derrape) + Espacio (ítem) + Q/E (golpes del artillero) + C (mirar atrás); J2 = flechas + L (derrape) + K (ítem) + J/; (golpes) + / (mirar atrás). R = reiniciar. **P / Esc / Start = pausa**.

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
- **Usar ítem**: botón B (mando), Espacio (J1), K (J2). Con "atrás" (stick abajo / S / ↓) los ataques salen hacia atrás y las trampas se colocan 3 m detrás; sin él, hacia adelante (trampas a 6 m).
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
- **6 vehículos** (`data/vehicles/`: Chatarrero, Azulón, Relámpago, Escorpión, Tanque, Cohete) y **16 personajes** (`data/characters/`: DranCr, ClarStar, FerChaos, EnD, Agnelopolus y PoleWar de la portada, más Grunk, Zorp, Xyla, Ojón, Tornillo, Huesos, Gloop, Brasa, Fungo y Kraki). Añadir un `.tres` = opción nueva.
- **Estadísticas** (% sobre la base): velocidad, aceleración, manejo, peso, derrape, fuera de pista, fuerza de golpe y rapidez con ítems. Kart final = vehículo + personaje + **sinergia** (a cada personaje le gustan o le sientan mal ciertos vehículos). *Fuera de pista* se activará cuando haya superficies; el circuito actual tiene muros.
- **Kart de 2 jugadores**: el conductor aporta manejo y estadísticas de conducción; el artillero aporta fuerza de golpe, rapidez con ítems y la mitad de su peso. Llevar dos personas cuesta -2 % de velocidad y -3 % de aceleración.
- **Rapidez con ítems** acorta la ruleta y la espera entre usos; **peso** reduce lo que te empuja un golpe. El color del 3.er mini turbo sigue saliendo del personaje del conductor.
- **Equilibrio**: `tools/balance.gd` calcula TODAS las combinaciones (96 en solitario y 1440 con artillero), marca las que se salen de ±15 % del promedio y escribe `docs/BALANCE.md`:
```powershell
Godot_console.exe --headless --path . --script tools/balance.gd -- --write
```
  Resultado actual: ninguna marcada; diferencia mejor/peor 5.8 % (solo) y 8.8 % (con artillero).
- Los datos se regeneran con `tools/generate_data.gd` (también crea vehículos y personajes).
- La portada (`assets/ui/cover.jpg`) se muestra en el menú principal pero **no está en el repositorio** hasta decidir su licencia (ver `CREDITS.md`).

## Calidades gráficas, sonido, exportación y actualizaciones (hito 7)
**Opciones** (menú principal): calidad Alta / Media / Baja, escala máxima de render, auto-ajuste de escala, FPS desbloqueados, pantalla completa y volúmenes. Se guardan en `user://settings.cfg`. En el primer arranque la calidad se elige según la GPU (Intel UHD → Baja, Iris Xe/Arc → Media, el resto → Alta).

| | Baja | Media | Alta |
|---|---|---|---|
| Sombras | tipo blob (sin sombras reales) | reales hasta 35 m | reales hasta 90 m |
| Antialiasing | ninguno | FXAA | MSAA 2x + FXAA |
| Post-procesado | ninguno | tono | brillo + tono |
| Distancia de dibujado / LOD | 160 m / x4 | 320 m / x2 | 700 m / x1 |
| Presupuesto de píxeles (todas las vistas) | ≈0,9 M | ≈1,6 M | sin límite |
| Escala base | 0,75 | 0,90 | 1,0 |

- Mismos modelos en las tres calidades. Con 4 vistas en 1080p la calidad Baja renderiza ≈900.000 píxeles internos en total.
- **Auto-ajuste**: si los FPS bajan de 60 durante 2 s seguidos, la escala baja un 5 % (mínimo 40 %); tras 20 s estables vuelve a subir despacio.
- **Sonido**: efectos sintetizados por código (propios, sin licencias de terceros) y motor con tono según la velocidad. Música: pendiente.
- **Exportar y publicar**: `docs/UPDATES.md` (flujo de GitHub Actions por etiqueta `vX.Y.Z`, zip + SHA-256, actualizaciones automáticas y evaluación de Velopack). Probar el export en local: `powershell -File tools/export_local.ps1`.
- Para medir FPS en otro equipo: `git clone`, abrir con Godot 4.7.2, jugar con F4 (4 vistas) y anotar el FPS (HUD arriba a la izquierda) en `docs/PERFORMANCE.md`.

## Teclado y multijugador en línea (hito 8)
- **Teclado como control adicional**: dos esquemas (J1: WASD + Shift/Espacio/Q/E; J2: flechas + L/K/J/;) que se unen al lobby igual que un mando (Espacio / K), se pueden mezclar con mandos y sirven para conducir, usar ítems y golpear. Los menús también se manejan con teclado.
- **En línea** (menú principal → En línea): multijugador de alto nivel de Godot sobre **ENet**; **1 o 2 jugadores por PC con una sola vista**, hasta 8 karts con bots. Entradas separadas de la lógica: en red solo viaja el estado de cada kart (~20 Hz), los ataques se replican como eventos y cada PC resuelve los impactos de sus propios karts. Detalles, limitaciones y cómo abrir el puerto UDP 24680 en `docs/ONLINE.md`.
- Prueba de red real (anfitrión + cliente en dos procesos, carrera completa, resultados idénticos): `powershell -File tools/net_test.ps1`.
- Sonido más suave: motor grave sin diente de sierra, volúmenes por defecto 50 % (efectos) y 20 % (motor), ajustables en Opciones.

## Arte: personajes y vehículos (hito 7)
Todo el arte 3D se **genera por código** (low poly, color por vértice, sin texturas ni assets de terceros): `scripts/art/` (`MeshBuilder`, `CharacterModel`, `VehicleModel`, `KartVisual`). Cada figura es **una sola malla** y cada kart son 3 mallas en total (vehículo + conductor + artillero), compartidas entre karts: barato para el i3.
- **16 personajes con mucha variedad** (11 especies: humanos, ogro, gris alienígena, insectoide, cíclope, robot, esqueleto, slime, dragona, hongo y kraken). Los de la portada tienen su aspecto: **DranCr** (marrón, casco de púas) con **ClarStar** (coletas rosas); **FerChaos** (casco dorado y trenzas) con **EnD** (armadura azul, visor y rifle de rayos); **Agnelopolus** (rojo, casco integral y barba) con **PoleWar** (pelo morado y ametralladora giratoria). En un kart de 2, la pareja original recibe un pequeño bono.
- **6 vehículos** con modelo propio: Chatarrero (púas y escapes), Azulón, Relámpago (aleta), Escorpión (cola y pinzas), Tanque (camión de ruedas enormes) y Cohete.
- La selección de personaje y la sala en línea muestran una **vista previa 3D giratoria** del kart con su conductor y artillero.
- Imágenes: `docs/art/` (`personajes.png`, `vehiculos.png`, `parejas.png`, `seleccion.png`, `carrera.png`, `carrera_duo.png`). Se regeneran con `res://scenes/debug/art_sheet.tscn`, `select_shot.tscn` y `race_shot.tscn` (necesitan render, no `--headless`).
- Añadir un personaje: editar `tools/generate_roster.gd` (estadísticas + `look`) y ejecutar `Godot_console.exe --headless --path . --script tools/generate_roster.gd`; luego `tools/balance.gd`.
- Licencia: los diseños de personajes y las imágenes son © DCRSoft, todos los derechos reservados (`LICENSE-ASSETS.md`); el código generador es MIT.

## Pausa y mirar atrás
- **Pausa**: **Start** (mando), **P** o **Esc** durante la carrera. En local congela todo (física, bots, cuenta atrás y tiempo) y ofrece *Continuar*, *Reiniciar carrera*, *Volver al lobby* y *Menú principal*. **En línea** no puede congelar a los demás: el menú se abre pero la carrera sigue (opciones *Continuar* y *Salir de la partida*). Cualquier jugador puede abrirla y cerrarla.
- **Mirar atrás** (mantener): **X** en el mando, **C** (teclado J1) o **/** (teclado J2). La cámara pasa por delante del kart y mira hacia lo que viene detrás, con un aviso en pantalla; al soltar vuelve a la normal. Funciona para cualquiera de los dos jugadores de un kart y en pantalla dividida cada vista es independiente.
- Capturas en `docs/art/` (`carrera_pausa.png`, `carrera_atras.png`).

## Ítems: iconos, modelos y reglas (hito 7)
- **HUD del ítem** (arriba al centro de cada vista): icono grande en un marco del color del ítem, nombre, insignia de usos (x3), ruleta animada al recogerlo, y pista "↓ + ítem: hacia atrás" en proyectiles y trampas. A su derecha, los **efectos activos** como fichas con su temporizador (verde = a favor, rojo = en contra; los orbitales muestran sus cargas).
- **23 iconos vectoriales** dibujados por código (`scripts/ui/item_icons.gd`) y **modelos 3D low poly** de la caja de ítems (cubo de cristal con marco dorado y "?" flotante), misil recto y teledirigido, bola rebotadora, bomba con mecha, aceite, clavos, caja falsa (naranja con "!"), barrera y mina (`scripts/art/item_models.gd`). La trampa que llevas como escudo se ve detrás del kart. Imágenes: `docs/art/items_iconos.png`, `items_modelos.png`, `carrera_hud.png`.
- **Reglas**: lo que afecta "a todos" (bomba, ola de choque, mina, tinta, controles invertidos...) **no afecta a quien lo lanza** ni, **sin fuego amigo**, a su equipo; con fuego amigo sí afecta a los compañeros (nunca al lanzador). Los dueños pisan sus propias trampas sin activarlas.
- La ayuda de controles de la pantalla se oculta a los 14 s de carrera.
