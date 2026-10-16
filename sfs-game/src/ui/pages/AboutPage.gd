extends Control
## AboutPage — 关于

var nav: Control
var _texts: Array = []

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()

func _bind(node: Object, key: String) -> void:
	_texts.append({"node": node, "key": key})

func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 90)
	root.add_theme_constant_override("margin_right", 90)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_bottom", 44)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)

	# 顶部返回 + 标题
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	var back := UiKit.ghost_button("←  " + Loc.t("common.back"))
	back.pressed.connect(func(): nav.go_back())
	head.add_child(back)
	var t := UiKit.title("", 30)
	_bind(t, "about.title")
	head.add_child(t)

	col.add_child(UiKit.divider())

	var card := UiKit.panel()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	card.add_child(inner)

	var desc := UiKit.label("", 19, UiKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(760, 0)
	_bind(desc, "about.desc")
	inner.add_child(desc)

	inner.add_child(UiKit.hsep(6))

	var pl := UiKit.label("", 16, UiKit.CYAN)
	_bind(pl, "about.platforms")
	inner.add_child(pl)

	var plat := RichTextLabel.new()
	plat.bbcode_enabled = true
	plat.fit_content = true
	plat.scroll_active = false
	plat.custom_minimum_size = Vector2(0, 120)
	plat.add_theme_font_override("normal_font", UiKit.font_base if UiKit.font_base else ThemeDB.fallback_font)
	plat.add_theme_font_size_override("normal_font_size", 16)
	plat.add_theme_color_override("default_color", UiKit.TEXT_DIM)
	plat.text = "[color=#4ddb8b]●[/color] Android (APK)   [color=#8ea0c0]arm64-v8a / armeabi-v7a[/color]\n" \
		+ "[color=#4ddb8b]●[/color] Web (WebAssembly)   [color=#8ea0c0]Chrome / Edge / Firefox / Safari[/color]\n" \
		+ "[color=#ffb648]○[/color] Windows / macOS / Linux   [color=#8ea0c0]in progress[/color]\n" \
		+ "[color=#ffb648]○[/color] iOS   [color=#8ea0c0]planned[/color]"
	inner.add_child(plat)

	inner.add_child(UiKit.hsep(6))
	var cr := UiKit.label("", 14, UiKit.TEXT_MUTE)
	_bind(cr, "about.credits")
	inner.add_child(cr)

	# 底部版本
	var ver := UiKit.label("", 13, UiKit.TEXT_MUTE)
	_texts.append({"node": ver, "key": "app.version", "args": {"v": "0.1.0"}})
	col.add_child(ver)

func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
