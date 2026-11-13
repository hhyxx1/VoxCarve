import { LengthMetrics } from '@kit.ArkUI';
import { RenderTask, TaskStatus } from '../domain/RenderTask';
import { AppAccent, XuzuoTheme } from './XuzuoTheme';

export interface XuzuoChoice {
  readonly id: string;
  readonly label: string;
}

@Component
export struct ActionButton {
  @Prop label: string;
  @Prop variant: string = 'secondary';
  @Prop available: boolean = true;
  @Prop pending: boolean = false;
  action: () => void = () => {};

  build() {
    Button(this.pending ? '处理中…' : this.label, { type: ButtonType.Normal, stateEffect: true })
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.variant === 'primary' ? AppAccent.onPrimary :
        this.variant === 'danger' ? XuzuoTheme.danger : XuzuoTheme.textPrimary)
      .backgroundColor(this.variant === 'primary' ? AppAccent.primary :
        this.variant === 'quiet' ? Color.Transparent : XuzuoTheme.surface)
      .border({ width: this.variant === 'quiet' || this.variant === 'primary' ? 0 : 1, color: XuzuoTheme.outline })
      .borderRadius(8)
      .constraintSize({ minHeight: XuzuoTheme.controlMin })
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .enabled(this.available && !this.pending)
      .accessibilityText(this.pending ? this.label + '，处理中' : this.label)
      .onClick(() => this.action())
  }
}

@Component
export struct TextFieldRow {
  @Prop label: string;
  @Prop fieldValue: string;
  @Prop issue: string = '';
  @Prop limit: number = 60;
  update: (text: string) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.label).fontSize(14).fontColor(XuzuoTheme.textPrimary)
      TextInput({ text: this.fieldValue })
        .maxLength(this.limit)
        .fontColor(XuzuoTheme.textPrimary)
        .backgroundColor(XuzuoTheme.surface)
        .border({ width: 1, color: XuzuoTheme.outline })
        .borderRadius(8)
        .constraintSize({ minHeight: XuzuoTheme.controlMin })
        .accessibilityText(this.label)
        .onChange((text: string) => this.update(text))
      if (this.issue) {
        Text(this.issue).fontSize(13).fontColor(XuzuoTheme.danger)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct SegmentedControl {
  @Prop options: XuzuoChoice[] = [];
  @Prop selectedId: string = '';
  @Prop available: boolean = true;
  select: (id: string) => void = () => {};

  build() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(4), cross: LengthMetrics.vp(4) } }) {
      ForEach(this.options, (option: XuzuoChoice) => {
        Button(option.label, { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor(option.id === this.selectedId ? AppAccent.onPrimary : XuzuoTheme.textPrimary)
          .backgroundColor(option.id === this.selectedId ? AppAccent.primary : XuzuoTheme.surface)
          .constraintSize({ minHeight: XuzuoTheme.controlMin })
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .enabled(this.available)
          .accessibilityText(option.id === this.selectedId ? option.label + '，已选中' : option.label)
          .onClick(() => this.select(option.id))
      }, (option: XuzuoChoice): string => option.id)
    }
    .width('100%')
  }
}

@Component
export struct DataRow {
  @Prop title: string;
  @Prop detail: string = '';
  action: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
        if (this.detail) {
          Text(this.detail).fontSize(14).fontColor(XuzuoTheme.textSecondary)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, bottom: 12 })
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .constraintSize({ minHeight: XuzuoTheme.controlMin })
    .borderRadius(8)
    .backgroundColor(XuzuoTheme.surface)
    .accessibilityText(this.detail ? this.title + '，' + this.detail : this.title)
    .onClick(() => this.action())
  }
}

@Component
export struct StatusChip {
  @Prop label: string;
  @Prop tone: string = 'neutral';

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor(this.tone === 'error' ? XuzuoTheme.danger :
        this.tone === 'success' ? XuzuoTheme.success :
          this.tone === 'warning' ? AppAccent.primaryText : XuzuoTheme.textPrimary)
      .padding({ top: 6, bottom: 6, left: 10, right: 10 })
      .backgroundColor(XuzuoTheme.elevated)
      .borderRadius(8)
  }
}

@Component
export struct EmptyPanel {
  @Prop title: string;
  @Prop detail: string;
  @Prop actionLabel: string = '';
  action: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(this.title).fontSize(20).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
      Text(this.detail).fontSize(15).fontColor(XuzuoTheme.textSecondary)
      if (this.actionLabel) {
        ActionButton({ label: this.actionLabel, variant: 'primary', action: () => this.action() })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(20)
    .backgroundColor(XuzuoTheme.surface)
    .borderRadius(12)
  }
}

@Component
export struct ErrorPanel {
  @Prop message: string;
  @Prop actionLabel: string = '重试';
  action: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(this.message).fontSize(15).fontColor(XuzuoTheme.textPrimary)
        .accessibilityText('操作失败。' + this.message)
      if (this.actionLabel) {
        ActionButton({ label: this.actionLabel, action: () => this.action() })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(20)
    .backgroundColor(XuzuoTheme.surface)
    .borderRadius(12)
  }
}

@Component
export struct PermissionGate {
  @Prop reason: string;
  @Prop actionLabel: string;
  action: () => void = () => {};

  build() {
    EmptyPanel({ title: '需要授权', detail: this.reason, actionLabel: this.actionLabel,
      action: () => this.action() })
  }
}

@Component
export struct TaskProgress {
  @Prop label: string;
  @Prop fraction: number = -1;
  @Prop canCancel: boolean = false;
  @Prop renderTask?: RenderTask = undefined;
  cancel: () => void = () => {};

  private visibleFraction(): number {
    return this.renderTask?.progress ?? this.fraction;
  }

  private cancelAvailable(): boolean {
    const task = this.renderTask;
    return this.canCancel && (!task || task.status === TaskStatus.Queued || task.status === TaskStatus.Running ||
      task.status === TaskStatus.Verifying);
  }

  build() {
    Column({ space: 8 }) {
      if (this.visibleFraction() < 0) {
        LoadingProgress().width(24).height(24).color(AppAccent.primaryText)
      } else {
        Progress({ value: this.visibleFraction() * 100, total: 100 }).color(AppAccent.primaryText)
      }
      Text(this.label).fontSize(15).fontColor(XuzuoTheme.textPrimary)
      if (this.cancelAvailable()) {
        ActionButton({ label: '取消', action: () => this.cancel() })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .accessibilityText(this.label)
  }
}

export function showConfirmDialog(ui: UIContext, title: string, message: string,
  confirmLabel: string, confirm: () => void): void {
  ui.showAlertDialog({
    title: title,
    message: message,
    autoCancel: false,
    primaryButton: { value: '取消', action: () => {} },
    secondaryButton: { value: confirmLabel, fontColor: XuzuoTheme.danger, action: confirm }
  });
}
