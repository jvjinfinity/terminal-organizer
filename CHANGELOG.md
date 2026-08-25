# Changelog

## 1.3.7 — 2026-08-24

Notifications only fire when Grok **needs your input** or **is idle**.

- Grok hooks match `permission_prompt` and `idle_prompt` / `task_complete` only. They no longer run on every `Notification`, every `Stop`, or every `StopFailure`.
- Terminal BEL (tab-complete, pagers, and most CLI beeps) no longer posts a Mac banner.
- Window titles that say “action required” / “needs input” still can.

Update: `git pull && ./scripts/install.sh`, then start a **new** Grok in the session so it loads the hook. An already-running Grok keeps the old noisy hook until you quit it.

## 1.3.0 — 2026-08-24

First public MIT release. Finder-style session sidebar, real local shell, git branch, notes. Build with `./scripts/install.sh` (no paid Apple signing).
