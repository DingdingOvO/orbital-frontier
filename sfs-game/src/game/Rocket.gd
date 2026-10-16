extends RefCounted
class_name Rocket
## 火箭刚体 + 飞行物理（2D / SI 单位）
## pos 为「质心」相对行星中心的位置；angle 为相对局部天顶的转角（0 = 竖直向上）

const G0 := 9.80665
const MAX_STEER_RATE := 1.4          # rad/s，最大姿态角速度
const STEER_ACCEL := 2.6             # rad/s²，姿态角加速度（越大越跟手）
const CRASH_SPEED := 12.0            # m/s，触地速度超过即坠毁
const BASE_CD := 0.38                # 箭体阻力系数（需乘以迎风面积）
const CHUTE_FALLBACK_AREA := 800.0   # 降落伞等效阻力面积 Cd·A (m²) 的兜底值

var parts: Array = []                # 零件 id，从顶到底
var fuel: Array = []                 # 每个零件当前燃料（kg）
var alive_part: Array = []           # 是否仍在箭上

## 位置：float32 渲染缓存 + float64 精确积分值
## 关键：Godot 的 Vector2 是 32 位浮点，在 6.37e6 m 量级下最小步进约 0.5 m，
## 每帧只有零点几米的低速位移会被直接舍入掉（降落伞下降、悬停全部失效）。
## 因此物理积分必须走双精度分量，Vector2 只用于渲染与几何计算。
var pos := Vector2.ZERO:
	set(v):
		if not _internal_write:
			_px = v.x
			_py = v.y
		pos = v
var _px := 0.0
var _py := 0.0
var _internal_write := false
var vel := Vector2.ZERO
var angle := 0.0                     # 相对天顶的倾角
var spin := 0.0                      # 当前角速度

var body_id := "earth"
var stages: Array = []               # [[零件索引...], ...] 从底到顶
var active_stage := 0

var throttle := 0.0
var chute := false
var state := "flying"                # flying / landed / crashed
var on_pad := true                   # 仍在发射台上（未真正起飞）

var mission_time := 0.0
var max_altitude := 0.0
var max_speed := 0.0
var event_log: Array = []

# ── 初始化 ────────────────────────────────────────────────
func setup(design: Array, b_id: String = "earth") -> void:
	parts = design.duplicate()
	body_id = b_id
	fuel.clear()
	alive_part.clear()
	for id in parts:
		fuel.append(Parts.fuel_cap(id))
		alive_part.append(true)
	stages = Parts.stages_of(parts)
	active_stage = 0
	angle = 0.0
	spin = 0.0
	throttle = 0.0
	chute = false
	state = "flying"
	mission_time = 0.0
	max_altitude = 0.0
	max_speed = 0.0
	event_log = []
	var R := Space.radius(body_id)
	# 质心高度 = 地面半径 + 质心到箭底的距离 + 1 m 支撑间隙
	# （旧实现写死 R+3，比质心到底部的距离还小，导致第 1 帧就判定箭体穿地 → 直接"已着陆"）
	pos = Vector2(0.0, R + com_from_bottom() + 1.0)
	vel = Vector2.ZERO
	on_pad = true

# ── 质量与几何 ────────────────────────────────────────────
func total_mass() -> float:
	var m := 0.0
	for i in parts.size():
		if alive_part[i]:
			m += Parts.dry_mass(parts[i]) + fuel[i]
	return m

func stack_mass() -> float:
	var m := 0.0
	for i in parts.size():
		if alive_part[i]:
			m += Parts.dry_mass(parts[i])
	return m

## 质心到「当前火箭底部」的距离（米）
func com_from_bottom() -> float:
	var y := 0.0
	var s := 0.0
	var tot := 0.0
	for i in range(parts.size() - 1, -1, -1):
		if not alive_part[i]:
			continue
		var h := Parts.height(parts[i])
		var m: float = Parts.dry_mass(parts[i]) + float(fuel[i])
		s += m * (y + h * 0.5)
		tot += m
		y += h
	return s / tot if tot > 0.0 else 0.0

## 当前存活箭体的总高度
func stack_height() -> float:
	var y := 0.0
	for i in range(parts.size() - 1, -1, -1):
		if alive_part[i]:
			y += Parts.height(parts[i])
	return y

## 返回从底到顶的零件布局，供渲染使用
## [{idx, bottom, top, center, w, h, kind, id}]
func layout() -> Array:
	var out: Array = []
	var y := 0.0
	for i in range(parts.size() - 1, -1, -1):
		if not alive_part[i]:
			continue
		var h := Parts.height(parts[i])
		out.append({
			"idx": i, "bottom": y, "top": y + h, "center": y + h * 0.5,
			"w": Parts.width(parts[i]), "h": h,
			"kind": str(Parts.def(parts[i]).get("kind", "")),
			"id": parts[i],
		})
		y += h
	return out

func cross_section() -> float:
	var w := 0.0
	for i in parts.size():
		if alive_part[i]:
			w = max(w, Parts.width(parts[i]))
	return PI * pow(w * 0.5, 2.0)

# ── 推力 ──────────────────────────────────────────────────
func stage_parts(idx: int) -> Array:
	if idx < 0 or idx >= stages.size():
		return []
	return stages[idx]

func active_engines() -> Array:
	var out: Array = []
	for i in stage_parts(active_stage):
		if alive_part[i] and Parts.is_engine(parts[i]):
			out.append(i)
	return out

func engine_count_total() -> int:
	var n := 0
	for i in parts.size():
		if alive_part[i] and Parts.is_engine(parts[i]):
			n += 1
	return n

func max_thrust() -> float:
	var t := 0.0
	for i in active_engines():
		t += float(Parts.def(parts[i]).get("thrust", 0.0))
	return t

func stage_fuel() -> float:
	var f := 0.0
	for i in stage_parts(active_stage):
		if alive_part[i]:
			f += fuel[i]
	return f

func stage_fuel_cap() -> float:
	var f := 0.0
	for i in stage_parts(active_stage):
		if alive_part[i]:
			f += Parts.fuel_cap(parts[i])
	return f

func total_fuel() -> float:
	var f := 0.0
	for i in parts.size():
		if alive_part[i]:
			f += fuel[i]
	return f

## 比冲：按大气密度在真空/海平面之间线性插值
func current_isp(sample_pos: Vector2 = pos) -> float:
	var alt := sample_pos.length() - Space.radius(body_id)
	var rho := Space.density(body_id, alt)
	var rho0 := max(1e-6, float(Space.body(body_id).get("rho0", 1.225)))
	var out := 0.0
	var n := 0
	for i in active_engines():
		var d := Parts.def(parts[i])
		var isp_v := float(d.get("isp_vac", 300.0))
		var isp_a := float(d.get("isp_atm", 250.0))
		var k := clampf(rho / rho0, 0.0, 1.0)
		out += lerpf(isp_v, isp_a, k)
		n += 1
	return out / n if n > 0 else 300.0

func thrust_to_weight() -> float:
	var m := total_mass()
	if m <= 0.0:
		return 0.0
	var r := pos.length()
	var g := Space.mu(body_id) / (r * r)
	return max_thrust() / (m * g)

## Δv（理想，含所有级，依次消耗）
func delta_v() -> float:
	var dv := 0.0
	for si in stages.size():
		var dry := 0.0
		var fuel_kg := 0.0
		for i in stages[si]:
			dry += Parts.dry_mass(parts[i])
			fuel_kg += Parts.fuel_cap(parts[i])
		# 该级之上的质量（更靠前的级）
		var upper := 0.0
		for sj in range(si + 1, stages.size()):
			for i in stages[sj]:
				upper += Parts.dry_mass(parts[i]) + Parts.fuel_cap(parts[i])
		var m0 := dry + fuel_kg + upper
		var m1 := dry + upper
		if m1 > 0.0 and m0 > m1:
			var isp := 300.0
			# 用该级引擎的平均真空比冲
			var n := 0
			var s := 0.0
			for i in stages[si]:
				if Parts.is_engine(parts[i]):
					s += float(Parts.def(parts[i]).get("isp_vac", 300.0))
					n += 1
			if n > 0:
				isp = s / n
			dv += isp * G0 * log(m0 / m1)
	return dv

# ── 燃料消耗 ──────────────────────────────────────────────
## 消耗燃料，返回实际消耗量（kg）
func _burn(mdot_dt: float) -> float:
	var tanks: Array = []
	var avail := 0.0
	for i in stage_parts(active_stage):
		if alive_part[i] and fuel[i] > 0.0:
			tanks.append(i)
			avail += fuel[i]
	if avail <= 0.0:
		return 0.0
	var take: float = minf(avail, mdot_dt)
	for i in tanks:
		fuel[i] = max(0.0, fuel[i] - take * (fuel[i] / avail))
	return take

## 把双精度积分结果写回 float32 渲染缓存（不反向覆盖精确值）
func _flush() -> void:
	_internal_write = true
	pos = Vector2(_px, _py)
	_internal_write = false

## 双精度的地心距
func _radius_f() -> float:
	return sqrt(_px * _px + _py * _py)

# ── 主步进 ────────────────────────────────────────────────
## steer: -1..1 姿态输入；dt: 秒
func step(dt: float, throttle_in: float, steer: float) -> void:
	if state != "flying":
		return
	mission_time += dt
	throttle = clampf(throttle_in, 0.0, 1.0)

	# 姿态：先平滑角加速度逼近目标角速度，再积分（直接赋值角速度会显得很"硬"）
	var target_rate: float = steer * MAX_STEER_RATE
	spin = move_toward(spin, target_rate, STEER_ACCEL * dt)
	spin = clampf(spin, -MAX_STEER_RATE, MAX_STEER_RATE)
	angle += spin * dt

	var r := _radius_f()
	var alt := r - Space.radius(body_id)
	max_altitude = max(max_altitude, alt)
	if max_altitude > 30.0:
		on_pad = false
	max_speed = max(max_speed, vel.length())

	var up := Vector2(_px / r, _py / r)
	var dir := up.rotated(angle)
	var m := total_mass()
	if m <= 1e-6:
		return

	var acc := Space.gravity(body_id, Vector2(_px, _py))

	# 推力：燃料耗尽即不再产生推力（旧实现烧完油还在推）
	if throttle > 0.0:
		var th := max_thrust() * throttle
		if th > 0.0 and stage_fuel() > 0.0:
			var isp := current_isp()
			if isp > 1.0:
				var want := (th / (isp * G0)) * dt
				var got := _burn(want)
				var frac: float = (got / want) if want > 1e-12 else 0.0
				acc += dir * (th * frac / m)

	# 大气阻力
	var rho := Space.density(body_id, alt)
	if rho > 0.0:
		var v := vel.length()
		if v > 0.01:
			# 开伞时用伞的等效阻力面积（几十~几百 m²），而不是细小的箭体迎风面积
			var cd_area: float = chute_area() if chute else BASE_CD * cross_section()
			var drag := 0.5 * rho * v * v * cd_area
			acc += -vel.normalized() * (drag / m)

	# 半隐式欧拉积分（位置走双精度，避免低速位移被 float32 吃掉）
	vel += acc * dt
	_px += float(vel.x) * dt
	_py += float(vel.y) * dt
	_flush()

	# 触地判定
	var bottom_r := _radius_f() - com_from_bottom()
	if bottom_r <= Space.radius(body_id):
		_impact()

func _impact() -> void:
	var ground := Space.radius(body_id) + com_from_bottom()
	var rl := _radius_f()
	if rl > 1.0:
		_px = (_px / rl) * ground
		_py = (_py / rl) * ground
	_flush()
	var spd := vel.length()
	vel = Vector2.ZERO
	# 还没真正起飞（一直在发射台上）：只是停稳，不算着陆事件
	if on_pad:
		spin = 0.0
		angle = 0.0
		return
	# 用总速度判定（已包含垂直与水平分量），阈值内算软着陆
	if spd <= CRASH_SPEED:
		state = "landed"
		event_log.append({"t": mission_time, "e": "landed", "v": spd})
	else:
		state = "crashed"
		event_log.append({"t": mission_time, "e": "crashed", "v": spd})

# ── 操作 ──────────────────────────────────────────────────
func separate() -> bool:
	if active_stage + 1 >= stages.size():
		return false
	for i in stage_parts(active_stage):
		alive_part[i] = false
	active_stage += 1
	event_log.append({"t": mission_time, "e": "separate", "s": active_stage})
	return true

func deploy_chute() -> bool:
	for i in parts.size():
		if alive_part[i] and str(Parts.def(parts[i]).get("kind", "")) == "chute":
			chute = true
			event_log.append({"t": mission_time, "e": "chute"})
			return true
	return false

func has_chute() -> bool:
	for i in parts.size():
		if alive_part[i] and str(Parts.def(parts[i]).get("kind", "")) == "chute":
			return true
	return false

## 所有存活降落伞的等效阻力面积之和 Cd·A (m²)
func chute_area() -> float:
	var a := 0.0
	for i in parts.size():
		if alive_part[i] and str(Parts.def(parts[i]).get("kind", "")) == "chute":
			a += float(Parts.def(parts[i]).get("cd_chute", CHUTE_FALLBACK_AREA))
	return a if a > 0.0 else CHUTE_FALLBACK_AREA

# ── 读数 ──────────────────────────────────────────────────
func altitude() -> float:
	return _radius_f() - Space.radius(body_id)

func speed() -> float:
	return vel.length()

func speed_vertical() -> float:
	return vel.dot(pos.normalized())

func speed_horizontal() -> float:
	var up := pos.normalized()
	return vel.dot(Vector2(-up.y, up.x))

func elements() -> Dictionary:
	return Space.orbital_elements(body_id, pos, vel)

func is_in_orbit() -> bool:
	var el := elements()
	# 近地点必须高于大气层顶（80 km），否则会再入烧毁，不算入轨
	return float(el.get("peri", 0.0)) > Space.radius(body_id) + 80000.0

# ── 存档 ──────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"parts": parts, "fuel": fuel, "alive": alive_part,
		"pos": [pos.x, pos.y], "vel": [vel.x, vel.y],
		"angle": angle, "body": body_id, "active_stage": active_stage,
		"chute": chute, "state": state, "t": mission_time,
	}

func from_dict(d: Dictionary) -> void:
	parts = d.get("parts", [])
	fuel = d.get("fuel", [])
	alive_part = d.get("alive", [])
	var p: Array = d.get("pos", [0, 0])
	var v: Array = d.get("vel", [0, 0])
	pos = Vector2(p[0], p[1])
	vel = Vector2(v[0], v[1])
	angle = float(d.get("angle", 0.0))
	body_id = str(d.get("body", "earth"))
	active_stage = int(d.get("active_stage", 0))
	chute = bool(d.get("chute", false))
	state = str(d.get("state", "flying"))
	mission_time = float(d.get("t", 0.0))
	stages = Parts.stages_of(parts)
