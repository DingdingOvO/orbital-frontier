extends Node
## SaveGame — 多存档管理（每个存档独立记录进度、卫星与成就）

const DIR := "user://saves"

signal slots_changed()
signal saved(slot_id: String)

var current_id: String = ""
var data: Dictionary = {}

# 工坊 → 飞行 传递的火箭设计
var _pending_design: Array = []

const ACHIEVEMENTS := {
	"first_launch": {"zh_CN": "首次发射", "zh_TW": "首次發射", "en": "First Launch"},
	"alt_10km":     {"zh_CN": "突破 10 km", "zh_TW": "突破 10 km", "en": "Above 10 km"},
	"alt_100km":    {"zh_CN": "抵达太空 100 km", "zh_TW": "抵達太空 100 km", "en": "Reached Space"},
	"alt_1000km":   {"zh_CN": "高度 1000 km", "zh_TW": "高度 1000 km", "en": "1000 km Altitude"},
	"first_orbit":  {"zh_CN": "首次入轨", "zh_TW": "首次入軌", "en": "First Orbit"},
	"first_land":   {"zh_CN": "首次软着陆", "zh_TW": "首次軟著陸", "en": "First Soft Landing"},
	"moon_flyby":   {"zh_CN": "飞抵月球", "zh_TW": "飛抵月球", "en": "Reached the Moon"},
	"speed_2kms":   {"zh_CN": "速度 2 km/s", "zh_TW": "速度 2 km/s", "en": "2 km/s"},
	"stage_master": {"zh_CN": "多级分离", "zh_TW": "多級分離", "en": "Stage Separation"},
}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

# ── 槽位管理 ──────────────────────────────────────────────
func list_slots() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".json"):
			var meta := _read_meta(fn.get_basename())
			if not meta.is_empty():
				out.append(meta)
		fn = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a, b): return float(a.get("last", 0)) > float(b.get("last", 0)))
	return out

func _read_meta(id: String) -> Dictionary:
	var f := FileAccess.open(_path(id), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var p: Dictionary = parsed
	return {
		"id": id,
		"name": str(p.get("name", id)),
		"created": float(p.get("created", 0)),
		"last": float(p.get("last", 0)),
		"stats": p.get("stats", {}),
		"achievements": p.get("achievements", {}),
	}

func create_slot(name: String) -> String:
	var id := "slot_%d" % int(Time.get_unix_time_from_system())
	var now := Time.get_unix_time_from_system()
	_write(id, {
		"id": id, "name": name, "created": now, "last": now,
		"design": [], "rocket": {},
		"stats": {"launches": 0, "orbits": 0, "landings": 0, "crashes": 0,
			"best_altitude": 0.0, "best_speed": 0.0, "satellites": []},
		"achievements": {},
	})
	slots_changed.emit()
	return id

func delete_slot(id: String) -> void:
	if FileAccess.file_exists(_path(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(id)))
	if current_id == id:
		current_id = ""
		data = {}
	slots_changed.emit()

func load_slot(id: String) -> Dictionary:
	var f := FileAccess.open(_path(id), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	current_id = id
	data = parsed
	if not data.has("stats"):
		data["stats"] = {}
	if not data.has("achievements"):
		data["achievements"] = {}
	return data

func save_current() -> void:
	if current_id == "" or data.is_empty():
		return
	data["last"] = Time.get_unix_time_from_system()
	_write(current_id, data)
	saved.emit(current_id)

func has_any_slot() -> bool:
	return not list_slots().is_empty()

func has_save() -> bool:
	return has_any_slot()

func has_game() -> bool:
	return has_any_slot()

# ── 进度记录 ──────────────────────────────────────────────
func record_launch() -> void:
	_bump("launches")
	_unlock("first_launch")

func record_orbit() -> void:
	_bump("orbits")
	_unlock("first_orbit")

func record_landing(body: String) -> void:
	_bump("landings")
	_unlock("first_land")
	if body == "moon":
		_unlock("moon_flyby")

func record_crash() -> void:
	_bump("crashes")

func record_telemetry(alt: float, spd: float) -> void:
	if data.is_empty():
		return
	var s: Dictionary = data.get("stats", {})
	var changed := false
	if alt > float(s.get("best_altitude", 0.0)):
		s["best_altitude"] = alt
		changed = true
	if spd > float(s.get("best_speed", 0.0)):
		s["best_speed"] = spd
		changed = true
	if changed:
		data["stats"] = s
		save_current()
	if alt >= 10000.0:
		_unlock("alt_10km")
	if alt >= 100000.0:
		_unlock("alt_100km")
	if alt >= 1000000.0:
		_unlock("alt_1000km")
	if spd >= 2000.0:
		_unlock("speed_2kms")

func record_stage() -> void:
	_unlock("stage_master")

func add_satellite(sname: String, body: String, apo: float, peri: float) -> void:
	if data.is_empty():
		return
	var s: Dictionary = data.get("stats", {})
	var sats: Array = s.get("satellites", [])
	sats.append({"name": sname, "body": body, "apo": apo, "peri": peri,
		"t": Time.get_unix_time_from_system()})
	s["satellites"] = sats
	data["stats"] = s
	save_current()

func _bump(key: String) -> void:
	if data.is_empty():
		return
	var s: Dictionary = data.get("stats", {})
	s[key] = int(s.get(key, 0)) + 1
	data["stats"] = s
	save_current()

func _unlock(id: String) -> void:
	if data.is_empty():
		return
	var a: Dictionary = data.get("achievements", {})
	if a.has(id):
		return
	a[id] = Time.get_unix_time_from_system()
	data["achievements"] = a
	save_current()
	slots_changed.emit()

func achievement_name(id: String) -> String:
	var d: Dictionary = ACHIEVEMENTS.get(id, {})
	return str(d.get(Loc.current, d.get("en", id)))

func stat(key: String, fallback: Variant = 0) -> Variant:
	var s: Dictionary = data.get("stats", {})
	return s.get(key, fallback)

# ── 设计缓存 ──────────────────────────────────────────────
func cache_design(design: Array) -> void:
	_pending_design = design.duplicate()

func get_cached_design() -> Array:
	return _pending_design.duplicate()

# ── 文件 IO ───────────────────────────────────────────────
func _path(id: String) -> String:
	return DIR + "/" + id + ".json"

func _write(id: String, payload: Dictionary) -> void:
	var f := FileAccess.open(_path(id), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
