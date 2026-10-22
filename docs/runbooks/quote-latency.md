# Runbook: quote latency budget burn

**Alert:** `QuoteLatencyBudgetBurnFast` (page)
**SLO:** 99% of `POST /api/quote` requests complete in under 300 ms over 30 days. Error budget: 1%.
**Dashboard:** Grafana → *money-transfer / SLOs*

## What the alert means

Too many quote requests are slower than 300 ms. At the current rate the month's latency budget will be gone within days.

## First five minutes

1. **Dashboard → *Quote latency*.** Is p99 above 300 ms? Is it every request (p50 up too) or a tail (only p99)?
2. **Is a chaos experiment running?** A non-zero `faults/min (latency)` means `FAULT_LATENCY_MS` is set. Revert it.
3. **CPU saturation?** The app is CPU-bound, so slow responses usually mean throttled pods.
   ```bash
   kubectl -n money-transfer top pods
   kubectl -n money-transfer get hpa
   ```
   If the HPA is at `maxReplicas` or pods sit at their CPU request, scale up via a PR (`autoscaling.maxReplicas`, `resources`).
4. **Recent release?** Same as the availability runbook: check Argo CD history and `git revert` if it lines up.

## Mitigate first, investigate second

Revert recent changes before debugging. Every change to this cluster is a Git commit, so rolling back is always one revert away.
