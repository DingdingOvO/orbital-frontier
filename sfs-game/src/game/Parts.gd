extends RefCounted
class_name Parts
## 零件库 — 全部为原创数值，单位：kg / m / N / s
## 尺寸以"米"为单位，直接进入物理世界（地球半径 6371 km）。

const DEFS := {
	"pod": {
		"name_key": "part.capsule", "cat": "command", "kind": "pod",
		"dry_mass": 840.0, "fuel": 0.0, "w": 1.4, "h": 1.5,
		"crew": 1, "ctrl": true,
	},
	"nose": {
		"name_key": "part.nose", "cat": "aero", "kind": "nose",
		"dry_mass": 90.0, "fuel": 0.0, "w": 1.4, "h": 1.1,
	},
	"chute": {
		"name_key": "part.chute", "cat": "aero", "kind": "chute",
		"dry_mass": 70.0, "fuel": 0.0, "w": 1.4, "h": 0.6,
		"cd_chute": 1200.0,  # 开伞后的等效阻力面积 Cd·A (m²)，终端速度约 7 m/s
	},
	"tank_s": {
		"name_key": "part.tank_s", "cat": "fuel", "kind": "tank",
		"dry_mass": 320.0, "fuel": 2400.0, "w": 1.4, "h": 2.6,
	},
	"tank_m": {
		"name_key": "part.tank_m", "cat": "fuel", "kind": "tank",
		"dry_mass": 900.0, "fuel": 24000.0, "w": 1.9, "h": 4.2,
	},
	"tank_l": {
		"name_key": "part.tank_l", "cat": "fuel", "kind": "tank",
		"dry_mass": 1400.0, "fuel": 40000.0, "w": 2.5, "h": 6.6,
	},
	"engine_s": {
		"name_key": "part.engine_s", "cat": "engine", "kind": "engine",
		"dry_mass": 220.0, "fuel": 0.0, "w": 1.4, "h": 1.0,
		"thrust": 60000.0, "isp_vac": 300.0, "isp_atm": 255.0,
	},
	"engine_m": {
		"name_key": "part.engine_m", "cat": "engine", "kind": "engine",
		"dry_mass": 700.0, "fuel": 0.0, "w": 1.9, "h": 1.7,
		"thrust": 790000.0, "isp_vac": 350.0, "isp_atm": 300.0,
	},
	"engine_vac": {
		"name_key": "part.engine_vac", "cat": "engine", "kind": "engine",
		"dry_mass": 450.0, "fuel": 0.0, "w": 1.6, "h": 1.5,
		"thrust": 220000.0, "isp_vac": 380.0, "isp_atm": 120.0,
	},
	"engine_h": {
		"name_key": "part.engine_h", "cat": "engine", "kind": "engine",
		"dry_mass": 2200.0, "fuel": 0.0, "w": 2.5, "h": 2.2,
		"thrust": 1300000.0, "isp_vac": 320.0, "isp_atm": 285.0,
	},
	"decoupler": {
		"name_key": "part.decoupler", "cat": "struct", "kind": "decoupler",
		"dry_mass": 45.0, "fuel": 0.0, "w": 1.9, "h": 0.5,
	},
	"fin": {
		"name_key": "part.fin", "cat": "aero", "kind": "fin",
		"dry_mass": 55.0, "fuel": 0.0, "w": 0.35, "h": 1.3,
	},
	"legs": {
		"name_key": "part.legs", "cat": "struct", "kind": "legs",
		"dry_mass": 110.0, "fuel": 0.0, "w": 0.4, "h": 1.1,
	},
}

## 建造面板中的显示顺序
const PALETTE := [
	"pod", "nose", "chute",
	"tank_s", "tank_m", "tank_l",
	"engine_s", "engine_m", "engine_vac", "engine_h",
	"decoupler", "fin", "legs",
]

## 预设火箭（数组顺序 = 从顶到底）
## sounding 推重比 1.59 / Δv 2.9 km/s；orbiter 1.37 / Δv 10.0 km/s；lunar 1.48 / Δv 12.7 km/s
const PRESETS := {
	"sounding": ["pod", "chute", "tank_s", "engine_s"],
	"orbiter": ["pod", "chute", "tank_m", "engine_m", "decoupler", "tank_m", "engine_m"],
	"lunar": ["pod", "chute", "tank_m", "engine_vac", "decoupler", "tank_m", "engine_m", "decoupler", "tank_l", "engine_h"],
}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})

static func dry_mass(id: String) -> float:
	return float(DEFS.get(id, {}).get("dry_mass", 0.0))

static func fuel_cap(id: String) -> float:
	return float(DEFS.get(id, {}).get("fuel", 0.0))

static func height(id: String) -> float:
	return float(DEFS.get(id, {}).get("h", 1.0))

static func width(id: String) -> float:
	return float(DEFS.get(id, {}).get("w", 1.0))

static func is_engine(id: String) -> bool:
	return str(DEFS.get(id, {}).get("kind", "")) == "engine"

static func is_decoupler(id: String) -> bool:
	return str(DEFS.get(id, {}).get("kind", "")) == "decoupler"

static func is_tank(id: String) -> bool:
	return str(DEFS.get(id, {}).get("kind", "")) == "tank"

## 计算一堆零件的汇总参数（干质量 / 燃料 / 总高 / 最大宽度）
static func summarize(parts: Array) -> Dictionary:
	var dry := 0.0
	var fuel := 0.0
	var h := 0.0
	var w := 0.0
	for id in parts:
		dry += dry_mass(id)
		fuel += fuel_cap(id)
		h += height(id)
		w = max(w, width(id))
	return {"dry": dry, "fuel": fuel, "mass": dry + fuel, "height": h, "width": w}

## 按分离器把零件切成级（从底部起为第 1 级）
## 返回 Array[Array[int]]，每个元素是一级的零件索引数组，索引顺序与 parts 相同
static func stages_of(parts: Array) -> Array:
	var groups: Array = []
	var cur: Array = []
	# 从底部（数组末尾）往上
	for i in range(parts.size() - 1, -1, -1):
		var id: String = parts[i]
		if is_decoupler(id):
			if not cur.is_empty():
				groups.append(cur)
				cur = []
			continue
		cur.append(i)
	if not cur.is_empty():
		groups.append(cur)
	if groups.is_empty():
		groups.append([])
	return groups
