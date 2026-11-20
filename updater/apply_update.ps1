# Actualizador externo de TurboBros.
# Lo lanza el juego al cerrarse: espera a que termine, verifica el SHA-256 del .zip, copia los archivos nuevos
# sobre la instalación y vuelve a abrir el juego. Se distribuye junto al .exe (ver .github/workflows/release.yml).
param(
	[Parameter(Mandatory = $true)][int]$ProcessId,
	[Parameter(Mandatory = $true)][string]$Zip,
	[Parameter(Mandatory = $true)][string]$InstallDir,
	[Parameter(Mandatory = $true)][string]$Exe,
	[string]$ExpectedSha256 = "",
	[switch]$NoRelaunch
)
$ErrorActionPreference = "Stop"
$self = $MyInvocation.MyCommand.Name
function Fail([string]$msg, [int]$code) { Write-Host $msg; exit $code }

# 1) Esperar a que el juego se cierre (máx. 60 s)
if ($ProcessId -gt 0) {
	try { Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue } catch { }
}

# 2) Verificar el hash otra vez (el archivo no debe haber cambiado desde que el juego lo comprobó)
if (-not (Test-Path $Zip)) { Fail "Zip not found: $Zip" 3 }
if ($ExpectedSha256 -ne "") {
	$actual = (Get-FileHash -Path $Zip -Algorithm SHA256).Hash.ToLower()
	if ($actual -ne $ExpectedSha256.ToLower()) { Fail "SHA-256 mismatch" 2 }
}

# 3) Extraer a una carpeta temporal y copiar sobre la instalación (sin tocar este mismo script)
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("TurboBros_update_" + [guid]::NewGuid().ToString("N"))
try {
	Expand-Archive -Path $Zip -DestinationPath $tmp -Force
	$src = $tmp
	if (-not (Test-Path (Join-Path $tmp $Exe))) {
		$sub = Get-ChildItem $tmp -Directory | Select-Object -First 1
		if ($sub -and (Test-Path (Join-Path $sub.FullName $Exe))) { $src = $sub.FullName }
	}
	$copied = $false
	for ($i = 0; $i -lt 30 -and -not $copied; $i++) {
		try {
			Get-ChildItem -Path $src -Force | Where-Object { $_.Name -ne $self } |
				Copy-Item -Destination $InstallDir -Recurse -Force
			$copied = $true
		} catch { Start-Sleep -Seconds 1 }   # el .exe puede tardar un poco en liberarse
	}
	if (-not $copied) { Fail "Could not copy files" 4 }
} finally {
	if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
Remove-Item $Zip -Force -ErrorAction SilentlyContinue

# 4) Volver a abrir el juego
if (-not $NoRelaunch) { Start-Process -FilePath (Join-Path $InstallDir $Exe) -WorkingDirectory $InstallDir }
exit 0
