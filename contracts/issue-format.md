# Contract: issue format

Every loop-filed issue body carries these sections (the wrapper's queue lint
flags filings that no executor could ever pick up):

```markdown
## Found
<date, which loop/stage, what you were doing>

## Evidence
<ledger row / log path / verbatim command output — never a paraphrase>

## Proposal
<what to change and why, smallest viable>

## Action
<one of:
 loop — auto-fixable once accepted or cooled (requires bug + Repro + Verify)
 operator: <exact copy-pasteable commands the human runs>
 interactive: <exact ask the human pastes into an agent session — used for
   no-go-path work or design-grade changes>>

## Repro            (REQUIRED when labeled `bug`)
<exact commands from a clean state that demonstrate the defect — commands
you actually ran tonight; paste them, don't reconstruct them>

## Verify           (REQUIRED for action:loop)
<machine-checkable command(s) that prove the fix; the verifier runs these>
```

Labels at creation: `loop-filed` + exactly one `action:*` + exactly one
`component:*`; `bug` when it is one. DEDUP before filing:
`gh issue list -R $GH_REPO --state all --search "<distinctive phrase> in:title"`
— reference an existing open/recently-closed match in the digest instead of
re-filing.

## Decision issues (`🙋 needs-your-decision`)

For findings blocked on an owner call (risk trade-offs, ambiguity the
DIRECTION file doesn't answer), ALSO add the `🙋 needs-your-decision` label
and structure the body as:

```markdown
## Context
<what you were doing, what you found, the numbers>

## Why this needs you
<the exact knob / no-go rule / ambiguity that forbids the loop deciding>

## Options
- **A. <name> (recommended?)** — <what it does>. Choose this when <situation>.
  Enact: <exact command / precise DIRECTION edit / label to apply>.
- **B. …** (2–4 options total, each with when-to-choose + enacting action)

## To answer
Do an option's action directly, or reply `Option X` — the next nightly run
records it and keeps the enacting action in "Needs you" until done.
```

Every new decision issue gets a `> NOTIFY: decision needed #<n>` digest line.
A finding with no concrete executable action is a digest note, not an issue.
