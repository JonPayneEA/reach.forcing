# reach.forcing — Claude Code Guide

## Project overview

**reach.forcing** turns checked data into model forcing for the EA Flood Forecast Modelling
team: catchment rain built the operational way, gauge weights, source comparisons, event
uncertainty, ensembles and exports for pdmS7.

**Scope.** Downstream of fetching and checking only.

- Fetching belongs to `reach.io`. reach.forcing never calls an API or reads a remote store.
- Quality control belongs to `reach.validate`. reach.forcing reads QC flags; it never sets them.
- Models belong to `reach.hydro` and pdmS7.

## Conventions

- R (>= 4.1). Core functions take plain vectors, matrices and data frames, so they do not
  depend on any other package's classes; adapters to `reach.io` S7 objects come separately.
- Imports kept to base R and `stats` unless a dependency clearly earns its place.
- Times in UTC at the step start; depths in mm per step; coordinates in metres on British
  National Grid.
- Every R file starts with the Flode header block (Tool, Description, Flode Module, Author,
  Created, Tier, Inputs, Outputs, Dependencies).
- `.check()` for argument checks: a plain message, no call.

## Testing

```r
devtools::test()
```

testthat edition 3. Every expected value in a test comes from a closed form or a hand
calculation stated in the test, never from running the code and pasting its output. Every bug
fix gets a regression test that fails on the old code.

## Data

Tests, examples and vignettes use open or synthetic data only. Restricted sources (H19, FEH
SAAR, MOSES) are never committed, not even as small samples.

## Documentation

```r
devtools::document()
```

UK English, plain prose: no em dashes, no exclamation marks.
