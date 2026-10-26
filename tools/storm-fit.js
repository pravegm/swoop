#!/usr/bin/env node
// Storm-law fitter for Swoop. The pilots ignore the storm, so each run's path x(t) and its storm bonuses B(t)
// (Perfect, Tailwind and lighthouse push-backs) are recorded once with catching disabled. Any storm law can then be
// evaluated instantly: caught at the first t where x(t) + gapStart + B(t) − ∫n(t) ≤ 0.
//   node tools/storm-fit.js [seeds=12] [T.name=value ...]     # uses balance-sim.js's Tuning + overrides
'use strict';
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

function caughtTime(rec, law) {
  let pos = 0, sp; // storm distance travelled
  for (let i = 0; i < rec.xs.length; i++) {
    const t = i * SAMPLE;
    sp = law(t); pos += sp * SAMPLE;
    if (rec.xs[i] + law.gapStart + rec.bs[i] - pos <= 0) return t;
  }
  return CAP;
}
function median(a) { const b = a.slice().sort((x, y) => x - y); return b[Math.floor(b.length / 2)]; }

const recs = {};
for (const sk of skills) { recs[sk] = []; for (let i = 0; i < seeds; i++) recs[sk].push(record(sk, 1000 + i * 7919)); }

function makeLaw(base, accel, cruise, late, max, gap) {
  const f = (t) => { const ct = (cruise - base) / accel; return t <= ct ? base + accel * t : Math.min(max, cruise + late * (t - ct)); };
  f.gapStart = gap; f.desc = `base=${base} accel=${accel} cruise=${cruise} late=${late} max=${max} gap=${gap}`; return f;
}
const laws = [makeLaw(T.stormBaseSpeed, T.stormAccel, T.stormCruiseSpeed, T.stormLateAccel, T.stormMaxSpeed, T.gapStart)];
if (args.grid) {
  for (const base of [480, 540, 600]) for (const accel of [12, 15, 18]) for (const cruise of [1600, 1700, 1800, 1900]) for (const gap of [2400, 2800, 3200])
    laws.push(makeLaw(base, accel, cruise, T.stormLateAccel, T.stormMaxSpeed, gap));
}
const rows = [];
for (const law of laws) {
  const med = {}; let capped = 0;
  for (const sk of skills) { const ts = recs[sk].map(r => caughtTime(r, law)); med[sk] = median(ts); if (sk === 'perfect') capped = ts.filter(x => x >= CAP).length; }
  const ok = med.novice >= 52 && med.novice <= 72 && med.casual >= 140 && med.casual <= 160 && med.expert >= 340 && med.expert <= 460 && capped === 0;
  rows.push({ law, med, capped, ok });
}
for (const r of rows) if (!args.grid || r.ok || r === rows[0])
  console.log(`${r.ok ? 'OK ' : '   '}${r.law.desc}: novice=${r.med.novice.toFixed(0)} casual=${r.med.casual.toFixed(0)} expert=${r.med.expert.toFixed(0)} perfect=${r.med.perfect.toFixed(0)} perfectCapped=${r.capped}`);
