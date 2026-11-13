# 阶段 05 · 媒体与字幕集成

## 验证范围

| 功能 | 结果 | 证据与恢复路径 |
| --- | --- | --- |
| F03/F04 普通话离线草稿 | DEVICE_CONDITIONAL | MIA-AL00、HarmonyOS 7.0.0.109、API 26，合成的 16 kHz 单声道 PCM WAV，6.410 秒。设备返回「你好欢迎使用声检。」后提前完成。应用提示部分草稿，保留人工校对及填写时间入口。设备能力不足、格式不匹配或识别失败时可手工录入。 |
| F07 停顿复核 | PASS_HOST + PASS_DEVICE（默认门限） | 每 20 ms 计算各声道 RMS，所有声道达到门限才纳入候选。门限可调，默认 −45 dBFS。默认门限真机检出 500–1000 ms，进入剪辑台后由用户决定是否剪掉。 |
| F08 SRT / WebVTT | PASS_HOST + PASS_EMULATOR | 同一套校验拒绝重叠、超界和舍入后零时长。WebVTT 额外转义纯文本。实际导出 55 字节，剪后时码 00:00:00.500 至 00:00:01.000，SHA-256 为 `49346ce1f36428e6d485b59e2ca50d989ded1b4f6e26fb6c066b0af47617b1d7`。[样本](exports/stage05-sample.vtt) |
| F09/F10 试听与 WAV | PASS_DEVICE（阶段 04 基线） | 保留 PCM WAV 作为经过真机和外部复验的输出路径。[真机记录](PAGE_WALKTHROUGH.md) |
| F11/F12 压缩编码和视频 | NOT_RUN（完整数据链） | 阶段 01 仅验证模拟器能创建 AAC、MP3 编解码器和 MP4 封装器。SDK 有 MP3 原生编码及封装接口，尚缺实际编码到 EOS 和外部播放的证据。MP4 还需要视频轨、关键帧、重编码和 A/V 同步验证。导出页明确提供 WAV，压缩媒体和视频导入仍未接入。 |
| F13 运行中取消 | PASS_HOST（扫描中断）+ PASS_DEVICE（离线识别取消与重试） | 扫描和独立导出页的本地 WAV 渲染在块边界检查取消。取消时丢弃扫描结果，关闭 FD，移除渲染临时文件，且不会打开保存面板。WAV 渲染运行中取消尚无设备记录。已经进入系统保存面板时由系统处理取消。目标 URI 写入阶段没有应用内取消，持久任务队列和中断后续跑待实现。 |

Core Speech Kit 使用本机 SDK 的 `@hms.ai.speechRecognizer.d.ts`，`createEngine` 指定 `zh-CN`、离线模式，`startListening` 后以每包 640 字节传入 PCM。仅使用导入的文件音频，应用没有联网或麦克风权限声明。公开结果只有 isFinal、isLast 和文本。识别时间、字级对齐及准确率均未推定。手工绑定源区间后可沿用现有波形试听和剪后字幕映射。[华为语音识别指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/speechrecognizer-guide/) · [SpeechRecognizer 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/hms-ai-speechrecognizer/)

[WebVTT 规范](https://www.w3.org/TR/webvtt1/) · [华为封装格式](https://developer.huawei.com/consumer/en/doc/harmonyos-references/capi-native-avcodec-base-h/) · [自动化测试](STAGE05_DOMAIN_LOG.txt) · [签名构建和运行记录](STAGE05_DEVICE_LOG.txt)
