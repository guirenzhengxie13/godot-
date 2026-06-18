# 棋盘内角路灯实现方案

## 1. 目标

在当前 Godot 4.6 / Forward+ 项目中，为星形棋盘的 6 个内角区域添加程序化路灯。路灯应在夜晚逐渐亮起，使用暖色定向光照向棋盘中心，并接入现有 `high / medium / low` 渲染开销档，避免夜间真实光源数量失控。

本方案重点解决此前 Codex 无法稳定把物件放到棋盘内角的问题：**路灯位置必须基于棋盘轴坐标计算，而不是手写世界坐标或凭视觉猜测。**

---

## 2. 实现范围

### 本轮实现

1. 在棋盘中心六边形的 6 个内角附近生成 6 盏路灯。
2. 使用 `BoardManager.coord_to_world()` 将棋盘坐标转换为世界坐标。
3. 路灯由代码程序化生成，不依赖外部模型资源。
4. 每盏路灯包含灯杆、灯罩、发光灯泡、`SpotLight3D`。
5. 路灯真实光源接入现有 Forward+ 渲染开销档。
6. 路灯亮度接入现有日夜时间系统。
7. 白天关闭真实灯光，夜晚打开暖色灯光。
8. 所有路灯模型始终显示，只有真实光源按时间和渲染档位启用或关闭。

### 本轮不做

1. 不切换渲染器，继续保持 Forward+。
2. 不重做棋盘生成逻辑。
3. 不改动棋子、规则、AI、联网、回放等玩法逻辑。
4. 不引入复杂外部 3D 模型。
5. 不开启路灯阴影，避免 6 个动态阴影光源带来明显性能开销。
6. 不把路灯放置逻辑写成随机散布。

---

## 3. 当前项目基础

当前项目已经具备实现该需求的关键基础：

1. `BoardManager.gd` 使用棋盘轴坐标 `Vector2i(q, r)` 管理棋盘格。
2. `BoardManager.coord_to_world(coord: Vector2i) -> Vector3` 可以把棋盘坐标转换为 3D 世界坐标。
3. `BackgroundManager.gd` 已经负责环境、装饰、灯光、光影预设、渲染开销档和日夜时间系统。
4. 当前已经存在 `LIGHT_BUDGETS`，可用于控制不同性能档下真实光源数量。
5. 当前已经存在 `TIME_OF_DAY_KEYFRAMES`，可用于控制不同时间段的光照强度和氛围。

因此，内角路灯应作为 `BackgroundManager.gd` 的一个独立装饰系统实现。

---

## 4. 核心原则：使用棋盘坐标锚点，而不是世界坐标硬编码

### 错误做法

不要这样做：

```gdscript
var lamp_pos := Vector3(3.2, 0.0, -6.4)
```

这种做法会导致：

1. 棋盘尺寸、格距变化后路灯错位。
2. Codex 很难判断“内角”到底在哪里。
3. 视角或场景装饰变动后位置不可维护。
4. 后续如果 `center_radius` 或 `cell_spacing` 改动，路灯不会自动适配。

### 正确做法

使用中心六边形 6 个角的棋盘坐标作为锚点：

```gdscript
const INNER_CORNER_ANCHORS := [
    Vector2i(0, -4),
    Vector2i(4, -4),
    Vector2i(4, 0),
    Vector2i(0, 4),
    Vector2i(-4, 4),
    Vector2i(-4, 0),
]
```

这些坐标对应中心六边形的 6 个角点。路灯不直接放在格子中心，而是从棋盘中心向外偏移一段距离：

```gdscript
var anchor_world := _board_manager.coord_to_world(anchor_coord)
var outward := Vector3(anchor_world.x, 0.0, anchor_world.z).normalized()
var lamp_position := anchor_world + outward * inner_lamp_outset
```

这样路灯会被放在内角外侧的空隙区域，而不是压在棋盘格、棋子或主路径上。

---

## 5. 建议新增导出参数

在 `BackgroundManager.gd` 中新增以下参数：

```gdscript
@export var board_manager_path: NodePath

@export_group("Inner Board Lamps")
@export var inner_lamps_enabled := true
@export var inner_lamp_outset := 0.95
@export var inner_lamp_height := 2.4
@export var inner_lamp_light_height := 2.15
@export var inner_lamp_pole_radius := 0.045
@export var inner_lamp_pole_color := Color(0.18, 0.14, 0.10)
@export var inner_lamp_shade_color := Color(0.12, 0.09, 0.06)
@export var inner_lamp_bulb_radius := 0.105
@export var inner_lamp_energy := 0.75
@export var inner_lamp_range := 7.0
@export var inner_lamp_spot_angle := 38.0
@export var inner_lamp_spot_attenuation := 1.2
@export var inner_lamp_color := Color(1.0, 0.76, 0.46)
@export var inner_lamp_debug_markers := false
```

说明：

1. `inner_lamp_outset` 控制路灯从内角锚点向外偏移的距离。
2. `inner_lamp_height` 控制灯杆高度。
3. `inner_lamp_light_height` 控制真实光源高度。
4. `inner_lamp_energy` 控制夜晚最大亮度。
5. `inner_lamp_debug_markers` 用于调试位置，验收完成后默认关闭。

---

## 6. 建议新增成员变量

在 `BackgroundManager.gd` 中新增：

```gdscript
var _board_manager: Node = null
var _inner_board_lamps: Array[Node3D] = []
var _inner_lamp_lights: Array[SpotLight3D] = []
var _inner_lamp_bulbs: Array[MeshInstance3D] = []
var _inner_lamp_debug_lines: Array[MeshInstance3D] = []
```

建议路灯根节点结构：

```text
BackgroundManager
  └─ InnerBoardLamps
       ├─ InnerLamp_0
       │   ├─ Pole
       │   ├─ Arm
       │   ├─ Shade
       │   ├─ Bulb
       │   └─ LampLight
       ├─ InnerLamp_1
       └─ ...
```

---

## 7. Main.tscn 接入要求

`BackgroundManager` 与 `BoardManager` 是主场景下的同级节点，因此 `board_manager_path` 应设置为：

```text
../BoardManager
```

如果暂时不想修改 `Main.tscn`，也可以在代码中做兜底查找：

```gdscript
func _resolve_board_manager() -> void:
    if board_manager_path != NodePath("") and has_node(board_manager_path):
        _board_manager = get_node(board_manager_path)
        return

    var root := get_parent()
    if root and root.has_node("BoardManager"):
        _board_manager = root.get_node("BoardManager")
```

注意：由于 `BackgroundManager` 在场景树中的顺序可能早于 `BoardManager`，如果 `_ready()` 阶段拿不到棋盘坐标或棋盘未初始化，可使用 `call_deferred("_build_inner_board_lamps")` 延后生成。

---

## 8. 路灯生成流程

建议在 `BackgroundManager.gd` 中新增：

```gdscript
func _build_inner_board_lamps() -> void:
    if not inner_lamps_enabled:
        return

    _resolve_board_manager()
    if _board_manager == null or not _board_manager.has_method("coord_to_world"):
        push_warning("Inner board lamps skipped: BoardManager not found or coord_to_world missing.")
        return

    _clear_inner_board_lamps()

    var root := Node3D.new()
    root.name = "InnerBoardLamps"
    add_child(root)

    var anchors := [
        Vector2i(0, -4),
        Vector2i(4, -4),
        Vector2i(4, 0),
        Vector2i(0, 4),
        Vector2i(-4, 4),
        Vector2i(-4, 0),
    ]

    for i in anchors.size():
        var anchor_coord: Vector2i = anchors[i]
        var anchor_world: Vector3 = _board_manager.coord_to_world(anchor_coord)
        var outward := Vector3(anchor_world.x, 0.0, anchor_world.z).normalized()
        if outward.length_squared() < 0.001:
            outward = Vector3.FORWARD

        var lamp_position := anchor_world + outward * inner_lamp_outset
        var lamp := _create_inner_board_lamp(i, lamp_position, outward)
        root.add_child(lamp)
        _inner_board_lamps.append(lamp)
```

---

## 9. 单盏路灯结构

建议新增：

```gdscript
func _create_inner_board_lamp(index: int, base_position: Vector3, outward: Vector3) -> Node3D:
    var lamp := Node3D.new()
    lamp.name = "InnerLamp_%d" % index
    lamp.global_position = base_position

    # 让灯杆的装饰朝向棋盘中心
    var yaw := atan2(outward.x, outward.z)
    lamp.rotation.y = yaw

    var pole := MeshInstance3D.new()
    pole.name = "Pole"
    var pole_mesh := CylinderMesh.new()
    pole_mesh.height = inner_lamp_height
    pole_mesh.top_radius = inner_lamp_pole_radius
    pole_mesh.bottom_radius = inner_lamp_pole_radius
    pole_mesh.radial_segments = 12
    pole.mesh = pole_mesh
    pole.position = Vector3(0.0, inner_lamp_height * 0.5, 0.0)
    pole.material_override = _make_lamp_pole_material()
    lamp.add_child(pole)

    var arm := MeshInstance3D.new()
    arm.name = "Arm"
    var arm_mesh := CylinderMesh.new()
    arm_mesh.height = 0.55
    arm_mesh.top_radius = inner_lamp_pole_radius * 0.65
    arm_mesh.bottom_radius = inner_lamp_pole_radius * 0.65
    arm_mesh.radial_segments = 10
    arm.mesh = arm_mesh
    arm.position = Vector3(0.0, inner_lamp_light_height, -0.23)
    arm.rotation_degrees.x = 90.0
    arm.material_override = _make_lamp_pole_material()
    lamp.add_child(arm)

    var shade := MeshInstance3D.new()
    shade.name = "Shade"
    var shade_mesh := ConeMesh.new()
    shade_mesh.height = 0.22
    shade_mesh.bottom_radius = 0.24
    shade_mesh.top_radius = 0.11
    shade_mesh.radial_segments = 16
    shade.mesh = shade_mesh
    shade.position = Vector3(0.0, inner_lamp_light_height - 0.03, -0.46)
    shade.rotation_degrees.x = 180.0
    shade.material_override = _make_lamp_shade_material()
    lamp.add_child(shade)

    var bulb := MeshInstance3D.new()
    bulb.name = "Bulb"
    var bulb_mesh := SphereMesh.new()
    bulb_mesh.radius = inner_lamp_bulb_radius
    bulb_mesh.height = inner_lamp_bulb_radius * 2.0
    bulb_mesh.radial_segments = 16
    bulb_mesh.rings = 8
    bulb.mesh = bulb_mesh
    bulb.position = Vector3(0.0, inner_lamp_light_height - 0.12, -0.46)
    bulb.material_override = _make_lamp_bulb_material(0.0)
    lamp.add_child(bulb)
    _inner_lamp_bulbs.append(bulb)

    var light := SpotLight3D.new()
    light.name = "LampLight"
    light.position = bulb.position
    light.light_color = inner_lamp_color
    light.light_energy = 0.0
    light.spot_range = inner_lamp_range
    light.spot_angle = inner_lamp_spot_angle
    light.spot_attenuation = inner_lamp_spot_attenuation
    light.shadow_enabled = false
    lamp.add_child(light)
    _inner_lamp_lights.append(light)

    # 让 SpotLight3D 照向棋盘中心附近
    var target_global := Vector3.ZERO + Vector3.UP * 0.25
    light.look_at(target_global, Vector3.UP)

    return lamp
```

注意：如果实际测试中 `SpotLight3D` 方向反了，允许在 `look_at()` 后增加本地旋转修正。修正前应先用 debug marker 确认方向。

---

## 10. 材质函数

建议新增：

```gdscript
func _make_lamp_pole_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = inner_lamp_pole_color
    mat.roughness = 0.65
    mat.metallic = 0.15
    return mat

func _make_lamp_shade_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = inner_lamp_shade_color
    mat.roughness = 0.75
    mat.metallic = 0.05
    return mat

func _make_lamp_bulb_material(energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = inner_lamp_color
    mat.emission_enabled = true
    mat.emission = inner_lamp_color
    mat.emission_energy_multiplier = energy
    return mat
```

如果担心每帧创建材质，可后续优化为共享材质或缓存材质。本轮优先实现位置和功能正确。

---

## 11. 接入日夜时间系统

在 `TIME_OF_DAY_KEYFRAMES` 中为每个关键帧新增：

```gdscript
"inner_lamp_scale": 1.0
```

建议数值：

```text
0.0   深夜：1.00
5.5   日出：0.45
9.0   上午：0.00
12.5  正午：0.00
17.5  黄昏：0.65
21.0  夜晚：1.00
24.0  深夜：1.00
```

效果目标：

1. 白天路灯模型存在，但灯泡不亮，真实灯光关闭。
2. 黄昏路灯逐渐亮起。
3. 夜晚路灯暖光照向棋盘中心区域。
4. 日出路灯逐渐熄灭。

在 `_apply_time_of_day()` 采样结果中保留 `inner_lamp_scale`，并在 `_refresh_lighting_nodes()` 中调用：

```gdscript
_refresh_inner_board_lamps()
```

---

## 12. 刷新路灯亮度

新增：

```gdscript
func _refresh_inner_board_lamps() -> void:
    if _inner_board_lamps.is_empty():
        return

    var scale := float(_lighting_settings.get("inner_lamp_scale", 0.0))
    var profile_multiplier := float(_render_cost_settings.get("lamp_energy_multiplier", 1.0))
    var final_energy := inner_lamp_energy * scale * profile_multiplier
    var bulb_energy := clamp(scale * 1.8, 0.0, 2.2)

    for bulb in _inner_lamp_bulbs:
        if not is_instance_valid(bulb):
            continue
        bulb.visible = inner_lamps_enabled
        if bulb.material_override is StandardMaterial3D:
            var mat := bulb.material_override as StandardMaterial3D
            mat.emission_energy_multiplier = bulb_energy

    for light in _inner_lamp_lights:
        if not is_instance_valid(light):
            continue
        light.light_color = inner_lamp_color
        light.spot_range = inner_lamp_range
        light.spot_angle = inner_lamp_spot_angle
        light.light_energy = final_energy
```

注意：真实灯光最终是否启用，还要受光源预算系统控制。时间系统只负责亮度，预算系统负责数量。

---

## 13. 接入渲染开销档和光源预算

在 `LIGHT_BUDGETS` 中新增：

```gdscript
"inner_lamp_real_light_count": 6
```

建议预算：

```text
high:
  inner_lamp_real_light_count = 6

medium:
  inner_lamp_real_light_count = 4

low:
  inner_lamp_real_light_count = 2
```

在 `_refresh_light_budget()` 中新增：

```gdscript
_apply_light_budget_to_lamps(_inner_lamp_lights, int(budget.get("inner_lamp_real_light_count", 0)))
```

新增通用函数或复用现有预算函数：

```gdscript
func _apply_light_budget_to_lamps(lights: Array[SpotLight3D], active_count: int) -> void:
    for i in lights.size():
        var light := lights[i]
        if not is_instance_valid(light):
            continue
        var enabled := i < active_count
        light.visible = enabled
        if not enabled:
            light.light_energy = 0.0
```

如果当前项目已有类似 `_apply_light_budget_to_omni_lights()`，可抽象为支持 `Light3D` 的通用版本：

```gdscript
func _apply_light_budget_to_lights(lights: Array, active_count: int) -> void:
    for i in lights.size():
        var light := lights[i]
        if not is_instance_valid(light):
            continue
        var enabled := i < active_count
        light.visible = enabled
        if not enabled and light is Light3D:
            light.light_energy = 0.0
```

---

## 14. 与现有光源数量优化的关系

内角路灯不是替代现有 `BoardGlow`，而是承担夜晚主要照明作用。

建议职责分配：

```text
BoardGlow:
  地面氛围点缀，低档可以关闭真实点光，仅保留发光网格。

InnerBoardLamps:
  夜晚棋盘边缘和内角主照明，使用 SpotLight3D 朝棋盘中心照射。

BoardFill:
  柔和补光，控制棋盘暗部不要死黑。

ForestRim / MoodLights:
  背景氛围，不应承担棋盘主体照明。
```

因此，夜晚场景中建议让路灯承担更明确的主次关系：

1. 路灯：暖色局部主照明。
2. 月光或环境光：暗蓝色整体底光。
3. 棋盘 glow：弱装饰。
4. 萤火虫 / 花园灯：背景点缀。

---

## 15. 位置调试方案

如果 Codex 实现后路灯位置仍不准确，先不要手改世界坐标。应使用以下调试手段。

### 15.1 显示锚点 marker

在每个 `anchor_world` 处生成一个小球：

```gdscript
var marker := MeshInstance3D.new()
var mesh := SphereMesh.new()
mesh.radius = 0.08
marker.mesh = mesh
marker.global_position = anchor_world + Vector3.UP * 0.08
```

锚点 marker 应该落在中心六边形的 6 个角附近。

### 15.2 显示最终路灯位置 marker

在 `lamp_position` 处生成另一个小球。最终位置应该比锚点更靠外，落在棋盘内角外侧空隙。

### 15.3 调整 `inner_lamp_outset`

如果路灯太靠棋盘中心：

```text
inner_lamp_outset 增大，例如 1.15
```

如果路灯离棋盘太远：

```text
inner_lamp_outset 减小，例如 0.75
```

禁止通过直接改每盏灯的世界坐标修位置。

---

## 16. 验收标准

### 位置验收

1. 夜晚 21.0 时，棋盘 6 个内角附近能看到 6 盏路灯。
2. 路灯不压在棋子上。
3. 路灯不压在棋盘格中心。
4. 路灯不阻挡主要棋盘路径。
5. 改变 `cell_spacing` 后，路灯仍能跟随棋盘比例移动。

### 光照验收

1. 夜晚 21.0 时，路灯灯泡发光。
2. 夜晚 21.0 时，路灯暖光能照向棋盘中心附近。
3. 正午 12.5 时，真实路灯光源关闭或能量接近 0。
4. 黄昏 17.5 时，路灯处于半亮状态。
5. 日出 5.5 时，路灯逐渐熄灭。

### 性能档验收

1. `high` 档：6 个真实路灯 `SpotLight3D` 启用。
2. `medium` 档：4 个真实路灯 `SpotLight3D` 启用。
3. `low` 档：2 个真实路灯 `SpotLight3D` 启用。
4. 所有档位下，6 个路灯模型和灯泡模型都显示。
5. 低档下不会因为真实灯光减少而导致路灯模型消失。

### 稳定性验收

1. 启动项目无报错。
2. 切换光照时间无报错。
3. 切换 `high / medium / low` 渲染开销档无报错。
4. 开启自动昼夜循环后，路灯亮度平滑变化。
5. 不影响现有棋子点击、移动、AI、回放和联网逻辑。

---

## 17. Codex 执行提示词

可以直接把下面这段给 Codex：

```text
请根据 docs/inner_board_lamps_plan.md 实现棋盘内角路灯系统。

要求：
1. 保持 Godot Forward+ 渲染方案不变。
2. 只修改 BackgroundManager.gd 和必要的 Main.tscn NodePath 配置。
3. 不修改棋盘生成、棋子规则、AI、联网、回放逻辑。
4. 路灯位置必须基于 BoardManager.coord_to_world() 计算。
5. 使用中心六边形 6 个角坐标作为锚点：
   Vector2i(0, -4), Vector2i(4, -4), Vector2i(4, 0),
   Vector2i(0, 4), Vector2i(-4, 4), Vector2i(-4, 0)
6. 最终位置 = anchor_world + outward * inner_lamp_outset。
7. 每盏路灯包含灯杆、灯罩、发光灯泡、SpotLight3D。
8. SpotLight3D 朝棋盘中心照射，默认 shadow_enabled = false。
9. 新增 inner_lamp_scale 到日夜时间关键帧。
10. 接入现有 high / medium / low 光源预算：high 6、medium 4、low 2。
11. 所有路灯模型始终显示，只有真实光源按预算和时间启用。
12. 如果位置不准确，只允许调整 inner_lamp_outset，不允许改成硬编码世界坐标。
```

---

## 18. 推荐执行顺序

不要一次性把外观调到最终效果。建议分三步实现：

### Step 1：只实现位置

1. 生成 6 个简单小柱子。
2. 不加真实灯光。
3. 确认它们都位于棋盘内角外侧。

### Step 2：实现路灯模型和夜晚亮度

1. 加灯杆、灯罩、灯泡。
2. 加 `SpotLight3D`。
3. 接入 `inner_lamp_scale`。
4. 测试 12.5 / 17.5 / 21.0 三个时间点。

### Step 3：接入光源预算

1. high = 6。
2. medium = 4。
3. low = 2。
4. 确认低档只关闭真实灯，不隐藏模型。

---

## 19. 后续可选优化

本轮完成后，可考虑以下优化：

1. 给路灯增加轻微玻璃灯罩材质。
2. 给灯泡增加小范围 `Glow` 强化。
3. 夜晚降低部分 `BoardGlow` 真实点光，让路灯成为主光。
4. 为路灯创建独立 `InnerBoardLamp.gd`，从 `BackgroundManager.gd` 中进一步拆分。
5. 为路灯添加手动 UI 开关。
6. 将程序化路灯替换为轻量低面数模型资源。

这些都不是本轮必须项。当前第一目标是：**稳定、可维护地把 6 盏路灯放到棋盘内角区域，并正确接入夜晚光照。**
