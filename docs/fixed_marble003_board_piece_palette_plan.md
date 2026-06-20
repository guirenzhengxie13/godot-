# 固定 003 大理石棋盘与棋子内置调色盘方案

## 目标

本轮只处理棋盘与棋子的材质选择逻辑，不修改棋盘规则、AI、网络、存档、回放、光照、日夜循环和场景装饰。

目标效果：

1. 棋盘固定使用名称以 `003` 结尾的大理石材质。当前代码中已经出现的目标材质 ID 为 `大理石/Travertine003`。
2. 只保留这个 `003` 大理石棋盘材质，其它棋盘材质不再出现在 UI 选择项中。
3. 棋子不再使用大理石、石材、草地等贴图材质，改为内置基础颜色调色盘。
4. 玩家 1、玩家 2 的棋子颜色从调色盘中选择。
5. 增加颜色互斥系统：两个玩家不能选择相同颜色，也不能选择过于相近的颜色。
6. 保留当前 `BoardManager.apply_board_material()`、`BoardManager.apply_player_material()` 这类调用入口，但内部语义可以改为“棋盘固定材质 + 玩家颜色配置”。

## 当前代码事实

`BoardManager.gd` 目前统一维护棋盘和棋子材质选项：

- `material_options` 保存所有可选材质。
- `_board_material_id` 保存当前棋盘材质。
- `_player_material_ids` 保存玩家 1、玩家 2 的棋子材质。
- `apply_board_material(material_id)` 会给所有 cell 应用 profile。
- `apply_player_material(player_id, material_id)` 会给指定玩家的所有棋子应用 profile。

当前默认棋盘材质是内置的 `cover_meadow_stone`，而玩家棋子默认会优先选择若干大理石材质，其中已经包含 `大理石/Travertine003`。也就是说，`Travertine003` 目前存在于代码优先级里，但它还不是固定棋盘材质。当前 `_choose_initial_materials()` 中，棋盘默认写死为 `COVER_MEADOW_STONE_ID`，玩家材质首选列表中包含 `大理石/Travertine003`。

## 非目标

本轮不要做这些事情：

1. 不要继续调整草地、树木、阴影、雾、灯光。
2. 不要删除磁盘上的贴图资源文件，除非用户后续明确要求清理资源。
3. 不要重构 `GameUI.gd` 的整体菜单结构。
4. 不要改变棋子形状、技能视觉、Label3D 技能文字。
5. 不要改变存档格式中的棋子坐标、技能、回放逻辑。
6. 不要把玩家颜色写死到 `Piece.gd` 导出变量里，让颜色仍然由 `BoardManager` 统一下发。

## 推荐实现

### 1. BoardManager 中拆分“棋盘材质”和“棋子颜色”

当前 `material_options` 同时给棋盘和棋子使用。建议改成两个列表：

```gdscript
var board_material_options: Array[Dictionary] = []
var piece_color_options: Array[Dictionary] = []
```

为了兼容现有 UI，也可以暂时保留：

```gdscript
var material_options: Array[Dictionary] = []
```

但后续应让：

- 棋盘 OptionButton 只读 `board_material_options`。
- 玩家颜色 OptionButton 只读 `piece_color_options`。

如果不想大改 UI，可以让 `get_material_options()` 临时返回合并列表，但每个 option 增加字段：

```gdscript
"usage": "board" 或 "piece"
```

然后 UI 按 usage 分别过滤。

### 2. 固定棋盘目标材质

新增常量：

```gdscript
const FIXED_BOARD_MARBLE_ID := "大理石/Travertine003"
const FIXED_BOARD_MARBLE_SUFFIX := "003"
```

目标材质优先级：

1. 优先使用 `大理石/Travertine003`。
2. 如果路径不存在，扫描所有 `大理石` 分类下 ID 以 `003` 结尾的材质。
3. 如果仍不存在，使用 `COVER_MEADOW_STONE_ID` 作为安全 fallback，并打印 warning。

实现函数：

```gdscript
func _resolve_fixed_board_material_id() -> String:
	if _has_material_id(FIXED_BOARD_MARBLE_ID):
		return FIXED_BOARD_MARBLE_ID
	for option in material_options:
		var id := String(option.get("id", ""))
		var category := String(option.get("category", ""))
		if category == "大理石" and id.get_file().ends_with(FIXED_BOARD_MARBLE_SUFFIX):
			return id
	push_warning("Fixed 003 marble board material was not found; using cover meadow stone fallback.")
	return COVER_MEADOW_STONE_ID
```

注意：`id` 的格式类似 `大理石/Travertine003`，`id.get_file()` 可以得到 `Travertine003`。

### 3. 只暴露固定棋盘材质

扫描材质资源时可以继续扫描全部资源，但 UI 棋盘选择只显示固定材质。

新增：

```gdscript
func get_board_material_options() -> Array[Dictionary]:
	var fixed_id := _resolve_fixed_board_material_id()
	return [_get_material_option_by_id(fixed_id)]
```

也可以直接不显示棋盘材质选择 UI，只显示一行说明：

```text
棋盘材质：Travertine003 大理石（固定）
```

推荐保留只读说明，不再给用户选择其它棋盘材质。这样符合“只保留这个 003 结尾的大理石材质，其它不要”。

### 4. 棋子改为内置基础颜色调色盘

新增内置颜色配置，不依赖贴图：

```gdscript
const PIECE_COLOR_PALETTE := [
	{"id": "piece_red", "label": "红色", "base_color": Color(0.90, 0.12, 0.10)},
	{"id": "piece_blue", "label": "蓝色", "base_color": Color(0.12, 0.34, 0.95)},
	{"id": "piece_yellow", "label": "黄色", "base_color": Color(1.00, 0.76, 0.10)},
	{"id": "piece_green", "label": "绿色", "base_color": Color(0.12, 0.68, 0.28)},
	{"id": "piece_orange", "label": "橙色", "base_color": Color(1.00, 0.42, 0.08)},
	{"id": "piece_purple", "label": "紫色", "base_color": Color(0.58, 0.25, 0.95)},
	{"id": "piece_cyan", "label": "青色", "base_color": Color(0.05, 0.72, 0.95)},
	{"id": "piece_pink", "label": "粉色", "base_color": Color(1.00, 0.34, 0.62)}
]
```

默认选择：

```gdscript
_player_material_ids[1] = "piece_red"
_player_material_ids[2] = "piece_blue"
```

这里变量名 `_player_material_ids` 可以暂时不改，避免牵连过多；但注释中说明它现在保存的是“玩家棋子颜色 profile id”。后续再重构时可以改名为 `_player_color_ids`。

### 5. Piece.gd 支持 base_color profile

当前 `Piece.gd` 中 `_update_color()` 逻辑是：如果 profile 有 `color_path`，棋子颜色设为白色，让贴图显示；否则使用 `player_one_color` / `player_two_color`。新方案需要支持内置调色盘。

修改建议：

```gdscript
func _update_color() -> void:
	if _material == null:
		return

	if _is_selected:
		_material.albedo_color = selected_color
	elif _is_inspected:
		_material.albedo_color = inspected_color
	elif _material_profile.has("base_color"):
		_material.albedo_color = _material_profile["base_color"]
	elif player_id == 1:
		_material.albedo_color = player_one_color
	else:
		_material.albedo_color = player_two_color
```

同时，棋子颜色 profile 不应设置 `color_path`、`normal_path`、`roughness_path`。棋子要走干净的基础材质：

```gdscript
_material.albedo_texture = null
_material.normal_enabled = false
_material.normal_texture = null
_material.roughness_texture = null
_material.roughness = 0.46
_material.metallic = 0.0
_material.clearcoat_enabled = true
_material.clearcoat = 0.22
_material.clearcoat_roughness = 0.30
```

如果 Godot 版本中 `StandardMaterial3D.clearcoat` 字段不可用，则只设置 `clearcoat_enabled` 和 `clearcoat_roughness`，不要强行使用不存在属性。

### 6. 颜色互斥规则

#### 6.1 规则目标

两个玩家不能选择：

1. 完全相同的颜色。
2. 视觉上过于接近的颜色。

比如：

- 红色 vs 橙色：应判定为相近，不允许同时选择，或者至少默认不推荐。
- 蓝色 vs 青色：应判定为相近。
- 紫色 vs 粉色：应判定为相近。
- 红色 vs 蓝色：允许。
- 黄色 vs 蓝色：允许。
- 绿色 vs 紫色：允许。

#### 6.2 实现方式

在 `BoardManager.gd` 中新增：

```gdscript
const PIECE_COLOR_MIN_DISTANCE := 0.32
```

推荐使用 RGB 距离，简单稳定：

```gdscript
func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)
```

新增：

```gdscript
func are_piece_colors_compatible(color_id_a: String, color_id_b: String) -> bool:
	if color_id_a == color_id_b:
		return false
	var color_a := _get_piece_color_by_id(color_id_a)
	var color_b := _get_piece_color_by_id(color_id_b)
	return _color_distance(color_a, color_b) >= PIECE_COLOR_MIN_DISTANCE
```

如果 RGB 距离误判，再后续升级到 HSV hue 距离。第一版不需要复杂化。

### 7. 应用玩家颜色时做互斥校验

修改 `apply_player_material(player_id, material_id)`：

1. 如果 `material_id` 是棋子颜色 ID，则校验与其他玩家颜色是否兼容。
2. 不兼容时拒绝应用，保留原颜色。
3. 返回 bool 表示是否应用成功。

建议函数签名改为：

```gdscript
func apply_player_material(player_id: int, material_id: String) -> bool:
```

如果担心牵连调用处，可以先不改返回值，但仍然内部拒绝，并新增 signal：

```gdscript
signal player_material_rejected(player_id: int, material_id: String, reason: String)
```

推荐更明确：

```gdscript
signal player_color_rejected(player_id: int, color_id: String, reason: String)
```

兼容方案：保留旧 signal `player_material_changed`，新增拒绝 signal。

### 8. UI 处理：禁用相近颜色，而不是等用户选错

`GameUI.gd` 当前已经有 `_board_material_option`、`_player_one_material_option`、`_player_two_material_option` 三个选项控件。它也通过 `material_selected(target, material_id)` 发信号给 GameManager。

推荐 UI 行为：

1. 棋盘材质选择项改为只读标签，或者 OptionButton 只有一个 `Travertine003`。
2. 玩家 1 和玩家 2 使用颜色 OptionButton。
3. 当玩家 1 选择了红色，玩家 2 的相同/相近颜色显示为禁用或标注“不可用”。
4. Godot `OptionButton` 单项禁用如果实现麻烦，第一版可以允许显示全部颜色，但选中冲突颜色时弹出状态提示并恢复原选择。

第一版建议用简单可靠方案：

- 不做复杂禁用。
- 选中不兼容颜色时，由 `BoardManager` 拒绝。
- `GameUI` 显示提示：

```text
颜色过于接近，请为两个玩家选择区分更明显的颜色。
```

后续再优化成禁用项。

### 9. GameManager 桥接

当前 GameManager 应该已经在处理 `game_ui.material_selected`。修改时保持入口不变：

```gdscript
func _on_material_selected(target: String, material_id: String) -> void:
```

建议语义：

```gdscript
match target:
	"board":
		# 棋盘固定，不允许实际切换。可以忽略，或强制 apply fixed board material。
	"player_1":
		board_manager.apply_player_material(1, material_id)
	"player_2":
		board_manager.apply_player_material(2, material_id)
```

如果 `apply_player_material()` 返回 false，调用：

```gdscript
game_ui.show_lighting_status("颜色过于接近，请重新选择。")
```

更好是新增 `show_material_status()`，但为了少改 UI，第一版可以复用已有状态 Label。

## 分阶段执行

### Commit 1：固定棋盘 003 大理石

只改 `BoardManager.gd` 和必要的 UI 显示。

要求：

1. 新增 `FIXED_BOARD_MARBLE_ID := "大理石/Travertine003"`。
2. `_choose_initial_materials()` 中棋盘材质改为 `_resolve_fixed_board_material_id()`。
3. 棋盘材质 UI 只显示固定材质，或改为只读文本。
4. 其它大理石/草地/木头/石材不再作为棋盘可选项展示。
5. 不要删除资源文件。

验收：

- 启动后棋盘默认使用 `Travertine003`。
- UI 中无法切换到其它棋盘材质。
- 如果 `Travertine003` 缺失，项目不崩溃，有 fallback 和 warning。

### Commit 2：棋子内置基础调色盘

修改 `BoardManager.gd`、`Piece.gd`、`GameUI.gd`。

要求：

1. 新增 `PIECE_COLOR_PALETTE`。
2. 玩家 1 默认红色，玩家 2 默认蓝色。
3. 玩家棋子不再使用贴图材质。
4. `Piece.gd` 支持 `base_color` profile。
5. 棋子材质保持干净、稍微有高光，不要使用噪声贴图。

验收：

- 玩家 1 棋子是红色。
- 玩家 2 棋子是蓝色。
- 棋子表面不再出现大理石纹理、噪点跳动或粗糙贴图闪烁。
- 选中、高亮、技能视觉仍正常。

### Commit 3：颜色互斥系统

要求：

1. 新增颜色距离判断。
2. 两个玩家不能选择相同颜色。
3. 两个玩家不能选择过于接近的颜色。
4. 冲突时保留原颜色，并给 UI 提示。

验收：

- 玩家 1 选择红色后，玩家 2 不能选择红色。
- 玩家 1 选择红色后，玩家 2 选择橙色会被拒绝，或按阈值配置拒绝。
- 玩家 1 红色，玩家 2 蓝色允许。
- 玩家 1 黄色，玩家 2 蓝色允许。

### Commit 4：UI 清理

要求：

1. 将“棋盘材质”区域改为固定说明。
2. 将“玩家材质”文案改为“玩家颜色”。
3. 如果可以，在颜色选项旁显示小色块。
4. 不再出现任何贴图材质名称作为棋子选项。

验收：

- UI 文案不再混用“材质”和“颜色”。
- 玩家只感知为选择棋子颜色。
- 棋盘只显示固定 `Travertine003` 大理石。

## 注意事项

1. 不要直接删除 `assets/materials` 中的其它材质文件，防止后续资源引用断裂。
2. “只保留 003 材质”在本轮语义上指 UI 与运行时选择逻辑只保留它，不是物理删除仓库资源。
3. 棋盘和棋子材质不要共用同一个选择列表，否则用户会再次把棋子切成大理石贴图。
4. 棋子颜色互斥建议先用 RGB 距离实现，足够稳定后再考虑 HSV。
5. 如果 OptionButton 单项禁用实现复杂，第一版使用“选择后拒绝并恢复原选择”即可。
6. 保持存档兼容：旧存档里的棋子不应因为材质 ID 改动而无法载入。材质选择不是核心棋局数据，缺失时自动 fallback 到默认红蓝即可。

## Codex 执行提示

请根据本文件实现固定棋盘材质和棋子内置调色盘。

优先执行 Commit 1 和 Commit 2：

- 固定棋盘只使用 `大理石/Travertine003`。
- 棋子改为内置基础颜色调色盘，默认玩家 1 红色、玩家 2 蓝色。
- 暂时不要删除资源文件。
- 暂时不要重构整个 GameUI。
- 保持 Forward+ 渲染器不变。
- 不要改棋盘规则、AI、网络、存档、回放和光照。
