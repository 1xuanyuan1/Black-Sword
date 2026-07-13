# 自动测试

本目录保存项目的永久自动测试。测试代码不得写入正式存档目录，也不得依赖玩家已经存在的存档或编辑器状态。

## 运行全部测试

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path 'E:\workspace\godotwork\Black-Sword' --script 'res://tests/test_runner.gd'
```

## 运行单个套件

用户参数放在 `--` 分隔符之后：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path 'E:\workspace\godotwork\Black-Sword' --script 'res://tests/test_runner.gd' -- --suite=baseline
```

当前套件：

- `framework`：套件发现、异步执行和退出码。
- `baseline`：步骤 0 之前已有的完整 Demo 回归测试。
- `content_database`：Resource 内容加载、ID、引用完整性、旧数值和 `ContentRegistry` 兼容层。
- `save_manager`：三档隔离、原子保存、备份恢复、导入导出、GameState 与存档选择 UI。
- `meta_progression`：夜烬公式、重复提交保护、四条局外养成、全额重置、RunConfig、一次复生与局外大厅 UI。
- `character_system`：五角色定义、解锁费用与条件、档位隔离、固有特性、龙胆枪、角色卡与素材校验。
- `item_system`：五种即时效果、陶罐与精英掉落、同屏上限、四波保底、重复增益规则与临时效果 HUD。
- `skill_inventory`：10+10 内容、6+6 槽位、候选过滤、五级心法属性聚合与双排 HUD。
- `evolution_system`：十套配方、进阶条件、原槽替换、冷却继承、永久宝匣、三选一与单局三次上限。
- `wave_director`：十二波顺序、Boss 死亡门控、三控制器装配、两种新敌人、精英词缀与三名小 Boss。
- `map_and_boss`：四区与结界解锁、五类环境危险预警/伤害、鬼面剑豪显式状态机与 70%/35% 阶段转换。
- `story_ui`：三国主线与两条支线文本、十二响提示、已读存档、故事档案、八个独立 UI 场景和音频接入。

故事入口使用隔离测试存档并强制展示首次序章：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-story
```

## 编写约定

- 测试套件放在 `tests/suites/`，文件名使用 `test_<suite>.gd`。
- 套件继承 `RefCounted`，公开 `suite_name: StringName` 和异步兼容的 `run(tree, context)` 方法。
- 使用 `TestContext.check()` 记录断言，不自行结束测试进程。
- 需要文件读写的测试只能使用 `user://tests/` 下的独立临时目录，并只清理自己创建的目录。
- 每个开发步骤先运行对应套件，再运行完整回归测试；测试脚本在功能完成后继续保留。

## 第 3 步人工验收入口

以下入口仅在调试构建生效，存档写入 `user://tests/manual_meta_progression/`，不会碰玩家的 `user://saves/`：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64_console.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-meta-progression
```

## 第 4～6 步人工验收入口

角色入口使用隔离测试存档，提供足够夜烬并开放四名角色的支付解锁资格：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64_console.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-characters
```

道具入口直接进入战斗，依次投放五种道具并准备受伤状态、经验球与普通/精英测试目标：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64_console.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-items
```

技能入口直接进入战斗，填满 6 个主动与 6 个心法，并自动触发一次满槽升级三选一：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-skills
```

进阶入口准备四套合法配方与三个永久宝匣，靠近宝匣即可测试进阶三选一：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-evolutions
```

十二波入口把普通波压缩为 2.5 秒，并自动击败 Boss，便于快速检查完整顺序与三次宝匣：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-waves
```

地图/Boss 入口直接开放四区、同时激活五类危险并让鬼面剑豪入场：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-map-boss
```

全地图瓦片布局总览（隐藏 UI、自动解锁分区并缩小镜头）：

```powershell
& 'E:\Godot\Godot_v4.7-stable_win64.exe' --path 'E:\workspace\godotwork\Black-Sword' -- --qa-map-overview
```
