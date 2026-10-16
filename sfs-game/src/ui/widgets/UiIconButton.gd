extends Button
class_name UiIconButton
## UiIconButton — 统一规格的菜单按钮：左侧矢量图标 + 居中文字
## 所有同类按钮共用同一套宽高与圆角，保证视觉规范统一。

const UiIconScript := preload("res://src/ui/widgets/UiIcon.gd")

var icon_kind := "":
	set(v):
		icon_kind = v
		if is_instance_valid(_ic):
			_ic.kind = v
var icon_tint := Color.WHITE:
	set(v):
		icon_tint = v
		if is_instance_valid(_ic):
			_ic.tint = v

var _ic: Control

func _ready() -> void:
	_ic = UiIconScript.new()
	_ic.kind = icon_kind
	_ic.tint = icon_tint
	_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ic)
	_place()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_ic):
		_place()

## 图标水平位置随按钮宽度自适应，整体看起来始终"贴着左边一列"
func _place() -> void:
	var d := 24.0
	var ix := clampf(size.x * 0.08, 21.0, 36.0)
	_ic.position = Vector2(ix - d * 0.5, (size.y - d) * 0.5)
	_ic.size = Vector2(d, d)
