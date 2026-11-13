import type { TranscriptSegment } from '../domain/MediaModels';
import { frameToTimeUs } from '../domain/EditGraph';
import type { PcmPeak } from '../domain/PcmWav';
import { EmptyPanel, DataRow } from './XuzuoControls';
import { XuzuoTheme } from './XuzuoTheme';

export function timecode(timeUs: number): string {
  const totalMs = Math.floor(timeUs / 1000);
  const hours = Math.floor(totalMs / 3600000).toString().padStart(2, '0');
  const minutes = (Math.floor(totalMs / 60000) % 60).toString().padStart(2, '0');
  const seconds = (Math.floor(totalMs / 1000) % 60).toString().padStart(2, '0');
  const milliseconds = (totalMs % 1000).toString().padStart(3, '0');
  return hours + ':' + minutes + ':' + seconds + '.' + milliseconds;
}

@Component
export struct WaveformPane {
  @Prop @Watch('paint') peaks: PcmPeak[][] = [];
  @Prop pcmFrameCount: number = 0;
  @Prop pcmSampleRate: number = 0;
  @Prop @Watch('paint') rangeStart: number = 0;
  @Prop @Watch('paint') rangeEnd: number = 0;
  @Prop @Watch('paint') cursorFrame: number = 0;
  @Prop interactive: boolean = true;
  @Prop snapFrames: number = 1;
  select: (start: number, end: number) => void = () => {};
  seek: (frame: number) => void = () => {};
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
    if (this.pcmFrameCount > 0 && this.rangeEnd > this.rangeStart) {
      canvas.fillStyle = 'rgba(175, 157, 255, 0.35)';
      canvas.fillRect(width * this.rangeStart / this.pcmFrameCount, 0,
        width * (this.rangeEnd - this.rangeStart) / this.pcmFrameCount, height);
    }
    const laneHeight = height / this.peaks.length;
    for (let channel = 0; channel < this.peaks.length; channel++) {
      const lane = this.peaks[channel];
      const top = channel * laneHeight;
      const center = top + laneHeight / 2;
      canvas.fillStyle = '#8B789E';
      canvas.fillRect(0, center, width, 0.5);
      const step = width / lane.length;
      canvas.fillStyle = '#8871CC';
      for (let index = 0; index < lane.length; index++) {
        const peak = lane[index];
        canvas.fillRect(index * step, center - peak.max * laneHeight * 0.48, step,
          Math.max(1, (peak.max - peak.min) * laneHeight * 0.48));
      }
      if (this.peaks.length === 2) {
        canvas.font = '12px sans-serif';
        canvas.fillText(channel === 0 ? '左声道' : '右声道', 8, top + 15);
      }
    }
    if (this.pcmFrameCount > 0 && this.interactive) {
      canvas.fillStyle = '#FDBF92';
      canvas.fillRect(Math.min(width - 2, width * this.cursorFrame / this.pcmFrameCount), 0, 2, height);
    }
  }

  private handleTouch(event: TouchEvent): void {
    const touch = event.changedTouches[0];
    if (!this.interactive || !touch || this.canvasContext.width <= 0) {
      return;
    }
    const frame = touch.x / this.canvasContext.width * this.pcmFrameCount;
    const position = Math.max(0, Math.min(this.pcmFrameCount,
      Math.round(frame / this.snapFrames) * this.snapFrames));
    if (event.type === TouchType.Down) {
      this.dragOrigin = position;
      this.seek(position);
    } else if (event.type === TouchType.Move || event.type === TouchType.Up) {
      if (position !== this.dragOrigin) {
        this.select(Math.min(position, this.dragOrigin), Math.max(position, this.dragOrigin));
      }
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
          .backgroundColor(XuzuoTheme.background)
          .accessibilityText('音频波形，可通过当前选区输入起止时间')
          .onReady(() => this.paint())
          .onAreaChange(() => this.paint())
          .onTouch((event: TouchEvent) => this.handleTouch(event))
        if (this.pcmFrameCount > 0 && this.pcmSampleRate > 0) {
          Row() {
            Text('00:00:00.000').fontSize(12).fontColor(XuzuoTheme.textSecondary)
            Text(timecode(frameToTimeUs(this.pcmFrameCount, this.pcmSampleRate)))
              .fontSize(12).fontColor(XuzuoTheme.textSecondary)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ top: 6 })
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
