# 声剪 VoxCarve

HarmonyOS 7 · API 26 · 原生 Stage 工程。创建本地项目后，可导入单声道或双声道 16 位 PCM WAV，以及设备可解码的 MP3 和 AAC 音轨，拖选波形或输入时间码，试听原音和剪后结果，导出 WAV。

- [构建、安装及设备](docs/dev/ENVIRONMENT.md)
- [阶段 02 验证](docs/dev/TEST_REPORT.md)
- [阶段 03 音频流程与两套输出证据](docs/dev/CORE_WORKFLOW.md)
- [阶段 04 十页走查与验收](docs/dev/PAGE_WALKTHROUGH.md)
- [阶段 05 媒体与字幕集成](docs/dev/INTEGRATION_REPORT.md)
- [领域架构](docs/dev/ARCHITECTURE.md) · [UI 组件](docs/dev/UI_COMPONENTS.md) · [导航](docs/dev/NAVIGATION.md)
- [SDK 声明与官方 API 审计](docs/dev/API_AUDIT.md)
- [功能矩阵](docs/dev/IMPLEMENTATION_MATRIX.md) · [风险及测试样本](docs/dev/RISKS.md)

- [阶段 06 验收](docs/dev/ACCEPTANCE_REPORT.md) · [发布就绪](docs/dev/RELEASE_READINESS.md)
- [阶段 08 压缩音频导入与外部播放复验](docs/dev/COMPRESSED_IMPORT_QA.md)
- [剪辑台交互设计稿](docs/design/timeline-preview.html)
- 真机复验使用 API 26 MIA-AL00。配置本机 DevEco 签名后，按环境文档构建，选 uildMode=release 生成签名包，并用 hdc install -r 安装对应 HAP。
