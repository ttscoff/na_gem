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
