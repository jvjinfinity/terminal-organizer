# Changelog

## 1.3.11 — 2026-09-03

Sidebar footer shows this Mac’s version (`1.3.11`) in the bottom left, so you can tell whether you have the latest build.

## 1.3.10 — 2026-09-02

When Grok makes a nested worktree but the shell stays in the main folder, that session’s row shows the tree and the worktree branch.

- Each Grok is matched to its own desk (two sessions in the same project no longer both say `main`).
- If we cannot prove which worktree this Grok is using, the row stays as the shell: no guessing.
- Linked worktrees you `cd` into still use the 1.3.9 detector.

## 1.3.9 — 2026-08-27

Sidebar shows git **worktrees** at a glance.

- Linked worktrees keep the **project** name as the row title.
- A green tree icon and the worktree name sit under the title (`wt` is the icon, not extra text).
- Branch stays on the right, as before.
- Filter matches repo name and worktree name.

## 1.3.8 — 2026-08-26

Fix: idle Groks all lighting up **Done** at once.

- Dropped Grok `idle_prompt` / `task_complete` (those mean “has been sitting there,” not “just finished”).
- **Done** now comes from an observe-only `Stop` when `reason` is `end_turn` (not a subagent, not a stop-hook continuation, not session teardown).
- **Needs your input** is still `permission_prompt`.
- The ping is attached to the Grok process (`--pid`) so one event cannot mark every session under `~/Developer`, or every duplicate row of the same folder.

Update: `git pull && ./scripts/install.sh`, then **quit and start Grok again** in each session so it loads the hook.

## 1.3.7 — 2026-08-24

Notifications only fire when Grok **needs your input** or **is idle**.

- Grok hooks match `permission_prompt` and `idle_prompt` / `task_complete` only. They no longer run on every `Notification`, every `Stop`, or every `StopFailure`.
- Terminal BEL (tab-complete, pagers, and most CLI beeps) no longer posts a Mac banner.
- Window titles that say “action required” / “needs input” still can.

Update: `git pull && ./scripts/install.sh`, then start a **new** Grok in the session so it loads the hook. An already-running Grok keeps the old noisy hook until you quit it.

## 1.3.0 — 2026-08-24

First public MIT release. Finder-style session sidebar, real local shell, git branch, notes. Build with `./scripts/install.sh` (no paid Apple signing).
