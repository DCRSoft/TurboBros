extends SceneTree
## Renderiza la música procedural (MusicComposer) a assets/audio/music/<estilo>.wav y la fanfarria de resultados.
##   Godot_console.exe --headless --path . --script tools/generate_music.gd [-- tema1 tema2 ...]
## Sin argumentos genera todos los estilos. Son archivos propios (sin licencias de terceros): se pueden sustituir por
## música real con el mismo nombre (.wav u .ogg).

const OUT := "res://assets/audio/music/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		only.append(a)
	var comp := MusicComposer.new()
	for id in MusicComposer.style_ids():
		if not only.is_empty() and not only.has(String(id)):
			continue
		var t0 := Time.get_ticks_msec()
		_save(comp.render(id), String(id), true)
		print("%s: %d ms" % [id, Time.get_ticks_msec() - t0])
	if only.is_empty() or only.has("resultados"):
		_save(comp.render_jingle(), "resultados", false)
	print("Música generada.")
	quit()


func _save(samples: PackedFloat32Array, name: String, loop: bool) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MusicComposer.RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	var err := w.save_to_wav(ProjectSettings.globalize_path(OUT + name + ".wav"))
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [name, err])
