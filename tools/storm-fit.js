#!/usr/bin/env node
// Storm-law fitter for Swoop. The pilots ignore the storm, so each run's path x(t) and its storm bonuses B(t)
// (Perfect, Tailwind and lighthouse push-backs) are recorded once with catching disabled. Any storm law can then be
// evaluated instantly: caught at the first t where x(t) + gapStart + B(t) − ∫n(t) ≤ 0.
//   node tools/storm-fit.js [seeds=12] [T.name=value ...]     # uses balance-sim.js's Tuning + overrides
'use strict';
const fs = require('fs');
const S = require('./balance-sim.js');
const T = S.T;
const args = {}; for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); args[k] = v; if (k.startsWith('T.')) T[k.slice(2)] = parseFloat(v); }
const seeds = parseInt(args.seeds || '12');
const skills = ['novice', 'casual', 'expert', 'perfect'];
const DT = 1 / 120, CAP = 900, SAMPLE = 0.25;

function record(skill, seed) {
  const s = new S.FlightSession('flight', seed, 0);
  s.countdownLeft = 0;
  const p = new S.FlightPilot(skill, seed * 7 + 1);
  const xs = [], bs = [];
  let bonus = 0, t = 0, next = 0;
  while (t < CAP) {
    const ev = s.step(DT, p.tuck(s.snapshot(), s.sea));
    for (const e of ev) {
      if (e === 'perfect') bonus += T.perfectGapBonus;
      if (e === 'lighthouse') bonus += T.lighthouseGapBonus;
    }
    t += DT;
    s.stormX = -1e12; // never catch
    if (t >= next) { xs.push(s.x); bs.push(bonus + tailBonus(s)); next += SAMPLE; }
  }
  return { xs, bs };
}

// Tailwind bonuses: count chain multiples by wrapping touchdown.
const TB = new WeakMap();
const origTouch = S.FlightSession.prototype.touchdown;
S.FlightSession.prototype.touchdown = function (ev, calm, vmax) {
  const before = this.chain;
  origTouch.call(this, ev, calm, vmax);
  if (!calm && this.chain > before && this.chain % T.tailwindChain === 0) TB.set(this, (TB.get(this) || 0) + T.tailwindGapBonus);
};
function tailBonus(s) { return TB.get(s) || 0; }

// Returns the catch time and (optionally) pushes gap / fullLead samples while flying (the lead meter, UX-C3).
function caughtTime(rec, law, gapsOut) {
  let pos = 0; // storm distance travelled
  for (let i = 0; i < rec.xs.length; i++) {
    const t = i * SAMPLE;
    const gap = rec.xs[i] + law.gapStart + rec.bs[i] - pos;
    if (gap <= 0) return t;
    if (gapsOut) gapsOut.push(gap / T.fullLead);
    const sp = law(t) + law.leashRate * Math.max(0, gap - law.leashGap);
    pos += sp * SAMPLE;
  }
  return CAP;
}
function median(a) { const b = a.slice().sort((x, y) => x - y); return b[Math.floor(b.length / 2)]; }
function pct(a, p) { const b = a.slice().sort((x, y) => x - y); return b[Math.min(b.length - 1, Math.floor((b.length - 1) * p))]; }

// cache=<file>: reuse recorded runs (they only depend on the bird physics and pilots, not on the storm law).
let recs = null;
if (args.cache && fs.existsSync(args.cache)) { const c = JSON.parse(fs.readFileSync(args.cache, 'utf8')); if (c.seeds === seeds) recs = c.recs; }
if (!recs) {
  recs = {};
  for (const sk of skills) { recs[sk] = []; for (let i = 0; i < seeds; i++) recs[sk].push(record(sk, 1000 + i * 7919)); }
  if (args.cache) fs.writeFileSync(args.cache, JSON.stringify({ seeds, recs }));
}

function makeLaw(base, accel, cruise, late, max, gap, leashGap, leashRate) {
  const f = (t) => { const ct = (cruise - base) / accel; return t <= ct ? base + accel * t : Math.min(max, cruise + late * (t - ct)); };
  f.gapStart = gap; f.leashGap = leashGap; f.leashRate = leashRate;
  f.desc = `base=${base} accel=${accel} cruise=${cruise} late=${late} max=${max} gap=${gap} leash=${leashGap}@${leashRate}`;
  return f;
}
const laws = [makeLaw(T.stormBaseSpeed, T.stormAccel, T.stormCruiseSpeed, T.stormLateAccel, T.stormMaxSpeed, T.gapStart,
  T.stormLeashGap, T.stormLeashRate)];
if (args.grid) {
  for (const base of [420, 480]) for (const accel of [9, 12]) for (const cruise of [1300, 1400, 1500])
    for (const leashGap of [6000, 9000, 12000]) for (const leashRate of [0.15, 0.3, 0.5])
      laws.push(makeLaw(base, accel, cruise, T.stormLateAccel, T.stormMaxSpeed, T.gapStart, leashGap, leashRate));
}
const rows = [];
for (const law of laws) {
  const med = {}; let capped = 0; const gaps = [];
  for (const sk of skills) {
    const ts = recs[sk].map(r => caughtTime(r, law, sk === 'casual' ? gaps : null));
    med[sk] = median(ts); if (sk === 'perfect') capped = ts.filter(x => x >= CAP).length;
  }
  const g50 = pct(gaps, 0.5);
  const ok = med.novice >= 52 && med.novice <= 72 && med.casual >= 140 && med.casual <= 160 && med.expert >= 340 && med.expert <= 460 && capped === 0;
  rows.push({ law, med, capped, ok, g25: pct(gaps, 0.25), g50, g75: pct(gaps, 0.75) });
}
const score = (r) => Math.abs(r.med.novice - 62) / 17 + Math.abs(r.med.casual - 150) / 20 + Math.abs(r.med.expert - 400) / 100 + (r.capped ? 9 : 0);
if (args.grid) rows.sort((a, b) => score(a) - score(b));
for (const r of rows.slice(0, args.grid ? 12 : 1))
  console.log(`${r.ok ? 'OK ' : '   '}${r.law.desc}: novice=${r.med.novice.toFixed(0)} casual=${r.med.casual.toFixed(0)} expert=${r.med.expert.toFixed(0)} ` +
    `perfect=${r.med.perfect.toFixed(0)} perfectCapped=${r.capped} casualGap p25/50/75=${r.g25.toFixed(2)}/${r.g50.toFixed(2)}/${r.g75.toFixed(2)}`);
