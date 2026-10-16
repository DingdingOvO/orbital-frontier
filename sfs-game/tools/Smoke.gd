extends SceneTree
## Smoke.gd — 无头自动化冒烟测试
## 1) 参数体检：三套预设的推重比 / Δv 是否落在可用区间
## 2) 真实飞行：用自动驾驶仪跑完「点火 → 重力转弯 → 分离 → 入轨」全流程
## 运行：godot --headless --path <proj> --script res://tools/Smoke.gd

var _fail := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
	else:
		_fail += 1
		print("  [FAIL] ", msg)

func _initialize() -> void:
	print("========================================")
	print(" ORBITAL FRONTIER — SMOKE TEST")
	print("========================================")

	_test_presets()
	_test_liftoff()
	_test_ascent_guidance()
	_test_pad_idle()
	_test_fuel_depletion()
	_test_landing()
	_test_impact_crash()
	_test_orbit_math()

	print("========================================")
	if _fail == 0:
		print(" ALL CHECKS PASSED")
	else:
		print(" FAILED CHECKS: ", _fail)
	print("========================================")
	quit(1 if _fail > 0 else 0)

# ── 1) 预设参数体检 ────────────────────────────────────────
func _test_presets() -> void:
	print("\n[1] 预设参数")
	for id in ["sounding", "orbiter", "lunar"]:
		var r := Rocket.new()
		r.setup(Parts.PRESETS[id], "earth")
		var twr := r.thrust_to_weight()
		var dv := r.delta_v()
		print("  %-9s mass=%9.0f kg  TWR=%.2f  dV=%6.0f m/s  stages=%d  alt0=%.2f m"
			% [id, r.total_mass(), twr, dv, r.stages.size(), r.altitude()])
		_ok(twr > 1.15, "%s 推重比 %.2f > 1.15（能离开发射台）" % [id, twr])
		_ok(twr < 3.0, "%s 推重比 %.2f < 3.0（不会瞬间飞出视野）" % [id, twr])
		_ok(r.altitude() > 0.5, "%s 初始高度 %.2f m > 0.5（没有陷进地里）" % [id, r.altitude()])
		_ok(r.state == "flying", "%s 初始状态为 flying" % id)
	# orbiter 必须够入轨
	var ro := Rocket.new()
	ro.setup(Parts.PRESETS["orbiter"], "earth")
	_ok(ro.delta_v() > 9300.0, "orbiter Δv %.0f m/s 足够入轨（需 >9300）" % ro.delta_v())
	var rl := Rocket.new()
	rl.setup(Parts.PRESETS["lunar"], "earth")
	_ok(rl.delta_v() > 11500.0, "lunar Δv %.0f m/s 足够奔月（需 >11500）" % rl.delta_v())

# ── 2) 点火即离台 ──────────────────────────────────────────
func _test_liftoff() -> void:
	print("\n[2] 起飞（全推力 10 秒）")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["orbiter"], "earth")
	_ok(r.on_pad, "起始在发射台上")
	var h0 := r.altitude()
	var t := 0.0
	while t < 10.0:
		r.step(0.02, 1.0, 0.0)
		t += 0.02
	print("  10 s 后：高度 %.1f m，速度 %.1f m/s，垂直速度 %.1f m/s"
		% [r.altitude(), r.speed(), r.speed_vertical()])
	_ok(r.altitude() > h0 + 100.0, "10 秒内爬升超过 100 m（真的起飞了）")
	_ok(r.speed_vertical() > 25.0, "垂直速度 > 25 m/s")
	_ok(not r.on_pad, "已离开发射台")
	_ok(r.state == "flying", "状态仍为 flying（没有误判着陆）")

# ── 3) 自动驾驶入轨 ────────────────────────────────────────
func _test_ascent_guidance() -> void:
	print("\n[3] 自动驾驶入轨（orbiter 预设）")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["orbiter"], "earth")
	var R := Space.radius("earth")
	var dt := 0.05
	var t := 0.0
	var maxalt := 0.0
	var maxspd := 0.0
	var maxq_alt := 0.0
	var staged := false
	var log_t := 0.0
	while t < 2400.0 and r.state == "flying":
		var cmd := _autopilot(r)
		if cmd[2] and not staged:
			staged = true
		r.step(dt, cmd[0], cmd[1])
		t += dt
		maxalt = maxf(maxalt, r.altitude())
		maxspd = maxf(maxspd, r.speed())
		if log_t >= 30.0:
			log_t = 0.0
		log_t += dt
		if r.is_in_orbit():
			break
	var el := r.elements()
	var apo: float = float(el.get("apo", 0.0)) - R
	var peri: float = float(el.get("peri", 0.0)) - R
	print("  结果：state=%s  t=%.0f s  最大高度=%.1f km  最大速度=%.0f m/s"
		% [r.state, t, maxalt / 1000.0, maxspd])
	print("        远地点=%.1f km  近地点=%.1f km  级=%d/%d  剩余燃料=%.0f kg"
		% [apo / 1000.0, peri / 1000.0, r.active_stage + 1, r.stages.size(), r.total_fuel()])
	print("        入轨判定=%s  分离次数=%d" % [r.is_in_orbit(), r.event_log.size()])
	_ok(r.state != "crashed", "没有坠毁")
	_ok(maxalt > 90000.0, "最大高度超过 90 km（确实进了太空）")
	_ok(bool(r.is_in_orbit()), "判定为已入轨（近地点高于大气层顶）")
	_ok(peri > 90000.0, "近地点 %.1f km > 90 km" % (peri / 1000.0))

## 简易上升制导：重力转弯 → 抬远地点 → 滑行到远地点 → 圆化
func _autopilot(r: Rocket) -> Array:
	var R := Space.radius(r.body_id)
	var el := r.elements()
	var apo_raw: float = float(el.get("apo", 0.0))
	var apo: float = (apo_raw - R) if is_finite(apo_raw) else 1.0e12
	var peri: float = float(el.get("peri", 0.0)) - R
	var alt := r.altitude()
	var target := 100000.0

	# 该级燃料烧完，自动分离（模拟玩家按下分离键）
	var did_stage := false
	if r.stage_fuel() <= 1.0 and r.active_stage + 1 < r.stages.size():
		did_stage = r.separate()

	# 姿态：重力转弯程序（400 m 起转，45 km 时接近水平）
	var ta := 0.0
	if alt > 400.0:
		ta = clampf((alt - 400.0) / 45000.0, 0.0, 1.0) * PI * 0.5 * 0.98
	var err := ta - r.angle
	var st := clampf(err * 2.5, -1.0, 1.0)

	# 节流：爬升期抬远地点 → 滑行 → 在远地点附近圆化
	var th := 0.0
	if apo < target:
		th = 1.0
	elif alt < apo - 8000.0:
		th = 0.0                       # 已达标，滑行到远地点
	elif peri < target - 3000.0:
		th = 1.0                       # 远地点附近水平加速，抬近地点
	return [th, st, did_stage]

# ── 4) 发射台上静置 ────────────────────────────────────────
func _test_pad_idle() -> void:
	print("\n[4] 发射台静置 30 秒（不点火）")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["sounding"], "earth")
	var t := 0.0
	while t < 30.0:
		r.step(0.02, 0.0, 0.0)
		t += 0.02
	print("  高度 %.2f m，状态 %s，在台上=%s" % [r.altitude(), r.state, r.on_pad])
	_ok(r.state == "flying", "不点火不会误判为着陆/坠毁")
	_ok(r.on_pad, "仍然停在发射台上")
	_ok(absf(r.altitude()) < 20.0, "高度没有漂移")

# ── 5) 燃料耗尽 ────────────────────────────────────────────
func _test_fuel_depletion() -> void:
	print("\n[5] 燃料耗尽后不应再有推力")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["sounding"], "earth")
	# 放到 100 km 高空再测，避免触地判定干扰
	r.pos = Vector2(0.0, Space.radius("earth") + 100000.0)
	r.vel = Vector2.ZERO
	r.on_pad = false
	for i in r.fuel.size():
		r.fuel[i] = 0.0
	r.step(1.0, 1.0, 0.0)
	var expect := -Space.gravity("earth", r.pos).length() * 1.0
	print("  空油箱满节流 1 s：垂直速度 %.2f m/s（预期 %.2f，即纯自由落体）"
		% [r.speed_vertical(), expect])
	_ok(absf(r.speed_vertical() - expect) < 0.3, "没有燃料时确实没有推力（只有重力）")

# ── 6) 开伞软着陆 ──────────────────────────────────────────
func _test_landing() -> void:
	print("\n[6] 开伞软着陆（1.5 km 高空、50 m/s 下坠）")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["sounding"], "earth")
	r.pos = Vector2(0.0, Space.radius("earth") + 1500.0)
	r.vel = Vector2(0.0, -50.0)
	r.on_pad = false
	r.max_altitude = 1500.0
	r.chute = true
	var t := 0.0
	var impact_v := 0.0
	var next_log := 0.0
	while t < 900.0 and r.state == "flying":
		impact_v = r.speed()
		r.step(0.02, 0.0, 0.0)
		t += 0.02
		if t >= next_log:
			next_log += 60.0
			print("    t=%5.0fs  高度=%8.2f m  速度=%6.2f  垂直=%7.2f  com=%.2f"
				% [t, r.altitude(), r.speed(), r.speed_vertical(), r.com_from_bottom()])
	print("  落地用时 %.1f s，触地速度 %.1f m/s，状态 %s" % [t, impact_v, r.state])
	_ok(r.state == "landed", "开伞后安全着陆（状态 landed）")
	_ok(impact_v < 12.0, "触地速度 %.1f m/s < 12 m/s（降落伞确实减速了）" % impact_v)

# ── 7) 高速撞击 ────────────────────────────────────────────
func _test_impact_crash() -> void:
	print("\n[7] 高速撞击（无伞、200 m/s 砸向地面）")
	var r := Rocket.new()
	r.setup(Parts.PRESETS["sounding"], "earth")
	r.pos = Vector2(0.0, Space.radius("earth") + 2000.0)
	r.vel = Vector2(0.0, -200.0)
	r.on_pad = false
	r.max_altitude = 2000.0
	var t := 0.0
	while t < 60.0 and r.state == "flying":
		r.step(0.02, 0.0, 0.0)
		t += 0.02
	print("  状态 %s，事件 %s" % [r.state, str(r.event_log)])
	_ok(r.state == "crashed", "高速触地判定为坠毁")

# ── 8) 轨道数学 ────────────────────────────────────────────
func _test_orbit_math() -> void:
	print("\n[8] 轨道力学")
	var R := Space.radius("earth")
	var vc := Space.circular_speed("earth", R + 100000.0)
	print("  100 km 圆轨道速度 = %.1f m/s（应为 7845 左右）" % vc)
	_ok(absf(vc - 7845.0) < 15.0, "圆轨道速度正确")
	var el := Space.orbital_elements("earth", Vector2(0, R + 100000.0), Vector2(vc, 0))
	print("  圆轨道 e=%.5f  apo=%.1f km  peri=%.1f km"
		% [el["e"], (el["apo"] - R) / 1000.0, (el["peri"] - R) / 1000.0])
	_ok(float(el["e"]) < 0.01, "圆轨道偏心率接近 0")
	var pts := Space.sample_orbit("earth", Vector2(0, R + 100000.0), Vector2(vc, 0), 60)
	print("  轨道采样点数 = %d" % pts.size())
	_ok(pts.size() > 50, "解析轨道采样正常")
