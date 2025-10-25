# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    include NA::Editor

    attr_accessor :verbose, :extension, :include_ext, :na_tag, :command_line, :command, :globals, :global_file,
                  :cwd_is, :cwd, :stdin, :show_cwd_indicator

    def theme
      @theme ||= NA::Theme.load_theme
    end

    def notify(msg, exit_code: false, debug: false)
      return if debug && !NA.verbose

      if debug
        warn NA::Color.template("{x}#{NA.theme[:debug]}#{msg}{x}")
      else
        warn NA::Color.template("{x}#{msg}{x}")
      end
      Process.exit exit_code if exit_code
    end

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

      notify("#{NA.theme[:error]}No file selected, cancelled", exit_code: 1) unless res&.length&.positive?

      res
    end

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
    # @return [Array] Projects and actions
    def find_actions(target, search, tagged = nil, all: false, done: false, project: nil, search_note: true)
      todo = NA::Todo.new({ search: search,
                            search_note: search_note,
                            require_na: false,
                            file_path: target,
                            project: project,
                            tag: tagged,
                            done: done })

      unless todo.actions.count.positive?
        NA.notify("#{NA.theme[:error]}No matching actions found in #{File.basename(target,
                                                                                   ".#{NA.extension}").highlight_filename}")
        return
      end

      return [todo.projects, todo.actions] if todo.actions.count == 1 || all

      options = todo.actions.map { |action| "#{action.line} % #{action.parent.join('/')} : #{action.action}" }
      res = choose_from(options, prompt: 'Make a selection: ', multiple: true, sorted: true)

      NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless res&.length&.positive?

      selected = NA::Actions.new
      res.each do |result|
        idx = result.match(/^(\d+)(?= % )/)[1]
        action = todo.actions.select { |a| a.line == idx.to_i }.first
        selected.push(action)
      end
      [todo.projects, selected]
    end

    # Insert a new project into a todo file
    #
    # @param target [String] Path to the todo file
    # @param project [String] Project name
    # @param projects [Array<NA::Project>] Existing projects
    # @return [NA::Project] The new project
    def insert_project(target, project, _projects)
      path = project.split(%r{[:/]})
      todo = NA::Todo.new(file_path: target)
      built = []
      last_match = nil
      final_match = nil
      new_path = []
      matches = nil
      path.each_with_index do |part, i|
        built.push(part)
        matches = todo.projects.select { |proj| proj.project =~ /^#{built.join(':')}/i }
        if matches.count.zero?
          final_match = last_match
          new_path = path.slice(i, path.count - i)
          break
        else
          last_match = matches.last
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
                      tagged: nil)
      projects = find_projects(target)
      affected_actions = []

      target_proj = nil

      if move
        move = move.sub(/:$/, '')
        target_proj = projects.select { |pr| pr.project =~ /#{move.gsub(':', '.*?:.*?')}/i }.first
        if target_proj.nil?
          res = NA.yn(
            NA::Color.template("#{NA.theme[:warning]}Project #{NA.theme[:file]}#{move}#{NA.theme[:warning]} doesn't exist, add it"), default: true
          )
          if res
            target_proj = insert_project(target, move, projects)
            projects << target_proj
          else
            NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
          end
        end
      end

      contents = target.read_file.split("\n")

      if add.is_a?(Action)
        add_tag ||= []
        add.process(priority: priority, finish: finish, add_tag: add_tag, remove_tag: remove_tag)

        projects = find_projects(target)

        target_proj = if target_proj
                        projects.select { |proj| proj.project =~ /^#{target_proj.project}$/i }.first
                      else
                        # First try exact full-path match
                        projects.select { |proj| proj.project =~ /^#{add.parent.join(':')}$/i }.first
                      end

        # If no exact match, try unique suffix match (e.g., :Ideas at end)
        if target_proj.nil?
          leaf = Regexp.escape(add.parent.join(':'))
          suffix_matches = projects.select { |proj| proj.project =~ /(^|:)#{leaf}$/i }
          if suffix_matches.count == 1
            target_proj = suffix_matches.first
          elsif suffix_matches.count > 1 && $stdout.isatty
            choice = choose_from(suffix_matches.map(&:project), prompt: 'Select a target project: ', multiple: false)
            target_proj = projects.select { |proj| proj.project == choice }.first if choice
          end
        end

        if target_proj.nil?
          res = NA.yn(
            NA::Color.template("#{NA.theme[:warning]}Project #{NA.theme[:file]}#{add.project}#{NA.theme[:warning]} doesn't exist, add it"), default: true
          )

          if res
            target_proj = insert_project(target, project, projects)
            projects << target_proj
          else
            NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1)
          end

          if target_proj.nil?
            NA.notify("#{NA.theme[:error]}Error parsing project #{NA.theme[:filename]}#{target}",
                      exit_code: 1)
          end

          projects = find_projects(target)
          contents = target.read_file.split("\n")
        end

        indent = "\t" * target_proj.indent
        note = note.split("\n") unless note.is_a?(Array)
        note = if note.empty?
                 add.note
               else
                 overwrite ? note : add.note.concat(note)
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

        contents.insert(target_line, "#{indent}\t- #{add.action}#{note}")

        notify(add.pretty)

        # Track affected action and description
        changes = ['added']
        changes << 'finished' if finish
        changes << "priority=#{priority}" if priority.to_i.positive?
        changes << "tags+#{add_tag.join(',')}" unless add_tag.nil? || add_tag.empty?
        changes << "tags-#{remove_tag.join(',')}" unless remove_tag.nil? || remove_tag.empty?
        changes << 'note updated' unless note.nil? || note.empty?
        affected_actions << { action: add, desc: changes.join(', ') }
      else
        _, actions = find_actions(target, search, tagged, done: done, all: all, project: project,
                                                          search_note: search_note)

        return if actions.nil?

        actions.sort_by(&:line).reverse.each do |action|
          contents.slice!(action.line, action.note.count + 1)
          if delete
            # Track deletion before skipping re-insert
            affected_actions << { action: action, desc: 'deleted' }
            next
          end

          projects = shift_index_after(projects, action.line, action.note.count + 1)

          if edit
            editor_content = "#{action.action}\n#{action.note.join("\n")}"
            new_action, new_note = Editor.format_input(Editor.fork_editor(editor_content))
            action.action = new_action
            action.note = new_note
          end

          # If replace is defined, use search to search and replace text in action
          action.action.sub!(Regexp.new(Regexp.escape(search), Regexp::IGNORECASE), replace) if replace

          action.process(priority: priority, finish: finish, add_tag: add_tag, remove_tag: remove_tag)

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
    def add_action(file, project, action, note = [], priority: 0, finish: false, append: false)
      parent = project.split(%r{[:/]})

      if NA.global_file
        if NA.cwd_is == :tag
          add_tag = [NA.cwd]
        else
          project = NA.cwd
        end
      end

      action = Action.new(file, project, parent, action, nil, note)

      update_action(file, nil, add: action, project: project, add_tag: add_tag, priority: priority, finish: finish,
                               append: append)
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
        files.each { |f| save_working_dir(File.expand_path(f)) }
        files
      end
    end

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

      optional.push('*') if optional.count.zero? && required.count.zero? && negated.count.positive?
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
        dirs.delete_if { |d| !d.sub(/\.#{NA.extension}$/, '').dir_matches(any: optional, all: required, none: negated) }
      else
        dirs.delete_if do |d|
          !d.sub(/\.#{NA.extension}$/, '')
            .dir_matches(any: optional, all: required, none: negated, distance: 2, require_last: false)
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

    def save_search(title, search)
      file = database_path(file: 'saved_searches.yml')
      searches = load_searches
      title = title.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')

      if searches.key?(title)
        res = yn('Overwrite existing definition?', default: true)
        notify("#{NA.theme[:error]}Cancelled", exit_code: 0) unless res

      end

      searches[title] = search
      File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }
      NA.notify("#{NA.theme[:success]}Search #{NA.theme[:filename]}#{title}#{NA.theme[:success]} saved", exit_code: 0)
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

      NA.notify("#{NA.theme[:error]}No search definitions found", exit_code: 1) unless searches.count.positive?

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
              header = "esc: cancel,#{multiple ? ' tab: multi-select, ctrl-a: select all,' : ''} return: confirm"
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
                  mult_res << options[r.to_i - 1] if r.to_i&.positive?
                end
                mult_res.join("\n")
              else
                result.to_i&.positive? ? options[result.to_i - 1] : nil
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
