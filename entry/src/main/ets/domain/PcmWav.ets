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
  const bytes = await read(offset, length);
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

export async function samplePeaks(read: ReadBytes, track: PcmWavTrack, bins: number): Promise<PcmPeak[]> {
  const count = Math.min(bins, track.frameCount);
  if (!Number.isInteger(count) || count <= 0 || count > 4096) {
    throw new RangeError('INVALID_PEAK_COUNT');
  }
  const peaks: PcmPeak[] = [];
  for (let index = 0; index < count; index++) {
    let frame = Math.floor(index * track.frameCount / count);
    const end = Math.floor((index + 1) * track.frameCount / count);
    let min = 32767;
    let max = -32768;
    while (frame < end) {
      const frames = Math.min(end - frame, Math.floor(262144 / track.blockAlign));
      const bytes = frames * track.blockAlign;
      const block = await readExact(read, track.dataOffset + frame * track.blockAlign, bytes);
      for (let sample = 0; sample < bytes; sample += 2) {
        const value = block.getInt16(sample, true);
        min = Math.min(min, value);
        max = Math.max(max, value);
      }
      frame += frames;
    }
    peaks.push({ min: min / 32768, max: max / 32768 });
  }
  return peaks;
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
