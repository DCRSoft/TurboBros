extends Node
## Actualizaciones automáticas.
## 1) Al iniciar consulta la API PÚBLICA de Releases de GitHub por HTTPS (sin autenticación).
## 2) Compara con la versión actual (archivo VERSION). Si hay una nueva, descarga el .zip de Windows.
## 3) Verifica su SHA-256 (campo "digest" del asset o archivo <zip>.sha256 adjunto al Release).
## 4) Un actualizador EXTERNO (apply_update.ps1, junto al .exe) espera a que el juego se cierre, vuelve a
##    verificar el hash, copia los archivos nuevos encima y relanza el juego.

signal check_finished(result: Dictionary)
signal download_progress(done: int, total: int)
signal download_finished(ok: bool, message: String)

const REPO := "DCRSoft/TurboBros"
const API_URL := "https://api.github.com/repos/%s/releases/latest"
const UPDATE_DIR := "user://updates"
const PENDING_FILE := "user://updates/pending.json"
const SCRIPT_NAME := "apply_update.ps1"
const ZIP_PATTERN := "^TurboBros-v.+-windows\\.zip$"

var checked := false
var latest := {}      ## resultado de parse_release()
var downloading := false
var _http: HTTPRequest


# --- Funciones puras (probadas en el autotest) -------------------------------------

## Interpreta la respuesta de /releases/latest. Devuelve {available, version, zip_url, zip_name, zip_size,
## sha256, sha_url, notes}. Sin asset de Windows -> available = false.
static func parse_release(release: Dictionary, current_version: String) -> Dictionary:
	var out := {"available": false, "version": "", "zip_url": "", "zip_name": "", "zip_size": 0,
			"sha256": "", "sha_url": "", "notes": str(release.get("body", ""))}
	var tag := str(release.get("tag_name", ""))
	out["version"] = tag.trim_prefix("v")
	if tag == "" or GameVersion.compare(tag, current_version) <= 0:
		return out
	var rx := RegEx.create_from_string(ZIP_PATTERN)
	var assets: Array = release.get("assets", [])
	for a in assets:
		var name := str(a.get("name", ""))
		if rx.search(name) != null:
			out["zip_url"] = str(a.get("browser_download_url", ""))
			out["zip_name"] = name
			out["zip_size"] = int(a.get("size", 0))
			var digest := str(a.get("digest", ""))
			if digest.begins_with("sha256:"):
				out["sha256"] = digest.trim_prefix("sha256:").to_lower()
	for a in assets:
		if str(a.get("name", "")) == str(out["zip_name"]) + ".sha256":
			out["sha_url"] = str(a.get("browser_download_url", ""))
	out["available"] = out["zip_url"] != "" and (out["sha256"] != "" or out["sha_url"] != "")
	return out


## Extrae el hash de un archivo .sha256 (formato "hash  nombre" o solo el hash).
static func parse_sha_text(text: String, filename: String = "") -> String:
	for line in text.strip_edges().split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		var h := parts[0].to_lower()
		if h.length() == 64 and (filename == "" or parts.size() == 1 or parts[parts.size() - 1].trim_prefix("*") == filename):
			return h
	return ""


static func verify_file(path: String, expected_sha256: String) -> bool:
	if expected_sha256.length() != 64 or not FileAccess.file_exists(path):
		return false
	return FileAccess.get_sha256(path).to_lower() == expected_sha256.to_lower()


## Argumentos del actualizador externo (PowerShell).
static func build_apply_args(script: String, pid: int, zip_path: String, install_dir: String, exe_name: String,
		sha256: String) -> PackedStringArray:
	return PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", script,
			"-ProcessId", str(pid), "-Zip", zip_path, "-InstallDir", install_dir, "-Exe", exe_name,
			"-ExpectedSha256", sha256])


# --- Comprobación ------------------------------------------------------------------

func check() -> void:
	if checked:
		return
	checked = true
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_check_done)
	var headers := PackedStringArray(["User-Agent: TurboBros-Updater", "Accept: application/vnd.github+json"])
	var err := _http.request(API_URL % REPO, headers)
	if err != OK:
		check_finished.emit({"status": "error", "message": "No se pudo iniciar la consulta (%d)" % err})


func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		check_finished.emit({"status": "error", "message": "Sin conexión (%d)" % result})
		return
	if code == 404:
		check_finished.emit({"status": "no_releases"})  # aún no hay ningún Release publicado
		return
	if code != 200:
		check_finished.emit({"status": "error", "message": "GitHub respondió %d" % code})
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (json is Dictionary):
		check_finished.emit({"status": "error", "message": "Respuesta no válida"})
		return
	latest = parse_release(json, GameVersion.current)
	check_finished.emit({"status": "available" if latest["available"] else "up_to_date", "info": latest})


# --- Descarga ----------------------------------------------------------------------

func download() -> void:
	if downloading or not latest.get("available", false):
		return
	downloading = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE_DIR))
	if latest["sha256"] == "":
		var sha_req := HTTPRequest.new()
		sha_req.timeout = 20.0
		add_child(sha_req)
		sha_req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			sha_req.queue_free()
			var h := parse_sha_text(body.get_string_from_utf8(), latest["zip_name"]) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else ""
			if h == "":
				_fail("No se pudo obtener el SHA-256 de la actualización")
				return
			latest["sha256"] = h
			_download_zip())
		sha_req.request(latest["sha_url"], PackedStringArray(["User-Agent: TurboBros-Updater"]))
	else:
		_download_zip()


func _download_zip() -> void:
	var zip_path := UPDATE_DIR.path_join(latest["zip_name"])
	var req := HTTPRequest.new()
	req.download_file = zip_path
	req.timeout = 0.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		set_process(false)
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_fail("Falló la descarga (%d / HTTP %d)" % [result, code])
			return
		if not verify_file(zip_path, latest["sha256"]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
			_fail("El SHA-256 no coincide: descarga descartada")
			return
		var f := FileAccess.open(PENDING_FILE, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": latest["version"], "zip": ProjectSettings.globalize_path(zip_path),
				"sha256": latest["sha256"]}))
		f.close()
		downloading = false
		download_finished.emit(true, "Actualización %s lista" % latest["version"]))
	set_process(true)
	_progress_req = req
	var err := req.request(latest["zip_url"], PackedStringArray(["User-Agent: TurboBros-Updater"]))
	if err != OK:
		_fail("No se pudo iniciar la descarga (%d)" % err)

var _progress_req: HTTPRequest


func _process(_delta: float) -> void:
	if downloading and is_instance_valid(_progress_req):
		download_progress.emit(_progress_req.get_downloaded_bytes(), _progress_req.get_body_size())


func _fail(msg: String) -> void:
	downloading = false
	set_process(false)
	download_finished.emit(false, msg)


# --- Aplicación --------------------------------------------------------------------

func has_pending() -> bool:
	return FileAccess.file_exists(PENDING_FILE)


func pending_info() -> Dictionary:
	if not has_pending():
		return {}
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(PENDING_FILE))
	return json if json is Dictionary else {}


## Lanza el actualizador externo (solo en el juego exportado, no desde el editor). true = lanzado.
func launch_pending() -> bool:
	if OS.has_feature("editor") or not has_pending():
		return false
	var info := pending_info()
	var exe := OS.get_executable_path()
	var script := exe.get_base_dir().path_join(SCRIPT_NAME)
	if info.is_empty() or not FileAccess.file_exists(script):
		return false
	if not verify_file(str(info.get("zip", "")), str(info.get("sha256", ""))):
		DirAccess.remove_absolute(PENDING_FILE)  # archivo dañado o alterado: se descarta
		return false
	var args := build_apply_args(script, OS.get_process_id(), str(info["zip"]), exe.get_base_dir(), exe.get_file(),
			str(info["sha256"]))
	var pid := OS.create_process("powershell.exe", args)
	if pid > 0:
		DirAccess.remove_absolute(PENDING_FILE)
	return pid > 0


## Cierra el juego aplicando antes una actualización pendiente (si la hay).
func quit_game() -> void:
	launch_pending()
	get_tree().quit()
