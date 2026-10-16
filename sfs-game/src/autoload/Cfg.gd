extends Node
## Cfg — 用户配置持久化（user://config.json）
## 设置项：语言、音效、音乐、画质、震动、单位制、时间加速上限等。

const FILE_PATH := "user://config.json"

signal changed(key: String, value: Variant)

var data: Dictionary = {}

const DEFAULTS := {
	"language": "",            # 空 = 自动检测
	"sfx": 0.8,
	"music": 0.5,
	"quality": "high",         # low / medium / high
	"vibration": true,
	"units": "metric",         # metric / imperial
	"max_time_warp": 1000,
	"show_trajectory": true,
	"show_grid": true,
	"auto_save": true,
	"first_run": true,
}

func _ready() -> void:
	load_cfg()

func load_cfg() -> void:
	data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(FILE_PATH):
		var f := FileAccess.open(FILE_PATH, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					data[k] = parsed[k]

func save_cfg() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func get_value(key: String, fallback: Variant = null) -> Variant:
	if data.has(key):
		return data[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return fallback

func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save_cfg()
	changed.emit(key, value)
