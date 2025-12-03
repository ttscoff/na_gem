<!--README--><!--GITHUB--># na

[![Gem](https://img.shields.io/gem/v/na.svg)](https://rubygems.org/gems/na)
[![Travis](https://app.travis-ci.com/ttscoff/na_gem.svg?branch=main)](https://travis-ci.org/makenew/na_gem)
[![GitHub license](https://img.shields.io/github/license/ttscoff/na_gem.svg)](./LICENSE.txt)<!--END GITHUB-->

**A command line tool for adding and listing per-project todos.**

_If you're one of the rare people like me who find this useful, feel free to
[buy me some coffee][donate]._

The current version of `na` is <!--VER-->1.2.94<!--END VER-->.

<!--GITHUB-->
### Table of contents

- [Installation](#installation)
- [Optional Dependencies](#optional-dependencies)
- [Features](#features)
  - [Easy matching](#easy-matching)
  - [Recursion](#recursion)
  - [Adding todos](#adding-todos)
  - [Updating todos](#updating-todos)
- [Terminology](#terminology)
- [TaskPaper Syntax](#taskpaper-syntax)
- [Usage](#usage)
  - [Commands](#commands)
  - [add](#add)
  - [edit](#edit)
  - [find](#find)
  - [init, create](#init-create)
  - [move](#move)
  - [next, show](#next-show)
  - [plugin](#plugin)
  - [projects](#projects)
  - [saved](#saved)
  - [scan](#scan)
  - [tagged](#tagged)
  - [todos](#todos)
  - [update](#update)
  - [changelog](#changelog)
  - [complete](#complete)
  - [archive](#archive)
  - [tag](#tag)
  - [undo](#undo)
- [Configuration](#configuration)
  - [Working with a single global file](#working-with-a-single-global-file)
  - [Add tasks at the end of a project](#add-tasks-at-the-end-of-a-project)
  - [Prompt Hooks](#prompt-hooks)
- [Time tracking](#time-tracking)
- [Plugins](#plugins)
- [Changelog](#changelog)
<!--END GITHUB--><!--JEKYLL
- Table of Contents
{:.toc}
-->

`na` ("next action") is a command line tool designed to make it easy to see what your next actions are for any project, right from the command line. It works with TaskPaper-formatted files (but any plain text format will do), looking for `@na` tags (or whatever you specify) in todo files in your current folder.

Used with Taskpaper files, it can add new action items quickly from the command line, automatically tagging them as next actions. It can also mark actions as completed, delete them, archive them, and move them between projects.

It can also auto-display next actions when you enter a project directory, automatically locating any todo files and listing their next actions when you `cd` to the project (optionally recursive). See the [Prompt Hooks](#prompt-hooks) section for details.

### Installation

Assuming you have Ruby and RubyGems installed, you can just run `gem install na`. If you run into errors, try `gem install --user-install na`, or use `sudo gem install na`.

If you're using Homebrew, you have the option to install via [brew-gem](https://github.com/sportngin/brew-gem):

    brew install brew-gem
    brew gem install na

If you don't have Ruby/RubyGems, you can install them pretty easily with Homebrew, rvm, or asdf. I can't swear this tool is worth the time, but there _are_ a lot of great gems available...

<!--JEKYLL> You can find the na source code (MIT license) on [GitHub][].-->

### Optional Dependencies

If you have [gum][] installed, na will use it for command line input when adding tasks and notes. If you have [fzf][] installed, it will be used for menus, falling back to gum if available.

### Features

You can list next actions in files in the current directory by typing `na`. By default, `na` looks for `*.taskpaper` files and extracts items tagged `@na` and not `@done`. This can be modified to work with a single global file, and all of these options can be changed in the configuration.

#### Easy matching

`na` features intelligent project matching. Every time it locates a todo file, it adds the project to the database. Once a project is recorded, you can list its actions by using any portion of the parent directories or file names. If your project is in `~/Sites/dev/markedapp`, you could quickly list its next actions by typing `na next dev/mark`. Creat paths by separating with / or :, separate multiple queries with spaces. na will always look for the shortest match for a path.

#### Recursion

`na` can also recurse subdirectories to find all todo files in child folders as well. Use the `-d X` to search X levels deep from the current directory. `na -r` with no arguments will recurse from your current location, looking for todo files 3 directories deep.

#### Adding todos

You can also quickly add todo items from the command line with the `add` subcommand. The script will look for a file in the current directory with a `.taskpaper` extension (configurable).

If found, it will try to locate an `Inbox:` project, or create one if it doesn't exist. Any arguments after `add` will be combined to create a new task in TaskPaper format. They will automatically be assigned as next actions (tagged `@na`) and will show up when `na` lists the tasks for the project.

#### Updating todos

You can mark todos as complete, delete them, add and remove tags, change priority, and even move them between projects with the `na update` command.

### Terminology

**Todo**: Refers to a todo file, usually a TaskPaper document

**Project**: Refers to a project within the TaskPaper document, specified by an alphanumeric name (spaces allowed) followed by a colon. Projects can be nested by indenting a tab beyond the parent projects indentation.

**Action**: Refers to an individual task, specified by a line starting with a hyphen (`-`)

**Note**: Refers to lines appearing between action lines that start without hyphens. The note is attached to the preceding action regardless of indentation.

### TaskPaper Syntax

NA has its own syntax for searching tags, titles, and notes, but it also understands most of the [TaskPaper query syntax](https://guide.taskpaper.com/reference/searches/). TaskPaper-style searches are accepted anywhere you can pass a `@search(...)` expression, including:

- `na next "@search(...)"` (or via saved searches)
- `na find "@search(...)"` and `na saved NAME` when the saved value is `@search(...)`
- TaskPaper files themselves, on any line of the form `TITLE @search(PARAMS)` (these become runnable saved searches)

What follows documents the subset and extensions of TaskPaper search that `na` supports.

#### Predicates and tag searches

- **Simple text**: Bare words are treated as plain-text search tokens on the action line, combined with `and` by default.
- **Tag predicates**:
  - `@tag` (no value) means "this tag exists with any value". For example, `@priority` matches `@priority(1)`, `@priority(3)`, etc.
  - `@tag op VALUE` uses the following operators (TaskPaper relations are mapped to NA's comparison codes):
    - `=` / `==` / no operator: equality
    - `!=`: inequality (implemented as a negated equality)
    - `<`, `>`, `<=`, `>=`: numeric or date comparison when the value parses as a time or number
    - `contains` → `*=`: value substring match
    - `beginswith` → `^=`: prefix match
    - `endswith` → `$=`: suffix match
    - `matches` → `=~`: regular expression match (case-insensitive)
  - Relation modifiers like `[i]`, `[s]`, `[n]`, `[d]`, `[l]` are parsed and discarded; matching is always case-insensitive for string comparisons.
- **`@text`**:
  - `@text "foo"` is treated as a plain-text predicate on the action line (equivalent to searching for `"foo"`).
  - `@text` without a value is ignored.
- **`@done`**:
  - `@done` sets an internal "include done" flag and is not treated as a normal tag filter.
  - `not @done` (or `@done` combined with other predicates) correctly toggles whether completed actions are included.

#### Project predicates

- **Project equality**:
  - `project = "Inbox"` or `project == "Inbox"` limits results to actions under the `Inbox` project (matching NA's project path).
  - `project != "Archive"` excludes actions whose project chain ends in `Archive`.
- **Shortcuts**:
  - `project NAME` at the start of an expression is treated as a shortcut:
    - If it is the entire predicate, it becomes `project = "NAME"`.
    - If it is followed by additional logic, e.g. `project Inbox and @na`, the leading `NAME and` is dropped and the rest (`@na ...`) is parsed as normal. This matches TaskPaper's "type shortcut" usage rather than combining project name and text search.

#### Type shortcuts

TaskPaper defines type shortcuts that expand to `@type = ... and`. NA supports them in a way that is practical for task searches:

- `project QUERY`:
  - If used alone, becomes `project = "QUERY"`.
  - If followed by more predicates joined by `and`/`or`, only the tail expression is used (e.g. `project Inbox and @na` becomes `@na`).
- `task QUERY` and `note QUERY`:
  - The leading keyword is removed and the rest of the expression is interpreted as a normal text/tag predicate.
  - NA does not currently distinguish task vs note types for filtering; these shortcuts are primarily syntactic sugar.

#### Boolean logic

- `and` and `or` are supported with parentheses for grouping:
  - `@na and not @done`
  - `(@priority >= 3 and @na) or @today`
- Expressions are parsed into an internal boolean AST and converted to disjunctive normal form (OR of AND-clauses) before evaluation, so:
  - Complex nested groupings with multiple `and`/`or` operators behave as expected.
  - The unary `not` operator is handled at the predicate level (e.g. `not @done`, `not @priority >= 3`).

#### Item paths

NA understands a subset of TaskPaper item-path syntax and maps it to project scopes in your todo files. Item paths can be used:

- As the leading part of a `@search(...)` expression:
  - `@search(/Inbox//Bugs and not @done)`
- In TaskPaper saved searches (`TITLE @search(/Inbox//Project A and @na)`).

Supported item-path features:

- **Axes**:
  - `/Name` selects top-level items whose title contains `Name`.
  - `//Name` selects any descendants (at any depth) whose title contains `Name`.
- **Wildcards**:
  - `*` matches "all items" on that step.
  - Example: `/*` selects all top-level projects; `/Inbox//*` selects everything under `Inbox`.
- **Semantics in NA**:
  - Each matching project path is turned into an NA project chain like `"Inbox:New Videos"`.
  - Actions are filtered post-parse so that only actions whose parent chain starts with one of the resolved project paths are returned.

Current limitations:

- Set operations such as `union`, `intersect`, and `except` are not yet implemented.
- Slicing on item-path steps (e.g. `project *//not @done[0]` where `[0]` is attached to a path step) is not yet interpreted; see "Slicing results" below for what is supported.

#### Slicing results

NA supports TaskPaper-style slicing on the **result set of a `@search(...)` expression**, not (yet) on individual item-path steps:

- Supported forms:
  - `[index]`
  - `[start:end]`
  - `[start:]`
  - `[:end]`
  - `[:]`
- Examples:
  - `@search((project Inbox and @na and not @done)[0])`:
    - Evaluates the predicates, then returns only the first matching action.
  - `@search(/Inbox//Bugs and @na and not @done[0])`:
    - Restricts to the `Inbox/Bugs` subtree, then returns only the first incomplete `@na` action under that subtree.

Slice semantics:

- Slices are applied per clause after all tag/project/item-path filters:
  - `[index]` → the single action at `index` (0-based) if it exists.
  - `[start:end]` → actions in the half-open range `start...end`.
  - `[start:]` → actions from `start` to the end.
  - `[:end]` / `[:]` → from the beginning to `end` (or all actions).

#### Saved searches and TaskPaper files

- **YAML saved searches**:
  - `~/.local/share/na/saved_searches.yml` values that are plain strings continue to use NA's original search syntax.
  - Values of the form `@search(...)` are parsed using the TaskPaper engine described above and support the full feature set (predicates, boolean logic, item paths, slicing).
- **TaskPaper-embedded saved searches**:
  - Any line in a `.taskpaper` file that matches:
    - `TITLE @search(PARAMS)`
  - is treated as a saved search. `TITLE` becomes the search name, and `PARAMS` is parsed with the same TaskPaper engine. These searches are available via `na saved TITLE` and can coexist with YAML definitions.

#### Supported vs. unsupported TaskPaper features

In summary, NA's TaskPaper support includes:

- Tag predicates with most TaskPaper relations and modifiers.
- `@text` predicates for plain-text search.
- `@done` handling wired into NA's "done" flag.
- `project` equality and exclusions, plus a practical "project" type shortcut.
- Boolean logic with `and`, `or`, `not`, and parentheses.
- Item paths with `/`, `//`, and `*` to scope searches by project hierarchy.
- Result slicing on entire `@search(...)` expressions.
- Integration with `next`, `find`, and `saved` via `@search(...)`, including YAML and TaskPaper-defined saved searches.

The following TaskPaper features are **not** yet implemented:

- Item-path set operations (`union`, `intersect`, `except`).
- Slicing applied directly to individual item-path steps (only whole-expression slicing is currently supported).

Where NA already provided its own search syntax (e.g. `na find`, `na tagged`), TaskPaper searches are additive: you can choose whichever is more convenient for a given query, and `@search(...)` expressions are routed through a common TaskPaper engine so behavior is consistent across commands.

### Usage

```
@cli(bundle exec bin/na help)
```

#### Commands

##### add

Example: `na add This feature @idea I have`

If you run the `add` command with no arguments, you'll be asked for input on the command line.

###### Adding notes

Use the `--note` switch to add a note. If STDIN (piped) input is present when this switch is used, it will be included in the note. A prompt will be displayed for adding additional notes, which will be appended to any STDIN note passed. Press CTRL-d to end editing and save the note.

Notes are not displayed by the `next/tagged/find` commands unless `--notes` is specified.

```
@cli(bundle exec bin/na help add)
```

##### edit

```
@cli(bundle exec bin/na help edit)
```

##### find

Example: `na find cool feature idea`

Unless `--exact` is specified, search is tokenized and combined with AND, so `na find cool feature idea` translates to `cool AND feature AND idea`, matching any string that contains all of the words. To make a token required and others optional, add a `+` before it (e.g. `cool +feature idea` is `(cool OR idea) AND feature`). Wildcards allowed (`*` and `?`), use `--regex` to interpret the search as a regular expression. Use `-v` to invert the results (display non-matching actions only). Searches accept both NA search syntax and TaskPaper search syntax (see [TaskPaper search section](#taskpaper-syntax) above).

```
@cli(bundle exec bin/na help find)
```

##### init, create

```
@cli(bundle exec bin/na help init)
```

##### move

Move an action between projects. Argument is a search term, if left blank a prompt will allow you to enter terms. If no `--to` project is specified, a menu will be shown of projects in the target file.

Examples:

- `na move` (enter a search term, select a file/destination)
- `na move "Bug description"` (find matching action and show a menu of project destinations)
- `na move "Bug description" --to Bugs (move matching action to Bugs project)

```
@cli(bundle exec bin/na help move)
```

##### next, show

Examples:

- `na next` (list all next actions in the current directory)
- `na next -d 3` (list all next actions in the current directory and look for additional files 3 levels deep from there)
- `na next marked2` (show next actions from another directory you've previously used na on)

To see all next actions across all known todos, use `na next "*"`. You can combine multiple arguments to see actions across multiple todos, e.g. `na next marked nvultra`. Filters and search terms accept both NA search syntax and TaskPaper search syntax (see [TaskPaper search section](#taskpaper-syntax) above).

```
@cli(bundle exec bin/na help next)
```

##### plugin

Manage and run external plugins. See also the Plugins section below.

```
@cli(bundle exec bin/na help plugin)
```

###### plugin new

Create a new plugin script (aliases: `n`). Infers shebang by extension or `--language`.

```
@cli(bundle exec bin/na help plugin new)
```

###### plugin edit

Open an existing plugin in your default editor. Prompts if no name is given.

```
@cli(bundle exec bin/na help plugin edit)
```

###### plugin run

Run a plugin on selected actions (aliases: `x`). Supports input/output format flags and filters.

```
@cli(bundle exec bin/na help plugin run)
```

###### plugin enable

Move a plugin from `plugins_disabled` to `plugins` (alias: `e`).

```
@cli(bundle exec bin/na help plugin enable)
```

###### plugin disable

Move a plugin from `plugins` to `plugins_disabled` (alias: `d`).

```
@cli(bundle exec bin/na help plugin disable)
```

##### projects

List all projects in a file. If arguments are provided, they're used to match a todo file from history, otherwise the todo file(s) in the current directory will be used.

```
@cli(bundle exec bin/na help projects)
```

##### saved

The saved command runs saved searches. To save a search, add `--save SEARCH_NAME` to a `find` or `tagged` command. The arguments provided on the command line will be saved to a search file (`/.local/share/na/saved_searches.yml`), with the search named with the SEARCH_NAME parameter. You can then run the search again with `na saved SEARCH_NAME`. Repeating the SEARCH_NAME with a new `find/tagged` command will overwrite the previous definition.

Search names can be partially matched when calling them, so if you have a search named "overdue," you can match it with `na saved over` (shortest match will be used).

Run `na saved` without an argument to list your saved searches. Saved searches preserve whether NA search syntax or TaskPaper search syntax was used, and both syntaxes are supported when defining or running them (see [TaskPaper search section](#taskpaper-syntax) above).

> As a shortcut, if `na` is run with one argument that matches the name of a saved search, it will execute that search, so running `na maybe` is the same as running `na saved maybe`.
<!--JEKYLL{:.tip}-->

```
@cli(bundle exec bin/na help saved)
```

##### scan

Scan a directory tree for todo files and cache them in tdlist.txt. Avoids duplicates and can optionally prune non-existent entries.

Scan reports how many files were added and, if --prune is used, how many were pruned. With --dry-run, it lists the full file paths that would be added and/or pruned.

```
@cli(bundle exec bin/na help scan)
```

##### tagged

Example: `na tagged feature +maybe`.

Separate multiple tags/value comparisons with commas. By default tags are combined with AND, so actions matching all of the tags listed will be displayed. Use `+` to make a tag required and `!` to negate a tag (only display if the action does _not_ contain the tag). When `+` and/or `!` are used, undecorated tokens become optional matches. Use `-v` to invert the search and display all actions that _don't_ match.

You can also perform value comparisons on tags. A value in a TaskPaper tag is added by including it in parenthesis after the tag, e.g. `@due(2022-10-10 05:00)`. You can perform numeric comparisons with `<`, `>`, `<=`, `>=`, `==`, and `!=`. If comparing to a date, you can use natural language, e.g. `na tagged "due<today"`.

To perform a string comparison, you can use `*=` (contains), `^=` (starts with), `$=` (ends with), or `=` (matches). E.g. `na tagged "note*=video"`.

```
@cli(bundle exec bin/na help tagged)
```

##### todos

List all known todo files from history.

```
@cli(bundle exec bin/na help todos)
```

##### update

Example: `na update --in na --archive my cool action`

The above will locate a todo file matching "na" in todo history, find any action matching "my cool action", add a dated @done tag and move it to the Archive project, creating it if needed. If multiple actions are matched, a menu is presented (multi-select if fzf is available).

This command will perform actions (tag, untag, complete, archive, add note, etc.) on existing actions by matching your search text. Arguments will be interpreted as search tokens similar to `na find`. You can use `--exact` and `--regex`, as well as wildcards in the search string. You can also use `--tagged TAG_QUERY` in addition to or instead of a search query.

You can specify a particular todo file using `--file PATH` or any todo from history using `--in QUERY`.

If more than one file is matched, a menu will be presented, multiple selections allowed. If multiple actions match the search within the selected file(s), a menu will be presented. Use the `--all` switch to force operation on all matched tasks, skipping the menu.

> **Note:** When using the `update` command, if you have [fzf](https://github.com/junegunn/fzf) installed, menus for selecting files or actions will support multi-select (tab to mark multiple, return to confirm). If [gum](https://github.com/charmbracelet/gum) is installed, multi-select is also supported (use j/k/x to navigate and mark). If neither is available, a simple prompt is used. This makes it easy to apply updates to multiple actions at once.

Any time an update action is carried out, a backup of the file before modification will be made in the same directory with a `.` prepended and `.bak` appended (e.g. `marked.taskpaper` is copied to `.marked.taskpaper.bak`). Only one undo step is available, but if something goes wrong (and this feature is still experimental, so be wary), you can just copy the ".bak" file back to the original.

###### Marking a task as complete

You can mark an action complete using `--finish`, which will add a dated @done tag to the action. You can also mark it @done and immediately move it to the Archive project using `--archive`.

If you just want the action to stop appearing as a "next action," you can remove the next action tag using `--remove na` (or whatever your next action tag is configured as).

If you want to permanently delete an action, use `--delete` to remove it entirely.

###### Moving between projects

You can specify a new project for an action (moving it) with `--proj PROJECT_PATH`. A project path is hierarchical, with each level separated by a colon or slash. If the project path provided roughly matches an existing project, e.g. "mark:bug" would match "Marked:Bugs", then that project will be used. If no match is found, na will offer to generate a new project/hierarchy for the path provided. Strings will be exact but the first letter will be uppercased.

###### Adding notes

Use the `--note` switch to add a note. If STDIN (piped) input is present when this switch is used, it will be included in the note. A prompt will be displayed for adding additional notes, which will be appended to any STDIN note passed. Press CTRL-d to end editing and save the note.

Notes are not displayed by the `next/tagged/find` commands unless `--notes` is specified.

See the help output for a list of all available actions.

```
@cli(bundle exec bin/na help update)
```

##### changelog

View recent changes with `na changelog` or `na changes`.

```
@cli(bundle exec bin/na help changelog)
```

##### complete

Mark an action as complete, shortcut for `na update --finish`.

```
@cli(bundle exec bin/na help complete)
```

##### archive

Mark an action as complete and move to archive, shortcut for `na update --archive`.

```
@cli(bundle exec bin/na help archive)
```

##### tag

Add, remove, or modify tags.

Use `na tag TAGNAME --[search|tagged] SEARCH_STRING` to add a tag to matching action (use `--all` to apply to all matching actions). If you use `!TAGNAME` it will remove that tag (regardless of value). To change the value of an existing tag (or add it if it doesn't exist), use `~TAGNAME(NEW VALUE)`.

```
@cli(bundle exec bin/na help tag)
```

##### undo

Undoes the last file change resulting from an add or update command. If no argument is given, it undoes whatever the last change in history was. If an argument is provided, it's used to match against the change history, finding a specific file to restore from backup.

Only the most recent change can be undone.

```
@cli(bundle exec bin/na help undo)
```

### Configuration

Global options such as todo extension and default next action tag can be stored permanently by using the `na initconfig` command. Run na with the global options you'd like to set, and add `initconfig` at the end of the command. A file will be written to `~/.na.rc`. You can edit this manually, or just update it using the `initconfig --force` command to overwrite it with new settings.

> You can see all available global options by running `na help`.
<!--JEKYLL{:.tip}-->

Example: `na --ext md --na_tag next initconfig --force`

When this command is run, it doesn't include options for subcommands, but inserts placeholders for them. If you want to permanently set an option for a subcommand, you'll need to edit `~/.na.rc`. For example, if you wanted the `next` command to always recurse 2 levels deep, you could edit it to look like this:

```yaml
---
:ext: taskpaper
:na_tag: na
:d: 1
commands:
  :next:
    :depth: 2
  :add: {}
  :find: {}
  :tagged: {}
```

Note that I created a new YAML dictionary inside of the `:next:` command, and added a `:depth:` key that matches the setting I want to make permanent.

> **WARNING** Don't touch most of the settings at the top of the auto-generated file. Setting any of them to true will alter the way na interprets the commands you're running. Most of those options are there for backwards compatibility with the bash version of this tool and will eventually be removed.
<!--JEKYLL{:.warn}-->

#### Working with a single global file

na is designed to work with one or more TaskPaper files in each project directory, but if you prefer to use a single global TaskPaper file, you can add `--file PATH` as a global option and specify a single file. This will bypass the detection of any files in the current directory. Make it permanent by including the `--file` flag when running `initconfig`.

When using a global file, you can additionally include `--cwd_as TYPE` to determine whether the current working directory is used as a tag or a project (default is neither). If you add `--cwd_as tag` to the global options (before the command), the last element of the current working directory will be appended as an @tag (e.g. if you're in ~/Code/project/doing, the action would be tagged @doing). If you use `--cwd_as project` the action will be put into a project with the same name as the current directory (e.g. `Doing:` from the previous example).

#### Add tasks at the end of a project

By default, tasks are added at the top of the target project (Inbox, etc.). If you prefer new tasks to go at the end of the project by default, include `--add_at end` as a global option when running `initconfig`.

### Prompt Hooks

You can add a prompt command to your shell to have na automatically list your next actions when you `cd` into a directory. To install a prompt command for your current shell, just run `na prompt install`. It works with Zsh, Bash, and Fish. If you'd rather make the changes to your startup file yourself, run `na prompt show` to get the hook and instructions printed out for copying.

If you're using a single global file, you'll need `--cwd_as` to be `tag` or `project` for a prompt command to work. na will detect which system you're using and provide a prompt command that lists actions based on the current directory using either project or tag.

> You can also get output for shells other than the one you're currently using by adding "bash", "zsh", or "fish" to the show or install command.
<!--JEKYLL{:.tip}-->

> You can add `-r` to any of the calls to na to automatically recurse 3 directories deep, or just set the depth config permanently
<!--JEKYLL{:.tip}-->

After installing a hook, you'll need to close your terminal and start a new session to initialize the new commands.

### Time tracking

`na` supports tracking elapsed time between a start and finish for actions using `@started(YYYY-MM-DD HH:MM)` and `@done(YYYY-MM-DD HH:MM)` tags. Durations are not stored; they are calculated on the fly from these tags.

- Add/Finish/Update flags:
  - `--started TIME` set a start time when creating or finishing an item
  - `--end TIME` (alias `--finished`) set a done time
  - `--duration DURATION` backfill start time from the provided end time
  - All flags accept natural language (via Chronic) and shorthand: `30m ago`, `-2h`, `2h30m`, `2:30 ago`, `yesterday 5pm`

Examples:

```bash
na add --started "30 minutes ago" "Investigate bug"
na complete --finished now --duration 2h30m "Investigate bug"
na update --started "yesterday 3pm" --end "yesterday 5:15pm" "Investigate bug"
```

- Display flags (next/tagged):
  - `--times` show per‑action durations and a grand total (implies `--done`)
  - `--human` format durations as human‑readable text instead of `DD:HH:MM:SS`
  - `--only_timed` show only actions that have both `@started` and `@done` (implies `--times --done`)
  - `--only_times` output only the totals section (no action lines; implies `--times --done`)
  - `--json_times` output a JSON object with timed items, per‑tag totals, and overall total (implies `--times --done`)

Example outputs:

```bash
# Per‑action durations appended and totals table
na next --times --human

# Only totals table (Markdown), no action lines
na tagged "tag*=bug" --only_times

# JSON for scripting
na next --json_times > times.json
```

Notes:

- Any newly added or edited action text is scanned for natural‑language values in `@started(...)`/`@done(...)` and normalized to `YYYY‑MM‑DD HH:MM`.
- The color of durations in output is configurable via the theme key `duration` (defaults to `{y}`).

### Plugins

NA supports a plugin system that allows you to run external scripts to transform or process actions. Plugins are stored in `~/.local/share/na/plugins` and can be written in any language with a shebang.

#### Getting Started

The first time NA runs, it will create the plugins directory with a README and two sample plugins:
- `Add Foo.py` - Adds a `@foo` tag with a timestamp
- `Add Bar.sh` - Adds a `@bar` tag

You can delete or modify these sample plugins as needed.

#### Running Plugins

You can manage and run plugins using subcommands under `na plugin`:

- `new`/`n`: scaffold a new plugin script
- `edit`: open an existing plugin
- `run`/`x`: run a plugin against selected actions
- `enable`/`e`: move from disabled to enabled
- `disable`/`d`: move from enabled to disabled

Plugins are executed with actions on STDIN and must return actions on STDOUT. Display commands can still pipe through plugins via `--plugin`, which only affects STDOUT (no writes).

#### Plugin Metadata

Plugins can specify their behavior in a metadata block after the shebang:

```bash
#!/usr/bin/env python3
# name: My Plugin
# input: json
# output: json
```

Available metadata keys (case-insensitive):
- `input`: Input format (`json`, `yaml`, `csv`, `text`)
- `output`: Output format
- `name` or `title`: Display name (defaults to filename)

#### Input/Output Formats

Plugins accept and return action data. Use `--input` and `--output` flags to override metadata:

```bash
na plugin MY_PLUGIN --input text --output json --divider "||"
```

**JSON/YAML Schema:**
```json
[
  {
    "file_path": "todo.taskpaper",
    "line": 15,
    "parents": ["Project", "Subproject"],
    "text": "- Action text @tag(value)",
    "note": "Note content",
    "tags": [
      { "name": "tag", "value": "value" }
    ]
  }
]
```

**Text Format:**
```
ACTION||ARGS||file_path:line||parents||text||note||tags
```

Default divider is `||` (configurable with `--divider`).
- `parents`: `Parent>Child>Leaf`
- `tags`: `name(value);name;other(value)`

If the first token isn’t a known action, it’s treated as `file_path:line` and the action defaults to UPDATE.

#### Actions

Plugins may return an optional ACTION with arguments. Supported (case-insensitive):
- UPDATE (default; replace text/note/tags/parents)
- DELETE
- COMPLETE/FINISH
- RESTORE/UNFINISH
- ARCHIVE
- ADD_TAG (args: one or more tags)
- DELETE_TAG/REMOVE_TAG (args: one or more tags)
- MOVE (args: target project path)

#### Plugin Behavior

**On `update` or `plugin` command:**
- Plugins can modify text, notes, tags, and parents
- Changing `parents` will move the action to the new project location
- `file_path` and `line` cannot be changed

**On display commands (`next`, `tagged`, `find`):**
- Plugins only transform STDOUT (no file writes)
- Use returned text/note/tags/parents for rendering
- Parent changes affect display but not file structure

#### Override Formats

You can override plugin defaults with flags on any command that supports `--plugin`:
```bash
na next --plugin FOO --input csv --output text
```

[fzf]: https://github.com/junegunn/fzf
[gum]: https://github.com/charmbracelet/gum
[donate]: http://brettterpstra.com/donate/
[github]: https://github.com/ttscoff/na_gem/

<!--GITHUB-->
PayPal link: [paypal.me/ttscoff](https://paypal.me/ttscoff)

## Changelog

See [CHANGELOG.md](https://github.com/ttscoff/na_gem/blob/master/CHANGELOG.md)
<!--END GITHUB--><!--END README-->
