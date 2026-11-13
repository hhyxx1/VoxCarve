# 工程现状

初始化前根目录仅有嵌套的 xuzuo-assets，父目录无 Git 仓库。C:/Project 与 Codex 工作树中未找到候选 bundle 的其他 app.json5。公开检索与 GitHub 已授权安装范围的同名检索均未发现 VoxCarve 仓库。此结论限定于扫描目录和可访问范围。

本地开发分支为 codex/sdk26-audit。资料库 main 的 SHA 为 2621898445470eee420c5d06af46046d052bd053，工作树清洁。VoxCarve 采用本地候选 bundle com.hhyxx.voxcarve。阶段 01 探测页从设置进入。

依赖顺序为 SDK 与设备探测 → 时间模型、编辑图与组件 → 本地 PCM / WAV 闭环 → 十页数据联动 → 条件性扩展 → 独立验收。阶段 03 已接通 PCM WAV 的真实导入、波形、非破坏性剪辑、撤销重做、重启恢复、试听与导出。完整压缩音轨与视频、文字稿、字幕、停顿复核和独立导出页待接入。

[设备与构建复现](ENVIRONMENT.md) · [接口证据](API_AUDIT.md) · [实现矩阵](IMPLEMENTATION_MATRIX.md)
