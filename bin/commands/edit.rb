# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Edit an existing action'
  long_desc 'Open a matching action in your default $EDITOR.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick which file to act on.

  Natural language dates are expanded in known date-based tags.'
  arg_name 'ACTION'
  command %i[edit] do |c|
    c.example 'na edit "An existing task"',
              desc: 'Find "An existing task" action and open it for editing'

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Interpret search pattern as regular expression'
    c.switch %i[e regex], negatable: false

    c.desc 'Match pattern exactly'
    c.switch %i[x exact], negatable: false

    c.action do |global_options, options, args|
      options[:edit] = true
      action = if args.count.positive?
                 args.join(' ').strip
               else
                 NA.request_input(options, prompt: 'Enter a task to search for')
               end

      NA.notify("#{NA.theme[:error]}Empty input", exit_code: 1) if (action.nil? || action.empty?) && options[:tagged].empty?

      if action
        tokens = nil
        if options[:exact]
          tokens = action
        elsif options[:regex]
          tokens = Regexp.new(action, Regexp::IGNORECASE)
        else
          tokens = []
          all_req = action !~ /[+!\-]/ && !options[:or]

          action.split(/ /).each do |arg|
            m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                        })
          end
        end
      end

      if (action.nil? || action.empty?) && options[:tagged].empty?
        NA.notify("#{NA.theme[:error]}Empty input, cancelled", exit_code: 1)
      end

      all_req = options[:tagged].join(' ') !~ /[+!-]/ && !options[:or]
      tags = []
      options[:tagged].join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+\-!])?(?<tag>[^ =<>$\^~]+?)(?:(?<op>[=<>~]{1,2}|[*$\^]=)(?<val>.*?))?$/)

        tags.push({
                    tag: m['tag'].wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!-]/
                  })
      end

      target_proj = NA.cwd_is == :project ? NA.cwd : nil

      if options[:file]
        file = File.expand_path(options[:file])
        NA.notify("#{NA.theme[:error]}File not found", exit_code: 1) unless File.exist?(file)

        targets = [file]
      elsif options[:todo]
        todo = []
        options[:todo].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todo.push({
                      token: m['tok'],
                      required: all_req || (!m['req'].nil? && m['req'] == '+'),
                      negate: !m['req'].nil? && m['req'] =~ /[!-]/
                    })
        end
        dirs = NA.match_working_dir(todo)

        if dirs.count == 1
          targets = [dirs[0]]
        elsif dirs.count.positive?
          targets = NA.select_file(dirs, multiple: true)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless targets && targets.count.positive?
        else
          NA.notify("#{NA.theme[:error]}Todo not found", exit_code: 1) unless targets && targets.count.positive?

        end
      else
        files = NA.find_files(depth: options[:depth])
        NA.notify("#{NA.theme[:error]}No todo file found", exit_code: 1) if files.count.zero?

        targets = files.count > 1 ? NA.select_file(files, multiple: true) : [files[0]]
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless files.count.positive?

      end

      NA.notify("#{NA.theme[:error]}No search terms provided", exit_code: 1) if tokens.nil? && options[:tagged].empty?

      targets.each do |target|
        NA.update_action(target,
                         tokens,
                         done: options[:done],
                         edit: options[:edit],
                         project: target_proj,
                         tagged: tags)
      end
    end
  end
end
