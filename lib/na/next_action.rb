# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    attr_accessor :verbose, :extension, :na_tag, :command_line, :command, :globals, :global_file, :cwd_is, :cwd, :stdin

    ##
    ## Output to STDERR
    ##
    ## @param      msg        [String] The message
    ## @param      exit_code  [Number] The exit code, no
    ##                        exit if false
    ## @param      debug      [Boolean] only display message if running :verbose
    ##
    def notify(msg, exit_code: false, debug: false)
      return if debug && !NA.verbose

      $stderr.puts NA::Color.template("{x}#{msg}{x}")
      Process.exit exit_code if exit_code
    end

    ##
    ## Display and read a Yes/No prompt
    ##
    ## @param      prompt   [String] The prompt string
    ## @param      default  [Boolean] default value if
    ##                      return is pressed or prompt is
    ##                      skipped
    ##
    ## @return     [Boolean] result
    ##
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

    ##
    ## Helper function to colorize the Y/N prompt
    ##
    ## @param      choices  [Array] The choices with
    ##                      default capitalized
    ##
    ## @return     [String] colorized string
    ##
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

    ##
    ## Create a new todo file
    ##
    ## @param      target    [String] The target path
    ## @param      basename  [String] The project base name
    ##
    def create_todo(target, basename)
      File.open(target, 'w') do |f|
        content = <<~ENDCONTENT
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
          \tNext @search(@#{NA.na_tag} and not @done and not project = \"Archive\")
        ENDCONTENT
        f.puts(content)
      end
      save_working_dir(target)
      notify("{y}Created {bw}#{target}")
    end

    ##
    ## Use the *nix `find` command to locate files matching NA.extension
    ##
    ## @param      depth  [Number] The depth at which to search
    ##
    def find_files(depth: 1)
      return [NA.global_file] if NA.global_file

      files = `find . -name "*.#{NA.extension}" -maxdepth #{depth}`.strip.split("\n")
      files.each { |f| save_working_dir(File.expand_path(f)) }
      files
    end

    ##
    ## Select from multiple files
    ##
    ## @note       If `gum` or `fzf` are available, they'll
    ##             be used (in that order)
    ##
    ## @param      files     [Array] The files
    ## @param      multiple  [Boolean] allow multiple selections
    ##
    ## @return [String, Array] array if multiple
    def select_file(files, multiple: false)
      res = choose_from(files, prompt: multiple ? 'Select files' : 'Select a file', multiple: multiple)

      notify('{r}No file selected, cancelled', exit_code: 1) unless res && res.length.positive?

      res
    end

    def shift_index_after(projects, idx, length = 1)
      projects.map do |proj|
        proj.line = proj.line - length if proj.line > idx
        proj.last_line = proj.last_line - length if proj.last_line > idx

        proj
      end
    end

    def find_projects(target)
      _, _, projects = parse_actions(require_na: false, file_path: target)
      projects
    end

    def find_actions(target, search, tagged = nil, all: false, done: false)
      _, actions, projects = parse_actions(search: search, require_na: false, file_path: target, tag: tagged, done: done)

      unless actions.count.positive?
        NA.notify("{r}No matching actions found in {bw}#{File.basename(target, ".#{NA.extension}")}")
        return
      end

      return [projects, actions] if actions.count == 1 || all

      options = actions.map { |action| "#{action.line} % #{action.parent.join('/')} : #{action.action}" }
      res = choose_from(options, prompt: 'Make a selection: ', multiple: true, sorted: true)

      NA.notify('{r}Cancelled', exit_code: 1) unless res && res.length.positive?

      selected = []
      res.each do |result|
        idx = result.match(/^(\d+)(?= % )/)[1]
        action = actions.select { |a| a.line == idx.to_i }.first
        selected.push(action)
      end
      [projects, selected]
    end

    def insert_project(target, project)
      path = project.split(%r{[:/]})
      _, _, projects = parse_actions(file_path: target)
      built = []
      last_match = nil
      final_match = nil
      new_path = []
      matches = nil
      path.each_with_index do |part, i|
        built.push(part)
        matches = projects.select { |proj| proj.project =~ /^#{built.join(':')}/i }
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

        if new_path.join('') =~ /Archive/i
          content = "#{content.strip}\n#{input.join("\n")}"
        else
          content = "#{input.join("\n")}\n#{content}"
        end

        new_project = NA::Project.new(path.map(&:cap_first).join(':'), indent - 1, input.count - 1, input.count - 1)
      else
        line = final_match.line + 1
        indent = final_match.indent + 1
        input = []
        new_path.each do |part|
          input.push("#{"\t" * indent}#{part.cap_first}:")
          indent += 1
        end
        content = content.split("\n").insert(line, input.join("\n")).join("\n")
        new_project = NA::Project.new(path.map(&:cap_first).join(':'), indent - 1, line + input.count - 1, line + input.count - 1)
      end

      File.open(target, 'w') do |f|
        f.puts content
      end

      new_project
    end

    def process_action(action, priority: 0, finish: false, add_tag: [], remove_tag: [], note: [])
      string = action.action

      if priority&.positive?
        string.gsub!(/(?<=\A| )@priority\(\d+\)/, '').strip!
        string += " @priority(#{priority})"
      end

      add_tag.each do |tag|
        string.gsub!(/(?<=\A| )@#{tag.gsub(/([()*?])/, '\\\\1')}(\(.*?\))?/, '')
        string.strip!
        string += " @#{tag}"
      end

      remove_tag.each do |tag|
        string.gsub!(/(?<=\A| )@#{tag.gsub(/([()*?])/, '\\\\1')}(\(.*?\))?/, '')
        string.strip!
      end

      string = "#{string.strip} @done(#{Time.now.strftime('%Y-%m-%d %H:%M')})" if finish && string !~ /(?<=\A| )@done/

      action.action = string

      action
    end

    def update_action(target,
                      search,
                      add: nil,
                      priority: 0,
                      add_tag: [],
                      remove_tag: [],
                      finish: false,
                      project: nil,
                      delete: false,
                      note: [],
                      overwrite: false,
                      tagged: nil,
                      all: false,
                      done: false,
                      append: false)

      projects = find_projects(target)

      target_proj = nil

      if project
        project = project.sub(/:$/, '')
        target_proj = projects.select { |pr| pr.project =~ /#{project.gsub(/:/, '.*?:.*?')}/i }.first
        if target_proj.nil?
          res = NA.yn(NA::Color.template("{y}Project {bw}#{project}{xy} doesn't exist, add it"), default: true)
          if res
            target_proj = insert_project(target, project)
          else
            NA.notify('{x}Cancelled', exit_code: 1)
          end
        end
      end

      contents = target.read_file.split(/\n/)

      if add.is_a?(Action)
        add_tag ||= []
        action = process_action(add, priority: priority, finish: finish, add_tag: add_tag, remove_tag: remove_tag)

        projects = find_projects(target)

        target_proj = if target_proj
                        projects.select { |proj| proj.project =~ /^#{target_proj.project}$/ }.first
                      else
                        projects.select { |proj| proj.project =~ /^#{action.parent.join(':')}$/ }.first
                      end

        NA.notify("{r}Error parsing project #{target_proj}", exit_code: 1) if target_proj.nil?

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
      else
        _, actions = find_actions(target, search, tagged, done: done, all: all)

        return if actions.nil?

        actions.sort_by(&:line).reverse.each do |action|
          contents.slice!(action.line, action.note.count + 1)
          next if delete

          projects = shift_index_after(projects, action.line, action.note.count + 1)

          action = process_action(action, priority: priority, finish: finish, add_tag: add_tag, remove_tag: remove_tag)

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
        end
      end

      backup_file(target)
      File.open(target, 'w') { |f| f.puts contents.join("\n") }

      add ? notify("{by}Task added to {bw}#{target}") : notify("{by}Task updated in {bw}#{target}")
    end

    ##
    ## Add an action to a todo file
    ##
    ## @param      file     [String] The target file
    ## @param      project  [String] The project name
    ## @param      action   [String] The action
    ## @param      note     [String] The note
    ##
    def add_action(file, project, action, note = [], priority: 0, finish: false, append: false)
      parent = project.split(%r{[:/]})

      if NA.global_file
        puts NA.global_file
        if NA.cwd_is == :tag
          add_tag = [NA.cwd]
        else
          project = NA.cwd
        end
        puts [add_tag, project]
      end

      action = Action.new(file, project, parent, action, nil, note)

      update_action(file, nil, add: action, project: project, add_tag: add_tag, priority: priority, finish: finish, append: append)
    end

    def project_hierarchy(actions)
      parents = { actions: []}
      actions.each do |a|
        parent = a.parent
        current_parent = parents
        parent.each do |par|
          if !current_parent.key?(par)
            current_parent[par] = { actions: [] }
          end
          current_parent = current_parent[par]
        end

        current_parent[:actions].push(a)
      end
      parents
    end

    def output_children(children, level = 1)
      out = []
      indent = "\t" * level
      children.each do |k, v|
        if k.to_s =~ /actions/
          indent += "\t"

          v.each do |a|
            item = "#{indent}- #{a.action}"

            unless a.tags.empty?
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

    ##
    ## Pretty print a list of actions
    ##
    ## @param      actions  [Array] The actions
    ## @param      depth    [Number] The depth
    ## @param      files    [Array] The files actions originally came from
    ## @param      regexes  [Array] The regexes used to gather actions
    ##
    def output_actions(actions, depth, files: nil, regexes: [], notes: false, nest: false, nest_projects: false)
      return if files.nil?

      if nest
        template = '%parent%action'

        parent_files = {}
        out = []

        if nest_projects
          actions.each do |action|
            if parent_files.key?(action.file)
              parent_files[action.file].push(action)
            else
              parent_files[action.file] = [action]
            end
          end

          parent_files.each do |file, acts|
            projects = project_hierarchy(acts)
            out.push("#{file.sub(%r{^./}, '').shorten_path}:")
            out.concat(output_children(projects, 0))
          end
        else
          template = '%parent%action'

          actions.each do |action|
            if parent_files.key?(action.file)
              parent_files[action.file].push(action)
            else
              parent_files[action.file] = [action]
            end
          end

          parent_files.each do |k, v|
            out.push("#{k.sub(%r{^\./}, '')}:")
            v.each do |a|
              out.push("\t- [#{a.parent.join('/')}] #{a.action}")
              out.push("\t\t#{a.note.join("\n\t\t")}") unless a.note.empty?
            end
          end
        end
        puts out.join("\n")
      else
        template = if files.count.positive?
                     if files.count == 1
                       '%parent%action'
                     else
                       '%filename%parent%action'
                     end
                   elsif find_files(depth: depth).count > 1
                     if depth > 1
                       '%filename%parent%action'
                     else
                       '%project%parent%action'
                     end
                   else
                     '%parent%action'
                   end
        template += '%note' if notes

        files.map { |f| notify("{dw}#{f}", debug: true) } if files

        puts(actions.map { |action| action.pretty(template: { output: template }, regexes: regexes, notes: notes) })
      end
    end

    ##
    ## Read a todo file and create a list of actions
    ##
    ## @param      depth       [Number] The directory depth
    ##                         to search for files
    ## @param      done        [Boolean] include @done actions
    ## @param      query       [Hash] The todo file query
    ## @param      tag         [Array] Tags to search for
    ## @param      search      [String] A search string
    ## @param      negate      [Boolean] Invert results
    ## @param      regex       [Boolean] Interpret as
    ##                         regular expression
    ## @param      project     [String] The project
    ## @param      require_na  [Boolean] Require @na tag
    ## @param      file_path   [String] file path to parse
    ##
    def parse_actions(depth: 1, done: false, query: nil, tag: nil, search: nil, negate: false, regex: false, project: nil, require_na: true, file_path: nil)
      actions = []
      required = []
      optional = []
      negated = []
      required_tag = []
      optional_tag = []
      negated_tag = []
      projects = []

      tag&.each do |t|
        unless t[:tag].nil?
          if negate
            optional_tag.push(t) if t[:negate]
            required_tag.push(t) if t[:required] && t[:negate]
            negated_tag.push(t) unless t[:negate]
          else
            optional_tag.push(t) unless t[:negate]
            required_tag.push(t) if t[:required] && !t[:negate]
            negated_tag.push(t) if t[:negate]
          end
        end
      end

      unless search.nil?
        if regex || search.is_a?(String)
          if negate
            negated.push(search)
          else
            optional.push(search)
            required.push(search)
          end
        else
          search.each do |t|
            opt, req, neg = parse_search(t, negate)
            optional.concat(opt)
            required.concat(req)
            negated.concat(neg)
          end
        end
      end

      files = if !file_path.nil?
                [file_path]
              elsif query.nil?
                find_files(depth: depth)
              else
                match_working_dir(query)
              end

      files.each do |file|
        save_working_dir(File.expand_path(file))
        content = file.read_file
        indent_level = 0
        parent = []
        last_line = 0
        in_action = false
        content.split("\n").each.with_index do |line, idx|
          if line.project?
            in_action = false
            proj = line.project
            indent = line.indent_level

            if indent.zero? # top level project
              parent = [proj]
            elsif indent <= indent_level # if indent level is same or less, split parent before indent level and append
              parent.slice!(indent, parent.count - indent)
              parent.push(proj)
            else # if indent level is greater, append project to parent
              parent.push(proj)
            end

            projects.push(NA::Project.new(parent.join(':'), indent, idx, idx))

            indent_level = indent
          elsif line.blank?
            in_action = false
          elsif line.action?
            in_action = false

            action = line.action
            new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action, idx)

            projects[-1].last_line = idx if projects.count.positive?

            next if line.done? && !done

            next if require_na && !line.na?

            has_search = !optional.empty? || !required.empty? || !negated.empty?

            next if has_search && !new_action.search_match?(any: optional,
                                                            all: required,
                                                            none: negated)

            if project
              rx = project.split(%r{[/:]}).join('.*?/.*?')
              next unless parent.join('/') =~ Regexp.new(rx, Regexp::IGNORECASE)
            end

            has_tag = !optional_tag.empty? || !required_tag.empty? || !negated_tag.empty?
            next if has_tag && !new_action.tags_match?(any: optional_tag,
                                                       all: required_tag,
                                                       none: negated_tag)

            actions.push(new_action)
            in_action = true
          elsif in_action
            actions[-1].note.push(line.strip) if actions.count.positive?
            projects[-1].last_line = idx if projects.count.positive?
          end
        end
        projects = projects.dup
      end

      [files, actions, projects]
    end

    def edit_file(file: nil, app: nil)
      os_open(file, app: app) if file && File.exist?(file)
    end

    ##
    ## Platform-agnostic open command
    ##
    ## @param      file  [String] The file to open
    ##
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

    ##
    ## Remove entries from cache database that no longer exist
    ##
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
                find_files(depth: depth)
              else
                match_working_dir(query)
              end
      target = files.count > 1 ? NA.select_file(files) : files[0]
      projects = find_projects(target)
      projects.each do |proj|
        parts = proj.project.split(/:/)
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
               notify('{br}Database empty', exit_code: 1) if content.empty?

               content.split(/\n/)
             end

      dirs.map! do |dir|
        "{xg}#{dir.sub(/^#{ENV['HOME']}/, '~').sub(%r{/([^/]+)\.#{NA.extension}$}, '/{xbw}\1{x}')}"
      end

      puts NA::Color.template(dirs.join("\n"))
    end

    def save_search(title, search)
      file = database_path(file: 'saved_searches.yml')
      searches = load_searches
      title = title.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')

      if searches.key?(title)
        res = yn('Overwrite existing definition?', default: true)
        notify('{r}Cancelled', exit_code: 0) unless res

      end

      searches[title] = search
      File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }
      NA.notify("{y}Search #{title} saved", exit_code: 0)
    end

    def load_searches
      file = database_path(file: 'saved_searches.yml')
      if File.exist?(file)
        searches = YAML.safe_load(file.read_file)
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

    def delete_search(strings = nil)
      NA.notify('{r}Name search required', exit_code: 1) if strings.nil? || strings.empty?

      file = database_path(file: 'saved_searches.yml')
      NA.notify('{r}No search definitions file found', exit_code: 1) unless File.exist?(file)

      searches = YAML.safe_load(file.read_file)
      keys = searches.keys.delete_if { |k| k !~ /(#{strings.join('|')})/ }

      res = yn(NA::Color.template(%({y}Remove #{keys.count > 1 ? 'searches' : 'search'} {bw}"#{keys.join(', ')}"{x})),
               default: false)

      NA.notify('{r}Cancelled', exit_code: 1) unless res

      searches.delete_if { |k| keys.include?(k) }

      File.open(file, 'w') { |f| f.puts(YAML.dump(searches)) }

      NA.notify("{y}Deleted {bw}#{keys.count}{xy} #{keys.count > 1 ? 'searches' : 'search'}", exit_code: 0)
    end

    def edit_searches
      file = database_path(file: 'saved_searches.yml')
      searches = load_searches

      NA.notify('{r}No search definitions found', exit_code: 1) unless searches.count.positive?

      editor = ENV['EDITOR']
      NA.notify('{r}No $EDITOR defined', exit_code: 1) unless editor && TTY::Which.exist?(editor)

      system %(#{editor} "#{file}")
      NA.notify("Opened #{file} in #{editor}", exit_code: 0)
    end

    ##
    ## Get path to database of known todo files
    ##
    ## @return     [String] File path
    ##
    def database_path(file: 'tdlist.txt')
      db_dir = File.expand_path('~/.local/share/na')
      # Create directory if needed
      FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      File.join(db_dir, file)
    end

    ##
    ## Create a backup file
    ##
    ## @param      target [String] The file to back up
    ##
    def backup_file(target)
      file = ".#{File.basename(target)}.bak"
      backup = File.join(File.dirname(target), file)
      FileUtils.cp(target, backup)
      NA.notify("{dw}Backup file created at #{backup}", debug: true)
    end

    ##
    ## Find a matching path using semi-fuzzy matching.
    ## Search tokens can include ! and + to negate or make
    ## required.
    ##
    ## @param      search        [Array] search tokens to
    ##                           match
    ## @param      distance      [Integer] allowed distance
    ##                           between characters
    ## @param      require_last  [Boolean] require regex to
    ##                           match last element of path
    ##
    ## @return     [Array] array of matching directories/todo files
    ##
    def match_working_dir(search, distance: 1, require_last: true)
      file = database_path
      notify('{r}No na database found', exit_code: 1) unless File.exist?(file)

      dirs = file.read_file.split("\n")

      optional = search.filter { |s| !s[:negate] }.map { |t| t[:token] }
      required = search.filter { |s| s[:required] }.map { |t| t[:token] }
      negated = search.filter { |s| s[:negate] }.map { |t| t[:token] }

      optional.push('*') if optional.count.zero? && required.count.zero? && negated.count.positive?
      if optional == negated
        required = ['*']
        optional = ['*']
      end

      NA.notify("{dw}Optional directory regex: {x}#{optional.map(&:dir_to_rx)}", debug: true)
      NA.notify("{dw}Required directory regex: {x}#{required.map(&:dir_to_rx)}", debug: true)
      NA.notify("{dw}Negated directory regex: {x}#{negated.map { |t| t.dir_to_rx(distance: 1, require_last: false) }}", debug: true)

      if require_last
        dirs.delete_if { |d| !d.sub(/\.#{NA.extension}$/, '').dir_matches(any: optional, all: required, none: negated) }
      else
        dirs.delete_if { |d| !d.sub(/\.#{NA.extension}$/, '').dir_matches(any: optional, all: required, none: negated, distance: 2, require_last: false) }
      end

      dirs = dirs.sort.uniq
      if dirs.empty? && require_last
        NA.notify("{y}No matches, loosening search", debug: true)
        match_working_dir(search, distance: 2, require_last: false)
      else
        dirs
      end
    end

    private

    ##
    ## Generate a menu of options and allow user selection
    ##
    ## @return     [String] The selected option
    ##
    ## @param      options   [Array] The options from which to choose
    ## @param      prompt    [String] The prompt
    ## @param      multiple  [Boolean] If true, allow multiple selections
    ## @param      sorted    [Boolean] If true, sort selections alphanumerically
    ## @param      fzf_args  [Array] Additional fzf arguments
    ##
    ## @return [String, Array] array if multiple is true
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
              `echo #{Shellwords.escape(options.join("\n"))}|#{TTY::Which.which('fzf')} #{default_args.join(' ')}`.strip
            elsif TTY::Which.exist?('gum')
              args = [
                '--cursor.foreground="151"',
                '--item.foreground=""'
              ]
              args.push '--no-limit' if multiple
              puts NS::Color.template("{bw}#{prompt}{x}")
              `echo #{Shellwords.escape(options.join("\n"))}|#{TTY::Which.which('gum')} choose #{args.join(' ')}`.strip
            else
              reader = TTY::Reader.new
              puts
              options.each.with_index do |f, i|
                puts NA::Color.template(format("{bw}%<idx> 2d{xw}) {y}%<action>s{x}\n", idx: i + 1, action: f))
              end
              result = reader.read_line(NA::Color.template("{bw}#{prompt}{x}")).strip
              result.to_i&.positive? ? options[result.to_i - 1] : nil
            end

      return false if res.strip.size.zero?

      multiple ? res.split(/\n/) : res
    end

    def parse_search(tag, negate)
      required = []
      optional = []
      negated = []
      new_rx = tag[:token].to_s.wildcard_to_rx

      if negate
        optional.push(new_rx) if tag[:negate]
        required.push(new_rx) if tag[:required] && tag[:negate]
        negated.push(new_rx) unless tag[:negate]
      else
        optional.push(new_rx) unless tag[:negate]
        required.push(new_rx) if tag[:required] && !tag[:negate]
        negated.push(new_rx) if tag[:negate]
      end

      [optional, required, negated]
    end

    ##
    ## Save a todo file path to the database
    ##
    ## @param      todo_file  The todo file path
    ##
    def save_working_dir(todo_file)
      file = database_path
      content = File.exist?(file) ? file.read_file : ''
      dirs = content.split(/\n/)
      dirs.push(File.expand_path(todo_file))
      dirs.sort!.uniq!
      File.open(file, 'w') { |f| f.puts dirs.join("\n") }
    end

    ##
    ## macOS open command
    ##
    ## @param      file  The file
    ## @param      app   The application
    ##
    def darwin_open(file, app: nil)
      if app
        `open -a "#{app}" #{Shellwords.escape(file)}`
      else
        `open #{Shellwords.escape(file)}`
      end
    end

    ##
    ## Windows open command
    ##
    ## @param      file  The file
    ##
    def win_open(file)
      `start #{Shellwords.escape(file)}`
    end

    ##
    ## Linux open command
    ##
    ## @param      file  The file
    ##
    def linux_open(file)
      if TTY::Which.exist?('xdg-open')
        `xdg-open #{Shellwords.escape(file)}`
      else
        notify('{r}Unable to determine executable for `xdg-open`.')
      end
    end
  end
end
