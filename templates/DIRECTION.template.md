# Direction

**Human-owned.** Every loop reads this file before acting and must never
edit it (the wrapper's no-go floor reverts any loop commit that touches
it). Change knobs here to steer; changes take effect next run. Edit it from
any browser — the loops pull before acting.

## Focus

Priorities, in order (the orchestrator triages every finding against this
list — make each falsifiable through a number or a trend where you can):

1. <what must never break for your users>
2. <keep deployed current / telemetry flowing — if you deploy>
3. <your key user-journey quality bar>
4. Repo/doc hygiene.

## Knobs

```yaml
deploy: ack                 # ack | auto — ack stages a DEPLOY PENDING item;
                            #   auto deploys when gates green, verifies,
                            #   rolls back code-only, notifies
push: local-only            # local-only | push — push only when every
                            #   unpushed commit is loop-prefixed
fix_pipeline: on            # on | off — reproduced bugs flow issue → PR
                            #   (fixer) → verify + merge (pr-verifier)
vm_cadence: daily           # off | daily — the brake on the e2e-user loop
notify_on: [failure, deploy, rollback, incident, pending-ack, new-user, decision-needed]
```

## No-go paths (loops may NEVER modify these — also mirrored in
## ops/loop.config.sh NOGO_PATHS, which is what the wrapper enforces)

- ops/DIRECTION.md, ops/loop.config.sh, .gitattributes, .gitignore
- <your crypto / auth / billing / installer / release paths>

## Standing orders (freeform — the loops read these verbatim)

- Prefer reverting a loop change over fixing it forward.
- When in doubt, do less and write it up.
- <anything you'd tell a careful new team member>
