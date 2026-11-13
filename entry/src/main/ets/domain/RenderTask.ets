export class TaskStatus {
  static readonly New = 'new';
  static readonly Validating = 'validating';
  static readonly Queued = 'queued';
  static readonly Running = 'running';
  static readonly Verifying = 'verifying';
  static readonly Cancelling = 'cancelling';
  static readonly Cancelled = 'cancelled';
  static readonly Unsupported = 'unsupported';
  static readonly Failed = 'failed';
  static readonly Success = 'success';
}

export class RenderTask {
  readonly id: string;
  private currentStatus: string = TaskStatus.New;
  private currentProgress: number = 0;
  private currentOutputUri?: string;
  private currentErrorCode?: string;
  private started?: number;
  private finished?: number;

  constructor(id: string) {
    this.id = id;
  }

  get status(): string { return this.currentStatus; }
  get progress(): number { return this.currentProgress; }
  get outputUri(): string | undefined { return this.currentOutputUri; }
  get errorCode(): string | undefined { return this.currentErrorCode; }
  get startedAtMs(): number | undefined { return this.started; }
  get finishedAtMs(): number | undefined { return this.finished; }

  transition(next: string, progress: number = this.progress, outputUri?: string, errorCode?: string): RenderTask {
    if (!this.canTransition(next) || !Number.isFinite(progress) || progress < this.progress ||
      progress > 1 || (next === TaskStatus.Success ? progress !== 1 || !outputUri?.trim() : progress === 1 || !!outputUri) ||
      ((next === TaskStatus.Failed || next === TaskStatus.Unsupported) && !errorCode?.trim())) {
      throw new Error('INVALID_TASK_TRANSITION');
    }
    const task = new RenderTask(this.id);
    task.currentStatus = next;
    task.currentProgress = progress;
    task.currentOutputUri = outputUri;
    task.currentErrorCode = errorCode;
    task.started = this.started ?? (next === TaskStatus.Running ? Date.now() : undefined);
    if (next === TaskStatus.Success || next === TaskStatus.Failed ||
      next === TaskStatus.Unsupported || next === TaskStatus.Cancelled) {
      task.finished = Date.now();
    }
    return task;
  }

  private canTransition(next: string): boolean {
    switch (this.status) {
      case TaskStatus.New:
        return next === TaskStatus.Validating || next === TaskStatus.Cancelled;
      case TaskStatus.Validating:
        return next === TaskStatus.Queued || next === TaskStatus.Unsupported ||
          next === TaskStatus.Failed || next === TaskStatus.Cancelled;
      case TaskStatus.Queued:
        return next === TaskStatus.Running || next === TaskStatus.Cancelled || next === TaskStatus.Failed;
      case TaskStatus.Running:
        return next === TaskStatus.Running || next === TaskStatus.Verifying ||
          next === TaskStatus.Cancelling || next === TaskStatus.Failed;
      case TaskStatus.Verifying:
        return next === TaskStatus.Success || next === TaskStatus.Cancelling || next === TaskStatus.Failed;
      case TaskStatus.Cancelling:
        return next === TaskStatus.Cancelled || next === TaskStatus.Failed;
      default:
        return false;
    }
  }
}
