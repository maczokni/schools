# Choosing a school in Greater Manchester

Exploratory R analysis to help choose a primary school (and, later, a
secondary) in Greater Manchester. It combines Department for Education (DfE)
performance tables, suspension data, Manchester City Council admissions
("catchment") data and school locations to answer three questions:

1. **Which schools get the best results?** KS2 (age 11) and KS4 (GCSE) results,
   nationally and across the ten GM boroughs.
2. **Which good schools are in reach?** How far each Manchester primary's
   offers went in the latest admissions round, compared with the distance from
   home.
3. **What else matters?** Suspension rates and proximity to a Metrolink stop.

The end product is a shortlist map of Manchester primaries we could
realistically get into, coloured by a composite score
(`outputs/maps/schools_to_look_at.html`).

---

## Project layout

```
schools/
├── schools.Rproj           open this first, so paths resolve from the project root
├── R/                      analysis scripts (run in RStudio, section by section)
├── data/                   raw downloads + one derived file (see below)
├── outputs/maps/           interactive leaflet maps (HTML)
└── _archive/               original scripts and superseded files (safe to delete)
```

## Scripts

| Script | What it does | Main output |
|---|---|---|
| `00_helpers.R` | Shared packages, constants (GM boroughs, school-type codes), and helpers for percentages, postcode geocoding and saving maps. Every other script `source()`s it. | – |
| `01_scrape_admissions_2026.R` | Parses the council's "demand for primary school places" pages (Reception, Sept 2026) into places, offers, unfilled places and the furthest distance offered. The HTML is pasted in by hand because the site blocks scripted requests. | `data/manchester_primary_school_places.csv` |
| `02_explore_ks2_ks4_2023.R` | First pass with 2022/23 tables: top GM secondaries (Attainment 8, grade 5+ English & maths, including grammar and independent schools), top GM primaries by KS2 maths, and a Walthamstow comparison. | `maths_90th_centile_schools_excluding_private.html` |
| `03_where_to_live_2023.R` | Where are the strong non-faith primaries? England-wide map; GM top 10% overlaid with 1 km Metrolink buffers; look-ups for Altrincham, Sale and Stretford. | `all_elementary_high_achievers.html`, `overlap_elementary_transport*.html` |
| `04_suspensions_2025.R` | Distribution of school suspension rates in 2024/25, with schools of interest marked; North West and England averages. | plots only |
| `05_shortlist_2025.R` | **Main analysis.** Joins KS2 2024/25 results, suspensions, admissions distances and school locations for Manchester primaries; works out which are "in catchment"; scores and maps them. Also maps England's top 20% secondaries on Attainment 8. | `schools_to_look_at.html`, `secondary_top20pc_attainment8.html` |

Run `01` before `05`. Every other script stands alone. The scripts are
exploratory and include `View()` calls, so step through them in RStudio
rather than running them in batch.

### How the shortlist score works (`05`)

For each Manchester primary:

- **Distance cut-off**: the last distance offered, taken from the council text
  ("…to a distance of 0.449 miles"). It is 0 when every applicant got a place,
  and NA when places were allocated by the school's own (usually faith)
  criteria.
- **In catchment** means the school had unfilled places, or home is within the
  distance cut-off.
- **Composite score** = z(% expected standard) + z(% higher standard)
  − z(% pupils with 1+ suspension) − 10 × z(distance from home). Distance is
  deliberately weighted heavily (`DIST_WEIGHT`).
- The map shows schools that are in catchment and within 10 miles.

The home location is set by `HOME_LON` / `HOME_LAT` at the top of the script.

## Data

All files are in `data/`. Unless noted, they come from DfE and are published under
the Open Government Licence.

| File | What it is | Used for | Used by |
|---|---|---|---|
| `ks2_school_attainment_data.csv` | KS2 school-level attainment, **2024/25** (Explore Education Statistics). Long format, with rows for each breakdown and subject. | % of pupils at the expected and higher standard in reading, writing & maths | 05 |
| `202425_performance_tables_schools_revised.csv` | KS4 school performance tables, **2024/25** (revised) | Attainment 8 average for secondaries | 05 |
| `suspensions-and-permanent-exclusions-in-england_2024-25/` | School-level suspensions and permanent exclusions, 2024/25 ([source](https://explore-education-statistics.service.gov.uk/data-catalogue/data-set/a4b5a46f-5bed-42b5-91b8-93620a04001e)), with its data guidance | Suspension rate and % of pupils suspended | 04, 05 |
| `edubasealldata20260126.csv` | Get Information About Schools (GIAS) extract of all establishments, 26 Jan 2026 | School easting/northing by URN | 05 |
| `manchester_primary_school_places.csv` | **Derived** from the Manchester City Council admissions pages for Reception 2026 | Places, unfilled places and distance cut-off | 05 (made by 01) |
| `2022-2023/england_ks2final.csv` | KS2 performance tables, **2022/23** (wide format) | KS2 maths/reading scores, % higher standard, faith designation, postcode | 02, 03 |
| `2022-2023/england_ks4final.csv` | KS4 performance tables, **2022/23** | Attainment 8, % grade 5+ in English & maths, school type, gender | 02, 03 |
| `EnglishLaNameCodes.csv` | Local authority code → name lookup | Filtering to the GM boroughs | 02, 03 |
| `TfGMMetroRailStops.csv` | Transport for Greater Manchester Metrolink stop locations | 1 km tram-stop buffers | 03 |
| `data_dictionaries/` | DfE metadata for the 2022/23 tables (`ks2_meta.csv`, `ks4_meta.xlsx`, `ks4_abbreviations.xlsx`, LA/region codes) | Decoding column names and codes | reference |
| `2022-2023/` (other files) | 2022/23 KS4 destinations, KS5 results and destinations, school census, school information | Not currently used | – |
| `results.csv` | Earlier GIAS search export with easting/northing | Superseded by the full GIAS extract | – |

## Outputs

These are interactive maps in `outputs/maps/`. Open them in a browser.

| File | Shows | Script |
|---|---|---|
| `schools_to_look_at.html` | **Shortlist**: Manchester primaries in catchment, coloured by composite score, with results, suspensions and distance in the pop-ups | 05 |
| `secondary_top20pc_attainment8.html` | Top 20% of secondaries in England by Attainment 8, 2024/25 | 05 |
| `maths_90th_centile_schools_excluding_private.html` | GM state primaries in the top 10% for KS2 maths, 2022/23 | 02 |
| `all_elementary_high_achievers.html` | Non-faith primaries in England with more than 11% of pupils at the KS2 higher standard, 2022/23 | 03 |
| `overlap_elementary_transport.html` / `_w_points.html` | Areas within 1 km of both a top-10% GM non-faith primary and a Metrolink stop. The `_w_points` version adds the schools and stops. | 03 |

## Requirements

R (≥ 4.1) with: `dplyr`, `stringr`, `purrr`, `janitor`, `ggplot2`, `scales`,
`sf`, `leaflet`, `htmlwidgets`, `rjson`, `rvest`.

```r
install.packages(c("dplyr", "stringr", "purrr", "janitor", "ggplot2", "scales",
                   "sf", "leaflet", "htmlwidgets", "rjson", "rvest"))
```

Geocoding in `02` and `03` calls the free `api.getthedata.com` postcode API
once per school. The England-wide map makes about 1,000 calls and takes a few
minutes.

## Caveats

- KS2 tables cover state-funded schools only. Independent primaries don't
  appear.
- The 2022/23 tables (scripts 02–03) and 2024/25 tables (script 05) have
  different layouts and column names, so they can't be swapped directly.
- Distance to school is straight-line distance from home. For borderline
  cases, check how the council measures distance.
- Admissions cut-offs change every year. Treat them as a guide only.

## AI use declaration

I wrote the original analysis myself: the questions, the choice of data, the
hand-copied admissions pages and the first versions of all the scripts. I
then used Claude, an AI assistant made by Anthropic (model
`claude-opus-5-5`), to tidy the repository before publishing it. Claude:

- **Tidied the code.** It added header and section comments to every script,
  moved the scripts into `R/` with numbered names, and pulled code that was
  repeated across scripts into `R/00_helpers.R`. This included the geocoding
  functions, the list of GM boroughs and the school-type codes.
- **Wrote this README.** It inferred the purpose of each script, data file and
  output from the code.
- **Fixed bugs.** The fixes:
  - The admissions scraper skipped five schools on the council's R–S page,
    which uses different wording.
  - School names in the admissions data were matched against all of England
    instead of Manchester only. This gave duplicate and wrong matches and left
    48 schools unmatched.
  - School locations now come from the full GIAS extract, which also replaced
    an inaccurate hand-entered location.
  - The secondary-school map was reading the wrong data file.
  - `03_where_to_live_2023.R` stopped with an error partway through.
- **Anonymised my home address.** It removed my home coordinates and a side
  analysis that could identify where I live from the code and the git
  history. It also kept the shortlist map, whose distances could reveal my
  location, out of the repository.
- **Set up the repository.** It wrote the `.gitignore` and removed the RStudio
  files and the large raw data files from the first commit.

Claude ran every script against the data to check that the changed code worked
and that the maps matched the originals. The analytical decisions, including
the weights in the composite score, are mine. I remain responsible for the
analysis and its conclusions.
