extends Node
## ModHost — Mod 加载与管理
## 目录：user://mods/<mod_id>/mod.json
## mod.json: { id, name, version, author, description, enabled, entry }
## 支持导入 .zip 包（自动解压），支持启用/停用/删除。

signal mods_changed()

const MODS_DIR := "user://mods"

var mods: Array[Dictionary] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODS_DIR))
	_ensure_sample()
	scan()

func mods_path() -> String:
	return ProjectSettings.globalize_path(MODS_DIR)

func _ensure_sample() -> void:
	# 放一个内置示例 Mod，让 Mod 页非空，同时演示 mod.json 规格
	var dir := MODS_DIR + "/sample.parts"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var meta := {
		"id": "sample.parts",
		"name": "Sample Parts Pack",
		"version": "1.0.0",
		"author": "Orbital Frontier",
		"description": "Bundled example mod: adds a demo part entry and shows the mod.json schema.",
		"enabled": false,
		"builtin": true,
		"entry": "mod.gd",
	}
	var f := FileAccess.open(dir + "/mod.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta, "\t"))
		f.close()

func scan() -> void:
	mods.clear()
	var d := DirAccess.open(MODS_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir() and not name.begins_with("."):
			var meta_path := MODS_DIR + "/" + name + "/mod.json"
			if FileAccess.file_exists(meta_path):
				var m := _read_meta(meta_path)
				if not m.is_empty():
					m["_dir"] = name
					mods.append(m)
		name = d.get_next()
	d.list_dir_end()
	mods.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	mods_changed.emit()

func _read_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var m: Dictionary = parsed
	m["enabled"] = bool(m.get("enabled", false))
	return m

func set_enabled(index: int, on: bool) -> void:
	if index < 0 or index >= mods.size():
		return
	mods[index]["enabled"] = on
	_write_meta(mods[index])
	mods_changed.emit()

func remove(index: int) -> void:
	if index < 0 or index >= mods.size():
		return
	var dirname: String = mods[index].get("_dir", "")
	if dirname != "":
		_delete_dir(MODS_DIR + "/" + dirname)
	scan()

func _write_meta(m: Dictionary) -> void:
	var dirname: String = m.get("_dir", "")
	if dirname == "":
		return
	var out := m.duplicate()
	out.erase("_dir")
	var f := FileAccess.open(MODS_DIR + "/" + dirname + "/mod.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()

func _delete_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			_delete_dir(path + "/" + n)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + n))
		n = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## 导入 .zip：解压到 mods/<zipbase>/，若包内有多层目录会自动下钻找 mod.json
func import_zip(zip_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "open_failed", "count": 0}
	var base := zip_path.get_file().get_basename()
	var target := MODS_DIR + "/" + base
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	for f in reader.get_files():
		if f.ends_with("/"):
			continue
		var data := reader.read_file(f)
		# 去掉 zip 内的顶层目录
		var rel := f
		var parts := f.split("/")
		if parts.size() > 1:
			rel = "/".join(Array(parts).slice(1))
		if rel == "":
			continue
		var full := target + "/" + rel
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full.get_base_dir()))
		var wf := FileAccess.open(full, FileAccess.WRITE)
		if wf:
			wf.store_buffer(data)
			wf.close()
	reader.close()
	scan()
	return {"ok": true, "error": "", "count": mods.size()}

func enabled_mods() -> Array:
	return mods.filter(func(m): return bool(m.get("enabled", false)))
