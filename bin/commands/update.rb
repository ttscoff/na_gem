# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Update an existing action'
  long_desc 'Provides an easy way to complete, prioritize, and tag existing actions.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick which file to act on.'
  arg_name 'ACTION'
  command %i[update] do |c|
    c.example 'na update --remove na "An existing task"',
              desc: 'Find "An existing task" action and remove the @na tag from it'
    c.example 'na update --tag waiting "A bug I need to fix" -p 4 -n',
              desc: 'Find "A bug..." action, add @waiting, add/update @priority(4), and prompt for an additional note'
    c.example 'na update --archive My cool action',
              desc: 'Add @done to "My cool action" and immediately move to Archive'

    c.desc 'Prompt for additional notes. Input will be appended to any existing note.
    If STDIN input (piped) is detected, it will be used as a note.'
    c.switch %i[n note], negatable: false

    c.desc 'Overwrite note instead of appending'
    c.switch %i[o overwrite], negatable: false

    c.desc 'Add/change a priority level 1-5'
    c.arg_name 'PRIO'
    c.flag %i[p priority], must_match: /[1-5]/, type: :integer, default_value: 0

    c.desc 'When moving task, add at [s]tart or [e]nd of target project'
    c.arg_name 'POSITION'
    c.flag %i[at], must_match: /^[sbea].*?$/i

    c.desc 'Move action to specific project'
    c.arg_name 'PROJECT'
    c.flag %i[to project proj]

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Add a tag to the action, @tag(values) allowed, use multiple times or combine multiple tags with a comma'
    c.arg_name 'TAG'
    c.flag %i[t tag], multiple: true

    c.desc 'Remove a tag from the action, use multiple times or combine multiple tags with a comma,
            wildcards (* and ?) allowed'
    c.arg_name 'TAG'
    c.flag %i[r remove], multiple: true

    c.desc 'Add a @done tag to action'
    c.switch %i[f finish], negatable: false

    c.desc 'Add a @done tag to action and move to Archive'
    c.switch %i[a archive], negatable: false

    c.desc 'Remove @done tag from action'
    c.switch %i[restore], negatable: false

    c.desc 'Delete an action'
    c.switch %i[delete], negatable: false

    c.desc "Open action in editor (#{NA::Editor.default_editor}).
            Natural language dates will be parsed and converted in date-based tags."
    c.switch %i[edit], negatable: false

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

    c.action do |global_options, options, args|
      reader = TTY::Reader.new

      append = options[:at] ? options[:at] =~ /^[ae]/i : global_options[:add_at] =~ /^[ae]/i

      if options[:restore] || (!options[:remove].nil? && options[:remove].include?('done'))
        options[:done] = true
        options[:tagged] << '+done'
      elsif !options[:remove].nil? && !options[:remove].empty?
        options[:tagged].concat(options[:remove])
      elsif options[:finish] && !options[:done]
        options[:tagged] << '-done'
      end

      action = if args.count.positive?
                 args.join(' ').strip
               else
                 NA.request_input(options, prompt: 'Enter a task to search for')
               end
      if action
        tokens = nil
        if options[:exact]
          tokens = action
        elsif options[:regex]
          tokens = Regexp.new(action, Regexp::IGNORECASE)
        else
          tokens = []
          all_req = action !~ /[+!-]/ && !options[:or]

          action.split(/ /).each do |arg|
            m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
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
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)

        tags.push({
                    tag: m['tag'].wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                  })
      end

      priority = options[:priority].to_i if options[:priority]&.to_i&.positive?
      add_tags = options[:tag] ? options[:tag].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').wildcard_to_rx } : []
      remove_tags = options[:remove] ? options[:remove].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').wildcard_to_rx } : []
      remove_tags << 'done' if options[:restore]

      stdin_note = NA.stdin ? NA.stdin.split("\n") : []

      line_note = if options[:note] && $stdin.isatty
                    puts stdin_note unless stdin_note.nil?
                    if TTY::Which.exist?('gum')
                      args = ['--placeholder "Enter a note, CTRL-d to save"']
                      args << '--char-limit 0'
                      args << '--width $(tput cols)'
                      `gum write #{args.join(' ')}`.strip.split("\n")
                    else
                      NA.notify("#{NA.theme[:prompt]}Enter a note, {bw}CTRL-d#{NA.theme[:prompt]} to end editing:#{NA.theme[:action]}")
                      reader.read_multiline
                    end
                  end

      note = stdin_note.empty? ? [] : stdin_note
      note.concat(line_note) unless line_note.nil? || line_note.empty?

      target_proj = if options[:project]
                      options[:project]
                    elsif NA.cwd_is == :project
                      NA.cwd
                    end

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
                      negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
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
        files = NA.find_files_matching({
                                         depth: options[:depth],
                                         done: options[:done],
                                         regex: options[:regex],
                                         require_na: false,
                                         search: tokens,
                                         tag: tags
                                       })
        NA.notify("#{NA.theme[:error]}No todo file found", exit_code: 1) if files.count.zero?

        targets = files.count > 1 ? NA.select_file(files, multiple: true) : [files[0]]
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless files.count.positive?

      end

      if options[:archive]
        options[:finish] = true
        options[:project] = 'Archive'
      end

      NA.notify("#{NA.theme[:error]}No search terms provided", exit_code: 1) if tokens.nil? && options[:tagged].empty?

      targets.each do |target|
        NA.update_action(target, tokens,
                         add_tag: add_tags,
                         all: options[:all],
                         append: append,
                         delete: options[:delete],
                         done: options[:done],
                         edit: options[:edit],
                         finish: options[:finish],
                         note: note,
                         overwrite: options[:overwrite],
                         priority: priority,
                         project: target_proj,
                         remove_tag: remove_tags,
                         tagged: tags)
      end
    end
  end
end
