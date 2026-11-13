export const runProbe: (fd: number, offset: number, length: number, cacheDir: string) => number;
export const decodeAudio: (inputFd: number, length: number, outputFd: number) => Promise<number>;
