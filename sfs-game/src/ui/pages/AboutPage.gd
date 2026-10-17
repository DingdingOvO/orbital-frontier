extends Control
## AboutPage — 关于（统一页面骨架：返回 + 标题 + 顶对齐内容区）

var nav: Control
var _texts: Array = []

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()

func _build() -> void:
	var sc := UiKit.page_scaffold(nav, "about.title", _texts)
	add_child(sc.root)
	var body: VBoxContainer = sc.body

	# ── 简介 ──
	var c1 := UiKit.panel()
	body.add_child(c1)
	var d := UiKit.label("", UiKit.FS_SUB, UiKit.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texts.append({"node": d, "key": "about.desc"})
	c1.add_child(d)

	# ── 支持平台 ──
	var c2 := UiKit.panel()
	body.add_child(c2)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", UiKit.SP_M)
	c2.add_child(v2)
	v2.add_child(UiKit.section_label("about.platforms", _texts))
	_plat_row(v2, "Android (APK)", "arm64-v8a · 27 MB", 1)
	_plat_row(v2, "Web (WebAssembly)", "Chrome / Edge / Firefox / Safari", 1)
	_plat_row(v2, "Windows / macOS / Linux", "about.soon", 0)
	_plat_row(v2, "iOS", "about.planned", 0)

	# ── 制作信息 ──
	var c3 := UiKit.panel(UiKit.PANEL_LO)
	body.add_child(c3)
	var v3 := VBoxContainer.new()
	v3.add_theme_constant_override("separation", UiKit.SP_XS)
	c3.add_child(v3)
	var cr := UiKit.label("", UiKit.FS_SMALL, UiKit.TEXT_DIM)
	_texts.append({"node": cr, "key": "about.credits"})
	v3.add_child(cr)
	var ver := UiKit.label("", UiKit.FS_TINY, UiKit.TEXT_MUTE)
	_texts.append({"node": ver, "key": "app.version", "args": {"v": "0.1.0"}})
	v3.add_child(ver)

## 平台行：状态点 + 名称 + 说明（note 以 "about." 开头则视为本地化 key）
func _plat_row(parent: Control, name: String, note: String, ready: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.SP_M)
	row.custom_minimum_size = Vector2(0, 30)
	var dot := UiKit.label("●" if ready == 1 else "○", UiKit.FS_SMALL,
		UiKit.OK if ready == 1 else UiKit.WARN)
	row.add_child(dot)
	var n := UiKit.label(name, UiKit.FS_BODY, UiKit.TEXT)
	n.custom_minimum_size = Vector2(240, 0)
	row.add_child(n)
	var s := UiKit.label("", UiKit.FS_SMALL, UiKit.TEXT_MUTE)
	if note.begins_with("about."):
		_texts.append({"node": s, "key": note})
	else:
		s.text = note
	row.add_child(s)
	parent.add_child(row)

func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
