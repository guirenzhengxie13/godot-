# Meadow 场景阴影、路灯间距与材质稳定性清理方案

## 目标

当前画面已经从暗色森林方向转到明亮草地棋盘方向，但仍存在三个明显问题：

1. 内角路灯离棋盘太近，视觉上像插在棋盘边缘，干扰棋子和技能标记。
2. 场景周围出现大块暗色椭圆阴影，压低整体明亮花园氛围。
3. 部分环境物件表面材质粗糙、噪声明显，移动镜头时有闪烁、跳动、脏斑感。

本轮优化只处理视觉稳定性和场景清理，不修改棋盘规则、棋子逻辑、AI、网络、存档、回放和 UI 业务逻辑。

---

## 当前代码判断

### 1. 内角路灯已经存在，但偏靠近棋盘

`BackgroundManager.gd` 已经有内角路灯系统，并且位置由 `INNER_CORNER_ANCHORS` + `BoardManager.coord_to_world()` 生成。

当前默认参数：

```gdscript
@export var inner_lamp_outset := 0.95
@export var inner_lamp_height := 2.4
@export var inner_lamp_light_height := 2.15
```

`inner_lamp_outset = 0.95` 对当前棋盘来说偏小，路灯容易贴着棋盘边缘或落在内角附近，视觉上显得拥挤。

### 2. 大块暗影主要不是实时阴影，而是手工生成的 CanopyShade

当前代码里存在 `_build_canopy_shadow_layer()`，它生成了若干个深色半透明椭圆片：

```gdscript
material.albedo_color = Color(0.04, 0.12, 0.055, 0.28)
material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
```

这些椭圆片本质上是假树荫，不受光照影响。白天封面花园风格下，它们会显得像一块块黑色污渍。

### 3. 部分材质跳动可能来自程序噪声贴图和贴片 z-fighting

当前 `_build_prop_material()` 会给很多环境物件统一加 `NoiseTexture2D`：

```gdscript
material.albedo_texture = _get_noise_texture(material_kind)
```

`_get_noise_texture()` 使用 128x128 程序噪声贴图。对小型低模物件、远处装饰和大面积草地来说，这种噪声可能在移动镜头时产生闪烁、粗糙、跳动感。

另外，部分地面装饰贴片、假阴影贴片、池塘/水面贴片都放在接近地面的高度。如果贴片高度太接近地面，镜头移动时可能出现 z-fighting 或边缘闪烁。

---

## 本轮修改原则

1. 不继续堆灯光，不通过更强曝光掩盖问题。
2. 优先减少假暗影、降低噪声、让材质更干净。
3. 保持明亮花园棋盘方向。
4. 路灯模型保留，但从棋盘内角外移。
5. 能用参数控制的地方全部导出参数，便于后续微调。
6. 不引入大型新资源。

---

## Commit 1：路灯整体外移，避免压住棋盘内角

### 修改文件

```text
scripts/BackgroundManager.gd
```

### 修改要求

将默认路灯外移距离从：

```gdscript
@export var inner_lamp_outset := 0.95
```

改为：

```gdscript
@export var inner_lamp_outset := 1.65
```

如果实际画面仍然贴棋盘，可以继续调到 `1.85`。不要超过 `2.2`，否则灯会脱离棋盘视觉关系。

### 路灯瞄准点同步调整

当前路灯瞄准点基于 `inner_lamp_aim_center_blend`，默认：

```gdscript
@export var inner_lamp_aim_center_blend := 0.55
```

路灯外移后，建议改成：

```gdscript
@export var inner_lamp_aim_center_blend := 0.48
```

目的：灯光不要全部打到棋盘中心，而是打在内角和棋盘中心之间的区域。

### 验收标准

1. 六盏路灯不再贴住棋盘边缘。
2. 路灯不压在棋子、技能标记、可走格高亮附近。
3. 夜晚仍能照亮棋盘内角，但白天不显得突兀。

---

## Commit 2：禁用或弱化大块 CanopyShade 假阴影

### 修改文件

```text
scripts/BackgroundManager.gd
```

### 新增导出参数

在环境参数区新增：

```gdscript
@export_group("Meadow Visual Cleanup")
@export var canopy_shadow_enabled := false
@export var canopy_shadow_alpha := 0.08
@export var canopy_shadow_min_radius := 14.0
```

### 修改 `_build_canopy_shadow_layer()`

函数开头加入：

```gdscript
func _build_canopy_shadow_layer() -> void:
	if not canopy_shadow_enabled:
		return
```

并将材质颜色从：

```gdscript
material.albedo_color = Color(0.04, 0.12, 0.055, 0.28)
```

改成：

```gdscript
material.albedo_color = Color(0.06, 0.16, 0.07, canopy_shadow_alpha)
```

### 避免靠近棋盘的大暗块

如果保留 CanopyShade，所有 patch 的中心位置距离棋盘中心应不小于 `canopy_shadow_min_radius`。

可以在添加 patch 前加入：

```gdscript
var pos: Vector3 = placements[index]["pos"]
if Vector2(pos.x, pos.z).length() < canopy_shadow_min_radius:
	continue
```

### 验收标准

1. 默认明亮花园画面中，不再出现大块黑色椭圆污渍。
2. 如果手动打开 `canopy_shadow_enabled`，阴影应该很淡，只作为边缘树荫氛围。
3. 棋盘附近不出现强假阴影。

---

## Commit 3：降低环境材质噪声，减少移动时表面跳动

### 修改文件

```text
scripts/BackgroundManager.gd
```

### 新增导出参数

```gdscript
@export var prop_noise_enabled := false
@export var prop_noise_texture_size := 64
@export var prop_noise_frequency_scale := 0.45
```

### 修改 `_build_prop_material()`

当前逻辑：

```gdscript
material.albedo_texture = _get_noise_texture(material_kind)
```

改为：

```gdscript
if prop_noise_enabled and material_kind in ["rock", "stone", "bark"]:
	material.albedo_texture = _get_noise_texture(material_kind)
else:
	material.albedo_texture = null
```

说明：

- 默认关闭噪声，让封面花园风格更干净。
- 只允许石头、石板、木头在需要时使用轻微噪声。
- 草、叶子、花不要使用程序噪声贴图，避免镜头移动时碎闪。

### 修改 `_get_noise_texture()`

当前贴图尺寸为 128：

```gdscript
texture.width = 128
texture.height = 128
```

改成：

```gdscript
texture.width = prop_noise_texture_size
texture.height = prop_noise_texture_size
```

当前频率：

```gdscript
noise.frequency = 0.085
```

改成：

```gdscript
noise.frequency = 0.085 * prop_noise_frequency_scale
```

草、树皮、岩石的频率分支也乘以 `prop_noise_frequency_scale`。

### 材质粗糙度建议

将 `_build_prop_material()` 中默认值从：

```gdscript
material.roughness = 0.74
```

改为：

```gdscript
material.roughness = 0.64
```

各类材质建议：

```gdscript
match material_kind:
	"leaf", "leaf_dark", "grass":
		material.roughness = 0.72
	"stone":
		material.roughness = 0.62
		material.normal_enabled = false
	"rock":
		material.roughness = 0.68
	"bark":
		material.roughness = 0.78
	"flower":
		material.roughness = 0.58
```

### 验收标准

1. 移动镜头时，环境小物件表面不再明显闪烁。
2. 石头、树、灯杆、花草不再有过强脏噪点。
3. 画面更接近封面图的干净、柔和、低噪声风格。

---

## Commit 4：修正地面和贴片 z-fighting 风险

### 修改文件

```text
scripts/BackgroundManager.gd
```

### 调整贴片高度规则

给地面贴片、假阴影、池塘、水面、石岸等贴片建立明确高度层级：

```text
GrassFloor 顶面附近：y = -0.12 + floor_height / 2
草地装饰底层贴片：y = 0.035
水面贴片：y = 0.055
石岸 / 小路贴片：y = 0.065
假阴影贴片：y = 0.075
```

不要让多个透明/半透明片使用非常接近的 y 值。

### 修改建议

1. `CoverMeadowGround` 的 y 从 `0.026` 提到 `0.05`。
2. `CanopyShade` 如果启用，y 从 `0.035` 提到 `0.075`。
3. 池塘水面和水带略高于石岸或明确错层，不要和底层地面重叠。
4. 所有透明贴片 `cast_shadow = SHADOW_CASTING_SETTING_OFF`。

### 验收标准

1. 镜头移动时，地面贴片不闪、不跳、不出现斑块交替覆盖。
2. 水面、草地、假阴影不会互相抢深度。
3. 场景边缘装饰仍然存在，但不会影响棋盘主体。

---

## Commit 5：环境物件阴影策略收敛

### 修改文件

```text
scripts/BackgroundManager.gd
```

### 新增导出参数

```gdscript
@export var decorative_prop_shadows_enabled := false
@export var landmark_shadows_enabled := true
```

### 修改 `_spawn_prop_from_root()`

当前默认逻辑：

```gdscript
_set_prop_shadow_mode(node, bool(placement.get("cast_shadow", material_kind not in ["grass", "flower", "leaf", "leaf_dark"])))
```

建议改成：

```gdscript
var default_shadow := decorative_prop_shadows_enabled and material_kind in ["stone", "rock", "bark"]
_set_prop_shadow_mode(node, bool(placement.get("cast_shadow", default_shadow)))
```

说明：

- 普通装饰物默认不投影。
- 只有少量大型地标、亭子、石桥可以投影。
- 明亮花园风格下，大面积随机阴影会降低干净感。

### 验收标准

1. 棋盘周围不会再出现杂乱碎阴影。
2. 大型地标仍然可以有轻微阴影，但不压暗棋盘主体。
3. 画面更接近封面图的柔和商业插画风格。

---

## 建议执行顺序

不要一次性做完全部。建议按以下顺序：

```text
1. Commit 2：先禁用 CanopyShade 大块假阴影
2. Commit 1：路灯外移
3. Commit 3：关闭环境物件噪声贴图
4. Commit 4：修正贴片高度，处理 z-fighting
5. Commit 5：收敛环境物件阴影
```

原因：当前截图里最明显的问题是大块暗影，其次才是路灯位置和材质闪烁。

---

## 给 Codex 的最小执行指令

先执行最小版本：

```text
请根据 docs/meadow_scene_shadow_material_cleanup_plan.md 先执行 Commit 2 和 Commit 1。
只修改 scripts/BackgroundManager.gd。
目标是：默认禁用或极大弱化 CanopyShade 大块假阴影，并把内角路灯从棋盘边缘向外移动。
不要修改棋盘规则、棋子逻辑、AI、网络、存档和 UI。
保持 Forward+ 渲染器不变。
```

如果这一步画面明显变干净，再继续执行 Commit 3：

```text
继续根据 docs/meadow_scene_shadow_material_cleanup_plan.md 执行 Commit 3。
目标是默认关闭环境物件程序噪声贴图，降低材质粗糙脏斑和移动时闪烁。
```
