# 《黑剑·荒寺夜行》V1 Godot 技术方案

文档状态：已确认，待实现  
目标引擎：Godot 4.7 stable  
目标平台：Windows、桌面 Web  
当前基线：现有 `tests/test_runner.gd` 全部通过

## 1. 目标与约束

V1 技术改造要在保留现有 Demo 可运行能力的前提下，支持以下正式系统：

- 五名角色与独立解锁条件。
- 10 个主动、10 个心法、6+6 槽位和十套进阶配方。
- 十二波、三名小 Boss、一个最终 Boss 和关卡阶段事件。
- 五种即时道具。
- 夜烬结算、四条有限养成分支和复生。
- 三档独立存档、版本迁移、备份及 Web 导入导出。
- 三国主线、赵云正史支线和水门异界支线的剧情标记。

### 1.1 明确不做

- 不保存战斗中途状态。
- 不引入服务端、账号、云同步或反作弊。
- 不为 V1 建立通用 ECS、依赖注入框架或全局事件总线。
- 不在一个版本中同时重写全部战斗表现；先建立数据和接口，再逐项迁移。
- 不自行生成或替换赵云正式造型。项目所有者已提供带水印 JPG 原型；它只用于确认银蓝甲步战设定，正式场景接入等待无水印透明底资源或按原型重制后的 Sprite Sheet。

## 2. 当前结构与主要问题

当前 Demo 的优点是场景可直接运行、角色与地图已有独立预设、基础测试覆盖了关键玩法。V1 需要处理的结构问题：

- `ContentRegistry` 在代码中集中创建技能、敌人与波次，数据修改必须改脚本。
- `Arena` 同时负责计时、生成、经验、Boss、结算和运行时对象管理。
- `SkillSystem` 同时负责槽位、候选、数值聚合和所有技能行为。
- `main.gd` 动态构建标题、角色选择、HUD、升级与结算 UI，难以独立编辑和复用。
- Boss 行为以单脚本条件分支管理，新增三名小 Boss 后可维护性不足。
- 当前没有持久化层，角色解锁、夜烬、养成和剧情都没有稳定所有者。

改造采用渐进迁移：旧场景在对应新系统验收前继续存在，不进行一次性大爆炸重写。

## 3. 目录与场景职责

建议新增的职责目录：

```text
res://
├── data/
│   ├── characters/       # CharacterDefinition .tres
│   ├── skills/           # 主动、心法、进阶 SkillDefinition .tres
│   ├── evolutions/       # EvolutionRecipe .tres
│   ├── enemies/          # EnemyDefinition .tres
│   ├── waves/            # WaveDefinition .tres
│   ├── items/            # ItemDefinition .tres
│   └── meta/             # MetaUpgradeDefinition .tres
├── scenes/
│   ├── app/              # Main、场景路由
│   ├── ui/               # 存档、大厅、选角、HUD、结算、剧情
│   ├── gameplay/         # BattleArena 与运行控制器
│   ├── actors/           # 玩家、普通敌人、Boss
│   ├── skills/           # 独立技能运行时场景
│   ├── items/            # 道具拾取物
│   └── world/            # 地图分区、危险与可破坏物
└── scripts/
    ├── autoload/         # 四个全局服务
    ├── data/             # Resource 与 DTO 类型
    ├── gameplay/         # 波次、生成、进阶、掉落、结算
    ├── actors/           # Actor 与行为组件
    ├── ui/               # 各界面控制器
    └── persistence/      # 序列化、校验、迁移
```

目录迁移分阶段完成，不为追求目录整齐一次性移动所有旧文件；移动脚本或场景时依赖 Godot 编辑器重定位并运行资源加载测试。

## 4. Autoload 与应用状态

V1 只使用四个 Autoload：

### 4.1 `SaveManager`

唯一负责 `user://` 文件读写、备份、迁移、导入和导出。不持有战斗节点，不发送玩法事件。

公开方法：

```gdscript
func list_slots() -> Array[SaveSlotSummary]
func create_slot(slot_index: int) -> ProfileData
func load_slot(slot_index: int) -> ProfileData
func save_profile(profile: ProfileData, reason: StringName) -> Error
func delete_slot(slot_index: int) -> Error
func export_slot(slot_index: int, target_path: String) -> Error
func import_slot(slot_index: int, source_path: String) -> ProfileData
```

### 4.2 `GameState`

持有当前档位与当前内存中的 `ProfileData`，负责消费夜烬、购买/重置养成、提交 `RunResult`、解锁角色和记录故事标记。所有修改成功后调用 `SaveManager`。

公开信号：

```gdscript
signal profile_loaded(profile: ProfileData)
signal currency_changed(night_embers: int)
signal unlocks_changed()
signal meta_upgrades_changed()
signal story_flags_changed()
```

`GameState` 不直接访问场景树中的玩家或敌人。

### 4.3 `ContentDatabase`

启动时扫描明确的数据目录，按 `StringName id` 建立只读索引，并运行引用完整性校验。公开查询返回强类型 Resource，不返回可被运行时修改的共享字典。

```gdscript
func character(id: StringName) -> CharacterDefinition
func skill(id: StringName) -> SkillDefinition
func evolution_for_active(id: StringName) -> EvolutionRecipe
func enemy(id: StringName) -> EnemyDefinition
func wave(index: int) -> WaveDefinition
func item(id: StringName) -> ItemDefinition
func meta_upgrade(id: StringName) -> MetaUpgradeDefinition
func validate_all() -> PackedStringArray
```

### 4.4 `AudioManager`

持有 Music 与 SFX 播放器、总线音量和场景切换时的音乐淡入淡出。设置保存在全局配置，不随存档切换。

## 5. 应用场景流

根场景只负责状态切换，不动态搭建完整 UI。界面均为独立 `.tscn`：

```text
Title → SaveSelect → Hub → CharacterSelect → Battle → Result
                       ↘ MetaProgression
                       ↘ StoryArchive
```

状态切换由 `AppController` 管理，使用枚举 `AppState`。每次只实例化当前主界面和需要的模态页；战斗结束后释放整个 Battle 子树，防止旧信号和对象残留。

界面之间传递小型 DTO 或 ID，不传递 UI 节点引用：

- 选角页输出 `character_id`。
- `GameState` 与角色定义构造 `RunConfig`。
- Battle 结束输出不可重复提交的 `RunResult`。
- Result 首次提交 `RunResult` 后标记 `submitted = true`，再进入夜烬和解锁展示。

## 6. 数据类型

所有公开 ID 使用稳定的英文小写 `StringName`。显示名称和说明可以修改，ID 一旦进入存档不得复用为其他内容。

### 6.1 `CharacterDefinition : Resource`

```gdscript
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var actor_scene: PackedScene
@export var portrait: Texture2D
@export var initial_skill_id: StringName
@export var trait_modifiers: Dictionary
@export var unlock_condition_id: StringName
@export var unlock_cost: int
@export var story_route_id: StringName
```

V1 角色 ID：`black_sword`、`minato`、`ning_shuanghua`、`xuandeng`、`zhao_yun`。

赵云数据可以先登记 ID、数值和解锁条件，但 `actor_scene` 与 `portrait` 在正式内容校验中不可为空。当前参考图为 1024×1024 带水印黑底 JPG，不符合生产资源条件；开发构建应明确报告“等待干净源图/重制 Sprite Sheet”，不能把参考图或网络占位图带入发布构建。

### 6.2 `SkillDefinition : Resource`

```gdscript
enum SkillType { ACTIVE, PASSIVE, EVOLVED }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var skill_type: SkillType
@export var icon: Texture2D
@export var max_level: int = 5
@export var level_values: Array[SkillLevelData]
@export var runtime_scene: PackedScene
@export var tags: Array[StringName]
```

- 主动和心法必须有五级数据。
- 进阶技能 `max_level = 1`，不进入普通升级池。
- 运行时不得修改共享 `SkillDefinition`；本局等级保存在 `SkillInventory`。
- 赵云新增 `dragon_spear`、`battlefield_tactics` 和 `seven_in_seven_out`，内容池合计 10 主动、10 心法和 10 进阶。

### 6.3 `EvolutionRecipe : Resource`

```gdscript
@export var id: StringName
@export var active_skill_id: StringName
@export var passive_skill_id: StringName
@export var evolved_skill_id: StringName
```

校验必须保证三个技能存在、类型正确、每个主动只有一个配方、每个进阶只被一个配方引用。

### 6.4 `EnemyDefinition : Resource`

保留现有生命、速度、伤害、经验、攻击范围和行为字段，新增：

```gdscript
@export var actor_scene: PackedScene
@export var enemy_class: StringName # normal/elite/miniboss/boss
@export var behavior_scene: PackedScene
@export var tags: Array[StringName]
@export var drop_profile_id: StringName
```

精英词缀是生成时附加的 `EliteModifier`，不复制整份敌人定义。小 Boss 与 Boss 使用独立定义和状态机场景。

### 6.5 `WaveDefinition : Resource`

```gdscript
enum WaveKind { NORMAL, MINIBOSS, FINAL_BOSS }

@export var index: int
@export var title: String
@export var kind: WaveKind
@export var target_duration: float
@export var rest_duration: float = 5.0
@export var spawn_groups: Array[SpawnGroupDefinition]
@export var enemy_cap: int
@export var elite_chance: float
@export var boss_id: StringName
@export var environment_event_ids: Array[StringName]
@export var unlock_zone_id: StringName
```

V1 必须且只能存在索引 1～12；第 3、6、9 波是 `MINIBOSS`，第 12 波是 `FINAL_BOSS`。

### 6.6 `ItemDefinition : Resource`

```gdscript
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var world_scene: PackedScene
@export var effect_id: StringName
@export var effect_values: Dictionary
@export var base_weight: float
```

效果实现由白名单 `ItemEffectRegistry` 映射，不从数据执行任意方法名。

### 6.7 `MetaUpgradeDefinition : Resource`

包含稳定 ID、显示文本、最大等级、每级费用和每级效果。购买逻辑只读取定义，由 `GameState` 校验余额、当前等级和上限。

### 6.8 运行 DTO

`ProfileData`、`RunConfig`、`RunResult` 与 `SaveSlotSummary` 使用 `RefCounted` 类型，显式实现 `to_dict()` 与 `from_dict()`；不直接序列化 Node、Resource、Vector2 或 Callable。

`RunResult` 最少包含：

```gdscript
var run_id: String
var character_id: StringName
var victory: bool
var elapsed_seconds: float
var completed_waves: int
var miniboss_kills: int
var final_boss_kill: bool
var kills: int
var player_level: int
var evolved_skill_ids: Array[StringName]
var story_events: Array[StringName]
var submitted: bool = false
```

## 7. 存档设计

### 7.1 文件布局

```text
user://settings.cfg
user://saves/slot_1.json
user://saves/slot_1.bak
user://saves/slot_2.json
user://saves/slot_2.bak
user://saves/slot_3.json
user://saves/slot_3.bak
```

设置共享，档位数据完全隔离。档位编号只允许 1～3，所有路径在 `SaveManager` 内生成，调用方不能传入任意目标路径。

### 7.2 Schema V1

```json
{
  "schema_version": 1,
  "slot_index": 1,
  "created_at_unix": 0,
  "updated_at_unix": 0,
  "play_seconds": 0,
  "night_embers": 0,
  "meta_upgrades": {
    "attack": 0,
    "health": 0,
    "insight": 0,
    "revive": 0
  },
  "unlocked_characters": ["black_sword"],
  "available_character_unlocks": [],
  "selected_character_id": "black_sword",
  "story_flags": [],
  "submitted_run_ids": [],
  "stats": {
    "runs": 0,
    "victories": 0,
    "best_wave": 0,
    "best_time_seconds": 0,
    "total_kills": 0,
    "total_night_embers": 0
  }
}
```

`submitted_run_ids` 记录已经成功结算的 `RunResult.run_id`。提交结算时先检查该集合，只有档案原子保存成功后才把结果标记为 `submitted`，从而同时阻止同一运行时对象和重新载入后的重复结算。

加载校验：

- 根必须为 Dictionary，`schema_version` 必须可迁移。
- `slot_index` 必须与目标档位一致。
- 所有数值非负；养成等级不得超过定义上限。
- 角色、故事和技能 ID 不认识时保留在 `unknown_ids` 日志中，但不让加载崩溃。
- `black_sword` 必须始终解锁；选择角色失效时回退到 `black_sword`。
- 不信任 JSON 内计算出的总消费额，重置返还根据当前等级和定义费用重新计算。

### 7.3 原子写入与备份

保存顺序：

1. 序列化到 `slot_n.tmp` 并关闭文件。
2. 立即重新读取临时文件，执行 JSON 解析和结构校验。
3. 当前正式档存在时复制为 `.bak`。
4. 用临时文件替换正式档。
5. 替换成功后删除临时文件。

任一步失败都保留旧正式档，并返回非 `OK` 的 `Error`。加载正式档失败时自动尝试 `.bak`；备份成功后在 UI 提示用户，并立即生成一份新的正式档。正式档和备份都失败时不得自动清空，必须让用户选择导出损坏文件或重建。

### 7.4 保存时机

- 新建档位。
- 提交且仅提交一次 `RunResult`。
- 购买或重置局外养成。
- 支付角色解锁费用。
- 写入新的故事标记。
- 从局外大厅返回标题页。

战斗中不写 Profile；崩溃或关闭页面会失去当前一局，但不会损坏局外进度。

### 7.5 Web 导入导出

- 导出使用同一 Schema，文件名包含档位与 UTC 时间。
- 导入先解析到内存、迁移、验证，再要求玩家确认覆盖目标档位。
- 导入成功前先备份原档；导入文件中的 `slot_index` 改写为目标档位。
- 导入不能访问任意系统路径；Web 使用浏览器文件选择与下载接口。
- UI 明示浏览器缓存可能被清理，建议玩家定期导出。

### 7.6 迁移

`SaveMigrationRegistry` 按版本逐级迁移，例如 `1 → 2 → 3`，禁止跨版本直接猜测字段。迁移前保留原文件备份。当前 Demo 没有正式存档，因此 V1 从 Schema 1 开始。

## 8. 战斗系统拆分

### 8.1 `RunController`

一局的唯一流程所有者：读取 `RunConfig`、启动波次、统计击杀与完成波、接收玩家死亡/最终 Boss 死亡、构造一次性 `RunResult`。它不实现具体刷怪或技能。

公开信号：

```gdscript
signal run_started(config: RunConfig)
signal run_finished(result: RunResult)
signal run_stats_changed(snapshot: RunStatsSnapshot)
```

### 8.2 `WaveDirector`

状态枚举：`PREPARING`、`ACTIVE`、`WAITING_FOR_BOSS_DEATH`、`RESTING`、`COMPLETED`。

公开信号：

```gdscript
signal wave_started(index: int, definition: WaveDefinition)
signal wave_progress_changed(index: int, remaining: float)
signal wave_completed(index: int)
signal miniboss_defeated(index: int, boss_id: StringName)
signal final_boss_defeated(boss_id: StringName)
signal environment_event_requested(id: StringName)
```

普通波按 50 秒结束；小 Boss 波必须 Boss 死亡才结束，90 秒后只停止援军；最终 Boss 不按时间自动结束。重复死亡信号通过内部 Boss instance ID 去重。

### 8.3 `SpawnDirector`

根据当前 `WaveDefinition` 和敌人上限生成普通敌人、精英与 Boss。负责合法出生点、屏幕外距离、地图碰撞检测和对象上限，不负责波次计时。

### 8.4 `SkillController` 与 `SkillInventory`

`SkillInventory` 只管理：

- 6 个主动 ID、6 个心法 ID。
- 当前等级。
- 已进阶映射。
- 升级候选合法性。

`SkillController` 管理冷却和实例化 `runtime_scene`。每个主动/进阶行为放入独立的 `SkillRuntime` 场景或脚本；通用投射、范围、连锁和环绕能力由可复用组件实现。

升级接口：

```gdscript
func get_upgrade_options(count: int, rng: RandomNumberGenerator) -> Array[SkillDefinition]
func can_add_skill(id: StringName) -> bool
func upgrade(id: StringName) -> SkillUpgradeResult
func can_evolve(recipe: EvolutionRecipe) -> bool
func apply_evolution(recipe: EvolutionRecipe) -> SkillUpgradeResult
```

候选随机只使用本局 `RunConfig.seed` 初始化的 RNG，自动测试可复现。

### 8.5 `EvolutionSystem`

- 监听小 Boss 死亡，在 Boss 死亡位置生成永久宝匣。
- 宝匣持有唯一 `chest_id`，只允许成功消费一次。
- 没有合法配方时保持锁定，并在技能变化后重新检查。
- 开启时暂停场景，最多展示三个合法进阶。
- 选择成功后先应用进阶，再消耗宝匣；应用失败则保留宝匣并报告错误。

### 8.6 `ItemDropSystem`

负责陶罐、精英掉落、四波保底、同屏三个道具上限和权重选择。`ItemPickup` 只检测玩家并把 `item_id` 交给效果注册表；具体效果不写在场景脚本的字符串分支中。

### 8.7 属性聚合

建立 `StatBlock`，所有来源先按分类相加，再按乘区计算，避免各脚本重复乘算。

```text
最大生命 = 角色基础生命 × (1 + 局外生命 + 角色生命 + 心法生命)
最终伤害 = 基础伤害 × (1 + 局外攻击) × (1 + 心法/角色同类增伤)
         × 目标类别增伤 × 临时增伤 × 暴击倍率
实际冷却 = 基础冷却 × max(0.45, 1 - 冷却缩减总值)
实际受伤 = 原始伤害 × max(0.55, 1 - 减伤总值)
实际经验 = max(1, round(基础经验 × (1 + 局外悟性)))
```

角色的“对精英与 Boss 伤害”归入目标类别乘区；同一乘区内部相加。伤害事件携带 `source_skill_id`、标签和是否暴击，便于统计与测试。

### 8.8 复生

`PlayerLifeController` 在准备发出最终 `died` 前查询 `RunConfig.revive_rank`：

- 等级 0：正常死亡。
- 等级 1～3 且本局未用：阻止死亡，分别恢复 30%/50%/70% 最大生命，获得 1.5/2/3 秒无敌。
- 清除玩家 180 单位内普通敌人；Boss 与小 Boss 只受到击退，不受伤害。
- 复生标记属于本局状态，不写入 Profile。
- 无敌结束前玩家碰撞与视觉闪烁状态必须一致。

## 9. 敌人与 Boss 架构

普通敌人采用 `EnemyActor` 加行为组件：`MeleeChaseBehavior`、`RangedKiteBehavior`、`ChargeBehavior`、`DiveBehavior`、`GroundSigilBehavior`。行为组件只决定移动和攻击意图，伤害、受击、状态和死亡由 Actor 统一处理。

Boss 采用显式状态机：

```text
ENTER → CHASE → WINDUP → ATTACK → RECOVER
                    ↘ PHASE_TRANSITION
                    ↘ DEAD
```

每个攻击是独立 `BossAction`，定义适用距离、冷却、权重、预警和执行。阶段切换只改变可用动作与参数，不在 `_physics_process` 中堆叠生命百分比条件。

## 10. 地图与环境

- `AbandonedTempleMap` 继续作为独立 PackedScene，内部拆为山门、枯林、经阁、封印殿四个 `MapZone`。
- 结界由 `ZoneGate` 管理；解锁前是可见且有碰撞的节点，解锁时先停止碰撞，再播放消散。
- 环境危险实现统一 `HazardArea` 接口，拥有预警、激活、冷却和关闭状态。
- 可破坏陶罐使用独立场景和 `Destructible` 组件，不与普通敌人共用击杀统计。
- 视觉墙体、树干和地面危险在编辑器中可见其碰撞或范围，自动测试抽查关键点。
- 飞行敌人的“无视树干”由碰撞层配置表达，不在每帧脚本中临时关闭碰撞。

## 11. UI 与剧情接入

- 存档、局外大厅、养成、角色选择、战斗 HUD、升级、进阶、结算和剧情分别为独立 Control 场景。
- UI 只订阅所属控制器的强类型信号；关闭界面时断开或随节点释放。
- 6+6 槽位使用固定容器，空槽显示弱化边框；进阶后替换图标并保留槽位索引。
- 剧情内容以 `StoryEventDefinition` 或等价只读数据读取，触发条件使用稳定事件 ID，不在波次脚本中硬编码整段文本。
- 已读长剧情允许跳过；Boss 战斗对白不暂停场景树。
- 赵云正式 Sprite Sheet 未交付时，角色卡在开发构建显示“等待正式步战资源”，发布构建的数据校验必须失败，防止带水印参考图或占位资源出包。

## 12. 性能方案

目标：

- Windows 1280×720/1920×1080：目标 60 FPS，最高密度场景 P95 帧时间不超过 16.7 ms。
- 桌面 Chromium/Edge Web：最低稳定 30 FPS，P95 帧时间不超过 33.3 ms。
- 场景切换和首次资源加载之外，不允许超过 100 ms 的主线程尖峰。

措施：

- 对投射物、经验球、伤害数字和短时特效建立类型安全对象池，回收时统一清空信号、计时器、碰撞和可见状态。
- 普通敌人仍使用场景实例，但活动上限不超过 150；Boss 援军上限按波次定义。
- 同屏经验球超过 220 时合并价值，不继续创建新节点。
- 远离玩家且屏幕外的纯视觉动画降低更新频率；战斗判定不得依赖被降频的动画帧。
- 使用 `MultiMeshInstance2D` 前先分析实际瓶颈，不为小规模对象牺牲编辑便利性。
- Web 使用 `gl_compatibility`/mobile 渲染路径，禁止依赖 Web 不支持的桌面渲染特性。

## 13. 自动测试与验收

继续使用 Godot 4.7 无窗口测试入口，按职责拆分测试脚本；聚合入口最终输出非零退出码表示失败。

### 13.1 数据校验

- 五个角色 ID 唯一，场景、头像、初始技能与解锁条件合法。
- 10 主动、10 心法均为五级；10 个进阶为一级。
- 十个配方一一对应，引用类型正确。
- 十二波索引连续；3/6/9 为小 Boss，12 为最终 Boss。
- 五个道具和四条养成定义数值完整。
- 正式发布校验在赵云无水印透明底步战资源未接入时必须失败，并给出明确错误；骑马动画不属于必需资源。

### 13.2 存档

- 三档创建、保存、重载、删除和互不污染。
- 夜烬、养成、角色、故事和统计往返一致。
- 临时文件校验失败不覆盖正式档。
- 正式档损坏时回退 `.bak`；双重损坏不自动清空。
- Schema 迁移逐级执行且幂等。
- Web 导入拒绝非法 JSON、越级养成和未知顶层结构。

### 13.3 战斗单元与集成

- 6+6 槽位限制和候选过滤。
- 主动 5 级加对应心法才可进阶；心法不要求满级。
- 宝匣在无合法配方时保留，合法后可开启且只消费一次。
- 三个宝匣使每局最多进阶三次。
- 第 3/6/9 波小 Boss 唯一生成；超时停止援军但不自动胜利。
- 第 12 波必须击败鬼面剑豪才产生胜利结果。
- 五种道具效果、掉落上限和四波保底。
- 复生每局至多一次，生命、无敌和清场范围符合等级。
- 夜烬公式边界：0 波退出、部分完成、满击杀奖励、首次胜利和重复提交。
- 赵云的龙胆枪等级行为、精英伤害加成和进阶瞬间无敌。

### 13.4 端到端与手测

- 加速完成完整十二波，验证波次、剧情、宝匣、结算、夜烬和保存闭环。
- 用每名角色开始一局，验证初始技能、特性和角色卡信息。
- Windows 键鼠、桌面 Web 键鼠、现有移动横屏触摸回归。
- 浏览器刷新、关闭页面、清缓存前导出、导入覆盖和损坏备份提示。
- 最高敌人/投射物密度性能场景记录 Windows 与 Web P50/P95 帧时间。
- 所有现有 Demo 测试在迁移期间持续通过；替换旧断言时必须先添加对应新断言。

## 14. 实施顺序与完成标准

### 阶段 0：文档和基线

- 本目录文档与 `AGENTS.md` 路由完成。
- 现有无窗口测试保持 `ALL TESTS PASSED`。

### 阶段 1：数据与持久化骨架

- 建立 Resource 类型、ContentDatabase、ProfileData、SaveManager 和三档测试。
- 迁移内容时保持当前四波 Demo 可运行。

### 阶段 2：夜烬、养成和三档 UI

- RunResult、夜烬结算、四条养成、免费重置、档位选择与 Web 导入导出完成。

### 阶段 3：角色系统

- 数据驱动选角与解锁完成。
- 宁霜华、玄灯接入。
- 赵云逻辑与数据可先完成；正式视觉接入等待从已确认原型制作出的无水印透明底步战 Sprite Sheet。

### 阶段 4：道具

- 陶罐、精英掉落、保底和五种效果完成。

### 阶段 5：技能重构与进阶

- 6+6 槽位、10+10 内容、独立运行时、十套配方与宝匣完成。
- 原有九个主动的行为回归通过，龙胆枪和七进七出新增测试通过。

### 阶段 6：十二波与地图

- 四区地图、两种新敌人、两种精英词缀、三名小 Boss 和最终 Boss 状态机完成。

### 阶段 7：剧情、美术和音频

- 三国时代开场、十二响、Boss 对白、三条角色路线和结局接入。
- 按已确认的银蓝甲原型完成无水印步战 Sprite Sheet、场景、碰撞与导入验证；排除全部骑马帧。
- 所有素材授权更新到 `CREDITS.md`。

### 阶段 8：平衡与发布

- 12 分钟目标、36～42 级、2～3 个进阶和夜烬产出达到策划验收区间。
- Windows 60 FPS 目标与桌面 Web 30 FPS 下限达成。
- 自动测试、手测清单、导出构建和授权检查全部通过。

## 15. 兼容性与变更纪律

- 数据 ID、存档字段或解锁条件变更必须同时修改迁移和测试。
- 玩家可观察数值以 `v1_game_design.md` 为准；实现不能只在代码中“临时调平衡”。
- 正式文字、时代与人物关系以 `v1_narrative_design.md` 为准。
- 技术接口调整先更新本文件，再改调用方。
- 当前计划从 9+9/四角色扩为 10+10/五角色，是 V1 已确认基线，不作为后续可选内容处理。
