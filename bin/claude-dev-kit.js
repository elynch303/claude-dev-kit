#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

const kitRoot = path.join(__dirname, '..');
const argv = process.argv.slice(2);

function printHelp() {
  console.log(`
Claude Dev Kit — CLI

Usage:
  claude-dev-kit <command> [target] [options]

Commands:
  install [target]   Full install: copy .claude/, install hook deps, run MCP wizard
  update  [target]   Migration only: pull in new agents/skills/hooks without prompts
  mcp     [target]   Run the MCP wizard only (configure integrations)
  version            Print the installed kit version
  help               Print this help summary

Options:
  --help             Print usage for any subcommand

Environment:
  CI=true            Run install/update non-interactively (skip all prompts)
  TARGET=<path>      Alternative to passing target as a positional argument

Examples:
  bunx claude-dev-kit@latest install
  bunx claude-dev-kit@latest install /path/to/project
  bunx claude-dev-kit@latest update
  bunx claude-dev-kit@latest mcp
  bunx claude-dev-kit@latest version
  CI=true bunx claude-dev-kit@latest install
`.trim());
}

function printVersion() {
  const pkgPath = path.join(kitRoot, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  console.log(pkg.version);
}

function runScript(phase, scriptArgs) {
  const scriptPath = path.join(kitRoot, 'scripts', 'install.sh');

  if (os.platform() !== 'win32') {
    const result = spawnSync('bash', [scriptPath, `--phase=${phase}`, ...scriptArgs], { stdio: 'inherit' });
    process.exit(result.status ?? 1);
  }

  // ── Windows: try bash (Git Bash / WSL) first, then PowerShell ──────────────
  function hasBash() {
    return spawnSync('bash', ['--version'], { stdio: 'pipe' }).status === 0;
  }

  if (hasBash()) {
    const result = spawnSync('bash', [scriptPath, `--phase=${phase}`, ...scriptArgs], { stdio: 'inherit' });
    process.exit(result.status ?? 1);
  }

  // No bash — fall back to PowerShell (install and mcp phases only)
  const ps1Path = path.join(kitRoot, 'scripts', 'install.ps1');
  const psArgs = ['-ExecutionPolicy', 'Bypass', '-File', ps1Path];
  if (phase === 'mcp') psArgs.push('-McpOnly');
  for (const arg of scriptArgs) psArgs.push(arg);

  const pwsh = spawnSync('pwsh', ['--version'], { stdio: 'pipe' }).status === 0 ? 'pwsh' : 'powershell';
  const result = spawnSync(pwsh, psArgs, { stdio: 'inherit' });
  process.exit(result.status ?? 1);
}

// ── Parse subcommand ──────────────────────────────────────────────────────────
const [subcommand, ...rest] = argv;

if (!subcommand || subcommand === '--help' || subcommand === '-h' || subcommand === 'help') {
  printHelp();
  process.exit(0);
}

if (subcommand === 'version' || subcommand === '--version' || subcommand === '-v') {
  printVersion();
  process.exit(0);
}

if (rest.includes('--help') || rest.includes('-h')) {
  printHelp();
  process.exit(0);
}

switch (subcommand) {
  case 'install':
    runScript('install', rest);
    break;
  case 'update':
    runScript('update', rest);
    break;
  case 'mcp':
    runScript('mcp', rest);
    break;
  default:
    console.error(`Unknown command: ${subcommand}`);
    console.error('Run "claude-dev-kit help" for usage.');
    process.exit(1);
}
