# known-failures.d — one marker file per pinned bug

A file here named after a test (e.g. `t35-notify-quoting`) pins a KNOWN,
issue-tracked bug: the test reports `xfail` while failing, and `XPASS`
(suite failure) once it passes without the pin being flipped. File content
is the tracking issue ref (e.g. `#34`). A PR that fixes a pinned bug must
also `git rm` its marker — that flip is the mechanical fail-before/
pass-after evidence. Distinct marker paths keep concurrent pin flips
conflict-free by construction (issue #34; the old single-list
`tests/known-failures.txt` merge-conflicted whenever two PRs flipped pins
the same night). This README is a directory keeper, never a pin.
