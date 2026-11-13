import { spawn } from 'node:child_process';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const chrome = process.argv[2];
const profile = await mkdtemp(join(tmpdir(), 'voxcarve-chrome-'));
const url = pathToFileURL(join(process.cwd(), 'docs/dev/exports/playback-check.html')).href;
const processHandle = spawn(chrome, ['--headless', '--mute-audio', '--autoplay-policy=no-user-gesture-required',
  '--remote-debugging-port=0', '--user-data-dir=' + profile, url], { windowsHide: true, stdio: 'ignore' });
let socket;
try {
  let port;
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0].trim();
      break;
    } catch {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }
  assert.ok(port, 'Chrome debugging endpoint missing');
  const endpoint = 'http://127.0.0.1:' + port;
  const version = await (await fetch(endpoint + '/json/version')).json();
  const targets = await (await fetch(endpoint + '/json/list')).json();
  const target = targets.find(item => item.url === url);
  assert.ok(target, 'Playback document missing');
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  console.log(version.Browser + ' HTMLAudioElement');
  let id = 0;
  for (const name of ['mono-cut.wav', 'stereo-cut.wav']) {
    id++;
    const response = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Playback timed out')), 12000);
      socket.addEventListener('message', function receive(event) {
        const packet = JSON.parse(event.data);
        if (packet.id !== id) return;
        clearTimeout(timer);
        socket.removeEventListener('message', receive);
        resolve(packet.result);
      });
    });
    socket.send(JSON.stringify({ id, method: 'Runtime.evaluate', params: {
      expression: 'window.verifyPlayback(' + JSON.stringify(name) + ')', awaitPromise: true, returnByValue: true
    } }));
    const result = await response;
    assert.ok(!result.exceptionDetails, JSON.stringify(result.exceptionDetails));
    assert.deepEqual(result.result.value, { duration: 1.5, position: 1.5, ended: true });
    console.log(name + ': duration 1.500 s, playback reached the ended event at 1.500 s');
  }
} finally {
  socket?.close();
  processHandle.kill();
}
