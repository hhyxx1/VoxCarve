import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { EditGraph } from '../domain/EditGraph';
import type { RenderSegment } from '../domain/MediaModels';
import { recognizeMandarin, OfflineSpeechResult } from './OfflineSpeechService';
import {
  detectQuietRanges, makeWavHeader, readPcmWav, samplePeaks, PcmWavTrack, PcmPeak, ReadBytes, PcmFrameRange
} from '../domain/PcmWav';

export interface OpenAudio {
  readonly track: PcmWavTrack;
  readonly peaks: PcmPeak[];
}

const importingProjects = new Set<number>();
let renderSerial = 0;

export class LocalAudioService {
  private context: common.UIAbilityContext;
  private player?: media.AVPlayer;
  private playbackFile?: fileIo.File;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  assetPath(id: number): string {
    return this.context.filesDir + '/project-' + id + '.wav';
  }

  async openProject(id: number): Promise<OpenAudio | undefined> {
    const path = this.assetPath(id);
    return (await fileIo.access(path)) ? this.analyze(path) : undefined;
  }

  async readTrack(id: number): Promise<PcmWavTrack | undefined> {
    const path = this.assetPath(id);
    if (!await fileIo.access(path)) {
      return undefined;
    }
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      return await readPcmWav(this.reader(file.fd), (await fileIo.stat(file.fd)).size);
    } finally {
      await fileIo.close(file);
    }
  }

  async quietRanges(id: number, track: PcmWavTrack, minimumMs: number,
    checkpoint: () => void, thresholdDb: number): Promise<PcmFrameRange[]> {
    const file = await fileIo.open(this.assetPath(id), fileIo.OpenMode.READ_ONLY);
    try {
      return await detectQuietRanges(this.reader(file.fd), track, minimumMs, checkpoint, thresholdDb);
    } finally {
      await fileIo.close(file);
    }
  }

  async transcribe(id: number, track: PcmWavTrack, checkpoint: () => void): Promise<OfflineSpeechResult> {
    if (track.channels !== 1 || track.sampleRate !== 16000 || track.frameCount > 16000 * 60) {
      throw new Error('SPEECH_FORMAT');
    }
    const file = await fileIo.open(this.assetPath(id), fileIo.OpenMode.READ_ONLY);
    try {
      return await recognizeMandarin(this.reader(file.fd), track.dataOffset,
        track.frameCount * track.blockAlign, checkpoint);
    } finally {
      await fileIo.close(file);
    }
  }

  private reader(fd: number): ReadBytes {
    return async (offset: number, length: number): Promise<ArrayBuffer> => {
      const buffer = new ArrayBuffer(length);
      fileIo.lseek(fd, offset);
      const bytes = await fileIo.read(fd, buffer);
      return bytes === length ? buffer : buffer.slice(0, bytes);
    };
  }

  async analyze(path: string): Promise<OpenAudio> {
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const read = this.reader(file.fd);
      const track = await readPcmWav(read, (await fileIo.stat(file.fd)).size);
      return { track: track, peaks: await samplePeaks(read, track, 192) };
    } finally {
      await fileIo.close(file);
    }
  }

  async choose(id: number): Promise<OpenAudio | undefined> {
    if (importingProjects.has(id)) {
      throw new Error('IMPORT_ALREADY_EXISTS');
    }
    importingProjects.add(id);
    try {
      if (await fileIo.access(this.assetPath(id))) {
        throw new Error('IMPORT_ALREADY_EXISTS');
      }
      return await this.selectAndCopy(id);
    } finally {
      importingProjects.delete(id);
    }
  }

  private async selectAndCopy(id: number): Promise<OpenAudio | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(this.context).select(options);
    if (uris.length === 0) {
      return undefined;
    }
    const source = await fileIo.open(uris[0], fileIo.OpenMode.READ_ONLY);
    const staged = this.assetPath(id) + '.importing';
    try {
      const originalSize = (await fileIo.stat(source.fd)).size;
      await fileIo.copyFile(source.fd, staged);
      if ((await fileIo.stat(staged)).size !== originalSize) {
        throw new Error('INCOMPLETE_COPY');
      }
      const result = await this.analyze(staged);
      await fileIo.rename(staged, this.assetPath(id));
      return result;
    } finally {
      try {
        await fileIo.close(source);
      } finally {
        await this.removeTemporary(staged);
      }
    }
  }

  async removeTemporary(path: string): Promise<void> {
    try {
      await fileIo.unlink(path);
    } catch (_) {
      // A missing staged file is normal after publishing it.
    }
  }

  async render(projectId: number, track: PcmWavTrack, graph: EditGraph, checkpoint?: () => void): Promise<string> {
    checkpoint?.();
    const sequence = graph.render(projectId.toString());
    const header = makeWavHeader(track.sampleRate, track.channels, sequence.totalFrames);
    const destination = this.context.cacheDir + '/voxcarve-render-' + projectId + '-' +
      Date.now() + '-' + renderSerial++ + '.wav';
    const input = await fileIo.open(this.assetPath(projectId), fileIo.OpenMode.READ_ONLY);
    try {
      const output = await fileIo.open(destination, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY |
        fileIo.OpenMode.TRUNC);
      try {
        await this.writeBlock(output.fd, header);
        const read = this.reader(input.fd);
        for (const segment of sequence.segments) {
          await this.copySegment(read, output.fd, track, segment, checkpoint);
        }
        const expected = header.byteLength + sequence.totalFrames * track.blockAlign;
        if ((await fileIo.stat(output.fd)).size !== expected) {
          throw new Error('INCOMPLETE_RENDER');
        }
        await fileIo.fsync(output.fd);
        checkpoint?.();
      } finally {
        await fileIo.close(output);
      }
      return destination;
    } catch (error) {
      await this.removeTemporary(destination);
      throw new Error((error as Error).message === 'TASK_CANCELLED' ? 'TASK_CANCELLED' : 'RENDER_FAILED');
    } finally {
      await fileIo.close(input);
    }
  }

  private async writeBlock(fd: number, buffer: ArrayBuffer): Promise<void> {
    let remaining = buffer;
    while (remaining.byteLength > 0) {
      const bytes = await fileIo.write(fd, remaining);
      if (bytes <= 0) {
        throw new Error('WRITE_FAILED');
      }
      remaining = remaining.slice(bytes);
    }
  }

  private async copySegment(read: ReadBytes, fd: number, track: PcmWavTrack, segment: RenderSegment,
    checkpoint?: () => void): Promise<void> {
    let offset = track.dataOffset + segment.sourceStartFrame * track.blockAlign;
    const end = track.dataOffset + segment.sourceEndFrame * track.blockAlign;
    while (offset < end) {
      checkpoint?.();
      const length = Math.min(262144, end - offset);
      const block = await read(offset, length);
      if (block.byteLength !== length) {
        throw new Error('INCOMPLETE_READ');
      }
      await this.writeBlock(fd, block);
      offset += length;
    }
  }

  private async chooseSaveUri(filename: string): Promise<string | undefined> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [filename];
    const targets = await new picker.DocumentViewPicker(this.context).save(options);
    return targets[0];
  }

  async saveCaptionText(id: number, content: string, format: 'srt' | 'vtt' = 'srt'): Promise<boolean> {
    const uri = await this.chooseSaveUri('voxcarve-captions-' + id + '.' + format);
    if (!uri) {
      return false;
    }
    const target = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const bytes = await fileIo.write(target.fd, content);
      if (bytes <= 0 || (await fileIo.stat(target.fd)).size !== bytes) {
        throw new Error('INCOMPLETE_EXPORT');
      }
      await fileIo.fsync(target.fd);
      return true;
    } finally {
      await fileIo.close(target);
    }
  }

  async save(path: string, id: number, filename: string = ''): Promise<number | undefined> {
    const uri = await this.chooseSaveUri(filename || 'voxcarve-cut-' + id + '.wav');
    if (!uri) {
      return undefined;
    }
    const input = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const expected = (await fileIo.stat(input.fd)).size;
      const target = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        const buffer = new ArrayBuffer(262144);
        let copied = 0;
        while (copied < expected) {
          const bytes = await fileIo.read(input.fd, buffer);
          if (bytes <= 0) {
            throw new Error('INCOMPLETE_EXPORT');
          }
          await this.writeBlock(target.fd, buffer.slice(0, bytes));
          copied += bytes;
        }
        await fileIo.fsync(target.fd);
        if (copied !== expected || (await fileIo.stat(target.fd)).size !== expected) {
          throw new Error('INCOMPLETE_EXPORT');
        }
        return copied;
      } finally {
        await fileIo.close(target);
      }
    } finally {
      await fileIo.close(input);
    }
  }

  async play(path: string, status: (state: string) => void): Promise<void> {
    await this.stop();
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    this.playbackFile = file;
    try {
      const player = await media.createAVPlayer();
      this.player = player;
      player.on('error', () => status('播放失败'));
      player.on('stateChange', async (state: media.AVPlayerState) => {
        if (this.player !== player) {
          return;
        }
        try {
          if (state === 'initialized') {
            await player.prepare();
          } else if (state === 'prepared') {
            await player.play();
          } else if (state === 'playing') {
            status('正在播放');
          } else if (state === 'completed') {
            status('播放完成');
          }
        } catch (_) {
          status('播放失败');
        }
      });
      player.fdSrc = { fd: file.fd, offset: 0, length: (await fileIo.stat(file.fd)).size };
    } catch (_) {
      await this.stop();
      throw new Error('PLAYBACK_FAILED');
    }
  }

  async stop(): Promise<void> {
    const player = this.player;
    const file = this.playbackFile;
    this.player = undefined;
    this.playbackFile = undefined;
    try {
      if (player) {
        await player.release();
      }
    } finally {
      if (file) {
        await fileIo.close(file);
      }
    }
  }
}
