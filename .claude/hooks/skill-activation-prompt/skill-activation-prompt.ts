#!/usr/bin/env tsx
import * as fs from "fs";
import * as path from "path";

interface HookInput {
  session_id?: string;
  prompt?: string;
  transcript_path?: string;
  hook_event_name?: string;
}

interface SkillRule {
  skill: string;
  priority: "critical" | "high" | "medium" | "low";
  alwaysActive?: boolean;
  triggers?: string[];
  message: string;
}

interface SessionState {
  [sessionId: string]: {
    skills: string[];
    timestamp: number;
  };
}

const SESSION_STATE_DIR = "/tmp/.claude-session-state";
const STATE_FILE = path.join(SESSION_STATE_DIR, "suggested-skills.json");
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

function getSessionState(sessionId: string): Set<string> {
  try {
    if (!fs.existsSync(STATE_FILE)) return new Set();
    const raw = fs.readFileSync(STATE_FILE, "utf-8");
    const data: SessionState = JSON.parse(raw);
    const now = Date.now();
    // Prune stale sessions
    for (const key of Object.keys(data)) {
      if (data[key].timestamp < now - MAX_AGE_MS) {
        delete data[key];
      }
    }
    return new Set(data[sessionId]?.skills ?? []);
  } catch {
    return new Set();
  }
}

function saveSessionState(sessionId: string, suggested: Set<string>): void {
  try {
    fs.mkdirSync(SESSION_STATE_DIR, { recursive: true });
    let data: SessionState = {};
    try {
      if (fs.existsSync(STATE_FILE)) {
        data = JSON.parse(fs.readFileSync(STATE_FILE, "utf-8"));
      }
    } catch {
      // start fresh
    }
    data[sessionId] = { skills: [...suggested], timestamp: Date.now() };
    fs.writeFileSync(STATE_FILE, JSON.stringify(data, null, 2));
  } catch {
    // non-fatal
  }
}

function main(): void {
  let input: HookInput = {};
  try {
    const stdin = fs.readFileSync("/dev/stdin", "utf-8").trim();
    if (stdin) input = JSON.parse(stdin);
  } catch {
    process.exit(0);
  }

  const prompt = (input.prompt ?? "").toLowerCase();
  const sessionId = input.session_id ?? "default";

  const rulesPath = path.join(__dirname, "skill-rules.json");
  let rules: SkillRule[] = [];
  try {
    rules = JSON.parse(fs.readFileSync(rulesPath, "utf-8"));
  } catch {
    process.exit(0);
  }

  const alreadySuggested = getSessionState(sessionId);

  const priorityOrder: Record<string, number> = {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3,
  };

  const toSuggest: SkillRule[] = [];
  for (const rule of rules) {
    if (alreadySuggested.has(rule.skill)) continue;

    if (rule.alwaysActive) {
      toSuggest.push(rule);
      continue;
    }

    if (rule.triggers) {
      for (const trigger of rule.triggers) {
        if (prompt.includes(trigger.toLowerCase())) {
          toSuggest.push(rule);
          break;
        }
      }
    }
  }

  if (toSuggest.length === 0) {
    process.exit(0);
  }

  toSuggest.sort(
    (a, b) => (priorityOrder[a.priority] ?? 9) - (priorityOrder[b.priority] ?? 9)
  );

  const lines = toSuggest.map((r) => `- [${r.priority.toUpperCase()}] ${r.message}`);
  const reminder = `SKILL ACTIVATION SUGGESTIONS:\n${lines.join("\n")}`;

  for (const r of toSuggest) {
    alreadySuggested.add(r.skill);
  }
  saveSessionState(sessionId, alreadySuggested);

  process.stdout.write(reminder);
  process.exit(0);
}

main();
