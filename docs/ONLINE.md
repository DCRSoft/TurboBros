# Multijugador en línea

Usa el **multijugador de alto nivel de Godot sobre ENet** (`ENetMultiplayerPeer`, UDP, puerto **24680** por defecto).

## Cómo se juega
1. Menú principal → **En línea**.
2. Un jugador elige **Crear partida** (anfitrión). La sala muestra su IP local.
3. Los demás eligen **Unirse a una partida**, escriben la IP del anfitrión (hace falta teclado) y pulsan Enter.
4. En la sala cada PC elige **vehículo y personaje** y se marca **listo** (A). Con **Y / E / ;** una PC pasa de 1 a 2 jugadores (conductor + artillero, con dos dispositivos); el artillero elige personaje con LB/RB o `,` `.`.
5. El anfitrión ajusta bots (`-`/`+`), vueltas (`[` `]`) y fuego amigo (`F`) y da la salida con Enter/Start cuando todos están listos.
6. Al terminar, resultados y vuelta a la sala sin perder la conexión.

Reglas: **1 o 2 jugadores por PC, una sola vista**; hasta **8 karts** entre humanos y bots (los bots los simula el anfitrión).
Por Internet, el anfitrión debe abrir/redirigir el puerto **UDP 24680** en su router (o usar una VPN tipo Radmin/ZeroTier/Tailscale).

## Cómo funciona
- **Entradas separadas de la lógica**: el kart solo lee `KartControls` (`KartController`). En red **nunca viajan los mandos**, solo el estado.
- **Cada PC simula SUS karts** (física arcade igual que en local) y envía su estado ~20 veces por segundo (`NetSync` → `net_state`, no fiable y ordenado). Los demás karts son **marionetas** (`Kart.make_remote()`): esfera cinemática que se interpola/extrapola hacia el último estado, sin física propia.
- **El anfitrión** gestiona la sala, la especificación de la carrera (`NetSession.build_spec`, determinista), la salida sincronizada (todos cargan → `net_begin` → cuenta atrás), las **llegadas** y los **resultados**. Los clientes calculan el progreso de todos para el HUD y la clasificación en vivo.
- **Ataques**: cada uso de ítem se replica como evento (`net_item_used`) y **todas las PCs lo ejecutan**, pero cada una **solo modifica sus propios karts**: la víctima aplica el efecto en su máquina (escudo, guardias y reflejo se resuelven allí). Proyectiles y trampas llevan un id común (`kart.net_id * 1000 + nº de uso`); si la víctima los destruye, avisa a las demás (`net_object_dead`). Los golpes cuerpo a cuerpo viajan como `net_melee` al dueño de la víctima.
- **Desconexión**: si un equipo se cae, su kart sale de la carrera; si cae el anfitrión, los clientes vuelven al menú.

## Limitaciones conocidas (versión inicial)
- Cada PC es autoritativa sobre su kart: sirve para jugar entre amigos, **no** está protegido contra trampas.
- Sin equipos en línea (todos contra todos) y sin descubrimiento automático de partidas en la red local (se escribe la IP).
- Las colisiones entre karts de distintas PCs son aproximadas (la marioneta no reacciona al choque, el dueño sí).
- Las cajas de ítems se recogen y reaparecen de forma independiente en cada PC.

## Pruebas
- Unitarias (especificación, marioneta): `selftest.tscn`.
- **Dos procesos reales en localhost** (sala → carrera completa → resultados idénticos en ambos):
```powershell
powershell -File tools/net_test.ps1
```
