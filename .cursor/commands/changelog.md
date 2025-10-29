Write a commmit message that uses @ labels to specify what type of change each line is. Apply @new, @fixed, @changed, @improved, and @breaking as appropriate to each line. Only add @ labels to changes that affect the user, not technical details. Technical details can be included in the commit, just don't add @ labels to those lines. Be sure to include a general description (< 60 characters) as the first line, followed by a line break.


Save this commit message to commit_message.txt. Overwrite existing contents.

Save this commit message to commit_message.txt{% if args.reset %}. Overwrite existing contents.{% else %}. Update the file, merging changes, if file exists, otherwise create new.{% endif %}