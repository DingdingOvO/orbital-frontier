extends Control
## Main — 应用根节点：主题、页面路由、全局背景。
## 页面：menu / settings / mods / about / workshop / flight

const StarfieldBg := preload("res://src/game/StarfieldBg.gd")
const MenuPage      := preload("res://src/ui/pages/MenuPage.gd")
const SettingsPage  := preload("res://src/ui/pages/SettingsPage.gd")
const ModsPage      := preload("res://src/ui/pages/ModsPage.gd")
const AboutPage     := preload("res://src/ui/pages/AboutPage.gd")
const SavePage      := preload("res://src/ui/pages/SavePage.gd")
const WorkshopPage  := preload("res://src/game/WorkshopPage.gd")
const FlightPage    := preload("res://src/game/FlightPage.gd")

var _pages: Dictionary = {}
var _current: String = ""

var _bg_layer: Control
var _page_root: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme

	_bg_layer = StarfieldBg.new()
	add_child(_bg_layer)

	_page_root = Control.new()
	_page_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)

	_register_pages()
	Loc.locale_changed.connect(_on_locale)
	# 支持 `-- --page=workshop` 直达指定页面（调试/自动化用），默认进主菜单
	var start_page := "menu"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			start_page = a.substr(7)
	show_page(start_page)

func _register_pages() -> void:
	_add_page("menu", MenuPage)
	_add_page("settings", SettingsPage)
	_add_page("mods", ModsPage)
	_add_page("about", AboutPage)
	_add_page("saves", SavePage)
	_add_page("workshop", WorkshopPage)
	_add_page("flight", FlightPage)

func _add_page(id: String, script: GDScript) -> void:
	var p: Control = script.new()
	p.name = "Page_" + id
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.visible = false
	if p.has_method("set_nav"):
		p.set_nav(self)
	_page_root.add_child(p)
	_pages[id] = p

func show_page(id: String, payload: Dictionary = {}) -> void:
	if not _pages.has(id):
		push_warning("unknown page: " + id)
		return
	if _current != "" and _pages.has(_current):
		var old = _pages[_current]
		if old.has_method("on_exit"):
			old.on_exit()
		old.visible = false
	_current = id
	var p = _pages[id]
	p.visible = true
	if p.has_method("on_enter"):
		p.on_enter(payload)

func go_back() -> void:
	show_page("menu")

func _on_locale(_c: String) -> void:
	# 页面自身监听 Loc，这里只确保背景不遮挡
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	match _current:
		"menu":
			pass
		"flight":
			show_page("workshop")
		_:
			go_back()
