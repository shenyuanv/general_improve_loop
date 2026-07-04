# SOTA autonomous dev loops & how to measure them (deep-research memo, 2026-07-04)

Method: 5-angle web sweep → 25 sources fetched → 125 claims extracted →
top 25 adversarially verified (3 skeptic votes each) → 23 confirmed,
2 refuted, 0 unverified. 107 agents, ~2.4M tokens. User-provided reference
(github.com/cobusgreyling/loop-engineering) folded in post-hoc (fetched,
not adversarially verified). Where this memo says VERIFIED, it means
survived 2-of-3 refutation votes with primary-source quotes.

## 1. The verified SOTA landscape (2024–2026)

**Two architectural families over one canonical workflow** (VERIFIED,
Jiang/Lo/Liu survey arXiv:2512.22256 + primaries): *agentic pipelines*
(predefined state-machine stages — Agentless, PatchPilot, MASAI's five
sub-agents: Test Template Generator → Issue Reproducer → Edit Localizer →
Fixer → Ranker) versus *autonomous agents* (planning/tool loops —
SWE-agent, OpenHands). Both follow localization → repair → optional
reproduction/regression validation → patch selection.

**Role-played software organizations** (VERIFIED): ChatDev (CEO/CTO/
programmer/reviewer/tester over waterfall phases, ACL 2024), MetaGPT
(Product Manager → Architect → Project Manager → Engineer → QA, SOPs as
prompt sequences, ICLR 2024), MAGIS (Manager/Repository Custodian/
Developer/QA on GitHub issues, NeurIPS 2024). Caveat: the SWE-bench
leaders are mostly single-agent or pipeline designs — role theater is not
what wins benchmarks; verification structure is.

**The production GitHub-native bar — Copilot cloud agent** (VERIFIED on
live GitHub docs): per-task ephemeral Actions sandbox; write access
confined to one `copilot/` branch; exactly one draft PR per task; cannot
mark ready-for-review, approve, or merge; the requester's approval does
not count toward required approvals (structural anti-rubber-stamp); CI on
agent pushes is human-gated by default. **REFUTED**: that it supports
scheduled/event-triggered unattended loops — it does not; every documented
path has a human in the trigger and merge loop.

**Community taxonomy** (user reference, loop-engineering): five building
blocks (scheduling, worktrees, skills, maker/checker sub-agents, durable
state), seven cadence patterns (Daily Triage, PR Babysitter, CI Sweeper…),
an L1 report-only → L2 assisted → L3 unattended rollout ladder, and a
0–100 "Loop Ready Score" CLI. Converges independently on this repo's
architecture; its caveat — "loop engineering amplifies judgment, both good
and bad" — matches our floors-guarantee-blast-radius law.

**Where this repo sits**: our relay is a hybrid — fixed pipeline at the
top (schedule → triage → fix → verify), autonomous agents inside each
stage, role charters like the org-simulation tradition, plus three things
the verified corpus does NOT document elsewhere: (a) fully unattended
nightly operation with *mechanical* bash floors (the refuted Copilot claim
means the flagship product explicitly lacks this); (b) an adversarial
default-REJECT verifier that re-reproduces on base; (c) gated self-hosting
(the loop improves its own engine behind promote/verify-live/rollback).

## 2. Benchmarks & field results

- SWE-bench dominates 2024–2026 (VERIFIED): real issues+PRs, scored by
  repo test suites; Lite=300, Verified=500 (OpenAI-annotated).
- **Resolve rates are inflated** (VERIFIED): ~6.2pp from
  incorrect-but-counted patches (PatchDiff, ICSE 2026: 7.8% of "resolved"
  fail the developer suite; 29.6% of plausible patches diverge from ground
  truth); plus contamination (DeepSeek-V3 releases tie on fresh
  SWE-rebench tasks, diverge on Verified). OpenAI retired Verified
  Feb 2026. The field's answer is continuous decontaminated mining
  (SWE-rebench: 21,336 auto-mined tasks, leaderboard contamination flags).
- Representative (historical) rates (VERIFIED): MAGIS 13.94% SWE-bench;
  DARS 47% Pass@1 Lite; trajectory to ~78% on Verified by 2026 per survey
  (fetch-level, not top-verified).
- Field results surfaced but NOT adversarially verified in this run
  (treat as leads): AIDev corpus (456k agent-authored PRs across 61k
  repos); ~83.8% eventual merge rate for Claude-Code-assisted PRs in one
  study; Devin self-reported 34%→67% merge rate YoY; METR RCT (16
  maintainers, 246 tasks): devs were ~19% *slower* with AI while
  believing they were ~20% faster — the canonical warning that perceived
  productivity ≠ measured productivity.

## 3. Measurement — the verified gap, and what to do about it

The field's toolkit (VERIFIED): execution-based (Resolved%, Pass@k),
match-based localization, cost/statistics (tokens, $, time), plus agent
metrics (trajectory efficiency, tool accuracy, complexity/coupling,
coverage maintenance). Three independent surveys converge (VERIFIED):
evaluation is one-dimensional — non-functional quality, human cognitive
load/intervention effort, and cooperation are unmeasured. **The corpus
contains ZERO executed controlled or quasi-experimental field studies
comparing loop-projects to baselines on DORA metrics, defect escape,
reviewer burden, or cost per merged fix.** Frameworks proposed; none run.

Implication for this repo: our nightly mechanical measurement (runs.jsonl
cost/outcome accounting, scorecard funnel/merge-latency/ratchet, xfail
fail-before/pass-after contract, digest↔accounting reconciliation, audit
ledger) already operationalizes much of what the literature only proposes.
The credible next step is to make this repo the executed study the field
lacks:

1. **Within-repo interrupted time series** (quasi-experiment): the
   pre-loop git/issue history is the baseline; loop-era windows compared
   on time-to-fix, defect-escape (bugs found post-merge per merged PR),
   test-count/LOC ratchet, and cost per merged fix — all already logged.
2. **Guard the known pitfalls** (all VERIFIED as real): rubber-stamping
   (our requester≠approver equivalent: default-REJECT verifier + never
   `--admin`; track reject rate >0), Goodharting on merge counts (rank
   defect-escape and journey-verdict trends above merge volume),
   perception bias (METR: never self-report speedup without the ledger),
   and benchmark-style inflation (our analogue: PatchDiff-style spot
   audits — does a "fixed" issue's defect actually stay dead? The journey
   re-test loop already does this for user-visible defects).
3. **Publishable metric set** (maps 1:1 to existing artifacts):
   scheduled_success_rate; merged-fix lead time (median 0.2h here vs
   field's days); cost/merged-fix; reviewer-burden = owner minutes/day
   (digest skim + decisions — trackable from 🙋 turnaround); defect
   escape = journey/tester finds attributable to loop-merged code.

## Refuted claims (kept for the record)
- Specific SWE-bench+ integrity percentages (32.67% leakage / 31.08%
  over-broad tests) as attributed — direction real, numbers unverified.
- Copilot cloud agent unattended scheduled operation — does not exist.

## Open questions the field hasn't answered
1. Any executed loop-vs-baseline field study? (None found — design one.)
2. True acceptance vs rubber-stamp rates for agent PRs at scale.
3. Safe unattended-trigger mechanisms preserving human gates (our
   harness is one existence proof; undocumented elsewhere).
4. Post-Verified benchmark succession (Pro vs rebench vs Live).

Primary sources: arXiv 2512.22256 · 2508.00083 · 2510.09721 · 2404.04834
(TOSEM'25) · 2310.06770 (SWE-bench) · 2503.15223 (PatchDiff/ICSE'26) ·
2505.20411 (SWE-rebench/NeurIPS'25) · 2403.17927 (MAGIS) · 2406.11638
(MASAI) · docs.github.com cloud-agent (live 2026-07-04) · metr.org RCT ·
github.com/cobusgreyling/loop-engineering (user reference).
