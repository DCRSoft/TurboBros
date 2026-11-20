# Distribución y actualizaciones

## Cómo se publica una versión
1. Subir la versión en `VERSION` (por ejemplo `0.2.0`) y hacer commit.
2. Crear y subir la etiqueta con la **misma** versión: `git tag v0.2.0 && git push origin v0.2.0`.
3. El flujo `.github/workflows/release.yml` hace, en este orden:
   1. Pasa los autotests (kart, ítems, lobby, equilibrio, carrera con bots, estabilidad física).
   2. Comprueba que la etiqueta coincide con `VERSION` (si no, falla).
   3. Exporta el build de Windows con Godot headless (Godot y plantillas verificados con SHA-512).
   4. Comprime `TurboBros-v0.2.0-windows.zip` (el `.exe`, `apply_update.ps1`, licencias y créditos) y calcula su **SHA-256** (`.zip.sha256`).
   5. Publica el Release con ambos archivos.

Para probar el export en esta PC sin GitHub: `powershell -File tools/export_local.ps1` (usa la plantilla guardada en `F:\Dev\Tools\GodotTemplates`).

## Cómo se actualiza el juego (actualizador propio)
1. Al iniciar, el menú principal consulta `https://api.github.com/repos/DCRSoft/TurboBros/releases/latest` por HTTPS, **sin autenticación** (solo envía un `User-Agent` genérico).
2. Compara la etiqueta con `VERSION`. Si hay una versión más nueva con asset `TurboBros-vX.Y.Z-windows.zip` y un hash verificable, aparece **«Actualizar a vX.Y.Z»**.
3. Descarga el `.zip` a `user://updates/` y verifica su **SHA-256** (campo `digest` del asset, o el archivo `.sha256` adjunto). Si no coincide, se descarta.
4. Al cerrar el juego (o con «Instalar y reiniciar»), el juego lanza `apply_update.ps1`, que **espera a que el proceso termine**, vuelve a verificar el hash, copia los archivos nuevos sobre la instalación (sin tocar su propio script) y vuelve a abrir el juego.
- Nunca se escribe nada fuera de la carpeta del juego y de `user://`. Los ajustes del jugador (`user://settings.cfg`) no se tocan.
- Desde el editor no se instala nada (solo se prueba la consulta).
- Prueba del actualizador externo sin abrir el juego: `powershell -File tools/test_updater.ps1`.

## Evaluación de Velopack
[Velopack](https://velopack.io) es un framework de instalación y actualización para apps de escritorio (sucesor de Squirrel.Windows) con instalador, accesos directos, desinstalador y **actualizaciones delta** (solo bajan lo que cambió).

| | Actualizador propio (actual) | Velopack |
|---|---|---|
| Esfuerzo | Ya hecho y probado; ~200 líneas | Hay que integrar su herramienta `vpk` en el CI y un cliente en el juego |
| Instalador / accesos directos | No (se descomprime el zip) | Sí |
| Descargas | Zip completo por versión | Delta (mucho menos al actualizar) |
| Dependencias | Solo PowerShell (incluido en Windows 10/11) | Herramienta externa; su cliente nativo/.NET hay que integrarlo con Godot (verificar el estado actual de esa integración antes de decidir) |
| Control | Total | Menor, más cosas "mágicas" |

**Decisión por ahora:** mantener el actualizador propio (simple, verificable, sin dependencias). Reevaluar Velopack si (a) el zip pasa de ~100–150 MB y las descargas completas molestan, o (b) se quiere un instalador con accesos directos y desinstalación.

## Pendiente antes del primer release público
- Firma de código (Windows SmartScreen mostrará aviso en un `.exe` sin firmar).
- Icono del `.exe` (requiere `rcedit`; está desactivado en `export_presets.cfg`).
- Probar el flujo completo con un Release real (la primera etiqueta).
