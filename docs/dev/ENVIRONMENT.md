# 声剪 · SDK 26 工程环境

核验日期 2026-11-12。工作区 C:/Project/VoxCarve。资料库为 xuzuo-assets 的 main，SHA 2621898445470eee420c5d06af46046d052bd053。工程使用本机 DevEco CodeGenie 自带的 Stage 模板，按同一安装中的 New Project 和 Native C++ 模板配置目标 API、模块和 NAPI。模板的预览路由和备份扩展已移除。

| 命令或证据 | 结果 |
| --- | --- |
| `Get-CimInstance Win32_OperatingSystem` | Windows 11 Pro 10.0.26300 |
| DevEco `product-info.json` | DevEco Studio 26.0.0.851 |
| SDK `default/openharmony/ets/oh-uni-package.json` | API 26.0.0 Release，组件 26.0.0.105 |
| 内置 `node.exe -v` / `jbr/bin/java.exe -version` | Node 24.14.1，JBR 25.0.2 |
| 内置 `ohpm.bat -v` / `node hvigorw.js --version` | ohpm 26.0.0.630，Hvigor 6.26.8 |
| `git --version` / `hdc -v` | 2.47.0.windows.1 / 3.2.0f |
| `Emulator.exe -list -details` | Mate 90 Pro 和 MatePad Pro 13 均配置为 API 26.0.0，x86_64 |
| `hdc shell param get const.ohos.apiversion` | 已启动 Mate 90 Pro，API 26，软件版本 7.0.0.107 |
| `hdc list targets` | 仅观察到模拟器 127.0.0.1:5555，真机 NOT_RUN |

在工作区根目录执行。开发工具使用 DevEco 内置版本，以覆盖本机指向已不存在 CLI 目录的 DEVECO_NODE_HOME。

```powershell
$ide = 'C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = "$ide/sdk"
$env:DEVECO_NODE_HOME = "$ide/tools/node"
$env:JAVA_HOME = "$ide/jbr"
& "$ide/tools/ohpm/bin/ohpm.bat" install --all
& "$ide/tools/node/node.exe" "$ide/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.hhyxx.voxcarve
```

[构建日志](BUILD_LOG.txt) · [模拟器 ArkTS 探测](ARKTS_PROBE_LOG.txt) · [模拟器原生媒体探测](NATIVE_PROBE_LOG.txt)

构建目标及兼容 API 均为 26.0.0。调试产物用于模拟器验证。候选 bundle 尚未注册 AGC。

## 探测复现

1. 启动 Mate 90 Pro。锁屏时向上滑动进入系统后执行安装与启动命令。
2. 打开文件选择器并返回，检查取消状态。通过「保存测试样本」保存内置 WAV，检查实际写入 64,044 字节。
3. 点击「初始化 PCM 播放器」和「查询离线转写语种」，核对界面结果。
4. 点击「探测原生媒体接口」，运行内置 WAV 首包读取以及编码器、解码器和封装器初始化。可用 `hdc shell hilog -x -T VoxCarveNative` 取证。
5. [样本主机验证](FIXTURE_LOG.txt)记录输入音频时长、静音段和哈希。模拟器日志时间由设备时钟生成。

构建与上述有限的设备探测为 PASS。构建包含 ArkTS 系统能力和异常处理告警。外部文件成功选择及重新打开、完整压缩音频解码和编码、试听、剪辑输出与真机验证为 NOT_RUN。最初以 shell 进程加载媒体库时遇到模拟器 linker namespace 依赖错误，最终探测通过 HAP 内 NAPI 运行。
