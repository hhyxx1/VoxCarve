import { AppAccent, XuzuoTheme } from './XuzuoTheme';
import type { XuzuoChoice } from './XuzuoControls';

@Component
export struct XuzuoAppBar {
  @Prop title: string;
  @Prop backAvailable: boolean = false;
  back: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      if (this.backAvailable) {
        Button('返回', { type: ButtonType.Normal })
          .constraintSize({ minHeight: XuzuoTheme.controlMin, minWidth: XuzuoTheme.controlMin })
          .padding({ left: 10, right: 10 })
          .fontSize(14)
          .fontColor(AppAccent.primaryText)
          .backgroundColor(Color.Transparent)
          .accessibilityText('返回上一页')
          .onClick(() => this.back())
      }
      Text(this.title).fontSize(20).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
        .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 20, right: 20, top: 4, bottom: 4 })
    .justifyContent(FlexAlign.Start)
  }
}

@Component
export struct NavigationShell {
  @Prop options: XuzuoChoice[];
  @Prop selectedId: string;
  @Prop wide: boolean = false;
  select: (id: string) => void = () => {};

  @Builder
  tab(option: XuzuoChoice) {
    Button(option.label, { type: ButtonType.Normal })
      .layoutWeight(this.wide ? 0 : 1)
      .width(this.wide ? '100%' : undefined)
      .constraintSize({ minHeight: XuzuoTheme.controlMin })
      .padding({ top: 8, bottom: 8, left: 8, right: 8 })
      .fontSize(15)
      .fontWeight(option.id === this.selectedId ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(option.id === this.selectedId ? AppAccent.primaryText : XuzuoTheme.textSecondary)
      .backgroundColor(option.id === this.selectedId ? XuzuoTheme.elevated : XuzuoTheme.surface)
      .borderRadius(8)
      .accessibilityText(option.id === this.selectedId ? option.label + '，当前页' : option.label)
      .onClick(() => this.select(option.id))
  }

  build() {
    if (this.wide) {
      Column({ space: 6 }) {
        ForEach(this.options, (option: XuzuoChoice) => { this.tab(option) }, (option: XuzuoChoice) => option.id)
      }
      .width(164)
      .height('100%')
      .padding(12)
      .backgroundColor(XuzuoTheme.surface)
    } else {
      Row({ space: 4 }) {
        ForEach(this.options, (option: XuzuoChoice) => { this.tab(option) }, (option: XuzuoChoice) => option.id)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(XuzuoTheme.surface)
    }
  }
}
