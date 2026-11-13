# 实现与验收矩阵

功能 ID 见资料库的 VoxCarve 04_ACCEPTANCE.md。阶段 01 的探测结果记录在 API_AUDIT.md，以下业务验收均为 NOT_RUN。

| 功能 | 页面 | 计划模块 | 可观察验收 |
| --- | --- | --- | --- |
| F01–F02 | projects / import | repository、platform/media | 选择真实文件，复制、识别轨道并生成可读 PCM，重启仍可恢复 |
| F03–F05 | transcript / timeline | services/speech、domain/edit | 人工分句和说话人标记，时间码跳转试听，删除区间实际影响渲染且可撤销 |
| F06 | timeline | components/waveform、domain/edit | 真波形缩放、拖选和时间码精调，边界换算到样本帧 |
| F07 | silence | domain/silence | 真实 PCM 计算候选，人工复核后才产生剪辑决定 |
| F08 | captions | domain/captions、services/export | 可编辑字幕，按剪后时间排序输出 UTF-8 SRT/VTT 并验重叠 |
| F09 | preview | services/render、platform/audio | 试听和导出共用剪辑序列，实际跳过删除片段 |
| F10–F12 | export | services/render、platform/media | 真实 WAV 通过外部工具复核。MP3/MP4 基于设备能力及可播放证据开放 |
| F13 | projects / history / export | repository、domain/edit | 版本撤销重做、任务取消和重启恢复，源文件保持原哈希 |
| F14–F15 | import / settings | platform、services | 录音显式触发。未授权时可本地导入，设备缺能力时保留人工剪辑路径 |

下一阶段先定义 MediaProject、SourceTrack、TranscriptSegment、EditDecision、RenderSequence、CaptionCue、RenderTask。以半开区间 [startFrame, endFrame) 和不可变原始素材建立可逆编辑图。逐句源时间用于定位，字幕输出时间由 RenderSequence 映射。

阶段 02 交付了十页导航、项目目录和编辑领域模型。F13 中的本地项目创建与重启恢复已通过模拟器验证，编辑历史快照通过主机用例。媒体、任务执行及完整 F01–F15 业务验收仍按后续阶段执行。[阶段 02 验证](TEST_REPORT.md)

阶段 03 在 16 位 PCM WAV 范围验证了 F01–F02、F06 的拖选与帧边界、F09–F10、F13 的项目和编辑恢复。视频、压缩音频、静音算法、转写与文字关联、字幕、任务队列和大文件专项仍待验证。[阶段 03 证据](CORE_WORKFLOW.md)

阶段 04 的 F04/F05 人工时间标注及定位、F07 逐段停顿候选、F08 字幕与 SRT、F09 独立试听页和 F13 编辑版本恢复已走查。其他能力及兼容性证据见 [十页走查](PAGE_WALKTHROUGH.md)。
阶段 05 增加 F03 有条件的普通话离线草稿、F07 可调停顿门限、F08 WebVTT 与 F13 部分运行中取消。压缩媒体、视频音画同步和持久任务队列仍待实现与验证。[阶段 05 集成报告](INTEGRATION_REPORT.md)
