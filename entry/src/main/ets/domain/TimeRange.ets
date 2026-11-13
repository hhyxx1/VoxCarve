import type { CaptionCue, RenderSequence } from './MediaModels';
import { frameToTimeUs, timeUsToFrame } from './EditGraph';

export interface TimeRange {
  readonly startUs: number;
  readonly endUs: number;
}

export function parseTimeRange(start: string, end: string, durationUs: number): TimeRange {
  const valid = /^\d+(\.\d{1,3})?$/;
  if (!valid.test(start.trim()) || !valid.test(end.trim())) {
    throw new RangeError('INVALID_TIME_RANGE');
  }
  const startUs = Math.round(Number(start) * 1000);
  const endUs = Math.round(Number(end) * 1000);
  if (!Number.isSafeInteger(endUs) || startUs >= endUs || endUs > durationUs) {
    throw new RangeError('INVALID_TIME_RANGE');
  }
  return { startUs: startUs, endUs: endUs };
}

export function mapSourceRange(range: TimeRange, sequence: RenderSequence): TimeRange | undefined {
  const sourceStart = timeUsToFrame(range.startUs, sequence.sampleRate);
  const sourceEnd = timeUsToFrame(range.endUs, sequence.sampleRate);
  let first = -1;
  let last = -1;
  for (const segment of sequence.segments) {
    const start = Math.max(sourceStart, segment.sourceStartFrame);
    const end = Math.min(sourceEnd, segment.sourceEndFrame);
    if (start < end) {
      if (first < 0) {
        first = segment.outputStartFrame + start - segment.sourceStartFrame;
      }
      last = segment.outputStartFrame + end - segment.sourceStartFrame;
    }
  }
  if (first < 0) {
    return undefined;
  }
  return { startUs: frameToTimeUs(first, sequence.sampleRate), endUs: frameToTimeUs(last, sequence.sampleRate) };
}

function srtTime(milliseconds: number): string {
  const hours = Math.floor(milliseconds / 3600000).toString().padStart(2, '0');
  const minutes = (Math.floor(milliseconds / 60000) % 60).toString().padStart(2, '0');
  const seconds = (Math.floor(milliseconds / 1000) % 60).toString().padStart(2, '0');
  return hours + ':' + minutes + ':' + seconds + ',' + (milliseconds % 1000).toString().padStart(3, '0');
}

export function encodeSrt(cues: CaptionCue[], durationUs: number): string {
  if (!cues.length) {
    throw new Error('INVALID_CAPTIONS');
  }
  const sorted = cues.slice().sort((a: CaptionCue, b: CaptionCue): number => a.outputStartUs - b.outputStartUs);
  const blocks: string[] = [];
  let previousEnd = 0;
  for (const cue of sorted) {
    const startMs = Math.round(cue.outputStartUs / 1000);
    const endMs = Math.round(cue.outputEndUs / 1000);
    const text = cue.text.trim().replace(/\r\n?|\n/g, '\n').split('\n')
      .filter((line: string): boolean => !!line.trim()).join('\r\n');
    if (!Number.isSafeInteger(cue.outputStartUs) || !Number.isSafeInteger(cue.outputEndUs) ||
      cue.outputStartUs < previousEnd || cue.outputEndUs > durationUs || startMs >= endMs || !text) {
      throw new Error('INVALID_CAPTIONS');
    }
    blocks.push((blocks.length + 1) + '\r\n' + srtTime(startMs) + ' --> ' + srtTime(endMs) + '\r\n' + text + '\r\n\r\n');
    previousEnd = cue.outputEndUs;
  }
  return blocks.join('');
}
