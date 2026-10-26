#!/usr/bin/env node
// Swoop balance simulator: a line-by-line Node port of Swoop/Core (SeaProfile, FlightSession, FlightPilot, Tuning).
// KEEP IN SYNC with Swoop/Core/*.swift. Used to tune Tuning numerically without a Swift compiler.
//
//   node tools/balance-sim.js                 # 20 seeds x 4 skills at dt 1/120, prints SWOOP-BAL lines
//   node tools/balance-sim.js seeds=40 skills=casual,expert dt=0.008333
//   node tools/balance-sim.js sea             # sea checks (max slope over 200 km, continuity) for a few seeds
//
// Numbers will not be bit-identical to Swift (libm differs), but the statistics match.
// Session differences (cosmetic only): Swift also eases the tuck during the countdown and moves the storm while caught;
// this port only models what affects balance (no milestone/newBest/stormClose events).
'use strict';

// MARK: Tuning (mirror of Swoop/Core/Tuning.swift)
const T = {
  gravity: 1500,
  tuckGravityFactor: 1.9,
  airTuckGravityFactor: 1.9,
  seaWavelengthScale: 2,
  seaAmplitudeScale: 1.4,
  liftPerpendicular: 1,
  pilotBranchEvery: 2,
  liftMaxFraction: 0.65,
  liftCoefficient: 0.012,
  airDrag: 0.04,
  waterFriction: 0.002,
  minSpeed: 260,
  maxSpeed: 2600,
  perfectAngleDeg: 14,
  perfectSlopeDeg: -4,
  goodAngleDeg: 30,
  perfectBoost: 0.06,
  splashKeep: 0.75,
  launchMargin: 0.04,
  launchGrace: 0.1,
  stormBaseSpeed: 520,
  stormAccel: 9,
  stormCruiseSpeed: 1500,
  stormLateAccel: 2.5,
  stormMaxSpeed: 3200,
  gapStart: 2400,
  fullLead: 3000,
  perfectGapBonus: 120,
  tailwindChain: 3,
  tailwindGapBonus: 600,
  tailwindDuration: 2.5,
  tailwindSpeedBoost: 0.15,
  lighthouseGapBonus: 800,
  cloudHeight: 900,
  cloudRearmHeight: 650,
  tuckAttack: 0.06,
  tuckRelease: 0.08,
  bodyAngleSmoothing: 0.08,
  caughtDuration: 1.8,
  caughtDrag: 1.6,
  caughtDriftSpeed: 90,
  countdownDuration: 3,
  startX: 0,
  startHeight: 260,
  startSpeed: 520,
  maxSubstep: 1 / 240,
  stormCloseLead: 0.15,
  stormRearmLead: 0.30,
  attractStormLag: 1500,
  pointsPerMeter: 10,
  perfectStyleMeters: 25,
  tailwindStyleMeters: 100,
  // Sea
  blendWidth: 600,
  setSlopeBudget: 1.0,
  blendSlopeCap: 1.08,
  tierLength: 30000,
  tutorialEnd: 4000,
  tutorialAmplitude: 150,
  tutorialWavelength: 1800,
  tutorialCrestX: 200,
};

// MARK: SeededRandom (SplitMix64) using BigInt
const MASK = (1n << 64n) - 1n;
class SeededRandom {
  constructor(seed) { this.state = BigInt.asUintN(64, BigInt(seed)); }
  next() {
    this.state = (this.state + 0x9E3779B97F4A7C15n) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & MASK;
    return z ^ (z >> 31n);
  }
  unit() { return Number(this.next() >> 11n) / 9007199254740992; }
  range(lo, hi) { return lo + (hi - lo) * this.unit(); }
}

const TAU = Math.PI * 2;
function smooth(t) { return t * t * (3 - 2 * t); }
function clamp(v, lo, hi) { return Math.min(Math.max(v, lo), hi); }
function wrapPhase(p) { let r = p % TAU; if (r < 0) r += TAU; return r; }

// MARK: SeaProfile
class SeaProfile {
  constructor(seed) {
    this.seed = seed;
    this.rng = new SeededRandom(BigInt.asUintN(64, BigInt(seed) ^ 0x5EA5EA5EA5EA5EAn));
    // sets[j] = { centre (blend centre, j>=1), bodyStart, end (= next centre - W/2), A:[3], f:[3], phi:[3] }
    const f0 = 1 / T.tutorialWavelength;
    const t0 = { centre: -1e12, bodyStart: 0, end: T.tutorialEnd, A: [T.tutorialAmplitude, 0, 0],
      f: [f0, 1 / 560, 1 / 420], phi: [wrapPhase(Math.PI / 2 - TAU * f0 * T.tutorialCrestX), 0, 0], rogue: false };
    this.sets = [t0];
    this.last = 0;
    this.blendFallbacks = 0; this.blendScales = 0;
  }
  // phase of component k of set j at x (body formula)
  bodyPhase(s, k, x) { return s.phi[k] + TAU * s.f[k] * (x - s.bodyStart); }
  generateNext() {
    const W = T.blendWidth;
    const prev = this.sets[this.sets.length - 1];
    const centre = prev.end + W / 2;
    const tier = Math.max(0, Math.floor(centre / T.tierLength));
    const g = Math.min(1, tier / 5);
    const r = this.rng;
    const len = Math.min(3500, r.range(1500, 2500) + 200 * tier);
    let rogue = tier >= 1 && !prev.rogue && r.unit() < 0.07;
    let A, lam;
    const twoComp = r.unit() < 0.3;
    if (rogue) {
      A = [r.range(140, 160), r.range(10, 20), 0];
      lam = [r.range(1000, 1150), r.range(480, 620), r.range(380, 480)];
    } else {
      A = [r.range(40 + 50 * g, 80 + 70 * g), r.range(20 + 30 * g, 50 + 40 * g), twoComp ? 0 : r.range(8 + 12 * g, 22 + 18 * g)];
      lam = [r.range(620, 900), r.range(460, 700), r.range(380, 500)];
    }
    const f = lam.map(l => 1 / (l * T.seaWavelengthScale));
    for (let k = 0; k < 3; k++) A[k] *= T.seaAmplitudeScale;
    // normalise the set's own slope budget
    let sum = 0; for (let k = 0; k < 3; k++) sum += TAU * A[k] * f[k];
    if (sum > T.setSlopeBudget) { const s = T.setSlopeBudget / sum; for (let k = 0; k < 3; k++) A[k] *= s; }
    const x0 = centre - W / 2;
    const bodyStart = centre + W / 2;
    const phi = [0, 0, 0];
    for (let k = 0; k < 3; k++) {
      const thA = this.bodyPhase(prev, k, x0);
      phi[k] = wrapPhase(thA + TAU * W * (prev.f[k] + (f[k] - prev.f[k]) / 2));
    }
    const s = { centre, bodyStart, end: centre + len - W / 2, A, f, phi, rogue };
    // enforce the blend's slope cap
    let tries = 0;
    while (this.blendMaxSlope(prev, s) > T.blendSlopeCap) {
      tries++;
      if (tries > 30) { // fallback: continue the previous set exactly
        this.blendFallbacks++;
        s.A = prev.A.slice(); s.f = prev.f.slice(); s.rogue = false;
        for (let k = 0; k < 3; k++) s.phi[k] = wrapPhase(this.bodyPhase(prev, k, x0) + TAU * W * prev.f[k]);
        break;
      }
      this.blendScales++;
      for (let k = 0; k < 3; k++) s.A[k] *= 0.9;
    }
    this.sets.push(s);
  }
  blendMaxSlope(a, b) {
    let m = 0;
    for (let i = 0; i <= 120; i++) {
      const x = b.centre - T.blendWidth / 2 + T.blendWidth * i / 120;
      m = Math.max(m, Math.abs(this.blendEval(a, b, x)[1]));
    }
    return m;
  }
  blendEval(a, b, x) {
    const W = T.blendWidth;
    const x0 = b.centre - W / 2;
    const t = clamp((x - x0) / W, 0, 1);
    const S = smooth(t), dS = 6 * t * (1 - t) / W;
    const I = t * t * t - t * t * t * t / 2; // integral of smoothstep
    let h = 0, d = 0;
    for (let k = 0; k < 3; k++) {
      const fa = a.f[k], df = b.f[k] - fa;
      const th = this.bodyPhase(a, k, x0) + TAU * W * (fa * t + df * I);
      const dth = TAU * (fa + df * S);
      const Aa = a.A[k], dA = b.A[k] - Aa;
      const amp = Aa + dA * S, damp = dA * dS;
      const sn = Math.sin(th), cs = Math.cos(th);
      h += amp * sn; d += damp * sn + amp * dth * cs;
    }
    return [h, d];
  }
  bodyEval(s, x) {
    let h = 0, d = 0;
    for (let k = 0; k < 3; k++) {
      if (s.A[k] === 0) continue;
      const th = this.bodyPhase(s, k, x);
      h += s.A[k] * Math.sin(th); d += s.A[k] * TAU * s.f[k] * Math.cos(th);
    }
    return [h, d];
  }
  index(x) {
    while (this.sets[this.sets.length - 1].end <= x) this.generateNext();
    let j = this.last;
    while (j > 0 && x < this.sets[j].centre - T.blendWidth / 2) j--;
    while (j < this.sets.length - 1 && x >= this.sets[j].end) j++;
    this.last = j;
    return j;
  }
  eval(x) {
    const j = this.index(x);
    const s = this.sets[j];
    if (j > 0 && x < s.bodyStart) return this.blendEval(this.sets[j - 1], s, x);
    return this.bodyEval(s, x);
  }
  height(x) { return this.eval(x)[0]; }
  slope(x) { return this.eval(x)[1]; }
  curvature(x) { const e = 2; return (this.slope(x + e) - this.slope(x - e)) / (2 * e); }
}

// MARK: Lighthouses
const Lighthouses = {
  x(i) { let x = 40000; for (let n = 1; n <= i; n++) x += Math.min(80000, 40000 + 10000 * n); return x; },
};

function stormSpeed(t) {
  const cruiseT = (T.stormCruiseSpeed - T.stormBaseSpeed) / T.stormAccel;
  if (t <= cruiseT) return T.stormBaseSpeed + T.stormAccel * t;
  return Math.min(T.stormMaxSpeed, T.stormCruiseSpeed + T.stormLateAccel * (t - cruiseT));
}
function gEff(u) { return T.gravity * (1 + T.tuckGravityFactor * u); }
function gAir(u) { return T.gravity * (1 + T.airTuckGravityFactor * u); }
function liftAccel(u, vx, vy) { return vy < 0 ? (1 - u) * Math.min(T.liftMaxFraction * T.gravity, T.liftCoefficient * vx * vx) : 0; }
// Airborne acceleration [ax, ay]: tuck gravity, spread-wing lift while descending, drag.
// liftPerpendicular = 1: the lift acts at right angles to the velocity (does no work: a dive turns into forward speed).
function airAccel(u, vx, vy, drag, calm) {
  const L = calm ? 0 : liftAccel(u, vx, vy);
  let lx = 0, ly = L;
  if (T.liftPerpendicular > 0 && L > 0) { const sp = Math.hypot(vx, vy); if (sp > 1e-6) { lx = -vy / sp * L; ly = vx / sp * L; } }
  return [lx - drag * vx, -gAir(u) + ly - drag * vy];
}

// MARK: FlightSession (balance-relevant subset, same logic as Swift)
class FlightSession {
  constructor(mode, seed, bestMeters) {
    this.mode = mode; this.seed = seed; this.sea = new SeaProfile(seed);
    this.phase = 'countdown'; this.countdownLeft = T.countdownDuration; this.time = 0; this.flightTime = 0;
    this.x = T.startX; this.y = this.sea.height(T.startX) + T.startHeight; this.vx = 0; this.vy = 0;
    this.skimming = false; this.s = 0; this.u = 0;
    this.stormX = this.x - T.gapStart;
    this.chain = 0; this.bestChain = 0; this.perfects = 0; this.goods = 0; this.splashes = 0; this.tailwinds = 0;
    this.tailwindLeft = 0; this.lighthouses = 0; this.cloudTouches = 0; this.cloudArmed = true;
    this.maxSpeed = 0; this.maxAlt = 0; this.caughtElapsed = 0; this.finished = false; this.airTime = 0;
    this.launches = 0; this.skimTime = 0;
  }
  snapshot() {
    const sp = Math.hypot(this.vx, this.vy);
    return { phase: this.phase, time: this.time, x: this.x, y: this.y, vx: this.vx, vy: this.vy, speed: sp,
      skimming: this.skimming, tuck: this.u, gap: this.x - this.stormX };
  }
  step(dt, tuck) {
    const ev = [];
    if (this.finished) return ev;
    dt = clamp(dt, 0, 0.25);
    const n = Math.max(1, Math.ceil(dt / T.maxSubstep - 1e-9));
    const h = dt / n;
    for (let i = 0; i < n; i++) this.sub(h, clamp(tuck, 0, 1), ev);
    return ev;
  }
  sub(dt, input, ev) {
    this.time += dt;
    if (this.phase === 'countdown') {
      this.countdownLeft -= dt;
      if (this.countdownLeft <= 0) { this.phase = 'flying'; this.vx = T.startSpeed; this.vy = 0; ev.push('started'); }
      return;
    }
    const tauE = input > this.u ? T.tuckAttack : T.tuckRelease;
    this.u += (input - this.u) * (1 - Math.exp(-dt / tauE));
    if (this.phase === 'caught') {
      this.caughtElapsed += dt;
      this.physics(dt, 0, ev, true);
      if (this.caughtElapsed >= T.caughtDuration) { this.phase = 'finished'; this.finished = true; ev.push('finished'); }
      return;
    }
    this.flightTime += dt;
    this.physics(dt, this.u, ev, false);
    if (this.tailwindLeft > 0) { this.tailwindLeft -= dt; if (this.tailwindLeft <= 0) { this.tailwindLeft = 0; ev.push('tailwindEnded'); } }
    // storm
    if (this.mode === 'attract') this.stormX = this.x - T.attractStormLag;
    else this.stormX += stormSpeed(this.flightTime) * dt;
    while (this.x >= Lighthouses.x(this.lighthouses)) { this.lighthouses++; this.stormX -= T.lighthouseGapBonus; ev.push('lighthouse'); }
    const alt = this.y - this.sea.height(this.x);
    if (this.cloudArmed && alt >= T.cloudHeight) { this.cloudArmed = false; this.cloudTouches++; ev.push('cloud'); }
    if (!this.cloudArmed && alt < T.cloudRearmHeight) this.cloudArmed = true;
    this.maxSpeed = Math.max(this.maxSpeed, Math.hypot(this.vx, this.vy)); this.maxAlt = Math.max(this.maxAlt, alt);
    if (this.mode !== 'attract' && this.x - this.stormX <= 0) { this.phase = 'caught'; this.caughtElapsed = 0; ev.push('caught'); this.caughtAt = this.flightTime; this.caughtX = this.x; }
  }
  physics(dt, u, ev, calm) {
    const sea = this.sea;
    const tailwind = this.tailwindLeft > 0;
    const vmax = T.maxSpeed * (tailwind ? 1 + T.tailwindSpeedBoost : 1);
    const minS = calm ? 0 : T.minSpeed;
    if (this.skimming) {
      const p = sea.slope(this.x); const phi = Math.atan(p);
      const g = gEff(u);
      let s = this.s;
      s += -g * Math.sin(phi) * dt;
      const drag = calm ? T.caughtDrag : (tailwind ? 0 : T.airDrag);
      s *= Math.exp(-(drag + T.waterFriction) * dt);
      if (calm) s = Math.max(s, T.caughtDriftSpeed);
      if (s * Math.cos(phi) < minS) s = minS / Math.cos(phi);
      s = Math.min(s, vmax);
      this.x += s * Math.cos(phi) * dt;
      const p2 = sea.slope(this.x); const phi2 = Math.atan(p2);
      this.y = sea.height(this.x);
      this.s = s; this.vx = s * Math.cos(phi2); this.vy = s * Math.sin(phi2);
      this.skimTime += dt;
      if (!calm && this.skimTime >= T.launchGrace) {
        const k = sea.curvature(this.x) / Math.pow(1 + p2 * p2, 1.5);
        if (k < 0 && -s * s * k > g * Math.cos(phi2) * (1 + T.launchMargin)) {
          this.skimming = false; this.y += 0.25; this.launches++; this.airTime = 0; ev.push('launched');
        }
      }
      return;
    }
    // airborne
    const drag = calm ? T.caughtDrag * 0.3 : (tailwind ? 0 : T.airDrag);
    const acc = airAccel(u, this.vx, this.vy, drag, calm);
    this.vx += acc[0] * dt;
    this.vy += acc[1] * dt;
    if (this.vx < minS) this.vx = minS;
    if (calm && this.vx < T.caughtDriftSpeed) this.vx = T.caughtDriftSpeed;
    const sp = Math.hypot(this.vx, this.vy);
    if (sp > vmax) { this.vx *= vmax / sp; this.vy *= vmax / sp; }
    const x0 = this.x, y0 = this.y; const d0 = y0 - sea.height(x0);
    this.x += this.vx * dt; this.y += this.vy * dt; this.airTime += dt;
    const d1 = this.y - sea.height(this.x);
    if (d1 <= 0) {
      const fr = d0 > 0 ? clamp(d0 / (d0 - d1), 0, 1) : 1;
      this.x = x0 + (this.x - x0) * fr; this.y = sea.height(this.x);
      this.touchdown(ev, calm, vmax);
    }
  }
  touchdown(ev, calm, vmax) {
    const p = this.sea.slope(this.x); const phi = Math.atan(p);
    const beta = Math.atan2(this.vy, this.vx);
    const alpha = Math.abs(beta - phi) * 180 / Math.PI;
    const sp = Math.hypot(this.vx, this.vy);
    let q, s;
    if (alpha <= T.perfectAngleDeg && phi * 180 / Math.PI < T.perfectSlopeDeg) { q = 'perfect'; s = sp * (1 + T.perfectBoost); }
    else if (alpha <= T.goodAngleDeg) { q = 'good'; s = sp * Math.cos(alpha * Math.PI / 180); }
    else { q = 'splash'; s = sp * Math.cos(alpha * Math.PI / 180) * T.splashKeep; }
    this.skimming = true; this.skimTime = 0;
    this.s = Math.min(Math.max(s, calm ? 0 : T.minSpeed), vmax);
    this.vx = this.s * Math.cos(phi); this.vy = this.s * Math.sin(phi);
    if (calm) return;
    this.cloudArmed = true;
    if (q === 'perfect') {
      this.perfects++; this.chain++; this.bestChain = Math.max(this.bestChain, this.chain); this.stormX -= T.perfectGapBonus;
      if (this.tailwindLeft > 0) this.tailwindLeft = T.tailwindDuration;
      if (this.chain % T.tailwindChain === 0) {
        this.stormX -= T.tailwindGapBonus;
        if (this.tailwindLeft <= 0) {
          this.tailwinds++; ev.push('tailwindStarted');
          this.s = Math.min(this.s * (1 + T.tailwindSpeedBoost), T.maxSpeed * (1 + T.tailwindSpeedBoost));
          this.vx = this.s * Math.cos(phi); this.vy = this.s * Math.sin(phi);
        }
        this.tailwindLeft = T.tailwindDuration;
      }
    } else { this.chain = 0; if (q === 'good') this.goods++; else this.splashes++; }
    ev.push(q);
  }
}

// MARK: FlightPilot (mirror of Swoop/Core/FlightPilot.swift)
// A human-like player. While skimming: tuck on downslopes (looking a little ahead), open for the climb.
// While airborne: keep the wings open, and plan *when* to tuck so that holding the tuck until touchdown lands on a
// downslope at the smallest angle (the centre of the widest "Perfect" window). Once it tucks in the air it holds the
// tuck until it touches down (a human dive, not a twitch). Novices ignore the sea and fold in a crude rhythm.
const SKILLS = {
  perfect: { lag: 0.03, assumedLag: 0.03, hold: 0.12, look: 0.05, replan: 0.15, noise: 0.0, jitter: 0.0, mistake: 0.0, rhythm: false },
  expert:  { lag: 0.08, assumedLag: 0.06, hold: 0.14, look: 0.05, replan: 0.2, noise: 0.04, jitter: 0.04, mistake: 0.06, rhythm: false },
  casual:  { lag: 0.15, assumedLag: 0.05, hold: 0.16, look: 0.03, replan: 0.25, noise: 0.10, jitter: 0.08, mistake: 0.20, rhythm: false },
  novice:  { lag: 0.25, assumedLag: 0.0, hold: 0.20, look: 0.0, replan: 1, noise: 0.0, jitter: 0.0, mistake: 0.0, rhythm: true },
};
const PRED_DT = 1 / 60;      // planning integration step (s)
const PRED_MAX_DELAY = 1.6;  // latest tuck the plan considers (s from now)
const PRED_MAX_FLIGHT = 4;   // give up on paths longer than this (s)
class FlightPilot {
  constructor(skill, seed) {
    this.skill = skill; this.p = SKILLS[skill]; this.rng = new SeededRandom(BigInt.asUintN(64, BigInt(seed) ^ 0x9170A7n));
    this.target = 0; this.lastChange = -1e9; this.history = []; this.output = 0; this.lastTime = -1;
    this.rhythmNext = 0; this.rhythmState = 0;
    this.committed = false; this.tuckAt = 1e18; this.nextPlan = -1e18; this.wasSkimming = true;
  }
  // Air accel for tuck u (same law as the session).
  static stepAir(st, u, dt, gScale) {
    const acc = airAccel(u, st.vx, st.vy, T.airDrag, false);
    const ax = acc[0], ay = acc[1] - gAir(u) * (gScale - 1);
    st.x += st.vx * dt + 0.5 * ax * dt * dt; st.y += st.vy * dt + 0.5 * ay * dt * dt;
    st.vx += ax * dt; st.vy += ay * dt;
    if (st.vx < T.minSpeed) st.vx = T.minSpeed;
  }
  // Fly the tucked branch from state b (copied) until touchdown. Returns quality rank and alpha.
  static landTucked(b0, sea, uTarget, delay, gScale, maxT) {
    const b = { x: b0.x, y: b0.y, vx: b0.vx, vy: b0.vy, u: b0.u };
    const k = 1 - Math.exp(-PRED_DT / T.tuckAttack);
    let t = 0;
    while (t < maxT) {
      const tu = t >= delay ? uTarget : b.u; // before `delay`, hold whatever u it had
      b.u += (tu - b.u) * k;
      const px = b.x, py = b.y; const d0 = py - sea.height(px);
      FlightPilot.stepAir(b, b.u, PRED_DT, gScale);
      const d1 = b.y - sea.height(b.x);
      if (d1 <= 0) {
        const fr = d0 > 0 ? clamp(d0 / (d0 - d1), 0, 1) : 1;
        const lx = px + (b.x - px) * fr;
        const phi = Math.atan(sea.slope(lx));
        const alpha = Math.abs(Math.atan2(b.vy, b.vx) - phi) * 180 / Math.PI;
        const phiDeg = phi * 180 / Math.PI;
        const rank = (alpha <= T.perfectAngleDeg && phiDeg < T.perfectSlopeDeg) ? 0 : (alpha <= T.goodAngleDeg ? 1 : 2);
        return { rank, alpha };
      }
      t += PRED_DT;
    }
    return { rank: 1, alpha: T.goodAngleDeg }; // no landing in sight: neutral
  }
  // Plan: seconds from now to start the tuck (Infinity = stay open to touchdown).
  plan(snap, sea, gScale) {
    const lag = this.p.assumedLag;
    const open = { x: snap.x, y: snap.y, vx: snap.vx, vy: snap.vy, u: snap.tuck };
    const k = 1 - Math.exp(-PRED_DT / T.tuckRelease);
    const ranks = [], alphas = [];
    let t = 0, landedOpen = null;
    let step = 0;
    while (t <= PRED_MAX_DELAY) {
      if (step % T.pilotBranchEvery === 0) {
        const r = FlightPilot.landTucked(open, sea, 1, lag, gScale, PRED_MAX_FLIGHT);
        ranks.push(r.rank); alphas.push(r.alpha);
      }
      step++;
      // advance the open path one step
      open.u += (0 - open.u) * k;
      const px = open.x, py = open.y; const d0 = py - sea.height(px);
      FlightPilot.stepAir(open, open.u, PRED_DT, gScale);
      const d1 = open.y - sea.height(open.x);
      t += PRED_DT;
      if (d1 <= 0) {
        const fr = d0 > 0 ? clamp(d0 / (d0 - d1), 0, 1) : 1;
        const lx = px + (open.x - px) * fr;
        const phi = Math.atan(sea.slope(lx));
        const alpha = Math.abs(Math.atan2(open.vy, open.vx) - phi) * 180 / Math.PI;
        const phiDeg = phi * 180 / Math.PI;
        landedOpen = { rank: (alpha <= T.perfectAngleDeg && phiDeg < T.perfectSlopeDeg) ? 0 : (alpha <= T.goodAngleDeg ? 1 : 2), alpha };
        break;
      }
    }
    // widest run of perfect delays
    let bestLen = 0, bestCentre = -1, run = 0;
    for (let i = 0; i < ranks.length; i++) {
      if (ranks[i] === 0) { run++; if (run > bestLen) { bestLen = run; bestCentre = i - (run - 1) / 2; } } else run = 0;
    }
    if (landedOpen && landedOpen.rank === 0) {
      // staying open is itself a perfect: prefer it unless a wider tucked window exists
      if (bestLen < 3) return Infinity;
    }
    const dd = PRED_DT * T.pilotBranchEvery;
    if (bestLen > 0) return bestCentre * dd;
    // no perfect: smallest alpha among good options (open landing included)
    let bi = -1, ba = 1e9;
    for (let i = 0; i < ranks.length; i++) if (ranks[i] <= 1 && alphas[i] < ba) { ba = alphas[i]; bi = i; }
    if (landedOpen && landedOpen.rank <= 1 && landedOpen.alpha <= ba) return Infinity;
    if (bi >= 0) return bi * dd;
    // everything splashes: smallest alpha overall
    for (let i = 0; i < ranks.length; i++) if (alphas[i] < ba) { ba = alphas[i]; bi = i; }
    if (landedOpen && landedOpen.alpha <= ba) return Infinity;
    return bi >= 0 ? bi * dd : Infinity;
  }
  desired(snap, sea) {
    if (snap.phase !== 'flying') return 0;
    const P = this.p;
    if (P.rhythm) {
      if (snap.time >= this.rhythmNext) { this.rhythmState = 1 - this.rhythmState; this.rhythmNext = snap.time + this.rng.range(0.55, 1.05); }
      return this.rhythmState;
    }
    if (snap.skimming) {
      this.wasSkimming = true; this.committed = false; this.tuckAt = 1e18;
      const ahead = snap.x + snap.speed * P.look;
      return sea.slope(ahead) < -0.03 ? 1 : 0;
    }
    if (this.wasSkimming) { this.wasSkimming = false; this.nextPlan = snap.time; this.committed = false; this.tuckAt = 1e18; }
    if (this.committed) return 1;
    if (snap.time >= this.nextPlan) {
      this.nextPlan = snap.time + P.replan;
      const gScale = 1 + (P.noise > 0 ? this.rng.range(-P.noise, P.noise) : 0);
      let d = this.plan(snap, sea, gScale);
      if (d !== Infinity) {
        if (P.jitter > 0) d += this.rng.range(-P.jitter, P.jitter);
        if (P.mistake > 0 && this.rng.unit() < P.mistake) d += (this.rng.unit() < 0.5 ? -1 : 1) * this.rng.range(0.12, 0.3);
        this.tuckAt = snap.time + Math.max(0, d);
      } else this.tuckAt = 1e18;
    }
    if (snap.time >= this.tuckAt) { this.committed = true; return 1; }
    return 0;
  }
  tuck(snap, sea) {
    const now = snap.time; const P = this.p;
    const dt = this.lastTime < 0 ? 0 : Math.max(0, now - this.lastTime); this.lastTime = now;
    const want = this.desired(snap, sea);
    this.history.push([now, want]);
    while (this.history.length > 1 && this.history[1][0] <= now - P.lag) this.history.shift();
    const seen = this.history[0][1];
    if (seen !== this.target && now - this.lastChange >= P.hold) { this.target = seen; this.lastChange = now; }
    if (snap.phase !== 'flying') this.target = 0;
    return this.target;
  }
}

// MARK: harness
function runOne(skill, seed, dt, cap) {
  const s = new FlightSession('flight', seed, 0);
  const pilot = new FlightPilot(skill, seed * 7 + 1);
  let t = 0; let snap = s.snapshot();
  const counts = { perfect: 0, good: 0, splash: 0, launched: 0, tailwindStarted: 0 };
  while (!s.finished && t < cap + 3) {
    const tuck = pilot.tuck(snap, s.sea);
    const ev = s.step(dt, tuck);
    for (const e of ev) if (counts[e] !== undefined) counts[e]++;
    t += dt; snap = s.snapshot();
    if (s.phase === 'caught' || s.finished) break;
  }
  const sec = s.phase === 'flying' ? s.flightTime : (s.caughtAt || s.flightTime);
  const x = s.caughtX !== undefined ? s.caughtX : s.x;
  return { sec, meters: x / 10, perfects: s.perfects, splashes: s.splashes, goods: s.goods, chain: s.bestChain,
    tail: s.tailwinds, maxSpeed: s.maxSpeed, maxAlt: s.maxAlt, clouds: s.cloudTouches, lh: s.lighthouses, capped: s.phase === 'flying' };
}
function pct(a, p) { const b = a.slice().sort((x, y) => x - y); const i = (b.length - 1) * p; const lo = Math.floor(i), hi = Math.ceil(i); return b[lo] + (b[hi] - b[lo]) * (i - lo); }

function main() {
  const args = {}; for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); args[k] = v === undefined ? true : v; }
  // Tuning overrides: T.liftMaxFraction=0.85
  for (const k of Object.keys(args)) if (k.startsWith('T.')) T[k.slice(2)] = parseFloat(args[k]);
  if (args.sea) return seaCheck(args);
  const seeds = parseInt(args.seeds || '20'); const dt = parseFloat(args.dt || String(1 / 120)); const cap = parseFloat(args.cap || '900');
  const skills = (args.skills || 'novice,casual,expert,perfect').split(',');
  for (const sk of skills) {
    const rs = []; for (let i = 0; i < seeds; i++) rs.push(runOne(sk, 1000 + i * 7919, dt, cap));
    const secs = rs.map(r => r.sec), m = rs.map(r => r.meters);
    const ppm = rs.map(r => r.perfects / Math.max(r.sec / 60, 1e-6));
    const avg = (f) => rs.reduce((a, r) => a + f(r), 0) / rs.length;
    console.log(`SWOOP-BAL skill=${sk} median=${pct(secs, .5).toFixed(1)}s p10=${pct(secs, .1).toFixed(1)} p90=${pct(secs, .9).toFixed(1)} ` +
      `medianMeters=${pct(m, .5).toFixed(0)} perfects/min=${pct(ppm, .5).toFixed(1)} splash/min=${avg(r => r.splashes / (r.sec / 60)).toFixed(1)} ` +
      `good/min=${avg(r => r.goods / (r.sec / 60)).toFixed(1)} chain=${avg(r => r.chain).toFixed(1)} tail=${avg(r => r.tail).toFixed(1)} vmax=${avg(r => r.maxSpeed).toFixed(0)} ` +
      `alt=${avg(r => r.maxAlt).toFixed(0)} clouds=${avg(r => r.clouds).toFixed(1)} lh=${avg(r => r.lh).toFixed(1)} capped=${rs.filter(r => r.capped).length}`);
    if (args.v) console.log('   secs', secs.map(x => x.toFixed(0)).join(' '));
  }
}

function seaCheck(args) {
  const seeds = parseInt(args.seeds || '5'); const km = parseFloat(args.km || '200');
  for (let i = 0; i < seeds; i++) {
    const sea = new SeaProfile(1000 + i * 7919);
    let maxS = 0, maxH = 0, jumpH = 0, jumpD = 0, prevH = null, prevD = null;
    const step = 2;
    for (let x = -2000; x <= km * 10000; x += step) {
      const [h, d] = sea.eval(x);
      maxS = Math.max(maxS, Math.abs(d)); maxH = Math.max(maxH, Math.abs(h));
      if (prevH !== null) { jumpH = Math.max(jumpH, Math.abs(h - prevH) - Math.abs(prevD) * step * 1.2); jumpD = Math.max(jumpD, Math.abs(d - prevD)); }
      prevH = h; prevD = d;
    }
    // finite-difference check of slope vs height
    let fdErr = 0; for (let x = 0; x < 200000; x += 37.3) { const fd = (sea.height(x + 0.5) - sea.height(x - 0.5)); fdErr = Math.max(fdErr, Math.abs(fd - sea.slope(x))); }
    console.log(`sea seed=${1000 + i * 7919} sets=${sea.sets.length} maxSlope=${maxS.toFixed(4)} maxH=${maxH.toFixed(0)} dDstep=${jumpD.toFixed(4)} fdErr=${fdErr.toFixed(5)} scales=${sea.blendScales} fallbacks=${sea.blendFallbacks} rogues=${sea.sets.filter(s => s.rogue).length}`);
  }
}

if (require.main === module) main();
module.exports = { T, SeaProfile, FlightSession, FlightPilot, SeededRandom, runOne };
