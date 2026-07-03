---
name: security-audit
description: Audits every git repo on the user's machine for leaked or about-to-leak secrets, then optionally hardens their global gitleaks setup. Use when the user wants to run a secret-leak audit, check for exposed credentials, or asks "is anything leaked" / "run the security audit".
---

## What this skill does

Three phases, run in order, each with its own explicit checkpoint:

**Phase 0 — Bootstrap.** Run `bash scripts/bootstrap-gitleaks.sh`. If it reports
`GITLEAKS_MISSING` after attempting install, stop and show the user the manual
install instructions it printed — do not proceed to Phase 1 without a working
`gitleaks` binary (`bash scripts/bootstrap-gitleaks.sh --check-only` should
report `GITLEAKS_OK` before continuing).

**Phase 1 — Audit.**

1. Discovery: ask the user which root directory to scan (default: their home
   directory). Run `bash scripts/discover-repos.sh <root>`. Show the list of
   discovered repos and ask "audit these N repos?" before doing anything else.
2. For each repo, run all six checks:
   - `bash scripts/check-hook-integrity.sh <repo>`
   - `bash scripts/check-tracked-history.sh <repo> config/default-gitleaks.toml 60`
     (the script itself enforces the 60s cap — default is also 60s if the
     third argument is omitted — and prints `TIMEOUT` rather than hanging;
     if it reports `TIMEOUT`, tell the user this repo was skipped — too
     large, rerun manually with `gitleaks git`)
   - `bash scripts/check-working-tree.sh <repo> config/default-gitleaks.toml`
   - `bash scripts/check-gitignore-coverage.sh <repo>`
   - `bash scripts/check-public-repo.sh <repo>`
   - `bash scripts/check-mcp-hygiene.sh <repo>`
3. Classify every raw output line into the severity ladder:
   - `check-tracked-history.sh` `HIT` line + `check-public-repo.sh` says `PUBLIC`
     → 🔴 CRITICAL
   - `check-tracked-history.sh` `HIT` line + repo is `PRIVATE` (or `NO_REMOTE`/
     `INFO_*`, since visibility couldn't be confirmed as safe) → 🟠 HIGH
   - `check-working-tree.sh` `HIT` line, or `check-gitignore-coverage.sh`
     `UNPROTECTED`/`TRACKED_DESPITE_IGNORE` → 🟡 MEDIUM
   - `check-hook-integrity.sh` `NO_GLOBAL_HOOK` or `SHADOW_OVERRIDE`, or
     `check-mcp-hygiene.sh` `HYGIENE` line → 🔵 LOW
   - Any check that returned an `INFO_*`/timeout-skip result and nothing else
     fired for that repo → ⚪ INFO
4. Never print a matched secret's raw value — every check script already
   redacts before printing (via `scripts/redact.sh`); do not re-derive or
   print the value yourself even if you can infer it from context.
5. Write the full findings list to `~/secret-leak-audit-report-<YYYY-MM-DD>.md`,
   `chmod 600` it immediately after writing, and include this disclaimer
   verbatim at the top of the report:
   > This scan checks for known secret patterns. The absence of a finding is
   > not a guarantee of zero exposure — rare or custom token formats may not
   > match. Use judgment; when in doubt, rotate.
6. Walk the findings one at a time, worst severity first, in conversation
   (not by dumping the whole report and asking one blanket question):
   - Show the finding (file:line, rule, severity, which repo).
   - For CRITICAL/HIGH: explain that the credential has already been seen by
     git and anyone with clone/view access, and that the primary fix is
     **rotating it at the source** — give a provider-specific pointer if the
     rule ID suggests one (`notion-api-key` → Notion Settings → Connections;
     `google-service-account-key-id` → Google Cloud Console → Credentials;
     `aws-access-key` → IAM). Offer to also untrack/gitignore the file as a
     secondary step, explicit that this alone does not undo the exposure.
   - For MEDIUM: offer to gitignore the file (and optionally move it out of
     the repo). This is genuinely sufficient — nothing has been exposed yet.
   - For LOW (structural): no per-finding fix — mention it resolves via
     Phase 2 and move on.
   - For LOW (`.mcp.json` hygiene): suggest switching to `${ENV_VAR}`, offer
     to make the edit if the user wants.
   - Any finding may be marked "not a secret / false positive — skip" instead
     of fixed; it stays in the saved report either way.
   - Never batch-fix. One finding, one yes/no, then the next.
7. Closing summary: what was fixed, what's still open (including INFO/
   skipped/false-positive items), the report file's path, and — if Phase 2
   hasn't run yet — ask explicitly whether to continue into it.

Each run is a complete, independent scan — this tool does not persist or
diff against a previous run's results. If the user runs it again later,
say so if asked why it isn't "only showing what's new."

**Phase 2 — Harden (only after its own explicit yes).**

Ask exactly this before running anything: "This changes global git settings
affecting every repo on this machine, not just the ones just audited.
Proceed?"

If yes: run `bash scripts/harden-install.sh` and relay its output plainly.
The script touches three targets — `~/.gitleaks.toml`, `~/.git-hooks/pre-commit`,
and global `core.hooksPath` — and for each one prints exactly one of:
- `*_INSTALLED` / `*_SET` — installed fresh.
- `*_PRESERVED_EXISTING` (`TOML_PRESERVED_EXISTING`, `HOOK_PRESERVED_EXISTING`,
  `HOOKSPATH_PRESERVED_EXISTING=<path>`) — something was already there and
  was left untouched. Relay the exact manual instructions the script printed
  for that target.
- `*_FAILED` (`TOML_INSTALL_FAILED: <error>`, `HOOK_INSTALL_FAILED: <error>`,
  `HOOKSPATH_SET_FAILED: <error>`) — the write itself failed (permissions,
  disk, etc.). The script exits non-zero and stops at the first failure, so
  later targets may not have run at all. Treat this as a hard stop: show the
  user the exact error, state plainly that protection is **not** fully
  active, and do not claim success for any target — including ones that
  reported `*_INSTALLED`/`*_SET` earlier in the same run — until the failure
  is resolved and the script is re-run cleanly.

Finish with a live proof-of-protection test — but only if the run completed
without any `*_FAILED` output: in a disposable temp git repo, stage a file
containing a known-bad string (e.g. reuse one of the samples from
`tests/test-default-gitleaks-toml.sh`), attempt to commit, show that it is
blocked, then clean up the temp repo. This is the payoff moment — show,
don't just tell, that the protection works.

## Non-negotiable rules (see also the parent repo's CLAUDE.md)

- Never print, log, or save a matched secret's raw value.
- Never attempt git history rewriting (no BFG, no filter-repo, no force-push).
- Never run Phase 2 without its own explicit confirmation, separate from the
  Phase 1 "audit these repos?" confirmation.
- Only scan/modify repos the user has consented to and has authority over —
  say so plainly before Phase 1 discovery runs.
