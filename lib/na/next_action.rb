# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    attr_accessor :verbose, :extension, :include_ext, :na_tag, :command_line, :command, :globals, :global_file,
                  :cwd_is, :cwd, :stdin, :show_cwd_indicator

    # Select actions across files using existing search pipeline
    # @return [Array<NA::Action>]
    def select_actions(file: nil, depth: 1, search: [], tagged: [], include_done: false)
      files = if file
                [file]
              else
                find_files(depth: depth)
              end
      out = []
      files.each do |f|
        _projects, actions = find_actions(f, search, tagged, done: include_done, all: true)
        out.concat(actions) if actions
      end
      out
    end

    # Apply a plugin result hash back to the underlying file
    # - Move if parents changed (project path differs)
    # - Update text/note/tags
    def apply_plugin_result(io_hash)
      file = io_hash['file_path']
      line = io_hash['line'].to_i
      parents = Array(io_hash['parents']).map(&:to_s)
      text = io_hash['text'].to_s
      note = io_hash['note'].to_s
      tags = Array(io_hash['tags']).to_h { |t| [t['name'].to_s, t['value'].to_s] }
      action_block = io_hash['action'] || { 'action' => 'UPDATE', 'arguments' => [] }
      action_name = action_block['action'].to_s.upcase
      action_args = Array(action_block['arguments'])

      # Load current action
      _projects, actions = find_actions(file, nil, nil, all: true, done: true, project: nil, search_note: true, target_line: line)
      action = actions&.first
      return unless action

      # Determine new project path from parents array
      new_project = ''
      new_parent_chain = []
      if parents.any?
        new_project = parents.first.to_s
        new_parent_chain = parents[1..] || []
      end

      case action_name
      when 'DELETE'
        update_action(file, { target_line: line }, delete: true, all: true)
        return
      when 'COMPLETE'
        update_action(file, { target_line: line }, finish: true, all: true)
        return
      when 'RESTORE'
        update_action(file, { target_line: line }, restore: true, all: true)
        return
      when 'ARCHIVE'
        update_action(file, { target_line: line }, finish: true, move: 'Archive', all: true)
        return
      when 'ADD_TAG'
        add_tags = action_args.map { |t| t.sub(/^@/, '') }
        update_action(file, { target_line: line }, add: action, add_tag: add_tags, all: true)
        return
      when 'DELETE_TAG', 'REMOVE_TAG'
        remove_tags = action_args.map { |t| t.sub(/^@/, '') }
        update_action(file, { target_line: line }, add: action, remove_tag: remove_tags, all: true)
        return
      when 'MOVE'
        move_to = action_args.first.to_s
        update_action(file, { target_line: line }, add: action, move: move_to, all: true, suppress_prompt: true)
        return
      end

      # Replace content on the existing action then write back in-place
      original_line = action.file_line
      original_project = action.project
      original_parent_chain = action.parent.dup

      # Update action content
      action.action = text
      action.note = note.to_s.split("\n")
      action.action.gsub!(/(?<=\A| )@\S+(?:\(.*?\))?/, '')
      unless tags.empty?
        tag_str = tags.map { |k, v| v.to_s.empty? ? "@#{k}" : "@#{k}(#{v})" }.join(' ')
        action.action = action.action.strip + (tag_str.empty? ? "" : " #{tag_str}")
      end

      # Check if parents changed
      parents_changed = new_project.to_s.strip != original_project || new_parent_chain != original_parent_chain
      move_to = parents_changed ? ([new_project] + new_parent_chain).join(':') : nil

      # Update in-place (with move if parents changed)
      update_action(file, { target_line: original_line }, add: action, move: move_to, all: true, suppress_prompt: true)
    end
    include NA::Editor

    # Returns the current theme hash for color and style settings.
    # @return [Hash] The theme settings
    def theme
      @theme ||= NA::Theme.load_theme
    end

    # Print a message to stderr, optionally exit or debug.
    # @param msg [String] The message to print
    # @param exit_code [Integer, Boolean] Exit code or false for no exit
    # @param debug [Boolean] Only print if verbose
    # @return [void]
    def notify(msg, exit_code: false, debug: false)
      return if debug && !NA.verbose

      if debug
        warn NA::Color.template("{x}#{NA.theme[:debug]}#{msg}{x}")
      else
        warn NA::Color.template("{x}#{msg}{x}")
      end
      Process.exit exit_code if exit_code
    end

    # Returns a map of priority levels to numeric values.
    # @return [Hash{String=>Integer}] Priority mapping
    def priority_map
      {
        'h' => 5,
        'm' => 3,
        'l' => 1
      }
    end

    #
    # Display and read a Yes/No prompt
    #
    # @param      prompt   [String] The prompt string
    # @param      default  [Boolean] default value if
    #                      return is pressed or prompt is
    #                      skipped
    #
    # @return     [Boolean] result
    #
    def yn(prompt, default: true)
      return default if ENV['NA_TEST'] == '1'
      return default unless $stdout.isatty

      tty_state = `stty -g`
      system 'stty raw -echo cbreak isig'
      yn = color_single_options(default ? %w[Y n] : %w[y N])
      $stdout.syswrite "\e[1;37m#{prompt} #{yn}\e[1;37m? \e[0m"
      res = $stdin.sysread 1
      res.chomp!
      puts
      system 'stty cooked'
      system "stty #{tty_state}"
      res.empty? ? default : res =~ /y/i
    end

    #
    # Helper function to colorize the Y/N prompt
    #
    # @param      choices  [Array] The choices with
    #                      default capitalized
    #
    # @return     [String] colorized string
    #
    def color_single_options(choices = %w[y n])
      out = []
      choices.each do |choice|
        case choice
        when /[A-Z]/
          out.push(NA::Color.template("{bw}#{choice}{x}"))
        else
          out.push(NA::Color.template("{dw}#{choice}{xg}"))
        end
      end
      NA::Color.template("{xg}[#{out.join('/')}{xg}]{x}")
    end

    #
    # Create a new todo file
    #
    # @param      target    [String] The target path
    # @param      basename  [String] The project base name
    #
    def create_todo(target, basename, template: nil)
      File.open(target, 'w') do |f|
        content = if template && File.exist?(template)
                    File.read(template)
                  else
                    <<~ENDCONTENT
                      Inbox:
                      #{basename}:
                      \tFeature Requests:
                      \tIdeas:
                      \tBugs:
                      Archive:
                      Search Definitions:
                      \tTop Priority @search(@priority = 5 and not @done)
                      \tHigh Priority @search(@priority > 3 and not @done)
                      \tMaybe @search(@maybe)
                      \tNext @search(@#{NA.na_tag} and not @done and not project = "Archive")
                    ENDCONTENT
                  end
        f.puts(content)
      end
      save_working_dir(target)
      notify("#{NA.theme[:warning]}Created #{NA.theme[:file]}#{target}")
    end

    # Select from multiple files
    #
    # If `gum` or `fzf` are available, they'll be used (in that order).
    #
    # @param files [Array<String>] The files to select from
    # @param multiple [Boolean] Allow multiple selections
    # @return [String, Array<String>] Selected file(s)
    def select_file(files, multiple: false)
      res = choose_from(files, prompt: multiple ? 'Select files' : 'Select a file', multiple: multiple)
      if res.nil? || res == false || (res.respond_to?(:length) && res.empty?)
        notify("#{NA.theme[:error]}No file selected, cancelled", exit_code: 1)
        return nil
      end
      if multiple
        res
      else
        res.is_a?(Array) ? res.first : res
      end
    end

    # Shift project indices after a given index by a length.
    # @param projects [Array<NA::Project>] Projects to shift
    # @param idx [Integer] Index after which to shift
    # @param length [Integer] Amount to shift
    # @return [Array<NA::Project>] Shifted projects
    def shift_index_after(projects, idx, length = 1)
      projects.map do |proj|
        proj.line = proj.line - length if proj.line > idx
        proj.last_line = proj.last_line - length if proj.last_line > idx

        proj
      end
    end

    # Find all projects in a todo file
    #
    # @param target [String] Path to the todo file
    # @return [Array<NA::Project>] List of projects
    def find_projects(target)
      todo = NA::Todo.new(require_na: false, file_path: target)
      todo.projects
    end

    # Find actions in a todo file matching criteria
    #
    # @param target [String] Path to the todo file
    # @param search [String, nil] Search string
    # @param tagged [String, nil] Tag to filter
    # @param all [Boolean] Return all actions
    # @param done [Boolean] Include done actions
    # @param project [String, nil] Project name
    # @param search_note [Boolean] Search notes
    # @param target_line [Integer] Specific line number to target
    # @return [Array] Projects and actions
    def find_actions(target, search, tagged = nil, all: false, done: false, project: nil, search_note: true, target_line: nil)
      todo = NA::Todo.new({ search: search,
                            search_note: search_note,
                            require_na: false,
                            file_path: target,
                            project: project,
                            tag: tagged,
                            done: done })

      unless todo.actions.any?
        NA.notify("#{NA.theme[:error]}No matching actions found in #{File.basename(target,
                                                                                   ".#{NA.extension}").highlight_filename}")
        return [todo.projects, NA::Actions.new]
      end

      return [todo.projects, todo.actions] if todo.actions.one? || all

      # If target_line is specified, find the action at that specific line
      if target_line
        matching_action = todo.actions.find { |a| a.line == target_line }
        return [todo.projects, NA::Actions.new([matching_action])] if matching_action

        NA.notify("#{NA.theme[:error]}No action found at line #{target_line}", exit_code: 1)
        return [todo.projects, NA::Actions.new]

      end

      options = todo.actions.map { |action| "#{action.file} : #{action.action}" }
      res = choose_from(options, prompt: 'Make a selection: ', multiple: true, sorted: true)

      unless res&.length&.positive?
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
        return [todo.projects, NA::Actions.new]
      end

      selected = NA::Actions.new
      res.each do |result|
        # Extract file:line from result (e.g., "./todo.taskpaper:21 : action text")
        match = result.match(/^(.+?):(\d+) : /)
        next unless match

        file_path = match[1]
        line_num = match[2].to_i
        action = todo.actions.select { |a| a.file_path == file_path && a.file_line == line_num }.first
        selected.push(action) if action
      end
      [todo.projects, selected]
    end

    # Insert a new project into a todo file
    #
    # @param target [String] Path to the todo file
    # @param project [String] Project name
    # @return [NA::Project] The new project
    def insert_project(target, project)
      path = project.split(%r{[:/]})
      todo = NA::Todo.new(file_path: target)
      built = []
      last_match = nil
      final_match = nil
      new_path = []
      matches = nil
      path.each_with_index do |part, i|
        built.push(part)
        built_path = built.join(':')
        matches = todo.projects.select { |proj| proj.project =~ /^#{Regexp.escape(built_path)}/i }
        exact_match = matches.find { |proj| proj.project.casecmp(built_path).zero? }
        if exact_match
          last_match = exact_match
        else
          final_match = last_match
          new_path = path.slice(i, path.count - i)
          break
        end
      end

      content = target.read_file
      if final_match.nil?
        indent = 0
        input = []

        new_path.each do |part|
          input.push("#{"\t" * indent}#{part.cap_first}:")
          indent += 1
        end

        if new_path.join =~ /Archive/i
          line = todo.projects.last&.last_line || 0
          content = content.split("\n").insert(line, input.join("\n")).join("\n")
        else
          split = content.split("\n")
          line = todo.projects.first&.line || 0
          before = split.slice(0, line).join("\n")
          after = split.slice(line, split.count - 0).join("\n")
          content = "#{before}\n#{input.join("\n")}\n#{after}"
        end

        new_project = NA::Project.new(path.map(&:cap_first).join(':'), indent - 1, line, line)
      else
        line = final_match.last_line + 1
        indent = final_match.indent + 1
        input = []
        new_path.each do |part|
          input.push("#{"\t" * indent}#{part.cap_first}:")
          indent += 1
        end
        content = content.split("\n").insert(line, input.join("\n")).join("\n")
        new_project = NA::Project.new(path.map(&:cap_first).join(':'), indent - 1, line + input.count - 1,
                                      line + input.count - 1)
      end

      File.open(target, 'w') do |f|
        f.puts content
      end

      new_project
    end

    # Update actions in a todo file (add, edit, delete, move, etc.)
    #
    # @param target [String] Path to the todo file
    # @param search [String, nil] Search string
    # @param search_note [Boolean] Search notes
    # @param add [Action, nil] Action to add
    # @param add_tag [Array<String>] Tags to add
    # @param all [Boolean] Update all matching actions
    # @param append [Boolean] Append to project
    # @param delete [Boolean] Delete matching actions
    # @param done [Boolean] Mark as done
    # @param edit [Boolean] Edit matching actions
    # @param finish [Boolean] Mark as finished
    # @param note [Array<String>] Notes to add
    # @param overwrite [Boolean] Overwrite notes
    # @param priority [Integer] Priority value
    # @param project [String, nil] Project name
    # @param move [String, nil] Move to project
    # @param remove_tag [Array<String>] Tags to remove
    # @param replace [String, nil] Replacement text
    # @param tagged [String, nil] Tag to filter
    # @return [void]
    def update_action(target,
                      search,
                      search_note: true,
                      add: nil,
                      add_tag: [],
                      all: false,
                      append: false,
                      delete: false,
                      done: false,
                      edit: false,
                      finish: false,
                      note: [],
                      overwrite: false,
                      priority: 0,
                      project: nil,
                      move: nil,
                      remove_tag: [],
                      replace: nil,
                      tagged: nil,
                      started_at: nil,
                      done_at: nil,
                      duration_seconds: nil,
                      suppress_prompt: false)
      # Coerce date/time inputs if passed as strings
      begin
        started_at = NA::Types.parse_date_begin(started_at) if started_at && !started_at.is_a?(Time)
      rescue StandardError
        # leave as-is
      end
      begin
        done_at = NA::Types.parse_date_end(done_at) if done_at && !done_at.is_a?(Time)
      rescue StandardError
        # leave as-is
      end
      NA.notify("UPDATE parsed started_at=#{started_at.inspect} done_at=#{done_at.inspect} duration=#{duration_seconds.inspect}", debug: true)
      # Expand target to absolute path to avoid path resolution issues
      target = File.expand_path(target) unless Pathname.new(target).absolute?

      projects = find_projects(target)
      affected_actions = []

      target_proj = nil

      if move
        move = move.sub(/:$/, '')
        target_proj = projects.select { |pr| pr.project =~ /#{move.gsub(':', '.*?:.*?')}/i }.first
        if target_proj.nil?
          if suppress_prompt || !$stdout.isatty
            target_proj = insert_project(target, move)
            projects << target_proj
          else
            res = NA.yn(
              NA::Color.template("#{NA.theme[:warning]}Project #{NA.theme[:file]}#{move}#{NA.theme[:warning]} doesn't exist, add it"), default: true
            )
            if res
              target_proj = insert_project(target, move)
              projects << target_proj
            else
              NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
            end
          end
        end
      end

      contents = target.read_file.split("\n")

      if add.is_a?(Action)
        # NOTE: Edit is handled in the update command before calling update_action
        # So we don't need to handle it here - the action is already edited

        add_tag ||= []
        NA.notify("PROCESS before add.process started_at=#{started_at.inspect} done_at=#{done_at.inspect}", debug: true)
        add.process(priority: priority,
                    finish: finish,
                    add_tag: add_tag,
                    remove_tag: remove_tag,
                    started_at: started_at,
                    done_at: done_at,
                    duration_seconds: duration_seconds)
        NA.notify("PROCESS after add.process action=\"#{add.action}\"", debug: true)

        # Remove the original action and its notes if this is an existing action
        action_line = add.file_line
        note_lines = add.note.is_a?(Array) ? add.note.count : 0
        contents.slice!(action_line, note_lines + 1) if action_line.is_a?(Integer)

        # Prepare updated note
        note = note.to_s.split("\n") unless note.is_a?(Array)
        updated_note = if note.empty?
                         add.note
                       else
                         overwrite ? note : add.note.concat(note)
                       end

        # Prepare indentation
        projects = find_projects(target)
        # If move is set, update add.parent to the target project
        add.parent = target_proj.project.split(':') if move && target_proj
        project_path = add.parent.join(':')
        target_proj ||= projects.select { |proj| proj.project =~ /^#{project_path}$/i }.first

        if target_proj.nil? && !project_path.empty?
          display_path = project_path.tr(':', '/')
          prompt = NA::Color.template(
            "#{NA.theme[:warning]}Project #{NA.theme[:file]}#{display_path}#{NA.theme[:warning]} doesn't exist, create it?"
          )
          should_create = NA.yn(prompt, default: true)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless should_create

          created_proj = insert_project(target, project_path)
          contents = target.read_file.split("\n")
          projects = find_projects(target)
          target_proj = projects.select { |proj| proj.project =~ /^#{project_path}$/i }.first || created_proj
        end

        add.parent = target_proj.project.split(':') if target_proj
        indent = target_proj ? ("\t" * target_proj.indent) : ''

        # Format note for insertion
        note_str = updated_note.empty? ? '' : "\n#{indent}\t\t#{updated_note.join("\n#{indent}\t\t").strip}"

        # If delete was requested in this direct update path, do not re-insert
        if delete
          affected_actions << { action: add, desc: 'deleted' }
        else
          # Insert at correct location
          if target_proj
            insert_line = if append
                            # End of project
                            target_proj.last_line + 1
                          else
                            # Start of project (after project header)
                            target_proj.line + 1
                          end
            # Ensure @started tag persists if provided
            final_action = add.action.dup
            if started_at && final_action !~ /(?<=\A| )@start(?:ed)?\(/i
              final_action = final_action.gsub(/(?<=\A| )@start(?:ed)?\(.*?\)/i, '').strip
              final_action = "#{final_action} @started(#{started_at.strftime('%Y-%m-%d %H:%M')})"
            end
            NA.notify("INSERT at #{insert_line} final_action=\"#{final_action}\"", debug: true)
            contents.insert(insert_line, "#{indent}\t- #{final_action}#{note_str}")
          else
            # Fallback: append to end of file
            final_action = add.action.dup
            if started_at && final_action !~ /(?<=\A| )@start(?:ed)?\(/i
              final_action = final_action.gsub(/(?<=\A| )@start(?:ed)?\(.*?\)/i, '').strip
              final_action = "#{final_action} @started(#{started_at.strftime('%Y-%m-%d %H:%M')})"
            end
            NA.notify("APPEND final_action=\"#{final_action}\"", debug: true)
            contents << "#{indent}\t- #{final_action}#{note_str}"
          end

          notify(add.pretty)
        end

        # Track affected action and description
        unless delete
          changes = ['updated']
          changes << 'finished' if finish
          changes << "priority=#{priority}" if priority.to_i.positive?
          changes << "tags+#{add_tag.join(',')}" unless add_tag.nil? || add_tag.empty?
          changes << "tags-#{remove_tag.join(',')}" unless remove_tag.nil? || remove_tag.empty?
          changes << 'note updated' unless note.nil? || note.empty?
          changes << "moved to #{target_proj.project}" if move && target_proj
          affected_actions << { action: add, desc: changes.join(', ') }
        end
      else
        # Check if search is actually target_line
        target_line = search.is_a?(Hash) && search[:target_line] ? search[:target_line] : nil
        _, actions = find_actions(target, search, tagged, done: done, all: all, project: project,
                                                          search_note: search_note, target_line: target_line)

        return if actions.nil?

        # Handle edit (single or multi-action)
        if edit
          editor_content = Editor.format_multi_action_input(actions)
          edited_content = Editor.fork_editor(editor_content)
          edited_actions = Editor.parse_multi_action_output(edited_content)

          # Map edited content back to actions
          actions.each do |action|
            # Use file_path:file_line as the key
            key = "#{action.file_path}:#{action.file_line}"
            action.action, action.note = edited_actions[key] if edited_actions[key]
          end
        end

        actions.sort_by(&:file_line).reverse.each do |action|
          contents.slice!(action.file_line, action.note.count + 1)
          if delete
            # Track deletion before skipping re-insert
            affected_actions << { action: action, desc: 'deleted' }
            next
          end

          projects = shift_index_after(projects, action.file_line, action.note.count + 1)

          # If replace is defined, use search to search and replace text in action
          action.action.sub!(Regexp.new(Regexp.escape(search), Regexp::IGNORECASE), replace) if replace

          action.process(priority: priority,
                         finish: finish,
                         add_tag: add_tag,
                         remove_tag: remove_tag,
                         started_at: started_at,
                         done_at: done_at,
                         duration_seconds: duration_seconds)

          target_proj = if target_proj
                          projects.select { |proj| proj.project =~ /^#{target_proj.project}$/ }.first
                        else
                          projects.select { |proj| proj.project =~ /^#{action.parent.join(':')}$/ }.first
                        end

          indent = "\t" * target_proj.indent
          note = note.split("\n") unless note.is_a?(Array)
          note = if note.empty?
                   action.note
                 else
                   overwrite ? note : action.note.concat(note)
                 end
          note = note.empty? ? '' : "\n#{indent}\t\t#{note.join("\n#{indent}\t\t").strip}"

          if append
            this_idx = 0
            projects.each_with_index do |proj, idx|
              if proj.line == target_proj.line
                this_idx = idx
                break
              end
            end

            target_line = if this_idx == projects.length - 1
                            contents.count
                          else
                            projects[this_idx].last_line + 1
                          end
          else
            target_line = target_proj.line + 1
          end

          contents.insert(target_line, "#{indent}\t- #{action.action}#{note}")

          notify(action.pretty)

          # Track affected action and description
          changes = []
          changes << 'finished' if finish
          changes << 'edited' if edit
          changes << "priority=#{priority}" if priority.to_i.positive?
          changes << "tags+#{add_tag.join(',')}" unless add_tag.nil? || add_tag.empty?
          changes << "tags-#{remove_tag.join(',')}" unless remove_tag.nil? || remove_tag.empty?
          changes << 'text replaced' if replace
          changes << "moved to #{target_proj.project}" if target_proj
          changes << 'note updated' unless note.nil? || note.empty?
          changes = ['updated'] if changes.empty?
          affected_actions << { action: action, desc: changes.join(', ') }
        end
      end

      backup_file(target)
      File.open(target, 'w') { |f| f.puts contents.join("\n") }

      if affected_actions.any?
        if affected_actions.all? { |e| e[:desc] =~ /^deleted/ }
          notify("#{NA.theme[:success]}Task deleted in #{NA.theme[:filename]}#{target}")
        elsif add
          notify("#{NA.theme[:success]}Task added to #{NA.theme[:filename]}#{target}")
        else
          notify("#{NA.theme[:success]}Task updated in #{NA.theme[:filename]}#{target}")
        end

        affected_actions.reverse.each do |entry|
          action_color = delete ? NA.theme[:error] : NA.theme[:success]
          notify("  #{entry[:action].to_s_pretty} — #{action_color}#{entry[:desc]}")
        end
      elsif add
        notify("#{NA.theme[:success]}Task added to #{NA.theme[:filename]}#{target}")
      else
        notify("#{NA.theme[:success]}Task updated in #{NA.theme[:filename]}#{target}")
      end
    end

    # Add an action to a todo file
    #
    # @param file [String] Path to the todo file
    # @param project [String] Project name
    # @param action [String] Action text
    # @param note [Array<String>] Notes
    # @param priority [Integer] Priority value
    # @param finish [Boolean] Mark as finished
    # @param append [Boolean] Append to project
    # @return [void]
    def add_action(file, project, action, note = [], priority: 0, finish: false, append: false, started_at: nil, done_at: nil, duration_seconds: nil)
      parent = project.split(%r{[:/]})
      file_project = File.basename(file, ".#{NA.extension}")

      if NA.global_file
        if NA.cwd_is == :tag
          add_tag = [NA.cwd]
        else
          project = NA.cwd
        end
      end

      action = Action.new(file, file_project, parent, action, nil, note)

      update_action(file, nil,
                    add: action,
                    project: project,
                    add_tag: add_tag,
                    priority: priority,
                    finish: finish,
                    append: append,
                    started_at: started_at,
                    done_at: done_at,
                    duration_seconds: duration_seconds)
    end

    # Build a nested hash representing project hierarchy from actions
    #
    # @param actions [Array<Action>] List of actions
    # @return [Hash] Nested hierarchy
    def project_hierarchy(actions)
      parents = { actions: [] }
      actions.each do |a|
        parent = a.parent
        current_parent = parents
        parent.each do |par|
          current_parent[par] = { actions: [] } unless current_parent.key?(par)
          current_parent = current_parent[par]
        end

        current_parent[:actions].push(a)
      end
      parents
    end

    # Output an Omnifocus-friendly action list
    #
    # @param      children  The children
    # @param      level     The indent level
    #
    def output_children(children, level = 1)
      out = []
      indent = "\t" * level
      return out if children.nil? || children.empty?

      children.each do |k, v|
        if k.to_s =~ /actions/
          indent += "\t"
          v&.each do |a|
            item = "#{indent}- #{a.action}"
            unless a.tags.nil? || a.tags.empty?
              tags = []
              a.tags.each do |key, val|
                next if key =~ /^(due|flagged|done)$/

                tag = key
                tag += "-#{val}" unless val.nil? || val.empty?
                tags.push(tag)
              end
              item += " @tags(#{tags.join(',')})" unless tags.empty?
            end
            item += "\n#{indent}\t#{a.note.join("\n#{indent}\t")}" unless a.note.empty?
            out.push(item)
          end
        else
          out.push("#{indent}#{k}:")
          out.concat(output_children(v, level + 1))
        end
      end
      out
    end

    # Open a file in the specified editor/application
    #
    # @param file [String, nil] Path to the file
    # @param app [String, nil] Application to use
    # @return [void]
    def edit_file(file: nil, app: nil)
      os_open(file, app: app) if file && File.exist?(file)
    end

    # Locate files matching NA.extension up to a given depth
    #
    # @param depth [Integer] The depth at which to search
    # @param include_hidden [Boolean] Whether to include hidden directories/files
    # @return [Array<String>] List of matching file paths
    def find_files(depth: 1, include_hidden: false)
      NA::Benchmark.measure("find_files (depth=#{depth})") do
        return [NA.global_file] if NA.global_file

        # Build a brace-expanded pattern list covering 1..depth levels, e.g.:
        # depth=1 -> "*.ext"
        # depth=3 -> "{*.ext,*/*.ext,*/*/*.ext}"
        ext = NA.extension
        patterns = (1..[depth.to_i, 1].max).map do |d|
          prefix = d > 1 ? ('*/' * (d - 1)) : ''
          "#{prefix}*.#{ext}"
        end
        pattern = patterns.length == 1 ? patterns.first : "{#{patterns.join(',')}}"

        files = Dir.glob(pattern, File::FNM_DOTMATCH)
        # Exclude hidden directories/files unless explicitly requested
        unless include_hidden
          files.reject! do |f|
            # reject any path segment beginning with '.' (excluding '.' and '..')
            f.split('/').any? { |seg| seg.start_with?('.') && seg !~ /^\.\.?$/ }
          end
        end
        files.map! { |f| f.sub(%r{\A\./}, '') }
        files.each { |f| save_working_dir(File.expand_path(f)) }
        files.uniq
      end
    end

    # Find files matching criteria and containing actions.
    # @param options [Hash] Options for file search
    # @option options [Integer] :depth Search depth
    # @option options [Boolean] :done Include done actions
    # @option options [String] :file_path File path
    # @option options [Boolean] :negate Negate search
    # @option options [Boolean] :hidden Include hidden files
    # @option options [String] :project Project name
    # @option options [String] :query Query string
    # @option options [Boolean] :regex Use regex
    # @option options [String] :search Search string
    # @option options [String] :tag Tag to filter
    # @return [Array<String>] Matching files
    def find_files_matching(options = {})
      defaults = {
        depth: 1,
        done: false,
        file_path: nil,
        negate: false,
        hidden: false,
        project: nil,
        query: nil,
        regex: false,
        search: nil,
        tag: nil
      }
      options = defaults.merge(options)
      files = find_files(depth: options[:depth], include_hidden: options[:hidden])
      return [] if files.nil? || files.empty?

      files.delete_if do |file|
        cmd_options = {
          depth: options[:depth],
          done: options[:done],
          file_path: file,
          negate: options[:negate],
          project: options[:project],
          query: options[:query],
          regex: options[:regex],
          require_na: options[:require_na],
          search: options[:search],
          tag: options[:tag]
        }
        todo = NA::Todo.new(cmd_options)
        todo.actions.empty?
      end

      files
    end

    # Find a matching path using semi-fuzzy matching.
    # Search tokens can include ! and + to negate or make required.
    #
    # @param search [Array<Hash>] Search tokens to match
    # @param distance [Integer] Allowed distance between characters
    # @param require_last [Boolean] Require regex to match last element of path
    # @return [Array<String>] Array of matching directories/todo files
    def match_working_dir(search, distance: 1, require_last: true)
      file = database_path
      NA.notify("#{NA.theme[:error]}No na database found", exit_code: 1) unless File.exist?(file)

      dirs = file.read_file.split("\n")

      optional = search.filter { |s| !s[:negate] }.map { |t| t[:token] }
      required = search.filter { |s| s[:required] && !s[:negate] }.map { |t| t[:token] }
      negated = search.filter { |s| s[:negate] }.map { |t| t[:token] }

      optional.push('*') if optional.none? && required.none? && negated.any?
      if optional == negated
        required = ['*']
        optional = ['*']
      end

      NA.notify("Optional directory regex: {x}#{optional.map { |t| t.dir_to_rx(distance: distance) }}", debug: true)
      NA.notify("Required directory regex: {x}#{required.map { |t| t.dir_to_rx(distance: distance) }}", debug: true)
      NA.notify("Negated directory regex: {x}#{negated.map do |t|
        t.dir_to_rx(distance: distance, require_last: false)
      end}", debug: true)

      if require_last
        dirs.delete_if do |d|
          !d.sub(/\.#{NA.extension}$/, '')
            .dir_matches?(any: optional, all: required, none: negated, require_last: true, distance: distance)
        end
      else
        dirs.delete_if do |d|
          !d.sub(/\.#{NA.extension}$/, '')
            .dir_matches?(any: optional, all: required, none: negated, distance: 2, require_last: false)
        end
      end

      dirs = dirs.sort_by { |d| File.basename(d) }.uniq

      dirs = find_exact_dir(dirs, search) unless optional == ['*']

      if dirs.empty? && require_last
        NA.notify("#{NA.theme[:warning]}No matches, loosening search", debug: true)
        match_working_dir(search, distance: 2, require_last: false)
      else
        NA.notify("Matched files: {x}#{dirs.join(', ')}", debug: true)
        dirs
      end
    end

    # Find a directory with an exact match from a list.
    # @param dirs [Array<String>] Directories to search
    # @param search [Array<Hash>] Search tokens
    # @return [Array<String>] Matching directories
    def find_exact_dir(dirs, search)
      terms = search.filter { |s| !s[:negate] }.map { |t| t[:token] }.join(' ')
      out = dirs
      dirs.each do |dir|
        if File.basename(dir).sub(/\.#{NA.extension}$/, '') =~ /^#{terms}$/
          out = [dir]
          break
        end
      end
      out
    end

    # Save a todo file path to the database
    #
    # @param todo_file [String] The todo file path
    # @return [void]
    def save_working_dir(todo_file)
      NA::Benchmark.measure('save_working_dir') do
        file = database_path
        content = File.exist?(file) ? file.read_file : ''
        dirs = content.split("\n")
        dirs.push(File.expand_path(todo_file))
        dirs.sort!.uniq!
        File.open(file, 'w') { |f| f.puts dirs.join("\n") }
      end
    end

    # Save a backed-up file to the database
    #
    # @param file [String] The file
    # @return [void]
    def save_modified_file(file)
      db = database_path(file: 'last_modified.txt')
      file = File.expand_path(file)
      if File.exist? db
        files = File.read(db).split("\n").map(&:strip)
        files.delete(file)
        files << file
        File.open(db, 'w') { |f| f.puts(files.join("\n")) }
      else
        File.open(db, 'w') { |f| f.puts(file) }
      end
    end

    # Get the last modified file from the database
    #
    # @param search [String, nil] Optional search string
    # @return [String, nil] Last modified file path
    def last_modified_file(search: nil)
      files = backup_files
      files.delete_if { |f| f !~ Regexp.new(search.dir_to_rx(require_last: true)) } if search
      files.last
    end

    # Get last modified file and restore a backup
    #
    # @param search [String, nil] Optional search string
    # @return [void]
    def restore_last_modified_file(search: nil)
      file = last_modified_file(search: search)
      if file
        restore_modified_file(file)
      else
        NA.notify("#{NA.theme[:error]}No matching file found")
      end
    end

    # Get list of backed up files
    #
    # @return [Array<String>] List of file paths
    def backup_files
      db = database_path(file: 'last_modified.txt')
      if File.exist?(db)
        File.read(db).strip.split("\n").map(&:strip)
      else
        NA.notify("#{NA.theme[:error]}Backup database not found")
        File.open(db, 'w', &:puts)
        []
      end
    end

    # Move deprecated backup files to new backup folder
    #
    # @return [void]
    def move_deprecated_backups
      backup_files.each do |file|
        if File.exist?(old_backup_path(file))
          NA.notify("Moving deprecated backup to new backup folder (#{file})", debug: true)
          backup_path(file)
        end
      end
    end

    # Get the old backup file path for a file
    #
    # @param file [String] The file
    # @return [String] Old backup file path
    def old_backup_path(file)
      File.join(File.dirname(file), ".#{File.basename(file)}.bak")
    end

    # Get the backup file path for a file
    #
    # @param file [String] The file
    # @return [String] Backup file path
    def backup_path(file)
      backup_home = File.expand_path('~/.local/share/na/backup')
      backup = old_backup_path(file)
      backup_dir = File.join(backup_home, File.dirname(backup))
      FileUtils.mkdir_p(backup_dir) unless File.directory?(backup_dir)

      backup_target = File.join(backup_home, backup)
      FileUtils.mv(backup, backup_target) if File.exist?(backup)
      backup_target
    end

    # Remove entries for missing backup files from the database
    #
    # @param file [String, nil] Optional file to filter
    # @return [void]
    def weed_modified_files(file = nil)
      files = backup_files

      files.delete_if { |f| f =~ /#{file}/ } if file

      files.delete_if { |f| !File.exist?(backup_path(f)) }

      File.open(database_path(file: 'last_modified.txt'), 'w') { |f| f.puts files.join("\n") }
    end

    # Restore a file from backup
    #
    # @param file [String] The file
    # @return [void]
    def restore_modified_file(file)
      bak_file = backup_path(file)
      if File.exist?(bak_file)
        FileUtils.mv(bak_file, file)
        NA.notify("#{NA.theme[:success]}Backup restored for #{file.highlight_filename}")
      else
        NA.notify("#{NA.theme[:error]}Backup file for #{file.highlight_filename} not found")
      end

      weed_modified_files(file)
    end

    # Get path to database of known todo files
    #
    # @param file [String] The database filename (default: 'tdlist.txt')
    # @return [String] File path
    def database_path(file: 'tdlist.txt')
      db_dir = File.expand_path('~/.local/share/na')
      # Create directory if needed
      FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      File.join(db_dir, file)
    end

    # Platform-agnostic open command
    #
    # @param file [String] The file to open
    # @param app [String, nil] Optional application to use
    # @return [void]
    def os_open(file, app: nil)
      os = RbConfig::CONFIG['target_os']
      case os
      when /darwin.*/i
        darwin_open(file, app: app)
      when /mingw|mswin/i
        win_open(file)
      else
        linux_open(file)
      end
    end

    #
    # Remove entries from cache database that no longer exist
    #
    def weed_cache_file
      db_dir = File.expand_path('~/.local/share/na')
      db_file = 'tdlist.txt'
      file = File.join(db_dir, db_file)
      return unless File.exist?(file)

      dirs = file.read_file.split("\n")
      dirs.delete_if { |f| !File.exist?(f) }
      File.open(file, 'w') { |f| f.puts dirs.join("\n") }
    end

    # List projects in a todo file or matching query.
    # @param query [Array] Query tokens
    # @param file_path [String, nil] File path
    # @param depth [Integer] Search depth
    # @param paths [Boolean] Show full paths
    # @return [void]
    def list_projects(query: [], file_path: nil, depth: 1, paths: true)
      files = if NA.global_file
                [NA.global_file]
              elsif !file_path.nil?
                [file_path]
              elsif query.nil?
                NA.find_files(depth: depth)
              else
                match_working_dir(query)
              end

      target = files.count > 1 ? NA.select_file(files) : files[0]
      return if target.nil?

      projects = find_projects(target)
      projects.each do |proj|
        parts = proj.project.split(':')
        output = if paths
                   "{bg}#{parts.join('{bw}/{bg}')}{x}"
                 else
                   parts.fill('{bw}—{bg}', 0..-2)
                   "{bg}#{parts.join(' ')}{x}"
                 end

        puts NA::Color.template(output)
      end
    end

    # Resolve a TaskPaper-style item path (subset) into NA project paths.
    #
    # Supported subset:
    #   - Child axis: /Project/Sub
    #   - Descendant axis: //Sub (e.g. /Inbox//Bugs)
    #   - Wildcard step: * (matches any project name in that position)
    #
    # @param path [String] TaskPaper-style item path (must start with '/')
    # @param file [String, nil] Optional single file to resolve against
    # @param depth [Integer] Directory search depth when no file is given
    # @return [Array<String>] Array of project paths like "Inbox:New Videos"
    def resolve_item_path(path:, file: nil, depth: 1)
      return [] if path.nil?

      steps = parse_item_path(path)
      return [] if steps.empty?

      files = if file
                [File.expand_path(file)]
              else
                find_files(depth: depth)
              end
      return [] if files.nil? || files.empty?

      matches = []

      files.each do |f|
        todo = NA::Todo.new(require_na: false, file_path: f)
        projects = todo.projects
        next if projects.empty?

        current = resolve_path_in_projects(projects, steps)
        current.each do |proj|
          matches << proj.project
        end
      end

      matches.uniq
    end

    # Parse a TaskPaper-style item path string into steps with axis and text.
    # Returns an Array of Hashes: { axis: :child|:desc, text: String,
    # wildcard: Boolean }.
    def parse_item_path(path)
      s = path.to_s.strip
      return [] unless s.start_with?('/')

      steps = []
      i = 0
      len = s.length

      while i < len
        break unless s[i] == '/'

        axis = :child
        if i + 1 < len && s[i + 1] == '/'
          axis = :desc
          i += 1
        end
        i += 1

        text = +''
        quote = nil

        while i < len
          ch = s[i]
          if quote
            text << ch
            quote = nil if ch == quote
            i += 1
            next
          end

          if ch == '"' || ch == "'"
            quote = ch
            text << ch
            i += 1
            next
          end

          break if ch == '/'

          text << ch
          i += 1
        end

        t = text.strip
        wildcard = t.empty? || t == '*'
        steps << { axis: axis, text: t, wildcard: wildcard }
      end

      steps
    end

    # Resolve a parsed item path against a list of NA::Project objects from a
    # single file.
    #
    # @param projects [Array<NA::Project>]
    # @param steps [Array<Hash>] Parsed steps from parse_item_path
    # @return [Array<NA::Project>] Matching projects (last step)
    def resolve_path_in_projects(projects, steps)
      return [] if steps.empty? || projects.empty?

      # First step: from a virtual root; child axis means top-level projects
      # (no ':' in path), descendant axis means any project in the file.
      first = steps.first
      current = []

      projects.each do |proj|
        case first[:axis]
        when :child
          next unless proj.project.split(':').length == 1
        when :desc
          # any project is a descendant of the virtual root
        end

        current << proj if item_path_step_match?(first, proj)
      end

      steps[1..].each do |step|
        next_current = []
        current.each do |parent|
          parent_path = parent.project
          parent_depth = parent_path.split(':').length
          projects.each do |proj|
            next if proj.equal?(parent)

            case step[:axis]
            when :child
              next unless proj.project.start_with?("#{parent_path}:")
              next unless proj.project.split(':').length == parent_depth + 1
            when :desc
              next unless proj.project.start_with?("#{parent_path}:")
            end

            next unless item_path_step_match?(step, proj)

            next_current << proj
            pp next_current.inspect
          end
        end
        current = next_current.uniq
        break if current.empty?
      end

      current
    end

    # Check if a project matches a single item-path step.
    def item_path_step_match?(step, proj)
      return true if step[:wildcard]

      name = proj.project.split(':').last.to_s
      txt = step[:text]
      return false if txt.nil? || txt.empty?

      if txt =~ /[*?]/
        rx = Regexp.new(txt.wildcard_to_rx, Regexp::IGNORECASE)
        !!(name =~ rx)
      else
        name.downcase.include?(txt.downcase)
      end
    end

    # List todo files matching a query.
    # @param query [Array] Query tokens
    # @return [void]
    def list_todos(query: [])
      dirs = if query
               match_working_dir(query, distance: 2, require_last: false)
             else
               file = database_path
               content = File.exist?(file) ? file.read_file.strip : ''
               notify("#{NA.theme[:error]}Database empty", exit_code: 1) if content.empty?

               content.split("\n")
             end

      dirs.map!(&:highlight_filename)

      puts NA::Color.template(dirs.join("\n"))
    end

    # Save a search definition to the database.
    # @param title [String] The search title
    # @param search [String] The search string
    # @return [void]
    def save_search(title, search)
      file = database_path(file: 'saved_searches.yml')
      searches = load_searches
      title = title.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').downcase

      if searches.key?(title)
        res = yn('Overwrite existing definition?', default: true)
        notify("#{NA.theme[:error]}Cancelled", exit_code: 0) unless res

      end

      searches[title] = search
      File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }
      NA.notify("#{NA.theme[:success]}Search #{NA.theme[:filename]}#{title}#{NA.theme[:success]} saved", exit_code: 0)
    end

    # Parse a TaskPaper-style @search() expression into NA search components.
    #
    # TaskPaper expressions are of the form (subset of full syntax):
    #   @search(@tag, @tag = 1, @tag contains 1, not @tag, project = "Name", not project = "Name", plain, "text")
    #
    # Supported operators (mapped from TaskPaper searches, see:
    # https://guide.taskpaper.com/reference/searches/):
    #   - boolean: and / not   (or/parentheses are not yet fully supported)
    #   - @tag, not @tag
    #   - @tag = VALUE, @tag > VALUE, @tag < VALUE, @tag >= VALUE, @tag <= VALUE, @tag =~ VALUE
    #   - @tag contains VALUE, beginswith VALUE, endswith VALUE, matches VALUE
    #   - @text REL VALUE  (treated as plain-text search on the line)
    #   - project = "Name", not project = "Name"
    #
    # The result can be passed directly to NA::Todo via the returned clause
    # hashes, which include keys :tokens, :tags, :project, :include_done, and
    # :exclude_projects.
    #
    # @param expr [String] TaskPaper @search() expression or inner content
    # @return [Hash] Parsed components for a single AND-joined clause
    def parse_taskpaper_search(expr)
      clauses = parse_taskpaper_search_clauses(expr)
      clauses.first || { tokens: [], tags: [], project: nil, include_done: nil, exclude_projects: [] }
    end

    # Internal: parse a single (AND-joined) TaskPaper clause into search
    # components.
    #
    # @param clause [String] Clause content with no surrounding @search()
    # @param out [Hash] Accumulator hash (tokens/tags/project/etc.)
    # @return [Hash] The same +out+ hash
    def parse_taskpaper_search_clause(clause, out)
      parts = clause.split(/\band\b/i).map(&:strip).reject(&:empty?)

      parts.each do |raw_part|
        part = raw_part.dup
        neg = false

        if part =~ /\Anot\s+(.+)\z/i
          neg = true
          part = Regexp.last_match(1).strip
        end

        # @tag, @tag OP VALUE, or @attribute OP VALUE
        if part =~ /\A@([A-Za-z0-9_\-:.]+)\s*(?:(=|==|!=|>=|<=|>|<|=~|contains(?:\[[^\]]+\])?|beginswith(?:\[[^\]]+\])?|endswith(?:\[[^\]]+\])?|matches(?:\[[^\]]+\])?)\s*(.+))?\z/i
          tag = Regexp.last_match(1)
          op  = Regexp.last_match(2)
          val = Regexp.last_match(3)&.strip
          val = val[1..-2] if val && ((val.start_with?('"') && val.end_with?('"')) || (val.start_with?("'") && val.end_with?("'")))

          # Handle @text as a plain-text predicate on the line
          if tag.casecmp('text').zero?
            if val
              token_val = val
              out[:tokens] << {
                token: token_val,
                required: !neg,
                negate: neg
              }
            end
            next
          end

          if tag.casecmp('done').zero?
            # Handle done specially via :include_done; do NOT add a tag filter,
            # otherwise Todo.parse would force include @done actions.
            out[:include_done] = !neg
            next
          end

          # Normalize operator: strip TaskPaper relation modifiers and map
          # relation names to our internal comparison codes.
          op = op.to_s.downcase
          # Strip relation modifiers like [i], [sl], [dn], etc.
          op = op.sub(/\[.*\]\z/, '')

          # Translate "!=" into a negated equality check
          if op == '!='
            op = '='
            neg = true
          elsif op == 'contains'
            op = '*='
          elsif op == 'beginswith'
            op = '^='
          elsif op == 'endswith'
            op = '$='
          elsif op == 'matches'
            op = '=~'
          end

          tag_hash = {
            tag: tag.wildcard_to_rx,
            comp: op,
            value: val,
            required: !neg,
            negate: neg
          }
          out[:tags] << tag_hash
          next
        end

        # project = "Name", project != "Name"
        if part =~ /\Aproject\s*(=|==|!=)\s*(.+)\z/i
          op = Regexp.last_match(1)
          val = Regexp.last_match(2).strip
          val = val[1..-2] if (val.start_with?('"') && val.end_with?('"')) || (val.start_with?("'") && val.end_with?("'"))

          if neg || op == '!='
            out[:exclude_projects] << val
          else
            out[:project] = val
          end
          next
        end

        # Fallback: treat as a plain text token
        token = part
        token = token[1..-2] if (token.start_with?('"') && token.end_with?('"')) || (token.start_with?("'") && token.end_with?("'"))
        out[:tokens] << {
          token: token,
          required: !neg,
          negate: neg
        }
      end

      out
    end

    # Parse a TaskPaper-style @search() expression into multiple OR-joined
    # clauses. Each clause is an AND-joined set of predicates represented as a
    # hash compatible with NA::Todo options. Supports nested boolean
    # expressions with parentheses using `and` / `or`. The unary `not`
    # operator is handled inside individual predicates.
    #
    # Also supports an optional leading item path (subset) before predicates, e.g.:
    #   @search(/Inbox//Testing and not @done)
    # The leading path is exposed on each clause as :item_paths and is later
    # resolved via resolve_item_path in run_taskpaper_search.
    #
    # @param expr [String] TaskPaper @search() expression or inner content
    # @return [Array<Hash>] Array of clause hashes
    def parse_taskpaper_search_clauses(expr)
      return [] if expr.nil?

      NA.notify("TP DEBUG expr: #{expr.inspect}", debug: true) if NA.verbose

      inner = expr.to_s.strip
      NA.notify("TP DEBUG inner initial: #{inner.inspect}", debug: true) if NA.verbose
      inner = Regexp.last_match(1).strip if inner =~ /\A@search\((.*)\)\s*\z/i
      NA.notify("TP DEBUG inner after @search strip: #{inner.inspect}", debug: true) if NA.verbose

      return [] if inner.empty?

      # Extract optional leading item path (must start with '/'). The remaining
      # content is treated as the boolean expression for predicates. We allow
      # spaces inside the path and stop at the first unquoted AND/OR keyword.
      item_path = nil
      if inner.start_with?('/')
        i = 0
        quote = nil
        sep_index = nil
        sep_len = nil
        while i < inner.length
          ch = inner[i]
          if quote
            quote = nil if ch == quote
            i += 1
            next
          end

          if ch == '"' || ch == "'"
            quote = ch
            i += 1
            next
          end

          # Look for unquoted AND/OR separators
          rest = inner[i..]
          if rest =~ /\A\s+and\b/i
            sep_index = i
            sep_len = rest.match(/\A\s+and\b/i)[0].length
            break
          elsif rest =~ /\A\s+or\b/i
            sep_index = i
            sep_len = rest.match(/\A\s+or\b/i)[0].length
            break
          end

          i += 1
        end

        if sep_index
          item_path = inner[0...sep_index].strip
          inner = inner[(sep_index + sep_len)..].to_s.strip
        else
          item_path = inner.strip
          inner = ''
        end
      end
      NA.notify("TP DEBUG item_path: #{item_path.inspect} inner now: #{inner.inspect}", debug: true) if NA.verbose

      # Extract optional trailing slice, e.g.:
      #   [index], [start:end], [start:], [:end], [:]
      # from the entire inner expression (including parenthesized forms like
      # (expr)[0]).
      slice = nil
      if inner =~ /\A(.+)\[(\d*:?(\d*)?)\]\s*\z/m
        expr_part = Regexp.last_match(1).strip
        slice_str = Regexp.last_match(2)

        if slice_str.include?(':')
          start_str, end_str = slice_str.split(':', 2)
          slice = {
            start: (start_str.nil? || start_str.empty? ? nil : start_str.to_i),
            end: (end_str.nil? || end_str.empty? ? nil : end_str.to_i)
          }
        else
          slice = { index: slice_str.to_i }
        end

        inner = expr_part
      end
      NA.notify("TP DEBUG slice: #{slice.inspect} inner after slice: #{inner.inspect}", debug: true) if NA.verbose

      # If the entire expression is wrapped in a single pair of parentheses,
      # strip them so shortcuts like `project Inbox and @na` can be recognized.
      if inner.start_with?('(') && inner.end_with?(')')
        depth = 0
        balanced = true
        inner.chars.each_with_index do |ch, idx|
          depth += 1 if ch == '('
          depth -= 1 if ch == ')'
          if depth.zero? && idx < inner.length - 1
            balanced = false
            break
          end
        end
        inner = inner[1..-2].strip if balanced
      end

      # Expand TaskPaper type shortcuts at the start of the predicate expression:
      #   project NAME  -> project = "NAME"
      #   task NAME     -> NAME                  (we only search tasks anyway)
      #   note NAME     -> NAME                  (approximate)
      if inner =~ /\A(project|task|note)\s+(.+)\z/i
        kind = Regexp.last_match(1).downcase
        rest = Regexp.last_match(2).strip
        case kind
        when 'project'
          # If this is just `project NAME`, treat it as a project constraint.
          # If it contains additional boolean logic (and/or), drop the
          # `project NAME` prefix and leave the rest of the expression
          # unchanged for normal predicate parsing.
          if rest =~ /\b(and|or)\b/i
            # Drop leading "NAME and" and keep the remainder, e.g.
            # "Inbox and @na and not @done" -> "@na and not @done"
            # then strip the leading "and" to leave "@na and not @done".
            inner = if rest =~ /\A(\S+)\s+and\s+(.+)\z/mi
                      Regexp.last_match(2).strip
                    else
                      rest
                    end
          else
            name = rest
            # Strip surrounding quotes if present
            name = name[1..-2] if (name.start_with?('"') && name.end_with?('"')) || (name.start_with?("'") && name.end_with?("'"))
            inner = %(project = "#{name}")
          end
        when 'task', 'note'
          # For now, treat as a plain text search on the rest
          inner = rest
        end
      end

      NA.notify("TP DEBUG inner before tokenizing: #{inner.inspect}", debug: true) if NA.verbose

      # Tokenize expression into TEXT, AND, OR, '(', ')', preserving quoted
      # strings and leaving `not` to be handled inside predicates.
      tokens = []
      current = +''
      quote = nil
      i = 0

      boundary = lambda do |str, idx, len|
        before = idx.positive? ? str[idx - 1] : nil
        after = (idx + len) < str.length ? str[idx + len] : nil
        before_ok = before.nil? || before =~ /\s|\(/
        after_ok = after.nil? || after =~ /\s|\)/
        before_ok && after_ok
      end

      while i < inner.length
        ch = inner[i]

        if quote
          current << ch
          quote = nil if ch == quote
          i += 1
          next
        end

        if ch == '"' || ch == "'"
          quote = ch
          current << ch
          i += 1
          next
        end

        if ch == '(' || ch == ')'
          tokens << [:TEXT, current] unless current.strip.empty?
          current = +''
          tokens << [ch, ch]
          i += 1
          next
        end

        if ch =~ /\s/
          unless current.strip.empty?
            tokens << [:TEXT, current]
            current = +''
          end
          i += 1
          next
        end

        rest = inner[i..]
        if rest.downcase.start_with?('and') && boundary.call(inner, i, 3)
          tokens << [:TEXT, current] unless current.strip.empty?
          current = +''
          tokens << [:AND, 'and']
          i += 3
          next
        elsif rest.downcase.start_with?('or') && boundary.call(inner, i, 2)
          tokens << [:TEXT, current] unless current.strip.empty?
          current = +''
          tokens << [:OR, 'or']
          i += 2
          next
        else
          current << ch
          i += 1
        end
      end
      tokens << [:TEXT, current] unless current.strip.empty?

      # Recursive-descent parser producing DNF (array of AND-clauses)
      index = 0

      current_token = lambda { tokens[index] }
      advance = lambda { index += 1 }

      # Declare parse_or in outer scope so it's visible inside parse_primary
      parse_or = nil

      parse_primary = lambda do
        tok = current_token.call
        return [] unless tok

        type, = tok
        if type == '('
          advance.call
          clauses = parse_or.call
          advance.call if current_token.call && current_token.call[0] == ')'
          clauses
        elsif type == :TEXT
          parts = []
          while current_token.call && current_token.call[0] == :TEXT
            parts << current_token.call[1].strip
            advance.call
          end
          pred = parts.join(' ').strip
          return [] if pred.empty?

          [parse_taskpaper_search_clause(pred, {
                                           tokens: [],
                                           tags: [],
                                           project: nil,
                                           include_done: nil,
                                           exclude_projects: [],
                                           item_paths: [],
                                           slice: slice
                                         })]
        else
          advance.call
          []
        end
      end

      parse_and = lambda do
        clauses = parse_primary.call
        while current_token.call && current_token.call[0] == :AND
          advance.call
          right = parse_primary.call
          combined = []
          clauses.each do |left_clause|
            right.each do |right_clause|
              combined << {
                tokens: left_clause[:tokens] + right_clause[:tokens],
                tags: left_clause[:tags] + right_clause[:tags],
                project: right_clause[:project] || left_clause[:project],
                include_done: right_clause[:include_done].nil? ? left_clause[:include_done] : right_clause[:include_done],
                exclude_projects: left_clause[:exclude_projects] + right_clause[:exclude_projects]
              }
            end
          end
          clauses = combined
        end
        clauses
      end

      parse_or = lambda do
        clauses = parse_and.call
        while current_token.call && current_token.call[0] == :OR
          advance.call
          right = parse_and.call
          clauses.concat(right)
        end
        clauses
      end

      clauses = parse_or.call

      # If there was only an item path and no predicates, create a single
      # empty clause to carry the path.
      if clauses.empty? && item_path
        clauses = [{
          tokens: [],
          tags: [],
          project: nil,
          include_done: nil,
          exclude_projects: [],
          item_paths: [],
          slice: slice
        }]
      end

      # Attach leading item path (if any) to all clauses
      if item_path
        clauses.each do |clause|
          clause[:item_paths] ||= []
          clause[:item_paths] << item_path
        end
      end

      clauses
    end

    # Load TaskPaper-style saved searches from todo files.
    #
    # Scans all lines in each file for:
    #   [WHITESPACE]TITLE @search(PARAMS)
    # regardless of project name or indentation. This allows searches to live
    # in any project (e.g. "Searches") or even at top level.
    #
    # @param depth [Integer] Directory depth to search for files
    # @return [Hash{String=>Hash}] Map of title to {:expr, :file}
    def load_taskpaper_searches(depth: 1)
      searches = {}
      files = find_files(depth: depth)
      return searches if files.nil? || files.empty?

      files.each do |file|
        content = file.read_file
        next if content.nil? || content.empty?

        content.each_line do |line|
          next if line.strip.empty?
          next unless line =~ /^\s*(.+?)\s+@search\((.+)\)\s*$/

          title = Regexp.last_match(1).strip
          expr = "@search(#{Regexp.last_match(2).strip})"
          searches[title] = { expr: expr, file: file }
        end
      end

      searches
    end

    # Evaluate a TaskPaper-style @search() expression and return matching
    # actions and files, without printing.
    #
    # @param expr [String] TaskPaper @search() expression
    # @param file [String,nil] Optional single file to search within
    # @param options [Hash] Display/search options (subset of find.rb)
    # @return [Array(NA::Actions, Array<String>, Array<Hash>)] actions, files, clauses
    def evaluate_taskpaper_search(expr, file: nil, options: {})
      clauses = parse_taskpaper_search_clauses(expr)
      NA.notify("TP DEBUG clauses: #{clauses.inspect}", debug: true) if NA.verbose
      return [NA::Actions.new, [], []] if clauses.empty?

      depth = options[:depth] || 1
      all_actions = NA::Actions.new
      all_files = []

      clauses.each do |parsed|
        search_tokens = parsed[:tokens]
        tags = parsed[:tags]
        include_done = parsed[:include_done]
        exclude_projects = parsed[:exclude_projects] || []
        project = parsed[:project] || options[:project]
        slice = parsed[:slice]

        # Resolve any item-path filters declared on this clause
        item_paths = Array(parsed[:item_paths]).compact
        resolved_paths = []
        item_paths.each do |p|
          resolved_paths.concat(resolve_item_path(path: p, file: file, depth: depth))
        end

        todo_options = {
          depth: depth,
          done: include_done.nil? ? options[:done] : include_done,
          query: nil,
          search: search_tokens,
          search_note: options.fetch(:search_notes, true),
          tag: tags,
          negate: options.fetch(:invert, false),
          regex: options.fetch(:regex, false),
          project: project,
          require_na: options.fetch(:require_na, false)
        }
        todo_options[:file_path] = file if file

        todo = NA::Todo.new(todo_options)

        # Start from the full action list for this clause
        clause_actions = todo.actions.to_a
        if NA.verbose
          NA.notify("TP DEBUG initial actions count: #{clause_actions.size}", debug: true)
          clause_actions.each do |a|
            NA.notify("TP DEBUG action: #{a.action.inspect} parents=#{Array(a.parent).inspect}", debug: true)
          end
        end

        # Apply project exclusions (e.g. "not project = \"Archive\"")
        unless exclude_projects.empty?
          before = clause_actions.size
          clause_actions.delete_if do |action|
            parents = Array(action.parent)
            last = parents.last.to_s
            full = parents.join(':')
            exclude_projects.any? do |proj|
              proj_rx = Regexp.new(Regexp.escape(proj), Regexp::IGNORECASE)
              last =~ proj_rx || full =~ /(^|:)#{Regexp.escape(proj)}$/i
            end
          end
          NA.notify("TP DEBUG after exclude_projects: #{clause_actions.size} (was #{before})", debug: true) if NA.verbose
        end

        # Apply item-path project filters, if any
        unless resolved_paths.empty?
          before = clause_actions.size
          clause_actions.delete_if do |action|
            parents = Array(action.parent)
            path = parents.join(':')
            resolved_paths.none? do |p|
              path =~ /\A#{Regexp.escape(p)}(?::|\z)/i
            end
          end
          NA.notify("TP DEBUG after item_path filter: #{clause_actions.size} (was #{before})", debug: true) if NA.verbose
        end

        # Apply slice, if present, to the filtered clause actions
        if slice
          before = clause_actions.size
          if slice[:index]
            idx = slice[:index].to_i
            clause_actions = idx.negative? ? [] : [clause_actions[idx]].compact
          else
            start_idx = slice[:start] || 0
            end_idx = slice[:end] || clause_actions.length
            clause_actions = clause_actions[start_idx...end_idx] || []
          end
          NA.notify("TP DEBUG after slice #{slice.inspect}: #{clause_actions.size} (was #{before})", debug: true) if NA.verbose
        end

        all_files.concat(todo.files)
        clause_actions.each { |a| all_actions.push(a) }
      end

      # De-duplicate actions across clauses
      seen = {}
      merged_actions = NA::Actions.new
      all_actions.each do |a|
        key = "#{a.file_path}:#{a.file_line}"
        next if seen[key]

        seen[key] = true
        merged_actions.push(a)
      end

      if NA.verbose
        NA.notify("TP DEBUG merged_actions count: #{merged_actions.size}", debug: true)
        merged_actions.each do |a|
          NA.notify("TP DEBUG merged action: #{a.file_path}:#{a.file_line} #{a.action.inspect}", debug: true)
        end
      end

      [merged_actions, all_files.uniq, clauses]
    end

    # Execute a TaskPaper-style @search() expression using NA::Todo and output
    # results with the standard formatting options.
    #
    # @param expr [String] TaskPaper @search() expression
    # @param file [String,nil] Optional single file to search within
    # @param options [Hash] Display/search options (subset of find.rb)
    # @return [void]
    def run_taskpaper_search(expr, file: nil, options: {})
      actions, files, clauses = evaluate_taskpaper_search(expr, file: file, options: options)
      depth = options[:depth] || 1

      # Build regexes for highlighting from all positive tokens across clauses
      regexes = []
      clauses.each do |parsed|
        sts = parsed[:tokens]
        if sts.is_a?(Array)
          regexes.concat(sts.delete_if { |token| token[:negate] }.map { |token| token[:token].wildcard_to_rx })
        elsif sts
          regexes << sts
        end
      end
      regexes.uniq!

      actions.output(depth,
                     {
                       files: files,
                       regexes: regexes,
                       notes: options.fetch(:notes, false),
                       nest: options.fetch(:nest, false),
                       nest_projects: options.fetch(:omnifocus, false),
                       no_files: options.fetch(:no_file, false),
                       times: options.fetch(:times, false),
                       human: options.fetch(:human, false)
                     })
    end

    # Load saved search definitions from YAML file
    #
    # @return [Hash] Hash of saved searches
    def load_searches
      file = database_path(file: 'saved_searches.yml')
      if File.exist?(file)
        searches = YAML.load(file.read_file)
      else
        searches = {
          'soon' => 'tagged "due<in 2 days,due>yesterday"',
          'overdue' => 'tagged "due<now"',
          'high' => 'tagged "prio>3"',
          'maybe' => 'tagged "maybe"'
        }
        File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }
      end
      searches
    end

    # Delete saved search definitions by name
    #
    # @param strings [Array<String>, String, nil] Names of searches to delete
    # @return [void]
    def delete_search(strings = nil)
      NA.notify("#{NA.theme[:error]}Name of search required", exit_code: 1) if strings.nil? || strings.empty?

      file = database_path(file: 'saved_searches.yml')
      NA.notify("#{NA.theme[:error]}No search definitions file found", exit_code: 1) unless File.exist?(file)

      strings = [strings] unless strings.is_a? Array

      searches = YAML.load(file.read_file)
      keys = searches.keys.delete_if { |k| k !~ /(#{strings.map(&:wildcard_to_rx).join('|')})/ }

      NA.notify("#{NA.theme[:error]}No search named #{strings.join(', ')} found", exit_code: 1) if keys.empty?

      res = yn(NA::Color.template(%(#{NA.theme[:warning]}Remove #{keys.count > 1 ? 'searches' : 'search'} #{NA.theme[:filename]}"#{keys.join(', ')}"{x})),
               default: false)

      NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless res

      searches.delete_if { |k| keys.include?(k) }

      File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }

      NA.notify(
        "#{NA.theme[:warning]}Deleted {bw}#{keys.count}{x}#{NA.theme[:warning]} #{keys.count > 1 ? 'searches' : 'search'}", exit_code: 0
      )
    end

    # Edit saved search definitions in the default editor
    #
    # @return [void]
    def edit_searches
      file = database_path(file: 'saved_searches.yml')
      searches = load_searches

      NA.notify("#{NA.theme[:error]}No search definitions found", exit_code: 1) unless searches.any?

      editor = NA.default_editor
      NA.notify("#{NA.theme[:error]}No $EDITOR defined", exit_code: 1) unless editor && TTY::Which.exist?(editor)

      system %(#{editor} "#{file}")
      NA.notify("#{NA.theme[:success]}Opened #{file} in #{editor}", exit_code: 0)
    end

    # Create a backup file
    #
    # @param target [String] The file to back up
    # @return [void]
    def backup_file(target)
      FileUtils.cp(target, backup_path(target))
      save_modified_file(target)
      NA.notify("#{NA.theme[:warning]}Backup file created for #{target.highlight_filename}", debug: true)
    end

    #
    # Request terminal input from user, readline style
    #
    # @param      options  [Hash] The options
    # @param      prompt   [String] The prompt
    #
    def request_input(options, prompt: 'Enter text')
      if $stdin.isatty && TTY::Which.exist?('gum') && (options[:tagged].nil? || options[:tagged].empty?)
        opts = [%(--placeholder "#{prompt}"),
                '--char-limit=500',
                "--width=#{TTY::Screen.columns}"]
        `gum input #{opts.join(' ')}`.strip
      elsif $stdin.isatty && options[:tagged].empty?
        NA.notify("#{NA.theme[:prompt]}#{prompt}:")
        reader.read_line(NA::Color.template("#{NA.theme[:filename]}> #{NA.theme[:action]}")).strip
      end
    end

    #
    # Generate a menu of options and allow user selection
    #
    # @return     [String] The selected option
    #
    # @param      options   [Array] The options from which to choose
    # @param      prompt    [String] The prompt
    # @param      multiple  [Boolean] If true, allow multiple selections
    # @param      sorted    [Boolean] If true, sort selections alphanumerically
    # @param      fzf_args  [Array] Additional fzf arguments
    #
    # @return [String, Array] array if multiple is true
    def choose_from(options, prompt: 'Make a selection: ', multiple: false, sorted: true, fzf_args: [])
      return nil unless $stdout.isatty

      options.sort! if sorted

      res = if TTY::Which.exist?('fzf')
              default_args = [%(--prompt="#{prompt}"), "--height=#{options.count + 2}", '--info=inline']
              default_args << '--multi' if multiple
              default_args << '--bind ctrl-a:select-all' if multiple
              header = "esc: cancel,#{' tab: multi-select, ctrl-a: select all,' if multiple} return: confirm"
              default_args << %(--header="#{header}")
              default_args.concat(fzf_args)
              options = NA::Color.uncolor(NA::Color.template(options.join("\n")))
              `echo #{Shellwords.escape(options)}|#{TTY::Which.which('fzf')} #{default_args.join(' ')}`.strip
            elsif TTY::Which.exist?('gum')
              args = [
                '--cursor.foreground="151"',
                '--item.foreground=""'
              ]
              args.push '--no-limit' if multiple
              puts NA::Color.template("#{NA.theme[:prompt]}#{prompt}{x}")
              options = NA::Color.uncolor(NA::Color.template(options.join("\n")))
              `echo #{Shellwords.escape(options)}|#{TTY::Which.which('gum')} choose #{args.join(' ')}`.strip
            else
              reader = TTY::Reader.new
              puts
              options.each.with_index do |f, i|
                puts NA::Color.template(format(
                                          "#{NA.theme[:prompt]}%<idx> 2d{xw}) #{NA.theme[:filename]}%<action>s{x}\n", idx: i + 1, action: f
                                        ))
              end
              result = reader.read_line(NA::Color.template("#{NA.theme[:prompt]}#{prompt}{x}")).strip
              if multiple
                mult_res = []
                result = result.gsub(',', ' ').gsub(/ +/, ' ').split(/ /)
                result.each do |r|
                  mult_res << options[r.to_i - 1] if r.to_i.positive?
                end
                mult_res.join("\n")
              else
                result.to_i.positive? ? options[result.to_i - 1] : nil
              end
            end

      return false if res&.strip&.empty?

      # pp NA::Color.uncolor(NA::Color.template(res))
      multiple ? NA::Color.uncolor(NA::Color.template(res)).split("\n") : NA::Color.uncolor(NA::Color.template(res))
    end

    private

    #
    # macOS open command
    #
    # @param      file  The file
    # @param      app   The application
    #
    def darwin_open(file, app: nil)
      if app
        `open -a "#{app}" #{Shellwords.escape(file)}`
      else
        `open #{Shellwords.escape(file)}`
      end
    end

    #
    # Windows open command
    #
    # @param      file  The file
    #
    def win_open(file)
      `start #{Shellwords.escape(file)}`
    end

    #
    # Linux open command
    #
    # @param      file  The file
    #
    def linux_open(file)
      if TTY::Which.exist?('xdg-open')
        `xdg-open #{Shellwords.escape(file)}`
      else
        notify("#{NA.theme[:error]}Unable to determine executable for `xdg-open`.")
      end
    end
  end
end
