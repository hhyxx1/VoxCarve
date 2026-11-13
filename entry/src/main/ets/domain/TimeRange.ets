import type { CaptionCue, RenderSequence, TranscriptSegment } from './MediaModels';
import { frameToTimeUs, timeUsToFrame } from './EditGraph';

export interface TimeRange {
  readonly startUs: number;
  readonly endUs: number;
}

export function transcriptAtRange(segments: TranscriptSegment[], range: TimeRange): TranscriptSegment | undefined {
  let best: TranscriptSegment | undefined;
  let longest = 0;
  for (const segment of segments) {
    if (segment.verified && segment.sourceStartUs !== undefined && segment.sourceEndUs !== undefined) {
      const overlap = Math.min(range.endUs, segment.sourceEndUs) - Math.max(range.startUs, segment.sourceStartUs);
      if (overlap > longest) {
        best = segment;
        longest = overlap;
      }
    }
  }
  return best;
}

export function captionTimelineKey(sequence: RenderSequence): string {
  const boundaries: number[] = [];
  for (const segment of sequence.segments) {
    const last = boundaries.length - 1;
    if (last >= 0 && boundaries[last] === segment.sourceStartFrame) {
      boundaries[last] = segment.sourceEndFrame;
    } else {
      boundaries.push(segment.sourceStartFrame, segment.sourceEndFrame);
    }
  }
  return sequence.sampleRate + ':' + boundaries.join(',');
}

export function verifyCaptionTimeline(cues: CaptionCue[], sequence: RenderSequence): void {
  const key = captionTimelineKey(sequence);
  if (cues.some((cue: CaptionCue): boolean => cue.timelineKey !== key)) {
    throw new Error('CAPTION_TIMELINE_CHANGED');
  }
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

function subtitleTime(milliseconds: number, separator: string): string {
  const hours = Math.floor(milliseconds / 3600000).toString().padStart(2, '0');
  const minutes = (Math.floor(milliseconds / 60000) % 60).toString().padStart(2, '0');
  const seconds = (Math.floor(milliseconds / 1000) % 60).toString().padStart(2, '0');
  return hours + ':' + minutes + ':' + seconds + separator + (milliseconds % 1000).toString().padStart(3, '0');
}

export function encodeSrt(cues: CaptionCue[], durationUs: number): string {
  return encodeCaptions(cues, durationUs, false);
}

export function encodeVtt(cues: CaptionCue[], durationUs: number): string {
  return encodeCaptions(cues, durationUs, true);
}

function encodeCaptions(cues: CaptionCue[], durationUs: number, webVtt: boolean): string {
  if (!cues.length) {
    throw new Error('INVALID_CAPTIONS');
  }
  const sorted = cues.slice().sort((a: CaptionCue, b: CaptionCue): number => a.outputStartUs - b.outputStartUs);
  const blocks: string[] = [];
  let previousEnd = 0;
  for (const cue of sorted) {
    const startMs = Math.round(cue.outputStartUs / 1000);
    const endMs = Math.round(cue.outputEndUs / 1000);
    const newline = webVtt ? '\n' : '\r\n';
    const separator = webVtt ? '.' : ',';
    const text = cue.text.trim().replace(/\r\n?|\n/g, '\n').split('\n')
      .filter((line: string): boolean => !!line.trim()).join(newline);
    if (!Number.isSafeInteger(cue.outputStartUs) || !Number.isSafeInteger(cue.outputEndUs) ||
      cue.outputStartUs < previousEnd || cue.outputEndUs > durationUs || startMs >= endMs || !text) {
      throw new Error('INVALID_CAPTIONS');
    }
    const payload = webVtt ? text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : text;
    const index = webVtt ? '' : (blocks.length + 1) + newline;
    blocks.push(index + subtitleTime(startMs, separator) + ' --> ' + subtitleTime(endMs, separator) +
      newline + payload + newline + newline);
    previousEnd = cue.outputEndUs;
  }
  return (webVtt ? 'WEBVTT\n\n' : '') + blocks.join('');
}
