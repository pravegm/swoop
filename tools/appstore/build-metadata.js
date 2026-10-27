// Usage (repo root): node tools/appstore/build-metadata.js
// Regenerates docs/appstore/asc-metadata.json and tools/appstore/fixtures/asc-metadata.sample.json from Swoop's docs:
// metadata.md (§1–§5 text, §7 categories, §8 age rating, §9 price/availability/release/copyright/URLs),
// review-notes.md (the REVIEW-NOTES block), achievements.md (the 12 achievements and 2 leaderboards) and
// featuring-nomination.md. Where a doc gives no machine-readable value, the constant below names the decision row in
// docs/appstore/DECISIONS.md it comes from. Ported from Brim's tools/appstore/build-metadata.js (pravegm/brim).
// It also cross-checks the runbook's §4b table (docs/LAUNCH-RUNBOOK.md) against achievements.md and prints any
// difference: the docs, not this script, must be fixed.
const fs = require('fs'), path = require('path');
const root = process.argv[2] || path.join(__dirname, '..', '..');
const outFile = process.argv[3] || path.join(root, 'docs/appstore/asc-metadata.json');
const fixtureFile = process.argv[4] || path.join(root, 'tools/appstore/fixtures/asc-metadata.sample.json');
const rd = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const problems = [];
function blockAfter(text, marker) {
  const i = text.indexOf(marker); if (i < 0) throw new Error('marker ' + marker);
  const s = text.indexOf('```\n', i) + 4;
  const e = text.indexOf('\n```', s);
  return text.slice(s, e);
}
function need(text, what, file) { if (!text.includes(what)) problems.push(`${file} no longer says ${JSON.stringify(what)}: check the constant that relies on it`); }

// ---- metadata.md ----------------------------------------------------------------------------------------------------
const md = rd('docs/appstore/metadata.md');
const name = blockAfter(md, '## 1. App name');
const subtitle = blockAfter(md, '## 2. Subtitle');
const promo = blockAfter(md, '## 3. Promotional text');
const descGB = blockAfter(md, '### en-GB (English U.K.)');
const descUS = blockAfter(md, '### en-US (English U.S.)');
const keywords = blockAfter(md, '## 5. Keywords');

// §7 Category (API values from the table). DECISIONS #7: Casual + Arcade, secondary Entertainment.
const catRows = Object.fromEntries([...md.matchAll(/^\| (Primary|Game subcategory 1|Game subcategory 2|Secondary category) \| [^|]+\| `([A-Z_]+)` \|$/gm)].map(m => [m[1], m[2]]));
const categories = {
  _comment: 'metadata.md §7 / DECISIONS #7. Apple dropped GAMES_ARCADE from its live list on 26 Oct 2026 (Brim run 40340641267). The categories step reads the live list first; a wanted subcategory that is not on it is replaced by the first live entry of fallbackSubcategories, or dropped (Casual alone). DECISIONS #7 names Action as the fallback; check/plan print what would be pushed.',
  primary: catRows['Primary'],
  primarySubcategories: [catRows['Game subcategory 1'], catRows['Game subcategory 2']].filter(Boolean),
  // DECISIONS #7 (27 Oct): Arcade if Apple's live list still has it, otherwise Action.
  fallbackSubcategories: ['GAMES_ACTION'],
  secondary: catRows['Secondary category'] || null
};
if (categories.primary !== 'GAMES' || categories.primarySubcategories.length !== 2) problems.push('metadata.md §7: category table not parsed: ' + JSON.stringify(catRows));

// §9: URLs, price, availability, release, copyright.
const site = 'https://pravegm.github.io/swoop/';
for (const u of [site, site + 'support.html', site + 'privacy.html']) need(md, '`' + u + '`', 'metadata.md §9');
need(md, '**United Kingdom, £1.99**', 'metadata.md §9');
need(md, '**except China mainland and Vietnam**', 'metadata.md §9');
need(md, '**Automatically release this version after App Review approval**', 'metadata.md §9');
const copyrightLine = (md.match(/^\| Copyright \| `([^`]+)` \|$/m) || [])[1];
if (!copyrightLine) problems.push('metadata.md §9: Copyright row not found');

// DECISIONS #12 (founder, 27 Oct): release automatically as soon as Apple approves (AFTER_APPROVAL), so
// launch morning needs no click.
const RELEASE = { type: 'AFTER_APPROVAL', earliestReleaseDate: null };
const LAUNCH = '2026-10-30T08:00:00Z';   // DECISIONS #13: the expected go-live (approval ~24-48 h after submission); nomination publish date

// ---- review-notes.md, featuring-nomination.md -----------------------------------------------------------------------
const rn = rd('docs/appstore/review-notes.md');
const notes = blockAfter(rn, '<!-- REVIEW-NOTES:BEGIN -->');
const fn = rd('docs/appstore/featuring-nomination.md');
const nomDesc = blockAfter(fn, '### Description');
const nomNotes = blockAfter(fn, '### Helpful Details');
const nomName = (fn.match(/\| Nomination Name \| `([^`]+)`/) || [])[1];
need(fn, 'Specific day: 2026-10-30', 'featuring-nomination.md');

// ---- achievements.md ------------------------------------------------------------------------------------------------
// | # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger |
// A cell "en-GB / en-US" holds the two spellings (kilometre / kilometer).
const ach = rd('docs/appstore/achievements.md');
const rows = ach.split('\n').filter(l => /^\| \d+ \| `swoop\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
function split2(c) { const p = c.split(' / '); return [p[0], p[1] || p[0]]; }
const achievements = rows.map(r => {
  const id = r[1].replace(/`/g, '');
  const [tGB, tUS] = split2(r[2]), [bGB, bUS] = split2(r[3]), [aGB, aUS] = split2(r[4]);
  const hidden = /yes/i.test(r[6]);
  const loc = (n, b, a) => ({ name: n, beforeEarnedDescription: b, afterEarnedDescription: a });
  return { vendorIdentifier: id, referenceName: tGB, points: parseInt(r[5], 10), showBeforeEarned: !hidden, repeatable: false,
    localizations: { 'en-GB': loc(tGB, bGB, aGB), 'en-US': loc(tUS, bUS, aUS) }, image: `tools/appstore/badges/${id}.png` };
});
// Leaderboards: achievements.md "Leaderboards (2)" and DECISIONS #18 (whole metres, suffix " m" singular and plural,
// High to Low, best score, range 0–1,000,000; swoop.daily recurring daily from Wed 28 Oct 2026 00:00 UTC).
for (const s of ['`swoop.longest`', '`swoop.daily`', '`Longest flight`', '`Daily Flight`', '`Longest Flight`', '` m` / ` m`',
                 '0 – 1,000,000', 'Start **Wed 28 Oct 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day**']) need(ach, s, 'achievements.md');
const lbLoc = (n) => ({ name: n, formatterSuffix: ' m', formatterSuffixSingular: ' m' });
const leaderboards = [
  { vendorIdentifier: 'swoop.longest', referenceName: 'Longest flight', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 1000000, recurrence: null, localizations: { 'en-GB': lbLoc('Longest Flight'), 'en-US': lbLoc('Longest Flight') } },
  { vendorIdentifier: 'swoop.daily', referenceName: 'Daily Flight', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 1000000,
    recurrence: { startDate: '2026-10-28T00:00:00Z', duration: 'PT24H', rule: 'FREQ=DAILY;INTERVAL=1' },
    localizations: { 'en-GB': lbLoc('Daily Flight'), 'en-US': lbLoc('Daily Flight') } }
];

// ---- runbook §4b cross-check (the founder's click list must say the same as achievements.md) -------------------------
const rb = rd('docs/LAUNCH-RUNBOOK.md');
const rbRows = rb.split('\n').filter(l => /^\| `swoop\.ach\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
for (const r of rbRows) {
  const id = r[0].replace(/`/g, ''), a = achievements.find(x => x.vendorIdentifier === id);
  if (!a) { problems.push(`runbook §4b lists ${id}, achievements.md does not`); continue; }
  const g = a.localizations['en-GB'];
  const cmp = [['title', r[1], g.name], ['before', r[2], g.beforeEarnedDescription], ['after', r[3], g.afterEarnedDescription], ['points', r[4], String(a.points)]];
  for (const [k, x, y] of cmp) if (x !== y) problems.push(`runbook §4b ${id} ${k}: ${JSON.stringify(x)} vs achievements.md ${JSON.stringify(y)}`);
}
if (rbRows.length !== achievements.length) problems.push(`runbook §4b has ${rbRows.length} achievements, achievements.md ${achievements.length}`);

// ---- screenshots (docs/appstore/screenshots.md; DECISIONS #16: 8 per set) --------------------------------------------
// Paths inside a downloaded store.yml run: the workflow runs `gh run download <run> -n store-69 -D <dir>/store-69`, and
// store.yml uploads raw-69/store/ itself, so the PNGs sit at the artifact's top level (store-69/P01-book-hero.png).
// Flagged frames live in _flagged/ and so never resolve here. P09 (Route) and P10 (Flight School) are "recommended"
// in screenshots.md: add them to FRAMES (and to its upload order) once their MANIFEST lines are clean.
const FRAMES = ['01-book-hero', '02-perfect', '03-storm', '04-lighthouse', '05-tailwind', '06-moonrise', '07-results', '08-birds'];
const ssc = rd('ci/store-scenarios.txt'), dsc = rd('ci/duo-store-scenarios.txt');
for (const f of FRAMES) { need(ssc, '\nP' + f + '|', 'ci/store-scenarios.txt'); need(dsc, '\nD' + f + '|', 'ci/duo-store-scenarios.txt'); }
const screenshots = {
  _comment: 'store.yml artifacts store-69 (6.9", 2868x1320), store-63 (6.3", 2622x1206: App Store Connect\'s required "Dynamic Island, medium" slot, the APP_IPHONE_61 class) and store-duo (inner 2853x2007), all landscape. Frames P01-P08 / D01-D08 (DECISIONS #16, screenshots.md order). DEFAULT_STORE_RUN in .github/workflows/asc.yml names the run.',
  APP_IPHONE_67: FRAMES.map(n => `store-69/P${n}.png`),
  APP_IPHONE_61: FRAMES.map(n => `store-63/P${n}.png`),
  duoInner: FRAMES.map(n => `store-duo/D${n}.png`)
};

const meta = {
  _comment: 'Generated by tools/appstore/build-metadata.js from docs/appstore/metadata.md, review-notes.md, achievements.md and featuring-nomination.md (and DECISIONS.md for the rows named in the script); asc.swift pushes it (tools/appstore/README.md). Do not edit by hand: change the docs and regenerate. No personal data: the App Review contact is read at run time from Squish (--inherit-from com.pravegm.squish). The copyright is DECISIONS #31 (the public handle, not a personal name).',
  bundleId: 'com.pravegm.swoop',
  primaryLocale: 'en-GB',
  copyrightHolder: copyrightLine || null,
  contentRights: 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
  categories,
  localizations: {
    'en-GB': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descGB, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site },
    'en-US': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descUS, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site }
  },
  ageRating: {
    _comment: 'metadata.md §8 (DECISIONS #8): 4+; every content item None, every capability No, Contests None (leaderboards are not prize contests), not Made for Kids. Names from AgeRatingDeclarationUpdateRequest (as Brim, API docs read 26 Oct 2026).',
    parentalControls: false, ageAssurance: false, unrestrictedWebAccess: false, userGeneratedContent: false, messagingAndChat: false,
    advertising: false, socialMedia: false, socialMediaAgeRestricted: false,
    profanityOrCrudeHumor: 'NONE', horrorOrFearThemes: 'NONE', alcoholTobaccoOrDrugUseOrReferences: 'NONE', matureOrSuggestiveThemes: 'NONE',
    medicalOrTreatmentInformation: 'NONE', healthOrWellnessTopics: false, sexualContentOrNudity: 'NONE', sexualContentGraphicAndNudity: 'NONE',
    violenceCartoonOrFantasy: 'NONE', violenceRealistic: 'NONE', violenceRealisticProlongedGraphicOrSadistic: 'NONE', gunsOrOtherWeapons: 'NONE',
    gamblingSimulated: 'NONE', contests: 'NONE', gambling: false, lootBox: false, kidsAgeBand: null,
    ageRatingOverrideV2: 'NONE', koreaAgeRatingOverride: 'NONE'
  },
  review: { notes, demoAccountRequired: false, contact: { firstName: null, lastName: null, phone: null, email: null } },
  release: { _comment: 'DECISIONS #12 (founder, 27 Oct): released automatically as soon as App Review approves it. The tool never releases or submits.', ...RELEASE },
  price: { baseTerritory: 'GBR', customerPrice: '1.99' },
  availability: { _comment: 'DECISIONS #10 (27 Oct): every territory except China mainland and Vietnam (both need a local game licence; Brim excludes both). Mac and Vision Pro availability has no public API: the tool prints the clicks.', excludedTerritories: ['CHN', 'VNM'], availableInNewTerritories: true },
  achievements,
  leaderboards,
  screenshots,
  nomination: {
    _comment: 'docs/appstore/featuring-nomination.md (DECISIONS #26). notes = Helpful Details. submit: true presses Submit (a saved draft is not a nomination). Submitted with the listing, ahead of release on approval.',
    name: nomName, type: 'APP_LAUNCH', description: nomDesc, notes: nomNotes, publishStartDate: LAUNCH,
    deviceFamilies: ['IPHONE'], locales: ['en-GB', 'en-US'], supplementalMaterialsUris: [site],
    hasInAppEvents: false, launchInSelectMarketsFirst: false, preOrderEnabled: false, submit: true
  }
};

// ---- the validator's own checks, early (asc.swift validate is the authority) ----------------------------------------
const c = s => [...s].length, b = s => Buffer.byteLength(s);
const placeholder = s => (s.includes('[') && s.includes(']')) || /todo|tbd|placeholder|example\.com|\{domain\}|<domain>/i.test(s);
const limits = [['name', name, 30], ['subtitle', subtitle, 30], ['promo', promo, 170], ['descGB', descGB, 4000], ['descUS', descUS, 4000], ['nomName', nomName, 60], ['nomDesc', nomDesc, 1000], ['nomNotes', nomNotes, 500]];
for (const [k, v, l] of limits) { if (!v) problems.push(`${k}: empty`); else { if (c(v) > l) problems.push(`${k}: ${c(v)} > ${l}`); if (placeholder(v)) problems.push(`${k}: looks like a placeholder to asc.swift`); } }
if (b(keywords) > 100) problems.push(`keywords: ${b(keywords)} bytes > 100`);
if (b(notes) > 4000) problems.push(`review notes: ${b(notes)} bytes > 4000`);
if (placeholder(notes)) problems.push('review notes look like a placeholder to asc.swift (brackets, TODO, TBD)');
const pts = achievements.reduce((a, x) => a + x.points, 0);
if (achievements.length !== 12) problems.push(`achievements: ${achievements.length}, expected 12`);
if (pts !== 625) problems.push(`achievement points: ${pts}, expected 625 (DECISIONS #20)`);
if (achievements.some(a => !a.showBeforeEarned)) problems.push('an achievement is hidden; DECISIONS #20 says none');

fs.writeFileSync(outFile, JSON.stringify(meta, null, 2) + '\n');
console.log({ name: c(name), subtitle: c(subtitle), promo: c(promo), descGB: c(descGB), descUS: c(descUS), kwBytes: b(keywords), notesBytes: b(notes),
  nomName: c(nomName), nomDesc: c(nomDesc), nomNotes: c(nomNotes), ach: achievements.length, pts, copyright: meta.copyrightHolder,
  categories: [categories.primary, ...categories.primarySubcategories, categories.secondary].join(' '), release: RELEASE.type });
console.log(achievements.map(a => `${a.vendorIdentifier} ${a.points} show=${a.showBeforeEarned} | ${a.localizations['en-US'].name} | ${a.localizations['en-US'].beforeEarnedDescription} | ${a.localizations['en-US'].afterEarnedDescription}`).join('\n'));

const fx = JSON.parse(JSON.stringify(meta));
fx._comment = 'CI fixture for asc.swift validate (a placeholder URL, a partial en-US, missing images, no screenshots). The real data is docs/appstore/asc-metadata.json.';
fx.localizations['en-GB'].supportUrl = 'https://[SITE]/support.html';
fx.localizations['en-US'] = { description: descUS };
fx.achievements = fx.achievements.map(a => ({ ...a, localizations: { 'en-GB': a.localizations['en-GB'] }, image: 'tools/appstore/fixtures/missing.png' }));
delete fx.screenshots;
fs.writeFileSync(fixtureFile, JSON.stringify(fx, null, 2) + '\n');

if (problems.length) {
  console.log('\nDOC PROBLEMS (fix the docs, then regenerate):\n  ' + problems.join('\n  '));
  process.exitCode = 1;
} else {
  console.log('\nOK: docs consistent with each other for every value this script reads.');
}
