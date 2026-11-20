extends Node
## Calidades gráficas (Alta / Media / Baja), escala de render con presupuesto de píxeles y auto-ajuste.
## Mismos modelos en las tres calidades; cambian sombras, antialiasing, post-procesado, distancia de dibujado,
## LOD, partículas y resolución interna. Los ajustes se guardan en user://settings.cfg.

signal changed

enum Quality { LOW, MEDIUM, HIGH }

## Presupuestos iniciales (se ajustan con mediciones reales en cada equipo).
const PRESETS := {
	Quality.LOW: {
		"name": "Baja", "shadows": false, "shadow_distance": 0.0, "msaa": 0, "fxaa": false,
		"glow": false, "tonemap": false, "far": 1000.0, "lod": 4.0, "particles": 0.25,
			"terrain_cell": 10.0, "terrain_distance": 260.0, "prop_density": 0.3, "prop_distance": 130.0,
		"pixel_budget": 900000, "base_scale": 0.75, "textures": false,
	},
	Quality.MEDIUM: {
		"name": "Media", "shadows": true, "shadow_distance": 35.0, "msaa": 0, "fxaa": true,
		"glow": false, "tonemap": true, "far": 1200.0, "lod": 2.0, "particles": 0.5,
			"terrain_cell": 7.0, "terrain_distance": 480.0, "prop_density": 0.65, "prop_distance": 230.0,
		"pixel_budget": 1600000, "base_scale": 0.9, "textures": true,
	},
	Quality.HIGH: {
		"name": "Alta", "shadows": true, "shadow_distance": 90.0, "msaa": 2, "fxaa": true,
		"glow": true, "tonemap": true, "far": 1500.0, "lod": 1.0, "particles": 1.0,
			"terrain_cell": 6.0, "terrain_distance": 800.0, "prop_density": 1.0, "prop_distance": 400.0,
		"pixel_budget": 0, "base_scale": 1.0, "textures": true,
	},
}

const SETTINGS_PATH := "user://settings.cfg"

var quality: Quality = Quality.HIGH
var user_scale := 1.0        ## tope manual de escala (0.4 - 1.0)
var auto_scale := true       ## bajar la escala si los FPS caen de 60
var unlock_fps := false      ## FPS sin tope (solo el render; la física sigue a 60 Hz con interpolación)
var fullscreen := false
var dynamic_scale := 1.0     ## escala actual del auto-ajuste
var measuring := false       ## true mientras hay una carrera/pantalla dividida activa

var _controller := ScaleController.new()
var _accum := 0.0
var _warmup := 0.0


func _ready() -> void:
	load_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		# Primer arranque: calidad según la GPU. No se guarda hasta que el jugador cambie algo en Opciones.
		quality = detect_quality(RenderingServer.get_video_adapter_name())
	apply_global()


func _process(delta: float) -> void:
	if not (auto_scale and measuring):
		_warmup = 0.0
		return
	_warmup += delta
	if _warmup < 4.0:  # no medir durante la carga de la escena
		return
	_accum += delta
	if _accum >= 1.0:
		_accum = 0.0
		var before := _controller.scale
		_controller.tick(Engine.get_frames_per_second())
		if not is_equal_approx(before, _controller.scale):
			dynamic_scale = _controller.scale
			changed.emit()


# --- Consulta ---------------------------------------------------------------

func preset() -> Dictionary:
	return PRESETS[quality]


func get_value(key: String) -> Variant:
	return PRESETS[quality][key]


func quality_name(q: Quality = quality) -> String:
	return PRESETS[q]["name"]


## Escala máxima que cabe en el presupuesto de píxeles de la calidad (total_px = píxeles de todas las vistas a escala 1).
static func budget_scale(q: Quality, total_px: float) -> float:
	var budget: float = PRESETS[q]["pixel_budget"]
	if budget <= 0.0 or total_px <= 0.0:
		return 1.0
	return clampf(sqrt(budget / total_px), 0.25, 1.0)


## Escala final de render de las vistas.
func effective_scale(total_px: float, manual := 1.0) -> float:
	var s := minf(manual, user_scale)
	s = minf(s, float(get_value("base_scale")))
	s = minf(s, budget_scale(quality, total_px))
	if auto_scale:
		s = minf(s, dynamic_scale)
	return clampf(s, 0.25, 1.0)


## Calidad inicial según la GPU (heurística; se puede cambiar en Opciones).
static func detect_quality(adapter_name: String) -> Quality:
	var n := adapter_name.to_lower().replace("(r)", "").replace("(tm)", "")
	if n.contains("iris xe") or n.contains("intel arc"):
		return Quality.MEDIUM
	if n.contains("intel") or n.contains("uhd") or n.contains("llvmpipe") or n.contains("software"):
		return Quality.LOW
	return Quality.HIGH


# --- Cambios ----------------------------------------------------------------

func set_quality(q: Quality) -> void:
	quality = q
	dynamic_scale = 1.0
	_controller.reset(1.0)
	_commit()


func set_user_scale(s: float) -> void:
	user_scale = clampf(snappedf(s, 0.05), 0.4, 1.0)
	_commit()


func set_auto_scale(on: bool) -> void:
	auto_scale = on
	dynamic_scale = 1.0
	_controller.reset(1.0)
	_commit()


func set_unlock_fps(on: bool) -> void:
	unlock_fps = on
	_commit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_commit()


func _commit() -> void:
	apply_global()
	save_settings()
	changed.emit()


## Ajustes de ventana/motor.
func apply_global() -> void:
	Engine.max_fps = 0 if unlock_fps else 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(want)


## Aplica la calidad a un viewport (cada vista de pantalla dividida).
func apply_to_viewport(vp: Viewport) -> void:
	var p := preset()
	vp.msaa_3d = Viewport.MSAA_2X if int(p["msaa"]) >= 2 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.mesh_lod_threshold = float(p["lod"])


## Aplica la calidad al entorno y al sol de una escena (sombras reales o no, post-procesado).
func apply_to_scene(root: Node) -> void:
	var p := preset()
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env != null:
			env.glow_enabled = p["glow"]
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if p["tonemap"] else Environment.TONE_MAPPER_LINEAR
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := n as DirectionalLight3D
		sun.shadow_enabled = p["shadows"]
		sun.directional_shadow_max_distance = maxf(float(p["shadow_distance"]), 1.0)


# --- Guardado ---------------------------------------------------------------

func save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return  # las pruebas automáticas no tocan los ajustes reales del jugador
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # conserva la sección de audio
	cfg.set_value("graphics", "quality", int(quality))
	cfg.set_value("graphics", "user_scale", user_scale)
	cfg.set_value("graphics", "auto_scale", auto_scale)
	cfg.set_value("graphics", "unlock_fps", unlock_fps)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", Quality.HIGH)), 0, 2) as Quality
	user_scale = clampf(float(cfg.get_value("graphics", "user_scale", 1.0)), 0.4, 1.0)
	auto_scale = bool(cfg.get_value("graphics", "auto_scale", true))
	unlock_fps = bool(cfg.get_value("graphics", "unlock_fps", false))
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
