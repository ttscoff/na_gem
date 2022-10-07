# na

[![Gem](https://img.shields.io/gem/v/na.svg)](https://rubygems.org/gems/na)
[![Travis](https://app.travis-ci.com/ttscoff/na_gem.svg?branch=main)](https://travis-ci.org/makenew/na_gem)
[![GitHub license](https://img.shields.io/github/license/ttscoff/na_gem.svg)](./LICENSE.txt)

**A command line tool for adding and listing per-project todos.**

_If you're one of the rare people like me who find this useful, feel free to
[buy me some coffee][donate]._

The current version of `na` is 1.1.22
.

`na` ("next action") is a command line tool designed to make it easy to see what your next actions are for any project, right from the command line. It works with TaskPaper-formatted files (but any plain text format will do), looking for `@na` tags (or whatever you specify) in todo files in your current folder. 

Used with Taskpaper files, it can add new todo items quickly from the command line, automatically tagging them as next actions.

It can also auto-display next actions when you enter a project directory, automatically locating any todo files and listing their next actions when you `cd` to the project (optionally recursive). See the [Prompt Hooks](#prompt-hooks) section for details.

### Installation

Assuming you have Ruby and RubyGems installed, you can just run `gem install na`. If you run into errors, use `sudo gem install na`.

If you're using Homebrew, you have the option to install via [brew-gem](https://github.com/sportngin/brew-gem):

    brew install brew-gem
    brew gem install na

If you don't have Ruby/RubyGems, you can install them pretty easily with Homebrew, rvm, or asdf. I can't swear this tool is worth the time, but there _are_ a lot of great gems available...



### Features

You can list next actions in files in the current directory by typing `na`. By default, `na` looks for `*.taskpaper` files and extracts items tagged `@na` and not `@done`. All of these can be changed in the configuration.

#### Easy matching

`na` features intelligent project matching. Every time it locates a todo file, it adds the project to the database. Once a project is recorded, you can list its actions by using any portion of the parent directories or file names. If your project is in `~/Sites/dev/markedapp`, you could quickly list its next actions by typing `na next dev/mark`. Creat paths by separating with / or :, separate multiple queries with spaces. na will always look for the shortest match for a path.

#### Recursion

`na` can also recurse subdirectories to find all todo files in child folders as well. Use the `-d X` to search X levels deep from the current directory. `na -r` with no arguments will recurse from your current location, looking for todo files 3 directories deep.

#### Adding todos

You can also quickly add todo items from the command line with the `add` subcommand. The script will look for a file in the current directory with a `.taskpaper` extension (configurable). 

If found, it will try to locate an `Inbox:` project, or create one if it doesn't exist. Any arguments after `add` will be combined to create a new task in TaskPaper format. They will automatically be assigned as next actions (tagged `@na`) and will show up when `na` lists the tasks for the project.

### Usage

```
NAME
    na - Add and list next actions for the current project

SYNOPSIS
    na [global options] command [command options] [arguments...]

VERSION
    1.1.22

GLOBAL OPTIONS
    -a, --[no-]add          - Add a next action (deprecated, for backwards compatibility)
    -d, --depth=DEPTH       - Recurse to depth (default: 1)
    --[no-]debug            - Display verbose output
    --ext=EXT               - File extension to consider a todo file (default: taskpaper)
    --help                  - Show this message
    -n, --note              - Prompt for additional notes (deprecated, for backwards compatibility)
    -p, --priority=PRIORITY - Set a priority 0-5 (deprecated, for backwards compatibility) (default: none)
    -r, --[no-]recurse      - Recurse 3 directories deep (deprecated, for backwards compatability)
    -t, --na_tag=TAG        - Tag to consider a next action (default: na)
    --version               - Display the program version

COMMANDS
    add          - Add a new next action
    edit         - Open a todo file in the default editor
    find, grep   - Find actions matching a search pattern
    help         - Shows a list of commands or help for one command
    init, create - Create a new todo file in the current directory
    initconfig   - Initialize the config file using current global options
    next, show   - Show next actions
    prompt       - Show or install prompt hooks for the current shell
    tagged       - Find actions matching a tag
    todos        - Show list of known todo files
```

#### Commands

##### add

Example: `na add This feature @idea I have`

If you run the `add` command with no arguments, you'll be asked for input on the command line.

```
NAME
    add - Add a new next action

SYNOPSIS

    na [global options] add [command options] ACTION

DESCRIPTION
    Provides an easy way to store todos while you work. Add quick   reminders and (if you set up Prompt Hooks) they'll automatically display   next time you enter the directory.   If multiple todo files are found in the current directory, a menu will   allow you to pick to which file the action gets added. 

COMMAND OPTIONS
    -d, --depth=DEPTH   - Search for files X directories deep (default: 1)
    -f, --file=PATH     - Specify the file to which the task should be added (default: none)
    -n, --note          - Prompt for additional notes
    -p, --priority=PRIO - Add a priority level 1-5 (default: 0)
    -t, --tag=TAG       - Use a tag other than the default next action tag (default: none)
    --to=PROJECT        - Add action to specific project (default: Inbox)
    -x                  - Don't add next action tag to new entry

EXAMPLES

    # Add a new action to the Inbox, including a tag
    na add "A cool feature I thought of @idea"

    # Add a new action to the Inbox, set its @priority to 4, and prompt for an additional note
    na add "A bug I need to fix" -p 4 -n
```

##### edit

```
NAME
    edit - Open a todo file in the default editor

SYNOPSIS

    na [global options] edit [command options] 

DESCRIPTION
    Let the system choose the defualt, (e.g. TaskPaper), or specify a command line utility (e.g. vim).              If more than one todo file is found, a menu is displayed. 

COMMAND OPTIONS
    -a, --app=EDITOR    - Specify a Mac app (default: none)
    -d, --depth=DEPTH   - Recurse to depth (default: 1)
    -e, --editor=EDITOR - Specify an editor CLI (default: none)

EXAMPLES

    # Open the main todo file in the default editor
    na edit

    # Display a menu of all todo files three levels deep from the
               current directory, open selection in vim.
    na edit -d 3 -a vim
```

##### find

Example: `na find cool feature idea`

Unless `--exact` is specified, search is tokenized and combined with AND, so `na find cool feature idea` translates to `cool AND feature AND idea`, matching any string that contains all of the words. To make a token required and others optional, add a `+` before it (e.g. `cool +feature idea` is `(cool OR idea) AND feature`). Wildcards allowed (`*` and `?`), use `--regex` to interpret the search as a regular expression. Use `-v` to invert the results (display non-matching actions only).

```
NAME
    find - Find actions matching a search pattern

SYNOPSIS

    na [global options] find [command options] PATTERN

DESCRIPTION
    Search tokens are separated by spaces. Actions matching all tokens in the pattern will be shown   (partial matches allowed). Add a + before a token to make it required, e.g. `na find +feature +maybe` 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: none)
    -e, --regex                            - Interpret search pattern as regular expression
    --in=TODO_PATH                         - Show actions from a specific todo file in history. May use wildcards (* and ?) (default: none)
    -o, --or                               - Combine search tokens with OR, displaying actions matching ANY of the terms
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    -v, --invert                           - Show actions not matching search pattern
    -x, --exact                            - Match pattern exactly

EXAMPLES

    # Find all actions containing feature, idea, and swift
    na find feature idea swift

    # Find all actions containing the exact text "feature idea"
    na find -x feature idea
```

##### init, create

```
NAME
    init - Create a new todo file in the current directory

SYNOPSIS

    na [global options] init [PROJECT]

EXAMPLES

    # Generate a new todo file, prompting for project name
    na init

    # Generate a new todo for a project called warpspeed
    na init warpspeed
```

##### next, show

Examples:

- `na next` (list all next actions in the current directory)
- `na next -d 3` (list all next actions in the current directory and look for additional files 3 levels deep from there)
- `na next marked2` (show next actions from another directory you've previously used na on)

```
NAME
    next - Show next actions

SYNOPSIS

    na [global options] next [command options] [QUERY]

DESCRIPTION
    Next actions are actions which contain the next action tag (default @na),   do not contain @done, and are not in the Archive project.   Arguments will target a todo file from history, whether it's in the current   directory or not. Todo file queries can include path components separated by /   or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma). 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: 2)
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    -t, --tag=TAG                          - Alternate tag to search for (default: none)

EXAMPLES

    # display the next actions from any todo files in the current directory
    na next

    # display the next actions from the current directory, traversing 3 levels deep
    na next -d 3

    # display next actions for a project you visited in the past
    na next marked
```

##### tagged

Example: `na tagged feature +maybe`.

Separate multiple tags with spaces or commas. By default tags are combined with AND, so actions matching all of the tags listed will be displayed. Use `+` to make a tag required and `!` to negate a tag (only display if the action does _not_ contain the tag). When `+` and/or `!` are used, undecorated tokens become optional matches. Use `-v` to invert the search and display all actions that _don't_ match.

```
NAME
    next - Show next actions

SYNOPSIS

    na [global options] next [command options] [QUERY]

DESCRIPTION
    Next actions are actions which contain the next action tag (default @na),   do not contain @done, and are not in the Archive project.   Arguments will target a todo file from history, whether it's in the current   directory or not. Todo file queries can include path components separated by /   or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma). 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: 2)
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    -t, --tag=TAG                          - Alternate tag to search for (default: none)

EXAMPLES

    # display the next actions from any todo files in the current directory
    na next

    # display the next actions from the current directory, traversing 3 levels deep
    na next -d 3

    # display next actions for a project you visited in the past
    na next marked
```

### Configuration

Global options such as todo extension and default next action tag can be stored permanently by using the `na initconfig` command. Run na with the global options you'd like to set, and add `initconfig` at the end of the command. A file will be written to `~/.na.rc`. You can edit this manually, or just update it using the `initconfig --force` command to overwrite it with new settings.

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


### Prompt Hooks

You can add a prompt command to your shell to have na automatically list your next actions when you `cd` into a directory. To install a prompt command for your current shell, just run `na prompt install`. It works with Zsh, Bash, and Fish. If you'd rather make the changes to your startup file yourself, run `na prompt show` to get the hook and instructions printed out for copying.

> You can also get output for shells other than the one you're currently using by adding "bash", "zsh", or "fish" to the show or install command.


> You can add `-r` to any of the calls to na to automatically recurse 3 directories deep, or just set the depth config permanently


After installing a hook, you'll need to close your terminal and start a new session to initialize the new commands.


### Misc

If you have [gum][] installed, na will use it for command line input when adding tasks and notes.

[gum]: https://github.com/charmbracelet/gum
[donate]: http://brettterpstra.com/donate/
[github]: https://github.com/ttscoff/na_gem/


PayPal link: [paypal.me/ttscoff](https://paypal.me/ttscoff)

## Changelog

See [CHANGELOG.md](https://github.com/ttscoff/na_gem/blob/master/CHANGELOG.md)
