# Rainfall inputs and uncertainty: the plan

The end-to-end plan for rainfall inputs: from the gauge archive, H19, HadUK-Grid and SAAR,
through quality control and catchment averaging, to model forcing with its uncertainty attached.
reach.forcing implements the downstream part; `reach.io` fetches and `reach.validate` checks.

| Part | What it covers |
|---|---|
| [1. Plan](01-plan.md) | The summary, the inputs chain, the decisions taken and the roadmap |
| [2. Processes in detail](02-processes.md) | The eight processes: steps, decision points, criteria and roles |
| [3. Source comparisons](03-source-comparisons.md) | The numerical comparisons between gauges, SAAR, HadUK-Grid and H19 |
| [4. Data build](04-data-build.md) | What to extract, download and generate in Databricks, and how to store it |
| [5. Explorer specification](05-explorer-specification.md) | The catchment explorer, a Shiny app in Databricks |

The plan began as a Claude Doc and was copied here on 16 November 2026. This copy is now the
master: change the plan by pull request, so every change has a reason and a reviewer. The
diagrams in `images/` are pictures of the doc's diagrams at that date; redraw them if the
stages they show change.

The plan names datasets the team holds, such as H19 and FEH SAAR, but contains none of their
data.
