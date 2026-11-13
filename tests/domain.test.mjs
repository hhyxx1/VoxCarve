import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';

registerHooks({
  load(url, context, nextLoad) {
    if (url.endsWith('.ets')) {
      return {
        format: 'module',
        source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')),
        shortCircuit: true
      };
    }
    return nextLoad(url, context);
  }
});

const domain = '../entry/src/main/ets/domain/';
const { EditGraph, frameToTimeUs, timeUsToFrame } = await import(domain + 'EditGraph.ets');
const { RenderTask, TaskStatus } = await import(domain + 'RenderTask.ets');

test('adjacent output slices meet exactly after overlapping source removals', () => {
  const graph = new EditGraph(48000, 48000);
  const edited = graph.remove('first', 4800, 14400, 1).remove('second', 9600, 19200, 2);
  assert.deepEqual(edited.render('pcm').segments.map(s => [
    s.sourceStartFrame, s.sourceEndFrame, s.outputStartFrame, s.outputStartUs
  ]), [[0, 4800, 0, 0], [19200, 48000, 4800, 100000]]);
  assert.equal(edited.render('pcm').totalFrames, 33600);
  assert.equal(graph.render('pcm').totalFrames, 48000);
});

test('undo, redo, and branching preserve prior graphs and drop the new branch redo tail', () => {
  const graph = new EditGraph(16000, 16000).remove('first', 0, 1000, 1);
  const edited = graph.remove('second', 2000, 3000, 2);
  const undone = edited.undo();
  assert.equal(undone.render('pcm').totalFrames, 15000);
  assert.equal(undone.redo().render('pcm').totalFrames, 14000);
  assert.equal(undone.remove('third', 4000, 7000, 3).redo().render('pcm').totalFrames, 12000);
  assert.equal(edited.render('pcm').totalFrames, 14000);
});

test('44100 Hz boundaries round-trip and invalid intervals fail', () => {
  for (const frame of [0, 1, 2, 441, 44101, 79380000]) {
    assert.equal(timeUsToFrame(frameToTimeUs(frame, 44100), 44100), frame);
  }
  assert.equal(frameToTimeUs(44101, 44100), 1000023);
  assert.throws(() => new EditGraph(44100, 10).remove('bad', 2, 11, 1), RangeError);
  assert.throws(() => new EditGraph(44100, 10).remove('bad', 2, 2, 1), RangeError);
  assert.equal(new EditGraph(44100, 10).remove('all', 0, 10, 1).render('pcm').segments.length, 0);
});

test('cancelling during verification forbids success and leaves the old task intact', () => {
  const running = new RenderTask('render-1').transition(TaskStatus.Validating)
    .transition(TaskStatus.Queued).transition(TaskStatus.Running, 0.2)
    .transition(TaskStatus.Verifying, 0.95);
  assert.throws(() => running.transition(TaskStatus.Success, 1));
  const cancelled = running.transition(TaskStatus.Cancelling).transition(TaskStatus.Cancelled);
  assert.equal(cancelled.status, TaskStatus.Cancelled);
  assert.throws(() => cancelled.transition(TaskStatus.Success, 1, 'test.wav'));
  assert.equal(running.status, TaskStatus.Verifying);
  assert.equal(running.transition(TaskStatus.Success, 1, 'test.wav').outputUri, 'test.wav');
});


test('restoring an undone revision preserves both the cursor and the redo path', () => {
  const old = new EditGraph(16000, 16000).remove('a', 0, 1000, 1).remove('b', 2000, 3000, 2).undo();
  const snapshot = JSON.parse(JSON.stringify(old.snapshot()));
  const restored = EditGraph.restore(snapshot);
  snapshot.decisions[0].sourceEndFrame = 8000;
  assert.equal(restored.render('pcm').totalFrames, 15000);
  assert.equal(restored.redo().render('pcm').totalFrames, 14000);
});

test('retaining a source interval is reversible and respects existing removals', () => {
  const graph = new EditGraph(48000, 48000).remove('remove', 12000, 24000, 1);
  const retained = graph.retain('retain', 6000, 36000, 2);
  assert.deepEqual(retained.render('pcm').segments.map(s => [s.sourceStartFrame, s.sourceEndFrame]), [
    [6000, 12000], [24000, 36000]
  ]);
  assert.equal(retained.undo().render('pcm').totalFrames, 36000);
  assert.equal(retained.redo().render('pcm').totalFrames, 18000);
});
