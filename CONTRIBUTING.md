# Contributing

This is a spare-time open-source Mac app. Useful, focused patches are welcome. There is no paid support and no Apple Developer signing.

## Build

```bash
./scripts/install.sh    # Release → /Applications
./scripts/run.sh        # debug build, open from dist/
swift build -c debug --product TerminalOrganizer
```

Checks that do **not** overwrite your real session list:

```bash
./scripts/qc.sh
```

## What belongs here

The product is a Finder-style list of shells: folder, git branch, a note. Keep that simple.

Good PRs: bug fixes, safer install, better git/cwd, drop/paste, docs.

Please ask before adding splits, browsers, or multiplexer features.

## Conventions

- macOS 14+, Swift 6.2
- Do not pass `PATH` in the PTY environment (login zsh / `path_helper` need to own it)
- Keep `TERM_PROGRAM=TerminalOrganizer` (do not spoof Ghostty or Terminal.app)
- Do not set Grok notification method to `osc777`
- No secrets in the repo
