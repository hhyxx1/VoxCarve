import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';

registerHooks({
  load(url, context, nextLoad) {
    if (!url.endsWith('.ets')) return nextLoad(url, context);
    return { format: 'module', source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true };
  }
});
const { readPcmWav, samplePeaks, sampleChannelPeaks, makeWavHeader } =
  await import('../entry/src/main/ets/domain/PcmWav.ets');
const fixtures = new URL('../entry/src/main/resources/rawfile/', import.meta.url);

function fixture(name) {
  return readFileSync(new URL(name, fixtures));
}
function reader(bytes) {
  return async (offset, length) => Uint8Array.from(bytes.subarray(offset, offset + length)).buffer;
}
test('parses both real PCM fixtures and finds the silent half-second', async () => {
  for (const [name, rate, channels] of [['mono-16k.wav', 16000, 1], ['stereo-48k.wav', 48000, 2]]) {
    const data = fixture(name);
    const track = await readPcmWav(reader(data), data.length);
    assert.deepEqual([track.sampleRate, track.channels, track.frameCount], [rate, channels, rate * 2]);
    const peaks = await samplePeaks(reader(data), track, 4);
    assert.ok(peaks[0].max > 0 && peaks[0].min < 0);
    assert.deepEqual(peaks[1], { min: 0, max: 0 });
  }
});

test('a truncated data chunk or non-PCM format is rejected', async () => {
  const data = fixture('mono-16k.wav');
  await assert.rejects(readPcmWav(reader(data.subarray(0, -1)), data.length - 1), /INVALID_WAV/);
  data.writeUInt16LE(3, 20);
  await assert.rejects(readPcmWav(reader(data), data.length), /UNSUPPORTED_WAV/);
});

test('a rendered WAV header reports the exact retained frame count', async () => {
  const original = fixture('stereo-48k.wav');
  const header = Buffer.from(makeWavHeader(48000, 2, 72000));
  const audio = Buffer.concat([header, original.subarray(44, 44 + 96000), original.subarray(44 + 192000)]);
  const parsed = await readPcmWav(reader(audio), audio.length);
  assert.equal(parsed.frameCount, 72000);
  assert.equal(parsed.dataOffset, 44);
  assert.throws(() => makeWavHeader(48000, 2, 0), /EMPTY_RENDER/);
});

test('silence candidates use PCM samples and respect the minimum duration', async () => {
  const { detectQuietRanges } = await import('../entry/src/main/ets/domain/PcmWav.ets');
  for (const name of ['mono-16k.wav', 'stereo-48k.wav']) {
    const data = fixture(name);
    const track = await readPcmWav(reader(data), data.length);
    assert.deepEqual(await detectQuietRanges(reader(data), track, 300), [
      { startFrame: track.sampleRate / 2, endFrame: track.sampleRate }
    ]);
    assert.deepEqual(await detectQuietRanges(reader(data), track, 600), []);
  }
});

test('cancelled PCM analysis discards candidates and stops reading', async () => {
  const { detectQuietRanges } = await import('../entry/src/main/ets/domain/PcmWav.ets');
  const data = fixture('stereo-48k.wav');
  const read = reader(data);
  const track = await readPcmWav(read, data.length);
  let reads = 0;
  await assert.rejects(detectQuietRanges(async (offset, length) => {
    reads++;
    return read(offset, length);
  }, track, 300, () => {
    if (reads === 2) throw new Error('TASK_CANCELLED');
  }), /TASK_CANCELLED/);
  assert.equal(reads, 2);
});

test('zoom reads only the requested real PCM frames and preserves channels', async () => {
  const data = fixture('stereo-48k.wav');
  const track = await readPcmWav(reader(data), data.length);
  const ranges = [];
  const read = async (offset, length) => {
    ranges.push([offset, length]);
    return reader(data)(offset, length);
  };
  const lanes = await sampleChannelPeaks(read, track, 4, 24000, 48000);
  assert.equal(lanes.length, 2);
  assert.deepEqual(lanes[0], Array(4).fill({ min: 0, max: 0 }));
  assert.deepEqual(lanes[1], lanes[0]);
  assert.equal(ranges[0][0], track.dataOffset + 24000 * track.blockAlign);
  assert.equal(ranges.at(-1)[0] + ranges.at(-1)[1], track.dataOffset + 48000 * track.blockAlign);
  await assert.rejects(sampleChannelPeaks(read, track, 4, 48000, 48000), /INVALID_PEAK_RANGE/);
});
