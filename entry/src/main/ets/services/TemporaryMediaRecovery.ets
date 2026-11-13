import { fileIo } from '@kit.CoreFileKit';
import { isRenderCache, isStagedImport } from '../domain/TemporaryMedia';

export async function recoverInterruptedMedia(filesDir: string, cacheDir: string): Promise<number> {
  const counts = await Promise.all([
    sweep(filesDir, isStagedImport),
    sweep(cacheDir, isRenderCache)
  ]);
  return counts[0] + counts[1];
}

async function sweep(directory: string, matches: (name: string) => boolean): Promise<number> {
  const names = await fileIo.listFile(directory);
  let removed = 0;
  for (const name of names) {
    if (!matches(name)) {
      continue;
    }
    const path = directory + '/' + name;
    try {
      if ((await fileIo.lstat(path)).isFile()) {
        await fileIo.unlink(path);
        removed++;
      }
    } catch (_) {
      // A single inaccessible entry should not prevent recovery of the others.
    }
  }
  return removed;
}
