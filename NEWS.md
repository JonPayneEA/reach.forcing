# reach.forcing 0.0.0.9000

- Source comparisons: `ratio_checks()` (typical ratio with a bootstrap interval over water
  years, spread, winter against summer, Sen's trend and Pettitt's change point in the annual
  ratio), `daily_agreement()` (wet-day hit and false-alarm rates, dry-while-wet and
  wet-while-dry days by month, bias by band), `timing_offset()` and `temperature_bands()`.
- First functions: `operational_rain()` rebuilds catchment rain the operational way
  (fixed Thiessen weights scaled up over the gauges that report, H19 at a standing weight,
  H19 alone below a temperature threshold); `gauge_weights()` gives Thiessen weights over a
  catchment, or redrawn over a subset of gauges; `longterm_ratios()` measures a gauge against
  SAAR moved to its own years with HadUK-Grid.
