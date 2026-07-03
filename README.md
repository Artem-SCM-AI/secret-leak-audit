# secret-leak-audit

Free tool: audits every git repo on your machine for leaked or
about-to-leak secrets, then — separately, and only if you say yes —
hardens your setup so it structurally can't happen again.

Built after a real incident: a live API token and a service-account key
sat hardcoded in a public repo for two weeks because a secret-scanning
hook had been silently disabled by a local git config override, and the
scanning rule that should have caught it was checking an outdated token
format. This tool exists so that specific failure mode gets caught
automatically, for anyone, not just after the fact.

## Canonical source

Only trust `https://github.com/Artem-SCM-AI/secret-leak-audit`. If you
found this anywhere else, verify against that URL before running it —
a tool that asks for filesystem and git-config access is a plausible
target for a malicious lookalike.

## Requirements

- Claude Code CLI, installed and authorized
- `gitleaks` (the tool installs this for you on macOS/Linux if missing;
  on Windows you'll need to install it manually — see below)
- Optional: `gh` CLI, authenticated, for public/private repo visibility
  checks (skipped gracefully if not present)

## Quick start

```bash
git clone https://github.com/Artem-SCM-AI/secret-leak-audit.git
cd secret-leak-audit
```

Open this folder in Claude Code and ask it to run the security audit.
It will:

1. Make sure `gitleaks` is installed
2. Ask which folder to scan (defaults to your home directory) and show
   you what it found before touching anything
3. Check each repo for: already-exposed secrets, secrets about to be
   committed, gitignore gaps, whether the repo is public, and a
   `.mcp.json` hygiene check if you use Claude Code MCP servers
4. Walk you through every finding one at a time — nothing gets changed
   without you saying yes to that specific item
5. Ask, separately, whether you want it to install permanent protection
   (a global pre-commit hook) so this can't happen again on any future
   repo — this step changes settings that affect your whole machine, not
   just what was just scanned, so it's a separate explicit yes

## What it does NOT do

- It does not rewrite git history. If a secret is already committed, the
  fix it recommends is **rotating the credential at its source**
  (revoking/regenerating it with the provider) — removing it from git
  alone does not undo the fact that it was already exposed.
- It does not guarantee zero exposure. It checks for known secret
  patterns; unusual or custom token formats may not match. Use judgment.
- It does not silently overwrite any existing gitleaks/hook configuration
  you already have. If something's already there, it tells you what to
  add by hand instead of touching it.

## Uninstalling the global hook

If you ran the hardening step and want to remove it later:

```bash
git config --global --unset core.hooksPath
rm -f ~/.git-hooks/pre-commit
```

(Leaves `~/.gitleaks.toml` in place — delete it separately if you want.)

## Emergency override

If the installed hook ever blocks a commit you're certain is safe:

```bash
git commit --no-verify
```

Use sparingly — this skips the check entirely for that one commit.

## Windows

No automatic installer in this version. Install `gitleaks` manually from
https://github.com/gitleaks/gitleaks/releases, then open this folder in
Claude Code as above — Phase 1 (the audit) works the same way once
`gitleaks` is on your PATH.

## No warranty

Provided as-is. This is a free tool, not a security guarantee. You're
responsible for your own security posture.
