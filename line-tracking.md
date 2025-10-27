When editing and displaying commands, we should include a line number. It should be formatted like PATH:LINE as part of the action.file attribute. Line number should be included any time we display a path. For instances where we don't display the path (only one file is targeted), just the line number should be displayed, extracted from the :line on the action.file attribute.

When we display a menu of actions, the line number should be included. This should be used to target the action for any modifications, allowing handling of duplicate actions. The line number can be extracted from the menu result and used for targeting. When dealing with multiple actions, they should be modified in reverse order so the line number isn't affected if a note is added that would change the line numbers of succeeding actions.

This would also allow us to use the `edit` command on multiple actions. When the content of the editor is created, multiple actions should be separated with comments conFor instances where we don't display the path (only one file is targeted), just the line number should be displayed, extracted from the :line on the action.file attribute.taining their PATH:LINE locations.

```
# ./frozen.taskpaper:21
The action to be edited
Note for the action
```

At the top of the editor, there should be a comment:

```
# Do not edit # comment lines. Add notes on new lines after the action.
# Blank lines and lines will be ignored
```

When reading the output of the editor, use the # PATH:LINE comments to target the edits in the files. Ignore other # lines.

The update command should accept a path:line argument. If the argument matches that format and the specified file exists, the action at that line should be affected. The user can use a display command (`next`, `grep`, etc.) to see the file/line.

