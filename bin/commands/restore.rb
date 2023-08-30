# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Find and remove @done tag from an action'
  arg_name 'PATTERN'
  command %i[restore unfinish] do |c|
    c.example 'na restore "An existing task"',
              desc: 'Find "An existing task" and remove @done'
    c.example 'na unfinish "An existing task"',
              desc: 'Alias for restore'

    c.desc 'Prompt for additional notes. Input will be appended to any existing note.
    If STDIN input (piped) is detected, it will be used as a note.'
    c.switch %i[n note], negatable: false

    c.desc 'Overwrite note instead of appending'
    c.switch %i[o overwrite], negatable: false

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

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
      options[:remove] = ['done']
      options[:done] = true
      options[:finish] = false
      options[:f] = false
      
      cmd = commands[:update]
      action = cmd.send(:get_action, nil)
      action.call(global, options, args)
    end
  end
end
