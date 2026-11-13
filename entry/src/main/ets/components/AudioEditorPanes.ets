import type { TranscriptSegment } from '../domain/MediaModels';
import { frameToTimeUs } from '../domain/EditGraph';
import type { PcmPeak } from '../domain/PcmWav';
import { EmptyPanel, DataRow } from './XuzuoControls';
import { XuzuoTheme } from './XuzuoTheme';

function timecode(timeUs: number): string {
  const totalMs = Math.floor(timeUs / 1000);
  const hours = Math.floor(totalMs / 3600000).toString().padStart(2, '0');
  const minutes = (Math.floor(totalMs / 60000) % 60).toString().padStart(2, '0');
  const seconds = (Math.floor(totalMs / 1000) % 60).toString().padStart(2, '0');
  const milliseconds = (totalMs % 1000).toString().padStart(3, '0');
  return hours + ':' + minutes + ':' + seconds + '.' + milliseconds;
}

@Component
export struct WaveformPane {
  @Prop @Watch('paint') peaks: PcmPeak[] = [];
  @Prop pcmFrameCount: number = 0;
  @Prop pcmSampleRate: number = 0;
  @Prop @Watch('paint') rangeStart: number = 0;
  @Prop @Watch('paint') rangeEnd: number = 0;
  select: (start: number, end: number) => void = () => {};
  private dragOrigin: number = 0;
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  private paint(): void {
    const canvas = this.canvasContext;
    const width = canvas.width;
    const height = canvas.height;
    if (this.peaks.length === 0 || width <= 0 || height <= 0) {
      return;
    }
    canvas.clearRect(0, 0, width, height);
    canvas.fillStyle = '#7056B7';
    const step = width / this.peaks.length;
    for (let index = 0; index < this.peaks.length; index++) {
      const peak = this.peaks[index];
      const top = (1 - peak.max) * height / 2;
      const span = (peak.max - peak.min) * height / 2;
      canvas.fillRect(index * step, top, step, Math.max(1, span));
    }
    if (this.pcmFrameCount > 0 && this.rangeEnd > this.rangeStart) {
      canvas.fillStyle = 'rgba(175, 157, 255, 0.35)';
      canvas.fillRect(width * this.rangeStart / this.pcmFrameCount, 0,
        width * (this.rangeEnd - this.rangeStart) / this.pcmFrameCount, height);
    }
  }

  private handleTouch(event: TouchEvent): void {
    const touch = event.changedTouches[0];
    if (!touch || this.canvasContext.width <= 0) {
      return;
    }
    const position = Math.max(0, Math.min(this.pcmFrameCount,
      Math.round(touch.x / this.canvasContext.width * this.pcmFrameCount)));
    if (event.type === TouchType.Down) {
      this.dragOrigin = position;
    } else if (event.type === TouchType.Move || event.type === TouchType.Up) {
      this.select(Math.min(position, this.dragOrigin), Math.max(position, this.dragOrigin));
    }
  }

  build() {
    Column() {
      if (this.peaks.length === 0) {
        EmptyPanel({ title: '暂无音轨', detail: '导入素材后，这里会显示从音频采样生成的波形。' })
      } else {
        Canvas(this.canvasContext)
          .width('100%')
          .height(144)
          .backgroundColor(XuzuoTheme.surface)
          .accessibilityText('音频波形')
          .onReady(() => this.paint())
          .onAreaChange(() => this.paint())
          .onTouch((event: TouchEvent) => this.handleTouch(event))
        if (this.pcmFrameCount > 0 && this.pcmSampleRate > 0) {
          Row() {
            Text('00:00:00.000').fontSize(13).fontColor(XuzuoTheme.textSecondary)
            Text(timecode(frameToTimeUs(this.pcmFrameCount, this.pcmSampleRate)))
              .fontSize(13).fontColor(XuzuoTheme.textSecondary)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
      }
    }
    .width('100%')
  }
}

@Component
export struct TranscriptPane {
  @Prop segments: TranscriptSegment[] = [];
  activate: (segment: TranscriptSegment) => void = () => {};

  private detail(segment: TranscriptSegment): string {
    const parts: string[] = [];
    if (segment.speaker) {
      parts.push(segment.speaker);
    }
    if (segment.sourceStartUs !== undefined && segment.sourceEndUs !== undefined) {
      parts.push(timecode(segment.sourceStartUs) + ' – ' + timecode(segment.sourceEndUs));
    }
    parts.push(segment.verified ? '已核对' : '待校准');
    return parts.join(' · ');
  }

  build() {
    Column({ space: 8 }) {
      if (this.segments.length === 0) {
        EmptyPanel({ title: '暂无文字稿', detail: '文字稿可绑定人工核对的音频区间。' })
      } else {
        ForEach(this.segments, (segment: TranscriptSegment) => {
          DataRow({
            title: segment.text,
            detail: this.detail(segment),
            action: () => this.activate(segment)
          })
        }, (segment: TranscriptSegment): string => segment.id)
      }
    }
    .width('100%')
  }
}
