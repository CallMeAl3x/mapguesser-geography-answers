// Assemble les CSV publiés à partir de data/raw (sortie de extract.sql).
//   MAPGUESSER_ROOT=~/Documents/MapGuesser bun scripts/build.ts
// Ne garde que les pays et territoires du jeu (254), ajoute leurs noms, calcule les taux.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dir, '..');
const MG = process.env.MAPGUESSER_ROOT ?? path.join(process.env.HOME!, 'Documents/MapGuesser');
const core: Record<string, any> = JSON.parse(readFileSync(path.join(MG, 'src/data/countries-core.json'), 'utf8'));

const readCsv = (file: string) => {
  const [head, ...lines] = readFileSync(path.join(ROOT, 'data/raw', file), 'utf8').trim().split('\n');
  const cols = head.split(',');
  return lines.map((l) => Object.fromEntries(l.split(',').map((v, i) => [cols[i], v])));
};
const esc = (v: unknown) => {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const writeCsv = (file: string, rows: Record<string, unknown>[]) => {
  const cols = Object.keys(rows[0]);
  writeFileSync(path.join(ROOT, 'data', file), [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\n') + '\n');
  console.log(`${file}: ${rows.length} lignes`);
};
const name = (code: string) => core[code]?.name?.en ?? '';
const known = (code: string) => code in core;
const pct = (a: number, b: number) => (b ? Math.round((1000 * a) / b) / 10 : 0);

// Pays du jeu
writeCsv(
  'countries.csv',
  Object.entries(core)
    .map(([code, c]) => ({
      code,
      name_en: c.name?.en ?? '',
      name_fr: c.name?.fr ?? '',
      continent_en: c.continent?.en ?? '',
      un_member: c.isUNMember ? 1 : 0,
    }))
    .sort((a, b) => a.code.localeCompare(b.code)),
);

// Difficulté par pays
const diff = readCsv('country_difficulty.csv').filter((r) => known(r.code));
const roundsOf = new Map(diff.map((r) => [r.code, +r.rounds]));
writeCsv(
  'country_difficulty.csv',
  diff
    .map((r) => ({
      code: r.code,
      name_en: name(r.code),
      rounds: +r.rounds,
      players: +r.players,
      failed_rounds: +r.failed_rounds,
      fail_rate_pct: pct(+r.failed_rounds, +r.rounds),
      skipped_without_answer: +r.skipped_without_answer,
      skip_rate_pct: pct(+r.skipped_without_answer, +r.rounds),
      avg_attempts: +r.avg_attempts,
    }))
    .sort((a, b) => b.fail_rate_pct - a.fail_rate_pct || a.code.localeCompare(b.code)),
);

// Paires de confusion. COD -> COG est écarté : « congo » est un nom ambigu, pas une erreur de carte.
writeCsv(
  'confusion_pairs.csv',
  readCsv('confusion_pairs.csv')
    .filter((r) => known(r.shown_code) && known(r.typed_code) && !(r.shown_code === 'COD' && r.typed_code === 'COG'))
    .map((r) => ({
      shown_code: r.shown_code,
      shown_name: name(r.shown_code),
      typed_code: r.typed_code,
      typed_name: name(r.typed_code),
      answers: +r.answers,
      rounds: +r.rounds,
      players: +r.players,
      pct_of_shown_rounds: pct(+r.rounds, roundsOf.get(r.shown_code) ?? 0),
    })),
);

// Lieux tapés à la place d'un pays (liste fermée de extract.sql)
writeCsv(
  'typed_places.csv',
  readCsv('typed_places.csv')
    .filter((r) => known(r.shown_code))
    .map((r) => ({ typed_place: r.place, shown_code: r.shown_code, shown_name: name(r.shown_code), answers: +r.answers, players: +r.players })),
);

// Résumé
const [s] = readCsv('summary.csv');
writeFileSync(path.join(ROOT, 'data/summary.json'), JSON.stringify({ ...s, answers: +s.answers, rounds: +s.rounds, players: +s.players }, null, 2) + '\n');
console.log('summary.json', s);
