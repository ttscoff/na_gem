# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Find and mark an action as @done'
  arg_name 'ACTION'
  command %i[complete finish] do |c|
    c.example 'na complete "An existing task"',
              desc: 'Find "An existing task" and mark @done'
    c.example 'na finish "An existing task"',
              desc: 'Alias for complete'

    c.desc 'Prompt for additional notes. Input will be appended to any existing note.
    If STDIN input (piped) is detected, it will be used as a note.'
    c.switch %i[n note], negatable: false

    c.desc 'Overwrite note instead of appending'
    c.switch %i[o overwrite], negatable: false

    c.desc 'Add a @done tag to action and move to Archive'
    c.switch %i[a archive], negatable: false

    c.desc 'Move action to specific project'
    c.arg_name 'PROJECT'
    c.flag %i[to project proj]

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Act on all matches immediately (no menu)'
    c.switch %i[all], negatable: false

    c.desc 'Interpret search pattern as regular expression'
    c.switch %i[e regex], negatable: false

    c.desc 'Match pattern exactly'
    c.switch %i[x exact], negatable: false

    c.action do |global, options, args|
      options[:finish] = true
      options[:f] = true
      options[:project] = 'Archive' if options[:archive] && !options[:project]

      cmd = commands[:update]
      action = cmd.send(:get_action, nil)
      action.call(global, options, args)
    end
  end
end
