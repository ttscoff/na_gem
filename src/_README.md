<!--README--><!--GITHUB--># na

[![Gem](https://img.shields.io/gem/v/na.svg)](https://rubygems.org/gems/na)
[![Travis](https://app.travis-ci.com/ttscoff/na_gem.svg?branch=main)](https://travis-ci.org/makenew/na_gem)
[![GitHub license](https://img.shields.io/github/license/ttscoff/na_gem.svg)](./LICENSE.txt)<!--END GITHUB-->

**A command line tool for adding and listing per-project todos.**

_If you're one of the rare people like me who find this useful, feel free to
[buy me some coffee][donate]._

The current version of `na` is <!--VER-->1.2.29<!--END VER-->.

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

Unless `--exact` is specified, search is tokenized and combined with AND, so `na find cool feature idea` translates to `cool AND feature AND idea`, matching any string that contains all of the words. To make a token required and others optional, add a `+` before it (e.g. `cool +feature idea` is `(cool OR idea) AND feature`). Wildcards allowed (`*` and `?`), use `--regex` to interpret the search as a regular expression. Use `-v` to invert the results (display non-matching actions only).

```
@cli(bundle exec bin/na help find)
```

##### init, create

```
@cli(bundle exec bin/na help init)
```

##### next, show

Examples:

- `na next` (list all next actions in the current directory)
- `na next -d 3` (list all next actions in the current directory and look for additional files 3 levels deep from there)
- `na next marked2` (show next actions from another directory you've previously used na on)

To see all next actions across all known todos, use `na next "*"`. You can combine multiple arguments to see actions across multiple todos, e.g. `na next marked nvultra`.

```
@cli(bundle exec bin/na help next)
```

##### projects

List all projects in a file. If arguments are provided, they're used to match a todo file from history, otherwise the todo file(s) in the current directory will be used.

```
@cli(bundle exec bin/na help projects)
```

##### saved

The saved command runs saved searches. To save a search, add `--save SEARCH_NAME` to a `find` or `tagged` command. The arguments provided on the command line will be saved to a search file (`/.local/share/na/saved_searches.yml`), with the search named with the SEARCH_NAME parameter. You can then run the search again with `na saved SEARCH_NAME`. Repeating the SEARCH_NAME with a new `find/tagged` command will overwrite the previous definition.

Search names can be partially matched when calling them, so if you have a search named "overdue," you can match it with `na saved over` (shortest match will be used).

Run `na saved` without an argument to list your saved searches.

> As a shortcut, if `na` is run with one argument that matches the name of a saved search, it will execute that search, so running `na maybe` is the same as running `na saved maybe`.
<!--JEKYLL{:.tip}-->

```
@cli(bundle exec bin/na help saved)
```

##### tagged

Example: `na tagged feature +maybe`.

Separate multiple tags/value comparisons with commas. By default tags are combined with AND, so actions matching all of the tags listed will be displayed. Use `+` to make a tag required and `!` to negate a tag (only display if the action does _not_ contain the tag). When `+` and/or `!` are used, undecorated tokens become optional matches. Use `-v` to invert the search and display all actions that _don't_ match.

You can also perform value comparisons on tags. A value in a TaskPaper tag is added by including it in parenthesis after the tag, e.g. `@due(2022-10-10 05:00)`. You can perform numeric comparisons with `<`, `>`, `<=`, `>=`, `==`, and `!=`. If comparing to a date, you can use natural language, e.g. `na tagged "due<today"`.

To perform a string comparison, you can use `*=` (contains), `^=` (starts with), `$=` (ends with), or `=` (matches). E.g. `na tagged "note*=video"`.

```
@cli(bundle exec bin/na help show)
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

If more than one file is matched, a menu will be presented, multiple selections allowed. If multiple actions match the search within the selected file(s), a menu will be presented. If you have fzf installed, you can select one action to update with return, or use tab to mark multiple tasks to which the action will be applied. With gum you can use j, k, and x to mark multiple actions. Use the `--all` switch to force operation on all matched tasks, skipping the menu.

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


[fzf]: https://github.com/junegunn/fzf
[gum]: https://github.com/charmbracelet/gum
[donate]: http://brettterpstra.com/donate/
[github]: https://github.com/ttscoff/na_gem/

<!--GITHUB-->
PayPal link: [paypal.me/ttscoff](https://paypal.me/ttscoff)

## Changelog

See [CHANGELOG.md](https://github.com/ttscoff/na_gem/blob/master/CHANGELOG.md)
<!--END GITHUB--><!--END README-->
