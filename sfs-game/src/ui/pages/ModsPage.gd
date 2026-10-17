extends Control
## ModsPage — Mod 管理：列表 / 启用停用 / 删除 / 导入 .zip

var nav: Control
var _texts: Array = []
var _list_box: VBoxContainer
var _status: Label
var _dialog: FileDialog
var _hint: Label
var _btn_import: Button
var _btn_folder: Button

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	ModHost.mods_changed.connect(_on_mods_changed)
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()
	_rebuild()

func _on_mods_changed() -> void:
	_rebuild.call_deferred()

func _build() -> void:
	var sc := UiKit.page_scaffold(nav, "mod.title", _texts)
	add_child(sc.root)
	var col: VBoxContainer = sc.body

	_btn_import = UiKit.ghost_button("", 15)
	_btn_import.icon_kind = "plus"
	_btn_import.custom_minimum_size = Vector2(184, 42)
	_btn_import.pressed.connect(func(): _dialog.popup_centered_ratio(0.7))
	sc.head.add_child(_btn_import)
	_texts.append({"node": _btn_import, "key": "mod.import"})

	_btn_folder = UiKit.ghost_button("", 15)
	_btn_folder.icon_kind = "folder"
	_btn_folder.custom_minimum_size = Vector2(184, 42)
	_btn_folder.pressed.connect(_open_folder)
	sc.head.add_child(_btn_folder)
	_texts.append({"node": _btn_folder, "key": "mod.openfolder"})

	_hint = UiKit.label("", UiKit.FS_SMALL, UiKit.TEXT_MUTE)
	_texts.append({"node": _hint, "key": "mod.hint"})
	col.add_child(_hint)

	var scroll := UiKit.themed_scroll(ScrollContainer.new())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", UiKit.SP_M)
	scroll.add_child(_list_box)

	_status = UiKit.label("", UiKit.FS_SMALL, UiKit.OK)
	col.add_child(_status)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.add_filter("*.zip", "Mod Package")
	_dialog.file_selected.connect(_on_zip_selected)
	add_child(_dialog)

# ── 列表 ─────────────────────────────────────────────────
func _rebuild() -> void:
	if _list_box == null:
		return
	for c in _list_box.get_children():
		c.queue_free()
	if ModHost.mods.is_empty():
		_list_box.add_child(UiKit.empty_state("mod.none", _texts))
		return
	for i in ModHost.mods.size():
		_list_box.add_child(_mod_row(ModHost.mods[i], i))

func _mod_row(m: Dictionary, idx: int) -> Control:
	var p := UiKit.panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	h.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	info.add_child(name_row)
	name_row.add_child(UiKit.label(str(m.get("name", m.get("id", "?"))), 19, UiKit.TEXT))
	name_row.add_child(UiKit.label("v" + str(m.get("version", "0.0.0")), 13, UiKit.CYAN))
	if bool(m.get("builtin", false)):
		name_row.add_child(UiKit.label("[" + Loc.t("mod.builtin") + "]", 13, UiKit.WARN))
	var by := UiKit.label("by " + str(m.get("author", "unknown")), 13, UiKit.TEXT_MUTE)
	info.add_child(by)
	var desc := UiKit.label(str(m.get("description", "")), 14, UiKit.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 0)
	info.add_child(desc)

	var state := VBoxContainer.new()
	state.add_theme_constant_override("separation", 4)
	h.add_child(state)
	var tg := UiKit.toggle(bool(m.get("enabled", false)))
	tg.toggled.connect(func(on: bool): ModHost.set_enabled(idx, on))
	state.add_child(tg)
	var st := UiKit.label(Loc.t("mod.enabled") if bool(m.get("enabled", false)) else Loc.t("mod.disabled"), 12, UiKit.OK if bool(m.get("enabled", false)) else UiKit.TEXT_MUTE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_child(st)

	var rm := UiKit.ghost_button(Loc.t("mod.remove"), 14)
	rm.pressed.connect(func(): ModHost.remove(idx))
	h.add_child(rm)
	return p

# ── 操作 ─────────────────────────────────────────────────
func _on_zip_selected(path: String) -> void:
	var r := ModHost.import_zip(path)
	if bool(r.get("ok", false)):
		_status.add_theme_color_override("font_color", UiKit.OK)
		_status.text = Loc.t("mod.imported", {"n": 1})
	else:
		_status.add_theme_color_override("font_color", UiKit.DANGER)
		_status.text = Loc.t("mod.failed", {"e": str(r.get("error", "?"))})
	_rebuild()

func _open_folder() -> void:
	var path := ModHost.mods_path()
	# 移动端/网页端没有可直接打开的资源管理器，改为复制路径并给出提示
	if OS.get_name() in ["Android", "iOS", "Web"]:
		DisplayServer.clipboard_set(path)
		_status.add_theme_color_override("font_color", UiKit.CYAN)
		_status.text = Loc.t("mod.path_copied", {"p": path})
		return
	var err := OS.shell_open("file://" + path)
	if err != OK:
		_status.add_theme_color_override("font_color", UiKit.WARN)
		_status.text = path

# ── 刷新 ─────────────────────────────────────────────────
func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
	_rebuild()
