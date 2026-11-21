# Pruebas pendientes en equipos reales

Lo que no se puede comprobar con las pruebas automáticas (`selftest`, `race_selftest`, `net_test`, `scenery_probe`).
Build para probar: `TurboBros-v0.1.0-windows.zip` (se descomprime y se ejecuta `TurboBros.exe`).

## 1. Rendimiento (laptop i5-1135G7 / Worker mobile i3-1005G1)
- [ ] Opciones → Calidad **Baja**, auto-ajuste activado. Carrera de 1 jugador en una pista con mucho decorado (03 Bosque) y en una de poco (07 Industrial): anota los FPS (arriba a la izquierda).
- [ ] Lo mismo en **Media**.
- [ ] Lobby → **F9** (4 vistas + 4 bots con IA): anota los FPS y la escala de render que queda.
- [ ] Pista 10 (Fantasía) y 02 (Neón): son las de más triángulos de terreno.

## 2. Mando real
- [ ] Esquema Xbox: A acelera, B ítem, X mirar atrás, Y reversa, LB/RB derrapar, Start pausa.
- [ ] Selección: stick/cruceta mueven; A confirma; B quita "listo".
- [ ] Pantalla de pista: LB/RB cambian las vueltas; A arranca.
- [ ] Mandos desconectados: al volver al lobby se omiten (los demás jugadores siguen activos).

## 3. En línea entre dos PC
- [ ] Anfitrión: menú → En línea → crear; el cliente se conecta por IP (puerto 7777).
- [ ] El anfitrión elige pista con **T** y se ve el mapa en las dos pantallas.
- [ ] Carrera completa: los resultados coinciden en ambas PC; turbos, rampas y atajos se ven igual.

## 4. Sensaciones (lo que más importa)
- [ ] Arranque: acelerar antes de los 2 s ahoga el motor; a los 2 s da el turbo máximo; después, menos.
- [ ] ¿Las pistas se sienten variadas (curvas a izquierda y derecha)? ¿Alguna es demasiado larga o corta?
- [ ] ¿Los atajos son un buen riesgo/recompensa (~80 m menos)? ¿Los bots los usan demasiado o poco?
- [ ] Música: ¿qué estilos gustan y cuáles cansan? ¿Volumen por defecto (40 %) correcto?
- [ ] Sonidos: ¿alguno molesta (tic de menú, turbo, motor ahogado)?
