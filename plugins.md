I would like to add a plugin architecture to na_gem. It should allow the user to add plugins to ~/.local/share/na/plugins/. These plugins can be any shell script (with a shebang). They can be run with `na plugin NAME`, which accepts the plugin filename with or without an extension, and with or without spaces (so that `plugin AddFoo` will run `Add Foo.sh` if found, but the user can also use `plugin "Add Foo"`).

A plugin will be a shell script that takes input on STDIN. The input should be an action as a JSON object, with the file path, line number, action text, note, and array of tags/values (`tags: [{ name: "done", value: "2025-10-29 03:00"}, { name: "na", value: ""}]`). That should be the default. 

The `plugin` command should accept a `--input TYPE` flag that accepts `json`, `yaml` or `text`. The YAML should be the same as the JSON (but as YAML), and the text should just be the file_path:line_number, action text, and note, split with "||" (newlines in the note replaced with \n, and filename and line number are combined with : not the divider), with no colorization. One action per line. The "||" in `--input text` should also be a flag `--divider "STRING"` that defaults to "||", but allows the user to specify a different string to split the parts on. 

The plugin will need to return output (on STDOUT) in the same format as the input (yaml, json, or text with specified divider), unless `--output FORMAT` is specified with a different type. The `plugin` command will execute the script for every command passed to it, and update the actions based on the returned output.

The `plugin` command should accept all the same filter flags as `finish` or other actions that update commands. 

For the `update` command, it should accept a `--plugin NAME` flag, and if it's using interactive menus, a list of plugin names (basename minus extension) should be added to the list of available operations.

Also add a `--plugin NAME`, `--input TYPE`, and `--output TYPE` flag to all search and display commands (next, grep, tagged, etc.). That way the user can filter output with any command and run the result through the plugin.

In lieu of the `--input` and `--output` commands, the plugin itself can have a comment block after the shebang with `key: value` pairs. When reading a plugin, check for a comment block with `input: JSON` `output: YAML` (case insensitive). The user can also define a `name` or `title` (interchangeable) in this block, which will be used instead of the base name if provided. We need to ignore leading characters when scanning for this comment block (e.g. # or //). The block can have blank lines before it. The only keys we read are input, output, and name/title. Parsing stops at the first blank line or after all three keys are populated. Other keys might exist, like `author` or `description`, which should be ignored.

The plugins shouldn't need to be executable, the hashbang should be read and used to execute the script.

When `na` runs, it should check for the existence of the `plugins` directory, creating it if it's missing, and adding a `~/.local/share/na/plugsin/README.md` file with plugin instructions if one doesn't exist. Any `.md` or `.bak` file in the plugins directory should be ignored. In fact, let's have a helper validate the files in the directory by checking for a shebang and ignoring if none exists, and also ignoring any '.bak' or '.md' files.

Have NA also create 2 sample plugins in the `~/.local/share/na/plugins` folder when creating it (do not create plugins if the folder already exists). Have the sample plugins be a Python script and a Bash script. The sample plugins should just do something benign like add a tag with a dynamic value to the passed actions. In the README.md note that the user can delete the sample plugins. Give the sample plugins names "Add Foo.py" and "Add Bar.sh" and have them add @foo and @bar, respectively.

### Summary ###

- plugins are script files in ~/.local/share/na/plugins
	- plugins require a shebang, which is used to execute them
	- plugin base names (without extension) becomes the command name (spaces are handled)
	- Ignore 
- `plugin` subcommand
	- accepts plugin name as argument
	- has a `--input TYPE` flag that determines the input type (yaml, json, or text)
	- has a `--output TYPE` (yaml, json, or text)
	- has a `--divider` flag that determines the divider when `--input text` is used
- `update` subcommand
	- accepts a `--plugin NAME` flag
	- Adds plugin names to interactive menu when no action is specified
- main script parses the output of the plugin, stripping whitespace and reading it as YAML, JSON, or text split on the divider (based on `--output` and defaulting to the value of `--input`), then updates each action in the result. Line numbers should be passed on both input and output and used to update the specific actions.
- Generate README and scripts