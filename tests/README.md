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

## 编写约定

- 测试套件放在 `tests/suites/`，文件名使用 `test_<suite>.gd`。
- 套件继承 `RefCounted`，公开 `suite_name: StringName` 和异步兼容的 `run(tree, context)` 方法。
- 使用 `TestContext.check()` 记录断言，不自行结束测试进程。
- 需要文件读写的测试只能使用 `user://tests/` 下的独立临时目录，并只清理自己创建的目录。
- 每个开发步骤先运行对应套件，再运行完整回归测试；测试脚本在功能完成后继续保留。
