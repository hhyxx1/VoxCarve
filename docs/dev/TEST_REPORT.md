# 阶段 02 · 测试报告

验收日期 2026-11-12。分支 `codex/sdk26-audit`。DevEco Studio 26.0.0.851，SDK 26.0.0 Release，Hvigor 6.26.8。手机 Mate 90 Pro 和平板 MatePad Pro 13 均运行 API 26，系统软件 7.0.0.107。

| 测试 | 结果 | 证据 |
| --- | --- | --- |
| 编译 ArkTS、CMake 和 NAPI，生成未签名 debug HAP | PASS_HOST | [构建日志](STAGE02_BUILD_LOG.txt)；仍有 SDK 异常处理和设备系统能力告警 |
| 重叠删除、保留、撤销重做与分支、快照恢复、44.1 kHz 边界和取消状态 | PASS_HOST | [6 项领域测试](STAGE02_DOMAIN_LOG.txt)，直接执行源码中的纯领域逻辑 |
| 项目空态、创建 RDB 项目、停止应用进程后恢复同一项目 | PASS_EMULATOR | [手机日志](STAGE02_DEVICE_LOG.txt)，合成名称 Stage02-Verification |
| 十个业务入口、系统返回、取消放弃项目名后保留表单内容 | PASS_EMULATOR | [手机日志](STAGE02_DEVICE_LOG.txt) |
| 手机深浅主题，切回跟随系统 | PASS_EMULATOR | 工作区 .artifacts/stage02 下的 phone-settings-dark.png 和 phone-settings-light.png，页面底色抽样随外观变化 |
| 平板侧栏与正文顶部对齐，切换剪辑台 | PASS_EMULATOR | [平板日志](STAGE02_TABLET_LOG.txt)，截图 tablet-sidebar-final.png |
| 主文字、次文字、CTA、已选导航和错误文案的 token 对比度 | PASS_HOST | [对比度计算](STAGE02_CONTRAST_LOG.txt)，所测组合最小 5.53:1 |
| 独立 360/390/430vp 逐宽预览、屏幕阅读器、应用主动权限拒绝、数据库失败注入、真机 | NOT_RUN | 已检查手机默认尺寸和平板宽屏。阶段 02 应用流程没有主动发起权限请求。 |
| 真实素材导入、波形、试听、剪辑、输出文件和外部复核 | NOT_RUN | 阶段 03 起执行。已有的 SDK 探测保留在设置。 |

阶段 03 的两套实际导出、播放、重启及异常验收见 [CORE_WORKFLOW.md](CORE_WORKFLOW.md)。阶段 02 的独立大字体检查测得 Normal 标题 115 px、Extra large 标题 149 px。最高档触发系统提示，未完成该档交互验收。[字号记录](STAGE02_FONT_LOG.txt)

## 复现

以 [环境文档](ENVIRONMENT.md) 的命令构建并安装。双模拟器同时连接时，用 `hdc -t 127.0.0.1:5555` 指向手机，`hdc -t 127.0.0.1:5557` 指向平板。先在项目页创建草稿，再强停并重启。进入剪辑台打开子页，使用系统返回。到设置切换主题并复测。

```powershell
$ide = 'C:\Program Files\Huawei\DevEco Studio'
& "$ide/tools/node/node.exe" --test tests/domain.test.mjs
```

## 阶段 02 源码与资料

- 新增 `domain/{MediaModels,EditGraph,RenderTask}.ets`、`repository/ProjectRepository.ets`、`viewmodel/WorkspaceState.ets`。
- 新增 `components/{XuzuoTheme,XuzuoControls,NavigationShell,AudioEditorPanes}.ets`、`pages/SdkProbePanel.ets`。更新 `pages/Index.ets` 的工作区导航和项目流程。
- 更新 `AppScope/app.json5`，新增 `AppScope/resources/base/profile/configuration.json`。更新 `entry/src/main/resources/{base,dark}/element/color.json`。
- 新增 `tests/domain.test.mjs`、本报告、阶段 02 日志、架构、组件及导航文档。更新 README、CURRENT_STATE、API_AUDIT 和 IMPLEMENTATION_MATRIX。
