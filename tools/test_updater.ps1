# Prueba de extremo a extremo del actualizador externo (sin abrir el juego):
#   powershell -File tools/test_updater.ps1
# Crea una "instalación" falsa y un .zip con la versión nueva, y comprueba que (a) con el hash correcto se
# reemplazan los archivos y (b) con un hash falso NO se toca nada.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root "updater\apply_update.ps1"
$work = Join-Path $root ".tmp_updater_test"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force $work | Out-Null
$fail = 0
function Check($name, $ok) { if ($ok) { Write-Host "PASS  $name" } else { Write-Host "FAIL  $name"; $script:fail++ } }

try {
	# Instalación vieja
	$install = Join-Path $work "install"
	New-Item -ItemType Directory $install | Out-Null
	Set-Content (Join-Path $install "a.txt") "viejo"
	Set-Content (Join-Path $install "keep.txt") "se conserva"
	# Paquete nuevo
	$pkg = Join-Path $work "pkg"
	New-Item -ItemType Directory $pkg | Out-Null
	Set-Content (Join-Path $pkg "a.txt") "nuevo"
	Set-Content (Join-Path $pkg "b.txt") "anadido"
	Set-Content (Join-Path $pkg "Game.exe") "exe"
	$zip = Join-Path $work "TurboBros-v9.9.9-windows.zip"
	Compress-Archive -Path (Join-Path $pkg "*") -DestinationPath $zip
	$sha = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()

	# (b) hash falso: no cambia nada y sale con código 2
	$bad = "0" * 64
	& powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProcessId 0 -Zip $zip -InstallDir $install -Exe "Game.exe" -ExpectedSha256 $bad -NoRelaunch
	Check "hash falso: código de salida 2" ($LASTEXITCODE -eq 2)
	Check "hash falso: la instalación queda intacta" ((Get-Content (Join-Path $install "a.txt")) -eq "viejo" -and -not (Test-Path (Join-Path $install "b.txt")))

	# (a) hash correcto: reemplaza, añade y conserva lo demás
	& powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProcessId 0 -Zip $zip -InstallDir $install -Exe "Game.exe" -ExpectedSha256 $sha -NoRelaunch
	Check "hash correcto: código de salida 0" ($LASTEXITCODE -eq 0)
	Check "hash correcto: archivo reemplazado" ((Get-Content (Join-Path $install "a.txt")) -eq "nuevo")
	Check "hash correcto: archivo nuevo añadido" (Test-Path (Join-Path $install "b.txt"))
	Check "hash correcto: archivos no incluidos se conservan" ((Get-Content (Join-Path $install "keep.txt")) -eq "se conserva")
	Check "hash correcto: el .zip se elimina" (-not (Test-Path $zip))
}
finally {
	if (Test-Path $work) { Remove-Item $work -Recurse -Force }
}
if ($fail -eq 0) { Write-Host "RESULTADO: TODO OK" } else { Write-Host "RESULTADO: $fail FALLOS" }
exit $fail
