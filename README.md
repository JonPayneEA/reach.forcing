# reach.forcing

**Model forcing from checked rain gauge, radar and gridded data.**

reach.forcing turns checked hydrometric and meteorological data into the series a
rainfall-runoff model is driven by, and says how far to trust them. It sits between the
packages that fetch and check data and the models that use it:

| Package | Job |
|---|---|
| `reach.io` | Fetches data (EA Hydrology API, WISKI, CEDA, Copernicus) and keeps the Bronze store |
| `reach.validate` | Checks every series: the rule book, its test cases, QC flags |
| **`reach.forcing`** | Weighting, catchment rain, source comparisons, event uncertainty, ensembles, exports |
| `reach.hydro`, pdmS7 | The models |

reach.forcing fetches nothing itself: every download goes through `reach.io`.

## What it does now

| Function | What it does |
|---|---|
| `operational_rain()` | Rebuilds catchment rain exactly as the operational system makes it: fixed Thiessen weights scaled up over the gauges that report, H19 at a standing weight of 0.01, and H19 alone below 4 °C |
| `gauge_weights()` | Thiessen weights of gauges over a catchment boundary; with `reporting`, the polygons redrawn over a subset (the challenger to scaling up) |
| `longterm_ratios()` | A gauge's long-term rain against SAAR moved to its own years with HadUK-Grid: the climate factor *c*, method ratio *m* and bias index *b* |

```r
library(reach.forcing)

rain <- cbind(A = c(1, 2, NA, NA), B = c(3, NA, 2, NA))
operational_rain(rain, weights = c(A = 0.6, B = 0.4), h19 = c(2, 2, 2, 5),
                 temperature = c(10, 10, 10, 2))
```

## What comes next

Source comparisons, model-free event uncertainty and calibration weights, the challenger
weightings, the rain error model and ensembles, and the export bundle for pdmS7. The design is
in the plan *Rainfall inputs and uncertainty: an end-to-end plan*.

## Installation

```r
# install.packages("remotes")
remotes::install_github("JonPayneEA/reach.forcing")
```

## Licence

MIT. Code, tests and examples use open or synthetic data only; restricted sources (H19, FEH
SAAR, MOSES) are never committed.
