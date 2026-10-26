#!/usr/bin/env node
// Goal-ladder cadence check (UX-SPEC §4). Plays a modelled player through the Flocks ladder, run after run, and prints
// when each rank is reached. The ladder is parsed straight from Swoop/Core/Goals.swift, so it is always in sync.
//
//   node tools/goal-cadence.js [players=6] [runsPerDay=5] [model=casual|expert] [autocomplete=0]
//   (model=casual: novice for 2 runs, then casual; model=expert: expert from run 1; autocomplete=0: the R4 rules)
//
// Player model (an assumption, documented in design/notes/core-R3.md):
// - runs 1–3 novice, runs 4–60 casual (12 days), then alternating casual/expert runs (players get better);
// - ~5 runs a day, and the first run of every day from day 2 is that day's Daily Flight;
// - goal progress is max-only per goal while the rank is current; at most one rank-up per run (ProgressStore rules).
// UX targets: rank 1 by run 2, rank 3 by run 8, rank 6 by day 4 (run 20), rank 10 by day 10 (run 50), rank 14 by
// day 21 (run 105).
'use strict';
const fs = require('fs');
const path = require('path');
const S = require('./balance-sim.js');
const args = {}; for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); args[k] = v; }
const players = parseInt(args.players || '6');
const perDay = parseInt(args.runsPerDay || '5');
const maxRuns = parseInt(args.runs || '140');

// MARK: parse the ladder
const src = fs.readFileSync(path.join(__dirname, '..', 'Swoop', 'Core', 'Goals.swift'), 'utf8');
const ladderSrc = src.slice(src.indexOf('static let ladder'), src.indexOf('public enum GoalEvaluator'));
const ranks = [];
for (const block of ladderSrc.split(/\n\s*\/\/ \d+ /).slice(1)) {
  const goals = [];
  const re = /g\("([^"]+)", \.(\w+), ([0-9.]+), "([^"]*)"\)/g; let m;
  while ((m = re.exec(block)) !== null) goals.push({ id: m[1], kind: m[2], target: parseFloat(m[3]), text: m[4] });
  if (goals.length) ranks.push(goals);
}
const dailyRunOnly = new Set((src.match(/dailyRunGoalIDs: Set<String> = \[([^\]]*)\]/) || ['', ''])[1].split(',').map(x => x.trim().replace(/"/g, '')).filter(Boolean));

function value(goal, r, lifetime, dailyEver, isDaily) {
  switch (goal.kind) {
    case 'reachMeters': return r.meters;
    case 'perfectsInRun': return r.perfects;
    case 'chain': return r.chain;
    case 'lighthouses': return r.lh;
    case 'cloudTouches': return r.clouds;
    case 'cleanMeters': return r.clean;
    case 'tailwinds': return r.tail;
    case 'totalMeters': return lifetime;
    case 'speed': return r.maxSpeed;
    case 'dailyPlayed': return (dailyRunOnly.has(goal.id) ? isDaily : (dailyEver || isDaily)) ? goal.target : 0;
  }
  return 0;
}
// Round 5 (P1-9): goals the player's bests already meet complete at once (GoalEvaluator.alreadyMet), cascading
// through ranks after a run. Mirrors Goals.swift: one-flight goals by the best single flight, totals by lifetime,
// "any Daily" by having played one, and daily-run-only goals never by bests.
function metByBests(goal, b) {
  switch (goal.kind) {
    case 'reachMeters': return b.meters >= goal.target;
    case 'perfectsInRun': return b.perfects >= goal.target;
    case 'chain': return b.chain >= goal.target;
    case 'lighthouses': return b.lh >= goal.target;
    case 'cloudTouches': return b.clouds >= goal.target;
    case 'cleanMeters': return b.clean >= goal.target;
    case 'tailwinds': return b.tail >= goal.target;
    case 'totalMeters': return b.lifetime >= goal.target;
    case 'speed': return b.maxSpeed >= goal.target;
    case 'dailyPlayed': return !dailyRunOnly.has(goal.id) && b.dailyEver;
  }
  return false;
}
function skillFor(run) {
  if (args.model === 'casual') return run <= 2 ? 'novice' : 'casual';
  if (args.model === 'expert') return 'expert';
  if (run <= 3) return 'novice';
  if (run <= 60) return 'casual';
  return run % 2 === 0 ? 'expert' : 'casual';
}

const cache = {};
function result(skill, seed) {
  const k = skill + ':' + seed;
  if (!cache[k]) cache[k] = S.runOne(skill, seed, 1 / 60, 900);
  return cache[k];
}

const reached = []; // reached[p][rank] = run
for (let p = 0; p < players; p++) {
  let rank = 0, lifetime = 0, dailyEver = false; let best = {};
  const bests = { meters: 0, perfects: 0, chain: 0, lh: 0, clouds: 0, clean: 0, tail: 0, maxSpeed: 0, lifetime: 0, dailyEver: false };
  const at = [0];
  for (let run = 1; run <= maxRuns && rank < ranks.length; run++) {
    const day = Math.floor((run - 1) / perDay) + 1;
    const isDaily = day >= 2 && (run - 1) % perDay === 0;
    const r = result(skillFor(run), 5000 + p * 104729 + run * 7919);
    lifetime += r.meters;
    const goals = ranks[rank];
    let done = 0;
    for (const g of goals) {
      const v = Math.min(1, value(g, r, lifetime, dailyEver, isDaily) / g.target);
      best[g.id] = Math.max(best[g.id] || 0, v);
      if (best[g.id] >= 1) done++;
    }
    if (isDaily) dailyEver = true;
    bests.meters = Math.max(bests.meters, r.meters); bests.perfects = Math.max(bests.perfects, r.perfects);
    bests.chain = Math.max(bests.chain, r.chain); bests.lh = Math.max(bests.lh, r.lh); bests.clouds = Math.max(bests.clouds, r.clouds);
    bests.clean = Math.max(bests.clean, r.clean); bests.tail = Math.max(bests.tail, r.tail); bests.maxSpeed = Math.max(bests.maxSpeed, r.maxSpeed);
    bests.lifetime = lifetime; bests.dailyEver = dailyEver;
    if (args.autocomplete !== '0') {
      // goals already met by the bests count as done now, and a finished flock cascades into the next one
      done = 0;
      for (const g of goals) if (best[g.id] >= 1 || metByBests(g, bests)) done++;
      while (done === goals.length && rank < ranks.length) {
        rank++; at[rank] = run; best = {};
        if (rank >= ranks.length) break;
        done = ranks[rank].filter(g => metByBests(g, bests)).length;
        if (done < ranks[rank].length) { done = -1; break; }
      }
    } else if (done === goals.length) { rank++; at[rank] = run; best = {}; }
  }
  reached.push(at);
}
console.log(`ranks parsed: ${ranks.length} flocks; daily-run-only goals: ${[...dailyRunOnly].join(', ') || 'none'}`);
const targets = args.model === 'expert' ? { 14: 60 } : { 1: 2, 3: 8, 6: 20, 10: 50, 14: 105 };
for (let k = 1; k <= ranks.length; k++) {
  const runs = reached.map(a => a[k]).filter(x => x !== undefined).sort((a, b) => a - b);
  const med = runs.length ? runs[Math.floor(runs.length / 2)] : undefined;
  const t = targets[k];
  console.log(`rank ${String(k).padStart(2)} (${ranks[k - 1].map(g => g.id).join(', ')}): median run ${med ?? '—'} ` +
    `(${runs.length}/${players} reached)${t ? (args.model === 'expert' ? `  target ≥ ${t}${med !== undefined && med >= t ? ' OK' : ' MISS'}` : `  target ≤ ${t}${med !== undefined && med <= t ? ' OK' : ' MISS'}`) : ''}`);
}
