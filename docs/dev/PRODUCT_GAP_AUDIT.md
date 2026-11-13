# VoxCarve 产品差距与 UI 一致性审查

2026-11-13。GitHub 默认分支实际 HEAD 为 b24e08402378580681c8cffab6df06b3c5cce516。修复分支 codex/product-gap-audit。规范基线为 xuzuo-assets/main@2621898445470eee420c5d06af46046d052bd053。审查覆盖 PRD、UX、技术规范、验收矩阵、极简视觉裁定、共用设计系统及十页页面规格。页面稿用于确认任务与结构，视觉以极简裁定为准。本机签名配置、.clangd、.clang-tidy 的 SHA-256 与开工前一致。

## F01–F15

代码路径以 entry/src/main 为基准。P0 为正确性风险，P1 为核心工作流或验收缺口，P2 为能力扩展。

| 功能 | 实现与代码 | 差距和修复次序 | 本轮验收 |
| --- | --- | --- | --- |
| F01 导入 | 部分。ets/services/LocalAudioService.ets 通过系统 Picker 读取、复制并检查长度，解析后重命名。单项目单轨。 | P1 增加空间预估、资产清单及导入取消。视频见 F12。 | 真机打开已有 MP3 PCM 和 WAV。全新导入矩阵 NOT_RUN。 |
| F02 解码 | 部分。cpp/audio_decode.c 对 MP3/AAC 解码到 PCM WAV，源文件只读，拒绝视频与多音轨。 | P0 建立压缩轨首尾填充、容器 PTS 到 PCM 的映射，旧项目保留原坐标。 | 已导入的 MP3 素材真机可打开，重新解码 NOT_RUN。WAV 源哈希核对通过。 |
| F03 转写 | 设备及输入受限。OfflineSpeechService.ets 和 ProjectToolPage.ets 支持离线普通话、16 kHz 单声道 PCM、≤60 秒，其他素材可手工处理。 | P1 五分钟口播、48 kHz 立体声及长访谈无法直接获得可用逐句稿。先验证重采样、分段和设备模型。 | 真机实际触发识别，界面报告提前结束并载入部分草稿。 |
| F04 校准 | 部分。ProjectToolPage.ets 支持源音时间及说话人，无时间的稿件标待校准。 | P1 同屏监听与调边；SDK 结果没有词句时间戳，逐字剪辑未建立。 | 真机检查设备受限提示及离线草稿，完整手工校准 NOT_RUN。 |
| F05 文字联动 | 部分。ProjectToolPage.ets 支持已校准句段定位波形，AudioWorkspace.ets 支持试听与可撤销剪辑。 | P1 波形回定位句段、文字检查器、播放追随及部分剪除标识。 | 本轮文字稿入口移到波形旁并走查；定位、删句和撤销全链 NOT_RUN。 |
| F06 精确编辑 | 部分。AudioEditorPanes.ets 的全轨 192 桶支持拖选及 0.1 秒吸附；AudioWorkspace.ets 支持六位小数秒并量化到帧；EditGraph.ets 支持分割。 | P1 可滚动缩放窗口、拖边和微调，再做片段合并。 | 分割、样本换算及历史单测通过，完整手势矩阵 NOT_RUN。 |
| F07 停顿 | 基础候选已实现。PcmWav.ets 每 20 ms 分声道计算 RMS，阈值与最短停顿可调，候选须人工确认。 | P1 候选内试听、前后保留量、误报语料验证。 | 主机 PCM 用例通过，长轨设备取消与误报 NOT_RUN。 |
| F08 字幕 | 部分。TimeRange.ets 从源区间生成剪后草稿并编码 SRT/VTT；基线允许仍在总时长内的过时字幕导出。 | P0 本轮保存时绑定来源映射，旧稿或映射变化显示待复核并拦截导出。分割/淡入不改变映射，撤销回同一映射可继续导出。批量重映射、字幕样式待做。 | 真机旧 VTT 被拦截；单测覆盖过时区间、撤销及分割；新稿写盘回读 NOT_RUN。 |
| F09 试听 | 音频已实现。LocalAudioService.ets 渲染保留片段，AudioWorkspace.ets 将播放时间回映源帧。 | P1 补字幕跟随及片段边界试听。 | 真机触发剪后试听，完整听感与长轨播放 NOT_RUN。 |
| F10 WAV | 已实现。LocalAudioService.ets 按图分块拷贝并应用淡入、校验输出长度。 | P0 系统授权 URI 在写入前 TRUNC，写失败可能留部分文件。后续需验证目标替换和可恢复错误反馈。 | 真机完成 WAV 写盘及系统保存取消，按样本核对实际产物。 |
| F11 压缩输出 | 未实现。cpp/media_probe.c 只有实例探测；UI 仅提供 WAV。 | P2 编码器能力、EOS、容器与外部播放需验证。 | 真机创建 MP3/AAC 编码器成功；实际编码输出 NOT_RUN。 |
| F12 视频 | 未实现。cpp/audio_decode.c 拒绝视频轨。 | P2 双轨解复用、关键帧、重编码和音画同步，依赖 F02 时基。 | 真机创建 MP4 muxer 成功；双轨数据写入和音画同步 NOT_RUN。 |
| F13 恢复 | 部分。ProjectRepository.ets 保存项目、文字与编辑快照，TemporaryMediaRecovery.ets 清理启动残留。无删除、持久任务队列、资产校验清单与空间不足恢复。 | P0 优先修复发布失败与任务状态，再做删除事务、孤儿回收、任务持久化。剪辑台已接入渲染取消。 | 真机重开已有图及保存取消；主动渲染取消、崩溃注入与长轨 NOT_RUN。 |
| F14 录音 | 未实现，module.json5 无麦克风权限。 | P2 录音、暂停、停止、中断及用户触发授权。 | 本机声明可用，设备录音 NOT_RUN。 |
| F15 权限 | 部分。系统文件和保存 Picker 授权，默认本地，应用无联网和麦克风权限；显示识别和导出限制。 | P1 补拒绝、系统撤销、缓存可管理及辅助技术验证。 | 保存取消和设备受限提示已实测，撤销与权限拒绝 NOT_RUN。 |

## API 26 与时基

本机 SDK 的 native_avcodec_base.h 提供轨道起点、缓冲时长、API 23 跳采样元数据和 API 24 解码开关。跳采样条目明确支持 MP3、Vorbis、Opus，首尾元数据可缺失。当前解码仅拒绝逆序 PTS，顺序拼接 PCM，未启用跳采样或保存容器时基，AAC edit list 需单独验证。保留原生 PCM 坐标可避免旧项目偏移。历史样本设备 PCM 分别为 97920/97280 帧，独立解码各 96000 帧，本轮未复测该差值。[压缩音频报告](COMPRESSED_IMPORT_QA.md) · [官方拆封装](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/audio-video-demuxer/)

本机 native_avcodec_audiocodec.h、native_avcodec_videoencoder.h、native_avcodec_videodecoder.h 和 native_avmuxer.h 确认音频同步编码、视频编解码及 MP3/MP4 容器入口存在。@ohos.multimedia.media.d.ts 有 createAVRecorder。设备编码和录音需用真实产物验收。[官方编码](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/synchronous-audio-encoding/) · [官方格式矩阵](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avcodec-support-formats/) · [官方录音接口](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-avrecorder-base-h/)

本机 @hms.ai.speechRecognizer.d.ts 的 SpeechRecognitionResult 只有文本与结束标记，无词句时戳。当前代码仅接短语音，完整模型与语言能力仍按设备验证。[官方识别接口](https://developer.huawei.com/consumer/en/doc/harmonyos-references/hms-ai-speechrecognizer/)

## 系列 ArkUI 基础契约

| 共用能力 | 四款应遵守 | VoxCarve 本轮与剩余差异 |
| --- | --- | --- |
| AppBar、AdaptiveNav | 页面标题 20vp，长标题省略；返回至少 48vp 且可朗读。手机底栏、平板侧栏，二级守卫统一。 | 统一顶栏和返回热区，保持三入口；二级页仍限 640vp，平板过度留白。 |
| Button、IconButton、ToolBar | 主/次/低强调/危险状态、8vp 圆角、≥48vp 热区、忙碌禁用，图标带标签，窄屏可溢出。 | 次按钮描边、危险操作语义化；合并重复修剪与保留。系列图标、溢出工具栏待补。 |
| FormField、SegmentedTabs、ListRow | 4vp 间距基准，14–16vp 正文，字段边框与错误，列表来自真实数据。 | 统一输入框轮廓；剪辑台秒与文字/字幕毫秒仍有转换成本。 |
| StatusChip、EmptyState、ErrorState、PermissionGate、ProgressSheet | 原因及可操作恢复，单主 CTA，任务进度与取消真实。 | 去掉通用重复错误徽标；剪辑台渲染接入取消。空态 CTA 合并、权限状态、持久任务待完成。 |
| ConfirmSheet、BottomSheet、主题 | 原生确认、危险反馈、纯色语义主题、减少动效、字号与读屏。 | 沿用原生确认及浅/深/系统偏好。对比度、减少动效开关、读屏与全量热区待验收。 |

VoxCarve 自持波形、时间窗、播放头、文本校准、编辑图和剪后轨道。LightBearing 自持日轨与方位，FrameMori 自持相机与帧时间轴，MacroLoom 自持宏按钮与执行回执。本轮只改 VoxCarve。试听及文字稿入口已靠近波形，工作台以分隔线代替重边框卡片。文字双向联动及大屏检查器仍是核心差距。

## 本轮构建与设备证据

- 基线执行 Node 单测 16 项通过。SDK 26 Release 增量构建成功，真机安装基线 HAP 并打开已有 MP3 测试项目。另从 Git 归档运行 ohpm install --all 后重新编译 ArkTS，干净源码构建生成未签名 HAP。[基线剪辑台](product-audit-evidence/baseline-timeline.png)
- 审查分支 17 项单测通过，ArkTS 编译及 Release 打包通过。命令为 node --test tests/*.test.mjs 和 hvigorw.js assembleHap --mode module -p module=entry@default -p product=default -p buildMode=release --no-daemon。完整日志与包位于本机 .artifacts/product-audit/。[编译、测试和设备探测摘录](product-audit-evidence/build-and-probe.txt)
- MIA-AL00，HarmonyOS 7.0.0.109，API 26。1224×2776、像素比 3.375，约 362.7vp。六页实拍，设置与波形核对浅深主题。底栏 162px，即 48vp。精确 360/390/430vp 以及大字 ≥1.3×、读屏、横屏、全控件热区矩阵 NOT_RUN。已有 Mate 90 Pro 模拟器约 365.7vp，无法替代三档目标。
- MatePad Pro 13 模拟器，HarmonyOS 7.0.0.107，API 26。2880×1920、像素比 2，1440vp。六页均有截图。平板 Picker 测试素材选择未完成，带音轨正常态及保存链 NOT_RUN。
- 真机系统保存取消显示“已取消保存”。另一次 [真实 WAV](product-audit-evidence/verified-cut.wav) 为 48 kHz 双声道、72000 帧、288044 字节、1.500 秒，逐字节匹配源帧 [0,24000) 与 [48000,96000)。SHA-256 为 299e06022d31c9740d1c90b0a8f18f16efcd74f5c3255d60fa127b8f63c0829d。源 SHA-256 为 7ae6a3240a1ebabe6a1e8221add599107370ee0189bd048f635881e669ea54a2，与仓库测试原件一致。
- T01/T03 验证已有手工图的真机输出和采样边界，新建工程至重新手工裁切的全链 NOT_RUN。T02 观察到离线部分草稿提示。T04/T05/T06 设备专项 NOT_RUN。此次没有把历史 PASS 计入本轮。

| 页面 | 手机 | 平板 |
| --- | --- | --- |
| 项目首页 | [浅色](product-audit-evidence/gap-projects-light.png) | [项目](product-audit-evidence/gap-tablet-projects.png) |
| 剪辑台 | [浅色](product-audit-evidence/gap-timeline-light.png) · [深色](product-audit-evidence/gap-timeline-dark.png) | [无素材](product-audit-evidence/gap-tablet-timeline.png) |
| 文字稿 | [页面](product-audit-evidence/gap-transcript-light.png) · [离线识别](product-audit-evidence/gap-asr.png) | [空态](product-audit-evidence/gap-tablet-transcript.png) |
| 字幕 | [页面](product-audit-evidence/gap-captions-light.png) · [旧稿拦截](product-audit-evidence/gap-caption-stale.png) | [无素材](product-audit-evidence/gap-tablet-captions.png) |
| 导出 | [WAV 表单](product-audit-evidence/gap-export-light.png) | [无素材](product-audit-evidence/gap-tablet-export.png) |
| 设置 | [浅色](product-audit-evidence/gap-settings-light.png) · [深色](product-audit-evidence/gap-settings-dark.png) | [浅色](product-audit-evidence/gap-tablet-settings.png) · [深色](product-audit-evidence/gap-tablet-settings-dark.png) |

下一轮先处理外部目标失败恢复、压缩时基与字幕重映射，随后完成精确波形编辑、文字双向联动和 UI 验收矩阵。视频、录音及压缩输出排在核心问题之后。

## 波形与字幕复验

本轮以审查提交 1a08aee 为起点。远端 main 为 b24e084。资源库 main 仍为 2621898。下表补充本轮状态，其他功能沿用前文的实现范围，历史 PASS 不计入本轮。

| PRD | 本轮状态 | 证据与未覆盖项 |
| --- | --- | --- |
| F02 / F06 | PASS_HOST / PASS_DEVICE | 窗口峰值按真实双声道 PCM 采样，主机测试确认只读指定帧；MIA-AL00 放大 0–1.020 秒，再右移到 0.510–1.530 秒。缩放围绕播放头，左右按钮按半窗平移；保留原有吸附与秒数输入。连续滚动手势、合并及长轨压力 NOT_RUN。 |
| F04 / F05 | PASS_HOST / PASS_DEVICE | 最大重叠匹配只选已校准句段。真机手工保存测试句段 100–350 ms，定位波形显示 0.1–0.35 秒，再打开文字稿命中该句。播放过程自动追随及同屏检查器 NOT_RUN。 |
| F08 | PASS_HOST | 签名由采样率和实际连续保留源区间构成。输出由这些区间按顺序累加得到；同游标、同时长但不同来源被拒绝。删除、保留、分割、淡入、撤销重做、等价旧映射、序列化重启与无签名旧数据均有测试。 |
| F08 | PASS_DEVICE | 旧字幕先显示待复核并阻止导出；校对重存后强制停止并重启，VTT 成功保存并读回。文件 SHA-256 a42f075aebed46672518383f240c79c4a1b4990c6f6de36bfb63649c33ed8861。选择器返回后、打开输出 URI 之前再次从数据库读取编辑图并核对；面板打开期间并发改变编辑图的注入测试 NOT_RUN。 |
| F09 / F10 | NOT_RUN | 本轮保留渲染代码。前一轮已验证 WAV 字节，本轮未重新测整条试听、WAV 导出及取消链。 |
| UI | PASS_DEVICE / NOT_RUN | 362.7vp 真机正常剪辑台、放大、文字命中与旧字幕截图。按钮沿用 48vp 最小高度和中性描边；工具位于波形下方。没有加入渐变或装饰卡。1440vp 模拟器安装成功，系统 Picker 未完成素材导入，正常态 NOT_RUN。指定 360/390/430vp 与大字体矩阵 NOT_RUN。 |

SDK 26 Release 干净构建使用 Git 源码归档、ohpm install --all、Node 单测和 Hvigor assembleHap，34 个任务全部重新执行，20 项单测通过。真机使用相同源文件的本机签名构建。签名和 IDE 文件的本地哈希保持一致。

[构建与实测摘录](timeline-regression-evidence/results.txt) · [真机概览](timeline-regression-evidence/timeline-regression-phone-overview.png) · [真机缩放](timeline-regression-evidence/timeline-regression-phone-zoom.png) · [文字定位](timeline-regression-evidence/timeline-regression-phone-transcript.png) · [旧字幕拦截](timeline-regression-evidence/timeline-regression-phone-legacy.png) · [真实 VTT](timeline-regression-evidence/verified.vtt)
