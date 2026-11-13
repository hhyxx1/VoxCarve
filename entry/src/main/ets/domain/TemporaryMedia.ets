export function isStagedImport(name: string): boolean {
  return /^project-[1-9][0-9]*\.wav\.(importing|decoding)(?![\s\S])/.test(name);
}

export function isRenderCache(name: string): boolean {
  return /^voxcarve-render-[1-9][0-9]*-[0-9]+-[0-9]+\.wav(?![\s\S])/.test(name);
}
