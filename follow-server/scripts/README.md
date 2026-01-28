# 批量标签导入脚本

## 概述

此脚本用于从 Excel 文件批量导入音乐标签。每个 Excel sheet 表示一个标签，sheet 中的歌曲将被打上该标签。

## 安装依赖

```bash
cd follow-server/scripts
pip install -r requirements.txt
```

## Excel 文件格式

```
tags.xlsx
├── Sheet: 华语流行      # Sheet 名称 = 标签名
│   ├── 周杰伦 - 七里香  # 格式: "歌手 - 歌曲名称"
│   ├── 周杰伦 - 晴天
│   └── ...
├── Sheet: 粤语经典
│   ├── 陈奕迅 - 富士山下
│   └── ...
└── Sheet: K歌必唱
    ├── 张学友 - 吻别
    └── ...
```

**注意**：
- 同一首歌可以出现在多个 sheet 中（多标签）
- 歌曲格式必须为 `歌手 - 歌曲名称`（注意是 ` - ` 带空格的连字符）
- 匹配时忽略大小写

## 使用方法

### 1. 生成示例模板

```bash
python generate_template.py
```

生成 `tags_template.xlsx` 作为参考。

### 2. 预览模式（推荐先执行）

```bash
python import_tags.py tags.xlsx --dry-run
```

预览模式会：
- 检查每个标签是否存在
- 验证歌曲是否能在数据库中找到
- 输出未匹配的歌曲列表
- **不会实际修改数据库**

### 3. 执行导入

```bash
python import_tags.py tags.xlsx
```

### 4. 指定标签分类

```bash
python import_tags.py tags.xlsx --category 风格
```

所有新创建的标签都会设置此分类。

### 5. 自定义数据库连接

```bash
python import_tags.py tags.xlsx \
    --db-host localhost \
    --db-port 5432 \
    --db-name follow \
    --db-user follow \
    --db-password follow
```

## 输出示例

```
📂 读取 Excel 文件: tags.xlsx
📋 发现 4 个标签 (sheets)

🏷️  处理标签: 华语流行 (5 首歌曲)
   ✨ 将创建新标签

🏷️  处理标签: 粤语经典 (5 首歌曲)
   ℹ️  标签已存在

==================================================
📊 执行统计:
   标签 - 新创建: 1, 已存在: 3
   歌曲 - 匹配成功: 18, 未找到: 2
   关联 - 新增: 15, 已存在跳过: 3
   错误 - 格式解析失败: 0

⚠️  未找到的歌曲 (2 首):
   [华语流行] 某歌手 - 某歌曲
   [粤语经典] 另一歌手 - 另一歌曲

📝 完整未找到列表已保存到: tags_not_found.txt
```

## 常见问题

### Q: 歌曲匹配不上怎么办？

A: 检查以下几点：
1. 歌曲格式是否正确（`歌手 - 歌曲名称`）
2. 歌手名称是否与数据库中一致
3. 歌曲名称是否完全匹配

### Q: 如何处理同一歌手的不同写法？

A: 脚本使用不区分大小写的匹配，但歌手名必须完全一致。如果数据库中是"周杰伦"，Excel 中也需要是"周杰伦"而非"Jay Chou"。

### Q: 标签已存在会怎样？

A: 如果标签名已存在，脚本会直接使用现有标签，不会创建重复。
