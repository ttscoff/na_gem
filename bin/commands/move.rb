# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Move an existing action to a different section'
  long_desc 'Provides an easy way to move an action.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick which file to act on.'
  arg_name 'ACTION'
  command %i[move] do |c|
    c.example 'na move "A bug in inbox" --to Bugs',
              desc: 'Find "A bug in inbox" action and move it to section Bugs'

    c.desc 'Prompt for additional notes. Input will be appended to any existing note.
    If STDIN input (piped) is detected, it will be used as a note.'
    c.switch %i[n note], negatable: false

    c.desc 'Overwrite note instead of appending'
    c.switch %i[o overwrite], negatable: false

    c.desc 'Move action to specific project. If not provided, a menu will be shown'
    c.arg_name 'PROJECT'
    c.flag %i[to]

    c.desc 'When moving task, add at [s]tart or [e]nd of target project'
    c.arg_name 'POSITION'
    c.flag %i[at], must_match: /^[sbea].*?$/i

    c.desc 'Search for actions in a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[from]

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Include notes in search'
    c.switch %i[search_notes], negatable: true, default_value: true

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

      args.concat(options[:search]) unless options[:search].nil?

      append = options[:at] ? options[:at] =~ /^[ae]/i : global_options[:add_at] =~ /^[ae]/i

      options[:done] = true

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

      stdin_note = NA.stdin ? NA.stdin.split("\n") : []

      line_note = if options[:note] && $stdin.isatty
                    puts stdin_note unless stdin_note.nil?
                    if TTY::Which.exist?('gum')
                      args = ['--placeholder "Enter a note, CTRL-d to save"']
                      args << '--char-limit 0'
                      args << '--width $(tput cols)'
                      gum = TTY::Which.which('gum')
                      `#{gum} write #{args.join(' ')}`.strip.split("\n")
                    else
                      NA.notify("#{NA.theme[:prompt]}Enter a note, {bw}CTRL-d#{NA.theme[:prompt]} to end editing:#{NA.theme[:action]}")
                      reader.read_multiline
                    end
                  end

      note = stdin_note.empty? ? [] : stdin_note
      note.concat(line_note) unless line_note.nil? || line_note.empty?

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
                                         project: options[:from],
                                         regex: options[:regex],
                                         require_na: false,
                                         search: tokens,
                                         tag: tags
                                       })
        NA.notify("#{NA.theme[:error]}No todo file found", exit_code: 1) if files.count.zero?

        targets = files.count > 1 ? NA.select_file(files, multiple: true) : [files[0]]
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless files.count.positive?
      end

      target_proj = if options[:to]
                      options[:to]
                    else
                      todo = NA::Todo.new(require_na: false, file_path: targets[0])
                      projects = todo.projects
                      menu = projects.each_with_object([]) { |proj, arr| arr << proj.project }

                      NA.choose_from(menu, prompt: 'Move to: ', multiple: false, sorted: false)
                    end

      NA.notify("#{NA.theme[:error]}No target selected", exit_code: 1) unless target_proj

      NA.notify("#{NA.theme[:error]}No search terms provided", exit_code: 1) if tokens.nil? && options[:tagged].empty?

      targets.each do |target|
        NA.update_action(target, tokens,
                         all: options[:all],
                         append: append,
                         move: target_proj,
                         note: note,
                         overwrite: options[:overwrite],
                         project: options[:from],
                         search_note: options[:search_notes],
                         tagged: tags)
      end
    end
  end
end
