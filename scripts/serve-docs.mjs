import { spawnSync, spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const candidates = process.env.STUDY_APP_PYTHON ? [process.env.STUDY_APP_PYTHON] : ['python3', 'python', path.resolve(root, '../../.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')];
const python = candidates.find((command) => spawnSync(command, ['--version'], { stdio: 'ignore' }).status === 0);
if (!python) { console.error('Python 3が必要です。STUDY_APP_PYTHONで指定してください。'); process.exit(1); }
const child = spawn(python, ['-m', 'http.server', '8000', '--directory', 'docs', '--bind', '127.0.0.1'], { cwd: root, stdio: 'inherit' });
child.on('close', (code) => { process.exitCode = code ?? 1; });
child.on('error', (error) => { console.error(error.message); process.exitCode = 1; });
