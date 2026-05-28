#!/usr/bin/env node
// Usage: node scripts/extract-photo-meta.mjs <slug> <imageDir>
// Example: node scripts/extract-photo-meta.mjs kyoto-winter public/images/kyoto
//
// Reads EXIF (timestamp + GPS) from every .jpg in <imageDir>, writes
// src/data/photo-meta/<slug>.json sorted by capture time. The Astro
// trail-map component consumes this JSON at build time.

import { readdir, mkdir, writeFile } from 'node:fs/promises';
import { join, basename, relative, sep } from 'node:path';
import exifr from 'exifr';

const [, , slug, imageDir] = process.argv;
if (!slug || !imageDir) {
  console.error('Usage: node scripts/extract-photo-meta.mjs <slug> <imageDir>');
  process.exit(1);
}

// Filename is canonical local-time source — YYYYMMDD_HHMMSS.jpg matches
// what the user sees in the post.
function parseFilenameTime(name) {
  const m = name.match(/^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/);
  if (!m) return null;
  const [, Y, M, D, h, mi, s] = m;
  return `${Y}-${M}-${D}T${h}:${mi}:${s}`;
}

const files = (await readdir(imageDir))
  .filter((f) => /\.jpe?g$/i.test(f))
  .sort();

const entries = [];
for (const f of files) {
  const abs = join(imageDir, f);
  let gps = null;
  try {
    gps = await exifr.parse(abs, { gps: true });
  } catch (e) {
    console.warn(`! ${f}: EXIF read failed (${e.message})`);
  }
  const time = parseFilenameTime(f);
  if (!gps || gps.latitude == null || gps.longitude == null) {
    console.warn(`! ${f}: no GPS, skipping`);
    continue;
  }
  // Public URL path — strip "public/" prefix so it works in <img src>.
  const publicPath = '/' + relative('public', abs).split(sep).join('/');
  entries.push({
    file: f,
    src: publicPath,
    time,
    lat: +gps.latitude.toFixed(6),
    lng: +gps.longitude.toFixed(6),
  });
}

entries.sort((a, b) => (a.time || '').localeCompare(b.time || ''));

const outDir = 'src/data/photo-meta';
await mkdir(outDir, { recursive: true });
const outPath = join(outDir, `${slug}.json`);
await writeFile(outPath, JSON.stringify(entries, null, 2) + '\n');

console.log(`${outPath}: ${entries.length} photos with GPS`);
