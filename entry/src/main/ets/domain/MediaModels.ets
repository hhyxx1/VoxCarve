export interface MediaProject {
  readonly id: number;
  readonly name: string;
  readonly createdAtMs: number;
  readonly updatedAtMs: number;
}

export interface SourceTrack {
  readonly id: string;
  readonly kind: 'audio' | 'video';
  readonly assetPath: string;
  readonly codecMime: string;
  readonly offsetUs: number;
  readonly durationUs: number;
  readonly sampleRate?: number;
  readonly channels?: number;
  readonly frameCount?: number;
}

export interface TranscriptSegment {
  readonly id: string;
  readonly trackId: string;
  readonly text: string;
  readonly speaker: string;
  readonly sourceStartUs?: number;
  readonly sourceEndUs?: number;
  readonly timeSource: 'unbound' | 'manual' | 'aligned' | 'sdk';
  readonly verified: boolean;
}

export type EditMode = 'remove' | 'retain' | 'split' | 'fade';

export interface EditDecision {
  readonly id: string;
  readonly mode: EditMode;
  readonly sourceStartFrame: number;
  readonly sourceEndFrame: number;
  readonly createdAtMs: number;
}

export interface RenderSegment {
  readonly sourceStartFrame: number;
  readonly sourceEndFrame: number;
  readonly outputStartFrame: number;
  readonly outputStartUs: number;
}

export interface RenderSequence {
  readonly trackId: string;
  readonly sampleRate: number;
  readonly totalFrames: number;
  readonly segments: ReadonlyArray<RenderSegment>;
}

export interface CaptionCue {
  readonly id: string;
  readonly transcriptSegmentId?: string;
  readonly timelineKey?: string;
  readonly outputStartUs: number;
  readonly outputEndUs: number;
  readonly text: string;
}
