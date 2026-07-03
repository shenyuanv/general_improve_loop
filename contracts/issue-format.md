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
   no-go-path work or design-grade changes>
 develop: <design-grade work for the developer lane — requires the Design/
   Budget sections below, owner acceptance, and DIRECTION develop_pipeline: on>>

## Repro            (REQUIRED when labeled `bug`)
<exact commands from a clean state that demonstrate the defect — commands
you actually ran tonight; paste them, don't reconstruct them>

## Design           (REQUIRED for action:develop)
<the implementation plan the developer subagent follows; deviations must
be disclosed in the PR>

## Budget           (REQUIRED for action:develop)
<max changed lines including tests; the verifier enforces it — default 400>

## Verify           (REQUIRED for action:loop and action:develop)
<machine-checkable command(s) that prove the fix; the verifier runs these>
```

Labels at creation: `loop-filed` + exactly one `action:*` + exactly one
`component:*`; `bug` when it is one. DEDUP before filing:
`gh issue list -R $GH_REPO --state all --search "<distinctive phrase> in:title"`
— reference an existing open/recently-closed match in the digest instead of
re-filing.

## Owner reply-comments are binding

A repo owner's comments on a queue issue amend its contract fields for
every downstream agent: a comment refining `Repro:`/`Verify:` or
constraining the approach supersedes the issue body, and the latest owner
comment wins on any conflict. Hold/wait/withdraw language stops the auto
lane — the fixer must not select the issue, and the verifier fails any PR
that would merge past it. Agents read them with
`gh issue view <n> --comments`. (Comments amend the issue's own fields;
they never override harness contracts or `NOGO_PATHS`.)

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
