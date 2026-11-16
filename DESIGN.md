# reach.forcing design

The parts of the rainfall inputs plan that govern this package. The full plan, with processes,
data build and the explorer specification, is kept with the Flood Forecast Modelling team.

## Scope

| Package | Job |
|---|---|
| `reach.io` | Fetching and the Bronze store; reading Silver |
| `reach.validate` | Quality control of every series: the rule book, its test cases, flags |
| **`reach.forcing`** | Everything downstream of checked data that a model needs |
| `reach.hydro`, pdmS7 | The models |

reach.forcing fetches nothing and sets no QC flags. It reads checked series and their flags.

## Principles

1. **The calibration of record uses the operational scheme exactly**: fixed Thiessen weights
   scaled up when gauges fail, H19 at a standing weight, H19 alone below 4 °C
   (`operational_rain()`). Better methods run beside it as challengers, never in its place.
2. **Challengers are compared on equal terms**: each gets its own calibration with the same
   structure, bounds, budget and seeds, scored on the same events, with gauge outages replayed.
   Gains are reported in two groups: those that fit today's system, and those that need it
   changed.
3. **Event uncertainty comes before calibration**, measured without a model: impossible events
   are excluded, the rest weighted by how far the rain sources agree. Model-based attribution
   (rain or model) comes only after calibration.
4. **Every number traces to its inputs**: outputs carry the input release, rule versions and
   source table versions.
5. **Licences travel with the data**: open, internal or restricted on every row; restricted
   data never reaches a published output, and never enters this repository.

## Tables it writes

| Table | One row per | Holds |
|---|---|---|
| `catchment_rain` | catchment, source, member, step | Rain by source (operational, H19, HadUK, ERA5, challengers); member 0 the best estimate |
| `catchment_checks` | catchment, check, period | Every source comparison, with its value, threshold and flag |
| `events` | station, event | Model-free event uncertainty and the calibration weight |

## Order of work

| Step | Functions | Status |
|---|---|---|
| 1 | `operational_rain()`, `gauge_weights()`, `longterm_ratios()` | Done |
| 2 | Source comparisons: `ratio_checks()`, `daily_agreement()`, `timing_offset()`, `temperature_bands()`; catchment totals by source still to come | Mostly done |
| 3 | Event uncertainty: source spread, ensemble rain range, runoff ratio range, seasonal envelope, timing; calibration weights and exclusions | |
| 4 | Challenger weightings: SAAR-scaled, cross-validated, redrawn on failure; `compare_weightings()` | |
| 5 | Rain error model and ensembles | |
| 6 | The export bundle for pdmS7, with provenance | |

## Statistical rules for comparisons

Ratios in logs, reported as factors; medians and median absolute deviations; values flagged
as rejected left out; minimum samples before any flag; dependence between sources recorded
(HadUK-Grid is built from gauges, H19 may be adjusted to them); a bootstrap interval on every
measure, with a flag only when the whole interval passes the threshold; thresholds as
versioned starting values, tuned by back-testing.
