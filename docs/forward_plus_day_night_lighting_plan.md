# Forward+ 场景光源数量优化与日出日落光照系统方案

## 0. 目标

本方案用于指导 Codex 在当前 Godot 4.6 项目中实现一套新的 Forward+ 光照管理系统。

本轮只处理两件事：

1. 优化场景真实光源数量，降低 Forward+ 下的实时点光源开销。
2. 增加从早到晚的时间光照变化，实现日出、白天、黄昏、夜晚的光照强度和色调变化。

本轮不要改渲染器。项目继续使用：

```ini
[rendering]
renderer/rendering_method="forward_plus"
```

本轮也不要大规模重做场景构图、装饰物布局、棋盘模型、UI 结构。后续可以再单独做“场景光照布置美术优化”。

---

## 1. 当前问题判断

当前 `BackgroundManager.gd` 已经有较完整的环境构建和光照参数系统，但真实光源数量偏多，且夜晚配置中存在“很多地方在发光，但主体棋盘层次仍然偏灰、偏糊”的问题。

当前光源结构大致包括：

- `BackgroundSun`：1 个 `DirectionalLight3D`。
- `SoftFillLight`：1 个 `DirectionalLight3D`。
- `BoardFill_0~3`：4 个棋盘补光 `OmniLight3D`。
- `BoardGlow_0~18`：约 19 个棋盘发光点，每个包含一个 `GlowDot` 网格和一个 `GlowLight` 点光。
- `ForestRim_0~5`：6 个森林边缘 `OmniLight3D`。
- 四角地标光源：通过 `_add_landmark_light()` 添加，加入 `_mood_lights`。
- 花园环灯笼光源：通过 `_add_garden_glow()` 添加，若内部也是 `OmniLight3D`，也属于真实光源开销。
- 萤火虫层：当前看起来主要是发光网格，不一定是真实光源，可以保留。

核心问题不是 Forward+ 不能做夜晚，而是当前装饰性点光太多，真实照明与装饰发光没有分层：

- 棋盘周围很多 glow spot 实际上更适合做“发光贴片”，不应该默认全部作为真实光源参与照明。
- 森林边缘光和地标光可以作为夜晚氛围，但不应该在所有档位、所有时间都满数量启用。
- 白天不需要绝大多数装饰性点光。
- 黄昏和夜晚才需要灯笼、萤火虫、棋盘边缘光逐渐增强。

---

## 2. 实现总原则

### 2.1 保持 Forward+ 不变

不要切换到 `mobile` 或 `gl_compatibility`。本轮所有优化都在 Forward+ 内完成。

### 2.2 区分“真实光源”和“假发光”

真实光源包括：

- `DirectionalLight3D`
- `OmniLight3D`
- `SpotLight3D`

假发光包括：

- `StandardMaterial3D.emission_enabled = true`
- `SHADING_MODE_UNSHADED` 的发光网格
- 透明叠加圆片
- billboard 发光点

原则：

```text
能用假发光表达氛围的，不使用真实 OmniLight。
只有确实需要照亮棋盘、地标、空间轮廓时，才启用真实光源。
```

### 2.3 棋盘主体优先

无论早晚，棋盘和棋子必须可读。夜晚可以暗，但不能让棋子、目标格、技能标记、行动提示淹没在草地和雾里。

优先保证：

1. 棋盘轮廓清晰。
2. 棋子颜色可识别。
3. 当前选中、可移动格、技能标记清楚。
4. 背景氛围其次。

---

## 3. 光源数量优化方案

### 3.1 新增光源预算系统

在 `BackgroundManager.gd` 中新增一个轻量光源预算配置。

建议新增：

```gdscript
const LIGHT_BUDGETS := {
	"high": {
		"board_fill_count": 4,
		"board_glow_real_light_count": 8,
		"forest_rim_count": 6,
		"mood_light_count": 8,
		"garden_glow_real_light_count": 6,
	},
	"medium": {
		"board_fill_count": 2,
		"board_glow_real_light_count": 4,
		"forest_rim_count": 3,
		"mood_light_count": 4,
		"garden_glow_real_light_count": 3,
	},
	"low": {
		"board_fill_count": 1,
		"board_glow_real_light_count": 0,
		"forest_rim_count": 0,
		"mood_light_count": 2,
		"garden_glow_real_light_count": 0,
	}
}
```

`high / medium / low` 应该和已有的 Forward+ 渲染开销档联动。如果上一份文档中的渲染开销档已经实现，则直接复用当前开销档 ID；如果还没有实现，先在 `BackgroundManager.gd` 里保留 `_render_cost_profile_id := "high"`。

### 3.2 给每类光源打分类 metadata

创建光源时给节点设置 metadata，方便统一控制：

```gdscript
light.set_meta("light_group", "board_fill")
light.set_meta("priority", index)
```

建议分类：

```text
board_fill        棋盘补光
board_glow        棋盘装饰发光点里的真实点光
forest_rim        森林边缘轮廓光
mood              地标/灯笼/喷泉氛围光
garden_glow       花园环灯笼光
```

所有真实 `OmniLight3D` 都必须至少有：

```gdscript
light.shadow_enabled = false
```

除非后续明确要做单个主视觉光源的阴影，否则装饰性点光禁止开阴影。

### 3.3 棋盘 Glow Spot 默认改成假发光优先

当前每个 `BoardGlow` 里都有一个 `GlowDot` 和一个 `GlowLight`。本轮保留 `GlowDot`，但按预算启用少量 `GlowLight`。

实现方式：

```gdscript
func _refresh_light_budget() -> void:
	var budget := LIGHT_BUDGETS.get(_render_cost_profile_id, LIGHT_BUDGETS["high"])
	_apply_light_group_budget(_board_fill_lights, int(budget.get("board_fill_count", 4)))
	_apply_board_glow_light_budget(int(budget.get("board_glow_real_light_count", 8)))
	_apply_light_group_budget(_forest_rim_lights, int(budget.get("forest_rim_count", 6)))
	_apply_light_group_budget(_mood_lights, int(budget.get("mood_light_count", 8)))
```

注意：

- 即使某个 `BoardGlow` 的真实点光被禁用，`GlowDot` 网格仍然可以显示。
- `GlowDot` 的透明度和 emission 仍然由 `board_glow_energy` 控制。
- 低档下 `board_glow_real_light_count = 0`，但棋盘边缘依然有假发光，不会完全失去氛围。

### 3.4 禁用光源时不要删除节点

为了避免运行时频繁创建/销毁节点，只做：

```gdscript
light.visible = false
light.light_energy = 0.0
```

启用时再恢复：

```gdscript
light.visible = true
light.light_energy = computed_energy
```

不要在切换档位时 `queue_free()`。

### 3.5 白天关闭大部分装饰点光

后续时间系统会根据时间给每组光源一个时间倍率。即使高画质档允许 8 个棋盘真实 glow light，白天也应该几乎不亮。

新增时间倍率：

```gdscript
_time_light_multipliers = {
	"board_glow": 0.0 ~ 1.0,
	"forest_rim": 0.0 ~ 1.0,
	"mood": 0.0 ~ 1.0,
	"firefly": 0.0 ~ 1.0,
}
```

---

## 4. 日出日落时间光照系统

### 4.1 新增时间字段

在 `BackgroundManager.gd` 中新增：

```gdscript
@export var time_of_day := 12.0
@export var auto_time_cycle_enabled := false
@export var day_length_seconds := 240.0
@export var time_transition_speed := 4.0
```

含义：

```text
time_of_day: 0.0 ~ 24.0，单位为小时。
auto_time_cycle_enabled: 是否自动循环一天。
day_length_seconds: 游戏内一天对应现实秒数。
time_transition_speed: 手动切换时间预设时的平滑速度。
```

默认建议：

```gdscript
var _time_of_day_target := 12.0
var _time_settings: Dictionary = {}
```

### 4.2 时间关键帧

新增：

```gdscript
const TIME_OF_DAY_KEYFRAMES := [
	{
		"time": 0.0,
		"label": "深夜",
		"sun_energy": 0.0,
		"ambient_energy": 0.28,
		"fill_energy": 0.025,
		"exposure": 0.82,
		"fog_density": 0.010,
		"fog_sky_affect": 0.42,
		"sun_pitch": -72.0,
		"sun_yaw": -160.0,
		"sun_color": Color(0.48, 0.58, 0.86),
		"fill_color": Color(0.32, 0.42, 0.72),
		"sky_top": Color(0.015, 0.025, 0.06),
		"sky_horizon": Color(0.05, 0.07, 0.12),
		"floor_tint": Color(0.22, 0.34, 0.22),
		"board_glow_energy": 0.22,
		"marker_glow_energy": 0.95,
		"firefly_energy": 1.0,
		"mood_light_scale": 1.0,
		"forest_rim_scale": 0.85,
	},
	{
		"time": 5.5,
		"label": "日出",
		"sun_energy": 0.035,
		"ambient_energy": 0.42,
		"fill_energy": 0.035,
		"exposure": 0.88,
		"fog_density": 0.009,
		"fog_sky_affect": 0.36,
		"sun_pitch": -12.0,
		"sun_yaw": -118.0,
		"sun_color": Color(1.0, 0.58, 0.32),
		"fill_color": Color(0.55, 0.62, 0.86),
		"sky_top": Color(0.18, 0.22, 0.42),
		"sky_horizon": Color(1.0, 0.58, 0.34),
		"floor_tint": Color(0.36, 0.48, 0.28),
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.84,
		"firefly_energy": 0.55,
		"mood_light_scale": 0.65,
		"forest_rim_scale": 0.55,
	},
	{
		"time": 9.0,
		"label": "上午",
		"sun_energy": 0.075,
		"ambient_energy": 0.72,
		"fill_energy": 0.045,
		"exposure": 0.92,
		"fog_density": 0.004,
		"fog_sky_affect": 0.22,
		"sun_pitch": -30.0,
		"sun_yaw": -132.0,
		"sun_color": Color(1.0, 0.86, 0.68),
		"fill_color": Color(0.78, 0.86, 1.0),
		"sky_top": Color(0.20, 0.42, 0.70),
		"sky_horizon": Color(0.58, 0.76, 0.86),
		"floor_tint": Color(0.54, 0.78, 0.42),
		"board_glow_energy": 0.08,
		"marker_glow_energy": 0.72,
		"firefly_energy": 0.0,
		"mood_light_scale": 0.1,
		"forest_rim_scale": 0.15,
	},
	{
		"time": 12.5,
		"label": "正午",
		"sun_energy": 0.09,
		"ambient_energy": 0.78,
		"fill_energy": 0.04,
		"exposure": 0.94,
		"fog_density": 0.0025,
		"fog_sky_affect": 0.16,
		"sun_pitch": -55.0,
		"sun_yaw": -150.0,
		"sun_color": Color(1.0, 0.96, 0.86),
		"fill_color": Color(0.82, 0.9, 1.0),
		"sky_top": Color(0.18, 0.48, 0.86),
		"sky_horizon": Color(0.68, 0.84, 0.94),
		"floor_tint": Color(0.58, 0.84, 0.46),
		"board_glow_energy": 0.045,
		"marker_glow_energy": 0.68,
		"firefly_energy": 0.0,
		"mood_light_scale": 0.0,
		"forest_rim_scale": 0.0,
	},
	{
		"time": 17.5,
		"label": "黄昏",
		"sun_energy": 0.055,
		"ambient_energy": 0.54,
		"fill_energy": 0.04,
		"exposure": 0.88,
		"fog_density": 0.0065,
		"fog_sky_affect": 0.32,
		"sun_pitch": -14.0,
		"sun_yaw": -40.0,
		"sun_color": Color(1.0, 0.46, 0.22),
		"fill_color": Color(0.46, 0.54, 0.84),
		"sky_top": Color(0.16, 0.22, 0.44),
		"sky_horizon": Color(1.0, 0.42, 0.24),
		"floor_tint": Color(0.42, 0.52, 0.30),
		"board_glow_energy": 0.16,
		"marker_glow_energy": 0.88,
		"firefly_energy": 0.45,
		"mood_light_scale": 0.6,
		"forest_rim_scale": 0.45,
	},
	{
		"time": 21.0,
		"label": "夜晚",
		"sun_energy": 0.0,
		"ambient_energy": 0.32,
		"fill_energy": 0.03,
		"exposure": 0.82,
		"fog_density": 0.010,
		"fog_sky_affect": 0.45,
		"sun_pitch": -68.0,
		"sun_yaw": 40.0,
		"sun_color": Color(0.42, 0.52, 0.86),
		"fill_color": Color(0.28, 0.36, 0.72),
		"sky_top": Color(0.015, 0.025, 0.06),
		"sky_horizon": Color(0.04, 0.06, 0.12),
		"floor_tint": Color(0.20, 0.32, 0.22),
		"board_glow_energy": 0.24,
		"marker_glow_energy": 1.0,
		"firefly_energy": 1.0,
		"mood_light_scale": 1.0,
		"forest_rim_scale": 0.85,
	},
	{
		"time": 24.0,
		"label": "深夜",
		"same_as": 0.0,
	},
]
```

`24.0` 可以在实际实现时展开成和 `0.0` 一样的字段，或者在采样函数里特殊处理。

### 4.3 时间采样函数

新增函数：

```gdscript
func _sample_time_of_day_settings(hour: float) -> Dictionary:
	# 1. 将 hour wrap 到 0.0 ~ 24.0。
	# 2. 找到前后两个 keyframe。
	# 3. 计算 t。
	# 4. 对 float 参数 lerp。
	# 5. 对 Color 参数 lerp。
	# 6. 返回混合后的 Dictionary。
```

需要支持的插值类型：

```gdscript
if a is Color and b is Color:
	result[key] = (a as Color).lerp(b as Color, t)
elif typeof(a) in [TYPE_FLOAT, TYPE_INT]:
	result[key] = lerpf(float(a), float(b), t)
else:
	result[key] = b
```

### 4.4 应用时间光照

新增：

```gdscript
func set_time_of_day(hour: float, immediate := false) -> void:
	_time_of_day_target = wrapf(hour, 0.0, 24.0)
	if immediate:
		time_of_day = _time_of_day_target
		_apply_time_of_day()
```

新增：

```gdscript
func _process(delta: float) -> void:
	if auto_time_cycle_enabled:
		time_of_day = wrapf(time_of_day + 24.0 * delta / maxf(day_length_seconds, 1.0), 0.0, 24.0)
		_apply_time_of_day()
	else:
		var diff := _shortest_hour_delta(time_of_day, _time_of_day_target)
		if absf(diff) > 0.01:
			time_of_day = wrapf(time_of_day + diff * minf(delta * time_transition_speed, 1.0), 0.0, 24.0)
			_apply_time_of_day()
```

注意：时间变化不要每帧调用完整 `_refresh_lighting_nodes()` 造成不必要开销。建议将 `_refresh_lighting_nodes()` 拆成两层：

```gdscript
func _refresh_static_lighting_nodes() -> void:
	# 画质档、渲染开销档、SSAO、render_scale、MSAA 等不需要每帧变的内容。

func _refresh_dynamic_time_lighting() -> void:
	# sun energy/color/rotation、ambient、exposure、fog、firefly、mood scale 等时间变化内容。
```

如果为了先快速实现，也可以继续调用 `_refresh_lighting_nodes()`，但后续要拆分优化。

---

## 5. 基础光照设置与时间设置的合成关系

当前项目已经有 `LIGHTING_PRESETS`，包含 `ambient_energy`、`sun_energy`、`fill_energy`、`exposure`、`ssao_intensity`、`render_scale`、`board_glow_energy` 等参数。

新增时间系统后，不建议直接覆盖 `_lighting_settings`，否则原来的光照预设和渲染开销档会互相污染。

推荐结构：

```gdscript
var _base_lighting_settings: Dictionary = {}
var _time_lighting_settings: Dictionary = {}
var _final_lighting_settings: Dictionary = {}
```

合成规则：

```text
_base_lighting_settings：来自光照预设 / 渲染开销档。
_time_lighting_settings：来自当前 time_of_day。
_final_lighting_settings：实际应用到 Environment 和 Light 节点。
```

对于光照强度类参数，时间系统可以覆盖：

```text
ambient_energy
sun_energy
fill_energy
exposure
fog_density
fog_sky_affect
sun_pitch
sun_yaw
board_glow_energy
marker_glow_energy
firefly_energy
mood_light_scale
forest_rim_scale
floor_tint_r/g/b
```

对于渲染开销类参数，时间系统不要覆盖：

```text
render_scale
msaa_level
fxaa_enabled
taa_enabled
debanding_enabled
ssao_intensity
reflection_intensity
floor_normal_scale
```

也就是说，时间控制“光线表现”，渲染开销档控制“性能成本”。

---

## 6. 天空颜色更新

当前 `_build_world_environment()` 使用 `ProceduralSkyMaterial` 时写死了天空颜色。

需要新增变量：

```gdscript
var _procedural_sky_material: ProceduralSkyMaterial
```

创建时保存引用：

```gdscript
_procedural_sky_material = procedural
```

时间变化时更新：

```gdscript
if _procedural_sky_material != null:
	_procedural_sky_material.sky_top_color = time_settings.get("sky_top", _procedural_sky_material.sky_top_color)
	_procedural_sky_material.sky_horizon_color = time_settings.get("sky_horizon", _procedural_sky_material.sky_horizon_color)
	_procedural_sky_material.sky_energy_multiplier = computed_sky_energy
```

建议：

```gdscript
var sky_energy := clampf(float(time_settings.get("ambient_energy", 0.6)) * 0.95, 0.18, 0.9)
```

夜晚不要完全黑，否则棋盘可读性会变差。

---

## 7. 太阳角度和光照强度

时间系统里的 `sun_pitch` 应该有明确规则：

```text
日出 / 黄昏：pitch 接近 -12 ~ -18，低角度，颜色偏暖。
上午 / 下午：pitch -28 ~ -40，中等角度。
正午：pitch -50 ~ -60，高角度，颜色偏白。
夜晚：sun_energy = 0，pitch 不重要，可以作为月光方向备用。
```

夜晚如果希望有一点月光，不要用很高的 `sun_energy`，建议：

```gdscript
sun_energy = 0.005 ~ 0.015
sun_color = Color(0.42, 0.52, 0.86)
```

但从你当前截图看，夜晚已经有较多发光装饰，建议第一版夜晚 `sun_energy = 0.0`，靠 ambient + soft fill + 少量 mood lights 保持可读性。

---

## 8. UI 接入方案

在 `GameUI.gd` 中增加一个简单时间选择入口即可，不要先做复杂时间轴。

建议增加按钮：

```text
时间：日出
时间：上午
时间：正午
时间：黄昏
时间：夜晚
自动昼夜：开/关
```

新增 signal：

```gdscript
signal time_of_day_selected(hour: float)
signal auto_time_cycle_toggled(enabled: bool)
```

在 `GameManager.gd` 中连接：

```gdscript
ui.time_of_day_selected.connect(_on_time_of_day_selected)
ui.auto_time_cycle_toggled.connect(_on_auto_time_cycle_toggled)
```

实现：

```gdscript
func _on_time_of_day_selected(hour: float) -> void:
	if background_manager != null and background_manager.has_method("set_time_of_day"):
		background_manager.set_time_of_day(hour)

func _on_auto_time_cycle_toggled(enabled: bool) -> void:
	if background_manager != null:
		background_manager.auto_time_cycle_enabled = enabled
```

第一版可以只做快捷按钮，不做滑条。后续再加入 0~24 小时滑条。

---

## 9. 推荐第一版时间预设

UI 快捷按钮对应：

```text
日出：5.5
上午：9.0
正午：12.5
黄昏：17.5
夜晚：21.0
```

如果要保留当前夜晚配置，可以把当前夜晚调参结果映射到 `21.0` keyframe。

---

## 10. 光源预算与时间系统的结合

最终每个真实点光的能量应由三部分相乘：

```text
最终能量 = 基础能量 × 时间倍率 × 光源预算启用状态
```

例：

```gdscript
var mood_time_scale := float(_time_lighting_settings.get("mood_light_scale", 1.0))
var render_budget_enabled := light.visible
light.light_energy = base_energy * mood_time_scale if render_budget_enabled else 0.0
```

棋盘 glow：

```gdscript
var board_glow_energy := float(_final_lighting_settings.get("board_glow_energy", 0.16))
var energy_scale := float(spot.get_meta("energy_scale", 0.6))
real_glow_light.light_energy = board_glow_energy * energy_scale if enabled_by_budget else 0.0
```

假发光 mesh 不受真实光源预算限制，只受 `board_glow_energy` 控制。

---

## 11. 建议改动文件

### 必改

```text
scripts/BackgroundManager.gd
```

需要实现：

- 光源预算常量。
- 光源分类 metadata。
- 光源预算刷新函数。
- 时间关键帧。
- 时间采样。
- 时间应用。
- 天空颜色动态更新。
- 暴露 `set_time_of_day()`。
- 暴露 `set_auto_time_cycle_enabled()`，或者直接操作导出变量。

### 可改

```text
scripts/GameUI.gd
scripts/GameManager.gd
```

用于接 UI 按钮。

### 暂不改

```text
project.godot
scenes/Main.tscn
```

除非需要给 `BackgroundManager` 导出变量保存默认值。

---

## 12. 实现顺序

### Phase 1：先做光源预算

1. 添加 `LIGHT_BUDGETS`。
2. 给棋盘补光、棋盘 glow、森林 rim、地标 mood light 打 metadata。
3. 实现 `_refresh_light_budget()`。
4. 在 `_refresh_lighting_nodes()` 末尾调用 `_refresh_light_budget()`。
5. 验证 high / medium / low 下真实 OmniLight 数量不同。

### Phase 2：做时间关键帧和采样

1. 添加 `TIME_OF_DAY_KEYFRAMES`。
2. 添加 `_sample_time_of_day_settings(hour)`。
3. 添加 `_apply_time_of_day()`。
4. 添加 `set_time_of_day(hour, immediate := false)`。
5. 手动从脚本调用 `set_time_of_day(5.5)`、`set_time_of_day(12.5)`、`set_time_of_day(21.0)` 测试效果。

### Phase 3：接 UI

1. 在光照设置菜单里增加时间快捷按钮。
2. GameUI 发 signal。
3. GameManager 转发给 BackgroundManager。
4. 增加“自动昼夜”切换按钮。

### Phase 4：微调参数

根据截图实际效果微调：

- 夜晚 ambient 不要太低，建议 0.28~0.36。
- 夜晚 exposure 不要低于 0.8。
- 夜晚 fog_density 不要超过 0.012，否则棋盘会糊。
- 夜晚 board_glow_energy 可以 0.20~0.26。
- 夜晚 marker_glow_energy 可以 0.9~1.1。
- 白天 mood_light_scale 接近 0。
- 黄昏 mood_light_scale 0.5~0.7。

---

## 13. 验收标准

实现完成后需要满足：

1. 项目仍然使用 Forward+。
2. 不同渲染开销档下，真实点光数量有明显差异。
3. 低档下棋盘 glow spot 仍可见，但不再全部使用真实点光。
4. 可以手动切换日出、上午、正午、黄昏、夜晚。
5. 自动昼夜开启后，光照能平滑循环。
6. 夜晚能保留氛围，但棋盘主体、棋子、选中状态仍清楚。
7. 白天大部分装饰性点光自动变暗或关闭。
8. 不出现频繁创建/销毁光源造成的卡顿。
9. 不破坏已有光照预设、材质切换、渲染开销档功能。

---

## 14. 本轮不要做的事

本轮不要做：

- 切换到 Mobile 或 Compatibility。
- 重做场景装饰布局。
- 大规模替换模型和材质。
- 加真实全局光照系统。
- 给所有灯开阴影。
- 写复杂天气系统。
- 写真实天文太阳轨迹。
- 做完整开放世界时间系统。

本轮目标是先把光照系统从“固定夜晚/固定白天预设”升级为“可控光源预算 + 可插值时间光照”。

---

## 15. Codex 执行提示

请 Codex 按以下要求实现：

```text
根据 docs/forward_plus_day_night_lighting_plan.md 修改当前 Godot 项目。
保持 Forward+ 渲染器不变。
优先修改 scripts/BackgroundManager.gd，实现真实光源预算和日出日落时间光照系统。
如果已有渲染开销档系统，则与 high/medium/low 档位联动；如果没有，则先在 BackgroundManager 内部保留默认 high 档。
第一版 UI 只需要加入日出/上午/正午/黄昏/夜晚快捷切换和自动昼夜开关。
不要重做场景布局，不要切换渲染器，不要大规模重构 GameManager。
```
