import type { EditDecision, EditMode, RenderSegment, RenderSequence } from './MediaModels';

const MICROSECONDS_PER_SECOND = 1000000;

function validatePosition(position: number, sampleRate: number): void {
  if (!Number.isSafeInteger(position) || position < 0 ||
    !Number.isInteger(sampleRate) || sampleRate < 1 || sampleRate > MICROSECONDS_PER_SECOND) {
    throw new RangeError('INVALID_TIME_POSITION');
  }
}

export function frameToTimeUs(frame: number, sampleRate: number): number {
  validatePosition(frame, sampleRate);
  const seconds = Math.floor(frame / sampleRate);
  const timeUs = seconds * MICROSECONDS_PER_SECOND +
    Math.round((frame % sampleRate) * MICROSECONDS_PER_SECOND / sampleRate);
  validatePosition(timeUs, sampleRate);
  return timeUs;
}

export function timeUsToFrame(timeUs: number, sampleRate: number): number {
  validatePosition(timeUs, sampleRate);
  return Math.floor(timeUs / MICROSECONDS_PER_SECOND) * sampleRate +
    Math.round((timeUs % MICROSECONDS_PER_SECOND) * sampleRate / MICROSECONDS_PER_SECOND);
}

export interface EditHistorySnapshot {
  readonly sampleRate: number;
  readonly sourceFrameCount: number;
  readonly decisions: ReadonlyArray<EditDecision>;
  readonly cursor: number;
}

function copyDecision(decision: EditDecision): EditDecision {
  return {
    id: decision.id, mode: decision.mode, sourceStartFrame: decision.sourceStartFrame,
    sourceEndFrame: decision.sourceEndFrame, createdAtMs: decision.createdAtMs
  };
}

export class EditGraph {
  private decisions: ReadonlyArray<EditDecision> = [];
  private cursor: number = 0;
  readonly sampleRate: number;
  readonly sourceFrameCount: number;

  constructor(sampleRate: number, sourceFrameCount: number) {
    frameToTimeUs(sourceFrameCount, sampleRate);
    this.sampleRate = sampleRate;
    this.sourceFrameCount = sourceFrameCount;
  }

  static restore(snapshot: EditHistorySnapshot): EditGraph {
    const graph = new EditGraph(snapshot.sampleRate, snapshot.sourceFrameCount);
    if (!Number.isInteger(snapshot.cursor) || snapshot.cursor < 0 || snapshot.cursor > snapshot.decisions.length) {
      throw new RangeError('INVALID_HISTORY_CURSOR');
    }
    const ids = new Set<string>();
    for (const decision of snapshot.decisions) {
      graph.validateDecision(decision);
      if (ids.has(decision.id)) {
        throw new Error('DUPLICATE_EDIT_ID');
      }
      ids.add(decision.id);
    }
    return graph.withHistory(snapshot.decisions.map(copyDecision), snapshot.cursor);
  }

  snapshot(): EditHistorySnapshot {
    return {
      sampleRate: this.sampleRate, sourceFrameCount: this.sourceFrameCount, cursor: this.cursor,
      decisions: this.decisions.map(copyDecision)
    };
  }

  private validateDecision(decision: EditDecision): void {
    if (!decision.id.trim() || !Number.isSafeInteger(decision.createdAtMs) || decision.createdAtMs < 0 ||
      (decision.mode !== 'remove' && decision.mode !== 'retain')) {
      throw new Error('INVALID_EDIT_METADATA');
    }
    const start = decision.sourceStartFrame;
    const end = decision.sourceEndFrame;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) ||
      start < 0 || start >= end || end > this.sourceFrameCount) {
      throw new RangeError('INVALID_EDIT_RANGE');
    }
  }

  remove(id: string, start: number, end: number, createdAtMs: number): EditGraph {
    return this.add('remove', id, start, end, createdAtMs);
  }

  retain(id: string, start: number, end: number, createdAtMs: number): EditGraph {
    return this.add('retain', id, start, end, createdAtMs);
  }

  private add(mode: EditMode, id: string, start: number, end: number, createdAtMs: number): EditGraph {
    const entry: EditDecision = {
      id: id, mode: mode, sourceStartFrame: start, sourceEndFrame: end, createdAtMs: createdAtMs
    };
    this.validateDecision(entry);
    const active = this.decisions.slice(0, this.cursor);
    if (active.some((decision: EditDecision): boolean => decision.id === id)) {
      throw new Error('DUPLICATE_EDIT_ID');
    }
    active.push(entry);
    return this.withHistory(active, active.length);
  }

  undo(): EditGraph {
    return this.withHistory(this.decisions, Math.max(0, this.cursor - 1));
  }

  redo(): EditGraph {
    return this.withHistory(this.decisions, Math.min(this.decisions.length, this.cursor + 1));
  }

  private withHistory(decisions: ReadonlyArray<EditDecision>, cursor: number): EditGraph {
    const graph = new EditGraph(this.sampleRate, this.sourceFrameCount);
    graph.decisions = decisions;
    graph.cursor = cursor;
    return graph;
  }

  render(trackId: string): RenderSequence {
    const removed: EditDecision[] = [];
    let sourceFrame = 0;
    let sourceEnd = this.sourceFrameCount;
    for (let index = 0; index < this.cursor; index++) {
      const decision = this.decisions[index];
      if (decision.mode === 'retain') {
        sourceFrame = Math.max(sourceFrame, decision.sourceStartFrame);
        sourceEnd = Math.min(sourceEnd, decision.sourceEndFrame);
      } else {
        removed.push(decision);
      }
    }
    removed.sort((a: EditDecision, b: EditDecision): number => a.sourceStartFrame - b.sourceStartFrame);
    const segments: RenderSegment[] = [];
    let outputFrame = 0;
    for (const decision of removed) {
      if (sourceFrame >= sourceEnd || decision.sourceStartFrame >= sourceEnd) {
        break;
      }
      if (sourceFrame < decision.sourceStartFrame) {
        segments.push(this.segment(sourceFrame, decision.sourceStartFrame, outputFrame));
        outputFrame += decision.sourceStartFrame - sourceFrame;
      }
      sourceFrame = Math.max(sourceFrame, decision.sourceEndFrame);
    }
    if (sourceFrame < sourceEnd) {
      segments.push(this.segment(sourceFrame, sourceEnd, outputFrame));
      outputFrame += sourceEnd - sourceFrame;
    }
    return { trackId: trackId, sampleRate: this.sampleRate, totalFrames: outputFrame, segments: segments };
  }

  private segment(start: number, end: number, output: number): RenderSegment {
    return {
      sourceStartFrame: start, sourceEndFrame: end, outputStartFrame: output,
      outputStartUs: frameToTimeUs(output, this.sampleRate)
    };
  }
}
