# 阶段 03 · 真实音频闭环

2026-11-12，Mate 90 Pro 模拟器，HarmonyOS 7.0.0.107，API 26。使用本机 DevEco Stage HAP 和系统文件选择器。样本是自生成测试音，未使用用户媒体。

## 复现

1. 按 [环境文档](ENVIRONMENT.md) 构建并安装。运行 `python tools/sdk26-probe/generate_fixtures.py` 可重建两套输入。将 WAV 放入模拟器本地下载目录。
2. 在项目页新建项目，点击项目进入剪辑台，点击「选择 WAV 文件」。在系统选择器依次进入 Browse、My phone 和 Download，选择测试样本。
3. 检查实际轨道规格和波形。从波形的 1/4 拖至 1/2，核对起止值 500 / 1000 毫秒。也可直接输入时间。点击「删除选区」，预期源时长 2.000 秒，剪后 1.500 秒。可用撤销和重做切换版本。
4. 点击「试听原音」或「试听剪后」。点击「导出 WAV」，在系统面板保存文件。重启应用并打开同一项目，核对剪后时长。
5. 将实际导出文件取回到本仓 `docs/dev/exports`。用下列命令验证采样和独立播放器。两套导出均保留在该目录。

```powershell
python tools/qa/verify_exports.py
node tools/qa/verify_playback.mjs 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$ide = 'C:\Program Files\Huawei\DevEco Studio'
& "$ide/tools/node/node.exe" --test tests/*.test.mjs
```

## 验收证据

| 测试 | 结果 |
| --- | --- |
| 16 kHz 单声道与 48 kHz 双声道输入，真实波形 | PASS_EMULATOR。原始文件与沙箱副本 SHA-256 一致。 |
| 拖选半秒、非破坏性删除、撤销重做、重启 | PASS_EMULATOR。两套项目恢复为 1.500 秒剪后时长。 |
| 应用内原音及剪后试听 | PASS_EMULATOR。AVPlayer 到达播放完成。 |
| 取消导出 | PASS_EMULATOR。未出现目标 WAV。 |
| 损坏或不支持的 WAV | 设备拒绝非 RIFF 样本，未发布沙箱素材。主机用例覆盖截断数据及非 PCM 编码。 |
| 外部 PCM 核对与播放 | PASS_HOST。逐字节匹配原始区间 [0, 0.5) 和 [1.0, 2.0)。Chrome HTMLAudioElement 播放到 ended，时长和结束位置均为 1.500 秒。Windows Media Player COM 一直在转换状态，外部验收改用 Chrome。 |

| 实际导出 | 音轨与大小 | SHA-256 |
| --- | --- | --- |
| [mono-cut.wav](exports/mono-cut.wav) | 16 kHz 单声道，24,000 帧，48,044 字节 | 231a9adc6f11dfc64c93d458a3434dc6647c27d07b55a81d7c199e9e687019cd |
| [stereo-cut.wav](exports/stereo-cut.wav) | 48 kHz 双声道，72,000 帧，288,044 字节 | 299e06022d31c9740d1c90b0a8f18f16efcd74f5c3255d60fa127b8f63c0829d |

[构建](STAGE03_BUILD_LOG.txt) · [领域与 WAV 测试](STAGE03_DOMAIN_LOG.txt) · [模拟器](STAGE03_DEVICE_LOG.txt) · [导出 PCM 与哈希](STAGE03_EXPORT_LOG.txt) · [外部播放](STAGE03_PLAYER_LOG.txt)

## 当前范围

当前导入接受 RIFF/WAVE 内的 16 位线性 PCM，单声道或双声道。采样按块读取并按实际帧生成波形。编辑图在 RDB 中保存，原始素材以只读方式打开。当前仅支持单项目单音轨，压缩音频与视频、字稿联动、完整任务取消、长音频专项及真机验收仍待完成。外部播放器通过程序观察播放事件，未做人工听感评估。
