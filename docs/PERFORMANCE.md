# Mediciones de FPS

Medir con el .exe exportado (Worker mobile, laptop de presentaciones) o desde el editor (la mamalona).
Objetivo: 60 FPS estables en calidad baja en Worker mobile.

| Hito | Fecha | Equipo | Calidad | Viewports | FPS medio / mínimo | Notas |
|------|-------|--------|---------|-----------|--------------------|-------|
| 1 | _pendiente_ | Worker mobile | — | 1 | | Probar desde el editor/proyecto; sin calidades aún |
| 1 | _pendiente_ | Laptop presentaciones | — | 1 | | |

## Cómo medir (hito 7)
1. `git clone https://github.com/DCRSoft/TurboBros.git` y abrir con Godot 4.7.2, o usar el `.exe` exportado de un Release.
2. Opciones → elegir la calidad (el primer arranque la elige según la GPU) y dejar el auto-ajuste activado.
3. En el lobby pulsar **F9** (prueba de rendimiento: 4 vistas + 4 bots, todos conducidos por la IA, sin necesidad de 4 mandos) y mirar el HUD (arriba a la izquierda): FPS, resolución de cada vista y escala aplicada. Dejar correr una carrera completa.
4. Anotar aquí el FPS sostenido y la escala final que dejó el auto-ajuste.

| Hito | Fecha | Equipo | Calidad | Vistas | FPS medio / mínimo | Escala final | Notas |
|------|-------|--------|---------|--------|--------------------|--------------|-------|
| 7 | _pendiente_ | Worker mobile (i3-1005G1, UHD G1) | Baja | 4 | | | objetivo: 60 FPS estables |
| 7 | _pendiente_ | Laptop presentaciones (i5-1135G7, Iris Xe) | Media | 4 | | | objetivo: 60 FPS |
| 7 | _pendiente_ | La mamalona (RX 6700 XT) | Alta | 4 | | | 4K, FPS desbloqueados |
