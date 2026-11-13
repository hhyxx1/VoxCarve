# 声剪 · 领域架构

## 模块关系

```text
Index / 原生导航 ──→ WorkspaceState ──→ MediaModels
       │
       ├──→ XuzuoTheme / 通用控件 / WaveformPane / TranscriptPane
       ├──→ ProjectRepository ──→ 本地 ArkData RDB
       └──→ SdkProbePanel ──→ File Picker / AudioKit / Speech Kit / NAPI

后续 PCM、试听和导出服务 ──→ EditGraph / RenderSequence / RenderTask
```

| 模块 | 已实现的契约 |
| --- | --- |
| `domain/MediaModels.ets` | `MediaProject` 保存稳定 RDB ID、名称和创建/更新时间。`SourceTrack` 区分音频和视频，包含素材路径、编码 MIME、轨道偏移和微秒时长。PCM 专用元数据为采样率、声道和帧数。 |
| `domain/EditGraph.ets` | `EditDecision` 记录源 PCM 半开帧区间 [startFrame, endFrame)、保留或删除以及创建时间。撤销/重做移动游标，新编辑分支截断 redo 尾部。快照保存全部决定和游标，恢复时检查范围、ID 与动作。 |
| `RenderSequence` | 一个音轨上的保留片段按源时间排序，输出由累计帧数从零生成。两端统一按最近帧量化，微秒由帧数换算，不在每段反复舍入。无保留帧时返回空序列，渲染服务须拒绝空导出。 |
| `TranscriptSegment` / `CaptionCue` | 文字稿用源音轨微秒，可无时码，记录说话人、来源和复核状态。字幕用剪后输出微秒，允许追溯到原文字稿。媒体服务应在确认后把文字区间提交给编辑图。 |
| `domain/RenderTask.ets` | New → Validating → Queued → Running → Verifying → Success。进度单调，成功要求输出 URI 且为 100%。取消进入 Cancelling/Cancelled，Failed 和 Unsupported 需要错误码。重试建立独立任务。 |
| `repository/ProjectRepository.ets` | `list()`、`create(name)` 实际读写 ArkData。`voxcarve.db` v1 记录项目元数据，原子单行插入。初始迁移使用可重复的 CREATE TABLE IF NOT EXISTS，成功后标记版本。未知版本保留原库并显示读取失败。 |
| `viewmodel/WorkspaceState.ets` | 列表区分 loading/ready/error，ready 空数组显示空态。页面和导航使用类型化数据与显式路由。 |

## 后续媒体边界

- 阶段 03 在临时沙箱文件完成媒体复制和校验后，再提交素材行、轨道和编辑快照。编辑图序列化接口已具备，RDB v1 目前只存项目目录。
- 原始素材、PCM 缓存和导出文件使用不同路径。工作线程按块解码，波形传真实归一化 min/max 峰值。播放与导出共享 RenderSequence，系统播放毫秒与业务微秒在适配层换算。
- 音轨 PTS 从累计帧数计算。视频还需验证轨道偏移、关键帧、显示顺序及音画同步。
- 文件经系统选择授权，默认离线。没有声明联网或录音权限。现有语音入口只查询离线语种。

阶段 03 实现 `domain/PcmWav.ets` 的 RIFF/PCM16 解析、分块峰值和 WAV 头生成。`LocalAudioService` 管理 Picker、原始副本、渲染临时文件及 AVPlayer。`AudioWorkspace` 驱动项目内操作。RDB v2 加入每项目一行编辑快照，由 v1 原位迁移。素材当前采用单项目固定沙箱文件名，解析通过后原子重命名。
