import { runProbe } from 'libvoxprobe.so';
import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';

@Component
export struct SdkProbePanel {
  @State private status: string = '选择一项能力进行探测。';
  @State private busy: boolean = false;

  private async probePicker(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    const files = await new picker.DocumentViewPicker(context).select(options);
    if (files.length === 0) {
      return '已取消选择';
    }
    const file = await fileIo.open(files[0], fileIo.OpenMode.READ_ONLY);
    try {
      const stat = await fileIo.stat(file.fd);
      return `已获临时只读授权，文件大小 ${stat.size} 字节`;
    } finally {
      await fileIo.close(file);
    }
  }

  private async saveProbeFixture(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const bytes = await context.resourceManager.getRawFileContent('mono-16k.wav');
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = ['voxcarve-sdk26-test.wav'];
    const files = await new picker.DocumentViewPicker(context).save(options);
    if (files.length === 0) {
      return '已取消保存';
    }

    const file = await fileIo.open(files[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const written = await fileIo.write(file.fd, bytes.slice().buffer);
      if (written !== bytes.byteLength || (await fileIo.stat(file.fd)).size !== written) {
        return '测试样本未完整写入';
      }
      return `已保存测试样本，${written} 字节`;
    } finally {
      await fileIo.close(file);
    }
  }

  private async probeRenderer(): Promise<string> {
    const options: audio.AudioRendererOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        channels: audio.AudioChannel.CHANNEL_2,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_MUSIC, rendererFlags: 0 }
    };
    const renderer = await audio.createAudioRenderer(options);
    try {
      const stream = await renderer.getStreamInfo();
      return `渲染器已创建，${stream.samplingRate} Hz，${stream.channels} 声道`;
    } finally {
      await renderer.release();
    }
  }

  private async probeSpeech(): Promise<string> {
    if (!canIUse('SystemCapability.AI.SpeechRecognizer')) {
      return '设备缺少语音识别系统能力';
    }
    const engine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 1 });
    try {
      const languages = await engine.listLanguages({ sessionId: 'voxcarve-sdk26' });
      return languages.length ? `离线语种：${languages.join('、')}` : '设备未返回可用离线语种';
    } finally {
      engine.shutdown();
    }
  }

  private async probeNativeMedia(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const names: string[] = ['mono-16k.wav', 'stereo-48k.wav'];
    const results: string[] = [];
    for (const name of names) {
      const source = await context.resourceManager.getRawFd(name);
      try {
        const code = runProbe(source.fd, source.offset, source.length, context.cacheDir);
        results.push(`${name}：${code === 0 ? '通过' : `失败标记 ${code}`}`);
      } finally {
        await context.resourceManager.closeRawFd(name);
      }
    }
    return results.join(' · ');
  }

  private async runProbe(probe: () => Promise<string>): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.status = '探测中…';
    try {
      this.status = await probe();
    } catch (error) {
      const detail = error as BusinessError;
      this.status = `探测失败（${detail.code ?? '未知错误'}）`;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('声剪 · SDK 26 探测').fontSize(24).fontWeight(FontWeight.Bold)
      Button('文件选择与只读访问').enabled(!this.busy).onClick(() => {
        this.runProbe(() => this.probePicker());
      })
      Button('保存测试样本').enabled(!this.busy).onClick(() => {
        this.runProbe(() => this.saveProbeFixture());
      })
      Button('初始化 PCM 播放器').enabled(!this.busy).onClick(() => {
        this.runProbe(() => this.probeRenderer());
      })
      Button('查询离线转写语种').enabled(!this.busy).onClick(() => {
        this.runProbe(() => this.probeSpeech());
      })
      Button('探测原生媒体接口').enabled(!this.busy).onClick(() => {
        this.runProbe(() => this.probeNativeMedia());
      })
      Text(this.status).fontSize(16)
    }
    .width('100%')


    .alignItems(HorizontalAlign.Start)

  }
}
