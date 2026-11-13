# 声剪阶段 08 · 压缩音频导入

2026-11-13 在 MIA-AL00（HarmonyOS 7.0.0.109，API 26）通过系统文件选择器导入 MP3 和 AAC/M4A 测试素材。两次均从解码后的 PCM 绘制波形，在波形上拖选并保留区间，触发剪后试听，再通过系统保存面板导出 WAV。应用重启后，AAC 项目恢复到已保存的剪后时长。此前的 PCM WAV 项目仍可打开。

| 输入 | 解码帧数（48 kHz 双声道） | 波形选区（毫秒） | 导出帧数 | Chrome 播放结束时长 |
| --- | ---: | --- | ---: | ---: |
| [MP3](exports/compressed/VoxCarve-QA-MP3.mp3) | 97920 | 509.063–1010.646 | 24076 | 0.501583 秒 |
| [AAC/M4A](exports/compressed/VoxCarve-QA-AAC.m4a) | 97280 | 505.729–1004.042 | 23919 | 0.498313 秒 |

- Python `wave` 核对 WAV 格式、帧数及采样。MP3 导出与解码素材的半开帧区间 [24435, 48511) 逐字节一致，AAC 与 [24275, 48194) 逐字节一致。导出峰值分别为 10162 和 10727（有符号 16 位整数采样的绝对值）。
- Chrome 158.0.8127.37 的 HTMLAudioElement 播放两份导出文件，均到达 `ended`，结束位置与报告时长相同。
- 测试素材来自工程内的合成 `stereo-48k.wav`。用 FFmpeg 9.0.2 分别执行 `-c:a libmp3lame -b:a 192k` 和 `-c:a aac -b:a 160k` 可复现输入。真机导入和剪辑后，系统下载目录的源文件 SHA-256 与传入前一致。伪装成 MP3 的 28 字节文本触发解码错误，项目仍显示暂无音轨，沙箱无该项目素材及残留暂存文件。
- Node 测试 15 项通过。DevEco Release 模式 HAP 在真机安装成功。SDK 签名工具验证通过，内嵌 profile 类型为 debug，用于设备 QA。

| 文件 | SHA-256 |
| --- | --- |
| MP3 输入 | `c5aa0eb542e6bac3a731e9266f98ee7951c9733685abe40ac1e7a118c6c24532` |
| AAC/M4A 输入 | `50623a754ae918fda33dfe70553ae382d161427ecca8e550cb8f74c1a205e4e8` |
| [MP3 选区 WAV](exports/compressed/mp3-cut.wav) | `5e7bb5bc136d4973f52eebbc42561514fdd2abbfc325978391761441166fd8bb` |
| [AAC 选区 WAV](exports/compressed/aac-cut.wav) | `aab6bd5f5827fdd33dd12686f5fbdf9a3820c81a1aa3a49df5b27b4b7123a83d` |

## 实现范围

系统授权 URI 以只读方式打开。导入先复制到沙箱，压缩轨在后台解码为 16 位 PCM。校验声道、采样率、缓冲区边界与 PCM 的 PTS 顺序后，再将验证通过的 WAV 发布为项目素材。压缩副本是暂存文件，发布后清理。支持单音轨 MP3 和 AAC，输出为单声道或双声道。

编辑时间轴从第一帧解码 PCM 开始。FFmpeg 独立解码两个样本均得到 96000 帧，设备解码分别得到 97920 和 97280 帧，包含可测的编码延迟及尾部填充。当前保留设备实际输出的帧，容器间的无缝裁边和压缩轨长文件尚待专项验证。视频、MP3/MP4 输出和解码中主动取消仍待实现。

[同步音频解码](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/synchronous-audio-decoding/) · [官方格式矩阵](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avcodec-support-formats/)
