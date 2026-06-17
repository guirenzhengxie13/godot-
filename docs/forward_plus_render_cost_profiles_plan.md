# Forward+ 渲染开销分档切换方案

## 目标

在保持 Godot 项目继续使用 `Forward+` 渲染器的前提下，新增一个可在游戏内切换的“渲染开销档位”系统。

本方案给 Codex 使用，目标是让 Codex 按文档实现：

- 保持 `project.godot` 中 `renderer/rendering_method="forward_plus"` 不变。
- 不切换到 `mobile` 或 `gl_compatibility`。
- 不重做场景光照布置，不移动、不删除、不新增灯光节点。
- 只做“渲染开销参数分档”和“运行时切换”。
- 当前画质可以作为 `high` 高渲染档。
- 追加 `medium` 中渲染档和 `low` 低渲染档。
- 后续再单独处理场景氛围、光照布局、美术方向。

---

## 当前约束

当前项目是 3D 棋盘类场景，不需要改变渲染器路线。本次任务只在 `Forward+` 内部控制开销。

必须保留：

```ini
[rendering]
renderer/rendering_method="forward_plus"
```

不要做：

```ini
renderer/rendering_method="mobile"
renderer/rendering_method="gl_compatibility"
```

---

## 当前问题

目前 `BackgroundManager.gd` 中已经存在光照预设，例如 `soft_day`、`performance_clean` 等。它们同时混合了：

- 场景氛围参数；
- 后期参数；
- 抗锯齿参数；
- 渲染缩放参数；
- SSAO / Fog / Glow 等成本参数。

这会导致一个问题：

> 玩家切换光照氛围时，也会隐式改变渲染开销。

本次目标是把“光照氛围 preset”和“渲染开销 profile”拆成两套概念。

建议最终概念：

```text
Lighting Preset   = 场景氛围 / 颜色 / 光照风格
Render Cost Profile = 性能开销 / 采样 / 后期强度 / 装饰复杂度
```

---

## 新增渲染开销档位

新增三个档位：

```gdscript
high
medium
low
```

UI 显示名建议：

```text
高渲染
中渲染
低渲染
```

### 1. high：高渲染档

定位：保留当前项目观感，作为默认高画质基准。

建议参数：

```gdscript
{
    "label": "高渲染",
    "render_scale": 1.2,
    "msaa_level": 2,
    "fxaa_enabled": true,
    "taa_enabled": false,
    "debanding_enabled": true,
    "ssao_intensity_multiplier": 1.0,
    "fog_density_multiplier": 1.0,
    "reflection_intensity_multiplier": 1.0,
    "board_glow_energy_multiplier": 1.0,
    "grass_density_multiplier": 1.0,
    "ground_radial_segments": 128
}
```

说明：

- `high` 不追求降开销。
- 尽量复现当前默认效果。
- 如果当前 `soft_day` 是默认氛围，`high + soft_day` 应该接近现在画面。

### 2. medium：中渲染档

定位：推荐默认游玩档。画面不要明显崩，但降低多余成本。

建议参数：

```gdscript
{
    "label": "中渲染",
    "render_scale": 1.0,
    "msaa_level": 2,
    "fxaa_enabled": true,
    "taa_enabled": false,
    "debanding_enabled": true,
    "ssao_intensity_multiplier": 0.65,
    "fog_density_multiplier": 0.85,
    "reflection_intensity_multiplier": 0.75,
    "board_glow_energy_multiplier": 0.65,
    "grass_density_multiplier": 0.65,
    "ground_radial_segments": 96
}
```

说明：

- `render_scale` 降到 `1.0` 是主要收益点。
- 保留 `MSAA 2X + FXAA`，避免棋盘边缘锯齿太明显。
- SSAO、Fog、Reflection、Glow 都只做强度削减，不改变布局。
- 草地数量降低，但不完全移除。

### 3. low：低渲染档

定位：低配电脑 / 调试 / 笔记本省电档。

建议参数：

```gdscript
{
    "label": "低渲染",
    "render_scale": 0.85,
    "msaa_level": 0,
    "fxaa_enabled": true,
    "taa_enabled": false,
    "debanding_enabled": false,
    "ssao_intensity_multiplier": 0.25,
    "fog_density_multiplier": 0.55,
    "reflection_intensity_multiplier": 0.35,
    "board_glow_energy_multiplier": 0.25,
    "grass_density_multiplier": 0.35,
    "ground_radial_segments": 64
}
```

说明：

- 低档仍然保持 Forward+。
- 低档不删除任何灯光，不改灯光摆放。
- 可以降低已有 glow light 的能量，但不要在本阶段重构灯光系统。
- 如果 `render_scale = 0.85` 观感太糊，可以改成 `0.9`。

---

## 推荐实现范围

### 需要修改的文件

建议只修改：

```text
scripts/BackgroundManager.gd
scripts/GameUI.gd
scripts/GameManager.gd
```

必要时可修改：

```text
scenes/Main.tscn
```

但如果信号连接都在脚本里做，最好不改 `.tscn`。

### 不建议修改的文件

本次不要修改：

```text
project.godot
scenes/Cell.tscn
scenes/Piece.tscn
scripts/BoardManager.gd
scripts/MoveValidator.gd
scripts/PassiveSkillRuleEngine.gd
scripts/AIPlayer.gd
scripts/NetworkManager.gd
```

---

## BackgroundManager.gd 实现建议

### 1. 新增渲染开销配置常量

在 `BackgroundManager.gd` 中新增：

```gdscript
const RENDER_COST_PROFILE_ORDER := ["high", "medium", "low"]

const RENDER_COST_PROFILES := {
    "high": {
        "label": "高渲染",
        "render_scale": 1.2,
        "msaa_level": 2,
        "fxaa_enabled": true,
        "taa_enabled": false,
        "debanding_enabled": true,
        "ssao_intensity_multiplier": 1.0,
        "fog_density_multiplier": 1.0,
        "reflection_intensity_multiplier": 1.0,
        "board_glow_energy_multiplier": 1.0,
        "grass_density_multiplier": 1.0,
        "ground_radial_segments": 128,
    },
    "medium": {
        "label": "中渲染",
        "render_scale": 1.0,
        "msaa_level": 2,
        "fxaa_enabled": true,
        "taa_enabled": false,
        "debanding_enabled": true,
        "ssao_intensity_multiplier": 0.65,
        "fog_density_multiplier": 0.85,
        "reflection_intensity_multiplier": 0.75,
        "board_glow_energy_multiplier": 0.65,
        "grass_density_multiplier": 0.65,
        "ground_radial_segments": 96,
    },
    "low": {
        "label": "低渲染",
        "render_scale": 0.85,
        "msaa_level": 0,
        "fxaa_enabled": true,
        "taa_enabled": false,
        "debanding_enabled": false,
        "ssao_intensity_multiplier": 0.25,
        "fog_density_multiplier": 0.55,
        "reflection_intensity_multiplier": 0.35,
        "board_glow_energy_multiplier": 0.25,
        "grass_density_multiplier": 0.35,
        "ground_radial_segments": 64,
    },
}
```

### 2. 新增运行时状态

```gdscript
var _render_cost_profile_id := "high"
var _render_cost_settings: Dictionary = RENDER_COST_PROFILES["high"].duplicate(true)
```

### 3. 新增公开方法

```gdscript
func get_render_cost_profiles() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for profile_id in RENDER_COST_PROFILE_ORDER:
        var profile := RENDER_COST_PROFILES[profile_id]
        result.append({
            "id": profile_id,
            "label": profile.get("label", profile_id),
        })
    return result

func get_render_cost_profile_id() -> String:
    return _render_cost_profile_id

func apply_render_cost_profile(profile_id: String, persist := true) -> void:
    if not RENDER_COST_PROFILES.has(profile_id):
        push_warning("Unknown render cost profile: %s" % profile_id)
        return

    _render_cost_profile_id = profile_id
    _render_cost_settings = RENDER_COST_PROFILES[profile_id].duplicate(true)
    _apply_render_cost_settings()

    if persist:
        _save_render_cost_profile()
```

### 4. 应用规则

新增 `_apply_render_cost_settings()`。

职责：

- 应用 viewport 渲染缩放。
- 应用 MSAA / FXAA / TAA / Debanding。
- 刷新 Environment 中的 SSAO/Fog/Reflection/Glow 强度倍率。
- 刷新草地数量或可见数量。
- 不改变灯光节点位置。
- 不改变灯光节点数量。

伪代码：

```gdscript
func _apply_render_cost_settings() -> void:
    _apply_viewport_render_settings()
    _refresh_lighting_nodes()
    _refresh_environment_cost_settings()
    _refresh_decoration_cost_settings()
```

如果当前已有 `_apply_viewport_render_settings()`，优先复用，不要另写一套并行逻辑。

### 5. 解决 Lighting Preset 和 Render Cost Profile 的覆盖顺序

关键原则：

> 光照预设先应用，渲染开销档后覆盖性能相关参数。

建议加一个方法：

```gdscript
func _get_effective_lighting_value(key: String, fallback: Variant = null) -> Variant:
    var cost_keys := {
        "render_scale": true,
        "msaa_level": true,
        "fxaa_enabled": true,
        "taa_enabled": true,
        "debanding_enabled": true,
    }

    if cost_keys.has(key) and _render_cost_settings.has(key):
        return _render_cost_settings[key]

    return _lighting_settings.get(key, fallback)
```

对于 SSAO/Fog/Reflection/Glow，不建议直接覆盖原始值，而是使用 multiplier：

```gdscript
var base_ssao := float(_lighting_settings.get("ssao_intensity", 1.0))
var ssao_multiplier := float(_render_cost_settings.get("ssao_intensity_multiplier", 1.0))
environment.ssao_intensity = base_ssao * ssao_multiplier
```

同理：

```gdscript
fog_density = base_fog_density * fog_density_multiplier
reflection_intensity = base_reflection_intensity * reflection_intensity_multiplier
board_glow_energy = base_board_glow_energy * board_glow_energy_multiplier
```

这样可以保证：

- 光照预设继续决定“风格”；
- 渲染开销档只决定“成本倍率”；
- 切换光照风格不会把渲染档位冲掉。

### 6. 存档

建议保存到 `user://render_cost_profile.cfg`。

```gdscript
const RENDER_COST_PROFILE_CONFIG_PATH := "user://render_cost_profile.cfg"
```

保存字段：

```text
render_cost/profile_id
```

伪代码：

```gdscript
func _save_render_cost_profile() -> void:
    var config := ConfigFile.new()
    config.set_value("render_cost", "profile_id", _render_cost_profile_id)
    config.save(RENDER_COST_PROFILE_CONFIG_PATH)

func _load_render_cost_profile() -> void:
    var config := ConfigFile.new()
    if config.load(RENDER_COST_PROFILE_CONFIG_PATH) != OK:
        apply_render_cost_profile("high", false)
        return

    var profile_id := str(config.get_value("render_cost", "profile_id", "high"))
    apply_render_cost_profile(profile_id, false)
```

在 `_ready()` 的初始化流程中调用 `_load_render_cost_profile()`。

如果当前 `BackgroundManager.gd` 已经有光照 preset 的保存逻辑，渲染开销 profile 可以独立保存，避免和光照 preset 混在一起。

---

## GameUI.gd 实现建议

当前 UI 已经有光照 preset 相关信号：

```gdscript
signal lighting_preset_selected(preset_id: String)
signal lighting_value_changed(parameter: String, value: float)
signal save_lighting_requested
signal reset_lighting_requested
```

建议新增：

```gdscript
signal render_cost_profile_selected(profile_id: String)
```

新增成员变量：

```gdscript
var _render_cost_profile_options: Array[Dictionary] = []
var _render_cost_profile_option: OptionButton
var _render_cost_controls_syncing := false
```

新增公开方法：

```gdscript
func set_render_cost_profiles(options: Array[Dictionary], selected_id: String) -> void:
    _render_cost_profile_options = options
    if _render_cost_profile_option == null:
        return

    _render_cost_controls_syncing = true
    _render_cost_profile_option.clear()

    var selected_index := 0
    for i in options.size():
        var option := options[i]
        _render_cost_profile_option.add_item(str(option.get("label", option.get("id", ""))))
        _render_cost_profile_option.set_item_metadata(i, str(option.get("id", "")))
        if str(option.get("id", "")) == selected_id:
            selected_index = i

    _render_cost_profile_option.select(selected_index)
    _render_cost_controls_syncing = false
```

新增回调：

```gdscript
func _on_render_cost_profile_selected(index: int) -> void:
    if _render_cost_controls_syncing:
        return
    if _render_cost_profile_option == null:
        return

    var profile_id := str(_render_cost_profile_option.get_item_metadata(index))
    render_cost_profile_selected.emit(profile_id)
```

UI 摆放建议：

- 放在现有光影 / Lighting 菜单中。
- 标题为：`渲染开销`。
- OptionButton 选项：`高渲染`、`中渲染`、`低渲染`。
- 不要新建复杂页面。

---

## GameManager.gd 实现建议

在 `_ready()` 中，现有应该已经连接了光照 preset 相关信号。新增连接：

```gdscript
ui.render_cost_profile_selected.connect(_on_render_cost_profile_selected)
```

初始化 UI：

```gdscript
ui.set_render_cost_profiles(
    background_manager.get_render_cost_profiles(),
    background_manager.get_render_cost_profile_id()
)
```

新增回调：

```gdscript
func _on_render_cost_profile_selected(profile_id: String) -> void:
    background_manager.apply_render_cost_profile(profile_id)
    ui.set_render_cost_profiles(
        background_manager.get_render_cost_profiles(),
        background_manager.get_render_cost_profile_id()
    )
```

注意：

- `GameManager` 只做中转，不直接写渲染参数。
- 参数应用逻辑放在 `BackgroundManager`。
- UI 只负责显示和发信号。

---

## 分档参数优先级

最终生效优先级建议：

```text
Godot Forward+ renderer
    ↓
Lighting Preset 基础氛围参数
    ↓
Render Cost Profile 成本覆盖 / 成本倍率
    ↓
用户手动滑条微调
```

但是为了降低本次实现复杂度，可以先做简化版：

```text
Lighting Preset 基础氛围参数
    ↓
Render Cost Profile 成本覆盖 / 成本倍率
```

手动滑条和渲染开销 profile 的冲突可以后续再处理。

---

## 不纳入本次任务的内容

以下内容后续再做，不要在本次实现：

- 重做主光 / 补光 / 环境光布局。
- 删除棋盘周围 glow spot。
- 把真实 OmniLight 改成假发光贴片。
- 重做背景氛围。
- 改天空盒、美术色调、材质风格。
- 切换到 Mobile 渲染器。
- 切换到 Compatibility 渲染器。
- 重构 `BackgroundManager.gd` 的整体架构。
- 拆分 UI 文件。

---

## 验收标准

Codex 实现后，应满足：

1. `project.godot` 仍然是：

```ini
renderer/rendering_method="forward_plus"
```

2. 游戏内可以选择：

```text
高渲染
中渲染
低渲染
```

3. 切换档位后立即生效，不需要重启游戏。

4. 切换光照 preset 后，当前渲染开销档位不应丢失。

5. 重启游戏后，最近选择的渲染开销档位可以恢复。

6. 高渲染档接近当前默认画面。

7. 中渲染档画面基本保持，但开销低于高渲染档。

8. 低渲染档画面可以略糊或略平，但帧率应明显优于高渲染档。

9. 本次实现不移动、不新增、不删除灯光节点。

10. 本次实现不切换 Godot renderer。

---

## 测试步骤

### 1. 检查渲染器

打开 `project.godot`，确认：

```ini
renderer/rendering_method="forward_plus"
```

### 2. 启动游戏

确认游戏正常进入主场景。

### 3. 打开光影 / 设置菜单

确认可以看到新的：

```text
渲染开销
```

并且有：

```text
高渲染
中渲染
低渲染
```

### 4. 切换档位

依次切换：

```text
高渲染 → 中渲染 → 低渲染 → 高渲染
```

观察：

- 是否卡顿；
- 画面是否实时变化；
- 控制台是否报错；
- 棋盘、棋子、UI 是否正常。

### 5. 切换光照 preset

在任意渲染开销档位下切换光照 preset。

确认：

- 光照氛围改变；
- 渲染开销档位 UI 仍显示原选择；
- 渲染开销档位不会被光照 preset 重置。

### 6. 重启测试

选择 `低渲染` 后退出，再重新运行。

确认：

- UI 显示 `低渲染`；
- 实际渲染参数也是低渲染档。

---

## 推荐实现顺序

1. 在 `BackgroundManager.gd` 增加 `RENDER_COST_PROFILES`。
2. 增加 `apply_render_cost_profile()`、`get_render_cost_profiles()`、`get_render_cost_profile_id()`。
3. 将 viewport 相关参数改为从 render cost profile 读取。
4. 将 SSAO/Fog/Reflection/Glow 改为 lighting preset × cost multiplier。
5. 增加保存/读取 profile 的逻辑。
6. 在 `GameUI.gd` 增加 OptionButton 和 signal。
7. 在 `GameManager.gd` 连接 UI 与 BackgroundManager。
8. 运行测试。
9. 修复低档下过糊或过暗的问题。

---

## 给 Codex 的关键提醒

请保持本次改动“小步可回退”：

- 不要顺手重构整个 `BackgroundManager.gd`。
- 不要把光照 preset 全部重写。
- 不要改棋盘、棋子、规则、AI、联网逻辑。
- 不要改变 renderer。
- 不要把光照布局优化和渲染开销分档混在同一个 PR。

本次只做：

```text
Forward+ 下的渲染开销 profile 系统
```

后续再做：

```text
场景光照布置优化
整体氛围美术优化
真实光源数量优化
假发光 / 假阴影替代方案
```
