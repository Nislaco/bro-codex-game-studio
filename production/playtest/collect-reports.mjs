#!/usr/bin/env node
// Collects every playtest session report into one summary table.
//
// Usage: node collect-reports.mjs [reportDir]
// Default report dir: ~/.local/share/godot/app_userdata/othello
//
// Prints a markdown table ready to paste into a debrief report, plus any
// per-session findings that stand out (slow start, many invalid clicks,
// uncompleted matches, settings never explored).

import { readdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const dir = process.argv[2] || join(homedir(), '.local/share/godot/app_userdata/othello');

let files = [];
try {
  files = readdirSync(dir).filter(f => f.startsWith('playtest_') && f.endsWith('.json')).sort();
} catch {
  console.log(`No report directory at ${dir}`);
  process.exit(0);
}

if (files.length === 0) {
  console.log(`No playtest reports found in ${dir}`);
  console.log('Run ./run-session.sh <scenario> first.');
  process.exit(0);
}

const sessions = files.map(f => {
  try {
    const d = JSON.parse(readFileSync(join(dir, f), 'utf8'));
    d._file = f;
    return d;
  } catch {
    return null;
  }
}).filter(Boolean);

const s = (v) => (v === undefined || v === null ? '—' : String(v));
const sec = (ms) => (ms >= 0 ? (ms / 1000).toFixed(1) + 's' : '—');

console.log(`# Playtest session summary (${sessions.length} session${sessions.length === 1 ? '' : 's'})\n`);
console.log('| # | File | Duration | 1st move | Moves | Invalid | Skips | Restarts | Settings | Completed | Outcome |');
console.log('|---|------|----------|----------|-------|---------|-------|----------|----------|-----------|---------|');

sessions.forEach((d, i) => {
  const settings = (d.mode_changes ?? 0) + (d.difficulty_changes ?? 0);
  console.log(
    `| ${i + 1} | \`${d._file}\` | ${sec(d.duration_ms)} | ${sec(d.first_legal_move_ms)} | ` +
    `${s(d.moves_placed)} | ${s(d.invalid_clicks)} | ${s(d.skipped_turns)} | ${s(d.restarts)} | ` +
    `${settings} | ${d.completed ? 'yes' : 'no'} | ${s(d.outcome)} |`
  );
});

console.log('\n## Findings\n');
let flagged = 0;
sessions.forEach((d, i) => {
  const notes = [];
  if (d.first_legal_move_ms > 60000) notes.push(`slow start (${sec(d.first_legal_move_ms)} to first legal move)`);
  if ((d.invalid_clicks ?? 0) > (d.moves_placed ?? 0)) notes.push('more invalid clicks than legal moves');
  if (d.completed === false) notes.push('match did not complete');
  if ((d.mode_changes ?? 0) === 0 && (d.difficulty_changes ?? 0) === 0) notes.push('settings never explored');
  if (d.restarts === 0) notes.push('restart never used');
  if (d.skipped_turns > 0) notes.push(`encountered ${d.skipped_turns} pass/skip event(s)`);
  if (notes.length === 0) {
    console.log(`- Session ${i + 1}: no anomalies detected.`);
  } else {
    flagged++;
    console.log(`- Session ${i + 1}: ${notes.join('; ')}.`);
  }
});

if (flagged === 0) {
  console.log('\nNo anomalies in any session.');
}

console.log('\n## Session event trails\n');
sessions.forEach((d, i) => {
  console.log(`### Session ${i + 1} — \`${d._file}\`\n`);
  console.log('```');
  (d.events ?? []).forEach(e => {
    const { event, t_ms, ...rest } = e;
    const extra = Object.keys(rest).length ? ' ' + JSON.stringify(rest) : '';
    console.log(`  ${String(t_ms).padStart(6)}ms  ${event}${extra}`);
  });
  console.log('```\n');
});
