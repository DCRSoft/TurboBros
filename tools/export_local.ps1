# Exporta y empaqueta el juego en esta PC usando la plantilla de Windows ya descargada (sin instalar nada en AppData).
#   powershell -File tools/export_local.ps1
# Requiere F:\Dev\Tools\Godot (editor) y F:\Dev\Tools\GodotTemplates\4.7.2\windows_release_x86_64.exe.
param(
	[string]$Godot = "F:\Dev\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe",
	[string]$Template = "F:\Dev\Tools\GodotTemplates\4.7.2\windows_release_x86_64.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path $Template)) { throw "Falta la plantilla: $Template" }
$version = (Get-Content VERSION -Raw).Trim()

# Preset temporal con la plantilla local (el export_presets.cfg del repo usa las plantillas instaladas, como el CI)
$backup = Get-Content export_presets.cfg -Raw
try {
	$tpl = $Template.Replace("\", "/")
	$tplDebug = $tpl.Replace("windows_release_", "windows_debug_")
	$patched = $backup -replace 'custom_template/release=""', "custom_template/release=`"$tpl`"" `
		-replace 'custom_template/debug=""', "custom_template/debug=`"$tplDebug`""
	# UTF-8 SIN BOM (con BOM Godot no reconoce el preset)
	[IO.File]::WriteAllText((Join-Path $root "export_presets.cfg"), $patched, (New-Object Text.UTF8Encoding $false))
	New-Item -ItemType Directory -Force build | Out-Null
	& $Godot --headless --path . --import | Out-Null
	& $Godot --headless --path . --export-release "Windows Desktop" "build/TurboBros.exe"
	if ($LASTEXITCODE -ne 0) { throw "El export falló (código $LASTEXITCODE)" }
}
finally {
	[IO.File]::WriteAllText((Join-Path $root "export_presets.cfg"), $backup)
}
& powershell -NoProfile -ExecutionPolicy Bypass -File tools/package_release.ps1 -Version $version
