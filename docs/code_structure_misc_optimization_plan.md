# Chinese Checkers 3D 代码结构与杂项优化建议方案

> 本文档用于指导 Codex 分阶段优化当前 Godot 4.6 项目结构。  
> 本轮只做结构梳理与可执行优化方案，不要求一次性大重构。  
> 原则：保持现有功能可运行、保持 `Forward+` 渲染方案、避免大范围破坏性改动。

---

## 1. 当前项目结构判断

当前项目是一个 Godot 4.6 的 3D Chinese Checkers 项目，主入口为：

```text
project.godot
└─ run/main_scene = res://scenes/Main.tscn
```

主场景 `Main.tscn` 采用“主场景 + 多 Manager 同级挂载”的结构：

```text
Main.tscn
├─ BackgroundManager
├─ BoardManager
├─ ViewFocusMarkerManager
├─ MoveValidator
├─ PassiveSkillRuleEngine
├─ AudioManager
├─ NetworkManager
├─ GameManager
├─ AIPlayer
├─ Camera3D
├─ DirectionalLight3D
└─ GameUI
```

这个结构已经有较好的模块雏形：棋盘、规则、AI、UI、网络、背景、音频都已经拆成独立节点。

但当前主要问题是：

1. `GameManager.gd` 职责过多，已经承担游戏流程、UI 连接、AI、联网、回放、撤回、材质切换、光照参数转发等大量职责。
2. `GameUI.gd` 动态构建 UI 过多，信号和控件状态集中在一个文件里，后续维护成本会继续上升。
3. 规则入口存在分散风险，基础规则、技能规则、在线校验逻辑后续容易不一致。
4. 配置、存档、调试、日志、资源目录还可以继续规范化。
5. 当前项目已经进入“可玩原型 + 多功能堆叠”阶段，下一步应该从“继续加功能”转向“控制复杂度”。

---

## 2. 优化总原则

本方案建议遵循以下原则：

```text
先文档化，再小步拆分；
先分离低风险模块，再处理核心流程；
先保持现有外部接口，再逐步替换内部实现；
不要一次性重写 GameManager；
不要把 UI、规则、联网、存档继续混进同一个脚本。
```

具体执行优先级：

```text
P0：补文档、补目录说明、补开发规范。
P1：拆对局记录/回放/存档，降低 GameManager 体积。
P2：拆 UI 面板，降低 GameUI 体积。
P3：统一规则入口，避免本地/AI/联网规则不一致。
P4：整理资源目录、配置、日志、调试开关。
P5：建立轻量测试场景与开发工具脚本。
```

---

## 3. 推荐目录结构

当前脚本都在 `scripts/` 根目录下。建议逐步整理为以下结构：

```text
scripts/
├─ core/
│  ├─ GameManager.gd
│  ├─ GameState.gd
│  ├─ GameConstants.gd
│  └─ SignalBus.gd                 # 可选
│
├─ board/
│  ├─ BoardManager.gd
│  ├─ BoardGeometry.gd
│  └─ BoardSnapshot.gd             # 可选
│
├─ rules/
│  ├─ MoveValidator.gd
│  ├─ PassiveSkillRuleEngine.gd
│  ├─ ActionTypes.gd
│  └─ RuleContext.gd               # 可选
│
├─ gameplay/
│  ├─ TurnController.gd
│  ├─ MatchRecorder.gd
│  ├─ ReplayController.gd
│  └─ AIPlayer.gd
│
├─ network/
│  ├─ NetworkManager.gd
│  ├─ OnlineGameController.gd
│  └─ OnlineMessageTypes.gd
│
├─ ui/
│  ├─ GameUI.gd
│  ├─ StartMenu.gd
│  ├─ PauseMenu.gd
│  ├─ ReplayPanel.gd
│  ├─ LightingPanel.gd
│  └─ NetworkPanel.gd
│
├─ presentation/
│  ├─ BackgroundManager.gd
│  ├─ AudioManager.gd
│  ├─ FocusCamera.gd
│  ├─ ViewFocusMarker.gd
│  └─ ViewFocusMarkerManager.gd
│
└─ entities/
   ├─ Cell.gd
   └─ Piece.gd
```

注意：不要求一次性移动所有文件。Godot 项目中直接移动脚本可能影响 `.tscn` 引用。建议分阶段进行：

1. 第一阶段只新增新模块，不移动旧脚本。
2. 第二阶段迁移低风险脚本，如 `AudioManager.gd`、`AIPlayer.gd`、`FocusCamera.gd`。
3. 第三阶段迁移核心脚本，并用 Godot 编辑器或确认 `.tscn` 引用更新。

---

## 4. GameManager 拆分建议

### 4.1 当前问题

`GameManager.gd` 当前是项目总控中心，连接了大量节点：

```gdscript
board_manager
move_validator
skill_rules
audio_manager
background_manager
game_ui
focus_camera
ai_player
network_manager
```

它同时保存了当前玩家、选中棋子、合法目标、连跳棋子、联网状态、回放状态、撤回栈、对局记录、技能开关、随机种子、分析模式等状态。

这说明 `GameManager` 已经不只是“管理游戏”，而是承担了多个子系统职责。

### 4.2 目标结构

建议最终让 `GameManager` 只负责：

```text
1. 初始化依赖节点。
2. 连接主要信号。
3. 控制当前游戏模式。
4. 转发高层 UI 请求。
5. 调用子 Controller 完成具体业务。
```

拆出的模块：

```text
TurnController.gd
负责：选中棋子、合法行动、执行行动、强制连跳、结束回合、撤回本回合。

MatchRecorder.gd
负责：对局记录结构、追加 move entry、保存 JSON、载入 JSON、最新记录路径。

ReplayController.gd
负责：回放播放、暂停、上一手、下一手、slider step index、按 step 恢复棋盘状态。

OnlineGameController.gd
负责：在线模式下的主机权威、move_request、move_applied、turn_changed、game_reset 等协议逻辑。

GameState.gd
负责：当前玩家、game_over、selected_piece、forced_chain_piece、game_mode、local_player_id 等可序列化状态。
```

### 4.3 分阶段拆分顺序

不要先拆 `TurnController`，因为它最容易影响核心手感。建议先拆低风险模块：

```text
第一步：拆 MatchRecorder
第二步：拆 ReplayController
第三步：拆 OnlineGameController
第四步：拆 TurnController
第五步：抽 GameState
```

### 4.4 MatchRecorder 建议接口

新增文件：

```text
scripts/gameplay/MatchRecorder.gd
```

建议接口：

```gdscript
class_name MatchRecorder
extends RefCounted

const MATCH_RECORD_DIR := "user://match_records"
const LATEST_MATCH_RECORD_PATH := "user://match_records/latest_match.json"

var record: Dictionary = {}

func reset(seed: int, initial_snapshot: Array, player_count: int) -> void:
    pass

func append_turn_entry(entry: Dictionary) -> void:
    pass

func save_latest() -> Error:
    pass

func save_to_path(path: String) -> Error:
    pass

func load_from_path(path: String) -> Dictionary:
    return {}

func has_record() -> bool:
    return not record.is_empty()
```

`GameManager` 暂时保留原方法名，但内部委托给 `MatchRecorder`，降低一次性替换风险。

---

## 5. GameUI 拆分建议

### 5.1 当前问题

`GameUI.gd` 当前包含大量信号和控件状态：

```text
开始菜单
暂停菜单
联网输入
回放条
撤回按钮
种子输入
AI 托管开关
材质选择
光照预设选择
光照 slider
技能说明
胜利面板
HUD
```

`_ready()` 中会调用：

```gdscript
_prepare_legacy_controls()
_build_hud_controls()
_build_replay_controls()
_build_start_menu()
_build_pause_menu()
_build_lighting_menu()
```

这说明 UI 已经具备拆分条件。

### 5.2 目标结构

建议 UI 拆成：

```text
scenes/ui/GameHUD.tscn
scenes/ui/StartMenu.tscn
scenes/ui/PauseMenu.tscn
scenes/ui/ReplayPanel.tscn
scenes/ui/LightingPanel.tscn
scenes/ui/NetworkPanel.tscn
scenes/ui/MaterialPanel.tscn
scenes/ui/SkillInfoPanel.tscn
```

对应脚本：

```text
scripts/ui/GameHUD.gd
scripts/ui/StartMenu.gd
scripts/ui/PauseMenu.gd
scripts/ui/ReplayPanel.gd
scripts/ui/LightingPanel.gd
scripts/ui/NetworkPanel.gd
scripts/ui/MaterialPanel.gd
scripts/ui/SkillInfoPanel.gd
```

`GameUI.gd` 最终只保留为 UI Facade：

```text
GameManager 只和 GameUI 通信；
GameUI 内部再分发给各个 Panel；
各个 Panel 只负责自己的控件和信号。
```

### 5.3 拆分顺序

优先拆低耦合面板：

```text
第一步：LightingPanel
第二步：ReplayPanel
第三步：NetworkPanel
第四步：MaterialPanel
第五步：StartMenu / PauseMenu
第六步：HUD
```

原因：

```text
LightingPanel 和 ReplayPanel 功能边界最清楚；
HUD 与游戏流程耦合较高，后拆更稳。
```

---

## 6. 规则系统优化建议

### 6.1 当前风险

当前规则系统大致分为：

```text
MoveValidator.gd              # 基础移动与跳跃规则
PassiveSkillRuleEngine.gd     # 被动技能与 action 生成
GameManager.gd                # 某些模式下的实际流程判断
AIPlayer.gd                   # AI 获取候选行动
OnlineGameController 计划中    # 未来在线权威校验
```

风险在于：

```text
本地模式、AI 模式、在线模式可能分别使用不同规则入口；
后续新增技能时，容易出现本地能走、AI 不会走、在线不同步的问题。
```

### 6.2 统一规则入口

建议最终统一为：

```gdscript
skill_rules.get_legal_actions(player_id, piece, board_state, rule_context)
skill_rules.get_action_by_input_target(...)
skill_rules.apply_action_to_board(action, board_manager)
```

`MoveValidator` 只保留为底层几何规则工具：

```text
是否相邻
是否跳跃
获取跳跃中点
获取方向数组
获取连续跳候选
```

AI、在线主机、本地玩家都不直接使用 `MoveValidator.get_legal_moves()` 作为最终规则入口。

### 6.3 Action 数据结构规范

建议建立统一 action 结构：

```gdscript
{
    "actor_piece_id": String,
    "player_id": int,
    "from": Vector2i,
    "input_target": Vector2i,
    "base_landing": Vector2i,
    "final_coord": Vector2i,
    "move_kind": String,       # step / jump / dash_jump / skill
    "jumped_coords": Array,
    "effects": Array,
    "requires_continue": bool,
    "metadata": Dictionary,
}
```

对于回放和网络传输，必须提供可 JSON 化版本：

```gdscript
func serialize_action(action: Dictionary) -> Dictionary:
    pass

func deserialize_action(data: Dictionary) -> Dictionary:
    pass
```

---

## 7. 存档、回放与数据格式优化

### 7.1 当前建议

对局记录建议固定版本号：

```json
{
  "schema_version": 1,
  "game_version": "dev",
  "created_at": "2026-xx-xxTxx:xx:xx",
  "seed": 12345,
  "player_count": 2,
  "initial_snapshot": [],
  "turns": []
}
```

每个 turn entry：

```json
{
  "turn_index": 1,
  "player_id": 1,
  "entries": [
    {
      "type": "move",
      "action": {},
      "before_snapshot": [],
      "after_snapshot": []
    }
  ]
}
```

### 7.2 存档目录建议

```text
user://match_records/
├─ latest_match.json
├─ autosave_001.json
└─ manual/
   ├─ 2026-xx-xx_001.json
   └─ 2026-xx-xx_002.json
```

### 7.3 兼容策略

加载记录时必须检查：

```text
schema_version 是否存在；
initial_snapshot 是否存在；
turns 是否为 Array；
action 是否可反序列化；
缺字段时给默认值，不直接崩溃。
```

---

## 8. 网络模块优化建议

### 8.1 当前目标

`NetworkManager.gd` 应只负责网络连接与消息收发，不应该知道太多游戏规则。

推荐分层：

```text
NetworkManager.gd
负责：WebSocket / WebRTC / DataChannel / raw Dictionary 收发。

OnlineMessageTypes.gd
负责：消息类型常量、字段校验、序列化工具。

OnlineGameController.gd
负责：主机权威、客户端请求、远端应用、同步状态。
```

### 8.2 消息类型常量化

新增：

```text
scripts/network/OnlineMessageTypes.gd
```

示例：

```gdscript
class_name OnlineMessageTypes

const MOVE_REQUEST := "move_request"
const MOVE_APPLIED := "move_applied"
const END_TURN_REQUEST := "end_turn_request"
const TURN_CHANGED := "turn_changed"
const GAME_RESET := "game_reset"
const RESET_REQUEST := "reset_request"
const STATE_SYNC := "state_sync"
const PING := "ping"
const PONG := "pong"
```

避免在多个文件里手写字符串。

### 8.3 在线状态同步

建议保留主机权威：

```text
客户端只发请求；
主机校验规则；
主机广播结果；
客户端只应用主机结果。
```

后续技能、撤回、重开、观战都应遵守这个原则。

---

## 9. 配置系统优化建议

### 9.1 当前问题

当前大量参数分散在脚本 `@export` 和硬编码常量中，例如：

```text
AI 延迟
回放延迟
棋盘大小
棋子高度偏移
材质根目录
光照预设
网络默认信令地址
音频路径
```

建议将稳定配置逐步收敛为 Resource 或 Config 文件。

### 9.2 推荐配置资源

```text
resources/config/GameConfig.tres
resources/config/BoardConfig.tres
resources/config/AIConfig.tres
resources/config/RenderCostProfileConfig.tres
resources/config/LightingTimeProfileConfig.tres
```

对应脚本：

```text
scripts/config/GameConfig.gd
scripts/config/BoardConfig.gd
scripts/config/AIConfig.gd
scripts/config/RenderCostProfileConfig.gd
scripts/config/LightingTimeProfileConfig.gd
```

### 9.3 初期不要过度设计

第一阶段只建议抽：

```text
AIConfig
RenderCostProfileConfig
LightingTimeProfileConfig
```

棋盘几何和核心规则暂时保留在现有脚本中，避免影响主要玩法。

---

## 10. 调试、日志与开发工具优化

### 10.1 统一 Debug 开关

新增：

```text
scripts/core/DebugFlags.gd
```

示例：

```gdscript
class_name DebugFlags

const ENABLE_RULE_LOG := false
const ENABLE_NETWORK_LOG := true
const ENABLE_REPLAY_LOG := false
const ENABLE_RENDER_PROFILE_LOG := true
const ENABLE_AI_LOG := false
```

避免到处 `print()`，也方便切换调试范围。

### 10.2 统一日志工具

新增：

```text
scripts/core/GameLogger.gd
```

接口：

```gdscript
class_name GameLogger

static func info(scope: String, message: String) -> void:
    print("[%s] %s" % [scope, message])

static func warn(scope: String, message: String) -> void:
    push_warning("[%s] %s" % [scope, message])

static func error(scope: String, message: String) -> void:
    push_error("[%s] %s" % [scope, message])
```

后续替换：

```gdscript
print("xxx")
```

为：

```gdscript
GameLogger.info("Network", "xxx")
```

### 10.3 开发测试按钮归类

当前 UI 中已有测试布局、重开、回放、光照、材质等功能。建议后续把开发工具集中在一个 Debug 面板中：

```text
DebugPanel
├─ 加载胜利测试布局
├─ 随机种子重开
├─ 导出当前棋盘快照
├─ 复制当前光照参数
├─ FPS / draw calls 显示开关
├─ AI 立即走一步
└─ 网络模拟延迟 / 断线
```

正式 UI 与调试 UI 分离，避免主菜单越来越乱。

---

## 11. 资源目录优化建议

建议整理为：

```text
assets/
├─ audio/
│  ├─ sfx/
│  └─ music/
│
├─ materials/
│  ├─ board/
│  ├─ pieces/
│  ├─ environment/
│  └─ ui/
│
├─ textures/
│  ├─ board/
│  ├─ environment/
│  ├─ particles/
│  └─ ui/
│
├─ models/
│  ├─ environment/
│  ├─ props/
│  └─ pieces/
│
└─ ui/
   ├─ icons/
   ├─ panels/
   └─ backgrounds/
```

注意：资源移动会影响 `.import` 和场景引用，建议不要一次性批量移动。应使用 Godot 编辑器移动，或移动后检查所有 `res://` 路径。

---

## 12. 场景结构优化建议

### 12.1 Main.tscn 保持轻量

当前 `Main.tscn` 已经挂载了多个 Manager。后续建议把视觉场景和逻辑 Manager 分组：

```text
Main
├─ World
│  ├─ BackgroundManager
│  ├─ BoardManager
│  ├─ ViewFocusMarkerManager
│  └─ Camera3D
│
├─ Systems
│  ├─ MoveValidator
│  ├─ PassiveSkillRuleEngine
│  ├─ AudioManager
│  ├─ NetworkManager
│  ├─ GameManager
│  └─ AIPlayer
│
└─ UI
   └─ GameUI
```

这样场景树更容易读。

### 12.2 DirectionalLight3D 归属

当前 `Main.tscn` 中存在一个 `DirectionalLight3D`，但能量为 0。后续若 `BackgroundManager` 已经完全负责光照，可以考虑：

```text
方案 A：删除 Main.tscn 中的 DirectionalLight3D；
方案 B：把它改名为 LegacyDirectionalLight，并注释说明由 BackgroundManager 接管；
方案 C：交给 BackgroundManager 获取并复用。
```

推荐方案 C 或 A，避免后续误以为它还在参与光照。

---

## 13. 性能与杂项优化建议

### 13.1 对象创建与复用

当前棋盘构建和棋子重置会动态 instantiate。棋类项目规模不大，性能问题不大，但可以注意：

```text
不要每帧创建材质；
高亮材质尽量复用；
Glow / Marker / UI StyleBox 尽量缓存；
频繁临时 Dictionary / Array 的地方可后续优化。
```

### 13.2 材质实例管理

Godot 中修改共享材质可能影响所有实例。建议：

```text
公共材质：只读共享；
需要运行时变色的材质：duplicate 后缓存；
不要每次 hover / highlight 都 new StandardMaterial3D。
```

### 13.3 输入处理

当前 `GameManager._unhandled_input()` 处理空格结束回合、Backspace/Z 撤回。建议后续统一到 InputMap：

```text
ui_end_turn
ui_undo_turn
ui_toggle_pause
ui_toggle_analysis
ui_replay_play_pause
```

避免硬编码键位，也方便玩家自定义。

### 13.4 错误兜底

建议所有跨模块调用前增加轻量兜底：

```gdscript
if background_manager == null:
    GameLogger.warn("GameManager", "BackgroundManager missing")
    return
```

但不要过度 try-catch 式隐藏错误。开发阶段应尽早暴露问题。

---

## 14. 文档补充建议

建议新增：

```text
docs/architecture_overview.md
项目架构总览，说明 Main.tscn、核心 Manager、数据流。

docs/rule_system.md
说明基础移动、跳跃、技能、Action 数据结构。

docs/match_record_schema.md
说明对局记录 JSON 格式。

docs/network_protocol.md
说明在线消息类型与主机权威流程。

docs/ui_structure.md
说明 UI Facade 和各 Panel 分工。

docs/rendering_profiles.md
说明 Forward+ 渲染开销档位、光照时间系统。
```

已有的 Forward+ 渲染开销和昼夜光照方案可以归到 rendering 文档组。

---

## 15. 推荐 Codex 执行任务拆分

### Task 1：补架构文档

```text
新增 docs/architecture_overview.md。
基于 Main.tscn 和 scripts 目录说明当前节点结构、核心依赖、主要数据流。
不修改代码。
```

### Task 2：新增 MatchRecorder 空模块并接入

```text
新增 scripts/gameplay/MatchRecorder.gd。
将 GameManager 中对局记录的创建、保存、载入相关逻辑逐步委托给 MatchRecorder。
保持原 UI 按钮行为不变。
```

### Task 3：新增 GameLogger 与 DebugFlags

```text
新增 scripts/core/GameLogger.gd 和 scripts/core/DebugFlags.gd。
只替换 Network、Replay、Render profile 相关 print，不大范围改动。
```

### Task 4：拆 LightingPanel

```text
新增 scripts/ui/LightingPanel.gd 和 scenes/ui/LightingPanel.tscn。
把 GameUI 中光照预设、渲染开销档、时间光照相关 UI 独立出来。
GameUI 保持 facade，对外信号名称不变。
```

### Task 5：统一规则入口

```text
检查 GameManager、AIPlayer、OnlineGameController 中是否直接使用 MoveValidator 作为最终规则入口。
将最终合法行动判断统一改为 PassiveSkillRuleEngine 的 Action 系统。
MoveValidator 只作为底层几何工具。
```

### Task 6：整理在线消息类型

```text
新增 scripts/network/OnlineMessageTypes.gd。
替换散落在代码中的 move_request、move_applied、turn_changed 等字符串常量。
不改变协议字段结构。
```

---

## 16. 验收标准

每个阶段完成后，至少检查：

```text
1. 项目能打开 Main.tscn。
2. 本地玩家可以选择棋子、移动、结束回合。
3. AI 可以正常行动。
4. 撤回当前回合不报错。
5. 保存/载入对局记录不报错。
6. 回放上一手/下一手不报错。
7. 材质切换不报错。
8. 光照预设与渲染开销档切换不报错。
9. 在线模式按钮不报错，即使未连接服务端也应给出状态提示。
10. Godot 输出面板没有明显 null instance 错误。
```

---

## 17. 不建议现在做的事

当前阶段不建议：

```text
1. 一次性重写 GameManager。
2. 一次性移动所有脚本目录。
3. 一次性把所有 UI 改成独立 .tscn。
4. 同时修改规则、联网、回放、UI。
5. 在结构重构时顺手大改视觉效果。
6. 在没有测试记录的情况下重做存档格式。
7. 为了架构好看引入过多抽象层。
```

这个项目目前最需要的是“可控拆分”，不是“推倒重来”。

---

## 18. 推荐下一步

最稳妥的下一步是：

```text
先新增 MatchRecorder.gd，把对局记录相关逻辑从 GameManager 中拆出来。
```

原因：

```text
对局记录逻辑相对独立；
拆分收益明显；
对核心走棋手感影响较小；
可以为后续 ReplayController 拆分打基础。
```

建议给 Codex 的第一条执行指令：

```text
请根据 docs/code_structure_misc_optimization_plan.md，优先执行 Task 2：新增 MatchRecorder.gd 并将 GameManager 中对局记录创建、保存、载入相关逻辑委托给 MatchRecorder。保持现有 UI 行为和存档格式不变，不要同时重构回合系统。
```
