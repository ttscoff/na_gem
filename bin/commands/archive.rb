# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Mark an action as @done and archive'
  arg_name 'ACTION'
  command %i[archive] do |c|
    c.example 'na archive "An existing task"',
              desc: 'Find "An existing task", mark @done if needed, and move to archive'

    c.desc 'Prompt for additional notes. Input will be appended to any existing note.
    If STDIN input (piped) is detected, it will be used as a note.'
    c.switch %i[n note], negatable: false

    c.desc 'Overwrite note instead of appending'
    c.switch %i[o overwrite], negatable: false

    c.desc 'Archive all done tasks'
    c.switch %i[done], negatable: false

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Affect actions from a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[proj project]

    c.desc 'Act on all matches immediately (no menu)'
    c.switch %i[all], negatable: false

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

    c.desc 'Interpret search pattern as regular expression'
    c.switch %i[e regex], negatable: false

    c.desc 'Match pattern exactly'
    c.switch %i[x exact], negatable: false

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.action do |global, options, args|
      args.concat(options[:search])

      if options[:done]
        options[:tagged] << 'done'
        options[:all] = true
      else
        options[:tagged] << '-done'
      end

      options[:done] = true
      options['done'] = true
      options[:finish] = true
      options[:move] = 'Archive'
      options[:archive] = true
      options[:a] = true

      cmd = commands[:update]
      action = cmd.send(:get_action, nil)
      action.call(global, options, args)
    end
  end
end
