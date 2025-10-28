# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Update an existing action'
  long_desc 'Provides an easy way to complete, prioritize, and tag existing actions.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick which file to act on.'
  arg_name 'ACTION'
  command %i[update] do |c|
    c.desc 'Run a plugin by name on selected actions'
    c.arg_name 'NAME'
    c.flag %i[plugin]

    c.desc 'Plugin input format (json|yaml|csv|text)'
    c.arg_name 'TYPE'
    c.flag %i[input]

    c.desc 'Plugin output format (json|yaml|csv|text)'
    c.arg_name 'TYPE'
    c.flag %i[output]

    c.desc 'Divider string for text IO'
    c.arg_name 'STRING'
    c.flag %i[divider]
    c.desc 'Started time (natural language or ISO)'
    c.arg_name 'DATE'
    c.flag %i[started], type: :date_begin

    c.desc 'End/Finished time (natural language or ISO)'
    c.arg_name 'DATE'
    c.flag %i[end finished], type: :date_end

    c.desc 'Duration (e.g. 45m, 2h, 1d2h30m, or minutes)'
    c.arg_name 'DURATION'
    c.flag %i[duration], type: :duration
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
    c.flag %i[to move]

    c.desc 'Affect actions from a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[proj project]

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

    c.desc 'Use with --find to find and replace with new text. Enables --exact when used'
    c.arg_name 'TEXT'
    c.flag %i[replace]

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

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

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
      # Ensure all variables used in update loop are declared
      target_proj = if options[:move]
                      options[:move]
                    elsif NA.respond_to?(:cwd_is) && NA.cwd_is == :project
                      NA.cwd
                    end

      priority = options[:priority].to_i if options[:priority]&.to_i&.positive?
      remove_tags = options[:remove] ? options[:remove].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').respond_to?(:wildcard_to_rx) ? t.wildcard_to_rx : t } : []
      remove_tags << 'done' if options[:restore]

      stdin_note = NA.respond_to?(:stdin) && NA.stdin ? NA.stdin.split("\n") : []
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

      append = options[:at] ? options[:at] =~ /^[ae]/i : global_options[:add_at] =~ /^[ae]/i
  add_tags = options[:tag] ? options[:tag].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').respond_to?(:wildcard_to_rx) ? t.wildcard_to_rx : t } : []
      # Build tags array from options[:tagged]
      all_req = options[:tagged].join(' ') !~ /[+!-]/ && !options[:or]
      tags = []
      options[:tagged].join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)
        tags.push({
          tag: m['tag'].respond_to?(:wildcard_to_rx) ? m['tag'].wildcard_to_rx : m['tag'],
          comp: m['op'],
          value: m['val'],
          required: all_req || (!m['req'].nil? && m['req'] == '+'),
          negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
        })
      end
      reader = TTY::Reader.new

      args.concat(options[:search]) unless options[:search].nil?

      append = options[:at] ? options[:at] =~ /^[ae]/i : global_options[:add_at] =~ /^[ae]/i

      if options[:restore] || (!options[:remove].nil? && options[:remove].include?('done'))
        options[:done] = true
        options[:tagged] << '+done'
      elsif !options[:remove].nil? && !options[:remove].empty?
        options[:tagged].concat(options[:remove])
      elsif options[:finish] && !options[:done]
        options[:tagged] << '-done'
      end

      options[:exact] = true unless options[:replace].nil?

      # Check for PATH:LINE format in arguments
      target_file = nil
      target_line = nil
      if args.count.positive?
        pathline_match = args.join(' ').strip.match(/^(.+):(\d+)$/)
        if pathline_match
          target_file = pathline_match[1]
          target_line = pathline_match[2].to_i

          # Verify file exists
          if File.exist?(target_file)
            options[:file] = target_file
            options[:target_line] = target_line
            action = nil  # Skip search processing
          else
            NA.notify("#{NA.theme[:error]}File not found: #{target_file}", exit_code: 1)
          end
        end
      end

      if args.count.positive?
        action = args.join(' ').strip
      else
        action = nil
      end
      tokens = nil
      if action && !action.empty? && !target_line
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

      # If no search query or tags, list all tasks for selection
      if (action.nil? || action.empty?) && options[:tagged].empty?
        tokens = nil # No search, list all
      end

      # Gather all candidate actions for selection
      candidate_actions = []
      targets_for_selection = []
      files = NA.find_files_matching({
        depth: options[:depth],
        done: options[:done],
        project: options[:project],
        regex: options[:regex],
        require_na: false,
        search: tokens,
        tag: tags
      })
      files.each do |file|
        safe_search = (tokens.is_a?(String) || tokens.is_a?(Array) || tokens.is_a?(Regexp)) ? tokens : nil
        todo = NA::Todo.new({
          search: safe_search,
          search_note: options[:search_notes],
          require_na: false,
          file_path: file,
          project: options[:project],
          tag: tags,
          done: options[:done]
        })
        todo.actions.each do |action_obj|
          # Format: filename:LINENUM:parent > action
          # Include line number in display for unique matching
          display = "#{File.basename(action_obj.file_path)}:#{action_obj.file_line}:#{action_obj.parent.join('>')} | #{action_obj.action}"
          candidate_actions << display
          targets_for_selection << { file: action_obj.file_path, line: action_obj.file_line, action: action_obj }
        end
      end

      # Multi-select using fzf or gum if available
      selected_indices = []
      if candidate_actions.any?
        selector = nil
        if TTY::Which.exist?('fzf')
          selector = 'fzf --multi --prompt="Select tasks> "'
        elsif TTY::Which.exist?('gum')
          selector = 'gum choose --no-limit'
        end
        if selector
          require 'open3'
          input = candidate_actions.join("\n")

          # Use popen3 to properly handle stdin for fzf
          Open3.popen3(selector) do |stdin, stdout, stderr, wait_thr|
            stdin.write(input)
            stdin.close

            output = stdout.read

            selected = output.split("\n").map(&:strip).reject(&:empty?)

            # Track which candidates have been matched to avoid duplicates
            selected_indices = []
            candidate_actions.each_index do |i|
              if selected.include?(candidate_actions[i])
                selected_indices << i unless selected_indices.include?(i)
              end
            end
          end
        else
          # Fallback: select all or prompt for search string
          selected_indices = (0...candidate_actions.size).to_a
        end
      end

      # If no actions found, notify and exit
      if selected_indices.empty?
        NA.notify("#{NA.theme[:error]}No matching actions found for selection", exit_code: 1)
      end

      # Apply update to selected actions
      actionable = [
        options[:note],
        (options[:priority].to_i if options[:priority]).to_i.positive?,
        !options[:move].to_s.empty?,
        !(options[:tag].nil? || options[:tag].empty?),
        !(options[:remove].nil? || options[:remove].empty?),
        !options[:replace].to_s.empty?,
        options[:finish],
        options[:archive],
        options[:restore],
        options[:delete],
        options[:edit],
        options[:started],
        (options[:end] || options[:finished]),
        options[:duration]
      ].any?
      unless actionable
        # Interactive menu for actions
        actions_menu = [
          { key: :add_tag, label: 'Add Tag', param: 'Tag' },
          { key: :remove_tag, label: 'Remove Tag', param: 'Tag' },
          { key: :delete, label: 'Delete', param: nil },
          { key: :finish, label: 'Finish (mark done)', param: nil },
          { key: :edit, label: 'Edit', param: nil },
          { key: :priority, label: 'Set Priority', param: 'Priority (1-5)' },
          { key: :move, label: 'Move to Project', param: 'Project' },
          { key: :restore, label: 'Restore', param: nil },
          { key: :archive, label: 'Archive', param: nil },
          { key: :note, label: 'Add Note', param: 'Note' }
        ]
        # Append available plugins
        begin
          NA::Plugins.ensure_plugins_home
          NA::Plugins.list_plugins.each do |_key, path|
            meta = NA::Plugins.parse_plugin_metadata(path)
            disp = meta['name'] || File.basename(path, File.extname(path))
            actions_menu << { key: :_plugin, label: "Plugin: #{disp}", param: nil, plugin_path: path }
          end
        rescue StandardError
          # ignore plugin discovery errors in menu
        end
        selector = nil
        if TTY::Which.exist?('fzf')
          selector = 'fzf --prompt="Select action> "'
        elsif TTY::Which.exist?('gum')
          selector = 'gum choose'
        end
        menu_labels = actions_menu.map { |a| a[:label] }
        selected_action = nil
        if selector
          require 'open3'
          input = menu_labels.join("\n")
          output, _ = Open3.capture2("echo \"#{input.gsub('"', '\"')}\" | #{selector}")
          selected_action = output.strip
        else
          puts 'Select an action:'
          menu_labels.each_with_index { |label, i| puts "#{i+1}. #{label}" }
          idx = (STDIN.gets || '').strip.to_i - 1
          selected_action = menu_labels[idx] if idx >= 0 && idx < menu_labels.size
        end
        action_obj = actions_menu.find { |a| a[:label] == selected_action }
        if action_obj.nil?
          NA.notify("#{NA.theme[:error]}No action selected, cancelled", exit_code: 1)
        end
        # Prompt for parameter if needed
        param_value = nil
        # Only prompt for param if not :move (which has custom menu logic)
        if action_obj[:param] && action_obj[:key] != :move
          if TTY::Which.exist?('gum')
            gum = TTY::Which.which('gum')
            prompt = "Enter #{action_obj[:param]}: "
            param_value = `#{gum} input --placeholder "#{prompt}"`.strip
          else
            print "Enter #{action_obj[:param]}: "
            param_value = (STDIN.gets || '').strip
          end
        end
        # Set options for update
        case action_obj[:key]
        when :add_tag
          options[:tag] = [param_value]
        when :remove_tag
          options[:remove] = [param_value]
        when :delete
          options[:delete] = true
        when :finish
          options[:finish] = true
          # Timed finish? Prompt user for optional start/date inputs
          if NA.yn(NA::Color.template("#{NA.theme[:prompt]}Timed?"), default: false)
            # Ask for start date expression
            start_expr = nil
            if TTY::Which.exist?('gum')
              gum = TTY::Which.which('gum')
              prompt = 'Enter start date/time (e.g. "30 minutes ago" or "3pm"):'
              start_expr = `#{gum} input --placeholder "#{prompt}"`.strip
            else
              print 'Enter start date/time (e.g. "30 minutes ago" or "3pm"): '
              start_expr = (STDIN.gets || '').strip
            end
            start_time = NA::Types.parse_date_begin(start_expr)
            options[:started] = start_time if start_time
          end
        when :edit
          # Just set the flag - multi-action editor will handle it below
          options[:edit] = true
        when :priority
          options[:priority] = param_value
        when :move
          # Gather projects from the same file as the selected action
          selected_file = targets_for_selection[selected_indices.first][:file]
          todo = NA::Todo.new(file_path: selected_file)
          project_names = todo.projects.map { |proj| proj.project }
          project_menu = project_names + ['New project']
          move_selector = nil
          if TTY::Which.exist?('fzf')
            move_selector = 'fzf --prompt="Select project> "'
          elsif TTY::Which.exist?('gum')
            move_selector = 'gum choose'
          end
          selected_project = nil
          if move_selector
            require 'open3'
            input = project_menu.join("\n")
            output, _ = Open3.capture2("echo \"#{input.gsub('"', '\"')}\" | #{move_selector}")
            selected_project = output.strip
          else
            puts 'Select a project:'
            project_menu.each_with_index { |label, i| puts "#{i+1}. #{label}" }
            idx = (STDIN.gets || '').strip.to_i - 1
            selected_project = project_menu[idx] if idx >= 0 && idx < project_menu.size
          end
          if selected_project == 'New project'
            if TTY::Which.exist?('gum')
              gum = TTY::Which.which('gum')
              prompt = 'Enter new project name: '
              new_proj_name = `#{gum} input --placeholder "#{prompt}"`.strip
            else
              print 'Enter new project name: '
              new_proj_name = (STDIN.gets || '').strip
            end
            # Create the new project in the file
            NA.insert_project(selected_file, new_proj_name, todo.projects)
            options[:move] = new_proj_name
          else
            options[:move] = selected_project
          end
        when :restore
          options[:restore] = true
        when :archive
          options[:archive] = true
        when :note
          options[:note] = true
          note = [param_value]
        when :_plugin
          # Set plugin path directly
          options[:plugin] = action_obj[:plugin_path]
        end
      end
      did_direct_update = false

      # Group selected actions by file for batch processing
      actions_by_file = {}
      selected_indices.each do |idx|
        file = targets_for_selection[idx][:file]
        actions_by_file[file] ||= []
        actions_by_file[file] << targets_for_selection[idx][:action]
      end

      # If a plugin is specified, run it on all selected actions and apply results
      if options[:plugin]
        plugin_path = options[:plugin]
        unless File.exist?(plugin_path)
          # Resolve by name via registry
          resolved = NA::Plugins.resolve_plugin(plugin_path)
          plugin_path = resolved if resolved
        end
        meta = NA::Plugins.parse_plugin_metadata(plugin_path)
        input_fmt = (options[:input] || meta['input'] || 'json').to_s
        output_fmt = (options[:output] || meta['output'] || input_fmt).to_s
        divider = (options[:divider] || '||')

        all_actions = []
        actions_by_file.each_value { |list| all_actions.concat(list) }
        io_actions = all_actions.map(&:to_plugin_io_hash)
        stdin_str = NA::Plugins.serialize_actions(io_actions, format: input_fmt, divider: divider)
        stdout = NA::Plugins.run_plugin(plugin_path, stdin_str)
        returned = NA::Plugins.parse_actions(stdout, format: output_fmt, divider: divider)
        Array(returned).each { |h| NA.apply_plugin_result(h) }
        did_direct_update = true
        next
      end

      # Process each file's actions (non-plugin paths)
      actions_by_file.each do |file, action_list|
        # Rebuild all derived variables from options after menu-driven assignment
        add_tags = options[:tag] ? options[:tag].join(',').split(/ *, */).map { |t| t.sub(/^@/, '') } : []
        remove_tags = options[:remove] ? options[:remove].join(',').split(/ *, */).map { |t| t.sub(/^@/, '') } : []
        remove_tags << 'done' if options[:restore]
        priority = options[:priority].to_i if options[:priority]&.to_i&.positive?
        target_proj = if options[:move]
                        options[:move]
                      elsif NA.respond_to?(:cwd_is) && NA.cwd_is == :project
                        NA.cwd
                      end
        note_val = note
        if options[:note] && defined?(param_value) && param_value
          note_val = [param_value]
        end

        # Handle edit with multiple actions
        if options[:edit]
          # Open editor once with all actions for this file
          editor_content = NA::Editor.format_multi_action_input(action_list)
          edited_content = NA::Editor.fork_editor(editor_content)
          edited_actions = NA::Editor.parse_multi_action_output(edited_content)

          # If markers were removed but we have the same number of actions, match by position
          if edited_actions.empty? && action_list.size > 0
            # Parse content line by line, skipping comments and blanks
            non_comment_lines = edited_content.lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') }

            # Match each non-comment line to an action by position
            action_list.each_with_index do |action_obj, idx|
              if non_comment_lines[idx]
                # Split into action and notes
                lines = non_comment_lines[idx..-1]
                action_text = lines[0]
                note_lines = lines[1..-1] || []

                # Store by file:line key
                key = "#{action_obj.file_path}:#{action_obj.file_line}"
                edited_actions[key] = [action_text, note_lines]
              end
            end
          end

          # Update each action with edited content
          action_list.each do |action_obj|
            key = "#{action_obj.file_path}:#{action_obj.file_line}"
            if edited_actions[key]
              action_obj.action, action_obj.note = edited_actions[key]
            end
          end
        end

        # Update each action (process from bottom to top to avoid line shifts)
        action_list.sort_by(&:file_line).reverse.each do |action_obj|
          NA.update_action(file, nil,
            add: action_obj,
            add_tag: add_tags,
            all: true,
            append: append,
            delete: options[:delete],
            done: options[:done],
            edit: false,  # Already handled above
            finish: options[:finish],
            move: target_proj,
            note: note_val,
            overwrite: options[:overwrite],
            priority: priority,
            project: options[:project],
            remove_tag: remove_tags,
            replace: options[:replace],
            search_note: options[:search_notes],
            tagged: nil)
        end
        did_direct_update = true
      end
      if did_direct_update
        next
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
                      gum = TTY::Which.which('gum')
                      `#{gum} write #{args.join(' ')}`.strip.split("\n")
                    else
                      NA.notify("#{NA.theme[:prompt]}Enter a note, {bw}CTRL-d#{NA.theme[:prompt]} to end editing:#{NA.theme[:action]}")
                      reader.read_multiline
                    end
                  end

      note = stdin_note.empty? ? [] : stdin_note
      note.concat(line_note) unless line_note.nil? || line_note.empty?

      # Require at least one actionable option to be provided
      actionable = [
        options[:note],
        (options[:priority].to_i if options[:priority]).to_i.positive?,
        !options[:move].to_s.empty?,
        !(options[:tag].nil? || options[:tag].empty?),
        !(options[:remove].nil? || options[:remove].empty?),
        !options[:replace].to_s.empty?,
        options[:finish],
        options[:archive],
        options[:restore],
        options[:delete],
        options[:edit]
      ].any?

      NA.notify("#{NA.theme[:error]}No action specified, see `na help update`", exit_code: 1) unless actionable

      target_proj = if options[:move]
                      options[:move]
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
                                         project: options[:project],
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
        options[:move] = 'Archive'
      end

      NA.notify("#{NA.theme[:error]}No search terms provided", exit_code: 1) if tokens.nil? && options[:tagged].empty?

      # Handle target_line if provided (from PATH:LINE format)
      search_tokens = if options[:target_line]
                       { target_line: options[:target_line] }
                     else
                       tokens
                     end

      targets.each do |target|
        NA.update_action(target, search_tokens,
                         add_tag: add_tags,
                         all: options[:all],
                         append: append,
                         delete: options[:delete],
                         done: options[:done],
                         edit: options[:edit],
                         finish: options[:finish],
                         move: target_proj,
                         note: note,
                         overwrite: options[:overwrite],
                         priority: priority,
                         project: options[:project],
                         remove_tag: remove_tags,
                         replace: options[:replace],
                         search_note: options[:search_notes],
                         tagged: tags,
                         started_at: options[:started],
                         done_at: (options[:end] || options[:finished]),
                         duration_seconds: options[:duration])
      end
    end
  end
end
