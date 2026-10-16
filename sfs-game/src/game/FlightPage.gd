extends Control
## FlightPage — 飞行：物理步进 + 世界渲染 + 控制 HUD

const PHYS_DT := 0.02
const WARP_STEPS := [1, 5, 25, 100, 1000]
const MAX_PHYS_STEPS := 160

var nav: Control
var rocket: Rocket = null

# ── 相机 ──────────────────────────────────────────────────
var cam_pos := Vector2.ZERO
var cam_zoom := 4.0
var cam_target_zoom := 4.0

enum CamMode { FOLLOW, MAP }
var cam_mode := CamMode.FOLLOW
var cam_free := false
var _cam_tween: Tween
var _dragging := false
var _drag_last := Vector2.ZERO
var _intro_t := 1.0
var _intro_from_pos := Vector2.ZERO
var _intro_from_zoom := 4.0
var _pixels_moved := 0.0

const ZOOM_MIN := 1.0e-5
const ZOOM_MAX := 60.0
const PLANET_DRAW_LIMIT := 20000.0   # 行星半径在屏幕上的像素上限，超过就改用"地平线"画法

var throttle := 0.0
var steer := 0.0
var warp_idx := 0
var paused := false
var _autofly := false          # --autofly：内置演示自动驾驶（无人值守演示 / 自动化验证）
var _status := ""
var _last_state := ""

var _texts: Array = []
var _lbl_alt: Label
var _lbl_spd: Label
var _lbl_vspd: Label
var _lbl_apo: Label
var _lbl_peri: Label
var _lbl_fuel: Label
var _lbl_stage: Label
var _lbl_met: Label
var _lbl_guide: Label
var _guide_key := ""
var _intro_hint: Control
var _btn_stage: Button
var _btn_chute: Button
var _btn_warp: Button
var _btn_map: Button
var _btn_pause: Button
var _btn_left: Button
var _btn_right: Button
var _thr: UiSlider
var _thr_lbl: Label
var _thr_btn: Button
var _result_panel: Control
var _autosave_t := 0.0
var _traj_pts: PackedVector2Array = PackedVector2Array()
var _traj_timer := 0.0
var _telemetry_t := 0.0

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_hud()
	Loc.locale_changed.connect(func(_c: String): _refresh_texts())
	set_process(true)

func on_enter(payload: Dictionary) -> void:
	_hide_result()
	if payload.has("design"):
		rocket = Rocket.new()
		rocket.setup(payload["design"], "earth")
		SaveGame.record_launch()
		if not SaveGame.data.is_empty():
			SaveGame.data["design"] = payload["design"]
			SaveGame.save_current()
	else:
		# 从当前存档恢复
		var rd = SaveGame.data.get("rocket", {})
		if typeof(rd) == TYPE_DICTIONARY and not (rd as Dictionary).is_empty():
			rocket = Rocket.new()
			rocket.from_dict(rd)
		else:
			var dg = SaveGame.data.get("design", [])
			rocket = Rocket.new()
			if typeof(dg) == TYPE_ARRAY and not (dg as Array).is_empty():
				rocket.setup(dg, "earth")
			else:
				rocket.setup(Parts.PRESETS["orbiter"], "earth")
			SaveGame.record_launch()
	if rocket == null:
		rocket = Rocket.new()
		rocket.setup(Parts.PRESETS["orbiter"], "earth")
	warp_idx = 0
	paused = false
	_autofly = false
	for a in OS.get_cmdline_user_args():
		if a == "--autofly":
			_autofly = true
	if _autofly:
		warp_idx = 2          # 演示跑 25× 加速，几十秒内就能入轨
	cam_mode = CamMode.FOLLOW
	cam_free = false
	throttle = 0.0
	steer = 0.0
	_status = ""
	_last_state = ""
	_guide_key = ""
	_autosave_t = 0.0
	_telemetry_t = 0.0
	_traj_timer = 0.99
	_hide_result()
	if rocket:
		cam_pos = rocket.pos
		cam_zoom = _cam_desired_zoom()
		cam_target_zoom = cam_zoom
		_refresh_texts()
		_refresh_buttons()
		# 开场：从远景缓推到发射台（旧实现漏了这一步调用，动画从未播放）
		_play_intro()

func on_exit() -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()

# ── HUD 构建 ──────────────────────────────────────────────
func _build_hud() -> void:
	# 左上：飞行数据卡
	var flight := UiKit.glass(0.70, 18, 16)
	flight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	flight.position = Vector2(18, 16)
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flight)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	flight.add_child(fv)
	_hud_head(fv, "hud.flight")
	_lbl_alt = _hud_row(fv, "hud.altitude")
	_lbl_spd = _hud_row(fv, "hud.speed")
	_lbl_vspd = _hud_row(fv, "hud.vspeed")

	# 右上：任务数据卡
	var mission := UiKit.glass(0.70, 18, 16)
	mission.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mission.offset_left = -286
	mission.offset_top = 16
	mission.offset_right = -18
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mission)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	mission.add_child(mv)
	_hud_head(mv, "hud.mission")
	_lbl_met = _hud_row(mv, "hud.met")
	_lbl_stage = _hud_row(mv, "hud.stage", UiKit.CYAN)
	_lbl_apo = _hud_row(mv, "hud.apoapsis")
	_lbl_peri = _hud_row(mv, "hud.periapsis")
	_lbl_fuel = _hud_row(mv, "hud.fuel", UiKit.WARN)

	# 顶部中央：实时引导条
	var guide := UiKit.glass(0.78, 14, 14)
	guide.set_anchors_preset(Control.PRESET_CENTER_TOP)
	guide.offset_left = -240
	guide.offset_right = 240
	guide.offset_top = 16
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guide)
	_lbl_guide = UiKit.label("", 17, UiKit.CYAN)
	_lbl_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_child(_lbl_guide)

	# 底部控制条
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 18
	bar.offset_right = -18
	bar.offset_top = -108
	bar.offset_bottom = -16
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)

	# 节流
	var thr_box := UiKit.panel(Color(0.06, 0.09, 0.16, 0.80), 14, true)
	thr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(thr_box)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	thr_box.add_child(tv)
	var thr_head := HBoxContainer.new()
	var thl := UiKit.label("", 14, UiKit.TEXT_DIM)
	_texts.append({"node": thl, "key": "hud.throttle"})
	thr_head.add_child(thl)
	_thr_lbl = UiKit.label("0%", 18, UiKit.CYAN)
	_thr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	thr_head.add_child(_thr_lbl)
	tv.add_child(thr_head)
	var thr_row := HBoxContainer.new()
	thr_row.add_theme_constant_override("separation", 10)
	tv.add_child(thr_row)
	_thr = UiKit.slider(0.0, 0.0, 1.0, 0.05)
	_thr.custom_minimum_size = Vector2(200, 36)
	_thr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thr.value_changed.connect(func(v: float):
		throttle = v
		_thr_lbl.text = "%d%%" % roundi(v * 100.0))
	_thr.set_value(0.0)
	thr_row.add_child(_thr)
	_thr_btn = UiKit.button("100%", true, 16)
	_thr_btn.custom_minimum_size = Vector2(88, 40)
	_thr_btn.pressed.connect(func():
		_thr.set_value(1.0)
		throttle = 1.0
		_thr_lbl.text = "100%")
	thr_row.add_child(_thr_btn)

	# 转向
	var steer_box := UiKit.panel(Color(0.06, 0.09, 0.16, 0.80), 14, true)
	bar.add_child(steer_box)
	var sh := VBoxContainer.new()
	sh.add_theme_constant_override("separation", 3)
	steer_box.add_child(sh)
	var shl := UiKit.label("", 14, UiKit.TEXT_DIM)
	_texts.append({"node": shl, "key": "hud.steer"})
	shl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.add_child(shl)
	var shb := HBoxContainer.new()
	shb.add_theme_constant_override("separation", 10)
	sh.add_child(shb)
	# ↺ ↻ (U+21BA / U+21BB) —— 在裁剪字体范围内，不会渲染成方块
	_btn_left = _hold_btn(shb, "↺", func(on: bool): steer = -1.0 if on else 0.0)
	_btn_right = _hold_btn(shb, "↻", func(on: bool): steer = 1.0 if on else 0.0)

	# 动作
	var act_box := UiKit.panel(Color(0.06, 0.09, 0.16, 0.80), 14, true)
	bar.add_child(act_box)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 8)
	act_box.add_child(ah)
	_btn_stage = UiKit.button("", false, 17)
	_btn_stage.custom_minimum_size = Vector2(112, 58)
	_btn_stage.pressed.connect(_do_stage)
	_texts.append({"node": _btn_stage, "key": "hud.stage_btn"})
	ah.add_child(_btn_stage)
	_btn_chute = UiKit.button("", false, 17)
	_btn_chute.custom_minimum_size = Vector2(96, 58)
	_btn_chute.pressed.connect(_do_chute)
	_texts.append({"node": _btn_chute, "key": "part.chute"})
	ah.add_child(_btn_chute)
	_btn_map = UiKit.button("", false, 17)
	_btn_map.custom_minimum_size = Vector2(96, 58)
	_btn_map.pressed.connect(_toggle_map)
	_texts.append({"node": _btn_map, "key": "hud.map"})
	ah.add_child(_btn_map)
	_btn_warp = UiKit.button("", false, 17)
	_btn_warp.custom_minimum_size = Vector2(112, 58)
	_btn_warp.pressed.connect(_cycle_warp)
	ah.add_child(_btn_warp)
	_btn_pause = UiKit.button("", false, 17)
	_btn_pause.custom_minimum_size = Vector2(88, 58)
	_btn_pause.pressed.connect(_toggle_pause)
	ah.add_child(_btn_pause)

	# 左上角下方：返回工坊
	var back := UiKit.ghost_button("←  " + Loc.t("hud.revert"), 15)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 18
	back.offset_top = 152
	back.offset_right = 190
	back.offset_bottom = 196
	back.pressed.connect(func(): nav.show_page("workshop"))
	add_child(back)
	_texts.append({"node": back, "key": "hud.revert", "prefix": "←  "})

## HUD 分组小标题
func _hud_head(parent: Control, key: String) -> void:
	var l := UiKit.label("", 12, UiKit.TEXT_MUTE)
	l.add_theme_font_override("font", UiKit.spaced_font(3))
	_texts.append({"node": l, "key": key})
	parent.add_child(l)
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.12)
	sep.custom_minimum_size = Vector2(0, 1)
	parent.add_child(sep)
	parent.add_child(UiKit.hsep(3))

## HUD 一行：左标签 + 右大号数值
func _hud_row(parent: Control, key: String, value_col: Color = UiKit.TEXT) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(222, 26)
	parent.add_child(row)
	var k := UiKit.label("", 14, UiKit.TEXT_MUTE)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texts.append({"node": k, "key": key})
	row.add_child(k)
	var v := UiKit.label("—", 21, value_col)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", UiKit.number_font(0, 0.0))
	row.add_child(v)
	return v

func _hold_btn(parent: Control, txt: String, cb: Callable) -> Button:
	var b := UiKit.round_button(txt, 58, 26, true)
	b.button_down.connect(func(): cb.call(true))
	b.button_up.connect(func(): cb.call(false))
	parent.add_child(b)
	return b

func _refresh_texts() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = str(e.get("prefix", "")) + Loc.t(e.key)
	_refresh_buttons()
	_guide_key = ""

func _refresh_buttons() -> void:
	_btn_warp.text = "×%d" % WARP_STEPS[warp_idx]
	_btn_pause.text = Loc.t("hud.resume") if paused else Loc.t("hud.pause")

# ── 控制 ──────────────────────────────────────────────────
func _do_stage() -> void:
	if rocket and rocket.separate():
		SaveGame.record_stage()
		_feedback()
	_refresh_hud()

func _do_chute() -> void:
	if rocket and rocket.deploy_chute():
		_feedback()

func _cycle_warp() -> void:
	if rocket and rocket.state == "flying":
		warp_idx = (warp_idx + 1) % WARP_STEPS.size()
		_refresh_buttons()

func _toggle_map() -> void:
	cam_mode = CamMode.MAP if cam_mode == CamMode.FOLLOW else CamMode.FOLLOW
	cam_free = false
	_start_cam_transition(1.25)
	_refresh_buttons()

func _toggle_pause() -> void:
	paused = not paused
	_refresh_buttons()

func _feedback() -> void:
	# 仅在确实支持振动的平台调用，避免无权限时抛异常
	if bool(Cfg.get_value("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(30)

# ── 相机 ──────────────────────────────────────────────────
func _cam_center() -> Vector2:
	if cam_mode == CamMode.MAP:
		return Vector2.ZERO
	if rocket == null:
		return cam_pos
	return rocket.pos

## 跟随模式的目标缩放：让"屏幕竖向覆盖的高度"随高度线性增长
## 这样火箭与地表始终同时可见（旧公式在高空会把地表甩到几万像素外 → 全黑屏）
func _cam_desired_zoom() -> float:
	if rocket == null:
		return 4.0
	if cam_mode == CamMode.MAP:
		return (minf(size.x, size.y) * 0.42) / maxf(1.0, Space.radius(rocket.body_id))
	var alt: float = maxf(0.0, rocket.altitude())
	var span: float = 170.0
	if alt > 15.0:
		span = clampf(alt * 2.6 + 220.0, 170.0, 3.0e7)
	return clampf(maxf(1.0, size.y) / span, ZOOM_MIN, ZOOM_MAX)

## 平滑过渡：位置与缩放同步补间，视觉上是连续的推拉镜头
func _start_cam_transition(dur: float = 1.0) -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	var from_pos := cam_pos
	var from_zoom := cam_zoom
	var to_pos := _cam_center()
	var to_zoom := _cam_desired_zoom()
	cam_target_zoom = to_zoom
	_cam_tween = create_tween()
	_cam_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_cam_tween.tween_method(func(t: float):
		cam_pos = from_pos.lerp(to_pos, t)
		cam_zoom = lerpf(from_zoom, to_zoom, t), 0.0, 1.0, dur)

## 开场：从远景缓推到发射台
func _play_intro() -> void:
	if rocket == null:
		return
	var span: float = 1100.0
	_intro_from_zoom = clampf(maxf(1.0, size.y) / span, 0.01, 4.0)
	_intro_from_pos = rocket.pos + Vector2(-span * 0.38, span * 0.26)
	cam_pos = _intro_from_pos
	cam_zoom = _intro_from_zoom
	cam_target_zoom = _cam_desired_zoom()
	_intro_t = 0.0

func _update_camera(delta: float) -> void:
	if rocket == null:
		return
	if _intro_t < 1.0:
		_intro_t = minf(1.0, _intro_t + delta / 1.9)
		var e := 1.0 - pow(1.0 - _intro_t, 3.0)
		cam_pos = _intro_from_pos.lerp(_cam_center(), e)
		cam_zoom = lerpf(_intro_from_zoom, _cam_desired_zoom(), e)
		return
	if _cam_tween and _cam_tween.is_valid():
		return
	if cam_free:
		cam_zoom = lerpf(cam_zoom, cam_target_zoom, 1.0 - pow(0.002, delta))
		return
	cam_target_zoom = _cam_desired_zoom()
	cam_pos = cam_pos.lerp(_cam_center(), 1.0 - pow(0.0008, delta))
	cam_zoom = lerpf(cam_zoom, cam_target_zoom, 1.0 - pow(0.002, delta))

# ── 视角手势：拖动平移 / 滚轮与捏合缩放 / 双击回中 ──────────
func s2w(s: Vector2) -> Vector2:
	return (s - size * 0.5) / Vector2(cam_zoom, -cam_zoom) + cam_pos

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := s2w(screen_pos)
	cam_zoom = clampf(cam_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	cam_free = true
	cam_target_zoom = cam_zoom
	var after := s2w(screen_pos)
	cam_pos += before - after

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(e.position, 1.12)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(e.position, 1.0 / 1.12)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and e.double_click:
				cam_free = false
				_start_cam_transition(0.8)
				_dragging = false
			else:
				_dragging = e.pressed
				_drag_last = e.position
				_pixels_moved = 0.0
	elif e is InputEventMouseMotion and _dragging:
		var d: Vector2 = (e as InputEventMouseMotion).position - _drag_last
		_drag_last = (e as InputEventMouseMotion).position
		_pixels_moved += d.length()
		if _pixels_moved > 6.0:
			cam_free = true
			cam_pos -= d / Vector2(cam_zoom, -cam_zoom)
	elif e is InputEventMagnifyGesture:
		_zoom_at((e as InputEventMagnifyGesture).position, (e as InputEventMagnifyGesture).factor)
	elif e is InputEventPanGesture:
		cam_free = true
		cam_pos += ((e as InputEventPanGesture).delta * 18.0) / Vector2(cam_zoom, -cam_zoom)

# ── 主循环 ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if rocket == null:
		queue_redraw()
		return
	if _autofly and not paused:
		_apply_autopilot()
	if not paused and rocket.state == "flying":
		_physics_advance(delta)
	_update_camera(delta)
	_refresh_hud(delta)
	_autosave(delta)
	_update_trajectory(delta)
	queue_redraw()

## 演示自动驾驶：重力转弯 → 抬远地点 → 滑行 → 圆化（与冒烟测试同一套制导）
func _apply_autopilot() -> void:
	if rocket == null or rocket.state != "flying":
		return
	var R := Space.radius(rocket.body_id)
	var el := rocket.elements()
	var apo_raw: float = float(el.get("apo", 0.0))
	var apo: float = (apo_raw - R) if is_finite(apo_raw) else 1.0e12
	var peri: float = float(el.get("peri", 0.0)) - R
	var alt := rocket.altitude()
	var target := 100000.0
	if rocket.stage_fuel() <= 1.0 and rocket.active_stage + 1 < rocket.stages.size():
		_do_stage()
	var ta := 0.0
	if alt > 400.0:
		ta = clampf((alt - 400.0) / 45000.0, 0.0, 1.0) * PI * 0.5 * 0.98
	steer = clampf((ta - rocket.angle) * 2.5, -1.0, 1.0)
	var th := 0.0
	if apo < target:
		th = 1.0
	elif alt < apo - 8000.0:
		th = 0.0
	elif peri < target - 3000.0:
		th = 1.0
	throttle = th
	if is_instance_valid(_thr):
		_thr.set_value(th)

## 用真实帧时长驱动，固定步长上限；时间加速时自动放大步长
func _physics_advance(delta: float) -> void:
	var w: float = float(WARP_STEPS[warp_idx])
	var target: float = minf(delta, 0.1) * w
	var steps: int = clampi(int(ceil(target / PHYS_DT)), 1, MAX_PHYS_STEPS)
	var dt: float = target / float(steps)
	# 高倍加速时不施加姿态输入，避免"一秒转好几圈"的失控手感
	var st: float = steer if w < 100.0 else 0.0
	for i in steps:
		rocket.step(dt, throttle, st)
		if rocket.state != "flying":
			break

func _update_trajectory(delta: float) -> void:
	if rocket == null or rocket.state != "flying":
		_traj_pts = PackedVector2Array()
		return
	if not bool(Cfg.get_value("show_trajectory", true)):
		_traj_pts = PackedVector2Array()
		return
	_traj_timer += delta
	if _traj_timer < 0.2:
		return
	_traj_timer = 0.0
	var el := rocket.elements()
	if not bool(el.get("hyper", false)) and float(el.get("period", 0.0)) > 1.0:
		# 已形成闭合轨道：解析画一整圈，又准又省
		_traj_pts = Space.sample_orbit(rocket.body_id, rocket.pos, rocket.vel, 220)
	else:
		# 弹道飞行：向前积分 12 分钟
		_traj_pts = Space.predict_trajectory(rocket.body_id, rocket.pos, rocket.vel, 240, 3.0)

func _autosave(delta: float) -> void:
	if not bool(Cfg.get_value("auto_save", true)) or rocket == null:
		return
	_autosave_t += delta
	if _autosave_t > 3.0:
		_autosave_t = 0.0
		if rocket.state == "flying" and not SaveGame.data.is_empty():
			SaveGame.data["rocket"] = rocket.to_dict()
			SaveGame.save_current()

# ── HUD 刷新 ──────────────────────────────────────────────
func _refresh_hud(delta: float = 0.0) -> void:
	if rocket == null:
		return
	var alt := rocket.altitude()
	_lbl_alt.text = _fmt_dist(alt)
	_lbl_spd.text = "%d m/s" % roundi(rocket.speed())
	_lbl_vspd.text = "%+d m/s" % roundi(rocket.speed_vertical())
	var el := rocket.elements()
	var R := Space.radius(rocket.body_id)
	_lbl_apo.text = "∞" if bool(el.get("hyper", false)) else _fmt_dist(float(el.get("apo", 0.0)) - R)
	_lbl_peri.text = _fmt_dist(float(el.get("peri", 0.0)) - R)
	var f := rocket.stage_fuel()
	var cap := rocket.stage_fuel_cap()
	_lbl_fuel.text = "%d%%" % (roundi(100.0 * f / cap) if cap > 0.0 else 0)
	_lbl_stage.text = "%d / %d" % [rocket.active_stage + 1, rocket.stages.size()]
	_lbl_met.text = _fmt_time(rocket.mission_time)
	_thr_lbl.text = "%d%%" % roundi(throttle * 100.0)
	_refresh_guide()
	# 状态切换
	if rocket.state != _last_state:
		_last_state = rocket.state
		if rocket.state == "landed":
			SaveGame.record_landing(rocket.body_id)
			_show_result(Loc.t("hud.landed_on", {"p": Loc.t("planet." + rocket.body_id)}), UiKit.OK)
		elif rocket.state == "crashed":
			SaveGame.record_crash()
			_show_result(Loc.t("hud.crashed"), UiKit.DANGER)
	elif rocket.state == "flying" and _status != "orbit" and rocket.is_in_orbit():
		_status = "orbit"
		SaveGame.record_orbit()
		var el2 := rocket.elements()
		var R2 := Space.radius(rocket.body_id)
		SaveGame.add_satellite("SAT-%d" % (int(Time.get_unix_time_from_system()) % 100000),
			rocket.body_id, float(el2.get("apo", 0.0)) - R2, float(el2.get("peri", 0.0)) - R2)
		_show_result(Loc.t("hud.orbit"), UiKit.CYAN)
	# 遥测：按真实时间节流（旧实现每帧 +0.25，导致每秒写 15 次存档）
	_telemetry_t += delta
	if _telemetry_t >= 2.0:
		_telemetry_t = 0.0
		SaveGame.record_telemetry(rocket.altitude(), rocket.speed())

## 实时引导：告诉玩家当前该做什么
func _refresh_guide() -> void:
	var k := _guidance_key()
	if k == _guide_key:
		return
	_guide_key = k
	_lbl_guide.text = Loc.t(k) if k != "" else ""

func _guidance_key() -> String:
	if rocket == null:
		return ""
	if rocket.on_pad:
		return "guide.pad"
	if rocket.state == "crashed":
		return "guide.crashed"
	if rocket.state == "landed":
		return "guide.landed"
	var alt := rocket.altitude()
	if rocket.is_in_orbit():
		return "guide.orbit"
	if alt < 2000.0:
		return "guide.climb"
	if alt < 70000.0:
		return "guide.turn"
	return "guide.circularize"

func _fmt_dist(m: float) -> String:
	var a := absf(m)
	if a >= 1.0e6:
		return "%.2f Mm" % (m / 1.0e6)
	if a >= 1000.0:
		return "%.2f km" % (m / 1000.0)
	return "%.0f m" % m

func _fmt_time(s: float) -> String:
	var t := int(max(0.0, s))
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _show_result(text: String, col: Color) -> void:
	_hide_result()
	_result_panel = UiKit.panel(Color(col.r, col.g, col.b, 0.20), 14, true)
	_result_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_result_panel.offset_left = -230
	_result_panel.offset_right = 230
	_result_panel.offset_top = 76
	_result_panel.offset_bottom = 142
	_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 24, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(l)
	add_child(_result_panel)
	var tw := create_tween()
	tw.tween_interval(3.4)
	tw.tween_property(_result_panel, "modulate:a", 0.0, 0.6)

func _hide_result() -> void:
	if is_instance_valid(_result_panel):
		_result_panel.queue_free()
		_result_panel = null

# ── 世界渲染 ──────────────────────────────────────────────
func w2s(w: Vector2) -> Vector2:
	return (w - cam_pos) * Vector2(cam_zoom, -cam_zoom) + size * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("04060d"), true)
	_draw_stars()
	if rocket == null:
		return
	var b := Space.body(rocket.body_id)
	var R: float = float(b.get("radius", 6371000.0))
	var center := w2s(Vector2.ZERO)
	var rs: float = R * cam_zoom
	var horizon_y := w2s(Vector2(0.0, R)).y

	# 大气层 + 行星
	if rs < PLANET_DRAW_LIMIT:
		var atmo_h: float = float(b.get("atmo_h", 0.0))
		var ar: float = (R + atmo_h) * cam_zoom
		if atmo_h > 0.0 and ar < PLANET_DRAW_LIMIT:
			# 多层渐变，比单层平涂自然得多
			var layers := 6
			for i in layers:
				var t := float(i) / float(layers)
				draw_circle(center, lerpf(ar, rs, t), Color(0.30, 0.56, 1.0, 0.030))
		draw_circle(center, rs, Color(b.get("color", Color("2b6fd6"))))
		draw_circle(center, rs * 0.997, Color(b.get("color2", Color("14386f"))).lightened(0.07))
		# 地表高光：细线（旧实现线宽 rs*0.004，半径上万像素时变成一条粗色带）
		var seg: int = clampi(int(rs / 30.0), 64, 512)
		draw_arc(center, rs, 0.0, TAU, seg, Color(1, 1, 1, 0.16), maxf(1.5, minf(3.0, rs * 0.0006)))
	else:
		# 曲面已近似水平：画地平线 + 地表
		var atmo_h2: float = float(b.get("atmo_h", 0.0))
		if atmo_h2 > 0.0:
			var h := minf(atmo_h2 * cam_zoom, size.y * 2.0)
			if h > 1.0:
				draw_rect(Rect2(0, horizon_y - h, size.x, h), Color(0.25, 0.50, 1.0, 0.07), true)
		if horizon_y > -4000.0 and horizon_y < size.y + 4000.0:
			var land: Color = b.get("land_color", Color("3f7a4a"))
			var top := maxf(-2.0, horizon_y)
			draw_rect(Rect2(0, top, size.x, size.y - top + 4.0), land.darkened(0.72), true)
			draw_rect(Rect2(0, top, size.x, 14.0), land.darkened(0.20), true)
			draw_rect(Rect2(0, top + 14.0, size.x, 30.0), land.darkened(0.52), true)
			draw_line(Vector2(0, top), Vector2(size.x, top), Color(1, 1, 1, 0.35), 2.0)

	# 发射台
	var alt := rocket.altitude()
	if rocket.body_id == "earth" and alt < 3000.0 and rs >= PLANET_DRAW_LIMIT:
		var pad_y := horizon_y
		var px := w2s(Vector2(0.0, R)).x
		draw_line(Vector2(px - 46, pad_y), Vector2(px + 46, pad_y), Color(0.75, 0.80, 0.90, 0.85), 4.0)
		draw_line(Vector2(px - 32, pad_y + 16), Vector2(px + 32, pad_y + 16), Color(0.55, 0.60, 0.70, 0.6), 3.0)

	# 预测轨迹
	if bool(Cfg.get_value("show_trajectory", true)) and rocket.state == "flying" and cam_mode == CamMode.FOLLOW:
		_draw_trajectory()

	# 火箭
	_draw_rocket()

	# 地图模式：轨道叠加
	if cam_mode == CamMode.MAP:
		_draw_map_overlay()

func _draw_trajectory() -> void:
	if _traj_pts.size() < 2:
		return
	var sp := PackedVector2Array()
	for p in _traj_pts:
		sp.append(w2s(p))
	var col := Color(0.35, 0.95, 0.85, 0.6)
	if rocket.is_in_orbit():
		col = Color(0.42, 0.98, 0.62, 0.7)
	draw_polyline(sp, col, 2.0)

## 静态星空：世界坐标网格 + 确定性伪随机，提供飞行时的空间参照
func _draw_stars() -> void:
	var s := 96.0
	var ox := fmod(cam_pos.x * cam_zoom * 0.012, s)
	var oy := fmod(cam_pos.y * cam_zoom * 0.012, s)
	var cols := int(size.x / s) + 2
	var rows := int(size.y / s) + 2
	for gy in range(-1, rows):
		for gx in range(-1, cols):
			var sv := float(gx * 131 + gy * 977)
			var r1 := absf(fmod(sin(sv * 12.9898) * 43758.5453, 1.0))
			var r2 := absf(fmod(sin(sv * 78.233) * 12345.6789, 1.0))
			var r3 := absf(fmod(sin(sv * 39.425) * 23421.631, 1.0))
			var px := float(gx) * s + r1 * s - ox
			var py := float(gy) * s + r2 * s - oy
			draw_circle(Vector2(px, py), 0.7 + r3 * 1.1, Color(0.85, 0.90, 1.0, 0.20 + r1 * 0.55))

func _draw_rocket() -> void:
	if rocket == null:
		return
	var up := rocket.pos.normalized()
	var dir := up.rotated(rocket.angle)
	var com := rocket.com_from_bottom()
	var base := rocket.pos - dir * com       # 箭底的世界坐标
	# 屏幕坐标系 y 轴翻转，所以旋转角要取负号，否则箭体会画反
	var screen_angle := -rocket.angle
	for it in rocket.layout():
		var c: float = it["center"]
		var w: float = it["w"]
		var h: float = it["h"]
		var kind: String = it["kind"]
		var wp := base + dir * c
		var sp := w2s(wp)
		# 最小可见尺寸：高空时箭体只有零点几像素，直接跳过会导致"火箭凭空消失"
		var sz := Vector2(maxf(3.5, w * cam_zoom), maxf(4.5, h * cam_zoom))
		var col: Color = _part_color(kind, it["id"])
		draw_set_transform_matrix(Transform2D(screen_angle, sp))
		draw_rect(Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), col, true)
		draw_rect(Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), col.darkened(0.45), false, maxf(1.0, cam_zoom * 0.06))
		if kind == "engine":
			draw_rect(Rect2(-sz.x * 0.34, sz.y * 0.5, sz.x * 0.68, sz.y * 0.55), col.darkened(0.45), true)
			draw_rect(Rect2(-sz.x * 0.50, -sz.y * 0.1, sz.x, sz.y * 0.16), col.darkened(0.25), true)
		elif kind == "pod" and sz.x > 12.0:
			draw_rect(Rect2(-sz.x * 0.22, -sz.y * 0.2, sz.x * 0.44, sz.y * 0.4), Color("16233c"), true)
		elif kind == "chute" and sz.x > 8.0:
			draw_line(Vector2(-sz.x * 0.4, 0), Vector2(sz.x * 0.4, 0), col.darkened(0.5), 2.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# 尾焰（只在真正有推力时）
	if throttle > 0.01 and rocket.state == "flying" and rocket.max_thrust() > 0.0 and rocket.stage_fuel() > 0.0:
		var tip := base - dir * 0.15
		var sp := w2s(tip)
		var sc: float = clampf(cam_zoom / 4.0, 0.35, 3.0)
		var len_px: float = (10.0 + throttle * 30.0) * sc
		var wpx: float = 15.0 * sc
		draw_set_transform_matrix(Transform2D(screen_angle, sp))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-wpx * 0.5, 0), Vector2(wpx * 0.5, 0), Vector2(0, len_px)]),
			Color(1.0, 0.86, 0.46, 0.95))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-wpx * 0.85, 0), Vector2(wpx * 0.85, 0), Vector2(0, len_px * 1.9)]),
			Color(0.35, 0.72, 1.0, 0.0))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# 开伞
	if rocket.chute:
		var top := base + dir * rocket.stack_height()
		var sp := w2s(top)
		var rr := clampf(11.0 * cam_zoom, 8.0, 120.0)
		draw_arc(sp, rr, PI, TAU, 36, Color(0.96, 0.74, 0.36, 0.95), maxf(2.0, rr * 0.14))
		draw_line(sp, base + dir * rocket.stack_height(), Color(0.85, 0.85, 0.9, 0.55), 2.0)

	# 高空时箭体在屏幕上很小：加一圈标记，避免玩家"找不到自己在哪"
	if rocket.stack_height() * cam_zoom < 16.0:
		var c := w2s(rocket.pos)
		draw_arc(c, 11.0, 0.0, TAU, 32, Color(0.60, 0.88, 1.0, 0.9), 2.0)
		draw_circle(c, 3.0, Color.WHITE)

func _part_color(kind: String, id: String) -> Color:
	match kind:
		"pod": return Color("e7effb")
		"nose": return Color("ccd8ec")
		"chute": return Color("f2a93b")
		"engine": return Color("8590a4")
		"decoupler": return Color("58627a")
		"fin": return Color("79839b")
		"legs": return Color("6b758a")
		_:
			if id == "tank_l":
				return Color("cfd9ea")
			if id == "tank_s":
				return Color("e9f0fb")
			return Color("dde5f2")

func _draw_map_overlay() -> void:
	if rocket == null:
		return
	var pts := Space.sample_orbit(rocket.body_id, rocket.pos, rocket.vel, 200)
	if pts.size() < 3:
		return
	var sp := PackedVector2Array()
	for p in pts:
		sp.append(w2s(p))
	draw_polyline(sp, Color(0.42, 0.98, 0.62, 0.8), 2.0)
	# 标记当前位置
	var cur := w2s(rocket.pos)
	draw_circle(cur, 5.0, Color.WHITE)
	draw_arc(cur, 9.0, 0.0, TAU, 24, Color(0.42, 0.98, 0.62, 0.9), 2.0)
