# 声剪阶段 06 · 验收矩阵

2026-11-13，API 26。真机 MIA-AL00 / HarmonyOS 7.0.0.109。阶段 04–05 的模拟器及真机证据列为回归基线。

| PRD | 状态 | 覆盖与缺口 |
| --- | --- | --- |
| F01/F02 | PASS_DEVICE（PCM16 WAV） | 16/48 kHz 基线，44.1 kHz 30 分钟真机导入，源与沙箱 SHA-256 相同。真机拒绝截断 1 字节的 WAV 且未发布素材。压缩音频与视频轨未实现。 |
| F03/F04 | DEVICE_CONDITIONAL | 16 kHz 单声道普通话文件生成部分草稿，保留人工校准。SDK 结果无词句时间戳。 |
| F05 | PASS_EMULATOR / PASS_DEVICE | 模拟器人工句段定位，真机验证源区间定位、试听和非破坏性保留。完整文字联动真机 NOT_RUN。 |
| F06 | 部分 PASS_DEVICE | 拖选、帧级时间输入、保留和删除已覆盖。缩放、吸附、拆分和合并尚未交付。 |
| F07 | PASS_DEVICE | 30 分钟 PCM 的 900–901 秒静音被正确检测，候选由用户确认。运行中取消无候选结果。 |
| F08 | PASS_HOST / PASS_EMULATOR / PASS_DEVICE | SRT、WebVTT 校验和实际保存，剪后时间映射。真机中文 WebVTT 回读逐字节匹配。字幕独立回放样式 NOT_RUN。 |
| F09/F10 | PASS_DEVICE / PASS_HOST | 真机试听及 WAV 保存，外部工具复核单/双声道，30 分钟样本输出逐帧核对。 |
| F11/F12 | NOT_RUN | MP3/MP4 生产链未接入，无法验证压缩编码及 A/V 同步。 |
| F13 | 部分 PASS_DEVICE | 项目和编辑图重启恢复，长文件分析取消及离线识别取消。持久队列、暂停恢复、渲染中取消和资源耗尽专项 NOT_RUN。 |
| F14 | NOT_RUN | 应用内录音未实现。 |
| F15 | PASS_HOST / 部分 PASS_DEVICE | 无网络或麦克风权限，系统 Picker 及离线手工路径。系统权限撤销和动态网络隔离未实测。 |

T01、T03、T04 的 WAV 剪辑、采样边界和长音轨重启通过。T02 的时间戳缺失及校准提示见阶段 05。T05 未运行。T06 已覆盖真实候选、原文件哈希不变和既有撤销重做，未做系统性误报语料验证。

[阶段 04 页面与设备基线](PAGE_WALKTHROUGH.md) · [阶段 05 集成](INTEGRATION_REPORT.md) · [阶段 06 日志](STAGE06_QA_LOG.txt)
