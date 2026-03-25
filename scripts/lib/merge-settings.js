#!/usr/bin/env node
// scripts/lib/merge-settings.js
// Merges CDK's settings.json into a user's existing settings.json.
//
// Usage: node merge-settings.js <user-settings-path> <cdk-settings-path>
// Output: merged JSON on stdout
//
// Merge rules:
//   permissions.allow — union (add CDK entries not already present)
//   permissions.deny  — union (add CDK entries not already present)
//   hooks             — per-event: add CDK hook commands not already present
//                       (dedup key: command string, trimmed)
//   All other user settings are preserved unchanged.

'use strict';

const fs = require('fs');

const [, , userPath, cdkPath] = process.argv;

if (!userPath || !cdkPath) {
  process.stderr.write('Usage: node merge-settings.js <user-settings-path> <cdk-settings-path>\n');
  process.exit(1);
}

let user, cdk;
try {
  user = JSON.parse(fs.readFileSync(userPath, 'utf8'));
} catch (e) {
  process.stderr.write(`Failed to parse user settings at ${userPath}: ${e.message}\n`);
  process.exit(1);
}
try {
  cdk = JSON.parse(fs.readFileSync(cdkPath, 'utf8'));
} catch (e) {
  process.stderr.write(`Failed to parse CDK settings at ${cdkPath}: ${e.message}\n`);
  process.exit(1);
}

// Deep clone user settings as the base
const result = JSON.parse(JSON.stringify(user));

// Strip CDK internal-only comment keys if they leaked in
delete result._comment;
delete result._hooks_note;

// ── Merge permissions.allow ──────────────────────────────────────────────────
result.permissions = result.permissions ?? {};
const userAllow = new Set(result.permissions.allow ?? []);
for (const entry of (cdk.permissions?.allow ?? [])) {
  userAllow.add(entry);
}
result.permissions.allow = [...userAllow];

// ── Merge permissions.deny ───────────────────────────────────────────────────
const userDeny = new Set(result.permissions.deny ?? []);
for (const entry of (cdk.permissions?.deny ?? [])) {
  userDeny.add(entry);
}
result.permissions.deny = [...userDeny];

// ── Merge hooks ──────────────────────────────────────────────────────────────
result.hooks = result.hooks ?? {};

for (const [event, cdkGroups] of Object.entries(cdk.hooks ?? {})) {
  result.hooks[event] = result.hooks[event] ?? [];

  // Collect all command strings already present for this event
  const existingCommands = new Set();
  for (const group of result.hooks[event]) {
    for (const h of (group.hooks ?? [])) {
      if (h.command) existingCommands.add(h.command.trim());
    }
  }

  // For each CDK hook group, keep only commands not already present
  for (const cdkGroup of cdkGroups) {
    const newHooks = (cdkGroup.hooks ?? []).filter(
      (h) => h.command && !existingCommands.has(h.command.trim())
    );
    if (newHooks.length > 0) {
      result.hooks[event].push({ ...cdkGroup, hooks: newHooks });
    }
  }
}

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
