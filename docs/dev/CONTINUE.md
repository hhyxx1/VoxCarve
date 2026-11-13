# 声剪 · 阶段 07 交接

工程 C:/Project/VoxCarve，分支 codex/sdk26-audit。审查基线 98351f5，阶段 07 提交见本文件所属 Git 提交。独立资料库 xuzuo-assets/main 当前 SHA 2621898445470eee420c5d06af46046d052bd053。候选包名 com.hhyxx.voxcarve。

DevEco Studio 26.0.0.851、HarmonyOS SDK 26.0.0 Release、Hvigor 6.26.8。阶段 07 连接设备 MIA-AL00，HarmonyOS 7.0.0.109，API 26。沿用 ArkUI、Hvigor、CodeLinter 和测试驱动工作流。签名配置和 IDE 本地文件保留在用户工作区。

| 功能 | 实际代码 | 编译 | 设备 | 设计与未实现 |
| --- | --- | --- | --- | --- |
| PCM WAV 导入、波形和裁切 | LocalAudioService、PcmWav、EditGraph、AudioWorkspace | SDK 26 Release | 阶段 06 真机 30 分钟，输出采样独立核对；阶段 07 剪后试听复测 | 16 位单/双声道。压缩音频、视频、缩放/吸附/拆分/合并仍有缺口 |
| PCM 停顿、历史与重启 | ProjectToolPage、ProjectRepository、TemporaryMediaRecovery | SDK 26 Release | 阶段 06 真机取消和编辑恢复；本轮恢复日志见下 | 残留临时文件启动回收。项目删除、持久任务队列、写目标中断专项待完成 |
| 人工时间绑定和离线草稿 | ProjectToolPage、OfflineSpeechService、TimeRange | SDK 26 Release | 阶段 05 真机识别提前结束、取消及重试。SDK 不返回词句时戳 | 可在波形上人工校准，模型与输入仍有条件 |
| SRT / WebVTT 与 WAV | TimeRange、LocalAudioService | SDK 26 Release | 阶段 06 中文 WebVTT 真机回读；WAV 外部验证见验收报告 | MP3/MP4 完整编码、播放和音画同步待完成 |
| 项目、导航、外观和权限 | Index、NavigationShell、XuzuoControls | SDK 26 Release | 真机项目和试听导航，本轮未重跑全部十页 | 逐宽、横屏、辅助技术和录音仍待验证；当前无麦克风与联网权限 |

## 本轮审查与复现

- 临时文件清理仅扫描应用模块的 files 和 cache，匹配导入暂存和渲染文件的精确名称，lstat 确认普通文件后 unlink。入口 UIAbility 在启动首屏前调用，日志只记清理数量。不会扫描外部授权位置。仓库未跟踪签名证书文件。图标许可和 AGC 身份核验仍是发布缺口。
- 离线识别在异步读块后、向引擎送 PCM 前检查取消，完成回调也检查取消。最后一个有效数据包写入成功才记录输入送完。相邻回调取消的竞争条件未做确定性真机注入。
- 使用 `node --test tests/*.test.mjs` 和 [环境文档](ENVIRONMENT.md) 中的 assembleHap 命令，构建参数 `buildMode=release`。CodeLinter 使用 TypeScript、Correctness、Security 推荐规则。真机通过 HDC 安装并启动。
- SDK 26 文件声明可用 `rg -n 'function listFile|function lstat|function unlink' "$env:DEVECO_SDK_HOME/default/openharmony/ets/api/@ohos.file.fs.d.ts"` 核对。2026-11-13 复核官方 FileIO 参考。[华为 FileIO](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-fs/)

## 下一步

1. 以受控样本接通压缩音频的拆封装及 PCM 解码，核对声道、采样率、PTS 和导出字节。
2. 验证 MP3 编码到 EOS 与外部播放。视频路径独立验证关键帧、重编码和音画同步。
3. 完成项目删除、持久任务恢复和无障碍/尺寸矩阵，再复核发布资产及 AGC 身份。

当前仓库无 Git 远端。可用 `git diff 98351f5..HEAD` 审查本轮提交。[验收矩阵](ACCEPTANCE_REPORT.md) · [发布审查](RELEASE_READINESS.md) · [阶段 07 日志](STAGE07_QA_LOG.txt)
