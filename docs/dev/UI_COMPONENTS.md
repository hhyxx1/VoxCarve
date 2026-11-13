# 声剪 · ArkUI 组件

当前组件合同版本为 0.1。使用本仓 ArkUI 源码和浅色/深色资源限定符。浅色中性底 #F4F1EA，深色中性底 #0B1622，紫藤 #AF9DFF 作为主操作填充，杏色 #FDBF92 保留给后续小面积辅助状态。操作控件最小高度 48vp。

| 组件 | API 与用法 |
| --- | --- |
| XuzuoTheme / AppAccent | 背景、表面、浮层、文字、分隔、危险、成功和强调色。颜色由 base/dark 资源解析。 |
| XuzuoAppBar | title、backAvailable、back。带明确的返回无障碍标签。 |
| NavigationShell | options、selectedId、wide、select。600vp 以下底栏，以上侧栏；可滚动内容限制在 640vp。 |
| ActionButton | label、variant、available、pending、action。原生按压反馈，处理时禁用重复点击。 |
| TextFieldRow / SegmentedControl | 字段标签、输入与校验消息；分段选项在窄宽度下换行，显式朗读选中状态。 |
| DataRow / StatusChip | 可打开的数据行与文本状态。错误和完成状态均有文字。 |
| EmptyPanel / ErrorPanel | 空数据、缺能力和失败时的文案与可选操作。 |
| PermissionGate / TaskProgress | 权限说明和授权回调；不定或定量进度及可选取消回调。权限门禁在后续媒体授权流程接入。 |
| showConfirmDialog | 原生对话框。新建表单离开时保护未保存的输入。 |
| WaveformPane / TranscriptPane | 专有编辑组件，分别接收真实音频峰值和已存文字稿，当前空项目显示空态。 |

外观分段控件支持当次应用会话切换系统、浅色和深色。需要跨重启保存外观时，可在设置功能接入时持久化。
