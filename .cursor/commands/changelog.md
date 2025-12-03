Review all staged and unstaged files in the repo. Write a commmit message that uses @ labels to specify what type of change each line is. Apply @new, @fixed, @changed, @improved, and @breaking as appropriate to each line. Only add @ labels to changes that affect the user, not technical details. Technical details can be included in the commit, just don't add @ labels to those lines. Be sure to include a general description (< 60 characters) as the first line, followed by a line break.

Do not add @tags to notes about documentation updates. Always focus on actual code changes we've made since the last commit when generating the commit message.

Always use straight quotes and ascii punctuation, never curl quotes. Don't use emoji.

Always include a blank line after the first line (commit message) before the note.

Save this commit message to commit_message.txt. Overwrite existing contents.

Save this commit message to commit_message.txt{% if args.reset or args.replace %}. Overwrite existing contents.{% else %}. Update the file, merging changes, if file exists, otherwise create new.{% endif %}