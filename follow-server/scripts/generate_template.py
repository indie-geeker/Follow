#!/usr/bin/env python3
"""
生成示例 Excel 模板文件
"""

import pandas as pd

# 创建示例数据
example_data = {
    "华语流行": [
        "周杰伦 - 七里香",
        "周杰伦 - 晴天",
        "林俊杰 - 江南",
        "邓紫棋 - 泡沫",
        "陈奕迅 - 十年",
    ],
    "粤语经典": [
        "陈奕迅 - 富士山下",
        "张学友 - 吻别",
        "刘德华 - 忘情水",
        "Beyond - 海阔天空",
        "谭咏麟 - 讲不出再见",
    ],
    "K歌必唱": [
        "周杰伦 - 七里香",
        "林俊杰 - 江南",
        "张学友 - 吻别",
        "陈奕迅 - 十年",
        "五月天 - 突然好想你",
    ],
    "情歌": [
        "周杰伦 - 晴天",
        "邓紫棋 - 泡沫",
        "陈奕迅 - 十年",
        "张学友 - 吻别",
        "林俊杰 - 可惜没如果",
    ],
}

# 创建 Excel 文件
with pd.ExcelWriter("tags_template.xlsx", engine="openpyxl") as writer:
    for sheet_name, songs in example_data.items():
        df = pd.DataFrame(songs, columns=["歌曲"])
        df.to_excel(writer, sheet_name=sheet_name, index=False)

print("✅ 已生成示例模板: tags_template.xlsx")
print("\n📋 文件结构:")
for sheet_name, songs in example_data.items():
    print(f"   Sheet: {sheet_name} - {len(songs)} 首歌曲")
