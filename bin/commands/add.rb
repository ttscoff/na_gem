# frozen_string_literal: true

class App
  extend GLI::App
  desc "Add a new next action"
  long_desc 'Provides an easy way to store todos while you work. Add quick
  reminders and (if you set up Prompt Hooks) they\'ll automatically display
  next time you enter the directory.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick to which file the action gets added.'
  arg_name "ACTION"
  command :add do |c|
    c.desc "Started time (natural language or ISO)"
    c.arg_name "DATE"
    c.flag %i[started], type: :date_begin

    c.desc "End/Finished time (natural language or ISO)"
    c.arg_name "DATE"
    c.flag %i[end finished], type: :date_end

    c.desc "Duration (e.g. 45m, 2h, 1d2h30m, or minutes)"
    c.arg_name "DURATION"
    c.flag %i[duration], type: :duration
    c.example 'na add "A cool feature I thought of @idea"', desc: "Add a new action to the Inbox, including a tag"
    c.example 'na add "A bug I need to fix" -p 4 -n',
              desc: "Add a new action to the Inbox, set its @priority to 4, and prompt for an additional note."
    c.example 'na add "An action item (with a note)"',
              desc: "A parenthetical at the end of an action is interpreted as a note"

    c.desc "Prompt for additional notes. STDIN input (piped) will be treated as a note if present."
    c.switch %i[n note], negatable: false

    c.desc "Add a priority level 1-5 or h, m, l"
    c.arg_name "PRIO"
    c.flag %i[p priority], must_match: /[1-5hml]/, default_value: 0

    c.desc "Add action to specific project"
    c.arg_name "PROJECT"
    c.default_value "Inbox"
    c.flag %i[to project proj]

    c.desc "Add task at [s]tart or [e]nd of target project"
    c.arg_name "POSITION"
    c.flag %i[at], must_match: /^[sbea].*?$/i

    c.desc "Add to a known todo file, partial matches allowed"
    c.arg_name "TODO_FILE"
    c.flag %i[in todo]

    c.desc "Use a tag other than the default next action tag"
    c.arg_name "TAG"
    c.flag %i[t tag]

    c.desc 'Don\'t add next action tag to new entry'
    c.switch %i[x], negatable: false

    c.desc "Specify the file to which the task should be added"
    c.arg_name "PATH"
    c.flag %i[f file]

    c.desc "Mark task as @done with date"
    c.switch %i[finish done], negatable: false

    c.desc "Search for files X directories deep"
    c.arg_name "DEPTH"
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.action do |global_options, options, args|
      reader = TTY::Reader.new
      append = options[:at] ? options[:at] =~ /^[ae]/i : global_options[:add_at] =~ /^[ae]/

      priority = options[:priority].to_s || "0"
      if priority =~ /^[1-5]$/
        priority = priority.to_i
      elsif priority =~ /^[hml]$/
        priority = NA.priority_map[priority]
      else
        priority = 0
      end

      if NA.global_file
        target = File.expand_path(NA.global_file)
        unless File.exist?(target)
          res = NA.yn(NA::Color.template("#{NA.theme[:warning]}Specified file not found, create it"), default: true)
          if res
            basename = File.basename(target, ".#{NA.extension}")
            NA.create_todo(target, basename, template: global_options[:template])
          else
            NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
          end
        end
      elsif options[:file]
        target = File.expand_path(options[:file])
        unless File.exist?(target)
          res = NA.yn(NA::Color.template("#{NA.theme[:warning]}Specified file not found, create it"), default: true)
          if res
            basename = File.basename(target, ".#{NA.extension}")
            NA.create_todo(target, basename, template: global_options[:template])
          else
            NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
          end
        end
      elsif options[:todo]
        todo = []
        all_req = options[:todo] !~ /[+!\-]/
        options[:todo].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todo.push({
                      token: m["tok"],
                      required: all_req || (!m["req"].nil? && m["req"] == "+"),
                      negate: !m["req"].nil? && m["req"] =~ /[!\-]/,
                    })
        end
        dirs = NA.match_working_dir(todo)
        if dirs.count.positive?
          target = dirs[0]
        else
          todo = "#{options[:todo].sub(/#{NA.extension}$/, "")}.#{NA.extension}"
          target = File.expand_path(todo)
          unless File.exist?(target)
            res = NA.yn(NA::Color.template("#{NA.theme[:warning]}Specified file not found, create #{todo}"), default: true)
            NA.notify("#{NA.theme[:error]}Cancelled{x}", exit_code: 1) unless res

            basename = File.basename(target, ".#{NA.extension}")
            NA.create_todo(target, basename, template: global_options[:template])
          end
        end
      else
        files = NA.find_files(depth: options[:depth])
        if files.count.zero?
          res = NA.yn(NA::Color.template("#{NA.theme[:warning]}No todo file found, create one"), default: true)
          if res
            basename = File.expand_path(".").split("/").last
            target = "#{basename}.#{NA.extension}"
            NA.create_todo(target, basename, template: global_options[:template])
            files = NA.find_files(depth: 1)
          end
        end
        target = files.count > 1 ? NA.select_file(files) : files[0]
        NA.notify("#{NA.theme[:error]}Cancelled{x}", exit_code: 1) unless files.count.positive? && File.exist?(target)
      end

      action = if args.count.positive?
          args.join(" ").strip
        else
          NA.request_input(options, prompt: "Enter a task")
        end

      if action.nil? || action.empty?
        puts "Empty input, cancelled"
        Process.exit 1
      end

      note_rx = /^(.+) \(([^)]+)\)$/
      split_note = if action =~ note_rx
          n = Regexp.last_match(2)
          action.sub!(note_rx, '\1').strip!
          n
        end

      if priority&.to_i&.positive?
        action = "#{action.gsub(/@priority\(\d+\)/, "")} @priority(#{priority})"
      end

      na_tag = NA.na_tag
      if options[:x]
        na_tag = ""
      else
        na_tag = options[:tag] unless options[:tag].nil?
        na_tag = " @#{na_tag}"
      end

      action = "#{action.gsub(/#{na_tag}\b/, "")}#{na_tag}"

      stdin_note = NA.stdin ? NA.stdin.split("\n") : []

      line_note = if options[:note] && $stdin.isatty
          puts stdin_note unless stdin_note.nil?
          if TTY::Which.exist?("gum")
            args = ['--placeholder "Enter additional note, CTRL-d to save"']
            args << "--char-limit 0"
            args << "--width $(tput cols)"
            `gum write #{args.join(" ")}`.strip.split("\n")
          else
            NA.notify("#{NA.theme[:prompt]}Enter a note, {bw}CTRL-d#{NA.theme[:prompt]} to end editing#{NA.theme[:action]}")
            reader.read_multiline
          end
        end

      note = stdin_note.empty? ? [] : stdin_note
      note.<< split_note unless split_note.nil?
      note.concat(line_note) unless line_note.nil?

      # Compute started/done based on flags
      started_at = options[:started]
      started_at = NA::Types.parse_date_begin(started_at) if started_at && !started_at.is_a?(Time)
      done_at = options[:end] || options[:finished]
      done_at = NA::Types.parse_date_end(done_at) if done_at && !done_at.is_a?(Time)
      duration_seconds = options[:duration]

      NA.notify("ADD parsed started_at=#{started_at.inspect} done_at=#{done_at.inspect} duration=#{duration_seconds.inspect}", debug: true)

      # Ensure @started is present in the action text if a start time was provided
      if started_at
        started_str = started_at.strftime('%Y-%m-%d %H:%M')
        # remove any existing @start/@started tag before appending
        action = action.gsub(/(?<=\A| )@start(?:ed)?\(.*?\)/i, '').strip
        action = "#{action} @started(#{started_str})"
      end

      # Resolve TaskPaper-style item path in --to/--project if provided
      project = options[:project]
      if project && project.start_with?('/')
        paths = NA.resolve_item_path(path: project, file: target)
        if paths.count > 1
          choices = paths.map { |p| "#{File.basename(target)}: #{p}" }
          res = NA.choose_from(choices, prompt: 'Select target project', multiple: false)
          if res
            m = res.match(/: (.+)\z/)
            project = m ? m[1] : project
          else
            NA.notify("#{NA.theme[:error]}No project selected, cancelled", exit_code: 1)
          end
        elsif paths.count == 1
          project = paths.first
        end
      end

      NA.add_action(target, project, action, note,
                    finish: options[:finish], append: append,
                    started_at: started_at, done_at: done_at, duration_seconds: duration_seconds)
    end
  end
end
