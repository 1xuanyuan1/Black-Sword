# AI 资源库

该目录供 Godot 编辑器插件 `addons/npc_library_tool` 扫描 NPC 和特效资源。插件已在项目的 `project.godot` 中启用；重新打开编辑器后，可在右侧 Dock 找到“AI资源库”。

## 目录格式

一图全动作角色：

```text
AI资源库/一图全动作/<角色目录>/
├── npc.json
├── sprite.png
└── thumb.png
```

RPG Maker 角色：

```text
AI资源库/RPGMAKER/<角色目录>/
├── NPC.json
├── sprite.png
└── thumb.png                # 可选
```

- 每个角色使用独立目录。
- JSON 中 `assets.spritePath` 必须指向真实存在且已被 Godot 导入的贴图。
- 一图全动作数据使用 `_schema/npc.schema.v1.json` 和 `_schema/spritesheet.schema.v1.json`。
- RPG Maker 模式默认识别 144×192 图集，即 3 列 × 4 行、单帧 48×48。
- JSON 文件名建议统一使用小写 `npc.json`，避免在 Android、Linux 等区分大小写的平台上出现路径问题。

## 使用步骤

1. 把角色目录放入对应资源类型目录。
2. 等待 Godot 完成贴图导入。
3. 在右侧“AI资源库”面板选择资源类型。
4. 点击“扫描资源库”。
5. 预览角色并拖入打开的 2D 场景。
6. 插件生成的 PackedScene 会保存到 `res://generated/npc_library_tool/npcs/`。

当前已按项目需求导入原插件包中的示例资源，其中包括动漫及游戏角色形象。这些资源仅用于本地原型和插件验证；新增、发布或商用前，请确认自己拥有相应贴图、声音、角色形象和文本的使用权。
