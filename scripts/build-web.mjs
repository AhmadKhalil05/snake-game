// Rebuild from the Lua source at the repository root. Requires Node.js and zip.
import { mkdtempSync, cpSync, readdirSync, rmSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const staging = mkdtempSync(join(tmpdir(), 'snake-web-'));
const game = join(staging, 'game');
const archive = join(staging, 'Snake.love');
const web = join(root, 'web');
const runtimeCommit = 'c4f04e185033a7c9fbefa9be3bec88c41a90421b';
const runtime = `git+https://github.com/Davidobot/love.js.git#${runtimeCommit}`;

function run(command, args, cwd = root) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status})`);
}

try {
  mkdirSync(game);
  for (const entry of readdirSync(root)) {
    if (entry.endsWith('.lua') || entry === 'states') cpSync(join(root, entry), join(game, entry), { recursive: true });
  }
  run('zip', ['-q', '-9', '-r', archive, '.'], game);
  cpSync(archive, join(root, 'Snake.love'));
  run(process.platform === 'win32' ? 'npx.cmd' : 'npx', [
    '--yes', `--package=${runtime}`, 'love.js', '-c', '-t', 'Snake: Neon Runner',
    '-m', '67108864', archive, web
  ]);
  cpSync(join(root, 'web-template'), web, { recursive: true });
  console.log('Web build complete. Cloudflare Pages output directory: web');
} finally {
  rmSync(staging, { recursive: true, force: true });
}
