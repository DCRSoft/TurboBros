# Prueba de red real: lanza DOS procesos de Godot (anfitrión y cliente) en localhost y comprueba una carrera completa.
#   powershell -File tools/net_test.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = "F:\Dev\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$port = Get-Random -Minimum 24700 -Maximum 24990
$work = Join-Path $root ".tmp_net_test"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory $work | Out-Null
$scene = "res://scenes/debug/net_selftest.tscn"

function Start-Role($role, $extra) {
	$log = Join-Path $work "$role.log"
	$err = Join-Path $work "$role.err"
	$args = @("--headless", "--path", $root, $scene, "--", "--role=$role", "--port=$port") + $extra
	Start-Process -FilePath $godot -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError $err -PassThru -WindowStyle Hidden
}

$hostProc = Start-Role "host" @()
Start-Sleep -Seconds 5
$clientProc = Start-Role "client" @("--addr=127.0.0.1")
$deadline = (Get-Date).AddSeconds(300)
while ((-not $hostProc.HasExited -or -not $clientProc.HasExited) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
foreach ($p in @($hostProc, $clientProc)) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Write-Host "TIMEOUT: se cerró un proceso" } }

$fail = 0
foreach ($role in "host", "client") {
	$lines = Get-Content (Join-Path $work "$role.log") | Where-Object { $_ -match "^\[$role\]" -or $_ -match "SCRIPT ERROR" }
	$lines | ForEach-Object { Write-Host $_ }
	if (-not ($lines | Where-Object { $_ -match "NETTEST OK" })) { $fail++ }
	$errs = Get-Content (Join-Path $work "$role.log") | Where-Object { $_ -match "SCRIPT ERROR|Parse Error" }
	if ($errs) { $fail++ }
}
$hostRes = (Get-Content (Join-Path $work "host.log") | Where-Object { $_ -match "RESULT " } | Select-Object -First 1)
$cliRes = (Get-Content (Join-Path $work "client.log") | Where-Object { $_ -match "RESULT " } | Select-Object -First 1)
$a = ($hostRes -replace "^\[host\] ", "")
$b = ($cliRes -replace "^\[client\] ", "")
if ($a -and $a -eq $b) { Write-Host "PASS  los dos equipos ven los mismos resultados: $a" } else { Write-Host "FAIL  resultados distintos: host='$a' cliente='$b'"; $fail++ }

Remove-Item $work -Recurse -Force
if ($fail -eq 0) { Write-Host "RESULTADO: TODO OK" } else { Write-Host "RESULTADO: $fail FALLOS" }
exit $fail
