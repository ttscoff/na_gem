I would like to add time tracking to NA.

First, add the chronify gem if we haven't already.

The finish and add commands should have flags --start DATE, --end DATE, and --duration TIME. --end DATE sets a @done(DATE) tag. These accept any date format, including natural language (using the chronify gem).

For the add command, --start sets a @start(XXXX-XX-XX XX:XX) tag, --duration sets a @start tag by subtracting the duration from the current time unless there's a --end time, in which case it subtracts from that to create the @start time.

For the finish command, --duration without a --end subtracts duration from current time to create a @start tag and adds a @duration tag by subtracting @start from @done. --end creates an @done(DATE_TIME) tag and adds a @duration if @start is available. In the finish command, and existing @start can be updated with --start or --duration. Any command created with `add` or by editing with `update` detects @start, @end, and @duration tags in the action and processes the value of the tag to create a XXXX-XX-XX XX:XX date from whatever format (including natural language) is in the value.

In the `update` menu, if finish is selected, there should be a yes/no prompt for `Timed?`, in which case it will ask for a start date, which can include `30 minutes ago` or `3pm`, etc., which will be handled by chronify.

Any output command like `next`, `tagged`, or `grep` gets a --times switch that will output a block at the end with the total durations of actions that have a @start tag. Durations of individual actions are added in yellow at the end of the action, in square brackets. Durations are displayed in DD:HH:MM:SS format. A --human switch displays times as `XX days, XX hours, XX minutes, XX seconds`, with only the necessary elements (if it only took 5 minutes, it just displays `5 minutes, 30 seconds`).

The most effective way to handle the date/time flags is to add a DateTime type to GLI and have the flags in the DSL use that type. That type automatically runs the value through chronify. See the doing gem types DateBeginString and DateEndString in ~/Desktop/Code/doing/lib/doing/types.rb, and its usage in ~/Desktop/Code/doing/bin/doing e;nd ~/Desktop/Code/doing/bin/commands/finish.rb. We'll also want a Duration type that converts the flag argument to a number of seconds.

