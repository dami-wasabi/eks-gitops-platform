# Runbook: quote availability budget burn

**Alerts:** `QuoteAvailabilityBudgetBurnFast` (page), `QuoteAvailabilityBudgetBurnSlow` (ticket)
**SLO:** 99.5% of `POST /api/quote` requests succeed (not 5xx) over 30 days. Error budget: 0.5%.
**Dashboard:** Grafana → *money-transfer / SLOs*

## What the alert means

More quote requests are failing than the budget allows. The fast alert means about 2% of the whole month's budget is going per hour (or 5% per six hours), so you have hours, not days. The slow alert means the current error rate will exhaust the budget before the month ends.

## First five minutes

1. **Confirm it's real.** Dashboard → *Quote requests by status*. Are 5xx actually rising, and is traffic normal?
2. **Was anything just deployed?** Argo CD UI → `money-transfer` app → *History*. A recent sync is the most likely cause.
   ```bash
   kubectl -n argocd get application money-transfer -o jsonpath='{.status.history[-1]}'
   ```
3. **Is a chaos experiment running?** The *Pods and injected faults* panel. A non-zero `faults/min` means `FAULT_ERROR_RATE` is set: find and revert that change.
4. **Are the pods healthy?**
   ```bash
   kubectl -n money-transfer get pods
   kubectl -n money-transfer logs deploy/money-transfer --tail=100
   ```

## Mitigate first, investigate second

| Cause | Action |
|---|---|
| Bad release | `git revert` the change in this repo and merge. Argo CD rolls back in a few minutes. Don't hand-edit the cluster; `selfHeal` will undo it. |
| Fault injection left on | Revert the commit that set `FAULT_ERROR_RATE`. |
| Pods crash-looping / OOMKilled | Check `kubectl describe pod` for the reason; raise memory limits in `values.yaml` via a PR if needed. |
| Not enough capacity | Check the HPA (`kubectl -n money-transfer get hpa`). If it's at `maxReplicas`, raise it via a PR. |

## Afterwards

If the budget dropped noticeably, write a short postmortem (see [`docs/postmortems/`](../postmortems/)): what happened, how it was detected, the impact in budget terms, and what changes prevent a repeat.
