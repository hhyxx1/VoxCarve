import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { recoverInterruptedMedia } from '../services/TemporaryMediaRecovery';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.recoverAndLoad(windowStage);
  }

  private async recoverAndLoad(windowStage: window.WindowStage): Promise<void> {
    try {
      const removed = await recoverInterruptedMedia(this.context.filesDir, this.context.cacheDir);
      if (removed > 0) {
        hilog.info(0x1000, 'VoxCarveRecovery', 'Removed temporary media files: %{public}d', removed);
      }
    } catch (_) {
      hilog.warn(0x1000, 'VoxCarveRecovery', 'Temporary media recovery could not complete');
    }
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x1000, 'VoxCarveProbe', 'Failed to load page: %{public}d', error.code);
      }
    });
  }
}
