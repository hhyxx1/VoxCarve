import { common } from '@kit.AbilityKit';
import type { MediaProject, RenderSegment, RenderSequence } from '../domain/MediaModels';
import { EditGraph, frameToTimeUs, timeUsToFrame } from '../domain/EditGraph';
import type { ProjectRepository } from '../repository/ProjectRepository';
import { LocalAudioService, OpenAudio } from '../services/LocalAudioService';
import { ActionButton, ErrorPanel, StatusChip, TaskProgress, TextFieldRow } from './XuzuoControls';
import { timecode, WaveformPane } from './AudioEditorPanes';
import { AppAccent, XuzuoTheme } from './XuzuoTheme';
import type { TimeRange } from '../domain/TimeRange';
import type { PcmPeak } from '../domain/PcmWav';

@Component
export struct AudioWorkspace {
  @Prop project?: MediaProject = undefined;
  @Prop importOnly: boolean = false;
  @Prop initialRange?: TimeRange = undefined;
  repository?: ProjectRepository;
  imported: () => void = () => {};
  openTranscript: (range?: TimeRange) => void = () => {};
  @State private audio?: OpenAudio = undefined;
  @State private graph?: EditGraph = undefined;
  @State private startText: string = '0';
  @State private endText: string = '0';
  @State private selectionStart: number = 0;
  @State private selectionEnd: number = 0;
  @State private cursorFrame: number = 0;
  @State private fadeText: string = '0';
  @State private snap: boolean = true;
  @State private canCancelRender: boolean = false;
  @State private renderCancelled: boolean = false;
  @State private segments: RenderSegment[] = [];
  @State private outputFrames: number = 0;
  @State private viewStart: number = 0;
  @State private viewEnd: number = 0;
  @State private viewPeaks: PcmPeak[][] = [];
  @State private loadingWindow: boolean = false;
  private windowRequest: number = 0;
  @State private taskLabel: string = '';
  @State private feedback: string = '';
  @State private issue: string = '';
  private service?: LocalAudioService;
  private mounted: boolean = false;
  private renderPath?: string;

  aboutToAppear(): void {
    this.mounted = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.service = new LocalAudioService(context);
    this.restore();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.windowRequest++;
    if (!this.taskLabel) {
      this.stopPlayback();
    }
  }

  private async restore(): Promise<void> {
    if (!this.project || !this.service || !this.repository) {
      return;
    }
    this.taskLabel = '读取本地音轨';
    this.issue = '';
    try {
      const source = await this.service.openProject(this.project.id);
      if (source) {
        const saved = await this.repository.loadEdits(this.project.id);
        if (saved && (saved.sampleRate !== source.track.sampleRate ||
          saved.sourceFrameCount !== source.track.frameCount)) {
          throw new Error('EDIT_SOURCE_MISMATCH');
        }
        this.setAudio(source, saved);
      }
    } catch (_) {
      this.issue = '无法读取项目音轨或编辑记录。';
    } finally {
      this.taskLabel = '';
    }
  }

  private setAudio(source: OpenAudio, saved?: EditGraph): void {
    this.audio = source;
    this.setGraph(saved ?? new EditGraph(source.track.sampleRate, source.track.frameCount));
    this.viewStart = 0;
    this.viewEnd = source.track.frameCount;
    this.viewPeaks = source.peaks;
    const range = this.initialRange;
    const rate = source.track.sampleRate;
    this.updateSelection(range ? Math.min(source.track.frameCount, timeUsToFrame(range.startUs, rate)) : 0,
      range ? Math.min(source.track.frameCount, timeUsToFrame(range.endUs, rate)) : source.track.frameCount);
  }

  private async loadWindow(start: number, size: number): Promise<void> {
    const audio = this.audio;
    const id = this.project?.id;
    const service = this.service;
    if (!audio || id === undefined || !service) {
      return;
    }
    const total = audio.track.frameCount;
    const left = Math.max(0, Math.min(start, total - size));
    const request = ++this.windowRequest;
    this.loadingWindow = true;
    try {
      const peaks = size === total ? audio.peaks : await service.waveformWindow(id, audio.track, left, left + size);
      if (this.mounted && request === this.windowRequest) {
        this.viewStart = left;
        this.viewEnd = left + size;
        this.viewPeaks = peaks;
      }
    } catch (_) {
      if (this.mounted && request === this.windowRequest) {
        this.issue = '无法读取这段波形，请重试。';
      }
    } finally {
      if (request === this.windowRequest) {
        this.loadingWindow = false;
      }
    }
  }

  private zoom(factor: number): void {
    const track = this.audio?.track;
    if (track) {
      const size = Math.min(track.frameCount,
        Math.max(Math.ceil(track.sampleRate / 20), Math.round((this.viewEnd - this.viewStart) * factor)));
      const center = this.cursorFrame >= this.viewStart && this.cursorFrame < this.viewEnd ?
        this.cursorFrame : Math.round((this.viewStart + this.viewEnd) / 2);
      this.loadWindow(center - Math.floor(size / 2), size);
    }
  }

  private goToTranscript(): void {
    try {
      this.openTranscript(this.graph ? this.selection(this.graph) : undefined);
    } catch (_) {
      this.issue = '请先输入有效选区，再定位文字稿。';
    }
  }

  private async choose(): Promise<void> {
    if (!this.project || !this.service || this.taskLabel || this.audio) {
      return;
    }
    this.taskLabel = '等待选择或分析音频';
    this.feedback = '';
    this.issue = '';
    try {
      const source = await this.service.choose(this.project.id);
      if (source) {
        this.setAudio(source);
        this.feedback = '音轨已导入';
        this.imported();
      }
    } catch (error) {
      const message = (error as Error).message;
      this.issue = message === 'AUDIO_DECODE_2' ? '此轨道或设备不支持解码。可选择单声道或双声道 16 位 PCM WAV。' :
        message.startsWith('AUDIO_DECODE_') ? '音频解码失败（' + message + '），请检查文件或选择 PCM WAV。' :
          '无法导入此文件，请检查文件是否完整并重试。';
    } finally {
      this.taskLabel = '';
    }
  }

  private updateSelection(start: number, end: number): void {
    const rate = this.audio?.track.sampleRate ?? 0;
    if (rate <= 0) {
      return;
    }
    this.selectionStart = start;
    this.selectionEnd = end;
    this.cursorFrame = start;
    this.startText = (frameToTimeUs(start, rate) / 1000000).toString();
    this.endText = (frameToTimeUs(end, rate) / 1000000).toString();
  }

  private setGraph(graph: EditGraph): void {
    this.graph = graph;
    const sequence = graph.render('audio');
    this.segments = sequence.segments.slice();
    this.outputFrames = sequence.totalFrames;
    this.fadeText = (frameToTimeUs(graph.fadeInFrames(), graph.sampleRate) / 1000000).toString();
  }

  private secondsToFrame(text: string, graph: EditGraph): number {
    if (!/^\d+(\.\d{1,6})?$/.test(text.trim())) {
      throw new RangeError('INVALID_TIME_RANGE');
    }
    const micros = Math.round(Number(text) * 1000000);
    if (!Number.isSafeInteger(micros) || micros > frameToTimeUs(graph.sourceFrameCount, graph.sampleRate)) {
      throw new RangeError('INVALID_TIME_RANGE');
    }
    return timeUsToFrame(micros, graph.sampleRate);
  }

  private selection(graph: EditGraph): TimeRange {
    const start = this.secondsToFrame(this.startText, graph);
    const end = this.secondsToFrame(this.endText, graph);
    if (start >= end) {
      throw new RangeError('INVALID_TIME_RANGE');
    }
    return { startUs: frameToTimeUs(start, graph.sampleRate), endUs: frameToTimeUs(end, graph.sampleRate) };
  }

  private async edit(mode: string): Promise<void> {
    if (!this.project || !this.graph || !this.repository || this.taskLabel) {
      return;
    }
    const graph = this.graph;
    this.issue = '';
    this.feedback = '';
    let next = graph;
    try {
      const now = Date.now();
      const id = now.toString() + '-' + graph.snapshot().cursor;
      if (mode === 'undo') {
        next = graph.undo();
      } else if (mode === 'redo') {
        next = graph.redo();
      } else if (mode === 'split') {
        next = graph.split(id, this.cursorFrame, now);
      } else if (mode === 'fade') {
        const frames = this.secondsToFrame(this.fadeText, graph);
        if (frames > this.outputFrames) {
          throw new RangeError('INVALID_FADE');
        }
        if (frames === graph.fadeInFrames()) {
          return;
        }
        next = graph.fadeIn(id, frames, now);
      } else {
        const range = this.selection(graph);
        const start = timeUsToFrame(range.startUs, graph.sampleRate);
        const end = timeUsToFrame(range.endUs, graph.sampleRate);
        next = mode === 'retain' ? graph.retain(id, start, end, now) : graph.remove(id, start, end, now);
        if (next.render('audio').totalFrames === 0) {
          this.issue = '此操作会移除全部音频，请调整选区。';
          return;
        }
        this.updateSelection(start, end);
      }
    } catch (_) {
      this.issue = mode === 'split' ? '请将播放头放在保留片段内部。' :
        mode === 'fade' ? '淡入时间须介于 0 和剪后时长之间。' : '请输入音轨范围内的有效起止时间，结束必须晚于开始。';
      return;
    }
    this.taskLabel = '保存编辑记录';
    try {
      await this.repository.saveEdits(this.project.id, next);
      this.setGraph(next);
      this.feedback = '编辑记录已保存';
    } catch (_) {
      this.issue = '编辑记录未保存，请重试。';
    } finally {
      this.taskLabel = '';
    }
  }

  private async stopPlayback(): Promise<void> {
    if (this.service) {
      try {
        await this.service.stop();
        if (this.renderPath) {
          await this.service.removeTemporary(this.renderPath);
          this.renderPath = undefined;
        }
      } catch (_) {
        if (this.mounted) {
          this.issue = '无法释放试听资源。';
        }
      }
    }
  }

  private async output(mode: string): Promise<void> {
    if (!this.project || !this.audio || !this.graph || !this.service || this.taskLabel) {
      return;
    }
    this.issue = '';
    this.feedback = '';
    this.taskLabel = mode === 'source' ? '准备试听' : '渲染音频';
    let temporary: string | undefined;
    let playbackSequence: RenderSequence | undefined;
    try {
      await this.stopPlayback();
      if (mode !== 'source') {
        let graph = this.graph;
        if (mode === 'selection') {
          const range = this.selection(graph);
          graph = new EditGraph(graph.sampleRate, graph.sourceFrameCount).retain('preview',
            timeUsToFrame(range.startUs, graph.sampleRate), timeUsToFrame(range.endUs, graph.sampleRate), Date.now());
        }
        playbackSequence = graph.render('audio');
        this.canCancelRender = true;
        temporary = await this.service.render(this.project.id, this.audio.track, graph, () => {
          if (this.renderCancelled || !this.mounted) {
            throw new Error('TASK_CANCELLED');
          }
        });
        this.canCancelRender = false;
      }
      if (mode === 'save' && temporary) {
        const bytes = await this.service.save(temporary, this.project.id);
        if (bytes !== undefined) {
          this.feedback = '已导出 WAV · ' + bytes + ' 字节';
        }
      } else if (this.mounted) {
        this.renderPath = temporary;
        await this.service.play(temporary ?? this.service.assetPath(this.project.id), (status: string) => {
          if (this.mounted) {
            this.feedback = status;
          }
        }, (milliseconds: number) => {
          if (this.mounted) {
            this.updatePlayhead(milliseconds, playbackSequence);
          }
        });
        if (!this.mounted) {
          await this.stopPlayback();
        }
      }
    } catch (error) {
      const code = (error as Error).message;
      if (code === 'TASK_CANCELLED') {
        this.feedback = '任务已取消';
      } else {
        this.issue = code === 'EMPTY_RENDER' ? '当前没有可输出的音频帧，请先撤销或调整剪切。' :
        code === 'INVALID_TIME_RANGE' || code === 'INVALID_EDIT_RANGE' ?
          '请选择音轨范围内的有效起止时间。' : '音频处理失败，请重试。';
      }
      await this.stopPlayback();
    } finally {
      if (temporary && temporary !== this.renderPath) {
        await this.service.removeTemporary(temporary);
      }
      this.canCancelRender = false;
      this.renderCancelled = false;
      this.taskLabel = '';
    }
  }

  private canUndo(): boolean {
    return (this.graph?.snapshot().cursor ?? 0) > 0;
  }

  private updatePlayhead(milliseconds: number, sequence?: RenderSequence): void {
    const track = this.audio?.track;
    if (!track) {
      return;
    }
    const frame = Math.max(0, Math.round(milliseconds * track.sampleRate / 1000));
    if (!sequence) {
      this.cursorFrame = Math.min(frame, track.frameCount);
      return;
    }
    for (const segment of sequence.segments) {
      const offset = frame - segment.outputStartFrame;
      const length = segment.sourceEndFrame - segment.sourceStartFrame;
      if (offset >= 0 && offset < length) {
        this.cursorFrame = segment.sourceStartFrame + offset;
        return;
      }
    }
    if (sequence.segments.length > 0) {
      this.cursorFrame = sequence.segments[sequence.segments.length - 1].sourceEndFrame;
    }
  }

  private canRedo(): boolean {
    const history = this.graph?.snapshot();
    return history !== undefined && history.cursor < history.decisions.length;
  }

  private trackSummary(): string {
    const track = this.audio?.track;
    const graph = this.graph;
    if (!track || !graph) {
      return '';
    }
    const duration = frameToTimeUs(track.frameCount, track.sampleRate) / 1000000;
    const output = frameToTimeUs(graph.render('audio').totalFrames, track.sampleRate) / 1000000;
    return track.sampleRate + ' Hz · ' + track.channels + ' 声道 · 原始 ' + duration.toFixed(3) +
      ' 秒 · 剪后 ' + output.toFixed(3) + ' 秒';
  }

  @Builder
  sectionHeading(label: string) {
    Text(label).fontSize(17).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
  }

  @Styles
  editorPanel() {
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  waveform() {
    WaveformPane({
      peaks: this.viewPeaks,
      pcmFrameCount: this.audio?.track.frameCount ?? 0,
      pcmSampleRate: this.audio?.track.sampleRate ?? 0,
      viewStart: this.viewStart, viewEnd: this.viewEnd,
      rangeStart: this.selectionStart, rangeEnd: this.selectionEnd, cursorFrame: this.cursorFrame,
      interactive: !this.importOnly && !this.taskLabel && !this.loadingWindow,
      snapFrames: this.snap ? Math.max(1, Math.round((this.audio?.track.sampleRate ?? 0) / 10)) : 1,
      seek: (frame: number) => { this.cursorFrame = frame },
      select: (start: number, end: number) => { this.updateSelection(start, end) }
    })
  }

  @Builder
  editor() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.sectionHeading('音频波形与选区')
        Blank()
        Text(timecode(frameToTimeUs(this.cursorFrame, this.audio?.track.sampleRate ?? 1)))
          .fontSize(13).fontFamily('monospace').fontColor(XuzuoTheme.textPrimary)
          .accessibilityText('播放位置 ' + timecode(frameToTimeUs(this.cursorFrame, this.audio?.track.sampleRate ?? 1)))
      }.width('100%')
      this.waveform()
      Row({ space: 8 }) {
        ActionButton({ label: '放大', available: !this.loadingWindow && !this.taskLabel &&
          this.viewEnd - this.viewStart > Math.ceil((this.audio?.track.sampleRate ?? 0) / 20),
          action: () => { this.zoom(0.5) } })
        ActionButton({ label: '缩小', available: !this.loadingWindow && !this.taskLabel &&
          this.viewEnd - this.viewStart < (this.audio?.track.frameCount ?? 0),
          action: () => { this.zoom(2) } })
        ActionButton({ label: '向左', available: this.viewStart > 0 && !this.loadingWindow && !this.taskLabel,
          action: () => { this.loadWindow(this.viewStart - Math.ceil((this.viewEnd - this.viewStart) / 2),
            this.viewEnd - this.viewStart) } })
        ActionButton({ label: '向右', available: this.viewEnd < (this.audio?.track.frameCount ?? 0) &&
          !this.loadingWindow && !this.taskLabel,
          action: () => { this.loadWindow(this.viewStart + Math.ceil((this.viewEnd - this.viewStart) / 2),
            this.viewEnd - this.viewStart) } })
      }.width('100%')
      if (this.loadingWindow) {
        Text('正在读取波形').fontSize(12).fontColor(XuzuoTheme.textSecondary)
      }
      Text(this.trackSummary()).fontSize(13).fontColor(XuzuoTheme.textSecondary)
      Row({ space: 8 }) {
        ActionButton({ label: '试听选区', available: !this.taskLabel, action: () => { this.output('selection') } })
          .layoutWeight(1)
        ActionButton({ label: '试听剪后', available: !this.taskLabel, action: () => { this.output('preview') } })
          .layoutWeight(1)
        ActionButton({ label: '停止', available: !this.taskLabel && this.feedback === '正在播放',
          action: () => { this.stopPlayback(); this.feedback = '已停止播放' } }).layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        ActionButton({ label: '试听原音', variant: 'quiet', available: !this.taskLabel,
          action: () => { this.output('source') } })
        ActionButton({ label: '文字稿', variant: 'quiet', available: !this.taskLabel,
          action: () => this.goToTranscript() })
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).editorPanel()

    Divider().color(XuzuoTheme.outline)
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.sectionHeading('当前选区')
        Blank()
        ActionButton({ label: this.snap ? '吸附 0.1 秒' : '吸附已关闭', available: !this.taskLabel,
          action: () => { this.snap = !this.snap } })
      }.width('100%')
      Row({ space: 8 }) {
        Column() {
          TextFieldRow({ label: '开始（秒）', fieldValue: this.startText, limit: 16,
            update: (text: string) => { this.startText = text } })
        }.layoutWeight(1)
        Column() {
          TextFieldRow({ label: '结束（秒）', fieldValue: this.endText, limit: 16,
            update: (text: string) => { this.endText = text } })
        }.layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        Column() {
          TextFieldRow({ label: '淡入（秒）', fieldValue: this.fadeText, limit: 16,
            update: (text: string) => { this.fadeText = text } })
        }.layoutWeight(1)
        ActionButton({ label: '应用淡入', available: !this.taskLabel, action: () => { this.edit('fade') } })
      }.width('100%').alignItems(VerticalAlign.Bottom)
    }.alignItems(HorizontalAlign.Start).editorPanel()

    Column({ space: 8 }) {
      this.sectionHeading('剪辑工具')
      Row({ space: 8 }) {
        ActionButton({ label: '保留选区', variant: 'primary', available: !this.taskLabel, action: () => { this.edit('retain') } })
          .layoutWeight(1)
        ActionButton({ label: '分割', available: !this.taskLabel, action: () => { this.edit('split') } }).layoutWeight(1)
        ActionButton({ label: '删除选区', variant: 'danger', available: !this.taskLabel,
          action: () => { this.edit('remove') } }).layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        ActionButton({ label: '撤销', available: !this.taskLabel && this.canUndo(), action: () => { this.edit('undo') } })
          .layoutWeight(1)
        ActionButton({ label: '重做', available: !this.taskLabel && this.canRedo(),
          action: () => { this.edit('redo') } }).layoutWeight(1)
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).editorPanel()

    Column({ space: 8 }) {
      this.sectionHeading('编辑轨道')
      if (this.segments.length > 0) {
        Row({ space: 1 }) {
          ForEach(this.segments, (segment: RenderSegment) => {
            Button({ type: ButtonType.Normal }) {
              Text('片段').fontSize(12).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(AppAccent.onPrimary)
            }
            .layoutWeight(segment.sourceEndFrame - segment.sourceStartFrame)
            .padding(0)
            .constraintSize({ minHeight: XuzuoTheme.controlMin })
            .backgroundColor(AppAccent.primary)
            .borderRadius(4)
            .accessibilityText('定位源片段 ' +
              timecode(frameToTimeUs(segment.sourceStartFrame, this.audio?.track.sampleRate ?? 1)))
            .enabled(!this.taskLabel)
            .onClick(() => { this.updateSelection(segment.sourceStartFrame, segment.sourceEndFrame) })
          }, (segment: RenderSegment) => segment.sourceStartFrame + '-' + segment.sourceEndFrame)
        }.width('100%')
        Row() {
          Text('00:00:00.000').fontSize(12).fontFamily('monospace').fontColor(XuzuoTheme.textSecondary)
          Text(timecode(frameToTimeUs(this.outputFrames, this.audio?.track.sampleRate ?? 1)))
            .fontSize(12).fontFamily('monospace').fontColor(XuzuoTheme.textSecondary)
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      } else {
        Text('当前没有可输出的片段。').fontSize(14).fontColor(XuzuoTheme.textSecondary)
      }
      ActionButton({ label: '导出 WAV', available: !this.taskLabel && this.outputFrames > 0,
        action: () => { this.output('save') } })
    }.alignItems(HorizontalAlign.Start).editorPanel()
  }

  build() {
    Column({ space: 12 }) {
      if (this.audio && this.graph && !this.importOnly) {
        this.editor()
      } else {
        this.waveform()
        if (this.audio && this.graph) {
          Text(this.trackSummary()).fontSize(15).fontColor(XuzuoTheme.textSecondary)
        }
        if (this.project && !this.audio && !this.issue) {
          ActionButton({ label: '选择音频文件', variant: 'primary', available: !this.taskLabel,
            action: () => { this.choose() } })
        }
        if (this.project && !this.importOnly) {
          ActionButton({ label: '文字稿', variant: 'quiet', available: !this.taskLabel,
            action: () => this.openTranscript() })
        }
      }
      if (this.taskLabel) {
        TaskProgress({ label: this.renderCancelled ? '正在取消' : this.taskLabel,
          canCancel: this.canCancelRender && !this.renderCancelled, cancel: () => { this.renderCancelled = true } })
      }
      if (this.feedback) {
        StatusChip({ label: this.feedback })
      }
      if (this.issue) {
        ErrorPanel({ message: this.issue, actionLabel: this.audio ? '' : '重试',
          action: () => { this.issue = ''; this.restore() } })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
