# na

[![Gem](https://img.shields.io/gem/v/na.svg)](https://rubygems.org/gems/na)
[![Travis](https://app.travis-ci.com/ttscoff/na_gem.svg?branch=main)](https://travis-ci.org/makenew/na_gem)
[![GitHub license](https://img.shields.io/github/license/ttscoff/na_gem.svg)](./LICENSE.txt)

**A command line tool for adding and listing per-project todos.**

_If you're one of the rare people like me who find this useful, feel free to
[buy me some coffee][donate]._

The current version of `na` is 1.2.27
.

`na` ("next action") is a command line tool designed to make it easy to see what your next actions are for any project, right from the command line. It works with TaskPaper-formatted files (but any plain text format will do), looking for `@na` tags (or whatever you specify) in todo files in your current folder. 

Used with Taskpaper files, it can add new action items quickly from the command line, automatically tagging them as next actions. It can also mark actions as completed, delete them, archive them, and move them between projects.

It can also auto-display next actions when you enter a project directory, automatically locating any todo files and listing their next actions when you `cd` to the project (optionally recursive). See the [Prompt Hooks](#prompt-hooks) section for details.

### Installation

Assuming you have Ruby and RubyGems installed, you can just run `gem install na`. If you run into errors, try `gem install --user-install na`, or use `sudo gem install na`.

If you're using Homebrew, you have the option to install via [brew-gem](https://github.com/sportngin/brew-gem):

    brew install brew-gem
    brew gem install na

If you don't have Ruby/RubyGems, you can install them pretty easily with Homebrew, rvm, or asdf. I can't swear this tool is worth the time, but there _are_ a lot of great gems available...



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
NAME
    na - Add and list next actions for the current project

SYNOPSIS
    na [global options] command [command options] [arguments...]

VERSION
    1.2.27

GLOBAL OPTIONS
    -a, --add               - Add a next action (deprecated, for backwards compatibility)
    --add_at=POSITION       - Add all new/moved entries at [s]tart or [e]nd of target project (default: start)
    --[no-]color            - Colorize output (default: enabled)
    --cwd_as=TYPE           - Use current working directory as [p]roject, [t]ag, or [n]one (default: none)
    -d, --depth=DEPTH       - Recurse to depth (default: 3)
    --[no-]debug            - Display verbose output
    --ext=EXT               - File extension to consider a todo file (default: taskpaper)
    -f, --file=PATH         - Use a single file as global todo, use initconfig to make permanent (default: none)
    --help                  - Show this message
    -n, --note              - Prompt for additional notes (deprecated, for backwards compatibility)
    -p, --priority=PRIORITY - Set a priority 0-5 (deprecated, for backwards compatibility) (default: none)
    -r, --[no-]recurse      - Recurse 3 directories deep (deprecated, for backwards compatability)
    -t, --na_tag=TAG        - Tag to consider a next action (default: na)
    --template=PATH         - Provide a template for new/blank todo files, use initconfig to make permanent (default: none)
    --version               - Display the program version

COMMANDS
    add                - Add a new next action
    archive            - Mark an action as @done and archive
    changes, changelog - Display the changelog
    complete, finish   - Find and mark an action as @done
    edit               - Open a todo file in the default editor
    find, grep         - Find actions matching a search pattern
    help               - Shows a list of commands or help for one command
    init, create       - Create a new todo file in the current directory
    initconfig         - Initialize the config file using current global options
    next, show         - Show next actions
    projects           - Show list of projects for a file
    prompt             - Show or install prompt hooks for the current shell
    saved              - Execute a saved search
    tagged             - Find actions matching a tag
    todos              - Show list of known todo files
    update             - Update an existing action
```

#### Commands

##### add

Example: `na add This feature @idea I have`

If you run the `add` command with no arguments, you'll be asked for input on the command line.

###### Adding notes

Use the `--note` switch to add a note. If STDIN (piped) input is present when this switch is used, it will be included in the note. A prompt will be displayed for adding additional notes, which will be appended to any STDIN note passed. Press CTRL-d to end editing and save the note. 

Notes are not displayed by the `next/tagged/find` commands unless `--notes` is specified.

```
NAME
    add - Add a new next action

SYNOPSIS

    na [global options] add [command options] ACTION

DESCRIPTION
    Provides an easy way to store todos while you work. Add quick reminders and (if you set up Prompt Hooks) they'll automatically display next time you enter the directory. If multiple todo files are found in the current directory, a menu will allow you to pick to which file the action gets added. 

COMMAND OPTIONS
    --at=POSITION                   - Add task at [s]tart or [e]nd of target project (default: none)
    -d, --depth=DEPTH               - Search for files X directories deep (default: 1)
    -f, --file=PATH                 - Specify the file to which the task should be added (default: none)
    --finish, --done                - Mark task as @done with date
    --in, --todo=TODO_FILE          - Add to a known todo file, partial matches allowed (default: none)
    -n, --note                      - Prompt for additional notes. STDIN input (piped) will be treated as a note if present.
    -p, --priority=PRIO             - Add a priority level 1-5 (default: 0)
    -t, --tag=TAG                   - Use a tag other than the default next action tag (default: none)
    --to, --project, --proj=PROJECT - Add action to specific project (default: Inbox)
    -x                              - Don't add next action tag to new entry

EXAMPLES

    # Add a new action to the Inbox, including a tag
    na add "A cool feature I thought of @idea"

    # Add a new action to the Inbox, set its @priority to 4, and prompt for an additional note.
    na add "A bug I need to fix" -p 4 -n

    # A parenthetical at the end of an action is interpreted as a note
    na add "An action item (with a note)"
```

##### edit

```
NAME
    edit - Open a todo file in the default editor

SYNOPSIS

    na [global options] edit [command options] 

DESCRIPTION
    Let the system choose the defualt, (e.g. TaskPaper), or specify a command line utility (e.g. vim).            If more than one todo file is found, a menu is displayed. 

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
    Search tokens are separated by spaces. Actions matching all tokens in the pattern will be shown (partial matches allowed). Add a + before a token to make it required, e.g. `na find +feature +maybe`, add a - or ! to ignore matches containing that token. 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: none)
    --[no-]done                            - Include @done actions
    -e, --regex                            - Interpret search pattern as regular expression
    --in=TODO_PATH                         - Show actions from a specific todo file in history. May use wildcards (* and ?) (default: none)
    --nest                                 - Output actions nested by file
    --[no-]notes                           - Include notes in output
    -o, --or                               - Combine search tokens with OR, displaying actions matching ANY of the terms
    --omnifocus                            - Output actions nested by file and project
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    --save=TITLE                           - Save this search for future use (default: none)
    --tagged=TAG                           - Match actions containing tag. Allows value comparisons (may be used more than once, default: none)
    -v, --invert                           - Show actions not matching search pattern
    -x, --exact                            - Match pattern exactly

EXAMPLES

    # Find all actions containing feature, idea, and swift
    na find feature idea swift

    # Find all actions containing feature and idea but NOT swift
    na find feature idea -swift

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

To see all next actions across all known todos, use `na next "*"`. You can combine multiple arguments to see actions across multiple todos, e.g. `na next marked nvultra`.

```
NAME
    next - Show next actions

SYNOPSIS

    na [global options] next [command options] [QUERY]

DESCRIPTION
    Next actions are actions which contain the next action tag (default @na), do not contain @done, and are not in the Archive project. Arguments will target a todo file from history, whether it's in the current directory or not. Todo file queries can include path components separated by / or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma). 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: none)
    --[no-]done                            - Include @done actions
    --exact                                - Search query is exact text match (not tokens)
    --in, --todo=TODO_FILE                 - Display matches from a known todo file (may be used more than once, default: none)
    --nest                                 - Output actions nested by file
    --[no-]notes                           - Include notes in output
    --omnifocus                            - Output actions nested by file and project
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    --regex                                - Search query is regular expression
    --search=QUERY                         - Filter results using search terms (may be used more than once, default: none)
    -t, --tag=TAG                          - Alternate tag to search for (default: none)
    --tagged=TAG                           - Match actions containing tag. Allows value comparisons (may be used more than once, default: none)

EXAMPLES

    # display the next actions from any todo files in the current directory
    na next

    # display the next actions from the current directory, traversing 3 levels deep
    na next -d 3

    # display next actions for a project you visited in the past
    na next marked
```

##### projects

List all projects in a file. If arguments are provided, they're used to match a todo file from history, otherwise the todo file(s) in the current directory will be used.

```
NAME
    projects - Show list of projects for a file

SYNOPSIS

    na [global options] projects [command options] [QUERY]

DESCRIPTION
    Arguments will be interpreted as a query for a known todo file, fuzzy matched. Separate directories with /, :, or a space, e.g. `na projects code/marked` 

COMMAND OPTIONS
    -d, --depth=DEPTH - Search for files X directories deep (default: 1)
    -p, --paths       - Output projects as paths instead of hierarchy
```

##### saved

The saved command runs saved searches. To save a search, add `--save SEARCH_NAME` to a `find` or `tagged` command. The arguments provided on the command line will be saved to a search file (`/.local/share/na/saved_searches.yml`), with the search named with the SEARCH_NAME parameter. You can then run the search again with `na saved SEARCH_NAME`. Repeating the SEARCH_NAME with a new `find/tagged` command will overwrite the previous definition.

Search names can be partially matched when calling them, so if you have a search named "overdue," you can match it with `na saved over` (shortest match will be used).

Run `na saved` without an argument to list your saved searches.

> As a shortcut, if `na` is run with one argument that matches the name of a saved search, it will execute that search, so running `na maybe` is the same as running `na saved maybe`.


```
NAME
    saved - Execute a saved search

SYNOPSIS

    na [global options] saved [command options] [SEARCH_TITLE]

DESCRIPTION
    Run without argument to list saved searches 

COMMAND OPTIONS
    -d, --delete - Delete the specified search definition
    -e, --edit   - Open the saved search file in $EDITOR

EXAMPLES

    na tagged "+maybe,+priority<=3" --save maybelater

    na saved maybelater

    na saved maybe

    na maybe

    na saved
```

##### tagged

Example: `na tagged feature +maybe`.

Separate multiple tags/value comparisons with commas. By default tags are combined with AND, so actions matching all of the tags listed will be displayed. Use `+` to make a tag required and `!` to negate a tag (only display if the action does _not_ contain the tag). When `+` and/or `!` are used, undecorated tokens become optional matches. Use `-v` to invert the search and display all actions that _don't_ match.

You can also perform value comparisons on tags. A value in a TaskPaper tag is added by including it in parenthesis after the tag, e.g. `@due(2022-10-10 05:00)`. You can perform numeric comparisons with `<`, `>`, `<=`, `>=`, `==`, and `!=`. If comparing to a date, you can use natural language, e.g. `na tagged "due<today"`.

To perform a string comparison, you can use `*=` (contains), `^=` (starts with), `$=` (ends with), or `=` (matches). E.g. `na tagged "note*=video"`.

```
NAME
    next - Show next actions

SYNOPSIS

    na [global options] next [command options] [QUERY]

DESCRIPTION
    Next actions are actions which contain the next action tag (default @na), do not contain @done, and are not in the Archive project. Arguments will target a todo file from history, whether it's in the current directory or not. Todo file queries can include path components separated by / or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma). 

COMMAND OPTIONS
    -d, --depth=DEPTH                      - Recurse to depth (default: none)
    --[no-]done                            - Include @done actions
    --exact                                - Search query is exact text match (not tokens)
    --in, --todo=TODO_FILE                 - Display matches from a known todo file (may be used more than once, default: none)
    --nest                                 - Output actions nested by file
    --[no-]notes                           - Include notes in output
    --omnifocus                            - Output actions nested by file and project
    --proj, --project=PROJECT[/SUBPROJECT] - Show actions from a specific project (default: none)
    --regex                                - Search query is regular expression
    --search=QUERY                         - Filter results using search terms (may be used more than once, default: none)
    -t, --tag=TAG                          - Alternate tag to search for (default: none)
    --tagged=TAG                           - Match actions containing tag. Allows value comparisons (may be used more than once, default: none)

EXAMPLES

    # display the next actions from any todo files in the current directory
    na next

    # display the next actions from the current directory, traversing 3 levels deep
    na next -d 3

    # display next actions for a project you visited in the past
    na next marked
```

##### todos

List all known todo files from history.

```
NAME
    todos - Show list of known todo files

SYNOPSIS

    na [global options] todos [QUERY]

DESCRIPTION
    Arguments will be interpreted as a query against which the list of todos will be fuzzy matched. Separate directories with /, :, or a space, e.g. `na todos code/marked`
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
NAME
    update - Update an existing action

SYNOPSIS

    na [global options] update [command options] ACTION

DESCRIPTION
    Provides an easy way to complete, prioritize, and tag existing actions. If multiple todo files are found in the current directory, a menu will allow you to pick which file to act on. 

COMMAND OPTIONS
    -a, --archive                   - Add a @done tag to action and move to Archive
    --all                           - Act on all matches immediately (no menu)
    --at=POSITION                   - When moving task, add at [s]tart or [e]nd of target project (default: none)
    -d, --depth=DEPTH               - Search for files X directories deep (default: 1)
    --delete                        - Delete an action
    --[no-]done                     - Include @done actions
    -e, --regex                     - Interpret search pattern as regular expression
    -f, --finish                    - Add a @done tag to action
    --file=PATH                     - Specify the file to search for the task (default: none)
    --in, --todo=TODO_FILE          - Use a known todo file, partial matches allowed (default: none)
    -n, --note                      - Prompt for additional notes. Input will be appended to any existing note.   If STDIN input (piped) is detected, it will be used as a note.
    -o, --overwrite                 - Overwrite note instead of appending
    -p, --priority=PRIO             - Add/change a priority level 1-5 (default: 0)
    -r, --remove=TAG                - Remove a tag to the action (may be used more than once, default: none)
    -t, --tag=TAG                   - Add a tag to the action, @tag(values) allowed (may be used more than once, default: none)
    --tagged=TAG                    - Match actions containing tag. Allows value comparisons (may be used more than once, default: none)
    --to, --project, --proj=PROJECT - Move action to specific project (default: none)
    -x, --exact                     - Match pattern exactly

EXAMPLES

    # Find "An existing task" action and remove the @na tag from it
    na update --remove na "An existing task"

    # Find "A bug..." action, add @waiting, add/update @priority(4), and prompt for an additional note
    na update --tag waiting "A bug I need to fix" -p 4 -n

    # Add @done to "My cool action" and immediately move to Archive
    na update --archive My cool action
```

### Configuration

Global options such as todo extension and default next action tag can be stored permanently by using the `na initconfig` command. Run na with the global options you'd like to set, and add `initconfig` at the end of the command. A file will be written to `~/.na.rc`. You can edit this manually, or just update it using the `initconfig --force` command to overwrite it with new settings.

> You can see all available global options by running `na help`.


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


#### Working with a single global file

na is designed to work with one or more TaskPaper files in each project directory, but if you prefer to use a single global TaskPaper file, you can add `--file PATH` as a global option and specify a single file. This will bypass the detection of any files in the current directory. Make it permanent by including the `--file` flag when running `initconfig`.

When using a global file, you can additionally include `--cwd_as TYPE` to determine whether the current working directory is used as a tag or a project (default is neither). If you add `--cwd_as tag` to the global options (before the command), the last element of the current working directory will be appended as an @tag (e.g. if you're in ~/Code/project/doing, the action would be tagged @doing). If you use `--cwd_as project` the action will be put into a project with the same name as the current directory (e.g. `Doing:` from the previous example).

#### Add tasks at the end of a project

By default, tasks are added at the top of the target project (Inbox, etc.). If you prefer new tasks to go at the end of the project by default, include `--add_at end` as a global option when running `initconfig`.

### Prompt Hooks

You can add a prompt command to your shell to have na automatically list your next actions when you `cd` into a directory. To install a prompt command for your current shell, just run `na prompt install`. It works with Zsh, Bash, and Fish. If you'd rather make the changes to your startup file yourself, run `na prompt show` to get the hook and instructions printed out for copying.

If you're using a single global file, you'll need `--cwd_as` to be `tag` or `project` for a prompt command to work. na will detect which system you're using and provide a prompt command that lists actions based on the current directory using either project or tag.

> You can also get output for shells other than the one you're currently using by adding "bash", "zsh", or "fish" to the show or install command.


> You can add `-r` to any of the calls to na to automatically recurse 3 directories deep, or just set the depth config permanently


After installing a hook, you'll need to close your terminal and start a new session to initialize the new commands.


[fzf]: https://github.com/junegunn/fzf
[gum]: https://github.com/charmbracelet/gum
[donate]: http://brettterpstra.com/donate/
[github]: https://github.com/ttscoff/na_gem/


PayPal link: [paypal.me/ttscoff](https://paypal.me/ttscoff)

## Changelog

See [CHANGELOG.md](https://github.com/ttscoff/na_gem/blob/master/CHANGELOG.md)
