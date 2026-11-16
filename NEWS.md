# reach.forcing 0.0.0.9000

- First functions: `operational_rain()` rebuilds catchment rain the operational way
  (fixed Thiessen weights scaled up over the gauges that report, H19 at a standing weight,
  H19 alone below a temperature threshold); `gauge_weights()` gives Thiessen weights over a
  catchment, or redrawn over a subset of gauges; `longterm_ratios()` measures a gauge against
  SAAR moved to its own years with HadUK-Grid.
