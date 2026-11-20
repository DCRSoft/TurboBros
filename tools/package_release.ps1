# Empaqueta el build de Windows: build/TurboBros-vX.Y.Z-windows.zip + .sha256
# Uso: pwsh tools/package_release.ps1 -Version v1.2.0 [-BuildDir build]
# Lo usan tanto el flujo de GitHub Actions como tools/export_local.ps1.
param(
	[Parameter(Mandatory = $true)][string]$Version,
	[string]$BuildDir = "build"
)
$ErrorActionPreference = "Stop"
$v = $Version.TrimStart("v")
$name = "TurboBros-v$v-windows"
$exe = Join-Path $BuildDir "TurboBros.exe"
if (-not (Test-Path $exe)) { throw "No existe $exe (exporta primero el proyecto)" }

$stage = Join-Path $BuildDir "stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item $exe $stage
Copy-Item "updater/apply_update.ps1" $stage          # actualizador externo (junto al .exe)
foreach ($f in "LICENSE", "LICENSE-ASSETS.md", "CREDITS.md") { Copy-Item $f $stage }

$zip = Join-Path $BuildDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
Remove-Item $stage -Recurse -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$zip.sha256", "$hash  $name.zip`n")
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Paquete: $zip ($mb MB)"
Write-Host "SHA-256: $hash"
