# API 26 审计

官方参考核验于 2026-11-12。本机路径以 DevEco Studio 的 `sdk/default` 为基准。下列本地路径对应普通应用调用面。系统能力和具体设备结果分别记录。

| 能力 | SDK 声明、版本、系统能力 | 设备结果与实现决策 | 官方参考 |
| --- | --- | --- | --- |
| Picker 与文件读写 | `openharmony/ets/kits/@kit.CoreFileKit.d.ts` 导出 `picker, fileIo`。声明见 `ets/api/@ohos.file.picker.d.ts` 和 `@ohos.file.fs.d.ts`。`DocumentViewPicker(context)` 自 12，`select/save` 自 9，UserFileService。 | 模拟器验证选择面板启动、取消回调，以及通过保存面板写入 64,044 字节的内置测试 WAV。选择成功并重新打开源 URI 的运行验证为 NOT_RUN。选择器只临时授权。导入时以只读 FD 将授权文件分块复制到沙箱临时文件，完成后原子入库。保存需用户确认目标。持久授权接口有设备和权限条件，本地副本方案可避开该依赖。 | [选择用户文件](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/select-user-file/) · [Picker 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V14/js-apis-file-picker-V14/) · [授权持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/file-persistpermission-V13/) |
| FD 媒体源与拆封装 | `openharmony/native/sysroot/usr/include/multimedia/player_framework` 内 `native_avsource.h`、`native_avdemuxer.h`、`native_avbuffer.h`。CreateWithFD、SelectTrackByID 自 10，ReadSampleBuffer 自 11。系统能力 Spliter。 | 以真实轨道 MIME 选择解码路径。WAV PCM 走解包和采样格式校验。压缩样本走解码器。Mate 90 Pro 模拟器成功读出两套 PCM WAV 首个 4,096 字节样本，MIME 为 audio/raw，分别为 16 kHz 单声道与 48 kHz 双声道，起始 PTS 都为 0 µs。 | [AVSource](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avsource-h/) · [AVDemuxer](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avdemuxer-h/) · [拆封装指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/audio-video-demuxer/) |
| 音频解码及编码 | 同目录 `native_avcodec_audiocodec.h`、`native_avcodec_base.h`。统一 AudioCodec 和 AVBuffer 接口自 11，同步队列自 20。系统能力 AudioDecoder / AudioEncoder。 | 按 MIME 和设备能力创建实例，再验证配置、输入、EOS 和 PCM 输出。模拟器成功创建 AAC 解码器、AAC 编码器和 MP3 编码器。压缩解码与编码的数据链待验证。 | [AudioCodec](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avcodec-audiocodec-h/) · [解码](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/audio-decoding/) · [编码](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/audio-encoding/) · [格式矩阵](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avcodec-support-formats/) |
| PCM 渲染 | `audio` 来自 `@kit.AudioKit`，`openharmony/ets/api/@ohos.multimedia.audio.d.ts`。createAudioRenderer 自 8，writeData 自 11，返回结果自 12。系统能力 Multimedia.Audio.Renderer。 | 模拟器成功创建 48 kHz 双声道 S16LE 渲染器。样本播放和中断处理待验证。 | [AudioRenderer](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-audio-audiorenderer/) · [播放指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/using-audiorenderer-for-playback/) |
| 封装与时码 | Native `native_avmuxer.h`、`native_avbuffer_info.h`。AVMuxer 自 10，WriteSampleBuffer 自 11。系统能力 Multimedia.Media.Muxer。PTS 为微秒，Demuxer seek 为毫秒。`@kit.MediaKit` 的 AVPlayer seek、currentTime 是毫秒。 | 统一以音频帧作为裁切边界，微秒作领域时码，UI 和 seek 在适配层转换。输出时间按累计帧数从零生成，同轨按封装要求提交。模拟器成功创建并释放 MP4 muxer。含重排序帧的 MP4 需要另外验证解码顺序、显示顺序与 A/V 同步。 | [AVMuxer](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avmuxer-h/) · [AVBuffer](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avbuffer-info-h/) · [AVPlayer](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-media-avplayer/) |
| Core Speech | `hms/ets/kits/@kit.CoreSpeechKit.d.ts` → `hms/ets/api/@hms.ai.speechRecognizer.d.ts`，自 4.1.0(11)，Stage，AI.SpeechRecognizer。文件流 PCM 16 kHz、单声道、16 bit。 | 模拟器以 `online: 1` 创建引擎并返回 `zh-CN`。结果仅含 `isFinal/isLast/result`，没有词级或句级时戳字段。文本草稿需手工绑定和复核时码。识别实际语音尚待验证。 | [SpeechRecognizer 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/hms-ai-speechrecognizer/) · [语音识别指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/speechrecognizer-guide/) |
| 网络与权限 | INTERNET 是系统授权普通权限，自 9。网络授权与产品媒体上传同意是两个独立条件。 | 本工程无网络、麦克风或广域文件访问权限声明。文件流探测与离线语种查询不访问麦克风。联网转写只有在供应商、数据范围、政策、费用及用户许可均明确后才启用。 | [开放的系统授权权限](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/permissions-for-all/) |

初次直接访问 AVDemuxer 英文参考超时，后续通过官方索引检索取得接口说明，并与本机头文件核对。


## 阶段 02 新增 API

- ArkData 使用 `@kit.ArkData` 的 relationalStore。SDK 26 声明在 `openharmony/ets/api/@ohos.data.relationalStore.d.ts`。RDB 核心 API 起于 9，version 属性起于 10，系统能力 `SystemCapability.DistributedDataManager.RelationalStore.Core`。项目库只在应用沙箱使用，手机模拟器通过实际创建和冷启动读取验证。[RdbStore 参考](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-data-relationalstore-rdbstore/)
- ArkUI 内建 `Navigation`、`NavPathStack`、`NavDestination`。Stage 的 NavPathStack 起于 API 10，pushPath 支持关闭切换动画。二级路由和系统返回经 API 26 手机模拟器验证。[Navigation 参考](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-navigation/)

## 阶段 03 媒体闭环

- `@kit.CoreFileKit` 的 Picker 与 FileIO。SDK 26 的 `@ohos.file.fs.d.ts` 声明 `copyFile`、`lseek`、`read`、`write`、`fsync`、`rename` 和 `unlink`。本地 URI 经只读 FD 复制到沙箱，分析通过后重命名。输出先渲染临时文件，再写入保存面板授权的 URI 并核对字节数。[文件管理参考](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-fs/) · [选择用户文件](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/select-user-file/)
- `media` 来自 `@kit.MediaKit`，对应 `@ohos.multimedia.media.d.ts`。AVPlayer 使用本地 `fdSrc`，依据状态事件调用 prepare 和 play，切换时 release 后关闭 FD。模拟器已验证原音和剪后试听到达完成状态。[AVPlayer 参考](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-media-avplayer/) · [本地音频播放指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/using-avplayer-for-playback/)
## 阶段 05

- Core Speech Kit 文件模式已真机收到普通话草稿。SDK 26 声明约束为 PCM16、16 kHz、单声道，writeAudio 每包 640 或 1280 字节，短语音最多 60 秒。本实现监听实际完成状态，提前结束时提示部分草稿。人工核对与时间绑定继续可用。[文件语音指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/speechrecognizer-guide/)
- SRT 与 WebVTT 共用剪后时间验证，FileIO 保存到系统授权 URI。WebVTT 实际文件已核对 UTF-8 和时码。[集成报告](INTEGRATION_REPORT.md)
