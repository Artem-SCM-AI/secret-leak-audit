# CLAUDE.md — secret-leak-audit

This repo is a distributable Claude Code package. The primary "code" is
`.claude/skills/security-audit.md`, which orchestrates the Bash scripts in
`scripts/`. When modifying a script, update its matching test in `tests/`
and run `tests/run-all.sh` before committing.

Never print a matched secret's raw value anywhere — always route findings
through `scripts/redact.sh` first.
