-- Extraction des agrégats publiés, à lancer en LECTURE SEULE sur la base de MapGuesser :
--   sed "s|__OUT__|$PWD/data/raw|g" scripts/extract.sql | psql "$DATABASE_URL"
-- Rien d'identifiant ne sort : uniquement des comptes, avec au moins 3 joueurs distincts par ligne.
\set QUIET on
\pset footer off
-- Seuls des objets TEMPORAIRES sont créés (disparus à la déconnexion) : aucune écriture dans les tables.

-- Réponses des vrais joueurs (bots du site exclus), mode Mapguessing (seul mode tracé dans cette table).
CREATE TEMP VIEW att AS
SELECT a."userId" AS uid, a."sessionId" AS sid, a."roundNumber" AS rnd,
       a."targetCountryCode" AS tgt, a."isCorrect" AS ok,
       a."chosenCountryName" = 'Skipped' AS skipped,
       lower(translate(btrim(a."chosenCountryName"),
         'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ','aaaaaaceeeeiiiinooooouuuuyy')) AS nm,
       a."createdAt" AS at
FROM "UserRoundAttempt" a JOIN "User" u ON u.id = a."userId"
WHERE u.name NOT LIKE 'Magellan.exe%';

-- 1. Difficulté par pays, par manche (une manche est ratée si aucun essai n'est juste).
CREATE TEMP VIEW rounds AS
SELECT sid, rnd, tgt, min(uid) AS uid, bool_or(ok) AS solved, bool_or(skipped) AS skipped,
       bool_and(skipped) AS skipped_only, count(*) AS tries
FROM att GROUP BY sid, rnd, tgt;

\copy (SELECT tgt AS code, count(*) AS rounds, count(DISTINCT uid) AS players, count(*) FILTER (WHERE NOT solved) AS failed_rounds, count(*) FILTER (WHERE skipped_only) AS skipped_without_answer, round(avg(tries), 3) AS avg_attempts FROM rounds GROUP BY tgt HAVING count(DISTINCT uid) >= 3 ORDER BY tgt) TO '__OUT__/country_difficulty.csv' CSV HEADER

-- 2. Paires de confusion : une réponse fausse rattachée à un AUTRE pays du jeu.
--    Le texte tapé est rattaché au pays qu'il désigne le plus souvent dans les bonnes réponses.
CREATE TEMP TABLE alias AS
SELECT nm, code FROM (
  SELECT nm, tgt AS code, row_number() OVER (PARTITION BY nm ORDER BY count(*) DESC) AS rk
  FROM att WHERE ok GROUP BY nm, tgt HAVING count(*) >= 2
) t WHERE rk = 1;

\copy (SELECT a.tgt AS shown_code, al.code AS typed_code, count(*) AS answers, count(DISTINCT (a.sid, a.rnd)) AS rounds, count(DISTINCT a.uid) AS players FROM att a JOIN alias al ON al.nm = a.nm WHERE NOT a.ok AND NOT a.skipped AND al.code <> a.tgt GROUP BY 1, 2 HAVING count(*) >= 5 AND count(DISTINCT a.uid) >= 3 ORDER BY answers DESC) TO '__OUT__/confusion_pairs.csv' CSV HEADER

-- 3. Lieux tapés à la place d'un pays : liste FERMÉE, relue à la main (pas de texte libre publié).
CREATE TEMP TABLE places (place text, pattern text);
INSERT INTO places VALUES
 ('Hawaii', '^hawa+i+( islands?)?$'), ('Tahiti', '^(tahiti|thaiti|taiti)$'), ('Bora Bora', '^bora ?bora$'),
 ('Dubai', '^duba[iy]$'), ('Bali', '^bali$'), ('Tibet', '^tibet$'), ('Kurdistan', '^kurdistan$'),
 ('Sahara', '^sahara$'), ('Easter Island', '^(easter islands?|ile de paques|iles de paques)$'),
 ('Zanzibar', '^zanzibar$'), ('Sicily', '^(sicily|sicile|sicilia)$'), ('Sardinia', '^(sardinia|sardaigne)$'),
 ('Crete', '^crete$'), ('Siberia', '^(siberia|siberie)$'), ('Tasmania', '^(tasmania|tasmanie)$'),
 ('Galapagos', '^galapagos$'), ('Alaska', '^alaska$'), ('Borneo', '^borneo$'),
 ('Caribbean', '^(caraibes?|caribbean|carribean|caribean|antilles)$'),
 ('Africa', '^(africa|afrique|north africa|central africa|west africa|afrique centrale|afrique du nord)$'),
 ('Yugoslavia', '^(yugoslavia|yougoslavie)$'), ('Persia', '^(persia|perse)$'),
 ('Rhodesia', '^(rhodesia|rhodesie)$'), ('USSR', '^(ussr|urss)$'),
 ('Rome', '^(rome|roma)$'), ('Tunis', '^tunisi?$'), ('Algiers', '^(alger|algeri|algiers)$'),
 ('Jerusalem', '^jerusalem$'), ('Abu Dhabi', '^abu dhabi$'), ('Doha', '^doha$'), ('Bern', '^(berne|bern)$');

\copy (SELECT p.place, a.tgt AS shown_code, count(*) AS answers, count(DISTINCT a.uid) AS players FROM att a JOIN places p ON a.nm ~ p.pattern WHERE NOT a.ok AND NOT a.skipped GROUP BY 1, 2 HAVING count(*) >= 3 ORDER BY 1, answers DESC) TO '__OUT__/typed_places.csv' CSV HEADER

\copy (SELECT count(*) AS answers, count(DISTINCT (sid, rnd)) AS rounds, count(DISTINCT uid) AS players, min(at)::date AS first_day, max(at)::date AS last_day FROM att) TO '__OUT__/summary.csv' CSV HEADER

