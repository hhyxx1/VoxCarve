import { common } from '@kit.AbilityKit';
import type { MediaProject } from '../domain/MediaModels';
import { EditGraph, frameToTimeUs, timeUsToFrame } from '../domain/EditGraph';
import type { ProjectRepository } from '../repository/ProjectRepository';
import { LocalAudioService, OpenAudio } from '../services/LocalAudioService';
import { ActionButton, ErrorPanel, StatusChip, TaskProgress, TextFieldRow } from './XuzuoControls';
import { WaveformPane } from './AudioEditorPanes';
import { XuzuoTheme } from './XuzuoTheme';
import { parseTimeRange, TimeRange } from '../domain/TimeRange';

@Component
export struct AudioWorkspace {
  @Prop project?: MediaProject = undefined;
  @Prop importOnly: boolean = false;
  @Prop initialRange?: TimeRange = undefined;
  repository?: ProjectRepository;
  imported: () => void = () => {};
  @State private audio?: OpenAudio = undefined;
  @State private graph?: EditGraph = undefined;
  @State private startText: string = '0';
  @State private endText: string = '0';
  @State private selectionStart: number = 0;
  @State private selectionEnd: number = 0;
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
    this.graph = saved ?? new EditGraph(source.track.sampleRate, source.track.frameCount);
    this.audio = source;
    const range = this.initialRange;
    const rate = source.track.sampleRate;
    this.updateSelection(range ? Math.min(source.track.frameCount, timeUsToFrame(range.startUs, rate)) : 0,
      range ? Math.min(source.track.frameCount, timeUsToFrame(range.endUs, rate)) : source.track.frameCount);
  }

  private async choose(): Promise<void> {
    if (!this.project || !this.service || this.taskLabel || this.audio) {
      return;
    }
    this.taskLabel = '等待选择或分析 WAV';
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
      this.issue = message === 'UNSUPPORTED_WAV' ? '请选择 16 位 PCM WAV（单声道或双声道）。' :
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
    this.startText = (frameToTimeUs(start, rate) / 1000).toString();
    this.endText = (frameToTimeUs(end, rate) / 1000).toString();
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
      if (mode === 'undo') {
        next = graph.undo();
      } else if (mode === 'redo') {
        next = graph.redo();
      } else {
        const range = parseTimeRange(this.startText, this.endText, frameToTimeUs(graph.sourceFrameCount, graph.sampleRate));
        const start = timeUsToFrame(range.startUs, graph.sampleRate);
        const end = timeUsToFrame(range.endUs, graph.sampleRate);
        const now = Date.now();
        const id = now.toString() + '-' + graph.snapshot().cursor;
        next = mode === 'retain' ? graph.retain(id, start, end, now) : graph.remove(id, start, end, now);
        this.updateSelection(start, end);
      }
    } catch (_) {
      this.issue = '请输入音轨范围内的有效起止时间，结束必须晚于开始。';
      return;
    }
    this.taskLabel = '保存编辑记录';
    try {
      await this.repository.saveEdits(this.project.id, next);
      this.graph = next;
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
    try {
      await this.stopPlayback();
      if (mode !== 'source') {
        let graph = this.graph;
        if (mode === 'selection') {
          const range = parseTimeRange(this.startText, this.endText, frameToTimeUs(graph.sourceFrameCount, graph.sampleRate));
          graph = new EditGraph(graph.sampleRate, graph.sourceFrameCount).retain('preview',
            timeUsToFrame(range.startUs, graph.sampleRate), timeUsToFrame(range.endUs, graph.sampleRate), Date.now());
        }
        temporary = await this.service.render(this.project.id, this.audio.track, graph);
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
        });
        if (!this.mounted) {
          await this.stopPlayback();
        }
      }
    } catch (error) {
      const code = (error as Error).message;
      this.issue = code === 'EMPTY_RENDER' ? '当前没有可输出的音频帧，请先撤销或调整剪切。' :
        code === 'INVALID_TIME_RANGE' || code === 'INVALID_EDIT_RANGE' ?
          '请选择音轨范围内的有效起止时间。' : '音频处理失败，请重试。';
      await this.stopPlayback();
    } finally {
      if (temporary && temporary !== this.renderPath) {
        await this.service.removeTemporary(temporary);
      }
      this.taskLabel = '';
    }
  }

  private canUndo(): boolean {
    return (this.graph?.snapshot().cursor ?? 0) > 0;
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

  build() {
    Column({ space: 12 }) {
      WaveformPane({
        peaks: this.audio?.peaks ?? [],
        pcmFrameCount: this.audio?.track.frameCount ?? 0,
        pcmSampleRate: this.audio?.track.sampleRate ?? 0,
        rangeStart: this.selectionStart, rangeEnd: this.selectionEnd,
        select: (start: number, end: number) => { this.updateSelection(start, end) }
      })
      if (this.project && !this.audio && !this.issue) {
        ActionButton({ label: '选择 WAV 文件', variant: 'primary', available: !this.taskLabel,
          action: () => { this.choose() } })
      }
      if (this.audio && this.graph) {
        Text(this.trackSummary()).fontSize(15).fontColor(XuzuoTheme.textSecondary)
        if (!this.importOnly) {
          TextFieldRow({ label: '开始时间（毫秒）', fieldValue: this.startText,
            update: (text: string) => { this.startText = text } })
          TextFieldRow({ label: '结束时间（毫秒）', fieldValue: this.endText,
            update: (text: string) => { this.endText = text } })
          Row({ space: 8 }) {
            ActionButton({ label: '删除选区', available: !this.taskLabel, action: () => { this.edit('remove') } })
            ActionButton({ label: '保留选区', available: !this.taskLabel, action: () => { this.edit('retain') } })
          }
          Row({ space: 8 }) {
            ActionButton({ label: '撤销', available: !this.taskLabel && this.canUndo(), action: () => { this.edit('undo') } })
            ActionButton({ label: '重做', available: !this.taskLabel && this.canRedo(), action: () => { this.edit('redo') } })
          }
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              ActionButton({ label: '试听原音', available: !this.taskLabel, action: () => { this.output('source') } })
              ActionButton({ label: '试听选区', available: !this.taskLabel, action: () => { this.output('selection') } })
            }
            Row({ space: 8 }) {
              ActionButton({ label: '试听剪后', available: !this.taskLabel, action: () => { this.output('preview') } })
              ActionButton({ label: '停止', available: !this.taskLabel, action: () => { this.stopPlayback() } })
            }
          }
          .alignItems(HorizontalAlign.Start)
          ActionButton({ label: '导出 WAV', variant: 'primary', available: !this.taskLabel,
            action: () => { this.output('save') } })
        }
      }
      if (this.taskLabel) {
        TaskProgress({ label: this.taskLabel })
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
