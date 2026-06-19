# 明亮花园画面质感重做计划（Codex 执行版）

## 0. 当前问题判断

当前实机画面已经有封面浅色棋盘、草地、路灯、装饰物和 Forward+ 渲染档位，但整体观感仍然偏暗、偏灰、偏阴沉，和封面图的“明亮花园棋盘”目标差距较大。

当前主要问题不是缺少物件，也不是继续堆更多灯，而是以下几点：

1. **整体曝光和主光强度偏低**  
   当前时间关键帧里的太阳能量很低，正午也只有 `sun_energy = 0.09`，上午约 `0.075`。这会导致画面主要靠环境光和雾撑亮，缺少真实阳光方向感。

2. **雾和天空影响仍然偏重**  
   夜晚/黄昏/清晨的雾会让画面灰化。如果玩家进入游戏时加载了历史自定义配置，画面可能继续沿用偏暗、偏雾的配置。

3. **草地贴图太暗、太脏、颗粒太重**  
   当前地面使用 `leafy_grass_diff_1k.jpg` 作为草地贴图。这个贴图细节较重，在俯视棋盘时容易形成暗绿噪声背景，使画面阴沉。

4. **棋盘虽然换成浅石板，但仍然偏平、偏灰**  
   当前棋盘浅石板的 `base_color` 是 `Color(0.80, 0.78, 0.66)`，可以继续保留，但需要让阳光、环境、阴影、AO 和边缘缝隙更干净。

5. **日夜系统覆盖了部分光影预设效果**  
   `cover_meadow` 光影预设已经存在，但 `_refresh_lighting_nodes()` 里优先使用 `time_of_day` 采样结果。也就是说，单纯调 `cover_meadow` 预设并不能完全控制最终画面，必须同步修改 `TIME_OF_DAY_KEYFRAMES`。

本轮目标：

> 把默认画面从“阴暗森林棋盘”改为“明亮、干净、暖阳、低雾、绿色花园棋盘”。

不要本轮重做玩法、UI、棋子规则、联网、存档和回放。

---

## 1. 目标画面描述

参考封面图，最终游戏内默认画面应该具有以下特征：

- 画面整体明亮，不压暗。
- 草地是偏黄绿、清爽、柔和的 meadow 风格，而不是深绿森林地表。
- 棋盘是浅米色 / 浅石灰色六边形石板，边缘清晰。
- 有明显暖色主光方向，类似上午或午后阳光。
- 阴影柔和，但不大片发黑。
- 雾极轻，只用于远处柔化，不应该笼罩棋盘主体。
- 路灯白天可以作为装饰物存在，但不要让黑色灯杆成为画面主角。
- 夜晚效果可以保留，但默认进入游戏应优先显示明亮封面风格。

---

## 2. 执行原则

### 必须保持

- 保持 `Forward+` 渲染器。
- 保留 `high / medium / low` 渲染开销档。
- 保留 `time_of_day` 日夜系统。
- 保留内角路灯系统。
- 保留 `cover_meadow` 视觉方向。

### 本轮不要做

- 不切换到 Mobile / Compatibility。
- 不重写棋盘生成逻辑。
- 不删除日夜系统。
- 不重做主菜单 UI。
- 不增加大量真实点光。
- 不引入大型第三方场景资源。

---

## 3. 第一阶段：把默认视觉锁定为明亮上午

### 3.1 默认时间改为上午 10 点左右

当前 `BackgroundManager.gd` 中默认：

```gdscript
@export var time_of_day := 12.0
```

建议改为：

```gdscript
@export var time_of_day := 10.0
```

原因：

- 10 点光线比正午更有方向感。
- 画面比黄昏/夜晚更接近封面。
- 仍然有柔和阴影，不会完全平。

### 3.2 启动时优先应用封面视觉目标

当前已经有：

```gdscript
func apply_cover_meadow_visual_target() -> void:
	apply_lighting_preset("cover_meadow")
	set_time_of_day(9.0, true)
	set_auto_time_cycle_enabled(false)
```

建议把时间改成 `10.0` 或 `10.5`：

```gdscript
func apply_cover_meadow_visual_target() -> void:
	apply_lighting_preset("cover_meadow")
	set_time_of_day(10.0, true)
	set_auto_time_cycle_enabled(false)
```

然后新增一个导出开关：

```gdscript
@export var force_cover_meadow_on_start := true
```

在 `_ready()` 末尾、所有保存配置加载完成后调用：

```gdscript
if force_cover_meadow_on_start:
	apply_cover_meadow_visual_target()
```

注意：这一步是为了防止历史保存的自定义光影配置把默认画面又拉回阴暗状态。

如果担心覆盖用户设置，可以改成只在 Debug 阶段开启：

```gdscript
@export var force_cover_meadow_on_start := OS.is_debug_build()
```

但当前建议先固定为 `true`，方便快速收敛画面基调。

---

## 4. 第二阶段：重调 TIME_OF_DAY_KEYFRAMES 的白天段

当前 `TIME_OF_DAY_KEYFRAMES` 是最终画面主控。不要只改 `LIGHTING_PRESETS.cover_meadow`，否则实际效果会被时间系统覆盖。

重点修改三个时间段：

- 上午 `9.0`
- 正午 `12.5`
- 黄昏 `17.5`

### 4.1 上午 9.0：作为默认封面风格主基调

建议把上午关键帧改成更明亮、更暖、更低雾：

```gdscript
{
	"time": 9.0,
	"label": "上午",
	"sun_energy": 0.42,
	"ambient_energy": 0.88,
	"fill_energy": 0.075,
	"exposure": 1.02,
	"fog_density": 0.0008,
	"fog_sky_affect": 0.05,
	"sun_pitch": -34.0,
	"sun_yaw": -132.0,
	"sun_color": Color(1.0, 0.88, 0.66),
	"fill_color": Color(0.86, 0.92, 1.0),
	"sky_top": Color(0.34, 0.58, 0.88),
	"sky_horizon": Color(0.76, 0.88, 0.96),
	"floor_tint": Color(0.70, 0.92, 0.46),
	"board_glow_energy": 0.015,
	"marker_glow_energy": 0.48,
	"firefly_energy": 0.0,
	"mood_light_scale": 0.0,
	"forest_rim_scale": 0.0,
	"inner_lamp_scale": 0.0,
}
```

### 4.2 正午 12.5：更亮但不要过曝

```gdscript
{
	"time": 12.5,
	"label": "正午",
	"sun_energy": 0.48,
	"ambient_energy": 0.92,
	"fill_energy": 0.06,
	"exposure": 1.0,
	"fog_density": 0.0006,
	"fog_sky_affect": 0.04,
	"sun_pitch": -58.0,
	"sun_yaw": -150.0,
	"sun_color": Color(1.0, 0.96, 0.84),
	"fill_color": Color(0.88, 0.94, 1.0),
	"sky_top": Color(0.28, 0.58, 0.92),
	"sky_horizon": Color(0.78, 0.90, 0.98),
	"floor_tint": Color(0.68, 0.94, 0.48),
	"board_glow_energy": 0.0,
	"marker_glow_energy": 0.45,
	"firefly_energy": 0.0,
	"mood_light_scale": 0.0,
	"forest_rim_scale": 0.0,
	"inner_lamp_scale": 0.0,
}
```

### 4.3 黄昏 17.5：保留暖色，但不要阴沉

```gdscript
{
	"time": 17.5,
	"label": "黄昏",
	"sun_energy": 0.30,
	"ambient_energy": 0.72,
	"fill_energy": 0.07,
	"exposure": 0.98,
	"fog_density": 0.002,
	"fog_sky_affect": 0.12,
	"sun_pitch": -14.0,
	"sun_yaw": -40.0,
	"sun_color": Color(1.0, 0.58, 0.30),
	"fill_color": Color(0.62, 0.70, 0.95),
	"sky_top": Color(0.32, 0.38, 0.68),
	"sky_horizon": Color(1.0, 0.56, 0.34),
	"floor_tint": Color(0.62, 0.78, 0.38),
	"board_glow_energy": 0.06,
	"marker_glow_energy": 0.66,
	"firefly_energy": 0.10,
	"mood_light_scale": 0.25,
	"forest_rim_scale": 0.15,
	"inner_lamp_scale": 0.25,
}
```

### 4.4 夜晚可以保留，但降低默认压迫感

夜晚不是本轮默认画面，但也不要过灰。

建议将夜晚：

```gdscript
"ambient_energy": 0.32,
"exposure": 0.82,
"fog_density": 0.010,
"fog_sky_affect": 0.45,
```

调整为：

```gdscript
"ambient_energy": 0.38,
"exposure": 0.90,
"fog_density": 0.006,
"fog_sky_affect": 0.25,
```

避免夜晚一开就雾蒙蒙、灰压压。

---

## 5. 第三阶段：降低雾和 SSAO 的压暗感

### 5.1 cover_meadow 预设降低 SSAO

当前 `cover_meadow` 中：

```gdscript
"ssao_intensity": 0.72,
"fog_density": 0.0018,
"fog_sky_affect": 0.10,
```

建议：

```gdscript
"ssao_intensity": 0.38,
"fog_density": 0.0008,
"fog_sky_affect": 0.04,
```

原因：

- SSAO 过强会让六边形缝隙和草地噪声都变脏。
- 封面图是柔和干净，不是重 AO 写实。

### 5.2 调整 Environment 初始值

`_build_world_environment()` 当前：

```gdscript
_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
_environment.tonemap_exposure = 0.9
_environment.tonemap_white = 3.0
_environment.ssao_intensity = 1.42
_environment.fog_density = 0.004
_environment.fog_sky_affect = 0.25
```

建议：

```gdscript
_environment.tonemap_mode = Environment.TONE_MAPPER_ACES # 如果 Godot 版本支持
_environment.tonemap_exposure = 1.0
_environment.tonemap_white = 4.0
_environment.ssao_intensity = 0.45
_environment.ssao_radius = 0.7
_environment.fog_density = 0.0008
_environment.fog_sky_affect = 0.04
```

如果 `Environment.TONE_MAPPER_ACES` 不存在，则保留 `FILMIC`，但提高 `tonemap_exposure` 并降低雾。

---

## 6. 第四阶段：重做草地材质，去掉暗绿噪声感

当前 `_build_floor_material()` 会加载：

```gdscript
floor_albedo_path := "res://assets/environment/leafy_grass_diff_1k.jpg"
floor_normal_path := "res://assets/environment/leafy_grass_nor_gl_1k.jpg"
floor_roughness_path := "res://assets/environment/leafy_grass_rough_1k.jpg"
```

这个贴图在当前俯视场景里太暗、太碎。

### 6.1 新增导出开关

```gdscript
@export var cover_meadow_clean_floor := true
```

### 6.2 clean floor 模式下不使用暗草地 albedo 贴图

在 `_build_floor_material()` 中：

```gdscript
if not cover_meadow_clean_floor:
	var albedo = load(floor_albedo_path)
	if albedo != null:
		material.albedo_texture = albedo
else:
	material.albedo_texture = null
```

clean floor 模式下使用：

```gdscript
material.albedo_color = Color(0.70, 0.92, 0.48)
material.roughness = 0.78
material.normal_enabled = false
material.normal_scale = 0.0
```

这样先让整体画面变干净。后续如果需要细节，再用浅色小草、花丛、灌木和石头补，不要让整张地面贴图承担所有细节。

### 6.3 可选：降低地面 UV 重复

当前：

```gdscript
floor_uv_repeat := 10.0
```

如果仍保留贴图，建议降到：

```gdscript
floor_uv_repeat := 5.5
```

减少高频噪声。

---

## 7. 第五阶段：棋盘材质继续明亮化

当前内置浅石板：

```gdscript
"base_color": Color(0.80, 0.78, 0.66),
"side_color": Color(0.45, 0.50, 0.34),
"roughness": 0.58,
"normal_scale": 0.025,
"clearcoat": 0.18,
"clearcoat_roughness": 0.42,
```

建议改为：

```gdscript
"base_color": Color(0.86, 0.84, 0.72),
"side_color": Color(0.56, 0.60, 0.42),
"roughness": 0.62,
"normal_scale": 0.015,
"clearcoat": 0.08,
"clearcoat_roughness": 0.55,
```

目的：

- 棋盘更接近封面里的浅米色石板。
- 降低镜面脏反光。
- 减少暗边。

---

## 8. 第六阶段：降低黑色路灯杆的压迫感

当前内角路灯颜色：

```gdscript
inner_lamp_pole_color := Color(0.18, 0.14, 0.10)
inner_lamp_shade_color := Color(0.12, 0.09, 0.06)
```

在白天封面风格中，黑色杆子太显眼，会破坏明亮花园感。

建议改成偏木色 / 石色：

```gdscript
@export var inner_lamp_pole_color := Color(0.46, 0.34, 0.20)
@export var inner_lamp_shade_color := Color(0.30, 0.42, 0.26)
```

或者更接近日式庭院灯：

```gdscript
@export var inner_lamp_pole_color := Color(0.42, 0.32, 0.22)
@export var inner_lamp_shade_color := Color(0.20, 0.34, 0.24)
```

白天灯泡不发光，夜晚再发暖光。

---

## 9. 第七阶段：启动菜单封面与实际画面对齐

封面图现在很好，但实际画面差距大。为了减少落差，需要新增一个“封面视觉一键目标”。

### 9.1 新增函数

```gdscript
func apply_bright_meadow_runtime_target() -> void:
	apply_lighting_preset("cover_meadow")
	apply_render_cost_profile("high", false)
	set_auto_time_cycle_enabled(false)
	set_time_of_day(10.0, true)
```

### 9.2 Debug 快捷入口

可以在光影设置 UI 或 Debug 中提供按钮：

```text
重置为封面明亮风格
```

点击后调用 `apply_bright_meadow_runtime_target()`。

---

## 10. Codex 分步执行建议

不要一次性做完全部。按以下顺序提交。

### Commit 1：默认明亮化

只改 `BackgroundManager.gd`：

1. `time_of_day` 默认改为 `10.0`。
2. 新增 `force_cover_meadow_on_start`。
3. `_ready()` 最后调用 `apply_cover_meadow_visual_target()`。
4. `apply_cover_meadow_visual_target()` 时间改为 `10.0`。
5. 修改上午、正午、黄昏、夜晚时间关键帧。

验收：

- 进入游戏默认不是阴暗森林。
- 棋盘主体明显变亮。
- 远处草地不再雾蒙蒙。

### Commit 2：草地去噪和提亮

只改 `BackgroundManager.gd`：

1. 新增 `cover_meadow_clean_floor`。
2. clean floor 模式下关闭草地 albedo / normal / roughness 贴图。
3. 使用浅绿色纯色草地。
4. 降低 `floor_uv_repeat` 或在 clean 模式下无视贴图 UV。

验收：

- 地面不再暗绿、脏、碎。
- 草地区域更像封面里的柔和 meadow。

### Commit 3：棋盘和路灯颜色调整

修改：

- `BoardManager.gd`
- `BackgroundManager.gd`

内容：

1. 提亮 `cover_meadow_stone`。
2. 降低棋盘 clearcoat。
3. 路灯杆从黑色改为木色 / 深绿屋檐色。

验收：

- 棋盘更接近封面浅石板。
- 路灯白天不再像黑色路障。

### Commit 4：增加一键封面风格重置入口

修改：

- `BackgroundManager.gd`
- `GameUI.gd`
- `GameManager.gd`

内容：

1. 新增 `apply_bright_meadow_runtime_target()`。
2. UI 光影菜单加按钮“重置为封面明亮风格”。
3. 点击后恢复封面风格，不受历史保存配置影响。

验收：

- 玩家误调光影后，可以一键回到明亮花园效果。

---

## 11. 直接给 Codex 的执行提示词

```text
根据 docs/bright_meadow_visual_rework_plan.md 执行 Commit 1：默认明亮化。

只修改 scripts/BackgroundManager.gd。
保持 Forward+ 渲染器不变。
不要改棋盘规则、棋子逻辑、网络、存档和 UI。
不要新增大型资源。

目标：让游戏启动后的实际画面默认接近封面图的明亮花园效果，而不是当前的暗绿阴沉森林效果。

具体要求：
1. 将 time_of_day 默认值改为 10.0。
2. 新增 force_cover_meadow_on_start 导出变量，默认为 true。
3. 将 apply_cover_meadow_visual_target() 的时间改为 10.0。
4. 在 _ready() 完成配置加载、地面、草地、装饰、灯光刷新和内角路灯构建后，若 force_cover_meadow_on_start 为 true，则调用 apply_cover_meadow_visual_target()。
5. 修改 TIME_OF_DAY_KEYFRAMES 中 9.0、12.5、17.5、21.0 的参数，按照文档给出的新数值提亮白天、降低雾和压暗感。
6. 调低 cover_meadow 预设的 ssao_intensity、fog_density、fog_sky_affect。
7. 不要删除日夜系统。
8. 不要删除路灯。
9. 不要改渲染开销 high/medium/low 档。

验收：
- 进入游戏默认画面明显更亮。
- 草地不再整体暗绿阴沉。
- 棋盘主体清晰、偏暖、接近封面图。
- 夜晚仍可通过时间按钮切换回来。
```

---

## 12. 视觉验收标准

完成后请用同一个镜头分别截图：

1. 默认启动画面。
2. 上午 10:00。
3. 正午 12:30。
4. 黄昏 17:30。
5. 夜晚 21:00。

默认启动画面应满足：

- 棋盘是画面最亮、最清楚的主体。
- 草地是清爽绿，不是暗绿黑。
- 雾只影响远景，不覆盖棋盘主体。
- 路灯白天不抢视觉。
- 棋子颜色清楚，红蓝黄不灰。
- 整体观感接近封面图，而不是当前暗夜森林图。
