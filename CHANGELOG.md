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
