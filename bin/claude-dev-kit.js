#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const os = require('os');

const kitRoot = path.join(__dirname, '..');
const args = process.argv.slice(2);

// ── Non-Windows: always use bash ─────────────────────────────────────────────
if (os.platform() !== 'win32') {
  const scriptPath = path.join(kitRoot, 'scripts', 'install.sh');
  const result = spawnSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
  process.exit(result.status ?? 1);
}

// ── Windows: try bash (Git Bash / WSL) first, then PowerShell ────────────────
function hasBash() {
  const r = spawnSync('bash', ['--version'], { stdio: 'pipe' });
  return r.status === 0;
}

if (hasBash()) {
  const scriptPath = path.join(kitRoot, 'scripts', 'install.sh');
  const result = spawnSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
  process.exit(result.status ?? 1);
}

// No bash — fall back to PowerShell
const ps1Path = path.join(kitRoot, 'scripts', 'install.ps1');

// Translate CLI args to PowerShell param style
// e.g. --mcp-only -> -McpOnly, positional target dir stays positional
const psArgs = ['-ExecutionPolicy', 'Bypass', '-File', ps1Path];
for (const arg of args) {
  if (arg === '--mcp-only') {
    psArgs.push('-McpOnly');
  } else {
    psArgs.push(arg);
  }
}

// Prefer pwsh (PowerShell 7+) over legacy powershell.exe (5.x)
const pwsh = spawnSync('pwsh', ['--version'], { stdio: 'pipe' }).status === 0
  ? 'pwsh'
  : 'powershell';

const result = spawnSync(pwsh, psArgs, { stdio: 'inherit' });
process.exit(result.status ?? 1);
