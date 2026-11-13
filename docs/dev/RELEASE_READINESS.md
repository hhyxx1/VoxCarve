# 声剪阶段 06 · 发布就绪审查

当前可交付为 API 26 设备测试包。商店发布门槛尚未满足。

- 本地候选包名 com.hhyxx.voxcarve，versionName 1.0.0、versionCode 1000000。AGC 注册记录和版本策略尚未核定。
- 阶段 08 的 Release 模式 HAP 已在 MIA-AL00 安装运行。签名校验通过，内嵌 profile 类型为 debug。商店分发证书与正式发行流程尚未核定。
- MP3 和 AAC/M4A 音轨导入已在真机通过。MP3/MP4 导出、视频与音画同步、录音、持久任务队列、工程删除、资产和缓存清理、无障碍与兼容性矩阵仍有缺口。[阶段 08 真机证据](COMPRESSED_IMPORT_QA.md)
- 商店上架、账号登录、AGC 注册、公开仓库和隐私政策发布需要用户明确授权。此次执行本地 QA。

[验收矩阵](ACCEPTANCE_REPORT.md) · [安全复核](SECURITY_REVIEW.md) · [测试环境和构建命令](ENVIRONMENT.md)
