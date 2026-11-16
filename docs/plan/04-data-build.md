# Data build

Everything the explorer and the processes need, in the order to build it: internal extracts and open downloads first, then the tables generated from them. Each step lands in Databricks under one catalog, raw data in `bronze`, cleaned in `silver`, products in `gold`, each row tagged with its licence. Volumes are rough; confirm them on the pilot. Every download from outside (the EA API, CEDA, Copernicus, NRFA) goes through `reach.io`; `reach.forcing` reads what it fetched.

## Stage 0: the workspace

Set up the catalog, the conventions and the pilot area before any data arrives, so nothing has to be moved later.

1. **One catalog, three layers.** A catalog for the inputs product (name to agree), with `bronze` for data as received, `silver` for checked and converted data, `gold` for the contract tables and explorer outputs.
2. **Conventions.** Times in UTC at the step start; depths in mm per step; flows in m³/s; British National Grid coordinates; station identifiers as the source system gives them, with an NRFA number column where one exists.
3. **Every table carries** `source`, `source_version`, `licence` (`open`, `internal`, `restricted`), `loaded_at` and, for derived tables, the rule or code version that made it.
4. **Access.** Restricted sources (H19, FEH SAAR, MOSES) in their own schema with access limited to the people their licences cover; the service account that runs the jobs registered against those licences.
5. **Choose the pilot.** One region holding Beggearn Huish and three to five critical catchments of different kinds (upland, lowland, chalk, urban, snow-prone). Every stage runs on the pilot first.

**Done when** the schemas exist, the conventions are written in the catalog's README, and the pilot catchments are named.

### Example: Stage 0 in Unity Catalog

All names are placeholders to agree with the platform team; check tag syntax against the workspace's runtime.

**Catalog, layers and a metadata schema**

```sql
CREATE CATALOG IF NOT EXISTS hydro_inputs
  COMMENT 'Rainfall inputs and uncertainty product. Conventions: see meta.conventions';

CREATE SCHEMA IF NOT EXISTS hydro_inputs.bronze            COMMENT 'Data as received, open and internal';
CREATE SCHEMA IF NOT EXISTS hydro_inputs.bronze_restricted COMMENT 'Data as received under restricted licence: H19, FEH, MOSES';
CREATE SCHEMA IF NOT EXISTS hydro_inputs.silver            COMMENT 'Checked and converted';
CREATE SCHEMA IF NOT EXISTS hydro_inputs.gold              COMMENT 'Contract tables and explorer outputs';
CREATE SCHEMA IF NOT EXISTS hydro_inputs.meta              COMMENT 'Conventions, releases, pilot, licences';

ALTER SCHEMA hydro_inputs.bronze_restricted SET TAGS ('licence' = 'restricted');
```

**Who can see what**

```sql
-- Groups named to the governance roles; the jobs run as one service principal
GRANT USE CATALOG ON CATALOG hydro_inputs TO `inputs-readers`;
GRANT SELECT ON SCHEMA hydro_inputs.gold TO `inputs-readers`;
GRANT ALL PRIVILEGES ON SCHEMA hydro_inputs.silver TO `inputs-custodians`;
GRANT ALL PRIVILEGES ON SCHEMA hydro_inputs.bronze TO `inputs-custodians`;

-- Restricted data: only people and the job the licences cover
GRANT SELECT ON SCHEMA hydro_inputs.bronze_restricted TO `licensed-h19-feh`;
GRANT SELECT ON SCHEMA hydro_inputs.bronze_restricted TO `sp-inputs-jobs`;
```

**One table built to the conventions** (the gauge series, laid out as Stage 2 recommends)

```sql
CREATE TABLE IF NOT EXISTS hydro_inputs.silver.rain_15min (
  gauge_key       INT       NOT NULL COMMENT 'Key into meta.rain_gauges',
  time            TIMESTAMP NOT NULL COMMENT 'UTC, start of the 15-minute step',
  rain_mm         FLOAT              COMMENT 'Depth in the step, mm; NULL = missing, 0 = dry',
  quality_code    STRING             COMMENT 'Source quality code, never stripped',
  source          STRING    NOT NULL COMMENT 'e.g. wiski, ea_hde_api',
  source_version  STRING             COMMENT 'Extract or file version',
  licence         STRING    NOT NULL COMMENT 'open | internal | restricted',
  loaded_at       TIMESTAMP NOT NULL
)
CLUSTER BY (gauge_key, time)
TBLPROPERTIES (delta.enableChangeDataFeed = true)
COMMENT 'Rain gauges, regular 15-minute grid, UTC';

ALTER TABLE hydro_inputs.silver.rain_15min SET TAGS ('licence' = 'internal', 'stage' = '2.2');
```

Generated tables add `rule_version` and `code_version` columns, so every row traces to the rule and code that made it.

**The export guard**: published outputs read only through a view that drops restricted rows.

```sql
CREATE OR REPLACE VIEW hydro_inputs.gold.catchment_rain_publishable AS
SELECT * FROM hydro_inputs.gold.catchment_rain
WHERE licence <> 'restricted';
```

**Conventions, releases and the pilot as tables**, so jobs and the explorer read them.

```sql
CREATE TABLE IF NOT EXISTS hydro_inputs.meta.conventions (item STRING, rule STRING);
INSERT INTO hydro_inputs.meta.conventions VALUES
  ('time',    'UTC, start of step'),
  ('depth',   'mm per step'),
  ('flow',    'm3/s'),
  ('coords',  'British National Grid, EPSG:27700'),
  ('ids',     'Source identifiers kept; NRFA number in its own column'),
  ('licence', 'open | internal | restricted, on every row and as a table tag');

CREATE TABLE IF NOT EXISTS hydro_inputs.meta.releases (
  release STRING, rule_book_version STRING, rain_15min_version BIGINT,
  signed_by STRING, signed_at TIMESTAMP, notes STRING);

CREATE TABLE IF NOT EXISTS hydro_inputs.meta.pilot_catchments (
  station_id STRING, nrfa_number STRING, name STRING, kind STRING, why STRING);
INSERT INTO hydro_inputs.meta.pilot_catchments VALUES
  ('[id]', '[nrfa]', 'Beggearn Huish', 'upland, 36.7 km2', 'Known 10% water shortfall; event 82'),
  ('[id]', '[nrfa]', '[name]', 'lowland',    '[reason]'),
  ('[id]', '[nrfa]', '[name]', 'chalk',      '[reason]'),
  ('[id]', '[nrfa]', '[name]', 'urban',      '[reason]'),
  ('[id]', '[nrfa]', '[name]', 'snow-prone', '[reason]');
```

The README in the `reach.forcing` repository says the same in prose: layers, conventions, the licence rule, who to ask for access, and the pilot list.

## Stage 1: station metadata

The registers come first: every later table hangs off a station or gauge identifier, and the operational configuration decides what the calibration must reproduce.

| Step | Dataset | From | Licence | Lands as |
| --- | --- | --- | --- | --- |
| 1.1 | Flow and level stations: identifier, NRFA number, location, datum, type (flow or level-only), period of record | Hydrometric archive (WISKI) extract | Internal | `bronze.stations` |
| 1.2 | Ratings: every rating with its validity period, equation or table, and limits | Hydrometric archive | Internal | `bronze.ratings` |
| 1.3 | Gaugings: every spot measurement, with date, stage, flow and quality | Hydrometric archive | Internal | `bronze.gaugings` |
| 1.4 | Rain gauges: identifier, location, height, type (tipping bucket or storage), bucket size, heated or not, and every move, instrument change or maintenance visit with its date | Hydrometric archive; field team records for history | Internal | `bronze.rain_gauges` |
| 1.5 | Check-gauge pairs: which storage gauge sits beside which tipping bucket | Field team | Internal | `bronze.check_gauge_pairs` |
| 1.6 | **Operational configuration**, per forecast catchment: its rain gauges and their Thiessen weights, the H19 weight, the temperature series and threshold for the switch, PACK and PDM parameters, the catchment area used | Forecasting system configuration | Internal | `bronze.operational_config`, versioned by date |

- Step 1.6 is the one most easily missed and most important: without it the calibration cannot reproduce operations. Take its history too, so a hindcast uses the configuration in force at the time.
- From 1.2 and 1.3 the highest gauged flow per station follows directly; it feeds the extrapolation checks.

**Done when** every pilot station and gauge appears once in each register, with its history.

## Stage 2: time series

The 15-minute records come next, with their quality codes, because every check and every model run reads them.

| Step | Dataset | From | Licence | Lands as |
| --- | --- | --- | --- | --- |
| 2.1 | Flow and level, 15-minute, whole record, with quality codes | Hydrometric archive | Internal | `bronze.flow_15min`, partitioned by station and year |
| 2.2 | Rain gauges, 15-minute, whole record, with quality codes | Hydrometric archive; the EA Hydrology Data Explorer API for anything missing | Internal, or open (OGL) from the API | `bronze.rain_15min_raw`, then `silver.rain_15min` |
| 2.3 | Check-gauge monthly totals | Hydrometric archive or field records | Internal | `bronze.check_gauge_monthly` |
| 2.4 | H19, 15-minute grids, whole period available | Internal store | Restricted | `bronze_restricted.h19`, kept as compressed grids partitioned by day |
| 2.5 | Temperature: the series the switch and PACK use, as named in 1.6 | Its source system | As that source | `bronze.temperature` |
| 2.6 | PET: MOSES, as used now; CHESS-PE as the open check | Met Office (MOSES); UKCEH EIDC (CHESS-PE) | Restricted; open | `bronze_restricted.moses_pe`, `bronze.chess_pe` |
| 2.7 | Real-time logs, where they exist: the inputs forecasters actually used, with substitutions | Forecasting system | Internal | `bronze.operational_inputs` |

- **H19 is the large one.** At 1 km over England and 15 minutes it is of the order of 20 GB a year uncompressed; store the grids compressed, and keep only catchment averages (Stage 5) in the hot tables.
- **Quality codes come with the values,** never stripped: process 2 reads them.
- **2.7 matters for hindcasts:** without it, a hindcast can only approximate what forecasters had.

**Done when** the pilot's series are loaded end to end, with counts of steps, gaps and quality codes per station checked against the source.

### Storing the gauge series

About 900 gauges with 20 years of 15-minute data is roughly 630 million gauge-steps (900 × 20 × 35,064): one long Delta table, not a file per gauge, and a few GB once compressed, since most steps are dry.

| Layer | Table | Layout | Why |
| --- | --- | --- | --- |
| Raw | `bronze.rain_15min_raw` | As received: source timestamps and time zone, value, quality code, file name | The record of what arrived; never edited |
| Regular | `silver.rain_15min` | One row per gauge and 15-minute step on a complete UTC grid; `NULL` for missing, `0` for dry | Every check and every catchment average reads this |
| Checked | `silver.gauge_series_qc` | Raw value, corrected value, flags, rule version, per gauge and step | Corrections sit beside the data, never over it |
| Aggregates | `silver.rain_hourly`, `silver.rain_daily_0900` | Hourly totals on whole UTC hours; daily totals on the 09:00 rain day, with the count of valid steps | The GSDR checks and the HadUK comparisons read these; about 160 million and 6.6 million rows |

- **Long, not wide.** One row per gauge and step appends, merges late data and filters by gauge cheaply; a column per gauge breaks every time a gauge is added.
- **Dense, not sparse.** Keep the dry steps. Dropping zeros saves little after compression and loses the difference between dry and missing, which the checks depend on.
- **Compact types.** An integer `gauge_key` into the gauge register, `FLOAT` depths (tips are 0.2 mm), a short quality code. Constant columns such as `source` and `licence` compress to almost nothing.
- **Cluster by gauge and time.** Liquid clustering on (`gauge_key`, `time`) serves both the explorer (a few gauges, the whole record) and the national checks (every gauge, one period). No partition per gauge: 900 small partitions slow everything down.
- **Revisions by merge.** New and revised data arrive by `MERGE` on (`gauge_key`, `time`); the change data feed records what changed and when.
- **Releases pinned to versions.** Each release records the Delta version of `silver.rain_15min` it was built from (`meta.releases`), so a calibration can be rerun on exactly the same data; keep the table's history at least as long as a release is in use.

## Stage 3: gridded references

The grids that test the gauges: HadUK-Grid is already in Databricks, SAAR is held internally, and ERA5-Land is the one download from outside.

| Step | Dataset | From | Licence | Lands as |
| --- | --- | --- | --- | --- |
| 3.1 | HadUK-Grid rainfall, 1 km, daily and monthly, 1961 to date | Already in Databricks; CEDA for any gap | Open (OGL) | `bronze.haduk_rain_daily`, `bronze.haduk_rain_monthly` |
| 3.2 | HadUK-Grid daily mean, minimum and maximum temperature, 1 km | As 3.1 | Open (OGL) | `bronze.haduk_temp_daily`, for the temperature analysis where no station series exists |
| 3.3 | FEH SAAR grid, 1961 to 1990, 1 km | Internal FEH holdings | Restricted | `bronze_restricted.feh_saar` |
| 3.4 | ERA5-Land, hourly precipitation, 2 m temperature and snow depth, over England | Copernicus Climate Data Store | Open with attribution | `bronze.era5land_hourly` |
| 3.5 | Optional: CEH-GEAR hourly, 1 km | UKCEH EIDC | Open | `bronze.ceh_gear_hourly`, only if a second gauge-based grid is wanted |

- HadUK-Grid long-term means for 1961 to 1990 and for each record period are computed from 3.1 in Stage 5, not downloaded.
- ERA5-Land is coarse (about 9 km); it serves as the broadly independent check, never as forcing.

**Done when** each grid covers the pilot area for its full period, and a spot check of a few cells matches the provider's published values.

## Stage 4: spatial layers

The layers that turn a clicked gauge into a catchment and fill its card; the terrain is already in Databricks, the rest are open downloads.

| Step | Dataset | From | Licence | Lands as |
| --- | --- | --- | --- | --- |
| 4.1 | EA LIDAR Composite DTM, 2 m | Already in Databricks | Open (OGL) | in place |
| 4.2 | OS Terrain 50, for gaps | OS Data Hub | Open (OGL) | `bronze.os_terrain50` |
| 4.3 | River network: OS Open Rivers, or the EA Detailed River Network | OS Data Hub; EA | Open; check DRN terms | `bronze.rivers` |
| 4.4 | NRFA catchment boundaries for gauged stations | NRFA | Open; confirm terms | `bronze.nrfa_boundaries` |
| 4.5 | NRFA catchment descriptors, where published | NRFA | Open; confirm terms | `bronze.nrfa_descriptors` |
| 4.6 | BGS geology, 1:625,000, bedrock and superficial | BGS | Open (OGL) | `bronze.bgs_geology` |
| 4.7 | Land cover: CORINE; UKCEH Land Cover Map if licensed | Copernicus; UKCEH | Open; licensed | `bronze.land_cover` |

- The internal terrain model (direction 3 in `future-directions.md`) is built from 4.1 to 4.3; its boundaries arrive in Stage 5 beside NRFA's.

**Done when** the pilot's catchments have an NRFA boundary (where one exists) and every layer covers them.

## Stage 5: generated tables

Nothing here is downloaded: each table is computed from the stages above, in this order, because each needs the ones before it.

| Step | Table | Built from | What it holds |
| --- | --- | --- | --- |
| 5.1 | `silver.catchments` | 1.1, 4.4, later the terrain model | One boundary per station and source, its area, and the difference from the area operations use (1.6) |
| 5.2 | `silver.grid_weights` | 5.1, the H19, HadUK, SAAR and ERA5 grids | The share of each grid cell inside each catchment, per grid |
| 5.3 | `silver.gauge_series_qc` | 2.2, 1.4, 2.4, the rule book | QC flags and corrected series (process 2), hourly checks plus the 15-minute layer |
| 5.4 | `gold.catchment_rain`, source `operational` | 5.3, 1.6, 2.4, 2.5 | The operational rain rebuilt exactly: fixed Thiessen weights scaled up on failure, H19 at 0.01, H19 alone below 4 °C |
| 5.5 | `gold.catchment_rain`, other sources | 5.2, 5.3, the grids | H19, HadUK daily and ERA5 catchment averages; later the challengers |
| 5.6 | `gold.catchment_rain_check` | 5.4, 2.7 | The rebuilt operational rain against the logged real-time inputs, where they exist; differences explained before going on |
| 5.7 | `silver.longterm_stats` | 3.1, 3.3, 5.3, 5.5 | The climate factor *c*, method ratio *m* and bias index *b* per gauge and catchment |
| 5.8 | `silver.events` | 2.1, 5.4, 5.5 | Events from `find_events()` per station, with the model-free uncertainty measures and the calibration weight |
| 5.9 | `gold.catchment_checks` | 5.7, 5.8, the source comparisons | Every comparison in [Source comparisons](03-source-comparisons.md), with its flag |
| 5.10 | `gold.explorer_card` | 5.1, 4.5 to 4.7, 2.1, 1.2, 1.3 | One row per station: everything the catchment card shows |

- **5.6 is the gate** for everything after it: if the rebuilt operational rain does not match what operations used, the calibration of record is not faithful to operations.
- The error model and the ensembles (phase 2) come after this list, from the cross-validation errors in 5.5.

**Done when** every table exists for the pilot, and 5.6 agrees with the operational logs or every difference is explained.

## Order of work

Run every stage on the pilot before any goes national: the pilot finds the format problems, the missing histories and the volumes while they are cheap to fix.

1. **Pilot, Stages 0 to 4.** Extracts and downloads for the pilot region only.
2. **Pilot, Stage 5 to step 5.6.** Rebuild the operational rain and match it to the logs. Stop here until it matches.
3. **Pilot, the rest of Stage 5.** Then the explorer's first screens can run on real data.
4. **National, Stages 1 to 4.** The registers and grids for every station, in bulk.
5. **National, Stage 5,** region by region, each region checked like the pilot.

**Requests to make now**, since each takes time to answer:

- [ ] Hydrometry: bulk extracts of stations, ratings, gaugings, rain gauges and 15-minute series, with quality codes, for the pilot region
- [ ] Field teams: gauge histories (moves, instrument changes, heating) and check-gauge pairs
- [ ] Forecasting systems: the operational configuration per catchment, with its history, and any logs of real-time inputs and substitutions
- [ ] Licensing: whether the H19, FEH and MOSES terms cover a service account running national jobs
- [ ] Databricks platform: the catalog, a restricted schema, and a cluster sized for H19
- [ ] Copernicus: a Climate Data Store account for ERA5-Land
