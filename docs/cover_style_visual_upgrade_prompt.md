# Codex 任务：将实际游戏画面向封面图的花园棋盘效果靠拢

## 0. 背景与目标

当前游戏已经实现了 Forward+ 渲染、日夜时间系统、渲染开销分档、内角路灯和基础庭院环境。当前实际截图的优点是：夜晚氛围、局部暖光、棋盘灯光已经可见。但整体视觉仍偏“黑暗森林 + 深色破碎石板 + 雾气遮挡”，与封面图目标存在明显差距。

本任务目标不是继续堆叠光源，也不是重做玩法逻辑，而是将默认展示方向调整为封面图风格：

- 明亮、温暖、清晰的日间花园棋盘。
- 浅色石板棋盘，边缘柔和，整体干净。
- 草地更鲜绿，花丛、灌木、岩石、桥、亭子/庭院装饰形成精致场景。
- 棋盘是画面主视觉，周围装饰服务于构图，不喧宾夺主。
- 夜晚和路灯可以保留，但默认封面/开始菜单/主推效果应以日间花园风格为准。

保持以下约束：

1. 保持 `project.godot` 中的 Forward+ 渲染器，不切换到 Mobile 或 Compatibility。
2. 不修改棋子规则、AI、联网、回放、胜负判断等玩法逻辑。
3. 优先修改视觉相关文件，主要是：
   - `scripts/BackgroundManager.gd`
   - `scripts/BoardManager.gd`
   - `scripts/Cell.gd`
   - 必要时少量修改 `scripts/GameManager.gd` / `scripts/GameUI.gd` 用于接入新预设。
4. 不要求一次性做出封面级最终品质，但要把默认风格方向从“暗夜森林”纠正到“明亮花园棋盘”。

---

## 1. 当前实际画面问题诊断

### 1.1 棋盘太暗、太脏、纹理噪声过强

实际截图中的棋盘是深蓝灰色破碎石材，纹理对比度很高。夜晚暖光照上去后，棋盘中央变亮，但整体仍显得脏、杂、硬。

封面图的棋盘是浅米色/浅灰色石板，格子边界清晰但不刺眼，整体感觉干净、温暖、适合桌游。

需要改动方向：

- 新增一个“封面风格棋盘材质”或默认棋盘材质。
- 棋盘主色从深蓝黑改为浅米灰。
- 降低法线和纹理粗糙噪声。
- 高亮状态仍保留，但默认状态不要自发光。
- 棋盘边缘可以略带草地绿色或浅阴影，增强嵌入草地的感觉。

### 1.2 环境太暗，雾气过重

实际截图整体雾气较重，远景和四角都被压暗，画面接近恐怖/夜探氛围。封面图虽然有景深和暗角，但核心区域很明亮，棋盘和棋子都非常清楚。

需要改动方向：

- 新增 `cover_meadow` / `meadow_day` 光影预设。
- 默认时间可以设为上午或正午，例如 `time_of_day = 9.0` 或 `12.5`。
- 降低日间雾气密度。
- 提高环境光和太阳光可读性。
- 使用暖色主光 + 柔和环境光，而不是蓝黑夜色。

### 1.3 路灯模型方向与封面图不一致

当前内角路灯更像黑色细杆路灯，夜晚照明已经开始生效。但封面图更接近日式/庭院石灯笼：低矮、方形灯箱、绿色/青色小屋顶、暖色窗格。

需要改动方向：

- 不删除现有内角路灯系统。
- 新增一种 `garden_lantern` 风格模型，可复用内角锚点或庭院环位置。
- 白天显示为庭院装饰，夜晚灯箱发暖光。
- 封面风格中优先使用低矮庭院灯笼，而不是黑色高杆路灯。

### 1.4 周围装饰缺少“精致庭院构图”

封面图的周围环境有明确层次：草地、花、石头、桥、水景、亭子/建筑、灌木，围绕棋盘形成精致的园林感。实际截图的装饰更随机，且夜晚被雾和暗色压掉了。

需要改动方向：

- 新增一个 `cover_meadow` 场景装饰布局。
- 装饰不要完全随机，应使用半固定构图点位。
- 棋盘四周加入：
  - 左上/左侧：桥或水景元素。
  - 后方：亭子/小建筑/岩石组。
  - 四角：花丛、灌木、石头。
  - 棋盘周边：低矮庭院灯笼。
- 中心棋盘周围 1.0~1.8 个格距内保持清爽，不要让装饰压到棋盘。

### 1.5 摄像机和景深缺少封面感

封面图是斜俯视、浅景深、棋盘居中偏左、右侧 UI 面板覆盖的构图。实际游戏局内截图更偏纯俯视调试视角，棋盘占比大但画面没有“产品封面”感。

需要改动方向：

- 对开始菜单/封面展示增加专用相机姿态。
- 不强制改变局内操作相机。
- 封面相机应更低一点、更斜一点，焦点在棋盘中心，开启轻微 DOF 和暗角。

---

## 2. 推荐实现总方案

新增一个视觉目标：`cover_meadow`。

这个目标不是一个普通光影滑条，而是一组协同设置：

```text
cover_meadow = 浅色棋盘材质 + 明亮日间光照 + 精致草地庭院装饰 + 低矮庭院灯笼 + 封面相机姿态
```

建议分为 4 个阶段实现：

1. **棋盘材质先改亮**：解决最大视觉差距。
2. **新增 cover_meadow 光影预设**：让环境从夜晚森林转到温暖日间。
3. **新增半固定庭院装饰布局**：增加封面图的精致感。
4. **新增封面相机姿态/景深**：用于开始菜单或展示画面。

不要一次性大改 UI 和玩法。

---

## 3. Task 1：新增封面风格棋盘材质

### 3.1 目标

将棋盘默认外观从“深色破碎石材”向“浅米色石板”靠拢。

封面目标关键词：

```text
warm ivory stone tiles, clean hex board, soft bevel, subtle stone variation, readable grid, not noisy, garden board game
```

### 3.2 修改建议

优先在 `BoardManager.gd` 和 `Cell.gd` 现有材质机制上实现，不要重写棋盘生成。

当前 `BoardManager` 会实例化 `Cell.tscn`，并对每个格子调用 `cell.set_material_profile()`。棋盘格世界坐标由 `coord_to_world()` 管理，不要破坏这套结构。

新增一个材质 profile，例如：

```gdscript
"cover_meadow_stone": {
    "label": "封面浅石板",
    "color_path": "",
    "normal_path": "",
    "roughness": 0.56,
    "base_color": Color(0.82, 0.80, 0.68),
    "side_color": Color(0.46, 0.50, 0.34),
    "normal_scale": 0.035,
}
```

如果现有材质扫描机制不方便直接新增 profile，则先用代码 fallback：当 `_board_material_id == "cover_meadow_stone"` 时，`Cell` 使用浅色 procedural 材质。

### 3.3 Cell.gd 具体要求

在 `Cell.gd` 中支持材质 profile 的这些可选字段：

```gdscript
base_color: Color
side_color: Color
normal_scale: float
roughness: float
clearcoat: float
clearcoat_roughness: float
```

默认封面棋盘建议：

```gdscript
base_color = Color(0.80, 0.78, 0.66)
side_color = Color(0.45, 0.50, 0.34)
roughness = 0.58
normal_scale = 0.025
clearcoat = 0.18
clearcoat_roughness = 0.42
```

不要让普通棋盘格开启 emission。只有选中、合法目标、技能范围等交互状态才允许 emission。

### 3.4 验收标准

- 正午/上午时间下，棋盘整体接近封面图的浅色石板。
- 棋盘纹理不再像黑色碎石，不抢走棋子和 UI 的注意力。
- 格子边界仍然清楚。
- 棋子颜色在浅色棋盘上更醒目。

---

## 4. Task 2：新增 cover_meadow 光影预设

### 4.1 目标

新增一个专门向封面图靠拢的日间预设，而不是直接改掉所有夜晚效果。

建议 ID：

```gdscript
"cover_meadow"
```

显示名：

```text
封面花园
```

### 4.2 BackgroundManager.gd 参数建议

在 `LIGHTING_PRESETS` 中新增：

```gdscript
"cover_meadow": {
    "label": "封面花园",
    "ambient_energy": 0.82,
    "sun_energy": 0.105,
    "fill_energy": 0.055,
    "reflection_intensity": 0.045,
    "exposure": 0.96,
    "ssao_intensity": 0.72,
    "render_scale": 1.2,
    "msaa_level": 2.0,
    "fxaa_enabled": 1.0,
    "taa_enabled": 0.0,
    "debanding_enabled": 1.0,
    "floor_tint_r": 0.58,
    "floor_tint_g": 0.82,
    "floor_tint_b": 0.42,
    "floor_normal_scale": 0.16,
    "fog_density": 0.0018,
    "fog_sky_affect": 0.10,
    "sun_pitch": -38.0,
    "sun_yaw": -132.0,
    "sun_angular_distance": 12.0,
    "board_fill_scale": 0.75,
    "forest_rim_scale": 0.0,
    "mood_light_scale": 0.0,
    "firefly_energy": 0.0,
    "board_glow_energy": 0.035,
    "marker_glow_energy": 0.58,
}
```

同时把 `cover_meadow` 加入 `LIGHTING_PRESET_ORDER`。

### 4.3 时间系统建议

封面风格不要使用夜晚 `21.0`。建议提供方法：

```gdscript
func apply_cover_meadow_visual_target() -> void:
    apply_lighting_preset("cover_meadow")
    set_time_of_day(9.0)
    set_auto_time_cycle_enabled(false)
```

如果已有 UI 光影菜单，可以让用户从菜单手动选择；如果开始菜单需要默认封面效果，则在开始菜单显示时调用。

### 4.4 验收标准

- 应能在光影预设菜单中选择“封面花园”。
- 选择后画面应明显变亮，雾气降低。
- 棋盘和棋子成为清晰主体。
- 夜晚路灯功能仍然保留，不被删除。

---

## 5. Task 3：新增封面庭院装饰布局

### 5.1 目标

让棋盘周围环境从“随机森林”转为“精致庭院”。

封面目标关键词：

```text
small garden bridge, gazebo / pavilion, stone lanterns, rounded rocks, flower clusters, trimmed shrubs, meadow grass, miniature garden board game
```

### 5.2 新增布局模式

在 `BackgroundManager.gd` 中新增导出字段：

```gdscript
@export var cover_meadow_layout_enabled := true
```

新增函数：

```gdscript
func _build_cover_meadow_layout() -> void:
    pass
```

这个函数应在地面、草地、主要装饰资源加载后调用。

### 5.3 半固定装饰点位

使用半固定点位，不要完全随机。示例：

```gdscript
const COVER_MEADOW_PROP_POINTS := [
    {"kind": "bridge", "position": Vector3(-8.8, 0.18, -5.8), "yaw": 28.0, "scale": 0.95},
    {"kind": "pavilion", "position": Vector3(-4.8, 0.18, -8.8), "yaw": -18.0, "scale": 0.85},
    {"kind": "rock_cluster", "position": Vector3(4.8, 0.18, -7.4), "yaw": 14.0, "scale": 1.15},
    {"kind": "rock_cluster", "position": Vector3(6.6, 0.18, 3.8), "yaw": -24.0, "scale": 1.0},
    {"kind": "flower_cluster", "position": Vector3(-7.6, 0.18, 5.2), "yaw": 8.0, "scale": 1.0},
    {"kind": "flower_cluster", "position": Vector3(2.2, 0.18, 8.0), "yaw": -12.0, "scale": 0.9},
    {"kind": "shrub_cluster", "position": Vector3(-6.2, 0.18, 0.8), "yaw": 34.0, "scale": 0.9},
    {"kind": "shrub_cluster", "position": Vector3(7.4, 0.18, -1.2), "yaw": -42.0, "scale": 1.0},
]
```

注意：这些是建议初始点位，实际可以微调。棋盘中心区域应保持干净，不要遮挡棋子移动和格子点击。

### 5.4 模型选择策略

优先使用现有 `assets/environment/kenney_nature` 与 `assets/environment/kenney_landmarks` 资源。

不要硬编码一个不存在的模型路径。实现时应写安全加载函数：

```gdscript
func _try_load_first_scene(paths: Array[String]) -> PackedScene:
    for path in paths:
        if ResourceLoader.exists(path):
            return load(path)
    return null
```

如果找不到模型，使用简单几何 fallback：

- bridge fallback：几个浅灰色长方体拼成桥。
- pavilion fallback：Cylinder/Box 组合出小亭子轮廓。
- rock fallback：低多边形 SphereMesh / BoxMesh。
- flower fallback：小球 + 细杆。
- shrub fallback：绿色半球。

### 5.5 验收标准

- 开始菜单或封面视角下，棋盘周边有明显花园装饰层次。
- 装饰不压到棋盘中心，不挡主要棋子。
- 左上/后方/右侧/下方都有视觉元素，不再像随机散落物。
- 远景不需要很密，重点是封面构图清楚。

---

## 6. Task 4：将高杆路灯补充为庭院灯笼风格

### 6.1 目标

保留当前内角路灯的照明功能，但增加一种更接近封面图的低矮庭院灯笼。

新增导出字段：

```gdscript
@export var inner_lamp_visual_style := "garden_lantern" # "pole" / "garden_lantern"
```

默认建议改为：

```gdscript
"garden_lantern"
```

### 6.2 garden_lantern 结构

每个灯笼节点建议结构：

```text
GardenLantern
  ├─ BaseStone        # 石基座，浅灰色
  ├─ BodyFrame        # 方形灯箱框架，深木色/石色
  ├─ WarmWindow       # 发光窗面，暖黄色 emission
  ├─ Roof             # 小屋顶，绿色/青灰色
  └─ LampLight        # SpotLight3D 或 OmniLight3D，夜晚启用
```

白天：灯箱不发强光，只作为装饰。

夜晚：窗面 emission 增强，真实光源按 `LIGHT_BUDGETS` 启用。

### 6.3 视觉参数建议

```gdscript
lantern_height = 0.95
lantern_base_size = 0.36
lantern_body_size = 0.42
lantern_roof_size = 0.58
lantern_window_color = Color(1.0, 0.72, 0.36)
lantern_roof_color = Color(0.18, 0.30, 0.22)
lantern_frame_color = Color(0.18, 0.13, 0.09)
```

封面图中的庭院灯偏低矮，不要做成黑色细长杆。

### 6.4 验收标准

- 白天画面能看到接近封面图的低矮庭院灯笼。
- 夜晚仍能照亮棋盘边缘。
- high/medium/low 光源预算仍然生效。

---

## 7. Task 5：封面相机姿态与景深

### 7.1 目标

封面图不是普通游戏视角，而是展示视角。不要直接覆盖玩家操作相机，建议新增“封面相机姿态”。

新增方法，放在相机控制脚本或 `GameManager.gd` 桥接中：

```gdscript
func apply_cover_camera_pose() -> void:
    pass
```

### 7.2 推荐相机参数

初始建议：

```gdscript
camera.position = Vector3(0.0, 9.4, 9.2)
camera.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
camera.fov = 38.0
```

也可以略微偏左：

```gdscript
camera.position = Vector3(-1.4, 9.2, 9.4)
camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
```

### 7.3 景深与暗角

如果当前相机已有 CameraAttributes，则新增或调整：

```gdscript
attributes.dof_blur_far_enabled = true
attributes.dof_blur_far_distance = 12.0
attributes.dof_blur_far_transition = 6.0
attributes.dof_blur_amount = 0.16
```

不要让景深影响棋盘中心清晰度。棋盘和棋子必须清楚，远处装饰可以轻微虚化。

暗角可以通过 UI 背景或后处理实现，但不要过重。封面图四周暗，中心亮；实际图当前是整体暗，这两者不同。

### 7.4 验收标准

- 开始菜单画面应类似封面图：棋盘居中偏左，右侧 UI 面板不遮挡棋盘主体。
- 棋盘中心清晰，远景轻微虚化。
- 不影响局内玩家正常旋转/缩放视角。

---

## 8. Task 6：开始菜单默认使用封面视觉目标

### 8.1 目标

进入游戏开始菜单时，自动呈现封面图风格；进入实际对局后，可以保留玩家选择的光影/时间。

建议流程：

```text
启动游戏 → 开始菜单显示 → apply_cover_meadow_visual_target() + apply_cover_camera_pose()
点击开始对战 → 进入游戏 → 保持当前视觉，或切换到用户上次选择
```

不要在每帧强制应用封面预设，否则用户手动调节会被覆盖。

### 8.2 验收标准

- 启动后第一眼接近封面图。
- 用户进入游戏后仍可通过光影菜单改回夜晚、黄昏、高/中/低渲染等。
- 自动昼夜不会在开始菜单默认乱动，除非用户开启。

---

## 9. 禁止事项

本任务不要做以下事情：

1. 不要切换渲染器。
2. 不要删除日夜系统。
3. 不要删除内角路灯系统。
4. 不要改棋子移动规则。
5. 不要把所有视觉参数写死在 `_process()` 里。
6. 不要使用不存在的模型路径导致运行时报错。
7. 不要把装饰物放到棋盘格中心或阻挡棋子。
8. 不要让普通棋盘格开启强 emission，封面图的亮来自光照和浅色材质，不是棋盘自发光。

---

## 10. 推荐执行顺序

按以下顺序提交，避免一次性大改难以排查：

### Commit 1：封面浅色棋盘材质

- 修改 `Cell.gd` 支持 profile 色彩字段。
- 修改 `BoardManager.gd` 新增或选择 `cover_meadow_stone`。
- 验证棋盘变浅。

### Commit 2：cover_meadow 光影预设

- 修改 `BackgroundManager.gd` 新增 `cover_meadow`。
- 保持 Forward+。
- 验证上午/正午效果接近封面图。

### Commit 3：封面庭院装饰布局

- 新增 `_build_cover_meadow_layout()`。
- 加桥、亭子、岩石、花丛、灌木 fallback。
- 验证构图。

### Commit 4：庭院灯笼模型

- 在现有内角路灯系统上新增 `garden_lantern` 样式。
- 保持夜晚照明预算。

### Commit 5：封面相机姿态

- 新增封面相机 pose。
- 开始菜单使用封面视觉。

---

## 11. 最终目标描述

最终启动画面应接近以下描述：

```text
A cozy miniature Chinese Checkers board placed in a bright meadow garden. The board is made of clean warm ivory hexagonal stone tiles. Colorful red, blue, and yellow pieces sit clearly on the board. Around the board are soft green grass, flowers, rounded rocks, small shrubs, a small garden bridge, and low Japanese-style lanterns with green roofs. Warm morning sunlight enters from the upper left, with soft shadows, slight depth of field, and a gentle vignette. The center board remains sharp and readable, while background props are softly blurred. The mood is polished, inviting, and playful rather than dark or foggy.
```

中文方向：

```text
明亮草地庭院里的精致跳棋棋盘，浅色六边形石板，红蓝黄棋子清晰醒目，周围有花草、岩石、灌木、小桥、庭院灯笼和亭子。暖色日光从左上方照入，中心棋盘清晰，远景轻微虚化，整体温暖、干净、适合封面展示。
```

---

## 12. 快速验收清单

完成后请逐项检查：

- [ ] 默认/封面画面不再是深色夜晚森林。
- [ ] 棋盘是浅米灰石板，接近封面图。
- [ ] 草地更鲜绿，雾气明显降低。
- [ ] 棋子在棋盘上清楚醒目。
- [ ] 周围有桥、岩石、花丛、灌木、庭院灯笼等构图元素。
- [ ] 内角灯笼白天是装饰，夜晚会亮。
- [ ] high/medium/low 渲染开销档仍可用。
- [ ] 日夜系统仍可用。
- [ ] 开始菜单封面视角接近参考封面图。
- [ ] 玩法逻辑没有变化。
