---
layout: post
title: One more na update
categories:
- Code
- Blog
tags:
- scripting
- zsh
- tagging
- na
- cli
- ruby
- productivity
- taskpaper
date: 2025-10-29 08:00
slug: one-more-na-update
post_class: code
keywords: [next action]
---
This week I pushed a set of focused improvements to [NA](https://brettterpstra.com/projects/na) that make interactive workflows a lot smoother and the codebase a little more robust — including first‑class time tracking.

If you run `na update` without arguments you'll now get an interactive menu that helps you pick the file(s) and actions to operate on, with multiple selection and small but important quality-of-life fixes across parsing, move/edit behavior, and documentation.

## TL;DR

- `na update` (no args) now launches an interactive, consistent selection flow for files and actions.
- The update submenu supports multi-select, edit, move, and direct action modes more reliably.
- Fixed many edge cases: nil-safe string helpers, clearer YARD docs, and better tests for helper code.
- Under-the-hood improvements to file selection, action movement, and tagging logic.

### New: Time tracking

- Add start/finish times right from the CLI:
  - `--started TIME` on `add`, `complete`/`finish`, and `update`
  - `--end TIME` (alias `--finished`) on `add`, `complete`/`finish`, and `update`
  - `--duration DURATION` to backfill a start time from the finish
- Natural language and shorthand supported everywhere: `30m ago`, `-2h`, `2h30m`, `2:30 ago`, `yesterday 5pm`
- Durations aren’t stored; they’re computed from `@started(...)` and `@done(...)` when displayed.
- Display enhancements in `next`/`tagged`:
  - `--times` shows per‑action durations and a grand total (implies `--done`)
  - `--human` switches durations to friendly text
  - `--only_timed` filters to actions with both `@started` and `@done` (implies `--times --done`)
  - `--only_times` outputs only the totals (no action list; implies `--times --done`)
  - `--json_times` emits a JSON object with timed actions, per‑tag totals, and overall totals (implies `--times --done`)
  - Per‑tag totals are shown as a Markdown table with aligned columns and a footer row for the grand total
  - Duration color is theme‑configurable via a `duration` key (default `{y}`)

Example:

```bash
na add --started "30 minutes ago" "Investigate bug"
na complete --finished now --duration 2h30m "Investigate bug"
na next --times --human
na next --only_times
na tagged bug --json_times | jq
```

## What triggered this

A number of small UX issues had crept in over time: the interactive menu sometimes re-prompted or skipped expected options, move/edit operations wouldn't always update a project's indexes correctly, and a few helper methods could raise when given `nil` paths or values. I wanted to make the interactive flow predictable and to harden the helpers so the command-line experience is less brittle.

## Interactive `na update` flow

Run `na update` with no arguments and you'll see a consistent selection flow:

- Choose one or more todo files (fuzzy search / [fzf](https://github.com/junegunn/fzf) / [gum](https://github.com/charmbracelet/gum) used when available).
- Pick which actions to update (multi-selection supported).
- Choose an operation: edit, move, add tag, remove tag, mark done, delete.

Examples:

```bash
$ na update
Select files: (interactive list)
Select actions (multi):
  [x] 23 % Inbox/Work : - Fix X
  [x] 45 % Inbox/Personal : - Call Y
Choose operation: (edit / move / done / delete / tag)
```

The menu now behaves consistently whether you pick a single file or multiple files; if you choose multi-select the update command applies as you'd expect to the set of chosen actions.

There's a direct action mode when you know the file and action: `na update PATH -l 23` still works as before. The interactive flow only kicks in when no explicit target is provided.

## Notable fixes

A lot of the work was small but important:

- Nil-safe string helpers: `trunc_middle`, `highlight_filename`, and friends were guarded against `nil` inputs so tests and UI code don't explode when a file is missing or the database contains a stray blank line.
- Action move/edit correctness: moving an action to a different project now updates parent indexes and project line numbers properly, avoiding off-by-one bugs that could leave the file in a strange state.
- `select_file` and fuzzy matching: the fuzzy and database-driven file selection was made more robust — the code handles directories that have a `file.na` or `file/file.na` pattern and falls back to a clear error instead of failing silently.
- YARD docs: cleaned up a number of `@!method` directives and added top-level `@example` blocks for the main classes and helpers so the docs are friendlier and generate without warnings.
- Tests: added and fixed unit tests for `Array`, `Hash`, and `String` helpers. TTY screen and color-related test stubs were improved for reliability on CI.
  - New tests for time features: JSON output, totals‑only output, timed‑only filtering.

## Try it

You can update to the latest version with:

{% iterm "gem install na" %}

That should give you v1.2.85 or higher.

If you're on a recent development build or want to try the updates locally:

```bash
# From the gem checkout
bundle exec bin/na update

# Or after building the gem and installing
na update
```

If you run into anything odd, please open an issue with the command you ran and a short description of what you expected vs what happened. Small, reproducible steps are the fastest way to a fix.

If you hit an error and want to include a backtrace, run the command with debug enabled and paste the output:

```bash
GLI_DEBUG=true na [COMMAND]
```

## Other updates

I last wrote about 1.2.80. Here are a few highlights from the subsequent releases:

- 1.2.85 (2025-10-26)
  - YARD docs polish — coverage is now effectively complete
  - Nil-safety: guards for `trunc_middle` and `highlight_filename`
- 1.2.84 (2025-10-25)
  - Fix: handle nil input when traversing depth
- 1.2.83 (2025-10-25)
  - Fix: ignore `-d X` values that exceed existing structure depth
  - Allow depth > 9 for `-d`
- 1.2.82 (2025-10-25)
  - New: multi‑select menu when using `na update`
- 1.2.81 (2025-10-25)
  - New: `na scan` to find untracked todo files (thanks @rhsev)
  - Improvements: RuboCop cleanup, YARD docs, and test coverage
  - Fixes: color reset in parent display; subdirectory traversal with `na next -d X`

Thanks for playing with it and for the helpful feedback you've been sending. Check out the [NA project page](https://brettterpstra.com/projects/na) for more info.
