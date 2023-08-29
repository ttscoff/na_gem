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

    c.desc 'Add a tag to the action, @tag(values) allowed'
    c.arg_name 'TAG'
    c.flag %i[t tag], multiple: true

    c.desc 'Remove a tag to the action'
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

      options[:done] = true if options[:restore] || options[:remove] =~ /^done/

      action = if args.count.positive?
                 args.join(' ').strip
               elsif $stdin.isatty && TTY::Which.exist?('gum') && options[:tagged].empty?
                 options = [
                   %(--placeholder "Enter a task to search for"),
                   '--char-limit=500',
                   "--width=#{TTY::Screen.columns}"
                 ]
                 `gum input #{options.join(' ')}`.strip
               elsif $stdin.isatty && options[:tagged].empty?
                 puts NA::Color.template('{bm}Enter search string:{x}')
                 reader.read_line(NA::Color.template('{by}> {bw}')).strip
               end

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
        puts 'Empty input, cancelled'
        Process.exit 1
      end

      all_req = options[:tagged].join(' ') !~ /[+!\-]/ && !options[:or]
      tags = []
      options[:tagged].join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+\-!])?(?<tag>[^ =<>$\^]+?)(?:(?<op>[=<>]{1,2}|[*$\^]=)(?<val>.*?))?$/)

        tags.push({
                    tag: m['tag'].wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                  })
      end

      priority = options[:priority].to_i if options[:priority]&.to_i&.positive?
      add_tags = options[:tag] ? options[:tag].map { |t| t.sub(/^@/, '').wildcard_to_rx } : []
      remove_tags = options[:remove] ? options[:remove].map { |t| t.sub(/^@/, '').wildcard_to_rx } : []

      stdin_note = NA.stdin ? NA.stdin.split("\n") : []

      line_note = if options[:note] && $stdin.isatty
                    puts stdin_note unless stdin_note.nil?
                    if TTY::Which.exist?('gum')
                      args = ['--placeholder "Enter a note, CTRL-d to save"']
                      args << '--char-limit 0'
                      args << '--width $(tput cols)'
                      `gum write #{args.join(' ')}`.strip.split("\n")
                    else
                      puts NA::Color.template('{bm}Enter a note, {bw}CTRL-d{bm} to end editing{bw}')
                      reader.read_multiline
                    end
                  end

      note = stdin_note.empty? ? [] : stdin_note
      note.concat(line_note) unless line_note.nil? || line_note.empty?

      target_proj = if options[:project]
                      options[:project]
                    elsif NA.cwd_is == :project
                      NA.cwd
                    else
                      nil
                    end

      if options[:file]
        file = File.expand_path(options[:file])
        NA.notify('{r}File not found', exit_code: 1) unless File.exist?(file)

        targets = [file]
      elsif options[:todo]
        todo = []
        options[:todo].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todo.push({
                      token: m['tok'],
                      required: all_req || (!m['req'].nil? && m['req'] == '+'),
                      negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                    })
        end
        dirs = NA.match_working_dir(todo)

        if dirs.count == 1
          targets = [dirs[0]]
        elsif dirs.count.positive?
          targets = NA.select_file(dirs, multiple: true)
          NA.notify('{r}Cancelled', exit_code: 1) unless targets && targets.count.positive?
        else
          NA.notify('{r}Todo not found', exit_code: 1) unless targets && targets.count.positive?

        end
      else
        files = NA.find_files(depth: options[:depth])
        NA.notify('{r}No todo file found', exit_code: 1) if files.count.zero?

        targets = files.count > 1 ? NA.select_file(files, multiple: true) : [files[0]]
        NA.notify('{r}Cancelled{x}', exit_code: 1) unless files.count.positive?

      end

      if options[:archive]
        options[:finish] = true
        options[:project] = 'Archive'
      end

      NA.notify('{r}No search terms provided', exit_code: 1) if tokens.nil? && options[:tagged].empty?

      targets.each do |target|
        NA.update_action(target, tokens,
                         priority: priority,
                         add_tag: add_tags,
                         remove_tag: remove_tags,
                         finish: options[:finish],
                         project: target_proj,
                         delete: options[:delete],
                         note: note,
                         overwrite: options[:overwrite],
                         tagged: tags,
                         all: options[:all],
                         done: options[:done],
                         append: append)
      end
    end
  end
end
