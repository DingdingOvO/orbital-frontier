extends Control
## SettingsPage — 设置：语言 / 音频 / 画面 / 玩法

var nav: Control
var _texts: Array = []        # [{node, key}] 分组标题
var _rows: Array = []         # [{label, key}] 设置项标题

var _lang_opt: OptionButton
var _quality_opt: OptionButton
var _units_opt: OptionButton
var _warp_opt: OptionButton
var _sfx: UiSlider
var _music: UiSlider
var _vib: UiToggle
var _traj: UiToggle
var _grid: UiToggle
var _autosave: UiToggle

const WARPS := [10, 100, 1000, 10000]
const QUALITIES := ["low", "medium", "high"]
const UNIT_KEYS := ["metric", "imperial"]

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_load_values()
	_refresh()

# ── 构建 ─────────────────────────────────────────────────
func _section(parent: Control, key: String) -> void:
	parent.add_child(UiKit.hsep(UiKit.SP_M))
	parent.add_child(UiKit.section_label(key, _texts))

## 设置行：统一用 UiKit.panel 的卡片样式（圆角/描边/投影全站一致）
func _row(key: String, control: Control) -> PanelContainer:
	var box := UiKit.panel(Color(0, 0, 0, 0), UiKit.RAD_PANEL, true, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.SP_L)
	row.custom_minimum_size = Vector2(0, 46)
	box.add_child(row)
	var lbl := UiKit.label("", UiKit.FS_BODY + 1, UiKit.TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rows.append({"label": lbl, "key": key})
	row.add_child(lbl)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return box

func _build() -> void:
	var sc := UiKit.page_scaffold(nav, "set.title", _texts)
	add_child(sc.root)
	var wrap: VBoxContainer = sc.body

	var scroll := UiKit.themed_scroll(ScrollContainer.new())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiKit.SP_S)
	scroll.add_child(body)

	# 语言
	_section(body, "common.language")
	_lang_opt = UiKit.option(["简体中文", "繁體中文", "English"], 0)
	_lang_opt.item_selected.connect(func(i: int): Loc.set_locale(Loc.CODES[i]))
	body.add_child(_row("common.language", _lang_opt))

	# 音频
	_section(body, "set.audio")
	_sfx = UiKit.slider(0.8, 0.0, 1.0, 0.05)
	_sfx.value_changed.connect(func(v: float): Cfg.set_value("sfx", v))
	body.add_child(_row("set.sfx", _sfx))
	_music = UiKit.slider(0.5, 0.0, 1.0, 0.05)
	_music.value_changed.connect(func(v: float): Cfg.set_value("music", v))
	body.add_child(_row("set.music", _music))

	# 画面
	_section(body, "set.graphics")
	_quality_opt = UiKit.option(["", "", ""], 2)
	_quality_opt.item_selected.connect(func(i: int): Cfg.set_value("quality", QUALITIES[i]))
	body.add_child(_row("set.quality", _quality_opt))

	# 玩法
	_section(body, "set.gameplay")
	_vib = UiKit.toggle(true)
	_vib.toggled.connect(func(on: bool): Cfg.set_value("vibration", on))
	body.add_child(_row("set.vibration", _vib))

	_units_opt = UiKit.option(["", ""], 0)
	_units_opt.item_selected.connect(func(i: int): Cfg.set_value("units", UNIT_KEYS[i]))
	body.add_child(_row("set.units", _units_opt))

	_traj = UiKit.toggle(true)
	_traj.toggled.connect(func(on: bool): Cfg.set_value("show_trajectory", on))
	body.add_child(_row("set.traj", _traj))

	_grid = UiKit.toggle(true)
	_grid.toggled.connect(func(on: bool): Cfg.set_value("show_grid", on))
	body.add_child(_row("set.grid", _grid))

	_warp_opt = UiKit.option(["10x", "100x", "1000x", "10000x"], 2)
	_warp_opt.item_selected.connect(func(i: int): Cfg.set_value("max_time_warp", WARPS[i]))
	body.add_child(_row("set.warp", _warp_opt))

	_autosave = UiKit.toggle(true)
	_autosave.toggled.connect(func(on: bool): Cfg.set_value("auto_save", on))
	body.add_child(_row("set.autosave", _autosave))

	body.add_child(UiKit.hsep(14))
	var reset := UiKit.ghost_button("")
	_texts.append({"node": reset, "key": "set.reset"})
	reset.pressed.connect(_on_reset)
	body.add_child(reset)

# ── 取值 / 刷新 ───────────────────────────────────────────
func _load_values() -> void:
	_lang_opt.selected = max(0, Loc.CODES.find(Loc.current))
	_sfx.set_value(float(Cfg.get_value("sfx", 0.8)))
	_music.set_value(float(Cfg.get_value("music", 0.5)))
	_quality_opt.selected = max(0, QUALITIES.find(str(Cfg.get_value("quality", "high"))))
	_units_opt.selected = max(0, UNIT_KEYS.find(str(Cfg.get_value("units", "metric"))))
	_warp_opt.selected = max(0, WARPS.find(int(Cfg.get_value("max_time_warp", 1000))))
	_vib.setup(bool(Cfg.get_value("vibration", true)))
	_traj.setup(bool(Cfg.get_value("show_trajectory", true)))
	_grid.setup(bool(Cfg.get_value("show_grid", true)))
	_autosave.setup(bool(Cfg.get_value("auto_save", true)))

func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key)
	for e in _rows:
		if is_instance_valid(e.label):
			e.label.text = Loc.t(e.key)
	_set_option_texts(_quality_opt, [Loc.t("set.q.low"), Loc.t("set.q.medium"), Loc.t("set.q.high")], QUALITIES, "quality")
	_set_option_texts(_units_opt, [Loc.t("set.units.metric"), Loc.t("set.units.imperial")], UNIT_KEYS, "units")
	_set_option_texts(_warp_opt, ["10x", "100x", "1000x", "10000x"], null, "max_time_warp")
	_lang_opt.selected = max(0, Loc.CODES.find(Loc.current))

func _set_option_texts(opt: OptionButton, texts: Array, keys, cfg_key: String) -> void:
	opt.clear()
	for i in texts.size():
		opt.add_item(str(texts[i]), i)
	if keys != null:
		opt.selected = max(0, Array(keys).find(str(Cfg.get_value(cfg_key, keys[0]))))
	else:
		opt.selected = max(0, WARPS.find(int(Cfg.get_value(cfg_key, 1000))))

func _on_reset() -> void:
	var lang := Loc.current
	Cfg.data = Cfg.DEFAULTS.duplicate(true)
	Cfg.data["language"] = lang
	Cfg.save_cfg()
	_load_values()
	_refresh()
	_toast(Loc.t("set.reset.done"))

func _toast(text: String) -> void:
	var l := UiKit.label(text, 15, UiKit.OK)
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.offset_left = -520
	l.offset_top = -56
	l.offset_right = -40
	l.offset_bottom = -26
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
