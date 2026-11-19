# 2026-11-03 — recursive worker tests exhausted workstation memory

**Who:** Codex, investigating an Antigravity worker's test changes  **Scope:** workstation test process  **Mode:** write
**Task:** diagnose the OOM reported during B2 reviewer implementation
**Skill:** diagnosing-bugs (local harness skill)

## What changed

Removed two uncommitted tests that launched unittest discovery of their own
suite. Each child reran those tests, creating recursive subprocess spawning.
Kept a single isolated-entrypoint subprocess check and bounded its timeout.
Further tests ran in a transient service with memory, task and runtime caps.
The worker was not restarted after the reboot; its committed implementation
and surviving fixes were inspected before use.

## Snapshot / backup taken

The worker's first implementation remained in its local Git commit, and its
surviving working changes were inspected before the recursive tests were
removed. No desktop configuration or memory settings were changed.

## How it was verified

Previous-boot kernel journals recorded global OOM kills of Orca and
Quickshell around 00:48 and 00:50 local time. Process tables in the two OOM
dumps contained more than 2,000 Python rows in total (rows across dumps,
not a count of unique processes). The recursive test code directly explains
unbounded Python spawning. These records do not establish a separate leak
inside Gemini's runner.

After removal, all 22 tests passed from an unrelated working directory under
512 MiB, 24-task and 30-second caps. One run reported a memory peak of
88.5 MiB; a subsequent run after small validation changes reported 54.8 MiB.
Sources: `journalctl -k -b -1` and `systemd-run --user` test results, inspected
2026-11-03. No attempt was made to reproduce the system-wide OOM.

## Still open

The process-spawning bug is removed. No separate runner leak has been proven.
