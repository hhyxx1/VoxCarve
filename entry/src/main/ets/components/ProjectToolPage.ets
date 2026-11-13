import { common } from '@kit.AbilityKit';
import { EditGraph, frameToTimeUs } from '../domain/EditGraph';
import type { CaptionCue, EditDecision, MediaProject, TranscriptSegment } from '../domain/MediaModels';
import type { PcmFrameRange, PcmWavTrack } from '../domain/PcmWav';
import { encodeSrt, encodeVtt, mapSourceRange, parseTimeRange, TimeRange } from '../domain/TimeRange';
import type { ProjectRepository } from '../repository/ProjectRepository';
import { LocalAudioService } from '../services/LocalAudioService';
import { VoxRoute } from '../viewmodel/WorkspaceState';
import {
  ActionButton, DataRow, EmptyPanel, ErrorPanel, showConfirmDialog, StatusChip, TaskProgress, TextFieldRow
} from './XuzuoControls';
import { XuzuoTheme } from './XuzuoTheme';

@Component
export struct ProjectToolPage {
  @Prop route: string;
  @Prop project?: MediaProject = undefined;
  repository?: ProjectRepository;
  locate: (range: TimeRange) => void = () => {};
  refreshTimeline: () => void = () => {};
  guardBack: (guarded: boolean, busy: boolean) => void = () => {};
  @State private track?: PcmWavTrack = undefined;
  @State private graph?: EditGraph = undefined;
  @State private transcript: TranscriptSegment[] = [];
  @State private captions: CaptionCue[] = [];
  @State private pauses: PcmFrameRange[] = [];
  @State private minimum: string = '300';
  @State private threshold: string = '-45';
  @State private cancellable: boolean = false;
  @State private cancelling: boolean = false;
  @State private scanned: boolean = false;
  @State private busyLabel: string = '';
  @State private issue: string = '';
  @State private message: string = '';
  @State private editing: boolean = false;
  @State private draftId: string = '';
  @State private draftSourceId?: string = undefined;
  @State private draftText: string = '';
  @State private draftSpeaker: string = '';
  @State private draftStart: string = '';
  @State private draftEnd: string = '';
  @State private filename: string = '';
  private service?: LocalAudioService;
  private mounted: boolean = false;
  private serial: number = 0;
  private temporary?: string;

  aboutToAppear(): void {
    this.mounted = true;
    if (this.project) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.service = new LocalAudioService(context);
      this.filename = 'voxcarve-cut-' + this.project.id;
      this.load();
    }
  }

  aboutToDisappear(): void {
    this.mounted = false;
    if (!this.busyLabel) {
      this.stop();
    }
    this.guardBack(false, false);
  }

  private async run(label: string, operation: () => Promise<void>): Promise<void> {
    if (this.busyLabel) {
      return;
    }
    this.busyLabel = label;
    this.issue = '';
    this.message = '';
    this.guardBack(this.editing, true);
    try {
      await operation();
    } catch (error) {
      if ((error as Error).message === 'TASK_CANCELLED') {
        this.message = '任务已取消';
      } else {
        this.issue = (error as Error).message || '操作失败，请重试。';
      }
    } finally {
      this.cancellable = false;
      this.cancelling = false;
      this.busyLabel = '';
      if (this.mounted) {
        this.guardBack(this.editing, false);
      } else {
        await this.stop();
      }
    }
  }

  private checkpoint(): void {
    if (this.cancelling || !this.mounted) {
      throw new Error('TASK_CANCELLED');
    }
  }

  private async load(): Promise<void> {
    const project = this.project;
    const repository = this.repository;
    const service = this.service;
    if (!project || !repository || !service) {
      return;
    }
    await this.run('读取项目', async () => {
      try {
        const track = await service.readTrack(project.id);
        this.track = track;
        this.graph = undefined;
        if (track) {
          const saved = await repository.loadEdits(project.id);
          if (saved && (saved.sampleRate !== track.sampleRate || saved.sourceFrameCount !== track.frameCount)) {
            throw new Error('EDIT_SOURCE_MISMATCH');
          }
          this.graph = saved ?? new EditGraph(track.sampleRate, track.frameCount);
        }
        if (this.route === VoxRoute.Transcript || this.route === VoxRoute.Captions) {
          this.transcript = await repository.listTranscript(project.id);
        }
        if (this.route === VoxRoute.Captions) {
          this.captions = await repository.listCaptions(project.id);
        }
      } catch (_) {
        throw new Error('无法读取本地音轨或项目记录。');
      }
    });
  }

  private begin(id: string, text: string, speaker: string, start?: number, end?: number, sourceId?: string): void {
    this.draftId = id;
    this.draftSourceId = sourceId;
    this.draftText = text;
    this.draftSpeaker = speaker;
    this.draftStart = start === undefined ? '' : (start / 1000).toString();
    this.draftEnd = end === undefined ? '' : (end / 1000).toString();
    this.editing = true;
    this.issue = '';
    this.message = '';
    this.guardBack(true, false);
  }

  private endEdit(): void {
    this.editing = false;
    this.guardBack(false, !!this.busyLabel);
  }

  private duration(output: boolean): number {
    const graph = this.graph;
    if (!graph) {
      return 0;
    }
    return frameToTimeUs(output ? graph.render('audio').totalFrames : graph.sourceFrameCount, graph.sampleRate);
  }

  private async saveText(): Promise<void> {
    const project = this.project;
    const repository = this.repository;
    const body = this.draftText.trim();
    if (!project || !repository || !body) {
      return;
    }
    const output = this.route === VoxRoute.Captions;
    const unbound = !this.draftStart.trim() && !this.draftEnd.trim();
    let range: TimeRange | undefined;
    try {
      if (output || !unbound) {
        range = parseTimeRange(this.draftStart, this.draftEnd, this.duration(output));
      }
    } catch (_) {
      this.issue = '请输入当前音轨范围内的有效起止毫秒，结束必须晚于开始。';
      return;
    }
    const id = this.draftId || Date.now().toString() + '-' + this.serial++;
    await this.run('保存文字', async () => {
      try {
        if (output && range) {
          await repository.saveCaption(project.id, {
            id: id, transcriptSegmentId: this.draftSourceId, outputStartUs: range.startUs,
            outputEndUs: range.endUs, text: body
          });
          this.captions = await repository.listCaptions(project.id);
        } else {
          await repository.saveTranscript(project.id, {
            id: id, trackId: 'audio', text: body, speaker: this.draftSpeaker.trim(),
            sourceStartUs: range?.startUs, sourceEndUs: range?.endUs,
            timeSource: range ? 'manual' : 'unbound', verified: range !== undefined
          });
          this.transcript = await repository.listTranscript(project.id);
        }
        this.endEdit();
        this.message = output ? '字幕已保存' : '文字稿已保存';
      } catch (_) {
        throw new Error('无法保存文字，请重试。');
      }
    });
  }

  private confirmRemoveCaption(): void {
    const id = this.draftId;
    const project = this.project;
    const repository = this.repository;
    if (!id || !project || !repository) {
      return;
    }
    showConfirmDialog(this.getUIContext(), '删除字幕？', '此字幕将从项目和后续字幕导出中移除。', '删除', () => {
        this.run('删除字幕', async () => {
          try {
            await repository.removeCaption(project.id, id);
            this.captions = this.captions.filter((cue: CaptionCue) => cue.id !== id);
            this.endEdit();
            this.message = '字幕已删除';
          } catch (_) {
            throw new Error('无法删除字幕，请重试。');
          }
        });
      });
  }

  private draftCaption(segment: TranscriptSegment): void {
    if (!this.graph || segment.sourceStartUs === undefined || segment.sourceEndUs === undefined) {
      return;
    }
    const range = mapSourceRange({ startUs: segment.sourceStartUs, endUs: segment.sourceEndUs },
      this.graph.render('audio'));
    if (!range) {
      this.issue = '这段文字对应的音频已被剪除。';
      return;
    }
    this.begin('', segment.text, '', range.startUs, range.endUs, segment.id);
  }

  private async exportCaptions(format: 'srt' | 'vtt'): Promise<void> {
    const project = this.project;
    const service = this.service;
    if (!project || !service) {
      return;
    }
    let content: string;
    try {
      content = format === 'vtt' ? encodeVtt(this.captions, this.duration(true)) :
        encodeSrt(this.captions, this.duration(true));
    } catch (_) {
      this.issue = '字幕有重叠、过短或超出剪后时长。请校对后重试。';
      return;
    }
    const label = format.toUpperCase();
    await this.run('保存 ' + label, async () => {
      try {
        this.message = await service.saveCaptionText(project.id, content, format) ? '已导出 ' + label : '已取消保存';
      } catch (_) {
        throw new Error('无法保存字幕，请重试。');
      }
    });
  }

  private speechSupported(): boolean {
    const track = this.track;
    return !!track && track.sampleRate === 16000 && track.channels === 1 &&
      track.frameCount <= 16000 * 60 && canIUse('SystemCapability.AI.SpeechRecognizer');
  }

  private async transcribe(): Promise<void> {
    const project = this.project;
    const track = this.track;
    const service = this.service;
    if (!project || !track || !service || !this.speechSupported()) {
      return;
    }
    await this.run('本地识别普通话', async () => {
      this.cancellable = true;
      try {
        const result = await service.transcribe(project.id, track, () => this.checkpoint());
        const text = result.text;
        this.checkpoint();
        this.cancellable = false;
        if (text) {
          this.begin('', text.slice(0, 500), '');
          this.message = !result.inputComplete ? '识别提前结束，已载入部分草稿。请试听校对并填写源音时间。' :
            text.length > 500 ? '已载入前 500 字，请校对并填写源音时间。' :
              '识别草稿待校对，请手工填写源音时间。';
        } else {
          this.message = '没有识别到普通话，请手动录入。';
        }
      } catch (error) {
        const code = (error as Error).message;
        throw new Error(code === 'TASK_CANCELLED' ? code : '离线转写失败，可手动录入（' + code + '）。');
      }
    });
  }

  private async scan(): Promise<void> {
    const project = this.project;
    const track = this.track;
    const service = this.service;
    const minimum = Number(this.minimum);
    const threshold = Number(this.threshold);
    if (!project || !track || !service) {
      return;
    }
    if (!Number.isInteger(minimum) || minimum < 100 || minimum > 10000) {
      this.issue = '停顿长度请输入 100–10000 毫秒之间的整数。';
      return;
    }
    if (!Number.isInteger(threshold) || threshold < -80 || threshold > -20) {
      this.issue = '门限请输入 −80 到 −20 dBFS 之间的整数。';
      return;
    }
    await this.run('分析 PCM 停顿', async () => {
      this.cancellable = true;
      this.scanned = false;
      this.pauses = [];
      try {
        const results = await service.quietRanges(project.id, track, minimum, () => this.checkpoint(), threshold);
        this.checkpoint();
        this.pauses = results;
        this.scanned = true;
      } catch (error) {
        throw new Error((error as Error).message === 'TASK_CANCELLED' ? 'TASK_CANCELLED' : '无法分析音频，请重试。');
      }
    });
  }

  private async stop(): Promise<boolean> {
    let released = true;
    try {
      await this.service?.stop();
    } catch (_) {
      released = false;
      if (this.mounted) {
        this.issue = '释放试听资源失败。';
      }
    } finally {
      const path = this.temporary;
      this.temporary = undefined;
      if (path) {
        await this.service?.removeTemporary(path);
      }
    }
    return released;
  }

  private async output(save: boolean): Promise<void> {
    const service = this.service;
    const graph = this.graph;
    const track = this.track;
    const project = this.project;
    if (!service || !graph || !track || !project) {
      return;
    }
    const name = this.filename.trim();
    if (save && (!name || /[\\/:*?"<>|]/.test(name) || name === '.' || name === '..')) {
      this.issue = '请输入有效的文件名。';
      return;
    }
    await this.run(save ? '渲染 WAV' : '准备试听', async () => {
      await this.stop();
      try {
        this.cancellable = true;
        const path = await service.render(project.id, track, graph, () => this.checkpoint());
        this.temporary = path;
        this.checkpoint();
        this.cancellable = false;
        if (save) {
          const bytes = await service.save(path, project.id, name.toLowerCase().endsWith('.wav') ? name : name + '.wav');
          this.message = bytes === undefined ? '已取消保存' : '已导出 WAV · ' + bytes + ' 字节';
          await this.stop();
        } else if (this.mounted) {
          await service.play(path, (status: string) => {
            if (this.mounted) {
              this.message = status;
            }
          });
        }
      } catch (error) {
        await this.stop();
        const code = (error as Error).message;
        throw new Error(code === 'TASK_CANCELLED' ? code :
          code === 'EMPTY_RENDER' ? '没有可输出的音频帧，请先调整剪辑。' :
          '音频处理失败，请重试。');
      }
    });
  }

  private async changeVersion(cursor: number): Promise<void> {
    const project = this.project;
    const repository = this.repository;
    const snapshot = this.graph?.snapshot();
    if (!project || !repository || !snapshot) {
      return;
    }
    await this.run('保存剪辑版本', async () => {
      const graph = EditGraph.restore({
        sampleRate: snapshot.sampleRate, sourceFrameCount: snapshot.sourceFrameCount,
        decisions: snapshot.decisions, cursor: cursor
      });
      await repository.saveEdits(project.id, graph);
      this.graph = graph;
      this.refreshTimeline();
      this.message = '已恢复版本 ' + cursor;
    });
  }

  private rangeLabel(startUs: number, endUs: number): string {
    return (startUs / 1000).toFixed(3) + '–' + (endUs / 1000).toFixed(3) + ' 毫秒';
  }

  private frameRange(startFrame: number, endFrame: number): TimeRange {
    const rate = this.track?.sampleRate ?? 1;
    return { startUs: frameToTimeUs(startFrame, rate), endUs: frameToTimeUs(endFrame, rate) };
  }

  private historyLabel(decision: EditDecision): string {
    const range = this.frameRange(decision.sourceStartFrame, decision.sourceEndFrame);
    return (decision.mode === 'remove' ? '删除 ' : '保留 ') + this.rangeLabel(range.startUs, range.endUs);
  }

  @Builder
  textForm(caption: boolean) {
    TextFieldRow({ label: caption ? '字幕内容' : '文字稿内容', fieldValue: this.draftText, limit: 500,
      update: (value: string) => { this.draftText = value } })
    if (!caption) {
      TextFieldRow({ label: '说话人', fieldValue: this.draftSpeaker,
        update: (value: string) => { this.draftSpeaker = value } })
    }
    if (caption || this.track) {
      TextFieldRow({ label: caption ? '剪后开始（毫秒）' : '源音开始（毫秒）', fieldValue: this.draftStart,
        update: (value: string) => { this.draftStart = value } })
      TextFieldRow({ label: caption ? '剪后结束（毫秒）' : '源音结束（毫秒）', fieldValue: this.draftEnd,
        update: (value: string) => { this.draftEnd = value } })
    }
    ActionButton({ label: '保存', variant: 'primary', available: !!this.draftText.trim() && !this.busyLabel,
      action: () => { this.saveText() } })
    ActionButton({ label: '取消编辑', available: !this.busyLabel, action: () => this.endEdit() })
    if (caption && this.draftId) {
      ActionButton({ label: '删除字幕', available: !this.busyLabel, action: () => this.confirmRemoveCaption() })
    }
  }

  @Builder
  transcriptContent() {
    Text('手动录入。核对过的源音时间可定位到剪辑台。').fontSize(15).fontColor(XuzuoTheme.textSecondary)
    if (this.editing) {
      this.textForm(false)
    } else {
      ActionButton({ label: '新增句段', variant: 'primary', available: !this.busyLabel,
        action: () => this.begin('', '', '') })
      if (this.speechSupported()) {
        ActionButton({ label: '离线识别普通话', available: !this.busyLabel, action: () => { this.transcribe() } })
      } else if (this.track) {
        Text('离线识别需设备支持，且音轨为不超过 60 秒的 16 kHz 单声道 PCM WAV。')
          .fontSize(14).fontColor(XuzuoTheme.textSecondary)
      }
      if (this.transcript.length === 0) {
        EmptyPanel({ title: '暂无文字稿', detail: '可先录入文字，导入音频后再校准时间。' })
      }
      ForEach(this.transcript, (segment: TranscriptSegment) => {
        Column({ space: 6 }) {
          DataRow({ title: segment.text,
            detail: (segment.speaker ? segment.speaker + ' · ' : '') +
              (segment.sourceStartUs !== undefined && segment.sourceEndUs !== undefined ?
                this.rangeLabel(segment.sourceStartUs, segment.sourceEndUs) : '待校准'),
            action: () => this.begin(segment.id, segment.text, segment.speaker, segment.sourceStartUs, segment.sourceEndUs)
          })
          if (segment.verified && segment.sourceStartUs !== undefined && segment.sourceEndUs !== undefined && this.track) {
            ActionButton({ label: '定位到剪辑台', action: () => this.locate({
              startUs: segment.sourceStartUs ?? 0, endUs: segment.sourceEndUs ?? 0
            }) })
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }, (segment: TranscriptSegment) => segment.id + segment.text + segment.speaker +
        segment.sourceStartUs + segment.sourceEndUs)
    }
  }

  @Builder
  captionContent() {
    Text('字幕使用剪后时间。剪辑变更后请复核已保存的字幕。').fontSize(15).fontColor(XuzuoTheme.textSecondary)
    if (this.editing) {
      this.textForm(true)
    } else {
      ActionButton({ label: '新增字幕', variant: 'primary', available: this.duration(true) > 0 && !this.busyLabel,
        action: () => this.begin('', '', '', 0, this.duration(true)) })
      if (this.captions.length > 0) {
        Row({ space: 8 }) {
          ActionButton({ label: '导出 SRT', available: !this.busyLabel, action: () => { this.exportCaptions('srt') } })
          ActionButton({ label: '导出 VTT', available: !this.busyLabel, action: () => { this.exportCaptions('vtt') } })
        }
      } else {
        EmptyPanel({ title: '暂无字幕', detail: '可以手动输入，也可从已校准的文字稿生成草稿。' })
      }
      ForEach(this.captions, (cue: CaptionCue) => {
        DataRow({ title: cue.text, detail: this.rangeLabel(cue.outputStartUs, cue.outputEndUs) +
          (cue.outputEndUs > this.duration(true) ? ' · 超出当前时长' : ''),
          action: () => this.begin(cue.id, cue.text, '', cue.outputStartUs, cue.outputEndUs, cue.transcriptSegmentId) })
      }, (cue: CaptionCue) => cue.id + cue.text + cue.outputStartUs + cue.outputEndUs + this.duration(true))
      ForEach(this.transcript.filter((segment: TranscriptSegment) => segment.verified), (segment: TranscriptSegment) => {
        DataRow({ title: segment.text, detail: '从文字稿生成字幕草稿', action: () => this.draftCaption(segment) })
      }, (segment: TranscriptSegment) => segment.id)
    }
  }

  @Builder
  silenceContent() {
    Text('每 20 毫秒计算各声道 RMS。所有声道低于或等于门限才计为停顿。')
      .fontSize(15).fontColor(XuzuoTheme.textSecondary)
    TextFieldRow({ label: '最短停顿（毫秒）', fieldValue: this.minimum,
      update: (value: string) => { this.minimum = value; this.scanned = false; this.pauses = [] } })
    TextFieldRow({ label: '停顿门限（dBFS）', fieldValue: this.threshold,
      update: (value: string) => { this.threshold = value; this.scanned = false; this.pauses = [] } })
    ActionButton({ label: '查找停顿', variant: 'primary', available: !this.busyLabel, action: () => { this.scan() } })
    if (this.scanned && this.pauses.length === 0) {
      StatusChip({ label: '没有符合门限的停顿' })
    }
    ForEach(this.pauses, (range: PcmFrameRange) => {
      DataRow({ title: this.rangeLabel(this.frameRange(range.startFrame, range.endFrame).startUs,
        this.frameRange(range.startFrame, range.endFrame).endUs), detail: '在剪辑台复核并决定是否删除',
        action: () => this.locate(this.frameRange(range.startFrame, range.endFrame)) })
    }, (range: PcmFrameRange) => range.startFrame + '-' + range.endFrame)
  }

  @Builder
  historyContent() {
    StatusChip({ label: '当前版本 ' + (this.graph?.snapshot().cursor ?? 0) })
    if ((this.graph?.snapshot().decisions.length ?? 0) === 0) {
      EmptyPanel({ title: '暂无剪辑记录', detail: '保留或删除选区后，可以在这里恢复编辑版本。' })
    } else {
      ActionButton({ label: '恢复原始顺序', available: !this.busyLabel && (this.graph?.snapshot().cursor ?? 0) > 0,
        action: () => { this.changeVersion(0) } })
      ForEach(this.graph?.snapshot().decisions.slice() ?? [], (decision: EditDecision, index: number) => {
        DataRow({ title: '版本 ' + (index + 1), detail: this.historyLabel(decision),
          action: () => {
            if (!this.busyLabel && this.graph?.snapshot().cursor !== index + 1) {
              this.changeVersion(index + 1);
            }
          } })
      }, (decision: EditDecision) => decision.id)
    }
  }

  build() {
    Column({ space: 12 }) {
      if (!this.project) {
        EmptyPanel({ title: '尚未选择项目', detail: '请先从项目列表打开一个项目。' })
      } else if (this.route === VoxRoute.Transcript) {
        this.transcriptContent()
      } else if (!this.track && !this.busyLabel) {
        EmptyPanel({ title: '暂无音轨', detail: '请先为项目导入 WAV。' })
      } else if (this.track) {
        if (this.route === VoxRoute.Captions) {
          this.captionContent()
        } else if (this.route === VoxRoute.Silence) {
          this.silenceContent()
        } else if (this.route === VoxRoute.History) {
          this.historyContent()
        } else {
          Text('剪后时长 ' + (this.duration(true) / 1000000).toFixed(3) + ' 秒')
            .fontSize(16).fontColor(XuzuoTheme.textPrimary)
          if (this.route === VoxRoute.Preview) {
            ActionButton({ label: '播放剪后音频', variant: 'primary', available: !this.busyLabel,
              action: () => { this.output(false) } })
            ActionButton({ label: '停止播放', available: !this.busyLabel && this.message === '正在播放',
              action: () => { this.run('停止播放', async () => { if (await this.stop()) { this.message = '已停止' } }) } })
          } else if (this.route === VoxRoute.Export) {
            Text('WAV · 16 位 PCM · 保留源采样率和声道').fontSize(15).fontColor(XuzuoTheme.textSecondary)
            Text('MP3 编码和 MP4 音画同步尚未通过输出验证。可保存 WAV。')
              .fontSize(14).fontColor(XuzuoTheme.textSecondary)
            TextFieldRow({ label: '导出文件名', fieldValue: this.filename,
              update: (value: string) => { this.filename = value } })
            ActionButton({ label: '保存 WAV', variant: 'primary', available: !this.busyLabel,
              action: () => { this.output(true) } })
          }
        }
      }
      if (this.busyLabel) {
        TaskProgress({ label: this.cancelling ? '正在取消' : this.busyLabel,
          canCancel: this.cancellable && !this.cancelling, cancel: () => { this.cancelling = true } })
      }
      if (this.message) {
        StatusChip({ label: this.message })
      }
      if (this.issue) {
        ErrorPanel({ message: this.issue, actionLabel: !this.track && !this.editing ? '重试读取' : '',
          action: () => { this.load() } })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
