# Source comparisons

Each comparison below names its sources, timescale, measure and the starting value that raises a flag; every starting value is tuned through process 3. Results land in `catchment_checks`.

## Long-term totals: gauges against SAAR

A gauge's long-term mean should match SAAR once SAAR is moved from 1961–1990 to the gauge's own period, and HadUK-Grid supplies that move.

For each gauge or catchment, over its period of record *P*:

```latex
c = \frac{\overline{H}_{P}}{\overline{H}_{1961\text{--}1990}} \qquad m = \frac{\overline{H}_{1961\text{--}1990}}{\mathrm{SAAR}} \qquad b = \frac{\overline{G}_{P}}{\mathrm{SAAR} \, c}
```

where *H* is HadUK-Grid annual rain at the gauge's cell, or averaged over the catchment, and *G* is the gauge's annual rain, or the catchment's gauge-based average.

| Measure | Meaning | Flag when (starting value) |
| --- | --- | --- |
| *c*, climate factor | How much wetter or drier the period is than 1961–1990 | Reported, not flagged |
| *m*, method ratio | HadUK against SAAR over the same years; differences in method, not climate | Outside 0.95 to 1.05: SAAR or HadUK suspect at that cell |
| *b*, gauge bias index | The gauge against SAAR, after the climate shift | Outside 0.90 to 1.10: gauge under- or over-recording, or poorly sited |

- Use only complete water years, with at least 10 of them; report the count.
- A 1 km cell's height can differ from the gauge's. Where they differ by more than about 50 m, report *b* but do not flag it.
- At catchment scale, *b* below 1 with runoff ratios near or above 1 points to under-catch; above 1 with low runoff ratios points to an area or flow problem.

## Monthly and annual: drift and breaks

The month-by-month ratio of each gauge to HadUK and to H19 should be steady; a trend or a step in it marks a gauge that has changed, not the weather.

For each gauge and month *t*, the log ratio to a reference *R* (HadUK cell, H19 pixel, or the mean of its neighbours):

```latex
r_t = \ln \frac{G_t}{R_t}
```

| Analysis | Sources | Measure | Flag when (starting value) |
| --- | --- | --- | --- |
| Typical ratio | Gauge ÷ HadUK, gauge ÷ H19 | Median of r, as a factor e^median | Outside 0.90 to 1.10 |
| Spread | The same | Median absolute deviation of r | Above twice the network's median spread |
| Seasonal split | The same, winter (Dec–Feb) and summer (Jun–Aug) apart | Winter factor ÷ summer factor | Below 0.90: winter under-catch, likely snow or wind |
| Trend | The same | Sen's slope of annual r, per decade | Beyond 3 per cent a decade |
| Change point | The same | Pettitt test on annual r; the year and the size of the step | Significant at 5 per cent and a step beyond 5 per cent |
| Double mass | Cumulative gauge against cumulative neighbour mean | Change in slope at the break | Beyond 5 per cent |

- A change point that matches a recorded gauge move, sensor change or maintenance visit is expected: split the series there and record it.
- A change point at the same date across several gauges in a region points to the reference, not the gauges.
- H19 enters only from its own start date, and through its own changes of radar or processing, which are recorded in its register entry.

## Daily: agreement day by day

At daily scale the gauge, its HadUK cell, its H19 pixel and its neighbours should agree on which days are wet and roughly how wet; persistent disagreement on either marks a faulty gauge.

Daily totals use the same rain day as HadUK (09:00 to 09:00 UTC), so gauge and H19 are summed to match it.

| Analysis | Sources | Measure | Flag when (starting value) |
| --- | --- | --- | --- |
| Wet-day agreement | Gauge against HadUK, H19 and neighbours | Hit rate and false-alarm rate for days of 1 mm or more | Hit rate below 0.80, or false-alarm rate above 0.20 |
| Dry while wet | Gauge against neighbours and H19 | Days the gauge records 0 while the neighbour median and H19 both exceed 5 mm | More than 2 in a month |
| Wet while dry | The same, reversed | Days the gauge exceeds 5 mm while the neighbours and H19 record under 0.5 mm | More than 2 in a month |
| Bias by intensity | Gauge against H19 and neighbours | Median ratio in bands of daily total (1–5, 5–15, 15–30, over 30 mm) | Any band outside 0.80 to 1.25 |
| Correlation | Gauge against neighbour mean | Spearman correlation of wet days, by season | Below the 5th percentile of the network for that season |

- Dry-while-wet runs are the commonest sign of a blocked funnel or a stuck tipper; they feed the single-gauge checks in process 2.
- Bias that grows with intensity points to tipping-bucket losses in heavy rain; bias in the lowest band alone points to evaporation or wetting losses.

## Sub-daily: gauges against H19

Only H19 and the gauges resolve storms within a day, so their hourly comparison tests timing, intensity and the 4 °C rule directly.

Compared hourly, gauge against the H19 pixel over it and the eight around it; 15-minute values are too noisy at a single pixel for anything but timing.

| Analysis | Measure | Flag or decision when (starting value) |
| --- | --- | --- |
| Timing | Lag of the peak cross-correlation, gauge against pixel, by month | A lag of one hour or more in a month: clock or summer-time error |
| Bias by temperature | Median gauge ÷ H19 in bands below 0 °C, 0 to 2, 2 to 4, 4 to 6 and above 6 °C | Sets the cold-weather rule: the band where the ratio falls away is the threshold, region by region |
| Bias by intensity | Median ratio in hourly bands (0.2–1, 1–4, 4–10, over 10 mm) | Any band outside 0.75 to 1.33 |
| Bias by season and range | Median ratio by season, and by distance from the radar | Reported; used to weight H19 in merging |
| Intensity distribution | Quantiles of wet hours, gauge against pixel (Q50, Q90, Q99) | Q99 ratio outside 0.67 to 1.5 |
| Detection | Hit and false-alarm rates for wet hours of 0.5 mm or more | Reported; poor detection limits H19's weight in summer storms |

- **The temperature analysis is the evidence for the 4 °C rule.** Fitted on the archive, it says where gauges and H19 part company in the cold, and whether the threshold should differ by region or gauge type (heated or not).
- If H19 is adjusted to gauges, the gauge being tested may be one of those it was adjusted to; check the adjustment network before reading agreement as validation.

## Catchment averages and events

At catchment scale the sources are compared as the model will see them, and the flow becomes a fifth witness: a source whose events return more water than fell is wrong somewhere.

| Analysis | Sources | Measure | Flag or decision when (starting value) |
| --- | --- | --- | --- |
| Annual totals | Thiessen, merged, H19 and HadUK catchment averages; SAAR scaled by *c* | Each against the others, by water year | Any source outside 0.90 to 1.10 of the median of the rest |
| Cross-validation | Thiessen and merged | Leave-one-gauge-out error at each gauge: bias, and RMSE of daily and hourly totals | Feeds the error model; reported per catchment |
| Event totals | All four | Event rain by source, for every event from `find_events()` | The sources' spread above 25 per cent of the median for an event: the event is reviewed |
| Event runoff ratios | Each source against flow | Event runoff ratio, flow volume ÷ event rain | Above 1.0, or far outside the season's range: rain short, flow high or area wrong |
| Annual balance | Each source against flow and PET | Rain minus flow against PET; the Budyko limits in `water_balance()` | Outside the limits: that source fails for that year |
| Effect on the model | Each source as forcing | Validation score and event scores of the calibrated model | Reported in process 5; a source that fits markedly better is investigated, not simply chosen |

- The event comparison is what would have flagged Beggearn Huish's event 82: 214 mm of rain against 212 mm of flow, a runoff ratio near 1 over four weeks of spring.
- A source that disagrees only in convective summers, or only in snow, is recorded with that condition rather than flagged overall.

## Statistical rules

Every comparison above follows the same rules, so its numbers mean the same thing everywhere.

- **Ratios in logs.** A gauge reading half and one reading double are equally wrong; log ratios treat them so. Report back as factors.
- **Robust measures.** Medians and median absolute deviations, not means and standard deviations: one storm or one fault must not move a gauge's verdict.
- **Flagged data out.** Values flagged high in process 2 leave every comparison; medium flags stay but are reported separately.
- **Minimum samples.** At least 10 complete water years for long-term totals, 24 months for trends, 30 wet days a season for daily measures and 100 wet hours a temperature band for sub-daily measures. Below these, report the measure with its count and raise no flag.
- **Dependence stated.** HadUK-Grid is built from gauges, possibly including the one being tested, and H19 may be adjusted to gauges. Each comparison records whether its reference could contain the gauge itself; where it could, a neighbour-only reference is computed too and both are reported.
- **Uncertainty on every measure.** A bootstrap over water years (or months) gives a 90 per cent interval; a flag needs the whole interval beyond the threshold, not just the central value.
- **Thresholds are starting values.** Each is tuned in process 3 against the archive's flag rates, and recorded with its version.
