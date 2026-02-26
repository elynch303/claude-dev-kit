#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');

const scriptPath = path.join(__dirname, '..', 'scripts', 'install.sh');
const args = process.argv.slice(2); // forward flags like --mcp-only

const result = spawnSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
process.exit(result.status ?? 1);
