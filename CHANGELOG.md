### 1.2.25

2023-08-21 07:23

#### FIXED

- Find command on Linux

### 1.2.24

2023-06-14 09:16

### 1.2.23

2023-06-05 10:42

#### FIXED

- Actually implement the --template option

### 1.2.22

2023-06-05 10:35

#### NEW

- Global `--template PATH` option to define a template for new files, can be added to .na.rc

#### IMPROVED

- Help verbiage and examples

#### FIXED

- Variable assignment warnings

### 1.2.20

2023-05-09 10:40

#### FIXED

- Allow single character projects
- Allow parens in project title

### 1.2.19

2023-01-17 16:49

#### IMPROVED

- `--nest` flag creates a flat list with project included in task title, `--omnifocus` creates OmniFocus-compatible project nesting

### 1.2.18

2023-01-17 13:38

#### IMPROVED

- Format tags OmniFocus wouldn't recognize as @tags(TAG) in --nest output
- Include notes in --nest output

### 1.2.17

2023-01-17 11:23

#### IMPROVED

- `--nest` works with `find` and `tagged`
- `--nest` creates heirarchy of parent projects, indented TaskPaper style

### 1.2.16

2023-01-17 10:13

#### NEW

- `na next --nest` will output a TaskPaper format list of actions grouped under their respective files with the filename as the containing project

#### FIXED

- Better solution to target_proj nil error

### 1.2.15

2022-11-28 10:58

#### FIXED

- `na update` error when not moving project

### 1.2.14

2022-11-12 10:57

#### NEW

- `na find --tagged` allows narrowing search results with tag queries
- `na tagged --search` allows narrowing tag results with text search
- `na next` accepts --tagged and --search (as well as --exact and --regex) for filtering actions

#### FIXED

- Error when a todo file contained a task without a project

### 1.2.13

2022-11-01 12:43

#### FIXED

- Allow colon at end of action without recognizing as project

### 1.2.12

2022-10-31 13:52

#### FIXED

- --save flag for find and tagged not working properly

### 1.2.11

2022-10-31 13:45

#### FIXED

- Frozen string error

### 1.2.10

2022-10-29 15:59

#### FIXED

- Better handling of tokenized search for todo matching with multiple arguments
- Guard for error parsing project name

### 1.2.9

2022-10-29 10:50

#### FIXED

- Na next with a todo search wasn't requiring a match

### 1.2.8

2022-10-28 11:52

#### IMPROVED

- Empty lines in notes end a task in the parser
- Moving a task to the end of a project respects line breaks

#### FIXED

- Moving action within same project to end not parsing correctly

### 1.2.7

2022-10-28 07:29

#### IMPROVED

- Code refactoring

#### FIXED

- All_req error
- Adding entries to project names containing hyphen

### 1.2.6

2022-10-26 10:50

#### NEW

- Pass notes to STDIN using piped input when using the `--note` switch
- `--notes` switch for next, find, and tagged to include action notes in output

#### IMPROVED

- Update na saved examples and documentation
- Better handling of unknown commands, affecting `na -a ACTION` and `na SAVED_SEARCH`
- Additional help documentation and examples
- Updated documentation
- If a todo query contains only a negative, display all non-matching todos
- Don't display readline prompts if not a TTY
- Prompt hook generator recognizes when a global file is being used and modifies prompt hooks to search for project name or tag based on the value of `--cwd_as`.

#### FIXED

- Debug messages showing when not using --debug

### 1.2.5

2022-10-26 07:39

#### FIXED

- Error with add command

### 1.2.4

2022-10-26 07:28

#### FIXED

- Backup file naming

### 1.2.3

2022-10-25 17:05

#### CHANGED

- Add a preceding dot to backup files created when updating to make backups hidden from notetaking apps and the like.

### 1.2.2

2022-10-25 14:30

#### CHANGED

- `na update --done` now means "include @done actions in search"
- `na next --in QUERY` now searches for a known todo file (formerly required arguments, now both work)

#### NEW

- `--at [start|end]` switch for `add` and `update` to determine
- Global `--file PATH` flag to specify a single global todo file
- `--add_at [start|end]` global flag that can be added to config to make permanent
- `--finish` switch for `na add` to immediately mark an action as @done
- `--cwd_as [project|tag]` global flag when using a global `--file` to determine if the current working directory (last element) is added as an @tag or parent project

#### IMPROVED

- Refactor `na add` to use improved task update code
- Confirm target file before requesting task when running `na

### 1.2.1

2022-10-22 10:18

#### NEW

- Added `--done` tag to next/find/tagged to include @done actions in the output
- Use `na changes` to view the changelog and see recent changes

#### IMPROVED

- You can run `na SAVED_SEARCH` using any saved search (same as running `na saved SAVED_SEARCH` but niftier)

### 1.2.0

2022-10-22 01:32

#### CHANGED

- `na add --to` now specifies a project, `--in` specifies a todo file
- Prefer fzf over gum when available

#### NEW

- `--edit` and `--delete` for saved searches (`na saved`)
- `na add --todo FILE` will match any known todo file when adding an action
- `na add --project PROJ` will match any existing project when adding an action
- `na update [options] search string` will update an existing task, moving it between projects, adding and removing tags, marking finished, setting priority, adding/replacing notes, or archiving it
- `--tagged TAG` flag for `na update` searches by tag/value
- `na projects` will list all projects in a todo file, optional argument to query known todos
- `--delete` switch for `na update`

#### IMPROVED

- Include arguments with `na edit` to narrow down which file to edit (partial matching)
- Improved handling of todo file search arguments for `na next`
- If todo file search returns zero results, loosen search
- When using !negations in todo matching, allow the negation to match any part of the path, not just last element
- Full token matching when using `na todos QUERY`
- Offer gum and readline fallbacks for fzf menu with `na update`
- `--overwrite` option when adding a note using `na update` (defaults to append)
- Allow multiple file selections for `na update`
- Display "Inbox" as a parent
- Ignore @done actions in next and tagged (unless specifically included) but allow them to appear in `na find`

#### FIXED

- `na add --priority` being interpreted as note
- Immediately save created todo files to history
- Multi-line note handling
- Project regex
- Error when an action contains a left curly brace
- Don't show @done tasks unless specifically searched for

### 1.1.26

2022-10-15 10:36

#### IMPROVED

- A parenthetical at the end of an action will be interpreted as a note. If --note is additionally supplied, entered note is concatenated to parenthetical note.
- Allow multi-line notes

### 1.1.25

2022-10-12 08:37

#### FIXED

- Unable to search for next action tag with `find` or `tagged`

### 1.1.24

2022-10-12 08:27

#### FIXED

- Force utf-8 encoding when reading files, should fix invalid byte sequence errors

### 1.1.23

2022-10-07 10:02

#### NEW

- Saved searches. Add `--save TITLE` to `tagged` or `find` commands to save the parameters for use with `na saved TITLE`

#### FIXED

- Restore wildcard capability of tag searches

### 1.1.22

2022-10-07 05:58

#### IMPROVED

- Help output and code documentation
- Allow wildcards (* and ?) when matching todo history
- Allow multiple todo queries separated by comma

#### FIXED

- Remove file extension when matching todo history
- Todo history query failed on exact match

### 1.1.21

2022-10-07 04:26

#### NEW

- `na todos` will list (and optionally search) known todo files from history

#### IMPROVED

- Fuzzier matching of todo file history
- Help output fixes
- Code documentation

### 1.1.20

2022-10-07 03:16

#### IMPROVED

- Date comparisons that don't specify a time are automatically adjusted to "noon" to allow direct comparison of days

### 1.1.19

2022-10-07 03:06

#### IMPROVED

- More help updates
- Added `--or` flag to `tagged` and `find` to default to OR boolean combination of search terms/tags
- Special handling for date comparisons to "today"

### 1.1.18

2022-10-06 17:23

#### FIXED

- Update help to match new default AND searches

### 1.1.17

2022-10-06 17:02

#### CHANGED

- Default to AND search with `tagged` unless a "+" or "!" is specified

### 1.1.16

2022-10-06 16:47

#### NEW

- `--in todo/path` flag for `find` and `tagged` commands to specify a todo file from history

### 1.1.15

2022-10-06 16:12

#### CHANGED

- If no + or ! tokens are given in search, default to AND search for tokens

#### IMPROVED

- Better handling of color in search highlighting

#### FIXED

- --regex search broken

### 1.1.14

2022-10-06 12:30

#### IMPROVED

- Code cleanup
- Highlight search terms in results

#### FIXED

- Multiple search terms overriding each other

### 1.1.13

2022-10-06 06:28

#### IMPROVED

- When specifying arguments to `next`, allow paths separated by / to do more exact matching

### 1.1.12

2022-10-06 05:42

#### NEW

- `na add -d X` to allow adding new actions to todo files in subdirectories
- You can now perform <>= queries on tag values (`na tagged "priority>=3"`)
- You can now perform string matches on tag values (`na tagged "note*=markdown"`)
- You can use `--project X` to display only actions within a specific project. Specify subprojects with a path, e.g. `na/bugs`. Partial matches allowed, works with `next`, `find`, and `tagged`
- Find and tagged recognize * and ? as wildcards
- --regex flag for find command
- --invert command (like grep -v) for find
- -v/--invert for tagged command

#### IMPROVED

- Require value 1-9 for --depth option

### 1.1.11

2022-10-05 08:56

#### IMPROVED

- Respect na_tag setting when creating new todo file
- Code cleanup

### 1.1.10

2022-10-05 08:19

#### FIXED

- When adding a project, don't use Ruby #capitalize, which downcases the rest of the project name

### 1.1.9

2022-10-03 12:08

#### NEW

- `na add --to PROJECT` option to add an action to a project other than Inbox. Case insensitive but requires exact project match. Missing project will be created at top of file.

#### FIXED

- `-t ALT_TAG` functionality fixed

### 1.1.8

2022-10-02 16:40

#### FIXED

- `na next -t X` didn't replace @na tag in search, but appended to it

### 1.1.7

2022-10-02 12:20

#### IMPROVED

- You can use !token to add negative values to tag/search queries, e.g. `na tagged +maybe !waiting`

### 1.1.6

2022-10-02 11:46

#### CHANGED

- `na find` and `na tagged` now operate on all actions, not just actions tagged @na. If you want to limit to @na actions, just include +na in the query.

### 1.1.5

2022-10-01 11:32

#### FIXED

- Parsing of project hierarchy for an action

### 1.1.4

2022-09-29 04:17

#### FIXED

- Doing reference in help screen for next

### 1.1.3

2022-09-28 07:12

#### FIXED

- `na next --tag X` not working

### 1.1.2

2022-09-28 06:37

#### IMPROVED

- Detailed instructions after installing prompt hooks

### 1.1.1

2022-09-28 04:49

#### CHANGED

- Belated minor version bump

### 1.0.6

2022-09-28 04:22

#### NEW

- `na prompt [show|install]` command to help with adding prompt hooks to your shell

### 1.0.5

2022-09-28 01:53

#### FIXED

- A note containing a colon would be recognized as a project line

### 1.0.4

2022-09-28 01:18

#### NEW

- OS agnostic command to open todo file in an editor
- `na init` command to generate a new todo file

#### IMPROVED

- Output formatting
- Make directory matching fuzzy for `na next`
- --verbose global switch to output debug info

### 1.0.3

2022-09-27 14:30

#### FIXED

- Running `na -a -n` yielded an error

### 1.0.2

2022-09-27 14:18

#### IMPROVED

- When using gum input, make the input field the width of the terminal

#### FIXED

- -a with no arguments will work for backward compatability

### 1.0.1

2022-09-27 12:52

#### NEW

- Add arguments to `na next` to query previously-seen na files in other directories

### 1.0.0

2022-09-27 10:45

#### IMPROVED

- Initial rewrite from Bash script to Ruby gem
- Backwards compatibility with the Bash version of NA
