extends Control
## SavePage — 存档列表：进入 / 新建 / 删除，展示每个存档的进度与成就

var nav: Control
var _texts: Array = []
var _list: VBoxContainer
var _btn_new: Button

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	SaveGame.slots_changed.connect(_rebuild)
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()
	_rebuild()

func on_enter(_p: Dictionary) -> void:
	_refresh()
	_rebuild()

func _build() -> void:
	var sc := UiKit.page_scaffold(nav, "save.title", _texts)
	add_child(sc.root)
	var col: VBoxContainer = sc.body

	_btn_new = UiKit.button("", true, 18)
	_btn_new.custom_minimum_size = Vector2(180, 46)
	_btn_new.pressed.connect(_on_new)
	sc.head.add_child(_btn_new)
	_texts.append({"node": _btn_new, "key": "save.new"})

	var scroll := UiKit.themed_scroll(ScrollContainer.new())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UiKit.SP_M)
	scroll.add_child(_list)

func _on_new() -> void:
	var id := SaveGame.create_slot(Loc.t("save.default_name"))
	SaveGame.load_slot(id)
	nav.show_page("workshop")

func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()

	var slots := SaveGame.list_slots()
	if slots.is_empty():
		_list.add_child(UiKit.empty_state("save.empty", _texts))
		return
	for s in slots:
		_list.add_child(_slot_row(s))

func _slot_row(s: Dictionary) -> Control:
	var p := UiKit.panel(UiKit.PANEL, 18, true, 18)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)

	# 左：名称 + 创建时间
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	var nm := UiKit.label(str(s.get("name", "?")), 22, UiKit.TEXT)
	left.add_child(nm)
	var created := float(s.get("created", 0))
	var ds := Time.get_datetime_string_from_unix_time(int(created), true)
	left.add_child(UiKit.label(Loc.t("save.created", {"d": ds}), 13, UiKit.TEXT_MUTE))

	# 统计行
	var stats: Dictionary = s.get("stats", {})
	var ach: Dictionary = s.get("achievements", {})
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 24)
	left.add_child(st)
	_mini(st, Loc.t("save.stat.launch"), str(int(stats.get("launches", 0))), UiKit.TEXT_DIM)
	_mini(st, Loc.t("save.stat.orbit"), str(int(stats.get("orbits", 0))), UiKit.OK)
	_mini(st, Loc.t("save.stat.land"), str(int(stats.get("landings", 0))), UiKit.CYAN)
	_mini(st, Loc.t("save.stat.ach"), "%d / %d" % [ach.size(), SaveGame.ACHIEVEMENTS.size()], UiKit.WARN)
	_mini(st, Loc.t("save.best_alt"), _fmt(float(stats.get("best_altitude", 0.0))), UiKit.TEXT_DIM)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	h.add_child(btns)
	var enter := UiKit.button(Loc.t("save.enter"), true, 17)
	enter.custom_minimum_size = Vector2(120, 46)
	var sid := str(s.get("id", ""))
	enter.pressed.connect(func():
		SaveGame.load_slot(sid)
		nav.show_page("workshop"))
	btns.add_child(enter)
	var del := UiKit.ghost_button(Loc.t("save.delete"), 15)
	del.custom_minimum_size = Vector2(120, 40)
	del.pressed.connect(func(): SaveGame.delete_slot(sid))
	btns.add_child(del)
	return p

func _mini(parent: Control, label_txt: String, value: String, col: Color) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	var l := UiKit.label(label_txt, 12, UiKit.TEXT_MUTE)
	v.add_child(l)
	v.add_child(UiKit.label(value, 18, col))

func _fmt(m: float) -> String:
	if m >= 1.0e6:
		return "%.2f Mm" % (m / 1.0e6)
	if m >= 1000.0:
		return "%.1f km" % (m / 1000.0)
	return "%.0f m" % m

func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
	_rebuild()
