export interface PcmWavTrack {
  readonly sampleRate: number;
  readonly channels: number;
  readonly frameCount: number;
  readonly blockAlign: number;
  readonly dataOffset: number;
}

export interface PcmPeak {
  readonly min: number;
  readonly max: number;
}

export type ReadBytes = (offset: number, length: number) => Promise<ArrayBuffer>;

async function readExact(read: ReadBytes, offset: number, length: number): Promise<DataView> {
  const pending: Promise<ArrayBuffer> = read(offset, length);
  const bytes = await pending;
  if (bytes.byteLength !== length) {
    throw new Error('INVALID_WAV');
  }
  return new DataView(bytes);
}

export async function readPcmWav(read: ReadBytes, fileSize: number): Promise<PcmWavTrack> {
  if (fileSize < 12) {
    throw new Error('INVALID_WAV');
  }
  const header = await readExact(read, 0, 12);
  if (header.getUint32(0) !== 0x52494646 || header.getUint32(8) !== 0x57415645) {
    throw new Error('UNSUPPORTED_WAV');
  }
  const riffEnd = header.getUint32(4, true) + 8;
  if (riffEnd > fileSize || riffEnd < 12) {
    throw new Error('INVALID_WAV');
  }
  let channels = 0;
  let sampleRate = 0;
  let blockAlign = 0;
  let dataOffset = 0;
  let dataSize = 0;
  let offset = 12;
  for (let chunks = 0; offset + 8 <= riffEnd && chunks < 4096; chunks++) {
    const chunk = await readExact(read, offset, 8);
    const kind = chunk.getUint32(0);
    const size = chunk.getUint32(4, true);
    const start = offset + 8;
    offset = start + size + (size % 2);
    if (offset > riffEnd) {
      throw new Error('INVALID_WAV');
    }
    if (kind === 0x666d7420 && blockAlign === 0) {
      if (size < 16) {
        throw new Error('INVALID_WAV');
      }
      const format = await readExact(read, start, 16);
      channels = format.getUint16(2, true);
      sampleRate = format.getUint32(4, true);
      blockAlign = format.getUint16(12, true);
      if (format.getUint16(0, true) !== 1 || format.getUint16(14, true) !== 16 ||
        channels < 1 || channels > 2 || sampleRate < 8000 || sampleRate > 192000) {
        throw new Error('UNSUPPORTED_WAV');
      }
      if (blockAlign !== channels * 2 || format.getUint32(8, true) !== sampleRate * blockAlign) {
        throw new Error('INVALID_WAV');
      }
    } else if (kind === 0x64617461 && dataOffset === 0) {
      dataOffset = start;
      dataSize = size;
    }
    if (dataOffset && blockAlign) {
      if (!dataSize || dataSize % blockAlign !== 0) {
        throw new Error('INVALID_WAV');
      }
      return {
        sampleRate: sampleRate, channels: channels, blockAlign: blockAlign,
        frameCount: dataSize / blockAlign, dataOffset: dataOffset
      };
    }
  }
  throw new Error('INVALID_WAV');
}

async function readPeaks(read: ReadBytes, track: PcmWavTrack, bins: number, separate: boolean,
  start: number, endFrame: number): Promise<PcmPeak[][]> {
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(endFrame) ||
    start < 0 || endFrame > track.frameCount || start >= endFrame) {
    throw new RangeError('INVALID_PEAK_RANGE');
  }
  const length = endFrame - start;
  const count = Math.min(bins, length);
  if (!Number.isInteger(count) || count <= 0 || count > 4096) {
    throw new RangeError('INVALID_PEAK_COUNT');
  }
  const lanes: PcmPeak[][] = separate && track.channels === 2 ? [[], []] : [[]];
  for (let index = 0; index < count; index++) {
    let frame = start + Math.floor(index * length / count);
    const end = start + Math.floor((index + 1) * length / count);
    const minima = [32767, 32767];
    const maxima = [-32768, -32768];
    while (frame < end) {
      const frames = Math.min(end - frame, Math.floor(262144 / track.blockAlign));
      const bytes = frames * track.blockAlign;
      const block = await readExact(read, track.dataOffset + frame * track.blockAlign, bytes);
      for (let sample = 0; sample < bytes; sample += 2) {
        const value = block.getInt16(sample, true);
        const lane = lanes.length === 2 ? (sample / 2) % 2 : 0;
        minima[lane] = Math.min(minima[lane], value);
        maxima[lane] = Math.max(maxima[lane], value);
      }
      frame += frames;
    }
    for (let lane = 0; lane < lanes.length; lane++) {
      lanes[lane].push({ min: minima[lane] / 32768, max: maxima[lane] / 32768 });
    }
  }
  return lanes;
}

export async function samplePeaks(read: ReadBytes, track: PcmWavTrack, bins: number): Promise<PcmPeak[]> {
  return (await readPeaks(read, track, bins, false, 0, track.frameCount))[0];
}

export function sampleChannelPeaks(read: ReadBytes, track: PcmWavTrack, bins: number,
  start: number = 0, end?: number): Promise<PcmPeak[][]> {
  return readPeaks(read, track, bins, true, start, end ?? track.frameCount);
}

export function makeWavHeader(sampleRate: number, channels: number, frames: number): ArrayBuffer {
  if (!Number.isSafeInteger(frames) || frames <= 0) {
    throw new Error('EMPTY_RENDER');
  }
  if (!Number.isInteger(sampleRate) || sampleRate < 8000 || sampleRate > 192000 ||
    (channels !== 1 && channels !== 2) || frames > Math.floor((0xffffffff - 36) / (channels * 2))) {
    throw new Error('UNSUPPORTED_WAV');
  }
  const blockAlign = channels * 2;
  const bytes = frames * blockAlign;
  const header = new DataView(new ArrayBuffer(44));
  header.setUint32(0, 0x52494646);
  header.setUint32(4, 36 + bytes, true);
  header.setUint32(8, 0x57415645);
  header.setUint32(12, 0x666d7420);
  header.setUint32(16, 16, true);
  header.setUint16(20, 1, true);
  header.setUint16(22, channels, true);
  header.setUint32(24, sampleRate, true);
  header.setUint32(28, sampleRate * blockAlign, true);
  header.setUint16(32, blockAlign, true);
  header.setUint16(34, 16, true);
  header.setUint32(36, 0x64617461);
  header.setUint32(40, bytes, true);
  return header.buffer;
}

export interface PcmFrameRange {
  readonly startFrame: number;
  readonly endFrame: number;
}

export async function detectQuietRanges(read: ReadBytes, track: PcmWavTrack, minimumMs: number,
  checkpoint?: () => void, thresholdDb: number = -45): Promise<PcmFrameRange[]> {
  const windowFrames = Math.round(track.sampleRate / 50);
  const minimumFrames = Math.ceil(track.sampleRate * minimumMs / 1000);
  const thresholdSquared = Math.pow(32768 * Math.pow(10, thresholdDb / 20), 2);
  const ranges: PcmFrameRange[] = [];
  let quietStart = -1;
  for (let first = 0; first < track.frameCount;) {
    checkpoint?.();
    const frameCount = Math.min(windowFrames * 32, track.frameCount - first);
    const block = await readExact(read, track.dataOffset + first * track.blockAlign, frameCount * track.blockAlign);
    checkpoint?.();
    for (let frame = 0; frame < frameCount; frame += windowFrames) {
      const samples = Math.min(windowFrames, frameCount - frame);
      let maxPower = 0;
      for (let channel = 0; channel < track.channels; channel++) {
        let sum = 0;
        for (let index = 0; index < samples; index++) {
          const value = block.getInt16((frame + index) * track.blockAlign + channel * 2, true);
          sum += value * value;
        }
        maxPower = Math.max(maxPower, sum / samples);
      }
      const position = first + frame;
      if (maxPower <= thresholdSquared) {
        if (quietStart < 0) {
          quietStart = position;
        }
      } else if (quietStart >= 0) {
        if (position - quietStart >= minimumFrames) {
          ranges.push({ startFrame: quietStart, endFrame: position });
        }
        quietStart = -1;
      }
    }
    first += frameCount;
  }
  if (quietStart >= 0 && track.frameCount - quietStart >= minimumFrames) {
    ranges.push({ startFrame: quietStart, endFrame: track.frameCount });
  }
  return ranges;
}
