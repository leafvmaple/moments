#!/usr/bin/env node
// Usage: node scripts/extract-photo-meta.mjs <slug> <imageDir>
// Example: node scripts/extract-photo-meta.mjs kyoto-winter public/images/kyoto
//
// Reads EXIF (timestamp + GPS) from every .jpg in <imageDir>, writes
// src/data/photo-meta/<slug>.json sorted by capture time. The Astro
// trail-map component consumes this JSON at build time.
//
// GPS fallback chain (per photo):
//   1. EXIF GPS in the public file itself.
//   2. EXIF GPS in photos/extracted/IMG_*_<HHMMSS>*.jpg with matching
//      timestamp (rescue from re-saved or Snapseed-stripped versions).
//   3. Nearest GPS-bearing peer in the same slug within ±60 minutes
//      (borrow location for files that never had GPS but are clearly
//      at the same scene/neighborhood as their neighbors). 60 min is
//      tight enough that travel typically stays in one district.
//   4. Skip with warning — no usable coordinates anywhere.

import { readdir, mkdir, writeFile, readFile } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { existsSync } from 'node:fs';
import exifr from 'exifr';

const [, , slug, imageDir] = process.argv;
if (!slug || !imageDir) {
  console.error('Usage: node scripts/extract-photo-meta.mjs <slug> <imageDir>');
  process.exit(1);
}

const EXTRACTED_DIR = 'photos/extracted';

// Filename is canonical local-time source — YYYYMMDD_HHMMSS.jpg matches
// what the user sees in the post.
function parseFilenameTime(name) {
  const m = name.match(/^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/);
  if (!m) return null;
  const [, Y, M, D, h, mi, s] = m;
  return { iso: `${Y}-${M}-${D}T${h}:${mi}:${s}`, date: `${Y}${M}${D}`, hhmmss: `${h}${mi}${s}` };
}

async function readGps(path) {
  try {
    const gps = await exifr.parse(path, { gps: true });
    if (gps && gps.latitude != null && gps.longitude != null) {
      return { lat: +gps.latitude.toFixed(6), lng: +gps.longitude.toFixed(6) };
    }
  } catch {}
  return null;
}

// Look in photos/extracted/ for an IMG_<date>_<hhmmss>*.jpg with usable GPS.
async function rescueFromExtracted(date, hhmmss) {
  if (!existsSync(EXTRACTED_DIR)) return null;
  let candidates;
  try {
    candidates = await readdir(EXTRACTED_DIR);
  } catch {
    return null;
  }
  const prefix = `IMG_${date}_${hhmmss}`;
  for (const name of candidates) {
    if (!name.startsWith(prefix)) continue;
    const gps = await readGps(join(EXTRACTED_DIR, name));
    if (gps) return { ...gps, source: `extracted/${name}` };
  }
  return null;
}

// If the output JSON already exists, preserve entries flagged
// `manual: true` so a hand-supplemented coordinate survives re-runs.
const outDir = 'src/data/photo-meta';
const outPath = join(outDir, `${slug}.json`);
const manualOverrides = new Map();
if (existsSync(outPath)) {
  try {
    const prev = JSON.parse(await readFile(outPath, 'utf8'));
    for (const e of prev) {
      if (e && e.manual === true && e.file && e.lat != null && e.lng != null) {
        manualOverrides.set(e.file, e);
      }
    }
  } catch {}
}

const files = (await readdir(imageDir))
  .filter((f) => /\.jpe?g$/i.test(f))
  .sort();

// Pass 1: collect filename metadata + public-file GPS + extracted-rescue GPS.
const records = [];
for (const f of files) {
  const abs = join(imageDir, f);
  const t = parseFilenameTime(f);
  if (!t) {
    console.warn(`! ${f}: filename does not match YYYYMMDD_HHMMSS pattern, skipping`);
    continue;
  }
  let gps = await readGps(abs);
  let gpsSource = gps ? 'self' : null;
  if (!gps) {
    const rescued = await rescueFromExtracted(t.date, t.hhmmss);
    if (rescued) {
      gps = { lat: rescued.lat, lng: rescued.lng };
      gpsSource = rescued.source;
    }
  }
  records.push({ file: f, time: t.iso, hhmmss: t.hhmmss, abs, gps, gpsSource });
}

// Pass 2: borrow from nearest GPS-bearing peer for any still missing.
const withGps = records.filter((r) => r.gps);
const NEIGHBOR_WINDOW_MIN = 60;
function minutesBetween(a, b) {
  return Math.abs(new Date(a).getTime() - new Date(b).getTime()) / 60000;
}
for (const r of records) {
  if (r.gps) continue;
  let best = null;
  let bestDelta = Infinity;
  for (const peer of withGps) {
    const delta = minutesBetween(r.time, peer.time);
    if (delta < bestDelta) {
      bestDelta = delta;
      best = peer;
    }
  }
  if (best && bestDelta <= NEIGHBOR_WINDOW_MIN) {
    r.gps = { lat: best.gps.lat, lng: best.gps.lng };
    r.gpsSource = `borrowed:${best.file} (±${bestDelta.toFixed(1)}min)`;
  }
}

// Emit JSON for entries with GPS. Track each photo's GPS source so the
// user can audit and supplement borrowed/missing coordinates.
const entries = [];
const fallbackRecovered = [];
const peerBorrowed = [];
const manualKept = [];
const skipped = [];

for (const r of records) {
  const override = manualOverrides.get(r.file);
  const publicPath = '/' + relative('public', r.abs).split(sep).join('/');
  if (override) {
    // Manual override wins regardless of what the source/fallback found.
    entries.push({
      file: r.file,
      src: publicPath,
      time: r.time,
      lat: override.lat,
      lng: override.lng,
      gpsSource: override.gpsSource ?? 'manual',
      manual: true,
    });
    manualKept.push(r.file);
    continue;
  }
  if (!r.gps) {
    skipped.push(r.file);
    continue;
  }
  const entry = {
    file: r.file,
    src: publicPath,
    time: r.time,
    lat: r.gps.lat,
    lng: r.gps.lng,
  };
  if (r.gpsSource !== 'self') {
    // Persist the source so we never forget which markers are inferred.
    entry.gpsSource = r.gpsSource;
    if (r.gpsSource.startsWith('borrowed:')) peerBorrowed.push({ file: r.file, source: r.gpsSource });
    else fallbackRecovered.push({ file: r.file, source: r.gpsSource });
  }
  entries.push(entry);
}

entries.sort((a, b) => (a.time || '').localeCompare(b.time || ''));

await mkdir(outDir, { recursive: true });
await writeFile(outPath, JSON.stringify(entries, null, 2) + '\n');

// Summary log — surface everything that didn't come from the photo's
// own EXIF so the user can decide whether to supplement manually.
console.log('');
console.log(`=== GPS audit for ${slug} ===`);
const selfCount = entries.length - fallbackRecovered.length - peerBorrowed.length - manualKept.length;
console.log(`  self EXIF:                ${selfCount}`);
console.log(`  manual (preserved):       ${manualKept.length}`);
for (const f of manualKept) console.log(`    ${f}`);
console.log(`  rescued from extracted/:  ${fallbackRecovered.length}`);
for (const r of fallbackRecovered) console.log(`    ${r.file} <- ${r.source}`);
console.log(`  borrowed from peer:       ${peerBorrowed.length}`);
for (const r of peerBorrowed) {
  const m = r.source.match(/±([\d.]+)min/);
  const delta = m ? +m[1] : 0;
  const flag = delta > 10 ? ' [REVIEW]' : '';
  console.log(`    ${r.file} <- ${r.source}${flag}`);
}
console.log(`  missing entirely:         ${skipped.length}`);
for (const f of skipped) console.log(`    ${f}  [SUPPLEMENT NEEDED]`);
console.log(`  ----`);
console.log(`  ${outPath}: ${entries.length} markers written`);
if (peerBorrowed.some((r) => /±([\d.]+)min/.test(r.source) && +r.source.match(/±([\d.]+)min/)[1] > 10) ||
    skipped.length > 0) {
  console.log(`  → review entries marked [REVIEW] / [SUPPLEMENT NEEDED] above`);
}

// Sync TODO.md with this slug's "needs supplement" entries (borrowed +
// skipped). Preserves checked items and entries from other slugs.
await updateTodo(slug, peerBorrowed, skipped);

async function updateTodo(slug, borrowed, missing) {
  const todoPath = 'TODO.md';
  if (!existsSync(todoPath)) return;
  const START = '<!-- GPS_TODO:START -->';
  const END = '<!-- GPS_TODO:END -->';
  const newForSlug = [
    ...borrowed.map((r) => ({ path: `${slug}/${r.file}`, source: r.source })),
    ...missing.map((f) => ({ path: `${slug}/${f}`, source: 'missing entirely' })),
  ];
  let todo = await readFile(todoPath, 'utf8');
  const sIdx = todo.indexOf(START);
  const eIdx = todo.indexOf(END);
  // Parse existing items (preserve check state and items from other slugs).
  const existing = [];
  if (sIdx !== -1 && eIdx !== -1 && sIdx < eIdx) {
    for (const line of todo.slice(sIdx + START.length, eIdx).split('\n')) {
      const m = line.match(/^- \[([ x])\] (\S+) — (.+)$/);
      if (m) existing.push({ checked: m[1] === 'x', path: m[2], source: m[3] });
    }
  }
  const otherSlug = existing.filter((i) => !i.path.startsWith(slug + '/'));
  const currentSlugExisting = existing.filter((i) => i.path.startsWith(slug + '/'));
  const currentSlug = newForSlug.map((np) => {
    const prev = currentSlugExisting.find((i) => i.path === np.path);
    return { checked: prev ? prev.checked : false, path: np.path, source: np.source };
  });
  const merged = [...otherSlug, ...currentSlug].sort((a, b) => a.path.localeCompare(b.path));
  const rendered = merged.map((i) => `- [${i.checked ? 'x' : ' '}] ${i.path} — ${i.source}`).join('\n');
  if (sIdx !== -1 && eIdx !== -1) {
    todo = todo.slice(0, sIdx) + START + '\n' + rendered + '\n' + todo.slice(eIdx);
  } else {
    const newSection = `

## 待补全坐标 (Trail Map)

> 自动生成区域：跑 \`extract-photo-meta.mjs\` 时会刷新下面这段（保留勾过的 \`[x]\` 和其他 slug 的条目）。
>
> - 资料够认出地标 → 把 \`src/data/photo-meta/<slug>.json\` 对应条目的 lat/lng 改对、加 \`"manual": true\` —— 下次跑就从这里消失
> - 借用的坐标已经足够近、可以接受 → 把 \`[ ]\` 改成 \`[x]\` —— 下次跑保留 \`[x]\` 标记

${START}
${rendered}
${END}
`;
    todo = todo.trimEnd() + newSection;
  }
  await writeFile(todoPath, todo);
  console.log(`  TODO.md: ${currentSlug.length} entries for ${slug}`);
}
