import { speechRecognizer } from '@kit.CoreSpeechKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import type { ReadBytes } from '../domain/PcmWav';

const CHUNK_BYTES = 640;
let nextSession = 0;

export interface OfflineSpeechResult {
  readonly text: string;
  readonly inputComplete: boolean;
}

export async function recognizeMandarin(read: ReadBytes, offset: number, length: number,
  checkpoint: () => void): Promise<OfflineSpeechResult> {
  if (!canIUse('SystemCapability.AI.SpeechRecognizer')) {
    throw new Error('SPEECH_UNSUPPORTED');
  }
  checkpoint();
  const engine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 1 });
  const session = 'voxcarve-' + Date.now() + '-' + nextSession++;
  try {
    checkpoint();
    return await runSession(engine, session, read, offset, length, checkpoint);
  } finally {
    try {
      engine.shutdown();
    } catch (_) {
      // The recognition service may already have terminated the engine.
    }
  }
}

function runSession(engine: speechRecognizer.SpeechRecognitionEngine, session: string, read: ReadBytes,
  offset: number, length: number, checkpoint: () => void): Promise<OfflineSpeechResult> {
  return new Promise<OfflineSpeechResult>((resolve, reject) => {
    let settled = false;
    let started = false;
    let sent = false;
    const clauses: string[] = [];
    let guard = -1;
    let deadline = -1;

    const cleanup = (): void => {
      settled = true;
      clearInterval(guard);
      clearTimeout(deadline);
    };
    const fail = (code: string): void => {
      if (settled) {
        return;
      }
      cleanup();
      if (started) {
        try {
          engine.cancel(session);
        } catch (_) {
          // onError may mean the session is already closed.
        }
      }
      reject(new Error(code));
    };
    const feed = async (): Promise<void> => {
      try {
        for (let position = 0; position < length; position += CHUNK_BYTES) {
          if (settled) {
            return;
          }
          checkpoint();
          const size = Math.min(CHUNK_BYTES, length - position);
          const data = await read(offset + position, size);
          if (settled) {
            return;
          }
          checkpoint();
          if (data.byteLength !== size) {
            fail('SPEECH_INPUT_TRUNCATED');
            return;
          }
          const packet = new Uint8Array(CHUNK_BYTES);
          packet.set(new Uint8Array(data));
          engine.writeAudio(session, packet);
          if (position + size >= length) {
            sent = true;
          }
          await new Promise<void>((resume) => { setTimeout(resume, 20); });
        }
        if (!settled) {
          checkpoint();
          engine.finish(session);
        }
      } catch (error) {
        const issue = error as BusinessError;
        fail(issue.message === 'TASK_CANCELLED' ? 'TASK_CANCELLED' : 'SPEECH_' + (issue.code ?? 'INPUT_FAILED'));
      }
    };
    guard = setInterval(() => {
      try {
        checkpoint();
      } catch (_) {
        fail('TASK_CANCELLED');
      }
    }, 100);
    deadline = setTimeout(() => fail('SPEECH_TIMEOUT'), Math.ceil(length / 32) + 15000);
    try {
      const listener: speechRecognizer.RecognitionListener = {
        onStart: (id: string, _message: string): void => {
          if (id === session && !settled && !started) {
            started = true;
            feed();
          }
        },
        onEvent: (_id: string, _code: number, _message: string): void => {},
        onResult: (id: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          if (id === session && !settled && result.isFinal && result.result.trim()) {
            clauses.push(result.result.trim());
          }
        },
        onComplete: (id: string, _message: string): void => {
          if (id === session && !settled) {
            try {
              checkpoint();
            } catch (_) {
              fail('TASK_CANCELLED');
              return;
            }
            if (!sent && !clauses.length) {
              fail('SPEECH_EARLY_COMPLETION');
              return;
            }
            cleanup();
            resolve({ text: clauses.join(''), inputComplete: sent });
          }
        },
        onError: (id: string, code: number, _message: string): void => {
          if (id === session) {
            fail('SPEECH_' + code);
          }
        }
      };
      engine.setListener(listener);
      engine.startListening({
        sessionId: session,
        audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 }
      });
    } catch (error) {
      fail('SPEECH_' + ((error as BusinessError).code ?? 'START_FAILED'));
    }
  });
}
