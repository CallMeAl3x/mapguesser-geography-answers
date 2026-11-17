# MapGuesser geography answers

Aggregated answers from [MapGuesser](https://mapguesser.fr/en), a free geography game where a country lights up on a world map and players **type** its name, with no multiple choice. Because answers are typed from scratch, every mistake records what the player named instead: a neighbour, a famous place nearby, or nothing at all.

**819,720 rounds · 1,441,540 answers · 9,238 players · 30 Jan 2026 to 17 Nov 2026**

Also on Kaggle: [What People Type When They Can't Name a Country](https://www.kaggle.com/datasets/alexandrebonefons/what-people-type-when-they-cant-name-a-country)

Write-ups based on this data:

- [The countries nobody can place on a map](https://mapguesser.fr/en/blogs/hardest-countries-to-place-on-a-map): failure rates, confusion pairs, why small islands are the hardest.
- [Hawaii, Dubai, Bali: what people type when they can't name the country](https://mapguesser.fr/en/blogs/hawaii-dubai-bali-what-people-type-when-they-cant-name-the-country): places, capitals and sound-alikes typed instead of a country.

## Files

| File | One row per | Rows |
|---|---|---|
| [`data/country_difficulty.csv`](data/country_difficulty.csv) | country or territory shown on the map | 254 |
| [`data/confusion_pairs.csv`](data/confusion_pairs.csv) | (country shown, other country typed) | 7,586 |
| [`data/typed_places.csv`](data/typed_places.csv) | (non-country place typed, country shown) | 406 |
| [`data/countries.csv`](data/countries.csv) | country or territory in the game | 254 |
| [`data/summary.json`](data/summary.json) | totals and date range | 1 |

### `country_difficulty.csv`

| Column | Meaning |
|---|---|
| `code`, `name_en` | ISO 3166-1 alpha-3 code (a few game-specific codes for sub-national entities, e.g. `ENG`), English name |
| `rounds` | rounds where this country was shown |
| `players` | distinct players who got it |
| `failed_rounds`, `fail_rate_pct` | rounds never answered correctly (all attempts wrong, or skipped) |
| `skipped_without_answer`, `skip_rate_pct` | rounds skipped without typing anything |
| `avg_attempts` | average attempts per round (a round allows several) |

### `confusion_pairs.csv`

A wrong answer is matched to a country when the typed text is a name the game accepts for that country (all languages and common spellings, learned from correct answers).

| Column | Meaning |
|---|---|
| `shown_code`, `shown_name` | country highlighted on the map |
| `typed_code`, `typed_name` | other country the player typed |
| `answers` | wrong answers (a player can make several in one round) |
| `rounds` | distinct rounds with at least one such answer |
| `players` | distinct players |
| `pct_of_shown_rounds` | `rounds` divided by all rounds of the shown country |

### `typed_places.csv`

Answers that name **no country at all**: islands, cities, regions, capitals, former countries. This is a **closed, hand-reviewed list** of 31 places (see [`scripts/extract.sql`](scripts/extract.sql)); free-text answers are never published. Spelling variants are merged (`hawaii`, `hawai`, `hawaaii`; `sicily`, `sicile`, `sicilia`).

| Column | Meaning |
|---|---|
| `typed_place` | the place typed, normalised to its English name |
| `shown_code`, `shown_name` | country highlighted on the map |
| `answers`, `players` | wrong answers and distinct players |

## Method and caveats

- **Mode**: only the map mode (country highlighted, type its name) is recorded. Flag and capital quizzes are not included.
- **Bots excluded**: the game's practice bots are removed. Every published row involves at least 3 distinct players; pairs need at least 5 answers, places at least 3.
- **Typed, not chosen**: this measures recall, not recognition. A multiple-choice quiz would give much better scores.
- **Small countries are tiny on screen**: part of the failure on micro-states may be about visibility, not knowledge.
- **Not a population sample**: these are people who chose to play a geography game. Among players whose country is known: France 26%, United States 13%, Brazil 8%, United Kingdom 5%, Germany 4%. The game exists in English, French, Portuguese, Italian and German.
- **Excluded pair**: `COD` → `COG` (DR Congo answered as "Congo") is a naming ambiguity, not a geography mistake.
- About a third of wrong answers match no country (typos, abandoned input); they are left out except for the closed list above.

## Licence and citation

Data under [Creative Commons Attribution 4.0](LICENSE) (CC BY 4.0): free to use, share and adapt, including commercially, **as long as you credit MapGuesser with a link**:

> Data: MapGuesser geography answers, https://mapguesser.fr/en

Citation metadata is in [`CITATION.cff`](CITATION.cff) (GitHub shows a "Cite this repository" button).

## Updating

```bash
# 1. Read-only extraction from the game database (only temporary objects are created)
sed "s|__OUT__|$PWD/data/raw|g" scripts/extract.sql | psql "$DATABASE_URL"
# 2. Build the published CSV files (needs the MapGuesser source for country names)
MAPGUESSER_ROOT=../MapGuesser bun scripts/build.ts
```

Questions or corrections: contact@mapguesser.fr
