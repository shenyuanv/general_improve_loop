#!/usr/bin/env bash
# T48 — roles/ layout end-to-end: the wrapper resolves a loop prompt by
# glob from its role folder (proven on the NEWEST role, manager), pipes it
# verbatim, and records the row under the loop name — role dirs are
# organization, loop names are the identifiers.
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop manager

t_assert_rc 0
t_assert_eq "$(t_row .loop)" "manager"
t_assert_eq "$(t_row .result)" "success"
t_assert_contains "$T_CAP/agent-argv.txt" "direction stewardship at proposal level"  # manager.md content
t_assert_contains "$T_CAP/agent-env.txt" "ILOOP_STATE=$T_STATE"

# unknown loop still fails loudly through the glob path
t_run_loop no-such-loop
t_assert_rc 1
t_assert_contains "$(t_runlog no-such-loop)" "no agent prompt at roles/"
